import 'dart:io';

import 'package:afrotok/widgets/status_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fenêtre d'information simple (09/11/2026) : elle remplace `awesome_dialog` (qui tirait `rive`, 3 Mo sur iPhone) dans les écrans de vérification du code SMS.
Widget _app(Widget Function(BuildContext) button, {Brightness b = Brightness.light}) => MaterialApp(
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData(brightness: b),
      home: Scaffold(body: Center(child: Builder(builder: button))),
    );

void main() {
  for (final b in [Brightness.light, Brightness.dark]) {
    for (final t in StatusDialogType.values) {
      testWidgets('fenêtre ${t.name} (${b.name}) : titre, message, bouton Fermer, rappel à la fermeture', (tester) async {
        var closed = 0;
        await tester.pumpWidget(_app(
          (context) => TextButton(onPressed: () => showStatusDialog(context, type: t, title: 'Titre ${t.name}', desc: 'Un message clair.', onClose: () => closed++), child: const Text('ouvrir')),
          b: b,
        ));
        await tester.tap(find.text('ouvrir'));
        await tester.pumpAndSettle();
        expect(find.byKey(ValueKey('status_dialog_${t.name}')), findsOneWidget);
        expect(find.text('Titre ${t.name}'), findsOneWidget);
        expect(find.text('Un message clair.'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('status_dialog_close')));
        await tester.pumpAndSettle();
        expect(find.byKey(ValueKey('status_dialog_${t.name}')), findsNothing);
        expect(closed, 1);
        expect(tester.takeException(), isNull);
      });
    }
  }

  test('le paquet awesome_dialog (et donc rive) n\'est plus dans l\'application', () {
    expect(File('pubspec.yaml').readAsStringSync().contains(RegExp(r'^\s*awesome_dialog\s*:', multiLine: true)), isFalse);
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
      final code = f.readAsStringSync().split('\n').where((l) => !l.trimLeft().startsWith('//')).join('\n');
      expect(code.contains("package:awesome_dialog/"), isFalse, reason: f.path);
    }
  });
}
