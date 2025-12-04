// services/abonnement_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/model_data.dart';
import '../providers/authProvider.dart';


class AbonnementService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Souscrire à un abonnement premium
  Future<Map<String, dynamic>> souscrirePremium({
    required int dureeMois,
    required UserData user,
    required BuildContext context,

  })
  async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('Utilisateur non connecté');

      // Vérifier si un abonnement premium est déjà actif
      if (user.abonnement?.estPremium == true) {
        throw Exception('Vous avez déjà un abonnement premium actif');
      }

      // Créer le nouvel abonnement
      final nouvelAbonnement = AfrolookAbonnement.premium(
        dureeMois: dureeMois,
      );

      // Calculer le prix
      final prixTotal = nouvelAbonnement.prix;

      // Vérifier le solde
      if (user.votre_solde_principal == null ||
          user.votre_solde_principal! < prixTotal) {
        return {
          'success': false,
          'message': 'Solde insuffisant',
          'soldeManquant': prixTotal - (user.votre_solde_principal ?? 0),
        };
      }

      // Déduire du solde
      final nouveauSolde = user.votre_solde_principal! - prixTotal;
      late UserAuthProvider authProvider =
      Provider.of<UserAuthProvider>(context, listen: false);
      // Mettre à jour l'utilisateur dans Firestore
      await _firestore.collection('Users').doc(userId).update({
        'votre_solde_principal': nouveauSolde,
        'abonnement': nouvelAbonnement.toJson(),
        // 'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
      await _firestore.collection('AppData').doc(authProvider.appDefaultData.id).update({
        'solde_gain': FieldValue.increment(prixTotal),
      });
      // Enregistrer la transaction
      await _enregistrerTransaction(
        userId: userId,
        montant: prixTotal,
        dureeMois: dureeMois,
      );

      return {
        'success': true,
        'message': 'Abonnement premium activé avec succès!',
        'abonnement': nouvelAbonnement,
      };

    } catch (e) {
      print('Erreur souscription: $e');
      rethrow;
    }
  }

  // Vérifier et mettre à jour l'abonnement expiré
  Future<void> verifierEtMettreAJourAbonnement(String userId) async {
    try {
      final userDoc = await _firestore.collection('Users').doc(userId).get();
      final userData = userDoc.data();

      if (userData != null && userData['abonnement'] != null) {
        final abonnement = AfrolookAbonnement.fromJson(
            Map<String, dynamic>.from(userData['abonnement']));

        // Si l'abonnement est expiré, le modèle le convertira automatiquement en gratuit
        // lors de fromJson(), mais nous devons sauvegarder le changement
        if (abonnement.estExpire) {
          await _firestore.collection('Users').doc(userId).update({
            'abonnement': abonnement.toJson(),
            'updatedAt': DateTime.now().millisecondsSinceEpoch,
          });
        }
      }
    } catch (e) {
      print('Erreur vérification abonnement: $e');
    }
  }


// Version simplifiée pour paiement par solde
  Future<void> _enregistrerTransaction({
    required String userId,
    required double montant,
    required int dureeMois,
  }) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final transactionRef = firestore.collection("TransactionSoldes").doc();
      final maintenant = DateTime.now();

      await transactionRef.set({
        "id": transactionRef.id,
        "user_id": userId,
        "type": TypeTransaction.DEPENSE.name,
        "statut": "VALIDER",
        "description": "Abonnement Premium $dureeMois mois - $montant FCFA",
        "montant": montant,
        "montant_total": montant,
        "numero_depot": null,
        "methode_paiement": "SOLDE",
        "frais": 0,
        "frais_operateur": 0,
        "frais_gain": 0,
        "id_transaction_paygate": null,
        "sous_type": "ABONNEMENT_PREMIUM",
        "duree_mois": dureeMois,
        "createdAt": maintenant.millisecondsSinceEpoch,
        "updatedAt": maintenant.millisecondsSinceEpoch,
        "reference": "ABON_${maintenant.millisecondsSinceEpoch}",
      });

      print("✅ Transaction abonnement enregistrée pour $dureeMois mois");

    } catch (e) {
      print("❌ Erreur transaction abonnement: $e");
      throw Exception("Échec enregistrement transaction");
    }
  }
  // Obtenir le prix d'un abonnement
  static double getPrixAbonnement(int dureeMois) {
    return AfrolookAbonnement.calculerPrix(dureeMois);
  }
}