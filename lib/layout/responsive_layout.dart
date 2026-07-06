import 'package:flutter/material.dart';

/// Breakpoints et utilitaires pour le layout responsive Afrolook.
///
///  Mobile   < 576 px  — layout actuel inchangé
///  Tablet   576–992px — 2 colonnes (sidebar étroite + feed)
///  Desktop  > 992 px  — 3 colonnes (sidebar large + feed + panneau droit)
class AppLayout {
  AppLayout._();

  // ── Breakpoints ──────────────────────────────────────────────────────────
  static const double _mobileBreak = 576.0;
  static const double _desktopBreak = 992.0;

  // ── Dimensions ───────────────────────────────────────────────────────────
  /// Largeur max du feed principal centré
  static const double maxFeedWidth = 680.0;
  /// Largeur max de la zone totale (feed + panels)
  static const double maxPageWidth = 1400.0;
  /// Sidebar large (desktop)
  static const double sidebarWidth = 220.0;
  /// Sidebar étroite (tablet — icônes uniquement)
  static const double sidebarNarrowWidth = 64.0;
  /// Panneau droit (desktop uniquement)
  static const double rightPanelWidth = 300.0;
  /// Hauteur de la TopBar desktop
  static const double topBarHeight = 56.0;

  // ── Helpers ───────────────────────────────────────────────────────────────
  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < _mobileBreak;

  static bool isWide(BuildContext context) =>
      MediaQuery.of(context).size.width >= _mobileBreak;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width > _desktopBreak;

  static bool isTablet(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return w >= _mobileBreak && w <= _desktopBreak;
  }

  /// Retourne la largeur de sidebar adaptée à l'écran courant.
  static double currentSidebarWidth(BuildContext context) =>
      isDesktop(context) ? sidebarWidth : sidebarNarrowWidth;

  /// Affiche le panneau droit uniquement sur desktop (> 992px).
  static bool showRightPanel(BuildContext context) => isDesktop(context);
}
