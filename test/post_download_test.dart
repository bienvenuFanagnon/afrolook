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
}
