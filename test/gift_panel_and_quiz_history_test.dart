import 'dart:async';

import 'package:afrotok/pages/LiveAgora/live_game_ui.dart';
import 'package:afrotok/pages/LiveAgora/live_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final gifts = [
    Gift(id: 'a', name: 'Rose', price: 10, icon: '🌹', color: Colors.red),
    Gift(id: 'b', name: 'Couronne', price: 50, icon: '👑', color: Colors.amber),
    Gift(id: 'c', name: 'Diamant', price: 100, icon: '💎', color: Colors.blue),
  ];

  Widget host(Widget child) => MaterialApp(home: Scaffold(body: Stack(children: [child])));

  testWidgets('panneau de cadeaux : les cadeaux envoyés récemment sont sur une ligne en haut, les autres suivent', (tester) async {
    tester.view.physicalSize = const Size(1000, 2200);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host(GiftPanelWidget(gifts: gifts, recentIds: const ['c', 'a'], onGiftSelected: (_) async {}, onClose: () {})));
    expect(find.text('Envoyés récemment'), findsOneWidget);
    expect(find.text('Les autres cadeaux'), findsOneWidget);
    // les cadeaux récents (Diamant puis Rose) précèdent l'autre (Couronne) à l'écran
    final diamant = tester.getTopLeft(find.text('Diamant')).dy;
    final rose = tester.getTopLeft(find.text('Rose')).dy;
    final couronne = tester.getTopLeft(find.text('Couronne')).dy;
    expect(diamant, lessThan(couronne));
    expect(rose, lessThan(couronne));
    expect(tester.getTopLeft(find.text('Diamant')).dx, lessThan(tester.getTopLeft(find.text('Rose')).dx));   // le plus récent d'abord
  });

  testWidgets('panneau de cadeaux sans récents : « Tous les cadeaux » ; un toucher envoie et montre un sablier pendant l\'envoi, un second toucher est ignoré', (tester) async {
    tester.view.physicalSize = const Size(1000, 2200);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    final sent = <String>[];
    final done = Completer<void>();
    await tester.pumpWidget(host(GiftPanelWidget(gifts: gifts, onGiftSelected: (g) {
      sent.add(g.id);
      return done.future;
    }, onClose: () {})));
    expect(find.text('Envoyés récemment'), findsNothing);
    expect(find.text('Tous les cadeaux'), findsOneWidget);
    await tester.tap(find.text('Rose'));
    await tester.pump();
    expect(sent, ['a']);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.text('Diamant'));   // envoi déjà en cours : ignoré
    await tester.pump();
    expect(sent, ['a']);
    done.complete();
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('panneau de cadeaux : l\'hôte est prévenu qu\'il ne peut pas s\'offrir un cadeau', (tester) async {
    tester.view.physicalSize = const Size(1000, 2200);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host(GiftPanelWidget(gifts: gifts, isHost: true, onGiftSelected: (_) async {}, onClose: () {})));
    expect(find.textContaining('Tu es l\'hôte'), findsOneWidget);
  });

  testWidgets('historique du quiz : bonne réponse en vert, ma mauvaise réponse en rouge, taux de réussite et podium', (tester) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    final quiz = {
      'status': 'ended', 'started_at': '2026-11-14T12:00:00Z', 'total': 2, 'pool': 1000,
      'questions': [
        {'index': 0, 'text': 'Capitale du Ghana ?', 'options': ['Kumasi', 'Accra', 'Lomé'], 'correct': 1, 'my_option': 0, 'answers': 4, 'correct_count': 3},
        {'index': 1, 'text': '2 + 2 ?', 'options': ['3', '4'], 'correct': 1, 'my_option': 1, 'answers': 0, 'correct_count': 0},
      ],
      'podium': [
        {'rank': 1, 'username': 'ama', 'points': 1800, 'coins': 500},
      ],
    };
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: LiveQuizHistorySheet(future: Future.value([quiz])))));
    await tester.pumpAndSettle();
    expect(find.text('Historique du quiz'), findsOneWidget);
    expect(find.textContaining('Capitale du Ghana ?'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsNWidgets(2));   // la bonne réponse de chaque question
    expect(find.byIcon(Icons.cancel_rounded), findsOneWidget);           // ma mauvaise réponse à la première
    expect(find.textContaining('75 % de bonnes réponses'), findsOneWidget);
    expect(find.text('Personne n\'a répondu.'), findsOneWidget);
    expect(find.textContaining('@ama · 1800 pts · +500'), findsOneWidget);
  });

  testWidgets('historique du quiz : message clair quand aucune question n\'est encore révélée', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: LiveQuizHistorySheet(future: Future.value([{'status': 'active', 'questions': [], 'podium': [], 'total': 3}])))));
    await tester.pumpAndSettle();
    expect(find.textContaining('Aucune question révélée'), findsOneWidget);
  });
}
