import 'package:afrotok/pages/admin/payment_logs_admin_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

PaymentLogEntry _e(String id, String provider, String step, bool ok, String msg, {bool expected = false, int minutesAgo = 5}) => PaymentLogEntry(id, {
      'at': DateTime.now().subtract(Duration(minutes: minutesAgo)).millisecondsSinceEpoch,
      'provider': provider, 'step': step, 'ok': ok, 'expected': expected, 'message': msg, 'amount': 1000, 'currency': 'XOF',
    });

void main() {
  final logs = [
    _e('1', 'feexpay', 'webhook', false, 'Solde insuffisant chez l\'opérateur'),
    _e('2', 'google_play', 'verify', false, 'Vérification Google Play indisponible'),
    _e('3', 'google_play', 'purchase', false, 'Achat annulé par la personne', expected: true),
    _e('4', 'feexpay', 'credit', true, ''),
  ];
  final stats = {'feexpay_ok': 3, 'feexpay_error': 1, 'google_play_error': 1, 'google_play_expected': 1};

  Future<void> show(WidgetTester t) async {
    await t.binding.setSurfaceSize(const Size(400, 900));
    await t.pumpWidget(MaterialApp(home: PaymentLogsAdminPage(preview: (logs: logs, stats: stats))));
    await t.pump(const Duration(milliseconds: 200));
  }

  testWidgets('erreurs seulement par défaut : les échecs sont visibles, pas les réussites ni les annulations', (t) async {
    await show(t);
    expect(find.textContaining('Solde insuffisant chez l’opérateur'.replaceAll('’', '\'')), findsOneWidget);
    expect(find.textContaining('Vérification Google Play indisponible'), findsOneWidget);
    expect(find.textContaining('Achat annulé par la personne'), findsNothing);
    expect(find.textContaining('Pièces ou solde crédités'), findsNothing);
    // compteurs du jour : 3 réussis, 2 erreurs (les annulations ne comptent pas)
    expect(find.text('3'), findsWidgets);
    expect(find.text('2'), findsWidgets);
    expect(t.takeException(), isNull);
  });

  testWidgets('« Tout » montre aussi les réussites et les annulations ; un fournisseur se filtre', (t) async {
    await show(t);
    await t.tap(find.text('Tout'));
    await t.pump();
    expect(find.textContaining('Pièces ou solde crédités'), findsOneWidget);
    expect(find.textContaining('Achat annulé par la personne'), findsOneWidget);
    await t.ensureVisible(find.widgetWithText(ChoiceChip, 'Google Play'));
    await t.pump();
    await t.tap(find.widgetWithText(ChoiceChip, 'Google Play'));
    await t.pump();
    expect(find.textContaining('Pièces ou solde crédités'), findsNothing);
    expect(find.textContaining('Vérification Google Play indisponible'), findsOneWidget);
  });

  testWidgets('toucher une ligne ouvre le détail', (t) async {
    await show(t);
    await t.tap(find.textContaining('Vérification Google Play indisponible'));
    await t.pumpAndSettle();
    expect(find.text('Détail'), findsOneWidget);
    expect(find.text('Copier'), findsOneWidget);
  });
}
