import 'package:afrotok/pages/LiveAgora/live_game_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Quiz du live (15/11/2026) : une question peut durer de 15 secondes à 30 minutes ; la durée totale s'affiche avant de lancer.
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

  test('libellés et compte à rebours en minutes', () {
    expect(kQuizSecondsChoices.last, kQuizMaxSeconds);
    expect(kQuizMaxSeconds, 1800);
    expect(clock(1800), '30:00');
    expect(clock(75), '01:15');
  });
}
