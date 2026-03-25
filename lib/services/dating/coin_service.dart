// lib/services/coin_service.dart
import 'package:afrotok/pages/widgetGlobal.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/dating_data.dart';
import '../../models/enums.dart';
import '../../models/model_data.dart';
import '../../providers/authProvider.dart';

class CoinService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final UserAuthProvider? authProvider;

  CoinService({this.authProvider});

  // Récupérer l'utilisateur connecté depuis le provider
  UserData? get _currentUser => authProvider?.loginUserData;
  String? get _currentUserId => _currentUser?.id;

  // Acheter des pièces
  Future<bool> buyCoins(CoinPackage package) async {
    try {
      final userId = _currentUserId;
      if (userId == null) throw Exception('Utilisateur non connecté');

      print('📱 Achat de pièces pour l\'utilisateur: $userId');
      print('📦 Pack: ${package.name} - ${package.coinsAmount} pièces - ${package.priceXof} FCFA');

      final userDoc = await _firestore.collection('Users').doc(userId).get();
      final userData = UserData.fromJson(userDoc.data() ?? {});

      // Vérifier si l'utilisateur a assez de solde
      if ((userData.votre_solde_principal ?? 0) < package.priceXof) {
        print('❌ Solde insuffisant: ${userData.votre_solde_principal} < ${package.priceXof}');
        throw Exception('Solde insuffisant');
      }

      return await _firestore.runTransaction((transaction) async {
        // 1. Déduire le solde principal
        final newPrincipalBalance = (userData.votre_solde_principal ?? 0) - package.priceXof;
        transaction.update(
          _firestore.collection('Users').doc(userId),
          {'votre_solde_principal': newPrincipalBalance},
        );
        print('💰 Solde principal déduit: $newPrincipalBalance FCFA');

        // 2. Créer la transaction d'achat
        final transactionId = _firestore.collection('user_coin_transactions').doc().id;
        final coinTransaction = UserCoinTransaction(
          id: transactionId,
          userId: userId,
          type: CoinTransactionType.buy_coins,
          coinsAmount: package.coinsAmount,
          xofAmount: package.priceXof,
          referenceId: package.id,
          description: 'Achat de ${package.coinsAmount} pièces',
          status: TransactionStatus.success,
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        );
        transaction.set(
          _firestore.collection('user_coin_transactions').doc(transactionId),
          coinTransaction.toJson(),
        );
        print('✅ Transaction d\'achat créée: $transactionId');

        // 3. Ajouter les pièces au portefeuille utilisateur
        final newCoinsBalance = (userData.coinsBalance ?? 0) + package.coinsAmount;
        transaction.update(
          _firestore.collection('Users').doc(userId),
          {
            'coinsBalance': newCoinsBalance,
            'totalCoinsPurchased': (userData.totalCoinsPurchased ?? 0) + package.coinsAmount,
          },
        );
        print('🎁 ${package.coinsAmount} pièces ajoutées. Nouveau solde: $newCoinsBalance');

        return true;
      });
    } catch (e) {
      print('❌ Erreur lors de l\'achat de pièces: $e');
      return false;
    }
  }

  // Dépenser des pièces
  Future<bool> spendCoins({
    required String userId,
    required int amount,
    required CoinTransactionType type,
    required String referenceId,
    required String description,
  }) async {
    try {
      if (userId != _currentUserId) {
        print('⚠️ Tentative de dépense pour un autre utilisateur');
      }

      final userDoc = await _firestore.collection('Users').doc(userId).get();
      final userData = UserData.fromJson(userDoc.data() ?? {});

      if ((userData.coinsBalance ?? 0) < amount) {
        print('❌ Solde de pièces insuffisant: ${userData.coinsBalance} < $amount');
        throw Exception('Solde de pièces insuffisant');
      }

      return await _firestore.runTransaction((transaction) async {
        // 1. Déduire les pièces
        final newCoinsBalance = (userData.coinsBalance ?? 0) - amount;
        transaction.update(
          _firestore.collection('Users').doc(userId),
          {
            'coinsBalance': newCoinsBalance,
            'totalCoinsSpent': (userData.totalCoinsSpent ?? 0) + amount,
          },
        );
        print('💰 $amount pièces déduites. Nouveau solde: $newCoinsBalance');

        // 2. Créer la transaction de dépense
        final transactionId = _firestore.collection('user_coin_transactions').doc().id;
        final coinTransaction = UserCoinTransaction(
          id: transactionId,
          userId: userId,
          type: type,
          coinsAmount: -amount, // Négatif pour dépense
          xofAmount: amount * 2.5, // 1 pièce = 2.5 FCFA
          referenceId: referenceId,
          description: description,
          status: TransactionStatus.success,
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        );
        transaction.set(
          _firestore.collection('user_coin_transactions').doc(transactionId),
          coinTransaction.toJson(),
        );
        print('✅ Transaction de dépense créée: $transactionId');

        return true;
      });
    } catch (e) {
      print('❌ Erreur lors de la dépense de pièces: $e');
      return false;
    }
  }

  // Dépenser des pièces pour l'utilisateur connecté
  Future<bool> spendCoinsForCurrentUser({
    required int amount,
    required CoinTransactionType type,
    required String referenceId,
    required String description,
  }) async {
    final userId = _currentUserId;
    if (userId == null) {
      print('❌ Utilisateur non connecté');
      return false;
    }
    return spendCoins(
      userId: userId,
      amount: amount,
      type: type,
      referenceId: referenceId,
      description: description,
    );
  }

  // Créditer un créateur
  Future<bool> creditCreator({
    required String creatorId,
    required int amount,
    required CoinTransactionType type,
    required String referenceId,
    required String description,
  }) async {
    try {
      print('📱 Crédit du créateur: $creatorId - $amount pièces');

      return await _firestore.runTransaction((transaction) async {
        // 1. Récupérer ou créer le wallet du créateur
        final walletQuery = await _firestore
            .collection('creator_coin_wallets')
            .where('creatorId', isEqualTo: creatorId)
            .limit(1)
            .get();

        CreatorCoinWallet wallet;
        if (walletQuery.docs.isEmpty) {
          // Créer un nouveau wallet
          wallet = CreatorCoinWallet(
            id: _firestore.collection('creator_coin_wallets').doc().id,
            creatorId: creatorId,
            userId: creatorId,
            balanceCoins: amount,
            totalEarnedCoins: amount,
            totalConvertedCoins: 0,
            createdAt: DateTime.now().millisecondsSinceEpoch,
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          );
          transaction.set(
            _firestore.collection('creator_coin_wallets').doc(wallet.id),
            wallet.toJson(),
          );
          print('✅ Nouveau wallet créé pour $creatorId');
        } else {
          wallet = CreatorCoinWallet.fromJson(walletQuery.docs.first.data());
          final newBalance = wallet.balanceCoins + amount;
          final newTotalEarned = wallet.totalEarnedCoins + amount;
          transaction.update(
            _firestore.collection('creator_coin_wallets').doc(wallet.id),
            {
              'balanceCoins': newBalance,
              'totalEarnedCoins': newTotalEarned,
              'updatedAt': DateTime.now().millisecondsSinceEpoch,
            },
          );
          print('💰 Wallet mis à jour: ${wallet.balanceCoins} → $newBalance');
        }

        // 2. Créer la transaction
        final transactionId = _firestore.collection('user_coin_transactions').doc().id;
        final coinTransaction = UserCoinTransaction(
          id: transactionId,
          userId: creatorId,
          type: type,
          coinsAmount: amount,
          xofAmount: amount * 2.5,
          referenceId: referenceId,
          description: description,
          status: TransactionStatus.success,
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        );
        transaction.set(
          _firestore.collection('user_coin_transactions').doc(transactionId),
          coinTransaction.toJson(),
        );
        print('✅ Transaction de crédit créée: $transactionId');

        return true;
      });
    } catch (e) {
      print('❌ Erreur lors du crédit du créateur: $e');
      return false;
    }
  }

  // Convertir des pièces en FCFA pour un créateur
  Future<bool> convertCoinsToXof({
    required String creatorId,
    required int amount,
  }) async {
    try {
      print('📱 Conversion de $amount pièces en FCFA pour $creatorId');

      final appDataDoc = await _firestore.collection('AppData').doc(appId).get();
      final appData = AppDefaultData.fromJson(appDataDoc.data() ?? {});

      final conversionRate = appData.tarifPubliCash_to_xof ?? 250.0; // 100 pièces = 250 FCFA
      final xofAmount = (amount / 100) * conversionRate;
      print('💰 Taux de conversion: 100 pièces = $conversionRate FCFA');
      print('💰 Montant converti: $xofAmount FCFA');

      return await _firestore.runTransaction((transaction) async {
        // 1. Récupérer le wallet du créateur
        final walletQuery = await _firestore
            .collection('creator_coin_wallets')
            .where('creatorId', isEqualTo: creatorId)
            .limit(1)
            .get();

        if (walletQuery.docs.isEmpty) {
          throw Exception('Wallet du créateur introuvable');
        }

        final wallet = CreatorCoinWallet.fromJson(walletQuery.docs.first.data());
        if (wallet.balanceCoins < amount) {
          print('❌ Solde insuffisant: ${wallet.balanceCoins} < $amount');
          throw Exception('Solde de pièces insuffisant');
        }

        // 2. Déduire les pièces du wallet
        final newBalance = wallet.balanceCoins - amount;
        final newTotalConverted = wallet.totalConvertedCoins + amount;
        transaction.update(
          _firestore.collection('creator_coin_wallets').doc(wallet.id),
          {
            'balanceCoins': newBalance,
            'totalConvertedCoins': newTotalConverted,
            'updatedAt': DateTime.now().millisecondsSinceEpoch,
          },
        );
        print('💰 Pièces déduites: ${wallet.balanceCoins} → $newBalance');

        // 3. Créer la demande de conversion
        final conversionId = _firestore.collection('creator_coin_conversions').doc().id;
        final conversion = CreatorCoinConversion(
          id: conversionId,
          creatorId: creatorId,
          userId: creatorId,
          coinsAmount: amount,
          xofAmount: xofAmount,
          conversionRate: conversionRate / 100,
          status: TransactionStatus.pending,
          requestedAt: DateTime.now().millisecondsSinceEpoch,
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        );
        transaction.set(
          _firestore.collection('creator_coin_conversions').doc(conversionId),
          conversion.toJson(),
        );
        print('✅ Demande de conversion créée: $conversionId');

        // 4. Ajouter au solde gain du créateur
        final userDoc = _firestore.collection('Users').doc(creatorId);
        transaction.update(userDoc, {
          'votre_solde_gain': FieldValue.increment(xofAmount),
        });
        print('💰 $xofAmount FCFA ajoutés au solde gain');

        return true;
      });
    } catch (e) {
      print('❌ Erreur lors de la conversion: $e');
      return false;
    }
  }

  // Convertir des pièces en FCFA pour le créateur connecté
  Future<bool> convertCoinsToXofForCurrentUser(int amount) async {
    final userId = _currentUserId;
    if (userId == null) {
      print('❌ Utilisateur non connecté');
      return false;
    }
    return convertCoinsToXof(creatorId: userId, amount: amount);
  }

  // Obtenir l'historique des transactions d'un utilisateur
  Future<List<UserCoinTransaction>> getUserTransactions(String userId) async {
    try {
      print('📱 Récupération des transactions pour $userId');
      final snapshot = await _firestore
          .collection('user_coin_transactions')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(100)
          .get();

      print('✅ ${snapshot.docs.length} transactions trouvées');
      return snapshot.docs
          .map((doc) => UserCoinTransaction.fromJson(doc.data()))
          .toList();
    } catch (e) {
      print('❌ Erreur lors de la récupération des transactions: $e');
      return [];
    }
  }

  // Obtenir l'historique des transactions de l'utilisateur connecté
  Future<List<UserCoinTransaction>> getCurrentUserTransactions() async {
    final userId = _currentUserId;
    if (userId == null) {
      print('❌ Utilisateur non connecté');
      return [];
    }
    return getUserTransactions(userId);
  }

  // Obtenir le wallet d'un créateur
  Future<CreatorCoinWallet?> getCreatorWallet(String creatorId) async {
    try {
      final snapshot = await _firestore
          .collection('creator_coin_wallets')
          .where('creatorId', isEqualTo: creatorId)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return CreatorCoinWallet.fromJson(snapshot.docs.first.data());
      }
      return null;
    } catch (e) {
      print('❌ Erreur récupération wallet: $e');
      return null;
    }
  }

  // Obtenir le wallet du créateur connecté
  Future<CreatorCoinWallet?> getCurrentCreatorWallet() async {
    final userId = _currentUserId;
    if (userId == null) return null;
    return getCreatorWallet(userId);
  }

  // Vérifier si un utilisateur a assez de pièces
  Future<bool> hasEnoughCoins(String userId, int requiredAmount) async {
    try {
      final userDoc = await _firestore.collection('Users').doc(userId).get();
      final userData = UserData.fromJson(userDoc.data() ?? {});
      final hasEnough = (userData.coinsBalance ?? 0) >= requiredAmount;
      print('💰 Vérification solde pour $userId: ${userData.coinsBalance} >= $requiredAmount → $hasEnough');
      return hasEnough;
    } catch (e) {
      print('❌ Erreur vérification solde: $e');
      return false;
    }
  }

  // Vérifier si l'utilisateur connecté a assez de pièces
  Future<bool> currentUserHasEnoughCoins(int requiredAmount) async {
    final userId = _currentUserId;
    if (userId == null) return false;
    return hasEnoughCoins(userId, requiredAmount);
  }
}