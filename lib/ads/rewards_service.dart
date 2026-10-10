import 'ad_gate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../models/model_data.dart';
import '../services/utils/abonnement_utils.dart';
import 'ad_config.dart';
import 'admob_service.dart';

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
  final bool freeOnly; // inutile pour un abonné (déjà inclus dans Premium/Gold)
  final bool hidden; // proposée seulement depuis un écran précis (pas dans la page Récompenses)
  const RewardOffer(this.id, this.icon, this.title, this.desc, this.ads, this.cap,
      {this.premium = false, this.hours = 0, this.freeOnly = false, this.hidden = false});
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

  // Réglages Firestore (AppConfig/rewards) : interrupteur, plafond de pubs, offres (activation, pubs, limites)
  static Map<String, dynamic> _cfg = {};
  static DateTime? _cfgAt;

  static Future<void> loadConfig({bool force = false}) async {
    final at = _cfgAt;
    if (!force && at != null && DateTime.now().difference(at) < const Duration(minutes: 5)) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('AppConfig').doc('rewards').get();
      _cfg = doc.data() ?? {};
      _cfgAt = DateTime.now();
    } catch (_) {}
  }

  static bool get enabledByConfig => _cfg['enabled'] != false;
  static int get maxAdsPerDay => ((_cfg['maxAdsPerDay'] as num?)?.toInt() ?? 10).clamp(1, 30);

  /// Offre avec les réglages Firestore ; null si désactivée.
  static RewardOffer? effective(RewardOffer o) {
    final offers = _cfg['offers'];
    final c = offers is Map && offers[o.id] is Map ? offers[o.id] as Map : const {};
    if (c['enabled'] == false) return null;
    int n(String k, int def) => (c[k] as num?)?.toInt() ?? def;
    return RewardOffer(o.id, o.icon, o.title, o.desc, n('ads', o.ads).clamp(1, 30), n('cap', o.cap),
        premium: o.premium, hours: n('hours', o.hours), freeOnly: o.freeOnly, hidden: o.hidden);
  }

  static const offers = <RewardOffer>[
    RewardOffer('premium_5h', Icons.star_rounded, 'Premium 5 heures', 'Tout le Premium : photos multiples, live HD, stickers…', 2, 3, premium: true, hours: 5),
    RewardOffer('premium_10h', Icons.star_rounded, 'Premium 10 heures', 'Tout le Premium pendant 10 heures', 3, 3, premium: true, hours: 10),
    RewardOffer('premium_24h', Icons.workspace_premium_rounded, 'Premium 24 heures', 'Tout le Premium pendant un jour', 5, 2, premium: true, hours: 24),
    RewardOffer('adfree_24h', Icons.block_rounded, 'Une journée sans pub', '24 h sans publicité', 1, 2),
    RewardOffer('coins_2', Icons.monetization_on_rounded, '2 pièces cadeau', 'Pour offrir des cadeaux et liker', 1, 5),
    RewardOffer('flame_shield', Icons.local_fire_department_rounded, 'Bouclier de flamme', 'Protège ta série de commentaires une fois', 1, 1),
    RewardOffer('stickers_3', Icons.sticky_note_2_rounded, '3 stickers aujourd\'hui', 'Pour les comptes gratuits', 1, 2, freeOnly: true),
    RewardOffer('photos_3', Icons.photo_library_rounded, 'Post avec 3 photos', 'Une publication avec plusieurs photos', 2, 3, freeOnly: true),
    // Studio Cartes : une pub = une capture de carte sans pièces (proposée depuis le studio)
    RewardOffer('card_capture', Icons.auto_awesome_rounded, 'Une carte Afrolook', 'Une capture de carte offerte', 1, 2, hidden: true),
  ];

  /// La page et les pubs récompensées sont-elles proposées à cette personne ?
  /// (Gold : aucune pub et tout déjà débloqué ; admin : toujours, pour vérifier.)
  static bool available(UserData? u) {
    if (u == null || !AdConfig.isMobile) return false;
    final c = AdConfig.current;
    if (!c.enabled || !c.rewardsEnabled || !enabledByConfig || c.unit('rewarded').isEmpty) return false;
    if (AbonnementUtils.isAdmin(u.role)) return true;
    return AdGate.subscriptionBypass > 0 || u.abonnement?.estGold != true;
  }

  /// Offres affichées selon le rôle : un vrai Premium (payé) ne voit pas les offres Premium.
  static List<RewardOffer> visibleOffers(UserData u) {
    final all = offers.where((o) => !o.hidden).map(effective).whereType<RewardOffer>().toList();
    if (AbonnementUtils.isAdmin(u.role)) return all;
    final ab = u.abonnement;
    final paidPremium = ab?.estPremium == true && ab?.methodePaiement != 'pubs';
    final anyPremium = ab?.estPremium == true;
    return all.where((o) => !(o.premium && paidPremium) && !(o.freeOnly && anyPremium)).toList();
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

  /// Plafond de pièces gagnées avec des pubs par semaine (AppConfig/rewards.coinsMaxPerWeek, 20 par défaut côté serveur).
  static int get coinsMaxPerWeek => ((_cfg['coinsMaxPerWeek'] as num?)?.toInt() ?? 20).clamp(0, 1000);

  /// Clé de la semaine ISO courante (UTC), identique à celle du serveur (`weekKey` de functions/src/ads/rewards.ts).
  static String weekKey([DateTime? now]) {
    final n = (now ?? DateTime.now()).toUtc();
    final day = DateTime.utc(n.year, n.month, n.day);
    final date = day.add(Duration(days: 4 - day.weekday));
    final week = ((date.difference(DateTime.utc(date.year, 1, 1)).inDays + 1) / 7).ceil();
    return '${date.year}W${week.toString().padLeft(2, '0')}';
  }

  /// Pièces déjà gagnées avec des pubs cette semaine.
  static Future<int> coinsThisWeek(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('AdRewardsWeek').doc('${uid}_${weekKey()}').get();
      return (doc.data()?['coins'] as num?)?.toInt() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Pièces cadeau données par l'offre « coins_2 » (réglable côté serveur : AppConfig/rewards.offers.coins_2.coins).
  static int get coinOfferCoins {
    final offers = _cfg['offers'];
    final c = offers is Map && offers['coins_2'] is Map ? offers['coins_2'] as Map : const {};
    return (c['coins'] as num?)?.toInt() ?? 2;
  }

  /// L'offre d'id [id] avec les réglages Firestore ; null si inconnue ou désactivée.
  static RewardOffer? offerById(String id) {
    for (final o in offers) {
      if (o.id == id) return effective(o);
    }
    return null;
  }

  /// Reste-t-il au moins une récompense [id] à prendre aujourd'hui (plafond de pubs et plafond de l'offre) ?
  static bool canClaimToday(RewardsStatus st, RewardOffer o) =>
      st.watched < maxAdsPerDay && (o.cap <= 0 || (st.claims[o.id] ?? 0) < o.cap);

  /// Parcours complet d'une récompense depuis un autre écran que la page Récompenses :
  /// regarde les pubs nécessaires, les compte (vérification AdMob ou déclaration), puis réclame l'offre.
  /// Retourne `false` si aucune pub n'était disponible. Lève [FirebaseFunctionsException] si le serveur refuse.
  static Future<bool> watchAndClaim(String offerId, String uid) async {
    final o = offerById(offerId);
    if (o == null) return false;
    var pending = (await status(uid)).pending;
    while (pending < o.ads) {
      final earned = await AdmobService.watchRewarded(userId: uid);
      if (!earned) return false;
      if (AdConfig.current.ssvEnabled) {
        final target = pending + 1;
        for (var i = 0; i < 8; i++) {
          pending = (await status(uid)).pending;
          if (pending >= target) break;
          await Future<void>.delayed(const Duration(milliseconds: 1500));
        }
        if (pending < target) return false;
      } else {
        pending = (await recordView()) ?? pending + 1;
      }
    }
    await claim(offerId);
    return true;
  }
}
