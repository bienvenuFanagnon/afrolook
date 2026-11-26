import 'payment_report.dart';
import 'dart:async';

import 'package:afrolook_api_client/afrolook_api_client.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:uuid/uuid.dart';

import '../models/coin_pack.dart';
import 'api/api_identity.dart';
import 'api/wallet_api.dart';
import '../utils/payment_region.dart';

enum PlayIapEventType { success, canceled, error, pending }

class PlayIapEvent {
  final PlayIapEventType type;
  final int coins;
  final String message;
  const PlayIapEvent(this.type, {this.coins = 0, this.message = ''});
}

/// Achats de pièces via Google Play Billing (Android uniquement) — pendant de AppleIapService.
///
/// Chaque achat est vérifié par l'API (POST /coins/purchases/google, qui relit le jeton chez Google et le confirme) avant d'être terminé.
/// Sur Android, Google NE renvoie PAS tout seul un achat non terminé au lancement : [start] le redemande (restorePurchases) à chaque
/// lancement, pour qu'un achat interrompu (coupure réseau, API indisponible, app fermée) finisse toujours crédité (26/11/2026).
/// Le serveur ne crédite jamais deux fois le même achat (« already_credited »).
class GooglePlayIapService extends ChangeNotifier {
  GooglePlayIapService._();
  static final GooglePlayIapService instance = GooglePlayIapService._();

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;
  final StreamController<PlayIapEvent> _events = StreamController<PlayIapEvent>.broadcast();

  bool storeAvailable = true;
  bool loadingProducts = false;
  List<ProductDetails> products = [];
  String? purchasingProductId;
  VoidCallback? onCoinsCredited;

  Stream<PlayIapEvent> get events => _events.stream;

  /// Même valeur que appAccountTokenFor() côté serveur : lie l'achat au compte Afrolook.
  static String accountToken(String uid) => const Uuid().v5(Namespace.url.value, 'afrolook:$uid');

  int coinsFor(String productId) =>
      CoinPack.playProducts.firstWhere((p) => p.playProductId == productId, orElse: () => CoinPack(coins: 0, priceFcfa: 0)).coins;

  /// À appeler une fois l'utilisateur connecté ; sans effet hors Android.
  void start() {
    if (!PaymentRegion.isAndroid || _sub != null) return;
    _sub = _iap.purchaseStream.listen(
      _onPurchases,
      onError: (Object e) => debugPrint('GooglePlayIapService: $e'),
    );
    // achats payés mais pas encore terminés (pièces pas encore créditées) : Google les renvoie seulement si on le demande
    unawaited(_resumeOpenPurchases());
  }

  Future<void> _resumeOpenPurchases() async {
    try {
      if (!await _iap.isAvailable()) return;
      await _iap.restorePurchases(applicationUserName: _myAccountToken());
    } catch (e) {
      debugPrint('GooglePlayIapService.restorePurchases: $e');
    }
  }

  static String? _myAccountToken() {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? ApiIdentity.myId;
    return uid == null ? null : accountToken(uid);
  }

  Future<void> loadProducts() async {
    if (!PaymentRegion.isAndroid) return;
    loadingProducts = true;
    notifyListeners();
    try {
      storeAvailable = await _iap.isAvailable();
      if (storeAvailable) {
        final ids = CoinPack.playProducts.map((p) => p.playProductId).toSet();
        final response = await _iap.queryProductDetails(ids);
        products = response.productDetails..sort((a, b) => coinsFor(a.id).compareTo(coinsFor(b.id)));
        if (response.notFoundIDs.isNotEmpty) {
          debugPrint('GooglePlayIapService: produits absents de Play Console : ${response.notFoundIDs}');
        }
      }
    } catch (e) {
      debugPrint('GooglePlayIapService.loadProducts: $e');
      storeAvailable = false;
    } finally {
      loadingProducts = false;
      notifyListeners();
    }
  }

  Future<void> buy(ProductDetails product) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || purchasingProductId != null) return;
    start();
    purchasingProductId = product.id;
    notifyListeners();
    try {
      // autoConsume: false (26/11/2026) : le module consommait l'achat dès le paiement, AVANT la vérification du serveur ; si elle échouait,
      // l'achat était perdu (consommé, jamais crédité, jamais rendu par Google). Il n'est maintenant consommé qu'une fois les pièces créditées.
      await _iap.buyConsumable(
        purchaseParam: PurchaseParam(productDetails: product, applicationUserName: accountToken(uid)),
        autoConsume: false,
      );
    } on PlatformException catch (e) {
      debugPrint('GooglePlayIapService.buy: $e');
      PaymentReport.send(provider: 'google_play', step: 'buy', code: e.code, message: e.message ?? e);
      _finishUi(const PlayIapEvent(PlayIapEventType.error,
          message: "L'achat n'a pas pu démarrer. Réessaie dans un instant."));
    }
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          _events.add(const PlayIapEvent(PlayIapEventType.pending, message: 'Achat en attente de validation par Google Play.'));
          break;
        case PurchaseStatus.canceled:
          PaymentReport.send(provider: 'google_play', step: 'purchase', code: 'canceled', message: 'Achat annulé par la personne', expected: true);
          await _complete(purchase);
          _finishUi(const PlayIapEvent(PlayIapEventType.canceled));
          break;
        case PurchaseStatus.error:
          PaymentReport.send(provider: 'google_play', step: 'purchase', code: purchase.error?.code, message: purchase.error?.message ?? 'Achat en erreur');
          await _complete(purchase);
          _finishUi(const PlayIapEvent(PlayIapEventType.error, message: "L'achat n'a pas abouti. Tu n'as pas été débité."));
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _deliver(purchase);
          break;
      }
    }
  }

  Future<void> _deliver(PurchaseDetails purchase) async {
    // Pas connecté (ni Firebase ni session de l'API) : on ne termine pas l'achat, il sera redemandé au prochain lancement.
    final token = purchase.verificationData.serverVerificationData;
    if ((FirebaseAuth.instance.currentUser == null && ApiIdentity.myId == null) || token.isEmpty) return;
    // achat repris au lancement (pas un achat en cours dans la boutique) : aucun message, sauf quand des pièces sont vraiment ajoutées
    final silent = purchasingProductId == null;
    try {
      // Le jeton d'achat est relu chez Google par l'API avant de créditer (jamais côté application).
      final result = await WalletApi.instance.verifyGoogle(purchase.productID, token);
      await _complete(purchase);
      // pièces créditées (ou déjà créditées) : on consomme l'achat pour pouvoir racheter le même pack (sinon itemAlreadyOwned)
      await _consume(purchase);
      final coins = (result['coins'] as num?)?.toInt() ?? coinsFor(purchase.productID);
      if (silent && result['already_credited'] == true) return;   // déjà crédité : on termine seulement l'achat chez Google
      onCoinsCredited?.call();
      _finishUi(PlayIapEvent(PlayIapEventType.success, coins: coins));
    } on ApiException catch (e) {
      final definitive = e.status >= 400 && e.status < 500 && e.status != 401 && e.status != 429 && e.code != 'pending';
      if (!definitive) PaymentReport.send(provider: 'google_play', step: 'verify', code: e.code, message: e.message);
      if (definitive) {
        await _complete(purchase);
        await _consume(purchase);   // refus définitif (autre compte, remboursé…) : on libère le pack
        _finishUi(const PlayIapEvent(PlayIapEventType.error,
            message: "Cet achat n'a pas pu être validé. Contacte le support si tu as été débité."));
      } else if (silent) {
        return;   // reprise au lancement : nouvel essai au prochain lancement, sans message
      } else {
        // Erreur temporaire : l'achat reste ouvert et sera crédité au prochain lancement.
        _finishUi(const PlayIapEvent(PlayIapEventType.error,
            message: 'Paiement reçu, mais la validation a échoué. Tes pièces seront créditées automatiquement '
                "au prochain lancement de l'app."));
      }
    } catch (e) {
      debugPrint('GooglePlayIapService._deliver: $e');
      PaymentReport.send(provider: 'google_play', step: 'verify', code: 'client', message: e);
      if (silent) return;
      _finishUi(const PlayIapEvent(PlayIapEventType.error,
          message: 'Paiement reçu, mais la validation a échoué. Tes pièces seront créditées automatiquement '
              "au prochain lancement de l'app."));
    }
  }

  Future<void> _consume(PurchaseDetails purchase) async {
    try {
      await _iap.getPlatformAddition<InAppPurchaseAndroidPlatformAddition>().consumePurchase(purchase);
    } catch (e) {
      debugPrint('GooglePlayIapService.consumePurchase: $e');
    }
  }

  Future<void> _complete(PurchaseDetails purchase) async {
    if (purchase.pendingCompletePurchase) {
      try {
        await _iap.completePurchase(purchase);
      } catch (e) {
        debugPrint('GooglePlayIapService.completePurchase: $e');
      }
    }
  }

  void _finishUi(PlayIapEvent event) {
    purchasingProductId = null;
    notifyListeners();
    _events.add(event);
  }
}
