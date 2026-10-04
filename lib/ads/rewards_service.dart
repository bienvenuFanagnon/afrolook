import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../models/model_data.dart';
import '../services/utils/abonnement_utils.dart';
import 'ad_config.dart';

/// Une offre de la page Récompenses (le serveur reste seul juge : catalogue, plafonds, rôles).
class RewardOffer {
  final String id;
  final IconData icon;
  final String title; // texte français (clé de traduction)
  final String desc;
  final int ads;
  final int cap;
  final bool premium;
  final int hours; // durée du Premium (offres Premium)
  const RewardOffer(this.id, this.icon, this.title, this.desc, this.ads, this.cap, {this.premium = false, this.hours = 0});
}

class RewardsStatus {
  final int watched;
  final int pending;
  final Map<String, int> claims;
  const RewardsStatus(this.watched, this.pending, this.claims);
  static const empty = RewardsStatus(0, 0, {});
}

class RewardsService {
  RewardsService._();

  static const maxAdsPerDay = 10;

  static const offers = <RewardOffer>[
    RewardOffer('premium_5h', Icons.star_rounded, 'Premium 5 heures', 'Tout le Premium : photos multiples, live HD, stickers…', 2, 3, premium: true, hours: 5),
    RewardOffer('premium_10h', Icons.star_rounded, 'Premium 10 heures', 'Tout le Premium pendant 10 heures', 3, 3, premium: true, hours: 10),
    RewardOffer('premium_24h', Icons.workspace_premium_rounded, 'Premium 24 heures', 'Tout le Premium pendant un jour', 5, 2, premium: true, hours: 24),
    RewardOffer('adfree_24h', Icons.block_rounded, 'Une journée sans pub', '24 h sans publicité', 1, 2),
    RewardOffer('coins_2', Icons.monetization_on_rounded, '2 pièces cadeau', 'Pour offrir des cadeaux et liker', 1, 5),
    RewardOffer('flame_shield', Icons.local_fire_department_rounded, 'Bouclier de flamme', 'Protège ta série de commentaires une fois', 1, 1),
  ];

  /// La page et les pubs récompensées sont-elles proposées à cette personne ?
  /// (Gold : aucune pub et tout déjà débloqué ; admin : toujours, pour vérifier.)
  static bool available(UserData? u) {
    if (u == null || !AdConfig.isMobile) return false;
    final c = AdConfig.current;
    if (!c.enabled || !c.rewardsEnabled || c.unit('rewarded').isEmpty) return false;
    if (AbonnementUtils.isAdmin(u.role)) return true;
    return u.abonnement?.estGold != true;
  }

  /// Offres affichées selon le rôle : un vrai Premium (payé) ne voit pas les offres Premium.
  static List<RewardOffer> visibleOffers(UserData u) {
    if (AbonnementUtils.isAdmin(u.role)) return offers;
    final ab = u.abonnement;
    final paidPremium = ab?.estPremium == true && ab?.methodePaiement != 'pubs';
    return offers.where((o) => !(o.premium && paidPremium)).toList();
  }

  static String _utcDay() => DateTime.now().toUtc().toIso8601String().substring(0, 10).replaceAll('-', '');

  static Future<RewardsStatus> status(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('AdRewards').doc('${uid}_${_utcDay()}').get();
      final d = doc.data() ?? {};
      final claims = <String, int>{};
      final raw = d['claims'];
      if (raw is Map) raw.forEach((k, v) => claims['$k'] = (v as num).toInt());
      return RewardsStatus((d['adsWatched'] as num?)?.toInt() ?? 0, (d['pending'] as num?)?.toInt() ?? 0, claims);
    } catch (_) {
      return RewardsStatus.empty;
    }
  }

  /// Déclare une pub regardée (mode sans vérification AdMob). Retourne les pubs en réserve.
  static Future<int?> recordView() async {
    final res = await FirebaseFunctions.instance.httpsCallable('recordAdView').call();
    return (res.data is Map ? (res.data['pending'] as num?)?.toInt() : null);
  }

  /// Échange des pubs en réserve contre une offre. Lève [FirebaseFunctionsException] si refusé.
  static Future<Map<String, dynamic>> claim(String offerId) async {
    final res = await FirebaseFunctions.instance.httpsCallable('claimReward').call({'offerId': offerId});
    return Map<String, dynamic>.from(res.data as Map);
  }
}
