import 'package:afrotok/pages/LiveAgora/live_game_ui.dart';
import 'package:afrotok/services/coin_checkout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// Historique des jeux d'un live (16/11/2026) : podium du quiz et classement complet, classement des soutiens du conte, icônes à la place des emojis.
void main() {
  final games = <Map<String, dynamic>>[
    {
      'id': 'q1', 'kind': 'quiz', 'status': 'ended', 'started_at': '2026-11-16T20:00:00Z', 'config': {}, 'winners': [], 'players': 12,
      'podium': [
        {'rank': 1, 'user_id': 'a', 'username': 'ana', 'points': 2400, 'coins': 0},
        {'rank': 2, 'user_id': 'b', 'username': 'bob', 'points': 1800, 'coins': 0},
        {'rank': 3, 'user_id': 'c', 'username': 'cia', 'points': 900, 'coins': 0},
      ],
    },
    {
      'id': 's1', 'kind': 'story', 'status': 'ended', 'started_at': '2026-11-16T19:00:00Z', 'config': {'question': 'Que fait le héros ?', 'options': ['Il ouvre', 'Il fuit']},
      'votes': [30, 10], 'winner_option': 0,
      'ranking': [
        {'rank': 1, 'user_id': 'a', 'username': 'ana', 'coins': 20},
        {'rank': 2, 'user_id': 'd', 'username': 'dan', 'coins': 10},
        {'rank': 3, 'user_id': 'e', 'username': 'eve', 'coins': 10},
        {'rank': 4, 'user_id': 'f', 'username': 'fab', 'coins': 10},
      ],
    },
  ];

  Future<void> pump(WidgetTester t, Widget w) async {
    t.view.physicalSize = const Size(900, 2000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(locale: const Locale('fr'), supportedLocales: const [Locale('fr')], localizationsDelegates: GlobalMaterialLocalizations.delegates, home: Scaffold(body: w)));
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
  }

  testWidgets('quiz terminé sans cagnotte : podium par points, nombre de joueurs, bouton du classement complet', (t) async {
    String? opened;
    await pump(t, LiveGamesHistorySheet(future: Future.value(games), onQuiz: () {}, onQuizRanking: (id) => opened = id));
    expect(find.byKey(const ValueKey('quiz_podium_q1_1')), findsOneWidget);
    expect(find.text('@ana'), findsOneWidget);
    expect(find.text('${CoinCheckout.fmt(2400)} pts'), findsOneWidget);
    expect(find.text('12 joueurs'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('quiz_ranking_q1')));
    expect(opened, 'q1');
  });

  testWidgets('conte terminé : meilleurs soutiens et classement complet dans sa fenêtre', (t) async {
    await pump(t, LiveGamesHistorySheet(future: Future.value(games)));
    expect(find.textContaining('Meilleurs soutiens'), findsOneWidget);
    await t.ensureVisible(find.byKey(const ValueKey('story_ranking_s1')));
    await t.tap(find.byKey(const ValueKey('story_ranking_s1')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('story_ranking_sheet')), findsOneWidget);
    expect(find.byKey(const ValueKey('story_rank_4')), findsOneWidget);
    expect(find.text('20 pièces'), findsWidgets);
  });

  testWidgets('aucun emoji dans l\'historique : médailles et coches en icônes', (t) async {
    await pump(t, LiveGamesHistorySheet(future: Future.value(games), onQuiz: () {}, onQuizRanking: (_) {}));
    final emoji = RegExp('[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}]', unicode: true);
    for (final w in t.widgetList<RichText>(find.byType(RichText))) {
      expect(emoji.hasMatch(w.text.toPlainText()), isFalse, reason: w.text.toPlainText());
    }
    expect(find.byIcon(Icons.emoji_events_rounded), findsWidgets);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);   // choix gagnant du conte
  });
}
