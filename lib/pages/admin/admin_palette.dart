import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Palette des pages admin, en thème clair et sombre.
///
/// Les pages admin historiques utilisaient des constantes de couleur sombres
/// (`_bg`, `_card`, `_textP`…). Elles lisent maintenant ces getters, alimentés par
/// [AdminPalette.of] appelé au début de chaque `build` de page.
class AdminPalette {
  static AppColors _c = AppColors.dark;

  /// À appeler au début du `build` de chaque page admin.
  static AppColors of(BuildContext context) => _c = AppColors.of(context);

  static bool get isDark => _c.isDark;
  static Color get bg => _c.background;
  static Color get surface => _c.surface;
  static Color get card => _c.isDark ? _c.surfaceVariant : _c.surface;
  static Color get field => _c.isDark ? _c.background : _c.surfaceVariant;
  static Color get border => _c.border;
  static Color get textP => _c.textPrimary;
  static Color get textS => _c.textSecondary;

  // Accents : variantes plus foncées en thème clair pour rester lisibles sur fond blanc.
  static Color get gold => _c.isDark ? const Color(0xFFF0B429) : const Color(0xFFB7791F);
  static Color get green => _c.isDark ? const Color(0xFF34C759) : const Color(0xFF1E9E4A);
  static Color get amber => _c.isDark ? const Color(0xFFFF9F0A) : const Color(0xFFD97706);
  static Color get blue => _c.isDark ? const Color(0xFF3B82F6) : const Color(0xFF2563EB);
  static Color get purple => _c.isDark ? const Color(0xFFBF5AF2) : const Color(0xFF8E3CC4);
  static Color get teal => _c.isDark ? const Color(0xFF30B0C7) : const Color(0xFF0E8A9E);
  static Color get pink => _c.isDark ? const Color(0xFFFF2D55) : const Color(0xFFD6204A);
  static Color get red => _c.isDark ? const Color(0xFFFF453A) : const Color(0xFFDC2626);
}
