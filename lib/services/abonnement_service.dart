// services/abonnement_service.dart

import 'package:afrotok/pages/component/consoleWidget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/model_data.dart';
import 'coin_checkout.dart';


class AbonnementService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ── Souscription générique (appelée par la page abonnement) ──────────────

  Future<Map<String, dynamic>> souscrire({
    required String planType, // 'premium' | 'gold'
    required int dureeMois,
    required UserData user,
    required BuildContext context,
    String balanceKey = 'votre_solde_depot',
  }) async {
    if (planType == 'gold') {
      return souscrireGold(dureeMois: dureeMois, user: user, context: context, balanceKey: balanceKey);
    }
    return souscrirePremium(dureeMois: dureeMois, user: user, context: context, balanceKey: balanceKey);
  }

  // ── Souscription Premium ──────────────────────────────────────────────────

  Future<Map<String, dynamic>> souscrirePremium({
    required int dureeMois,
    required UserData user,
    required BuildContext context,
    String balanceKey = 'votre_solde_depot',
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
        balanceKey: balanceKey,
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
    String balanceKey = 'votre_solde_depot',
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
        balanceKey: balanceKey,
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
    String balanceKey = 'votre_solde_depot',
  }) async {
    final prixTotal = nouvelAbonnement.prix;

    // Paiement en pièces (serveur) : la Cloud Function recalcule le prix, débite les pièces,
    // enregistre la transaction et la part de l'app. Le solde FCFA n'est plus utilisé.
    final planType = sousType == 'ABONNEMENT_GOLD' ? 'gold' : 'premium';
    final paid = await CoinCheckout.pay(
      context,
      kind: planType,
      priceFcfa: prixTotal,
      label: 'Abonnement $descriptionLabel — ${nouvelAbonnement.dureeMois} mois',
      dureeMois: nouvelAbonnement.dureeMois,
    );
    if (!paid) return {'success': false, 'message': '', 'cancelled': true};
    await _firestore.collection('Users').doc(user.id).update({
      'abonnement': nouvelAbonnement.toJson(),
    });
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

  // ── Helpers statiques ─────────────────────────────────────────────────────

  static double getPrixAbonnement(int dureeMois) =>
      AfrolookAbonnement.calculerPrix(dureeMois);

  static double getPrixGold(int dureeMois) =>
      AfrolookAbonnement.calculerPrixGold(dureeMois);
}