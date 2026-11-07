import 'package:afrotok/widgets/gold_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('une option sans fonction Gold associée n\'est jamais marquée fermée', () {
    expect(GoldBadge.locked(null), isFalse);
  });

  for (final b in [Brightness.light, Brightness.dark]) {
    testWidgets('pastille GOLD (${b.name}) : cadenas et mot GOLD, sans débordement, en version normale et compacte', (tester) async {
      await tester.pumpWidget(MaterialApp(theme: ThemeData(brightness: b), home: const Scaffold(body: Row(children: [GoldBadge(), SizedBox(width: 8), GoldBadge(compact: true)]))));
      expect(find.text('GOLD'), findsNWidgets(2));
      expect(find.byIcon(Icons.lock_rounded), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });
  }
}
