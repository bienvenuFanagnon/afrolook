import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';

class LocaleProvider extends ChangeNotifier {
  Locale _locale = Locale(deviceLanguageCode());

  Locale get locale => _locale;
  bool get isFrench => _locale.languageCode == 'fr';

  LocaleProvider() {
    _loadLocale();
  }

  Future<void> _loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    // Choix manuel de l'utilisateur en priorité, sinon langue du téléphone.
    final code = prefs.getString('app_locale') ?? deviceLanguageCode();
    if (kSupportedLocales.containsKey(code)) {
      _locale = Locale(code);
      notifyListeners();
    }
  }

  /// Langue du téléphone si l'app la propose, sinon anglais.
  static String deviceLanguageCode() {
    final code = PlatformDispatcher.instance.locale.languageCode;
    return kSupportedLocales.containsKey(code) ? code : 'en';
  }

  Future<void> setLocale(Locale locale) async {
    if (!kSupportedLocales.containsKey(locale.languageCode)) return;
    _locale = locale;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_locale', locale.languageCode);
  }

  void toggleLocale() {
    setLocale(_locale.languageCode == 'fr' ? const Locale('en') : const Locale('fr'));
  }

  /// Passe à la langue suivante dans la liste des langues supportées
  /// (utilisé par le petit sélecteur "drapeau" de la barre du haut).
  void cycleLocale() {
    final codes = kSupportedLocales.keys.toList();
    final currentIndex = codes.indexOf(_locale.languageCode);
    final nextIndex = (currentIndex + 1) % codes.length;
    setLocale(Locale(codes[nextIndex]));
  }
}
