
// services/pronostic_payment_service.dart


import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../models/model_data.dart';
import '../pages/widgetGlobal.dart';
import '../providers/authProvider.dart';

enum TypeTransaction {
  DEPENSE,
  GAIN,
  RECHARGE,
}

class PronosticPaymentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Vérifier le solde de l'utilisateur
  Future<double> getSoldeUtilisateur(String userId) async {
    try {
      final doc = await _firestore.collection('Users').doc(userId).get();
      return (doc.data()?['votre_solde_principal'] ?? 0).toDouble();
    } catch (e) {
      print('Erreur récupération solde: $e');
      return 0.0;
    }
  }

  // Débiter l'utilisateur de façon sécurisée
  Future<bool> debiterUtilisateur({
    required String userId,
    required double montant,
    required String raison,
    required String postId,
    required String pronosticId,
  }) async {
    // Utiliser une transaction Firestore pour garantir l'atomicité
    try {
      return await _firestore.runTransaction<bool>((transaction) async {
        // 1. Récupérer l'utilisateur
        DocumentReference userRef = _firestore.collection('Users').doc(userId);
        DocumentSnapshot userSnapshot = await transaction.get(userRef);

        if (!userSnapshot.exists) {
          throw Exception('Utilisateur non trouvé');
        }

        double soldeActuel = (userSnapshot.get('votre_solde_principal') ?? 0).toDouble();

        // 2. Vérifier le solde
        if (soldeActuel < montant) {
          return false; // Solde insuffisant
        }

        // 3. Débiter l'utilisateur
        transaction.update(userRef, {
          'votre_solde_principal': soldeActuel - montant,
        });

        // 4. Créditer le solde de l'application (cagnotte)
        String appDataId = await _getAppDataId();
        DocumentReference appDataRef = _firestore.collection('AppData').doc(appDataId);

        transaction.set(appDataRef, {
          'solde_gain': FieldValue.increment(montant),
        }, SetOptions(merge: true));

        // 5. Créer la transaction pour l'historique
        await _createTransaction(
          TypeTransaction.DEPENSE.name,
          montant,
          raison,
          userId,
          postId: postId,
          pronosticId: pronosticId,
        );

        return true;
      });
    } catch (e) {
      print('Erreur lors du débit: $e');
      return false;
    }
  }

  // Créditer les gagnants
  Future<bool> crediterGagnants({
    required Pronostic pronostic,
    required List<String> gagnantsIds,
    required double montantParGagnant,
    required UserAuthProvider authProvider, // ✅
  }) async {
    try {
      bool success = await _firestore.runTransaction<bool>((transaction) async {
        String appDataId = await _getAppDataId();
        DocumentReference appDataRef = _firestore.collection('AppData').doc(appDataId);

        DocumentSnapshot appDataSnapshot = await transaction.get(appDataRef);
        double soldeApp = (appDataSnapshot.get('solde_gain') ?? 0).toDouble();

        double totalADebiter = montantParGagnant * gagnantsIds.length;

        // if (soldeApp < totalADebiter) {
        //   throw Exception('Fonds insuffisants dans l\'application');
        // }

        for (String userId in gagnantsIds) {
          DocumentReference userRef = _firestore.collection('Users').doc(userId);
          DocumentSnapshot userSnapshot = await transaction.get(userRef);

          if (userSnapshot.exists) {
            double soldeActuel = (userSnapshot.get('votre_solde_principal') ?? 0).toDouble();

            transaction.update(userRef, {
              'votre_solde_principal': soldeActuel + montantParGagnant,
            });

            await _createTransaction(
              TypeTransaction.GAIN.name,
              montantParGagnant,
              'Gain pronostic: ${pronostic.equipeA.nom} vs ${pronostic.equipeB.nom}',
              userId,
              postId: pronostic.postId,
              pronosticId: pronostic.id,
            );
          }
        }

        // transaction.update(appDataRef, {
        //   'solde_gain': soldeApp - totalADebiter,
        // });

        return true;
      });

      // 🔥 Envoi notification après succès
      if (success) {
        final message =
            "🎉 Félicitations ! Vous faites partie des gagnants du pronostic ⚽\n"
            "💰 Votre compte a été crédité de ${montantParGagnant.toStringAsFixed(0)} FCFA.\n"
            "🚀 Continuez à jouer sur AfroLook !";

        await authProvider.sendPushToSpecificUsers(
          userIds: gagnantsIds,
          sender: authProvider.loginUserData,
          message: message,
          typeNotif: NotificationType.POST.name,
          postId: pronostic.postId,
          postType: 'PRONOSTIC',
          chatId: '',
        );
      }

      return success;
    } catch (e) {
      print('Erreur lors du crédit des gains: $e');
      return false;
    }
  }

  // Récupérer l'ID de AppData
  Future<String> _getAppDataId() async {
    // À adapter selon votre logique
    // Peut-être stocké dans authProvider ou ailleurs
    return appId; // À remplacer
  }

  // Créer une transaction dans l'historique
  Future<void> _createTransaction(
      String type,
      double montant,
      String raison,
      String userId, {
        String? postId,
        String? pronosticId,
      }) async {
    try {
      await _firestore.collection('TransactionSoldes').add({
        'user_id': userId,
        'montant': montant,
        'type': type,
        'description': raison,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'statut': StatutTransaction.VALIDER.name,
      });
    } catch (e) {
      print('Erreur création transaction: $e');
    }
  }

  // Vérifier si un utilisateur peut participer
  Future<Map<String, dynamic>> verifierParticipation({
    required String userId,
    required Pronostic pronostic,
    required int scoreA,
    required int scoreB,
  }) async {
    // 1. Vérifier si le pronostic est ouvert
    if (!pronostic.estOuvert) {
      return {
        'peutParticiper': false,
        'raison': 'Ce pronostic n\'est plus ouvert aux participations',
      };
    }

    // 2. Vérifier si l'utilisateur a déjà participé
    if (pronostic.aDejaParticipe(userId)) {
      return {
        'peutParticiper': false,
        'raison': 'Vous avez déjà participé à ce pronostic',
      };
    }

    // 3. Vérifier le quota pour ce score
    if (!pronostic.isScoreDisponible(scoreA, scoreB)) {
      return {
        'peutParticiper': false,
        'raison': 'Ce score a atteint le quota maximum de ${pronostic.quotaMaxParScore} participants',
      };
    }

    // 4. Si c'est payant, vérifier le solde
    if (pronostic.typeAcces == 'PAYANT') {
      double solde = await getSoldeUtilisateur(userId);
      if (solde < pronostic.prixParticipation) {
        return {
          'peutParticiper': false,
          'raison': 'Solde insuffisant (${solde.toStringAsFixed(0)} FCFA / ${pronostic.prixParticipation.toStringAsFixed(0)} FCFA)',
          'soldeActuel': solde,
          'prixRequis': pronostic.prixParticipation,
        };
      }
    }

    return {
      'peutParticiper': true,
      'raison': 'OK',
    };
  }
}