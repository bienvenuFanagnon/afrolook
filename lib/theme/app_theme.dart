import 'package:flutter/material.dart';

/// ThemeData clair et sombre pour Afrolook.
/// Basé sur la palette noir / vert / jaune (voir [AppColors] pour les accès
/// rapides aux couleurs sémantiques selon le thème actif).
class AppTheme {
  AppTheme._();

  static const Color _primaryLight = Color(0xFF1FAA59);
  static const Color _primaryDark = Color(0xFF2ECC71);
  static const Color _accentLight = Color(0xFFFFD400);
  static const Color _accentDark = Color(0xFFFFE14D);

  static ThemeData get light => ThemeData(
        brightness: Brightness.light,
        useMaterial3: true,
        fontFamily: 'Nunito',
        scaffoldBackgroundColor: const Color(0xFFFAFAF8),
        primaryColor: _primaryLight,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _primaryLight,
          brightness: Brightness.light,
          primary: _primaryLight,
          secondary: _accentLight,
          surface: const Color(0xFFFFFFFF),
        ),
        cardColor: const Color(0xFFFFFFFF),
        dividerColor: const Color(0xFFE5E5E0),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFFAFAF8),
          foregroundColor: Color(0xFF121212),
          elevation: 0,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFFFFFFFF),
          selectedItemColor: _primaryLight,
          unselectedItemColor: Color(0xFF7A7A75),
        ),
        textTheme: ThemeData.light().textTheme.apply(
              fontFamily: 'Nunito',
              bodyColor: const Color(0xFF121212),
              displayColor: const Color(0xFF121212),
            ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: _primaryLight,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: _primaryLight,
          foregroundColor: Colors.white,
        ),
      );

  static ThemeData get dark => ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        fontFamily: 'Nunito',
        scaffoldBackgroundColor: const Color(0xFF0E0E0E),
        primaryColor: _primaryDark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _primaryDark,
          brightness: Brightness.dark,
          primary: _primaryDark,
          secondary: _accentDark,
          surface: const Color(0xFF1A1A1A),
        ),
        cardColor: const Color(0xFF1A1A1A),
        dividerColor: const Color(0xFF2F2F2F),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0E0E0E),
          foregroundColor: Color(0xFFFFFFFF),
          elevation: 0,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF1A1A1A),
          selectedItemColor: _primaryDark,
          unselectedItemColor: Color(0xFF9A9A95),
        ),
        textTheme: ThemeData.dark().textTheme.apply(
              fontFamily: 'Nunito',
              bodyColor: const Color(0xFFFFFFFF),
              displayColor: const Color(0xFFFFFFFF),
            ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: _primaryDark,
            foregroundColor: const Color(0xFF0E0E0E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: _primaryDark,
          foregroundColor: Color(0xFF0E0E0E),
        ),
      );
}
