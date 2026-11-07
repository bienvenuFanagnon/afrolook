import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/widgets/reply_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget home) => MaterialApp(locale: const Locale('fr'), supportedLocales: const [Locale('fr')], localizationsDelegates: GlobalMaterialLocalizations.delegates, home: Scaffold(body: home));

void main() {
  tearDown(ReplyBanner.clear);

  test('le détail de la publication d\'origine est résumé pour chaque type : vidéo, image, audio, texte', () {
    final v = Post()..id = 'p1'..dataType = PostDataType.VIDEO.name..thumbnail = 'https://x/t.jpg'..description = '  Ma   vidéo\ndu jour ';
    final i = ReplyInfo.fromPost(v);
    expect((i.kind, i.thumbUrl, i.excerpt), ('video', 'https://x/t.jpg', 'Ma vidéo du jour'));
    final img = Post()..id = 'p2'..dataType = PostDataType.IMAGE.name..images = ['', 'https://x/a.jpg']..description = 'Photo';
    expect((ReplyInfo.fromPost(img).kind, ReplyInfo.fromPost(img).thumbUrl), ('image', 'https://x/a.jpg'));
    expect(ReplyInfo.fromPost(Post()..id = 'p3'..dataType = PostDataType.AUDIO.name).kind, 'audio');
    final long = ReplyInfo.fromPost(Post()..id = 'p4'..dataType = PostDataType.TEXT.name..description = 'a' * 200);
    expect((long.kind, long.thumbUrl, long.excerpt.length), ('text', null, 71));   // 70 caractères puis « … »
  });

  testWidgets('hors d\'une réponse, le bandeau n\'affiche rien', (tester) async {
    await tester.pumpWidget(_app(const ReplyBanner()));
    expect(find.byKey(const ValueKey('reply_banner')), findsNothing);
  });

  testWidgets('pendant une réponse, le bandeau dit à qui on répond, avec le type et un extrait (sombre sur une image, clair sur le formulaire)', (tester) async {
    for (final dark in [true, false]) {
      ReplyBanner.info.value = const ReplyInfo(postId: 'p1', pseudo: 'zuri', kind: 'audio', excerpt: 'Ma chanson');
      await tester.pumpWidget(_app(Center(child: ReplyBanner(dark: dark))));
      expect(find.byKey(const ValueKey('reply_banner')), findsOneWidget);
      expect(find.text('Tu réponds à @zuri'), findsOneWidget);
      expect(find.text('Audio · Ma chanson'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('sans détail connu (post introuvable), le bandeau reste simple', (tester) async {
    ReplyBanner.info.value = const ReplyInfo(postId: 'p1', pseudo: '', kind: 'text', excerpt: '');
    await tester.pumpWidget(_app(const ReplyBanner()));
    expect(find.text('Tu réponds à une publication'), findsOneWidget);
  });
}
