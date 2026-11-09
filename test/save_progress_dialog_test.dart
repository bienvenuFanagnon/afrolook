import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afrotok/widgets/save_progress_dialog.dart';

/// L'enregistrement dans la galerie montre une fenêtre avec une barre de progression, puis un résultat clair qui reste jusqu'au « OK » (10/11/2026).
void main() {
  Future<void> open(WidgetTester tester, Future<bool> Function(BuildContext) go, void Function(Future<bool>) keep) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (ctx) => Center(child: ElevatedButton(onPressed: () => keep(go(ctx)), child: const Text('go'))),
        ),
      ),
    ));
    await tester.tap(find.text('go'));
    await tester.pump();
  }

  testWidgets('la fenêtre montre l\'étape et une barre qui avance, ne se ferme pas toute seule, puis affiche « Enregistré » jusqu\'au OK', (tester) async {
    final gate = Completer<void>();
    final progress = <double>[];
    Future<bool>? result;
    await open(tester, (ctx) => SaveProgressDialog.run(ctx, doneText: 'Ta vidéo est dans ta galerie.', task: (report) async {
          report(0.1, 'Ajout de la signature Afrolook…');
          progress.add(0.1);
          await gate.future;
          report(0.9, 'Enregistrement dans ta galerie…');
          return null;
        }), (f) => result = f);
    await tester.pump();
    // en cours : la barre et l'étape sont visibles, pas de bouton OK, impossible de fermer en touchant à côté
    expect(find.byKey(const ValueKey('save_progress_dialog')), findsOneWidget);
    expect(find.byKey(const ValueKey('save_progress_bar')), findsOneWidget);
    expect(find.text('Ajout de la signature Afrolook…'), findsOneWidget);
    expect(find.byKey(const ValueKey('save_progress_ok')), findsNothing);
    await tester.tapAt(const Offset(5, 5));
    await tester.pump();
    expect(find.byKey(const ValueKey('save_progress_dialog')), findsOneWidget);
    // la tâche avance : étape suivante et pourcentage
    gate.complete();
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const ValueKey('save_done_text')), findsOneWidget);
    expect(find.text('Ta vidéo est dans ta galerie.'), findsOneWidget);
    // le résultat RESTE affiché (il ne se ferme pas tout seul) jusqu'au OK
    await tester.pump(const Duration(seconds: 10));
    expect(find.byKey(const ValueKey('save_progress_dialog')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('save_progress_ok')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('save_progress_dialog')), findsNothing);
    expect(await result, isTrue);
  });

  testWidgets('un échec montre la raison, reste affiché jusqu\'au OK et rend faux', (tester) async {
    Future<bool>? result;
    await open(tester, (ctx) => SaveProgressDialog.run(ctx, doneText: 'ok', task: (report) async => 'Autorise l\'accès aux photos.'), (f) => result = f);
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const ValueKey('save_error_text')), findsOneWidget);
    expect(find.text('Autorise l\'accès aux photos.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('save_progress_ok')));
    await tester.pumpAndSettle();
    expect(await result, isFalse);
  });

  testWidgets('une erreur inattendue dans la tâche est montrée comme un échec, jamais une fenêtre bloquée', (tester) async {
    Future<bool>? result;
    await open(tester, (ctx) => SaveProgressDialog.run(ctx, doneText: 'ok', task: (report) async => throw StateError('boum')), (f) => result = f);
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const ValueKey('save_error_text')), findsOneWidget);
    expect(find.byKey(const ValueKey('save_progress_ok')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('save_progress_ok')));
    await tester.pumpAndSettle();
    expect(await result, isFalse);
  });
}
