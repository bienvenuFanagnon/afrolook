import 'package:flutter/material.dart';

import '../models/model_data.dart';
import '../services/utils/abonnement_utils.dart';

/// Widget badge utilisateur unifié — à utiliser PARTOUT dans l'app.
///
/// Passe un [UserData] complet (recommandé) ou les params individuels
/// (pour les cas cache Map<String, dynamic> comme le chat de groupe).
///
/// Tailles conseillées :
///   - Avatar overlay (Positioned) : 13–14
///   - Inline username (Row)       : 14–16
///   - Profil / page détail        : 18–20
class UserBadgeWidget extends StatelessWidget {
  // ── Shortcut : passe directement le UserData ────────────────────────────────
  final UserData? user;

  // ── Params individuels (utilisés quand [user] est null) ─────────────────────
  final AfrolookAbonnement? abonnement;
  final bool isVerified;
  final bool officialBadge;
  final String? officialAccountType;
  final bool? isPremiumOverride;

  // ── Apparence ───────────────────────────────────────────────────────────────
  final double size;

  /// Affiche un fond rond blanc derrière le badge (défaut : true).
  /// Mettre [withBackground] = false pour les contextes inline très serrés.
  final bool withBackground;

  const UserBadgeWidget({
    super.key,
    this.user,
    this.abonnement,
    this.isVerified = false,
    this.officialBadge = false,
    this.officialAccountType,
    this.isPremiumOverride,
    this.size = 16,
    this.withBackground = true,
  });

  @override
  Widget build(BuildContext context) {
    return AbonnementUtils.getUserBadge(
      abonnement: user?.abonnement ?? abonnement,
      isVerified: user?.isVerify ?? isVerified,
      officialBadge: user?.officialBadge ?? officialBadge,
      officialAccountType: user?.officialAccountType ?? officialAccountType,
      isPremiumOverride: isPremiumOverride ?? (user?.abonnement?.estPremium == true ? true : null),
      size: size,
      withBackground: withBackground,
    );
  }
}
