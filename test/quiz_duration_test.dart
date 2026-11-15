import 'package:afrotok/pages/LiveAgora/live_game_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Quiz du live (15/11/2026) : une question peut durer de 15 secondes à 30 minutes ; la durée totale s'affiche avant de lancer.
/// Sondage : l'hôte choisit sa durée (1, 2, 5, 10 ou 30 minutes).
void main() {
  testWidgets('l\'hôte choisit 30 minutes par question, voit la durée totale et le quiz part avec 1800 secondes', (tester) async {
    tester.view.physicalSize = const Size(900, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    ({List<QuizDraft> questions, int pool, int seconds})? got;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (ctx) => Scaffold(body: TextButton(onPressed: () async => got = await askQuiz(ctx), child: const Text('ouvrir')))),
    ));
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('quiz_secs_15')), findsOneWidget);
    expect(find.text('30 min'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Capitale du Ghana ? | Kumasi | Accra*\n2 + 2 ? | 3 | 4*');
    await tester.tap(find.byKey(const ValueKey('quiz_secs_1800')));
    await tester.pumpAndSettle();
    // 2 questions × (30 min + 4 s pour la réponse) = 60 min 8 s
    expect(find.textContaining('60 min 8 s'), findsOneWidget);
    await tester.tap(find.byType(FilledButton));   // « Lancer »
    await tester.pumpAndSettle();
    expect(got?.seconds, 1800);
    expect(got?.questions.length, 2);
  });

  testWidgets("sondage : l'hôte choisit 1, 2, 5, 10 ou 30 minutes (2 par défaut) ; la durée part avec la question", (tester) async {
    tester.view.physicalSize = const Size(900, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    List<String>? got;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (ctx) => Scaffold(body: TextButton(
        onPressed: () async => got = await askFields(ctx, title: 'Sondage', fields: [
          (label: 'Question', hint: '', number: false, initial: ''),
          (label: 'Choix 1', hint: '', number: false, initial: ''),
          (label: 'Choix 2', hint: '', number: false, initial: ''),
          (label: 'Choix 3', hint: '', number: false, initial: ''),
        ], minuteChoices: kPollMinuteChoices, initialMinutes: 2),
        child: const Text('ouvrir'),
      ))),
    ));
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();
    for (final m in [1, 2, 5, 10, 30]) {
      expect(find.byKey(ValueKey('minutes_$m')), findsOneWidget);
    }
    expect(tester.widget<ChoiceChip>(find.byKey(const ValueKey('minutes_2'))).selected, isTrue);
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Quelle chanson ?');
    await tester.enterText(fields.at(1), 'Afro');
    await tester.enterText(fields.at(2), 'Coupé-décalé');
    await tester.tap(find.byKey(const ValueKey('minutes_10')));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    final poll = pollFromFields(got!);
    expect(poll.question, 'Quelle chanson ?');
    expect(poll.options, ['Afro', 'Coupé-décalé']);   // le choix 3 vide est retiré, la durée n'est pas prise pour un choix
    expect(poll.minutes, 10);
  });

  test('libellés et compte à rebours en minutes', () {
    expect(kQuizSecondsChoices.last, kQuizMaxSeconds);
    expect(kQuizMaxSeconds, 1800);
    expect(clock(1800), '30:00');
    expect(clock(75), '01:15');
  });
}
