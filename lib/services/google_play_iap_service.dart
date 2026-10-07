import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:uuid/uuid.dart';

import '../models/coin_pack.dart';
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
/// Chaque achat est vérifié par la Cloud Function verifyGooglePlayPurchase avant d'être terminé
/// auprès de Google. Tant qu'il n'est pas terminé, Google le redonne à chaque lancement :
/// un achat interrompu (coupure réseau, app fermée) finit toujours crédité.
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
      await _iap.buyConsumable(
        purchaseParam: PurchaseParam(productDetails: product, applicationUserName: accountToken(uid)),
      );
    } on PlatformException catch (e) {
      debugPrint('GooglePlayIapService.buy: $e');
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
          await _complete(purchase);
          _finishUi(const PlayIapEvent(PlayIapEventType.canceled));
          break;
        case PurchaseStatus.error:
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
    // Pas connecté : on ne termine pas l'achat, Google le redonnera au prochain lancement.
    final token = purchase.verificationData.serverVerificationData;
    if (FirebaseAuth.instance.currentUser == null || token.isEmpty) return;
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('verifyGooglePlayPurchase')
          .call({'productId': purchase.productID, 'purchaseToken': token});
      await _complete(purchase);
      final coins = (result.data is Map ? (result.data['coins'] as num?)?.toInt() : null) ?? coinsFor(purchase.productID);
      onCoinsCredited?.call();
      _finishUi(PlayIapEvent(PlayIapEventType.success, coins: coins));
    } on FirebaseFunctionsException catch (e) {
      const definitive = {'invalid-argument', 'failed-precondition', 'permission-denied'};
      if (definitive.contains(e.code)) {
        await _complete(purchase);
        _finishUi(const PlayIapEvent(PlayIapEventType.error,
            message: "Cet achat n'a pas pu être validé. Contacte le support si tu as été débité."));
      } else {
        // Erreur temporaire : l'achat reste ouvert et sera crédité au prochain lancement.
        _finishUi(const PlayIapEvent(PlayIapEventType.error,
            message: 'Paiement reçu, mais la validation a échoué. Tes pièces seront créditées automatiquement '
                "au prochain lancement de l'app."));
      }
    } catch (e) {
      debugPrint('GooglePlayIapService._deliver: $e');
      _finishUi(const PlayIapEvent(PlayIapEventType.error,
          message: 'Paiement reçu, mais la validation a échoué. Tes pièces seront créditées automatiquement '
              "au prochain lancement de l'app."));
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
