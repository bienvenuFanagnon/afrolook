import 'package:afrotok/pages/liveshop/live_orders_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> order(String id, String status, {String live = 'L1', int? fee, String? code}) => {
        'id': id, 'title': 'Article $id', 'status': status, 'price_xof': 10000, 'live_id': live, 'delivery_fee_xof': fee, 'delivery_code': code,
        'seller': {'username': 'awa_shop', 'verified': true},
      };

  Future<void> open(WidgetTester tester, List<Map<String, dynamic>> orders) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: LiveOrdersSheet(liveId: 'L1', loader: () async => orders))));
    await tester.pump();
    await tester.pump();
  }

  testWidgets('dans le live : frais de livraison à accepter ou refuser, sans quitter le live', (tester) async {
    await open(tester, [order('A', 'pending_buyer', fee: 1500)]);
    expect(find.byKey(const ValueKey('live_orders_sheet')), findsOneWidget);
    expect(find.textContaining('frais de livraison'), findsWidgets);
    expect(find.text('Accepter les frais'), findsOneWidget);
    expect(find.text('Refuser'), findsOneWidget);
    expect(find.textContaining('dans ce live'), findsOneWidget);
    expect(find.byIcon(Icons.verified_user_rounded), findsOneWidget);   // badge vendeur vérifié
    await tester.pumpWidget(const SizedBox());   // arrête la mise à jour automatique
  });

  testWidgets('dans le live : annuler tant que le vendeur n\'a pas validé ; plus d\'annulation une fois validée ; code et « J\'ai reçu » à l\'expédition', (tester) async {
    await open(tester, [order('A', 'pending_seller'), order('B', 'accepted'), order('C', 'shipped', code: '4821')]);
    expect(find.text('Annuler'), findsOneWidget);                 // seulement pour la commande en attente du vendeur
    expect(find.textContaining('le vendeur prépare'), findsOneWidget);
    expect(find.text('4821'), findsOneWidget);
    expect(find.text('J\'ai reçu'), findsOneWidget);
    expect(find.text('Signaler un problème'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('dans le live : les commandes de ce live passent en premier, rien à afficher → invitation à commander', (tester) async {
    await open(tester, [order('X', 'accepted', live: 'AUTRE'), order('Y', 'pending_seller')]);
    final y = tester.getTopLeft(find.text('Article Y')).dy;
    final x = tester.getTopLeft(find.text('Article X')).dy;
    expect(y, lessThan(x));
    await tester.pumpWidget(const SizedBox());
    await open(tester, []);
    expect(find.textContaining('Aucune commande en cours'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
