// providers/coin_gift_provider.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../models/coin_pack.dart';
import '../models/model_data.dart';
import '../services/coin_gift_service.dart';
import 'authProvider.dart';

// providers/coins/coin_gift_provider.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../models/model_data.dart';
import '../services/coin_gift_service.dart';
import 'authProvider.dart';

class CoinGiftUserProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  UserAuthProvider? _authProvider;
  UserData? _currentUser;

  // Constructeur avec authProvider optionnel
  CoinGiftUserProvider({UserAuthProvider? authProvider}) {
    _authProvider = authProvider;
    if (authProvider?.loginUserData != null) {
      _currentUser = authProvider!.loginUserData;
    }
  }

  UserData? get currentUser => _currentUser;

  // void setUser(UserData user) {
  //   _currentUser = user;
  //   notifyListeners();
  // }

  int get giftCoinsBalance => _currentUser?.giftCoinsBalance ?? 0;

  // Rafraîchir le solde et mettre à jour l'utilisateur dans authProvider
  Future<void> refreshBalance(String userId) async {
    final doc = await _firestore.collection('Users').doc(userId).get();
    if (doc.exists) {
      final updatedUser = UserData.fromJson(doc.data() as Map<String, dynamic>);
      _currentUser = updatedUser;

      // 🔥 METTRE À JOUR L'UTILISATEUR DANS AUTH PROVIDER
      if (_authProvider != null && _authProvider!.loginUserData?.id == userId) {
        _authProvider!.loginUserData = updatedUser;
      }

      notifyListeners();
    }
  }


  // providers/coin_gift_provider.dart

// Pour l'achat de pièces (supporte les deux cas)
  Future<bool> purchaseCoins({
    required String userPaid,      // Celui qui paie (utilisateur connecté)
    required String userReceived,  // Celui qui reçoit (peut être le même ou différent)
    required int coinsAmount,
    required double fcfaCost,
    required BuildContext context,
  }) async {
    try {
      await CoinGiftService.purchaseCoins(
        userPaid: userPaid,
        userReceived: userReceived,
        coinsAmount: coinsAmount,
        fcfaCost: fcfaCost,
        firestore: _firestore,
        authProvider: Provider.of<UserAuthProvider>(context, listen: false),
      );

      // Rafraîchir le solde du payeur
      await refreshBalance(userPaid);

      // Si différent, rafraîchir aussi le solde du receveur (optionnel)
      if (userPaid != userReceived) {
        await refreshBalance(userReceived);
      }

      return true;
    } catch (e) {
      debugPrint("Erreur achat pièces: $e");
      return false;
    }
  }

  // providers/coin_gift_provider.dart

  /// Envoyer un like avec des pièces (2 pièces: 1 pour le créateur, 1 pour l'application)
  /// Retourne un booléen indiquant si le like a été traité avec succès
  /// Si false, l'utilisateur a un solde insuffisant
  Future<bool> sendLikeWithCoins({
    required String senderId,
    required String receiverId,
    required Post post,
    required BuildContext context,
  }) async {
    try {
      final result = await CoinGiftService.sendLikeWithCoins(
        senderId: senderId,
        receiverId: receiverId,
        firestore: _firestore,
        authProvider: _authProvider!,
        post: post,
        context: context,
      );

      if (result) {
        // Rafraîchir le solde de l'utilisateur
        await refreshBalance(senderId);
        // await refreshFromAuth();
      }

      return result;
    } catch (e) {
      debugPrint("Erreur like avec pièces: $e");
      return false;
    }
  }
  // Acheter des pièces
  // Future<bool> purchaseCoins({
  //   required String userId,
  //   required int coinsAmount,
  //   required double fcfaCost,
  //   required BuildContext context,
  // })
  // async {
  //   try {
  //     await CoinGiftService.purchaseCoins(
  //       userId: userId,
  //       coinsAmount: coinsAmount,
  //       fcfaCost: fcfaCost,
  //       firestore: _firestore,
  //       authProvider: Provider.of<UserAuthProvider>(context, listen: false),
  //     );
  //     await refreshBalance(userId);
  //     return true;
  //   } catch (e) {
  //     debugPrint("Erreur achat pièces: $e");
  //     return false;
  //   }
  // }

  // providers/coin_gift_provider.dart

  /// Envoyer un cadeau
  Future<bool> sendGift({
    required String senderId,
    required String receiverId,
    required int coinsAmount,
    required Post post,
    required BuildContext context,
    required CoinPack giftPack,  // 🔥 NOUVEAU
    VoidCallback? onSuccess,
  }) async {
    try {
      final authProvider = Provider.of<UserAuthProvider>(context, listen: false);

      await CoinGiftService.sendGift(
        senderId: senderId,
        receiverId: receiverId,
        coinsAmount: coinsAmount,
        firestore: _firestore,
        authProvider: authProvider,
        post: post,
        context: context,
        giftPack: giftPack,  // 🔥 NOUVEAU
        onSuccess: onSuccess,
      );

      await refreshBalance(senderId);
      notifyListeners();

      return true;
    } catch (e) {
      debugPrint("Erreur envoi cadeau: $e");
      if (e.toString().contains('insuffisantes')) {
        return false;
      }
      rethrow;
    }
  }

  /// Récupérer les cadeaux d'un post (agrégés par type)
  Future<List<PostGift>> getPostGiftsAggregated(String postId) async {
    final snapshot = await _firestore
        .collection('PostGifts')
        .where('postId', isEqualTo: postId)
        .get();

    // Grouper par type de cadeau (icône + label)
    final Map<String, PostGift> aggregated = {};

    for (var doc in snapshot.docs) {
      final gift = PostGift.fromJson(doc.data());
      final key = '${gift.giftIcon}_${gift.giftLabel}_${gift.coinsAmount}';

      if (aggregated.containsKey(key)) {
        aggregated[key]!.quantity = (aggregated[key]!.quantity ?? 0) + 1;
        aggregated[key]!.totalCoins = (aggregated[key]!.totalCoins ?? 0) + (gift.coinsAmount ?? 0);
      } else {
        gift.quantity = 1;
        gift.totalCount = 1;
        gift.totalCoins = gift.coinsAmount;
        aggregated[key] = gift;
      }
    }

    return aggregated.values.toList();
  }

  /// Récupérer tous les cadeaux d'un post (non agrégés)
  Stream<List<PostGift>> getPostGiftsStream(String postId) {
    return _firestore
        .collection('PostGifts')
        .where('postId', isEqualTo: postId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => PostGift.fromJson(doc.data()))
        .toList());
  }

  // Envoyer un cadeau
  // Future<bool> sendGift({
  //   required String senderId,
  //   required String receiverId,
  //   required int coinsAmount,
  //   required Post post,
  //   required BuildContext context,
  //   VoidCallback? onSuccess,
  // }) async
  // {
  //   try {
  //     final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
  //
  //     await CoinGiftService.sendGift(
  //       senderId: senderId,
  //       receiverId: receiverId,
  //       coinsAmount: coinsAmount,
  //       firestore: _firestore,
  //       authProvider: authProvider,
  //       post: post,
  //       context: context,
  //       onSuccess: onSuccess,
  //     );
  //
  //     // 🔥 RAFRAÎCHIR LE SOLDE DE L'EXPÉDITEUR
  //     await refreshBalance(senderId);
  //
  //     // 🔥 FORCER LA MISE À JOUR DE L'UI
  //     notifyListeners();
  //
  //     return true;
  //   } catch (e) {
  //     debugPrint("Erreur envoi cadeau: $e");
  //     if (e.toString().contains('insuffisantes')) {
  //       return false;
  //     }
  //     rethrow;
  //   }
  // }

  // Recharger le provider depuis authProvider
  void refreshFromAuth() {
    if (_authProvider != null && _authProvider!.loginUserData != null) {
      _currentUser = _authProvider!.loginUserData;
      notifyListeners();
    }
  }
}