// services/retraitService.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/model_data.dart';
import '../models/payment_config.dart';

class RetraitService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collectionRetraits = 'TransactionRetraits';
  static const String _collectionUsers = 'Users';

  /// 🎯 Faire une demande de retrait
  static Future<bool> demanderRetrait({
    required String userId,
    required double montant,
    required String methodPaiement,
    required String numeroCompte,
    required String countryCode,
    required UserData userData,
  }) async {
    try {
      // Vérifier le solde
      if (userData.votre_solde_principal! < montant) {
        throw Exception('Solde insuffisant');
      }

      if (montant <= 0) {
        throw Exception('Montant invalide');
      }

      // Créer la transaction de retrait
      final transactionData = TransactionRetrait(
        userId: userId,
        userPseudo: userData.pseudo,
        userEmail: userData.email,
        userPhone: userData.numeroDeTelephone,
        montant: montant,
        methodPaiement: methodPaiement,
        numeroCompte: numeroCompte,
        countryCode: countryCode,
        description: 'Retrait $methodPaiement - $numeroCompte ($countryCode)',
        numeroTransaction: _generateTransactionNumber(),
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );

      // Utiliser une transaction Firestore pour garantir l'intégrité
      await _firestore.runTransaction((transaction) async {
        // 1. Bloquer le montant du retrait
        final userRef = _firestore.collection(_collectionUsers).doc(userId);
        final userDoc = await transaction.get(userRef);

        final currentBalance = (userDoc.get('votre_solde_principal') ?? 0.0).toDouble();
        if (currentBalance < montant) {
          throw Exception('Solde insuffisant pendant la transaction');
        }

        // Mettre à jour le solde
        transaction.update(userRef, {
          'votre_solde_principal': currentBalance - montant,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        });

        // 2. Enregistrer la demande de retrait
        final retraitRef = _firestore.collection(_collectionRetraits).doc();
        transaction.set(retraitRef, transactionData.toJson());
      });

      print('✅ Demande de retrait créée: $montant FCFA pour $countryCode');
      return true;
    } catch (e) {
      print('❌ Erreur demande retrait: $e');
      return false;
    }
  }

  /// 🔄 Valider un retrait (Admin)
  static Future<bool> validerRetrait({
    required String retraitId,
    required String adminId,
  }) async {
    try {
      await _firestore
          .collection(_collectionRetraits)
          .doc(retraitId)
          .update({
        'statut': 'VALIDER',
        'processed_by': adminId,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      });

      print('✅ Retrait validé: $retraitId');
      return true;
    } catch (e) {
      print('❌ Erreur validation retrait: $e');
      return false;
    }
  }

  /// 🚫 Annuler un retrait (Admin)
  static Future<bool> annulerRetrait({
    required String retraitId,
    required String adminId,
    required String motif,
  }) async {
    try {
      final retraitDoc = await _firestore
          .collection(_collectionRetraits)
          .doc(retraitId)
          .get();

      if (!retraitDoc.exists) {
        throw Exception('Transaction non trouvée');
      }

      final retrait = TransactionRetrait.fromJson(retraitDoc.data()!);

      await _firestore.runTransaction((transaction) async {
        final userRef = _firestore.collection(_collectionUsers).doc(retrait.userId);
        final userDoc = await transaction.get(userRef);

        final currentBalance = (userDoc.get('votre_solde_principal') ?? 0.0).toDouble();

        transaction.update(userRef, {
          'votre_solde_principal': currentBalance + retrait.montant!,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        });

        transaction.update(retraitDoc.reference, {
          'statut': 'ANNULE',
          'motif_annulation': motif,
          'processed_by': adminId,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        });
      });

      print('✅ Retrait annulé et solde remboursé: $retraitId');
      return true;
    } catch (e) {
      print('❌ Erreur annulation retrait: $e');
      return false;
    }
  }

  /// 📊 Récupérer les retraits d'un utilisateur
  static Stream<List<TransactionRetrait>> getRetraitsUtilisateur(String userId) {
    return _firestore
        .collection(_collectionRetraits)
        .where('user_id', isEqualTo: userId)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return TransactionRetrait.fromJson(data);
    })
        .toList());
  }

  /// 🔍 Récupérer les retraits par email (Admin)
  static Stream<List<TransactionRetrait>> searchRetraitsByEmail(String email) {
    return _firestore
        .collection(_collectionRetraits)
        .where('user_email', isEqualTo: email)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return TransactionRetrait.fromJson(data);
    })
        .toList());
  }

  /// 👑 Récupérer tous les retraits (Admin)
  static Stream<List<TransactionRetrait>> getAllRetraits() {
    return _firestore
        .collection(_collectionRetraits)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return TransactionRetrait.fromJson(data);
    })
        .toList());
  }

  /// 🔢 Générer un numéro de transaction unique
  static String _generateTransactionNumber() {
    final now = DateTime.now();
    return 'RET${now.millisecondsSinceEpoch}';
  }
}