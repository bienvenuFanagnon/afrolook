import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:uuid/uuid.dart';

import '../models/coin_pack.dart';
import '../utils/platform_guard.dart';

enum AppleIapEventType { success, canceled, error, pending }

class AppleIapEvent {
  final AppleIapEventType type;
  final int coins;
  final String message;
  const AppleIapEvent(this.type, {this.coins = 0, this.message = ''});
}

/// Achats de pièces via l'App Store (iOS uniquement).
///
/// Chaque achat est vérifié par la Cloud Function verifyApplePurchase avant d'être
/// terminé auprès d'Apple. Tant qu'il n'est pas terminé, Apple le redonne à chaque
/// lancement : un achat interrompu (coupure réseau, app fermée) finit toujours crédité.
class AppleIapService extends ChangeNotifier {
  AppleIapService._();
  static final AppleIapService instance = AppleIapService._();

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;
  final StreamController<AppleIapEvent> _events = StreamController<AppleIapEvent>.broadcast();

  bool storeAvailable = true;
  bool loadingProducts = false;
  List<ProductDetails> products = [];
  String? purchasingProductId;
  VoidCallback? onCoinsCredited;

  Stream<AppleIapEvent> get events => _events.stream;

  /// Même valeur que appAccountTokenFor() côté serveur : lie l'achat au compte Afrolook.
  static String appAccountToken(String uid) => const Uuid().v5(Namespace.url.value, 'afrolook:$uid');

  int coinsFor(String productId) =>
      CoinPack.appleProducts.firstWhere((p) => p.appleProductId == productId, orElse: () => CoinPack(coins: 0, priceFcfa: 0)).coins;

  /// À appeler une fois l'utilisateur connecté ; sans effet hors iOS.
  void start() {
    if (!kIsAppleStore || _sub != null) return;
    _sub = _iap.purchaseStream.listen(
      _onPurchases,
      onError: (Object e) => debugPrint('AppleIapService: $e'),
    );
  }

  Future<void> loadProducts() async {
    if (!kIsAppleStore) return;
    loadingProducts = true;
    notifyListeners();
    try {
      storeAvailable = await _iap.isAvailable();
      if (storeAvailable) {
        final ids = CoinPack.appleProducts.map((p) => p.appleProductId).toSet();
        final response = await _iap.queryProductDetails(ids);
        products = response.productDetails..sort((a, b) => coinsFor(a.id).compareTo(coinsFor(b.id)));
        if (response.notFoundIDs.isNotEmpty) {
          debugPrint('AppleIapService: produits absents d\'App Store Connect : ${response.notFoundIDs}');
        }
      }
    } catch (e) {
      debugPrint('AppleIapService.loadProducts: $e');
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
        purchaseParam: PurchaseParam(productDetails: product, applicationUserName: appAccountToken(uid)),
      );
    } on PlatformException catch (e) {
      debugPrint('AppleIapService.buy: $e');
      _finishUi(const AppleIapEvent(AppleIapEventType.error,
          message: "L'achat n'a pas pu démarrer. Réessaie dans un instant."));
    }
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          _events.add(const AppleIapEvent(AppleIapEventType.pending,
              message: "Achat en attente de validation par Apple."));
          break;
        case PurchaseStatus.canceled:
          await _complete(purchase);
          _finishUi(const AppleIapEvent(AppleIapEventType.canceled));
          break;
        case PurchaseStatus.error:
          await _complete(purchase);
          _finishUi(const AppleIapEvent(AppleIapEventType.error,
              message: "L'achat n'a pas abouti. Tu n'as pas été débité."));
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _deliver(purchase);
          break;
      }
    }
  }

  Future<void> _deliver(PurchaseDetails purchase) async {
    // Pas connecté : on ne termine pas l'achat, Apple le redonnera au prochain lancement.
    if (FirebaseAuth.instance.currentUser == null || purchase.purchaseID == null) return;
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('verifyApplePurchase')
          .call({'transactionId': purchase.purchaseID});
      await _complete(purchase);
      final coins = (result.data is Map ? (result.data['coins'] as num?)?.toInt() : null) ?? coinsFor(purchase.productID);
      onCoinsCredited?.call();
      _finishUi(AppleIapEvent(AppleIapEventType.success, coins: coins));
    } on FirebaseFunctionsException catch (e) {
      const definitive = {'invalid-argument', 'failed-precondition', 'permission-denied'};
      if (definitive.contains(e.code)) {
        await _complete(purchase);
        _finishUi(const AppleIapEvent(AppleIapEventType.error,
            message: "Cet achat n'a pas pu être validé. Contacte le support si tu as été débité."));
      } else {
        // Erreur temporaire : l'achat reste ouvert et sera crédité au prochain lancement.
        _finishUi(const AppleIapEvent(AppleIapEventType.error,
            message: "Paiement reçu, mais la validation a échoué. Tes pièces seront créditées automatiquement "
                "au prochain lancement de l'app."));
      }
    } catch (e) {
      debugPrint('AppleIapService._deliver: $e');
      _finishUi(const AppleIapEvent(AppleIapEventType.error,
          message: "Paiement reçu, mais la validation a échoué. Tes pièces seront créditées automatiquement "
              "au prochain lancement de l'app."));
    }
  }

  Future<void> _complete(PurchaseDetails purchase) async {
    if (purchase.pendingCompletePurchase) {
      try {
        await _iap.completePurchase(purchase);
      } catch (e) {
        debugPrint('AppleIapService.completePurchase: $e');
      }
    }
  }

  void _finishUi(AppleIapEvent event) {
    purchasingProductId = null;
    notifyListeners();
    _events.add(event);
  }
}
