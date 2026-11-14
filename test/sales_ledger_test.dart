import 'package:afrotok/pages/liveshop/sales_ledger_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('fr'));

  final now = DateTime.now().toUtc().toIso8601String();

  testWidgets('solde des ventes du vendeur : net reçu, commission, annulations, transactions du jour ; périodes au choix', (tester) async {
    tester.view.physicalSize = const Size(1080, 3600);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    final asked = <String>[];
    await tester.pumpWidget(MaterialApp(
      home: SalesLedgerPage(
        seller: true,
        loader: (from, to) async {
          asked.add('$from>$to');
          return {
            'summary': {'sales': 1, 'gross_xof': 10000, 'commission_xof': 1000, 'net_xof': 9000, 'cancelled': 1, 'in_escrow_xof': 7000},
            'by_day': [],
            'lines': [
              {'kind': 'sale', 'at': now, 'title': 'Sac', 'quantity': 1, 'other': 'kofi', 'gross_xof': 10000, 'commission_xof': 1000, 'amount_xof': 9000},
              {'kind': 'cancelled', 'at': now, 'title': 'Montre', 'quantity': 1, 'other': 'ama', 'gross_xof': 5000, 'commission_xof': 0, 'amount_xof': 0},
            ],
          };
        },
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Solde des ventes'), findsOneWidget);
    expect(find.textContaining('9'), findsWidgets);
    expect(find.text('Net reçu sur la période'), findsOneWidget);
    expect(find.textContaining('commission'), findsWidgets);
    expect(find.textContaining('à @kofi'), findsOneWidget);
    expect(find.textContaining('aucun argent reçu'), findsOneWidget);
    expect(find.textContaining('déjà ajouté à ton solde de gains'), findsOneWidget);
    await tester.tap(find.text('Hier'));
    await tester.pumpAndSettle();
    expect(asked.length, 2);
    expect(asked.first.split('>').first, isNot(asked.last.split('>').first));   // une autre date est demandée
  });

  testWidgets('mes dépenses (acheteur) : dépensé, remboursé, séquestre ; message quand la période est vide', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: SalesLedgerPage(
        seller: false,
        loader: (_, __) async => {'summary': {'purchases': 0, 'spent_xof': 0, 'refunded_xof': 0, 'net_spent_xof': 0, 'in_escrow_xof': 0}, 'by_day': [], 'lines': []},
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Mes dépenses'), findsOneWidget);
    expect(find.text('Dépensé sur la période'), findsOneWidget);
    expect(find.text('Aucun achat sur cette période.'), findsOneWidget);
  });
}
