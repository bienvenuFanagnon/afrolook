import 'package:afrotok/pages/liveshop/order_notifications_page.dart';
import 'package:afrotok/pages/liveshop/orders_dashboards.dart';
import 'package:afrotok/pages/liveshop/seller_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(Widget w) => MaterialApp(home: Scaffold(body: SingleChildScrollView(child: w)));

  final counts = {
    'buyer': {'todo': 2, 'progress': 1, 'done': 12, 'to_rate': 1},
    'seller': {'todo': 3, 'progress': 9, 'done': 38},
    'offers': {'seller': 2, 'buyer': 1},
    'total': 8,
    'seller_status': {'pending_seller': 3, 'accepted': 5, 'shipped': 4, 'completed': 38},
    'buyer_status': {'pending_seller': 1, 'shipped': 1, 'completed': 12},
    'promos': {'active': 3, 'uses': 17, 'linked': 1},
  };

  testWidgets('vue d\'ensemble : achats, ventes et offres d\'un coup d\'œil, le total à traiter, un toucher ouvre l\'onglet', (tester) async {
    final tabs = <int>[];
    await tester.pumpWidget(host(OrdersOverview(counts: counts, buyerStats: const {'in_escrow_xof': 45000}, sellerStats: const {'received_xof': 184500}, onTab: tabs.add)));
    expect(find.text('Vue d\'ensemble'), findsOneWidget);
    expect(find.textContaining('8'), findsWidgets);               // pastille du total à traiter
    expect(find.text('3'), findsNWidgets(2));                     // 3 ventes à traiter et 3 offres à répondre (2 + 1)
    expect(find.text('Achats'), findsOneWidget);
    expect(find.text('Ventes'), findsOneWidget);
    expect(find.text('Offres'), findsOneWidget);
    expect(find.textContaining('45'), findsWidgets);              // argent protégé de l'acheteur
    await tester.tap(find.text('Ventes'));
    await tester.tap(find.text('Offres'));
    await tester.tap(find.text('Achats'));
    expect(tabs, [1, 2, 0]);
  });

  testWidgets('vue d\'ensemble : tout à zéro dit « Tout est à jour »', (tester) async {
    await tester.pumpWidget(host(OrdersOverview(counts: const {'buyer': {}, 'seller': {}, 'offers': {}, 'total': 0}, buyerStats: null, sellerStats: null, onTab: (_) {})));
    expect(find.text('Tout est à jour'), findsOneWidget);
  });

  testWidgets('tableau de bord acheteur : argent protégé, ce qu\'il doit faire (réception, avis), étapes et vendeurs habituels', (tester) async {
    final stats = {
      'orders': 15, 'in_progress': 3, 'in_escrow_xof': 45000, 'spent_30d_xof': 82000,
      'by_day': [for (var i = 0; i < 14; i++) {'day': '2026-11-${i + 1}', 'spent_xof': i * 100}],
      'top_sellers': [{'username': 'awa_shop', 'orders': 5, 'spent_xof': 41000}],
      'next_actions': [
        {'id': 'a', 'title': 'Sac en cuir', 'status': 'shipped', 'seller': {'username': 'awa_shop'}},
        {'id': 'b', 'title': 'Robe wax', 'status': 'to_rate', 'seller': {'username': 'awa_shop'}},
      ],
    };
    final statuses = <String>[];
    var todo = 0;
    await tester.pumpWidget(host(BuyerDashboard(counts: counts, stats: stats, onStatus: statuses.add, onTodo: () => todo++, onOffers: () {})));
    expect(find.text('Argent protégé'), findsOneWidget);
    expect(find.text('À faire maintenant'), findsOneWidget);
    expect(find.text('Confirme la réception'), findsOneWidget);
    expect(find.text('Note ton achat'), findsOneWidget);
    expect(find.textContaining('@awa_shop'), findsWidgets);
    await tester.tap(find.text('Expédiées'));
    expect(statuses, ['shipped']);
    await tester.tap(find.text('Confirme la réception'));
    expect(todo, 1);
  });

  testWidgets('tableau de bord acheteur : rien à faire → message vert', (tester) async {
    await tester.pumpWidget(host(BuyerDashboard(counts: const {'buyer': {}, 'offers': {}}, stats: const {'next_actions': []}, onStatus: (_) {}, onTodo: () {}, onOffers: () {})));
    expect(find.textContaining('Rien à faire'), findsOneWidget);
  });

  testWidgets('badge vendeur vérifié : bouclier vert, mot « Vendeur vérifié » (ou icône seule en petit)', (tester) async {
    await tester.pumpWidget(host(const Column(children: [SellerVerifiedBadge(), SellerVerifiedBadge(compact: true)])));
    expect(find.byIcon(Icons.verified_user_rounded), findsNWidgets(2));
    expect(find.text('Vendeur vérifié'), findsOneWidget);   // la version complète seulement
    final icon = tester.widget<Icon>(find.byIcon(Icons.verified_user_rounded).first);
    expect(icon.color, SellerVerifiedBadge.green);
  });

  test('notifications de commandes : chaque type ouvre la bonne liste et a une phrase', () {
    expect(orderNotifTarget('ORDER_NEW'), 'sell');
    expect(orderNotifTarget('ORDER_REMIND'), 'sell');
    expect(orderNotifTarget('ORDER_SHIPPED'), 'buy');
    expect(orderNotifTarget('ORDER_FEE'), 'buy');
    expect(orderNotifTarget('OFFER_NEW'), 'offers');
    for (final t in kOrderNotifTypes) {
      expect(orderNotifText(t), isNotEmpty);
    }
    expect(orderNotifNeedsAction('ORDER_NEW'), isTrue);
    expect(orderNotifNeedsAction('ORDER_RECEIVED'), isFalse);
  });
}
