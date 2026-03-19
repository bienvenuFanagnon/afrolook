
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
        String? appDataId = await _getAppDataId();
        DocumentReference appDataRef = _firestore.collection('AppData').doc(appDataId!);

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
    required UserAuthProvider authProvider,
  }) async {
    try {
      // ✅ 1. Vérification
      if (gagnantsIds.isEmpty) {
        print('Aucun gagnant à créditer');
        return false;
      }

      // 🔹 Supprimer doublons
      final uniqueIds = gagnantsIds.toSet().toList();

      // ✅ 2. TRANSACTION (UNIQUEMENT FIRESTORE)
      bool success = await _firestore.runTransaction<bool>((transaction) async {
        for (String userId in uniqueIds) {
          if (userId.isEmpty) continue;

          DocumentReference userRef =
          _firestore.collection('Users').doc(userId);

          // 🔥 Pas besoin de get → on utilise increment (safe)
          transaction.update(userRef, {
            'votre_solde_principal':
            FieldValue.increment(montantParGagnant),
          });
        }

        return true;
      });

      if (!success) return false;

      print("✅ Soldes crédités avec succès");

      // ✅ 3. CRÉER LES TRANSACTIONS (hors transaction Firestore)
      await Future.wait(
        uniqueIds.map((userId) => _createTransaction(
          TypeTransaction.GAIN.name,
          montantParGagnant,
          'Gain pronostic: ${pronostic.equipeA.nom} vs ${pronostic.equipeB.nom}',
          userId,
          postId: pronostic.postId,
          pronosticId: pronostic.id,
        )),
      );

      print("✅ Transactions enregistrées");

      // ✅ 4. ENVOI NOTIFICATION
      final message =
          "🎉 Félicitations ! Vous faites partie des gagnants du pronostic ⚽\n"
          "💰 Votre compte a été crédité de ${montantParGagnant.toStringAsFixed(0)} FCFA.\n"
          "🚀 Continuez à jouer sur AfroLook !";

      await authProvider.sendPushToSpecificUsers(
        userIds: uniqueIds,
        sender: authProvider.loginUserData,
        message: message,
        typeNotif: NotificationType.GAIN.name,
        postId: pronostic.postId,
        postType: 'PRONOSTIC',
        chatId: '',
      );

      print("✅ Notifications envoyées");

      return true;
    } catch (e, stack) {
      print('❌ Erreur lors du crédit des gains: $e');
      print('Stack trace: $stack');
      return false;
    }
  }

// ✅ Améliorer _getAppDataId()
  Future<String?> _getAppDataId() async {
    try {
      var snapshot = await _firestore.collection('AppData').limit(1).get();
      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.first.id;
      }
      return null;
    } catch (e) {
      print('Erreur dans _getAppDataId: $e');
      return null;
    }
  }
  // Créditer les gagnants
  Future<bool> crediterGagnants2({
    required Pronostic pronostic,
    required List<String> gagnantsIds,
    required double montantParGagnant,
    required UserAuthProvider authProvider, // ✅
  }) async {
    try {
      bool success = await _firestore.runTransaction<bool>((transaction) async {
        // String appDataId = await _getAppDataId();
        // DocumentReference appDataRef = _firestore.collection('AppData').doc(appDataId);
        //
        // DocumentSnapshot appDataSnapshot = await transaction.get(appDataRef);
        // double soldeApp = (appDataSnapshot.get('solde_gain') ?? 0).toDouble();
        //
        // double totalADebiter = montantParGagnant * gagnantsIds.length;

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

         authProvider.sendPushToSpecificUsers(
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
  Future<String> _getAppDataId2() async {
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