import 'package:flutter/material.dart';

/// Palette centrale Afrolook — noir / vert / jaune + accents complémentaires.
/// Chaque couleur a une variante claire et une variante sombre.
/// Utiliser via [AppColors.of(context)] pour récupérer le bon set selon le thème actif.
class AppColors {
  final Brightness brightness;

  const AppColors._(this.brightness);

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
  Color get textSecondary => isDark ? const Color(0xFF9A9A95) : const Color(0xFF7A7A75);

  // Couleurs de marque
  Color get primary => isDark ? const Color(0xFF2ECC71) : const Color(0xFF1FAA59); // vert
  Color get onPrimary => isDark ? const Color(0xFF0E0E0E) : const Color(0xFFFFFFFF);
  Color get accent => isDark ? const Color(0xFFFFE14D) : const Color(0xFFFFD400); // jaune
  Color get onAccent => const Color(0xFF121212);

  /// Variante du jaune d'accent garantissant un bon contraste pour du texte/icônes
  /// sur fond clair ou sombre (le jaune pur `accent` est peu visible sur fond blanc).
  Color get supportAccent => isDark ? const Color(0xFFFFE14D) : const Color(0xFFB8860B);
  Color get black => const Color(0xFF121212);

  // Accents complémentaires
  Color get info => isDark ? const Color(0xFF5B9CFA) : const Color(0xFF3478F6); // chat / crypto
  Color get danger => isDark ? const Color(0xFFFF6B6F) : const Color(0xFFE5484D); // alertes / retraits
  Color get warning => isDark ? const Color(0xFFFF9248) : const Color(0xFFFF7A1A); // live / coins
  Color get success => primary;

  // Etats interactifs
  Color get divider => border;
  Color get shimmerBase => isDark ? const Color(0xFF242424) : const Color(0xFFECECE6);
  Color get shimmerHighlight => isDark ? const Color(0xFF2F2F2F) : const Color(0xFFF7F7F2);
}
