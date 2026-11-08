import 'package:afrotok/models/post_widget.dart';
import 'package:afrotok/widgets/post_widget_view.dart';
import 'package:afrotok/widgets/widgets_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget home) => MaterialApp(locale: const Locale('fr'), supportedLocales: const [Locale('fr')], localizationsDelegates: GlobalMaterialLocalizations.delegates, home: Scaffold(body: Center(child: home)));

void main() {
  tearDown(PostWidgetsLink.clear);

  test('un widget part à l\'API avec sa place, et se relit avec décomptes et réponse', () {
    final w = PostWidget(kind: WidgetKind.poll, config: {'question': 'Ton plat ?', 'options': ['Riz', 'Attiéké']}, x: .4, y: .5);
    expect(w.toApi(), {'type': 'poll', 'config': {'question': 'Ton plat ?', 'options': ['Riz', 'Attiéké']}, 'x': .4, 'y': .5, 'scale': 1.0});
    final r = PostWidget.fromApi({'id': 'w1', 'type': 'quiz', 'config': {'question': 'Q', 'options': ['a', 'b'], 'correct': 1}, 'x': .2, 'y': .7, 'scale': 1.2, 'counts': {'0': 3, '1': 5}, 'my_value': '1', 'responses_count': 8})!;
    expect((r.kind, r.id, r.counts['1'], r.myValue, r.responsesCount, r.correct), (WidgetKind.quiz, 'w1', 5, '1', 8, 1));
    expect(PostWidget.fromApi({'type': 'inconnu', 'config': {}}), isNull);
    expect(PostWidget.listFromApi([{'type': 'link', 'config': {'label': 'A', 'url': 'https://x'}}, {'type': 'bizarre'}, 'pas une carte']), hasLength(1));
  });

  test('au plus 3 widgets en cours d\'ajout ; la publication les prend une seule fois', () {
    for (var i = 0; i < 5; i++) {
      PostWidgetsLink.add(PostWidget(kind: WidgetKind.question, config: {'question': 'Q$i'}));
    }
    expect(PostWidgetsLink.drafts.value, hasLength(3));
    expect(PostWidgetsLink.isFull, isTrue);
    final taken = PostWidgetsLink.take()!;
    expect(taken, hasLength(3));
    expect(PostWidgetsLink.take(), isNull);   // lus une seule fois
    expect(PostWidgetsLink.drafts.value, isEmpty);
  });

  testWidgets('sondage : avant le vote des boutons, après le vote les pourcentages et mon choix coché', (tester) async {
    final w = PostWidget(id: 'w1', kind: WidgetKind.poll, config: {'question': 'Ton plat ?', 'options': ['Riz', 'Attiéké']});
    await tester.pumpWidget(_app(PostWidgetView(widget: w, preview: true)));
    expect(find.text('📊 Ton plat ?'), findsOneWidget);
    expect(find.text('Riz'), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);
    final voted = PostWidget(id: 'w1', kind: WidgetKind.poll, config: {'question': 'Ton plat ?', 'options': ['Riz', 'Attiéké']}, counts: {'0': 1, '1': 3}, myValue: '1', responsesCount: 4);
    await tester.pumpWidget(_app(PostWidgetView(widget: voted, preview: true)));
    expect(find.text('25 %'), findsOneWidget);
    expect(find.text('75 %'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
  });

  testWidgets('sondage : l\'auteur voit les pourcentages et le nombre de réponses sans avoir voté, un visiteur qui n\'a pas voté non', (tester) async {
    PostWidget mk({required bool author}) => PostWidget(kind: WidgetKind.poll, config: {'question': 'Ton plat ?', 'options': ['Riz', 'Attiéké']}, counts: {'0': 1, '1': 3}, responsesCount: 4, isAuthor: author);
    await tester.pumpWidget(_app(PostWidgetView(widget: mk(author: true))));
    expect(find.text('25 %'), findsOneWidget);
    expect(find.text('75 %'), findsOneWidget);
    expect(find.text('4 réponses'), findsOneWidget);
    await tester.pumpWidget(_app(PostWidgetView(widget: mk(author: false))));
    expect(find.textContaining('%'), findsNothing);
  });

  testWidgets('quiz : la bonne réponse est entourée une fois qu\'on a répondu ; compte à rebours, lien et carte de vente s\'affichent', (tester) async {
    final quiz = PostWidget(id: 'q', kind: WidgetKind.quiz, config: {'question': 'Capitale ?', 'options': ['Accra', 'Lomé'], 'correct': 1}, counts: {'1': 2}, myValue: '0', responsesCount: 2);
    await tester.pumpWidget(_app(PostWidgetView(widget: quiz, preview: true)));
    expect(find.text('🧠 Capitale ?'), findsOneWidget);
    final future = DateTime.now().toUtc().add(const Duration(days: 2, hours: 3));
    await tester.pumpWidget(_app(PostWidgetView(widget: PostWidget(kind: WidgetKind.countdown, config: {'title': 'Concert', 'at': future.toIso8601String()}), preview: true)));
    expect(find.text('⏳ Concert'), findsOneWidget);
    expect(find.textContaining(' j '), findsOneWidget);
    await tester.pumpWidget(_app(PostWidgetView(widget: PostWidget(kind: WidgetKind.link, config: {'label': 'Ma boutique', 'url': 'https://x.test'}), preview: true)));
    expect(find.text('🔗 Ma boutique'), findsOneWidget);
    await tester.pumpWidget(_app(PostWidgetView(widget: PostWidget(kind: WidgetKind.sale, config: {'product': 'Pagne wax', 'price': '8 000 F', 'place': 'Lomé', 'order_url': 'https://x.test/c'}), preview: true)));
    expect(find.text('🛍️ Pagne wax'), findsOneWidget);
    expect(find.text('8 000 F'), findsOneWidget);
    expect(find.text('Commander maintenant'), findsOneWidget);
    await tester.pumpWidget(_app(const SizedBox()));   // arrête le minuteur du compte à rebours
  });

  testWidgets('feuille « Ajouter un widget » : trois catégories, on choisit un sondage, on le remplit et il revient prêt à poser', (tester) async {
    PostWidget? out;
    await tester.pumpWidget(_app(Builder(builder: (ctx) => TextButton(onPressed: () async => out = await addWidgetFlow(ctx), child: const Text('go')))));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text('Ajouter un widget'), findsOneWidget);
    expect(find.text('INTERAGIR'), findsOneWidget);
    expect(find.text('VENDRE'), findsOneWidget);
    expect(find.byKey(const ValueKey('widget_kind_poll')), findsOneWidget);
    expect(find.byKey(const ValueKey('widget_kind_sale')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('widget_kind_poll')));
    await tester.pumpAndSettle();
    // formulaire incomplet : message d'erreur, rien n'est rendu
    await tester.tap(find.byKey(const ValueKey('wf_save')));
    await tester.pump();
    expect(find.text('Complète les champs demandés.'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('wf_question')), 'Ton plat préféré ?');
    await tester.enterText(find.byKey(const ValueKey('wo_0')), 'Riz');
    await tester.enterText(find.byKey(const ValueKey('wo_1')), 'Attiéké');
    await tester.tap(find.byKey(const ValueKey('wf_save')));
    await tester.pumpAndSettle();
    expect(out, isNotNull);
    expect((out!.kind, out!.question), (WidgetKind.poll, 'Ton plat préféré ?'));
    expect(out!.options, ['Riz', 'Attiéké']);
  });
}
