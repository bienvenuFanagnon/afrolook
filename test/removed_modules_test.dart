import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Modules abandonnés (09/11/2026) : CinetPay (paiement) et la page d'abonnement « Premium entreprise » qui l'utilisait, les rencontres (Afrolove), et trois paquets
/// remplacés pour alléger l'application. Ce test empêche leur retour par erreur (voir docs/TAILLE_APPLICATION.md).
void main() {
  final pubspec = File('pubspec.yaml').readAsStringSync();
  final dartFiles = Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart')).toList();

  String code(File f) => f.readAsStringSync().split('\n').where((l) => !l.trimLeft().startsWith('//')).join('\n');

  test('les paquets retirés ne sont plus déclarés', () {
    for (final p in ['cinetpay', 'csc_picker_plus', 'awesome_dialog']) {
      expect(RegExp('^\\s*$p\\s*:', multiLine: true).hasMatch(pubspec), isFalse, reason: p);
    }
  });

  test('plus aucun import des paquets retirés ni de CinetPay', () {
    for (final f in dartFiles) {
      final c = code(f);
      for (final p in ['package:cinetpay/', 'package:csc_picker_plus/', 'package:awesome_dialog/', 'package:flutter_inappwebview/']) {
        expect(c.contains(p), isFalse, reason: '${f.path} : $p');
      }
    }
  });

  test('la page d\'abonnement Premium entreprise est supprimée et plus appelée', () {
    expect(File('lib/pages/entreprise/abonnement/Subscription.dart').existsSync(), isFalse);
    expect(File('lib/pages/entreprise/abonnement/MySubscription.dart').existsSync(), isFalse);
    for (final f in dartFiles) {
      final c = code(f);
      expect(c.contains('PremiumSubscriptionPage'), isFalse, reason: f.path);
      expect(c.contains('CurrentSubscriptionPage'), isFalse, reason: f.path);
    }
  });

  test('aucune page de rencontres (Afrolove) ni traduction « dating » dans le code actif', () {
    for (final d in Directory('lib').listSync(recursive: true).whereType<Directory>()) {
      expect(RegExp('dating|afrolove|rencontre', caseSensitive: false).hasMatch(d.path.split(RegExp(r'[\\/]')).last), isFalse, reason: d.path);
    }
    final loc = code(File('lib/l10n/app_localizations.dart'));
    expect(RegExp(r'String get (navDating|profileMenuAfrolove|dating)', caseSensitive: false).hasMatch(loc), isFalse);
  });
}
