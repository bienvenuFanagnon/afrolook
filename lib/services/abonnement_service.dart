// services/abonnement_service.dart

import 'package:afrotok/pages/component/consoleWidget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/model_data.dart';
import '../providers/authProvider.dart';


class AbonnementService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ── Souscription générique (appelée par la page abonnement) ──────────────

  Future<Map<String, dynamic>> souscrire({
    required String planType, // 'premium' | 'gold'
    required int dureeMois,
    required UserData user,
    required BuildContext context,
  }) async {
    if (planType == 'gold') {
      return souscrireGold(dureeMois: dureeMois, user: user, context: context);
    }
    return souscrirePremium(dureeMois: dureeMois, user: user, context: context);
  }

  // ── Souscription Premium ──────────────────────────────────────────────────

  Future<Map<String, dynamic>> souscrirePremium({
    required int dureeMois,
    required UserData user,
    required BuildContext context,
  }) async {
    try {
      if (user.abonnement?.estPremium == true) {
        throw Exception('Vous avez déjà un abonnement actif');
      }

      final nouvelAbonnement = AfrolookAbonnement.premium(dureeMois: dureeMois);
      return await _processerSouscription(
        nouvelAbonnement: nouvelAbonnement,
        user: user,
        context: context,
        sousType: 'ABONNEMENT_PREMIUM',
        descriptionLabel: 'Premium',
      );
    } catch (e) {
      printVm('Erreur souscription Premium: $e');
      rethrow;
    }
  }

  // ── Souscription Gold ─────────────────────────────────────────────────────

  Future<Map<String, dynamic>> souscrireGold({
    required int dureeMois,
    required UserData user,
    required BuildContext context,
  }) async {
    try {
      if (user.abonnement?.estGold == true) {
        throw Exception('Vous avez déjà un abonnement Gold actif');
      }

      final nouvelAbonnement = AfrolookAbonnement.gold(dureeMois: dureeMois);
      return await _processerSouscription(
        nouvelAbonnement: nouvelAbonnement,
        user: user,
        context: context,
        sousType: 'ABONNEMENT_GOLD',
        descriptionLabel: 'Gold',
      );
    } catch (e) {
      printVm('Erreur souscription Gold: $e');
      rethrow;
    }
  }

  // ── Logique commune de paiement ───────────────────────────────────────────

  Future<Map<String, dynamic>> _processerSouscription({
    required AfrolookAbonnement nouvelAbonnement,
    required UserData user,
    required BuildContext context,
    required String sousType,
    required String descriptionLabel,
  }) async {
    final prixTotal = nouvelAbonnement.prix;
    final solde = user.votre_solde_depot ?? 0.0;

    if (solde < prixTotal) {
      return {
        'success': false,
        'message': 'Solde de dépôt insuffisant (${prixTotal.toStringAsFixed(0)} FCFA requis)',
        'soldeManquant': prixTotal - solde,
      };
    }

    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final nouveauSolde = solde - prixTotal;

    await _firestore.collection('Users').doc(user.id).update({
      'votre_solde_depot': nouveauSolde,
      'abonnement': nouvelAbonnement.toJson(),
    });

    await _firestore
        .collection('AppData')
        .doc(authProvider.appDefaultData.id)
        .update({'solde_gain': FieldValue.increment(prixTotal)});

    await _enregistrerTransaction(
      userId: user.id!,
      montant: prixTotal,
      dureeMois: nouvelAbonnement.dureeMois,
      sousType: sousType,
      descriptionLabel: descriptionLabel,
    );

    return {
      'success': true,
      'message': 'Abonnement $descriptionLabel activé avec succès !',
      'abonnement': nouvelAbonnement,
    };
  }

  // ── Vérification expiration ───────────────────────────────────────────────

  Future<void> verifierEtMettreAJourAbonnement(String userId) async {
    try {
      final userDoc = await _firestore.collection('Users').doc(userId).get();
      final userData = userDoc.data();
      if (userData == null || userData['abonnement'] == null) return;

      final abonnement = AfrolookAbonnement.fromJson(
          Map<String, dynamic>.from(userData['abonnement']));

      // Seule cette fonction est autorisée à remettre le plan à 'gratuit' dans Firestore.
      if (abonnement.estExpire) {
        final gratuit = AfrolookAbonnement.gratuit();
        await _firestore.collection('Users').doc(userId).update({
          'abonnement': gratuit.toJson(),
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        });
        printVm('✅ Abonnement expiré remis à gratuit pour $userId');
      }
    } catch (e) {
      printVm('❌ Erreur vérification abonnement: $e');
    }
  }

  // ── Enregistrement transaction ────────────────────────────────────────────

  Future<void> _enregistrerTransaction({
    required String userId,
    required double montant,
    required int dureeMois,
    required String sousType,
    required String descriptionLabel,
  }) async {
    try {
      final ref = _firestore.collection('TransactionSoldes').doc();
      final now = DateTime.now();
      await ref.set({
        'id': ref.id,
        'user_id': userId,
        'type': TypeTransaction.DEPENSE.name,
        'statut': 'VALIDER',
        'description': 'Abonnement $descriptionLabel $dureeMois mois - $montant FCFA',
        'montant': montant,
        'montant_total': montant,
        'numero_depot': null,
        'methode_paiement': 'SOLDE',
        'frais': 0,
        'frais_operateur': 0,
        'frais_gain': 0,
        'id_transaction_paygate': null,
        'sous_type': sousType,
        'duree_mois': dureeMois,
        'createdAt': now.millisecondsSinceEpoch,
        'updatedAt': now.millisecondsSinceEpoch,
        'reference': 'ABON_${now.millisecondsSinceEpoch}',
      });
      printVm('✅ Transaction $descriptionLabel enregistrée — $dureeMois mois');
    } catch (e) {
      printVm('❌ Erreur transaction abonnement: $e');
      throw Exception('Échec enregistrement transaction');
    }
  }

  // ── Helpers statiques ─────────────────────────────────────────────────────

  static double getPrixAbonnement(int dureeMois) =>
      AfrolookAbonnement.calculerPrix(dureeMois);

  static double getPrixGold(int dureeMois) =>
      AfrolookAbonnement.calculerPrixGold(dureeMois);
}