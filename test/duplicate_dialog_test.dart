import 'package:afrotok/services/authentic_video_check.dart';
import 'package:afrotok/services/post_source_link.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget home) => MaterialApp(locale: const Locale('fr'), supportedLocales: const [Locale('fr')], localizationsDelegates: GlobalMaterialLocalizations.delegates, home: Scaffold(body: home));

void main() {
  testWidgets('contenu déjà publié : le message nomme l\'auteur ; « Compris » renonce, « C\'est ma vidéo » envoie à la modération', (tester) async {
    bool? result;
    await tester.pumpWidget(_app(Builder(builder: (ctx) => TextButton(onPressed: () async => result = await AuthenticVideoCheck.duplicateDialog(ctx, author: 'zuri', video: true), child: const Text('go')))));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.textContaining('@zuri'), findsOneWidget);
    await tester.tap(find.text('Compris'));
    await tester.pumpAndSettle();
    expect(result, isFalse);

    PostExternalLink.clear();
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('duplicate_own')));
    await tester.pumpAndSettle();
    expect(result, isTrue);
    final taken = PostExternalLink.take();
    expect(taken?.$1, 'duplicate');
    expect(taken?.$2, isTrue);
  });

  testWidgets('auteur inconnu : message sans pseudo ; image : bouton « C\'est mon image »', (tester) async {
    await tester.pumpWidget(_app(Builder(builder: (ctx) => TextButton(onPressed: () => AuthenticVideoCheck.duplicateDialog(ctx, author: '', video: false), child: const Text('go')))));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.textContaining('@'), findsNothing);
    expect(find.text('C\'est mon image'), findsOneWidget);
  });
}
