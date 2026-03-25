// lib/services/coin_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/dating_data.dart';
import '../../models/enums.dart';
import '../../models/model_data.dart';

class CoinService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Acheter des pièces
  Future<bool> buyCoins(CoinPackage package) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('Utilisateur non connecté');

      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = UserData.fromJson(userDoc.data() ?? {});

      // Vérifier si l'utilisateur a assez de solde
      if ((userData.votre_solde_principal ?? 0) < package.priceXof) {
        throw Exception('Solde insuffisant');
      }

      return await _firestore.runTransaction((transaction) async {
        // 1. Déduire le solde principal
        final newPrincipalBalance = (userData.votre_solde_principal ?? 0) - package.priceXof;
        transaction.update(
          _firestore.collection('users').doc(userId),
          {'votre_solde_principal': newPrincipalBalance},
        );

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

        // 3. Ajouter les pièces au portefeuille utilisateur
        final newCoinsBalance = (userData.coinsBalance ?? 0) + package.coinsAmount;
        transaction.update(
          _firestore.collection('users').doc(userId),
          {
            'coinsBalance': newCoinsBalance,
            'totalCoinsPurchased': (userData.totalCoinsPurchased ?? 0) + package.coinsAmount,
          },
        );

        return true;
      });
    } catch (e) {
      print('Erreur lors de l\'achat de pièces: $e');
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
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = UserData.fromJson(userDoc.data() ?? {});

      if ((userData.coinsBalance ?? 0) < amount) {
        throw Exception('Solde de pièces insuffisant');
      }

      return await _firestore.runTransaction((transaction) async {
        // 1. Déduire les pièces
        final newCoinsBalance = (userData.coinsBalance ?? 0) - amount;
        transaction.update(
          _firestore.collection('users').doc(userId),
          {
            'coinsBalance': newCoinsBalance,
            'totalCoinsSpent': (userData.totalCoinsSpent ?? 0) + amount,
          },
        );

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

        return true;
      });
    } catch (e) {
      print('Erreur lors de la dépense de pièces: $e');
      return false;
    }
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

        return true;
      });
    } catch (e) {
      print('Erreur lors du crédit du créateur: $e');
      return false;
    }
  }

  // Convertir des pièces en FCFA pour un créateur
  Future<bool> convertCoinsToXof({
    required String creatorId,
    required int amount,
  }) async {
    try {
      final appDataDoc = await _firestore.collection('app_default_data').doc('main').get();
      final appData = AppDefaultData.fromJson(appDataDoc.data() ?? {});

      final conversionRate = appData.tarifPubliCash_to_xof ?? 250.0; // 100 pièces = 250 FCFA
      final xofAmount = (amount / 100) * conversionRate;

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

        // 4. Ajouter au solde gain du créateur
        final userDoc = _firestore.collection('users').doc(creatorId);
        transaction.update(userDoc, {
          'votre_solde_gain': FieldValue.increment(xofAmount),
        });

        return true;
      });
    } catch (e) {
      print('Erreur lors de la conversion: $e');
      return false;
    }
  }

  // Obtenir l'historique des transactions d'un utilisateur
  Future<List<UserCoinTransaction>> getUserTransactions(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('user_coin_transactions')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(100)
          .get();

      return snapshot.docs
          .map((doc) => UserCoinTransaction.fromJson(doc.data()))
          .toList();
    } catch (e) {
      print('Erreur lors de la récupération des transactions: $e');
      return [];
    }
  }
}