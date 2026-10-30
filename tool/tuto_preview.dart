// Aperçu temporaire du tutoriel de monétisation (à supprimer).
import 'package:afrotok/l10n/app_localizations.dart';
import 'package:afrotok/pages/intro/monetization_tutorial.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() {
  final lang = Uri.base.queryParameters['lang'] ?? 'fr';
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    locale: Locale(lang),
    supportedLocales: kSupportedLocales.keys.map((c) => Locale(c)).toList(),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: const MonetizationTutorialPage(),
  ));
}
