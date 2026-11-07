import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/services/post_download.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget home) => MaterialApp(locale: const Locale('fr'), supportedLocales: const [Locale('fr')], localizationsDelegates: GlobalMaterialLocalizations.delegates, home: Scaffold(body: home));

void main() {
  test('médias téléchargeables : plusieurs images, une vidéo, un audio ; une pub ou un texte n\'a rien à télécharger', () {
    final imgs = Post()..dataType = PostDataType.IMAGE.name..images = ['https://x/a.jpg', 'https://x/b.jpg', ' ']..url_media = 'https://x/a.jpg';
    expect(PostDownload.mediaOf(imgs).map((e) => e.kind), ['image', 'image']);
    final vid = Post()..dataType = PostDataType.VIDEO.name..url_media = 'https://x/v.mp4';
    expect(PostDownload.mediaOf(vid).single.kind, 'video');
    final aud = Post()..dataType = PostDataType.AUDIO.name..url_media = 'https://x/s.m4a';
    expect(PostDownload.mediaOf(aud).single.kind, 'audio');
    expect(PostDownload.mediaOf(Post()..dataType = PostDataType.TEXT.name), isEmpty);
  });

  testWidgets('plusieurs images : on choisit celles qu\'on veut (toutes cochées au départ), le bouton compte la sélection', (tester) async {
    List<({String url, String kind})>? result;
    final items = [for (final n in ['a', 'b', 'c']) (url: 'https://x/$n.jpg', kind: 'image')];
    await tester.pumpWidget(_app(Builder(builder: (ctx) => TextButton(onPressed: () async => result = await PostDownload.chooseImages(ctx, items, (u) => u), child: const Text('go')))));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text('Choisis les images à télécharger'), findsOneWidget);
    expect(find.text('Télécharger 3'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('pick_1')));   // on décoche la deuxième
    await tester.pumpAndSettle();
    expect(find.text('Télécharger 2'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('download_go')));
    await tester.pumpAndSettle();
    expect(result!.map((e) => e.url), ['https://x/a.jpg', 'https://x/c.jpg']);
  });

  testWidgets('aucune image cochée : le bouton est inactif', (tester) async {
    final items = [for (final n in ['a', 'b']) (url: 'https://x/$n.jpg', kind: 'image')];
    await tester.pumpWidget(_app(Builder(builder: (ctx) => TextButton(onPressed: () => PostDownload.chooseImages(ctx, items, (u) => u), child: const Text('go')))));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('pick_0')));
    await tester.tap(find.byKey(const ValueKey('pick_1')));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(find.byKey(const ValueKey('download_go'))).onPressed, isNull);
  });
  testWidgets('fenêtre « terminé » : reste affichée au milieu avec son message jusqu’à OK (une pub plein écran ne la ferme pas)', (tester) async {
    await tester.pumpWidget(_app(Builder(builder: (ctx) => TextButton(onPressed: () => showDialog<void>(context: ctx, builder: (_) => PostDownload.doneForTest('Ton média est dans ta galerie.')), child: const Text('go')))));
    await tester.tap(find.text('go'));
    await tester.pump();
    expect(find.byKey(const ValueKey('download_done')), findsOneWidget);
    expect(find.text('Téléchargement terminé'), findsOneWidget);
    expect(find.text('Ton média est dans ta galerie.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));   // le temps passe : elle ne disparaît pas toute seule
    expect(find.byKey(const ValueKey('download_done')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('download_done_ok')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('download_done')), findsNothing);
  });
  testWidgets('fenêtre d’avancement : étape et barre visibles au milieu, elles suivent les changements', (tester) async {
    final step = ValueNotifier<String>('Préparation…');
    final progress = ValueNotifier<double?>(null);
    await tester.pumpWidget(_app(Builder(builder: (ctx) => TextButton(onPressed: () => showDialog<void>(context: ctx, barrierDismissible: false, builder: (_) => PostDownload.progressForTest(step, progress, const ['video'])), child: const Text('go')))));
    await tester.tap(find.text('go'));
    await tester.pump();
    expect(find.byKey(const ValueKey('download_progress')), findsOneWidget);
    expect(find.text('Téléchargement en cours'), findsOneWidget);
    expect(find.text('Préparation…'), findsOneWidget);
    step.value = '2/3 · Signature de la vidéo…';
    progress.value = 0.4;
    await tester.pump();
    expect(find.text('2/3 · Signature de la vidéo…'), findsOneWidget);
    expect(tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator)).value, 0.4);
    expect(tester.takeException(), isNull);
  });
}
