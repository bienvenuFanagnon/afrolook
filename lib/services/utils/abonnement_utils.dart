// utils/abonnement_utils.dart
import 'package:flutter/material.dart';

import '../../models/model_data.dart';

/// Point de contrôle unique pour tous les droits liés à l'abonnement.
/// Toute vérification de permission passe par ici — jamais directement
/// par `abonnement?.estPremium` dans les pages.
///
/// Plans : 'gratuit' < 'premium' < 'gold'
/// Gold ⊃ Premium : estPremium retourne true pour Premium ET Gold.
class AbonnementUtils {
  // ── Checks de plan ───────────────────────────────────────────────────────

  static bool isPremiumActive(AfrolookAbonnement? abonnement) =>
      abonnement?.estPremium == true;

  static bool isGold(AfrolookAbonnement? abonnement) =>
      abonnement?.estGold == true;

  // ── Fonctionnalités Live ──────────────────────────────────────────────────

  static bool canLiveHD(AfrolookAbonnement? abonnement) =>
      abonnement?.estPremium == true;

  static int getLiveLatency(AfrolookAbonnement? abonnement) =>
      abonnement?.estPremium == true ? 500 : 2000;

  // ── Fonctionnalités Posts ─────────────────────────────────────────────────

  static bool canPostMultiplePhotos(AfrolookAbonnement? abonnement) =>
      abonnement?.estPremium == true;

  static int getMaxPhotosPerLook(AfrolookAbonnement? abonnement) =>
      abonnement?.estPremium == true ? 10 : 1;

  static bool hasTimeRestriction(AfrolookAbonnement? abonnement) =>
      abonnement?.estPremium != true;

  static int getRestrictionTime(AfrolookAbonnement? abonnement) =>
      abonnement?.estPremium == true ? 0 : 60;

  static bool canJoinChallengesFreely(AfrolookAbonnement? abonnement) =>
      abonnement?.estPremium == true;

  static bool canShareMoreText(AfrolookAbonnement? abonnement) =>
      abonnement?.estPremium == true;

  static bool canJoinSponsorEvents(AfrolookAbonnement? abonnement) =>
      abonnement?.estPremium == true;

  // ── Admin — traité comme Gold permanent ──────────────────────────────────

  /// Un admin plateforme (role == 'ADM') est effectivement Gold sans expiry.
  static bool isAdmin(String? role) => role == 'ADM';

  /// Vérifie Gold en tenant compte du rôle admin.
  static bool isEffectivelyGold(AfrolookAbonnement? abonnement, String? role) =>
      role == 'ADM' || abonnement?.estGold == true;

  // ── Fonctionnalités Groupes (Premium + Gold) ──────────────────────────────

  /// Créer et gérer un groupe de chat (Premium, Gold ou Admin)
  static bool canCreateGroup(AfrolookAbonnement? abonnement, {String? role}) =>
      role == 'ADM' || abonnement?.estPremium == true;

  /// Nombre max de groupes possédés (null = illimité, 0 = aucun)
  /// Admin → illimité · Gold → illimité · Premium → 2 · Gratuit → 0
  static int? maxGroupsOwned(AfrolookAbonnement? abonnement, {String? role}) {
    if (role == 'ADM') return null;
    if (abonnement?.estGold == true) return null;
    if (abonnement?.estPremium == true) return 2;
    return 0;
  }

  /// Nombre max de membres par groupe (null = illimité)
  /// Admin → illimité · Gold → illimité · Premium → 100
  static int? maxGroupMembers(AfrolookAbonnement? abonnement, {String? role}) {
    if (role == 'ADM') return null;
    if (abonnement?.estGold == true) return null;
    if (abonnement?.estPremium == true) return 100;
    return null;
  }

  // ── Fonctionnalités Groupes (Gold uniquement ou Admin) ───────────────────

  /// Créer un groupe privé payant (Gold ou Admin)
  static bool canCreatePrivateGroup(AfrolookAbonnement? abonnement, {String? role}) =>
      role == 'ADM' || abonnement?.estGold == true;

  /// Générer et partager un code unique de groupe (Gold ou Admin)
  static bool canUseGroupJoinCode(AfrolookAbonnement? abonnement, {String? role}) =>
      role == 'ADM' || abonnement?.estGold == true;

  /// Le groupe du propriétaire apparaît dans le carousel pub (Gold ou Admin)
  static bool canAppearInGoldCarousel(AfrolookAbonnement? abonnement, {String? role}) =>
      role == 'ADM' || abonnement?.estGold == true;

  // ── Dates et expiration ───────────────────────────────────────────────────

  static bool isExpiringSoon(AfrolookAbonnement? abonnement) =>
      abonnement?.expireBientot == true;

  static int getDaysRemaining(AfrolookAbonnement? abonnement) =>
      abonnement?.joursRestants ?? 0;

  static bool isExpired(AfrolookAbonnement? abonnement) =>
      abonnement?.estExpire == true;

  static String getFormattedEndDate(AfrolookAbonnement? abonnement) {
    if (abonnement == null || abonnement.type == 'gratuit') return 'Illimité';
    final d = abonnement.dateFin;
    return '${d.day}/${d.month}/${d.year}';
  }

  // ── Badge utilisateur — source unique ────────────────────────────────────
  // Priorité : isVerify > officiel personnel > officiel institutionnel > Gold > Premium

  static const _personalOfficialTypes = {
    'influencer', 'artist', 'publicFigure', 'entrepreneur'
  };
  static const _institutionalOfficialTypes = {
    'company', 'stateInstitution', 'media', 'journalist', 'ngo', 'association', 'other'
  };

  static Widget getUserBadge({
    AfrolookAbonnement? abonnement,
    required bool isVerified,
    bool officialBadge = false,
    String? officialAccountType,
    bool? isPremiumOverride,
    double size = 16,
    bool withBackground = false,
  }) {
    final isPremium = isPremiumOverride ?? abonnement?.estPremium == true;
    final isGoldUser = abonnement?.estGold == true;

    Widget? badge;

    // 1. Vérifié admin (bleu)
    if (isVerified) {
      badge = Icon(Icons.verified, color: Colors.blue, size: size);
    }
    // 2. Compte officiel personnel (orange)
    else if (officialBadge && _personalOfficialTypes.contains(officialAccountType)) {
      badge = Icon(Icons.verified, color: Colors.orange, size: size);
    }
    // 3. Compte officiel institutionnel (bleu carré)
    else if (officialBadge && _institutionalOfficialTypes.contains(officialAccountType)) {
      badge = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.blue,
          borderRadius: BorderRadius.circular(size * 0.2),
        ),
        child: Icon(Icons.verified, color: Colors.white, size: size * 0.75),
      );
    }
    // 4. Badge Gold 👑 (gradient or)
    else if (isGoldUser) {
      badge = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.5),
        ),
        child: Icon(Icons.workspace_premium, color: Colors.white, size: size * 0.6),
      );
    }
    // 5. Badge Premium ⭐ (gradient rose-or)
    else if (isPremium) {
      badge = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFDB813), Color(0xFFFF416C)],
          ),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.5),
        ),
        child: Icon(Icons.workspace_premium, color: Colors.white, size: size * 0.6),
      );
    }

    if (badge == null) return const SizedBox.shrink();

    if (!withBackground) return badge;

    return Container(
      width: size + 6,
      height: size + 6,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Center(child: badge),
    );
  }
}