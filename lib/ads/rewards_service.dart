import 'package:afrotok/services/api/regie_api.dart';
import 'rewarded_ads.dart';
import 'ad_gate.dart';
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

  // Réglages et état du jour, lus sur le serveur (GET /rewards/state) : interrupteur, plafond de pubs, offres (activation, pubs, limites)
  static Map<String, dynamic> _cfg = {};
  static DateTime? _cfgAt;
  static RewardsStatus _lastStatus = RewardsStatus.empty;
  static bool _serverSsv = false;

  /// Vérification AdMob côté serveur active ? (le serveur est seul juge)
  static bool get serverSsv => _serverSsv;

  static Future<void> loadConfig({bool force = false}) async {
    final at = _cfgAt;
    if (!force && at != null && DateTime.now().difference(at) < const Duration(minutes: 5)) return;
    try {
      _applyState(await RegieApi.rewardsState());
    } catch (_) {}
  }

  static void _applyState(Map<String, dynamic> d) {
    final offersRaw = d['offers'] is Map ? Map<String, dynamic>.from(d['offers'] as Map) : <String, dynamic>{};
    final offers = <String, dynamic>{};
    final claims = <String, int>{};
    for (final id in _knownIds) {
      final o = offersRaw[id];
      if (o is Map) {
        offers[id] = {'enabled': true, 'ads': o['ads'], 'cap': o['cap'], 'hours': o['hours'], 'coins': o['coins']};
        claims[id] = (o['claimed_today'] as num?)?.toInt() ?? 0;
      } else {
        offers[id] = {'enabled': false};
      }
    }
    _cfg = {'enabled': offersRaw.isNotEmpty || d['offers'] == null, 'maxAdsPerDay': d['max_ads_per_day'], 'offers': offers};
    _serverSsv = d['ssv'] == true;
    _lastStatus = RewardsStatus((d['watched'] as num?)?.toInt() ?? 0, (d['pending'] as num?)?.toInt() ?? 0, claims);
    _cfgAt = DateTime.now();
  }

  static const _knownIds = ['premium_5h', 'premium_10h', 'premium_24h', 'adfree_24h', 'coins_2', 'flame_shield', 'stickers_3', 'photos_3', 'card_capture'];

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

  static Future<RewardsStatus> status(String uid) async {
    try {
      _applyState(await RegieApi.rewardsState());
      return _lastStatus;
    } catch (_) {
      return RewardsStatus.empty;
    }
  }

  /// Déclare une pub regardée (mode sans vérification AdMob). Retourne les pubs en réserve.
  static Future<int?> recordView() async {
    final res = await RegieApi.rewardsView();
    return (res['pending'] as num?)?.toInt();
  }

  /// Échange des pubs en réserve contre une offre. Lève une [ApiException] (message en français) si le serveur refuse.
  static Future<Map<String, dynamic>> claim(String offerId) => RegieApi.rewardsClaim(offerId);

  /// Plafond de pièces gagnées avec des pubs par semaine (réglage `rewards.coinsMaxPerWeek`, 20 par défaut côté serveur).
  static int get coinsMaxPerWeek => ((_cfg['coinsMaxPerWeek'] as num?)?.toInt() ?? 20).clamp(0, 1000);

  /// Pièces déjà gagnées avec des pubs cette semaine : le serveur applique lui-même le plafond hebdomadaire et refuse au-delà
  /// (`coins_week`) ; la valeur n'est pas exposée par l'API (voir lacunes_api_regie_admin.md), donc 0 ici.
  static Future<int> coinsThisWeek(String uid) async => 0;

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
  /// Retourne `false` si aucune pub n'était disponible. Lève une [ApiException] si le serveur refuse.
  static Future<bool> watchAndClaim(String offerId, String uid) async {
    final o = offerById(offerId);
    if (o == null) return false;
    var pending = (await status(uid)).pending;
    while (pending < o.ads) {
      final earned = await RewardedAds.watch(userId: uid);
      if (!earned) return false;
      if (_serverSsv || AdConfig.current.ssvEnabled) {
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
