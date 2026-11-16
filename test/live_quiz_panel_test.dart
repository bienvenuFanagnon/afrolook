import 'dart:async';

import 'package:afrotok/pages/LiveAgora/live_game_ui.dart';
import 'package:afrotok/pages/LiveAgora/live_quiz_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Quiz à cagnotte des lives, nouvelle version (maquette validée le 15/11/2026).
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({'quiz_sound_muted': true}));   // pas de son pendant les tests

  LiveGame game(Map<String, dynamic> quiz, {List winners = const [], String status = 'active'}) =>
      LiveGame({'id': 'g1', 'kind': 'quiz', 'status': status, 'config': {}, 'quiz': {'v': 2, 'mode': 'planned', 'winners_count': 3, 'theme': 'scene', 'index': 0, 'total': 2, ...quiz}, 'winners': winners});

  Future<void> pump(WidgetTester t, Widget w) async {
    t.view.physicalSize = const Size(900, 2200);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(locale: const Locale('fr'), supportedLocales: const [Locale('fr')], localizationsDelegates: GlobalMaterialLocalizations.delegates, home: Scaffold(body: SingleChildScrollView(child: Padding(padding: const EdgeInsets.all(12), child: w)))));
  }

  Future<void> close(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());   // arrête les minuteries et animations du panneau
    await t.pump(const Duration(seconds: 3));
  }

  test('coût et partage : mêmes calculs que le serveur', () {
    expect(quizCost(90), 100);
    expect(quizCost(100), 112);
    expect(quizCost(180), 200);
    expect(quizCost(0), 0);
    expect(quizSplit(90, 3), [45, 30, 15]);
    expect(quizSplit(100, 5), [33, 26, 20, 13, 6]);
    expect(quizSplit(100, 20).length, 20);
  });

  testWidgets('toucher une réponse : un cercle tourne dans le choix, plus rien n\'est touchable, puis « enregistrée »', (t) async {
    final done = Completer<bool>();
    final taps = <int>[];
    final options = ['Togo', 'Kenya', 'Bénin', 'Égypte', 'Ghana', 'Ouganda', 'Zambie', 'Tanzanie', 'Mali', 'Chine'];
    await pump(t, LiveQuizPanel(game: game({'stage': 'answer', 'left': 18, 'seconds': 20, 'pot': 250, 'text': 'Pays d\'Afrique de l\'Ouest ?', 'options': options, 'multi': true}), isHost: false, onAnswer: (i) {
      taps.add(i);
      return done.future;
    }));
    expect(find.byKey(const ValueKey('quiz_jackpot')), findsOneWidget);
    for (var i = 0; i < 10; i++) {
      expect(find.byKey(ValueKey('quiz_opt_$i')), findsOneWidget);
    }
    await t.tap(find.byKey(const ValueKey('quiz_opt_8')));
    await t.pump();
    expect(find.descendant(of: find.byKey(const ValueKey('quiz_opt_8')), matching: find.byType(CircularProgressIndicator)), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('quiz_opt_1')));   // deuxième toucher pendant l'envoi : ignoré
    await t.pump();
    expect(taps, [8]);
    done.complete(true);
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    expect(find.descendant(of: find.byKey(const ValueKey('quiz_opt_8')), matching: find.byIcon(Icons.check_rounded)), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('quiz_opt_2')));   // déjà répondu : ignoré
    await t.pump();
    expect(taps, [8]);
    await close(t);
  });

  testWidgets('réponse refusée (temps fini, réseau) : le joueur peut retoucher', (t) async {
    var calls = 0;
    await pump(t, LiveQuizPanel(game: game({'stage': 'answer', 'left': 9, 'seconds': 15, 'pot': 100, 'text': 'Capitale du Ghana ?', 'options': ['Kumasi', 'Accra']}), isHost: false, onAnswer: (i) async {
      calls++;
      return calls > 1;
    }));
    await t.tap(find.byKey(const ValueKey('quiz_opt_1')));
    await t.pump();
    await t.pump();
    await t.tap(find.byKey(const ValueKey('quiz_opt_1')));
    await t.pump();
    expect(calls, 2);
    await close(t);
  });

  testWidgets('révélation : bonnes réponses en vert, gain du joueur, gagnants de la question', (t) async {
    await pump(t, LiveQuizPanel(game: game({
      'stage': 'reveal', 'left': 5, 'seconds': 15, 'pot': 90, 'text': 'Capitale du Ghana ?', 'options': ['Kumasi', 'Accra', 'Lomé'], 'correct_list': [1], 'my_option': 1, 'my_gain': 22,
      'question_winners': [
        {'user_id': 'a', 'username': 'ama', 'rank': 1, 'coins': 45},
        {'user_id': 'b', 'username': 'moi', 'rank': 2, 'coins': 22},
      ],
    }), isHost: false, onAnswer: (_) async => true));
    expect(find.descendant(of: find.byKey(const ValueKey('quiz_opt_1')), matching: find.byIcon(Icons.check_circle_rounded)), findsOneWidget);
    expect(find.textContaining('22'), findsWidgets);
    expect(find.text('@ama'), findsOneWidget);
    expect(find.text('+45'), findsOneWidget);
    await close(t);
  });

  testWidgets('préparation : la question reste cachée, compte à rebours et prochaine cagnotte', (t) async {
    await pump(t, LiveQuizPanel(game: game({'stage': 'prep', 'left': 4, 'next_pot': 500, 'text': null, 'options': []}), isHost: false, onAnswer: (_) async => true));
    expect(find.text('4'), findsOneWidget);
    expect(find.byKey(const ValueKey('quiz_opt_0')), findsNothing);
    expect(find.byKey(const ValueKey('quiz_jackpot')), findsOneWidget);
    await close(t);
  });

  testWidgets('hôte en direct : entre deux questions, « Envoyer une question » est actif ; bonnes réponses visibles pour lui seul', (t) async {
    var sent = 0;
    await pump(t, LiveQuizPanel(
      game: game({'mode': 'live', 'stage': 'wait', 'left': 0, 'answers': 312, 'pot': 100, 'host_questions': [
        {'text': 'Capitale ?', 'options': ['Kumasi', 'Accra'], 'correct': [1], 'seconds': 15, 'pot': 100, 'cost': 112, 'done': true},
      ]}),
      isHost: true,
      onAnswer: (_) async => true,
      onSendQuestion: () => sent++,
    ));
    await t.tap(find.byKey(const ValueKey('quiz_send_question')));
    await t.pump();
    expect(sent, 1);
    expect(find.text('312'), findsOneWidget);
    await close(t);
  });

  testWidgets('éditeur de question : jusqu\'à 10 choix, plusieurs bonnes réponses, erreurs claires', (t) async {
    QuizQ? got;
    await pump(t, Builder(builder: (ctx) => TextButton(onPressed: () async => got = await showQuizQuestionEditor(ctx, defSeconds: 30, defPot: 100), child: const Text('ouvrir'))));
    await t.tap(find.text('ouvrir'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('quiz_q_ok')));   // rien de rempli : erreur, la fenêtre reste
    await t.pump();
    expect(find.byKey(const ValueKey('quiz_q_ok')), findsOneWidget);
    await t.enterText(find.byKey(const ValueKey('quiz_q_text')), 'Pays d\'Afrique de l\'Ouest ?');
    await t.enterText(find.byKey(const ValueKey('quiz_q_opt_0')), 'Togo');
    await t.enterText(find.byKey(const ValueKey('quiz_q_opt_1')), 'Kenya');
    await t.enterText(find.byKey(const ValueKey('quiz_q_opt_2')), 'Bénin');
    await t.tap(find.byKey(const ValueKey('quiz_q_add_option')));
    await t.pump();
    await t.enterText(find.byKey(const ValueKey('quiz_q_opt_3')), 'Chine');
    await t.tap(find.byKey(const ValueKey('quiz_q_correct_0')));
    await t.tap(find.byKey(const ValueKey('quiz_q_correct_2')));
    await t.pump();
    await t.ensureVisible(find.byKey(const ValueKey('quiz_q_ok')));
    await t.tap(find.byKey(const ValueKey('quiz_q_ok')));
    await t.pumpAndSettle();
    expect(got?.options, ['Togo', 'Kenya', 'Bénin', 'Chine']);
    expect(got?.correct, {0, 2});
    expect(got?.seconds, 30);
    expect(got?.pot, 100);
    expect(got?.toJson()['correct'], [0, 2]);
  });

  test('réglages lus depuis le live : bornes et questions préparées', () {
    final s = QuizSettings.fromOptions({
      'quiz': {'winners': 50, 'seconds': 60, 'pot': 250, 'theme': 'neon', 'questions': [{'text': 'Q ?', 'options': ['a', 'b'], 'correct': [1], 'seconds': 15, 'pot': 90}]},
    });
    expect(s.winners, 20);
    expect(s.theme, 'neon');
    expect(s.questions.single.correct, {1});
    expect(s.listCost, 100);
    expect(QuizSettings.fromOptions(null).winners, 3);
  });

  testWidgets('sur un téléphone, 10 choix tiennent dans un panneau court ; réduit, il ne fait qu\'une barre et se rouvre à la question suivante', (t) async {
    final options = ['Togo', 'Kenya', 'Bénin', 'Égypte', 'Ghana', 'Ouganda', 'Zambie', 'Tanzanie', 'Mali', 'Chine'];
    Widget panel(int index) => Center(child: SizedBox(width: 304, child: LiveQuizPanel(   // largeur réelle : écran de 390 moins la colonne des boutons à droite
          game: game({'stage': 'answer', 'index': index, 'total': 10, 'left': 18, 'seconds': 20, 'pot': 250, 'text': 'Lesquels sont en Afrique de l\'Ouest ?', 'options': options, 'multi': true}),
          isHost: false,
          onAnswer: (_) async => true,
        )));
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(locale: const Locale('fr'), supportedLocales: const [Locale('fr')], localizationsDelegates: GlobalMaterialLocalizations.delegates, home: Scaffold(body: panel(0))));
    final full = t.getSize(find.byType(LiveQuizPanel)).height;
    expect(full, lessThan(310));   // environ un tiers de l'écran : la vidéo, la discussion et les cadeaux restent visibles
    // ignore: avoid_print
    print('hauteur du quiz avec 10 choix : $full');
    await t.tap(find.byKey(const ValueKey('quiz_reduce')));
    await t.pumpAndSettle(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('quiz_opt_0')), findsNothing);
    expect(find.byKey(const ValueKey('quiz_reduced_line')), findsOneWidget);
    expect(t.getSize(find.byType(LiveQuizPanel)).height, lessThan(56));   // une seule ligne
    await t.pumpWidget(MaterialApp(locale: const Locale('fr'), supportedLocales: const [Locale('fr')], localizationsDelegates: GlobalMaterialLocalizations.delegates, home: Scaffold(body: panel(1))));   // question suivante
    await t.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('quiz_opt_0')), findsOneWidget);
    await close(t);
  });

  testWidgets('image épinglée par l\'hôte : visible dans la question, la toucher l\'agrandit ; croix dans l\'en-tête', (t) async {
    var opened = 0;
    var closed = 0;
    await pump(t, LiveQuizPanel(
      game: game({'stage': 'answer', 'left': 9, 'seconds': 15, 'pot': 100, 'text': 'Quel monument est sur l\'image ?', 'options': ['Pyramide', 'Tour Eiffel', 'Colisée', 'Taj Mahal']}),
      isHost: true,
      onAnswer: (_) async => true,
      imageUrl: 'https://exemple.test/image.jpg',
      onOpenImage: () => opened++,
      onClose: () => closed++,
    ));
    await t.tap(find.byKey(const ValueKey('quiz_pin_image')));
    await t.tap(find.byKey(const ValueKey('quiz_close')));
    await t.pump();
    expect(opened, 1);
    expect(closed, 1);
    await close(t);
  });

  testWidgets('questions Afrolook : thème et nombre choisis, coût affiché, lancement ; plus de gratuits = bouton Gold', (t) async {
    final packs = {
      'themes': [{'id': 'mix', 'label': 'Mélange'}, {'id': 'football', 'label': 'Sport'}, {'id': 'histoire', 'label': 'Histoire'}],
      'counts': [5, 10, 20], 'free_per_month': 2, 'free_left': 1, 'gold': false,
    };
    var theme = 'mix';
    var count = 10;
    var launched = 0;
    var upgrade = 0;
    Widget box(Map<String, dynamic> p) => StatefulBuilder(builder: (_, setS) => QuizPacksBox(
          packs: p, theme: theme, count: count, pot: 90,
          onTheme: (v) => setS(() => theme = v), onCount: (v) => setS(() => count = v),
          onLaunch: () => launched++, onUpgrade: () => upgrade++,
        ));
    await pump(t, box(packs));
    expect(find.text('1 sur 2 gratuits ce mois-ci'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('quiz_pack_theme_football')));
    await t.pump();
    await t.tap(find.byKey(const ValueKey('quiz_pack_count_5')));
    await t.pump();
    expect(theme, 'football');
    expect(find.text('Lancer 5 questions · 500 pièces'), findsOneWidget);   // 5 × 100 (90 à gagner par question)
    await t.tap(find.byKey(const ValueKey('quiz_launch_pack')));
    expect(launched, 1);

    await pump(t, box({...packs, 'free_left': 0}));
    expect(find.text('Passer à Gold pour continuer'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('quiz_launch_pack')));
    expect(upgrade, 1);
    expect(launched, 1);

    await pump(t, box({...packs, 'free_left': null, 'gold': true}));
    expect(find.text('Illimité avec Gold'), findsOneWidget);
  });

  testWidgets('quiz sans cagnotte (prix remis en personne) : points et place au lieu des pièces, classement final et bouton du classement', (t) async {
    var opened = 0;
    await pump(t, LiveQuizPanel(game: game({
      'stage': 'reveal', 'left': 5, 'seconds': 15, 'pot': 0, 'text': 'Capitale du Ghana ?', 'options': ['Kumasi', 'Accra'], 'correct_list': [1], 'my_option': 1, 'my_q_points': 820, 'my_rank': 2,
      'question_winners': [{'user_id': 'a', 'username': 'ama', 'rank': 1, 'coins': 0, 'points': 940}],
    }), isHost: false, onAnswer: (_) async => true));
    expect(find.text('+820 pts · place 2'), findsOneWidget);
    expect(find.text('940 pts'), findsOneWidget);
    expect(find.byKey(const ValueKey('quiz_jackpot')), findsNothing);   // pas de cagnotte affichée
    await close(t);

    await pump(t, LiveQuizPanel(
      game: game({'stage': 'done', 'pot': 0, 'ranking': [{'user_id': 'a', 'username': 'ama', 'points': 2450}, {'user_id': 'b', 'username': 'kofi', 'points': 1800}]}, winners: [{'user_id': 'a', 'username': 'ama', 'rank': 1, 'coins': 0}], status: 'ended'),
      isHost: false, onAnswer: (_) async => true, onShowRanking: () => opened++,
    ));
    expect(find.text('CLASSEMENT FINAL'), findsOneWidget);
    expect(find.textContaining('450 pts'), findsOneWidget);   // séparateur des milliers insécable
    await t.tap(find.byKey(const ValueKey('quiz_full_ranking')));
    expect(opened, 1);
    await close(t);
  });

  testWidgets('réglages : « prix remis en personne » par défaut (aucune pièce), « cagnotte en pièces » au choix', (t) async {
    final s = QuizSettings();
    expect(s.physical, isTrue);
    await pump(t, StatefulBuilder(builder: (_, setS) => QuizSettingsEditor(settings: s, isGold: false, onChanged: () => setS(() {}))));
    expect(find.byKey(const ValueKey('quiz_winners')), findsNothing);   // pas de gagnants en pièces à régler
    await t.tap(find.byKey(const ValueKey('quiz_reward_coins')));
    await t.pump(const Duration(milliseconds: 300));
    expect(s.pot, 100);
    expect(find.byKey(const ValueKey('quiz_winners')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('quiz_reward_physical')));
    await t.pump(const Duration(milliseconds: 300));
    expect(s.pot, 0);
    await close(t);
  });

  testWidgets('classement complet : les 20 premiers, ma place à part, copie pour l\'hôte', (t) async {
    final data = {
      'final': true, 'questions': 5, 'players': 42, 'top': 20,
      'rows': [for (var i = 1; i <= 20; i++) {'rank': i, 'user_id': 'u$i', 'username': 'joueur$i', 'points': 3000 - i * 10, 'correct': 5 - (i ~/ 5), 'coins': 0}],
      'me': {'rank': 31, 'user_id': 'moi', 'points': 1200, 'correct': 2, 'coins': 0},
    };
    await pump(t, SizedBox(height: 1600, child: QuizRankingSheet(future: Future.value(data), isHost: true)));
    await t.pump();
    expect(find.text('Classement final'), findsOneWidget);
    expect(find.text('42 joueurs · 5 questions · les 20 premiers'), findsOneWidget);
    expect(find.byKey(const ValueKey('quiz_rank_31')), findsOneWidget);   // ma place, hors des 20
    expect(find.byKey(const ValueKey('quiz_ranking_copy')), findsOneWidget);
    expect(QuizRankingSheet.asText(t.element(find.byType(QuizRankingSheet)), data).split('\n').length, 21);
  });

  test('durée d\'un quiz enchaîné : temps de chaque question + 11 s (résultat et préparation)', () {
    expect(quizListSeconds([15, 30]), 67);
    expect(quizListSeconds(List.filled(10, 15)), 260);
  });

  testWidgets('avertissement : le quiz dépasse le temps qui reste au live', (t) async {
    await pump(t, Builder(builder: (ctx) => Column(children: [
          quizDurationNote(ctx, 50 * 60, 20 * 60),
          quizDurationNote(ctx, 5 * 60, 20 * 60),
        ])));
    expect(find.byKey(const ValueKey('quiz_duration_over')), findsOneWidget);
    expect(find.byKey(const ValueKey('quiz_duration_ok')), findsOneWidget);
    expect(find.textContaining('il ne reste que 20 min'), findsOneWidget);
  });
}
