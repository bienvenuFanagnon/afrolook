import 'package:flutter/material.dart';

/// Palette centrale Afrolook — noir / vert / jaune + accents complémentaires.
/// Chaque couleur a une variante claire et une variante sombre.
/// Utiliser via [AppColors.of(context)] pour récupérer le bon set selon le thème actif.
///
/// RÈGLE DE LISIBILITÉ (validée le 02/11/2026) : le jaune ne sert qu'en FOND (boutons, pastilles) avec du texte noir dessus ([accent] + [onAccent]) ; jamais en texte ni
/// en icône sur fond clair (contraste 1,4). Pour un texte ou une icône « jaune » sur fond clair : [accentText] (ambre foncé, contraste 5,1). Texte courant ≥ 4,5, icônes ≥ 3.
class AppColors {
  final Brightness brightness;

  const AppColors._(this.brightness);

  /// Palette sombre fixe (valeur par défaut avant d'avoir un BuildContext).
  static const AppColors dark = AppColors._(Brightness.dark);

  static AppColors of(BuildContext context) {
    return AppColors._(Theme.of(context).brightness);
  }

  bool get isDark => brightness == Brightness.dark;

  // Fonds
  Color get background => isDark ? const Color(0xFF0E0E0E) : const Color(0xFFFAFAF8);
  Color get surface => isDark ? const Color(0xFF1A1A1A) : const Color(0xFFFFFFFF);
  Color get surfaceVariant => isDark ? const Color(0xFF242424) : const Color(0xFFF1F1EC);
  Color get border => isDark ? const Color(0xFF2F2F2F) : const Color(0xFFE5E5E0);

  // Texte
  Color get textPrimary => isDark ? const Color(0xFFFFFFFF) : const Color(0xFF121212);
  Color get textSecondary => isDark ? const Color(0xFF9A9A95) : const Color(0xFF63635E); // contraste 6,0 sur blanc

  // Couleurs de marque
  Color get primary => isDark ? const Color(0xFF2ECC71) : const Color(0xFF158246); // vert (clair : 4,9 sur blanc, texte blanc dessus lisible)
  Color get onPrimary => isDark ? const Color(0xFF0E0E0E) : const Color(0xFFFFFFFF);
  Color get accent => isDark ? const Color(0xFFFFE14D) : const Color(0xFFFFD400); // jaune
  Color get onAccent => const Color(0xFF121212);

  /// Variante du jaune d'accent garantissant un bon contraste pour du texte/icônes
  /// sur fond clair ou sombre (le jaune pur `accent` est peu visible sur fond blanc).
  Color get supportAccent => isDark ? const Color(0xFFFFE14D) : const Color(0xFF8A6500);

  /// Texte ou icône « jaune » : ambre foncé sur fond clair (5,1), jaune d'accent sur fond sombre (14,8). Même valeur que [supportAccent].
  Color get accentText => supportAccent;

  /// Barre de navigation : icônes inactives (gris foncé, 6,5 sur blanc) et actives (vert de marque).
  Color get navInactive => isDark ? const Color(0xFF9A9A95) : const Color(0xFF5E5E59);
  Color get navActive => primary;

  /// Pastille de compteur (invitations, messages, notifications) : rouge, chiffre blanc (4,8) dans les deux thèmes.
  Color get badgeFill => const Color(0xFFD92D3A);
  Color get onBadge => const Color(0xFFFFFFFF);
  Color get black => const Color(0xFF121212);

  // Accents complémentaires
  Color get info => isDark ? const Color(0xFF5B9CFA) : const Color(0xFF1F5FD1); // chat / liens (clair : 5,8 sur blanc)
  Color get danger => isDark ? const Color(0xFFFF6B6F) : const Color(0xFFD92D3A); // alertes / retraits (clair : 4,8 sur blanc)
  Color get warning => isDark ? const Color(0xFFFF9248) : const Color(0xFFFF7A1A); // live / coins
  Color get success => primary;

  // Etats interactifs
  Color get divider => border;
  Color get shimmerBase => isDark ? const Color(0xFF242424) : const Color(0xFFECECE6);
  Color get shimmerHighlight => isDark ? const Color(0xFF2F2F2F) : const Color(0xFFF7F7F2);
}
