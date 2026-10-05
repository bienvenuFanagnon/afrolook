import 'package:afrotok/pages/quiz/widgets/hawk_mascot.dart';
import 'package:afrotok/pages/quiz/widgets/quiz_loading.dart';
import 'package:afrotok/pages/quiz/widgets/quiz_widgets.dart';
import 'package:afrotok/services/quiz/quiz_sound.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('la mascotte se dessine dans toutes les humeurs et avec tous les accessoires', (tester) async {
    for (final mood in HawkMood.values) {
      for (final acc in [null, 'acc_glasses', 'acc_cap', 'acc_crown']) {
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: Center(child: HawkMascot(mood: mood, size: 140, accessory: acc)))));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 900));
        expect(tester.takeException(), isNull, reason: '$mood / $acc');
      }
    }
  });

  testWidgets('la mascotte change d\'humeur sans erreur', (tester) async {
    Widget app(HawkMood m) => MaterialApp(home: Scaffold(body: HawkMascot(mood: m)));
    await tester.pumpWidget(app(HawkMood.idle));
    await tester.pumpWidget(app(HawkMood.cheer));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpWidget(app(HawkMood.sad));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
  });

  testWidgets('bouton, réponses et bulle', (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ListView(children: [
          QuizChunkyButton(label: 'Continuer', onPressed: () => taps++),
          const QuizChunkyButton(label: 'Désactivé', onPressed: null),
          for (final st in QuizOptionState.values) QuizOption(letter: 'A', text: 'Réponse', state: st, onTap: () {}),
          const QuizBubble(child: Text('Salut !')),
          const QuizPill(icon: Icons.star, label: '12', color: Colors.amber),
        ]),
      ),
    ));
    await tester.tap(find.text('CONTINUER'));
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });

  test('les sons fabriqués sont des fichiers WAV valides', () {
    for (final s in QuizSfx.values) {
      final b = QuizSound.debugWav(s);
      expect(String.fromCharCodes(b.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(b.sublist(8, 12)), 'WAVE');
      expect(b.length, greaterThan(1000));
      expect(b.length, lessThan(100000));
    }
  });

  test('drapeaux et unités', () {
    expect(quizFlag('TG'), '🇹🇬');
    expect(quizFlag(''), '🌍');
    expect(quizUnitOf(1), 0);
    expect(quizUnitOf(5), 0);
    expect(quizUnitOf(6), 1);
    expect(quizUnitOf(200), 39);
    expect(quizThemeOfUnit(8).key, 'courage');
    expect(quizClock(125), '02:05');
  });

  testWidgets("l'attente anime l'épervier et fait défiler les phrases", (tester) async {
    for (final kind in QuizLoadingKind.values) {
      for (final compact in [false, true]) {
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: QuizLoading(kind: kind, compact: compact))));
        final first = tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).toList();
        for (var k = 0; k < 6; k++) {
          await tester.pump(const Duration(milliseconds: 1900));
        }
        final later = tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).toList();
        expect(later, isNot(equals(first)), reason: '$kind');
        expect(tester.takeException(), isNull, reason: '$kind');
        await tester.pumpWidget(const SizedBox());
      }
    }
  });

  testWidgets("l'épervier s'agite et se dessine sans erreur", (tester) async {
    for (final mood in HawkMood.values) {
      for (final speaking in [false]) {
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: Center(child: HawkMascot(mood: mood, size: 140)))));
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump(const Duration(milliseconds: 700));
        expect(tester.takeException(), isNull, reason: '$mood / $speaking');
      }
    }
  });

  testWidgets("la réponse choisie pulse pendant la vérification", (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(children: [
          QuizOption(letter: 'A', text: 'Réponse', state: QuizOptionState.selected, checking: true, onTap: null),
          const QuizChecking(),
        ]),
      ),
    ));
    final first = tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).toList();
    for (var k = 0; k < 4; k++) {
      await tester.pump(const Duration(milliseconds: 1200));
    }
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).toList(), isNot(equals(first)));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
