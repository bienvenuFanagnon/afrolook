import 'package:afrotok/pages/LiveAgora/live_quiz_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// Séries de questions enregistrées (Gold) et questions Afrolook choisies à la création du live (16/11/2026).
void main() {
  QuizQ q(String t) => QuizQ(text: t, options: ['A', 'B', 'C'], correct: {0}, seconds: 30, pot: 0);

  /// Faux serveur : garde les séries en mémoire.
  QuizSeriesStore fakeStore(List<QuizSeriesItem> db, {String? refuse}) {
    var n = 0;
    return QuizSeriesStore(
      list: () async => List.of(db),
      save: (id, name, questions) async {
        if (refuse != null) throw QuizSeriesError(refuse);
        final it = QuizSeriesItem(id: id ?? 's${++n}', name: name, questions: questions);
        db.removeWhere((x) => x.id == it.id);
        db.insert(0, it);
        return it;
      },
      delete: (id) async => db.removeWhere((x) => x.id == id),
    );
  }

  // les fonds illustrés du quiz bougent sans fin : pas de pumpAndSettle
  Future<void> settle(WidgetTester t) async {
    for (var i = 0; i < 12; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> pump(WidgetTester t, Widget w) async {
    t.view.physicalSize = const Size(900, 2400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: Scaffold(body: SingleChildScrollView(child: w)),
    ));
  }

  testWidgets('enregistrer la liste comme série nommée, puis la recharger dans une autre liste', (t) async {
    final db = <QuizSeriesItem>[];
    final s = QuizSettings(questions: [q('Capitale du Togo ?'), q('Plus grand océan ?')]);
    await pump(t, StatefulBuilder(builder: (_, setS) => QuizSettingsEditor(settings: s, isGold: true, onChanged: () => setS(() {}), series: fakeStore(db))));

    await t.tap(find.byKey(const ValueKey('quiz_series_save')));
    await settle(t);
    await t.enterText(find.byKey(const ValueKey('quiz_series_name')), 'Culture générale');
    await t.tap(find.byKey(const ValueKey('quiz_series_save_ok')));
    await settle(t);
    expect(db.single.name, 'Culture générale');
    expect(db.single.questions.map((x) => x.text), ['Capitale du Togo ?', 'Plus grand océan ?']);
    expect(find.text('Série : Culture générale'), findsOneWidget);

    // nouvelle liste vide (autre live) : « Mes séries » puis toucher la série la charge
    final s2 = QuizSettings();
    await pump(t, StatefulBuilder(builder: (_, setS) => QuizSettingsEditor(key: const ValueKey('e2'), settings: s2, isGold: true, onChanged: () => setS(() {}), series: fakeStore(db))));
    expect(find.byKey(const ValueKey('quiz_series_save')), findsNothing);   // rien à enregistrer tant que la liste est vide
    await t.tap(find.byKey(const ValueKey('quiz_series_open')));
    await settle(t);
    await t.tap(find.byKey(const ValueKey('quiz_series_s1')));
    await settle(t);
    expect(s2.questions.map((x) => x.text), ['Capitale du Togo ?', 'Plus grand océan ?']);
    // les questions chargées sont des copies : les modifier ne change pas la série gardée
    s2.questions.first.text = 'Modifiée';
    expect(db.single.questions.first.text, 'Capitale du Togo ?');
  });

  testWidgets('liste déjà remplie : ajouter la série à la suite ; supprimer une série après confirmation ; refus du serveur affiché', (t) async {
    final db = [QuizSeriesItem(id: 'x', name: 'Sport', questions: [q('Champion 2022 ?')])];
    final s = QuizSettings(questions: [q('Première ?')]);
    await pump(t, StatefulBuilder(builder: (_, setS) => QuizSettingsEditor(settings: s, isGold: true, onChanged: () => setS(() {}), series: fakeStore(db))));
    await t.tap(find.byKey(const ValueKey('quiz_series_open')));
    await settle(t);
    await t.tap(find.byKey(const ValueKey('quiz_series_x')));
    await settle(t);
    await t.tap(find.byKey(const ValueKey('quiz_series_append')));
    await settle(t);
    expect(s.questions.map((x) => x.text), ['Première ?', 'Champion 2022 ?']);

    await t.tap(find.byKey(const ValueKey('quiz_series_open')));
    await settle(t);
    await t.tap(find.byKey(const ValueKey('quiz_series_delete_x')));
    await settle(t);
    await t.tap(find.byKey(const ValueKey('quiz_series_delete_ok')));
    await settle(t);
    expect(db, isEmpty);
    expect(find.byKey(const ValueKey('quiz_series_empty')), findsOneWidget);
    Navigator.of(t.element(find.byKey(const ValueKey('quiz_series_empty')))).pop();
    await settle(t);

    // le serveur refuse (20 séries) : son message s'affiche
    await pump(t, StatefulBuilder(builder: (_, setS) => QuizSettingsEditor(key: const ValueKey('e3'), settings: s, isGold: true, onChanged: () => setS(() {}), series: fakeStore([], refuse: 'Tu as déjà 20 séries.'))));
    await t.tap(find.byKey(const ValueKey('quiz_series_save')));
    await settle(t);
    await t.enterText(find.byKey(const ValueKey('quiz_series_name')), 'Encore');
    await t.tap(find.byKey(const ValueKey('quiz_series_save_ok')));
    await settle(t);
    expect(find.text('Tu as déjà 20 séries.'), findsOneWidget);
  });

  testWidgets('sans Gold ou sans accès aux séries : boutons cachés', (t) async {
    await pump(t, QuizSettingsEditor(settings: QuizSettings(questions: [q('Une ?')]), isGold: false, onChanged: () {}, series: fakeStore([])));
    expect(find.byKey(const ValueKey('quiz_series_open')), findsNothing);
    await pump(t, QuizSettingsEditor(key: const ValueKey('g'), settings: QuizSettings(questions: [q('Une ?')]), isGold: true, onChanged: () {}));
    expect(find.byKey(const ValueKey('quiz_series_open')), findsNothing);
  });

  test('questions Afrolook choisies à la création : envoyées avec les réglages et relues dans le live', () {
    final s = QuizSettings()..pack = (theme: 'histoire', count: 20);
    expect(s.toJson()['pack'], {'theme': 'histoire', 'count': 20});
    final back = QuizSettings.fromOptions({'quiz': s.toJson()});
    expect(back.pack, (theme: 'histoire', count: 20));
    expect(QuizSettings.fromOptions({'quiz': {'pack': null}}).pack, isNull);
    expect(QuizSettings().toJson().containsKey('pack'), isFalse);
  });

  testWidgets('création du live : interrupteur des questions Afrolook, thème et nombre visibles seulement s\'il est ouvert, pas de bouton Lancer', (t) async {
    final packs = {'themes': [{'id': 'mix', 'label': 'Mélange'}, {'id': 'histoire', 'label': 'Histoire'}], 'counts': [5, 10, 20], 'free_left': 2, 'free_per_month': 2};
    QuizPackPick? pick;
    Widget box() => QuizPacksBox(
          packs: packs,
          theme: pick?.theme ?? 'mix',
          count: pick?.count ?? 10,
          pot: 0,
          enabled: pick != null,
          onToggle: (v) => pick = v ? (theme: 'mix', count: 10) : null,
          onTheme: (v) => pick = (theme: v, count: pick?.count ?? 10),
          onCount: (v) => pick = (theme: pick?.theme ?? 'mix', count: v),
        );
    await pump(t, StatefulBuilder(builder: (_, setS) => GestureDetector(onTap: () => setS(() {}), child: box())));
    expect(find.byKey(const ValueKey('quiz_pack_theme_histoire')), findsNothing);
    await t.tap(find.byKey(const ValueKey('quiz_pack_toggle')));
    await pump(t, StatefulBuilder(builder: (_, setS) => box()));
    expect(pick, (theme: 'mix', count: 10));
    await t.tap(find.byKey(const ValueKey('quiz_pack_theme_histoire')));
    await pump(t, StatefulBuilder(builder: (_, setS) => box()));
    expect(pick?.theme, 'histoire');
    expect(find.byKey(const ValueKey('quiz_launch_pack')), findsNothing);
    expect(find.byKey(const ValueKey('quiz_pack_ready')), findsOneWidget);
  });
}
