import 'dart:io';

import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/widgets/post_menu_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// Menu unique d'une publication (08/11/2026) : les mêmes lignes dans le fil, les pages détail et les vidéos verticales.
Widget _app(Post post, UserData me, {Brightness b = Brightness.light, List<PostMenuExtra> extras = const [], bool fav = false}) => MaterialApp(
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData(brightness: b),
      home: Scaffold(
        body: Builder(
          builder: (context) => SingleChildScrollView(
            child: PostMenuSheetBody(
              pageContext: context,
              sheetContext: context,
              post: post,
              me: me,
              isFavorite: fav,
              onToggleFavorite: () {},
              onDelete: () {},
              extras: extras,
            ),
          ),
        ),
      ),
    );

Post _post({String author = 'autre'}) => Post()
  ..id = 'p1'
  ..user_id = author
  ..user = (UserData()..id = author..pseudo = 'awa')
  ..description = 'Une publication';

UserData _me({String role = 'USER'}) => UserData()
  ..id = 'moi'
  ..role = role;

bool _has(String key) => find.byKey(ValueKey(key)).evaluate().isNotEmpty;

void main() {
  testWidgets('une publication d\'un autre : diffusion, favoris, réponses en vidéo, signaler, bloquer ; ni booster ni supprimer', (tester) async {
    await tester.pumpWidget(_app(_post(), _me()));
    expect(_has('menu_diffusion'), isTrue);
    expect(_has('menu_favorite'), isTrue);
    expect(_has('menu_replies'), isTrue);
    expect(_has('menu_report'), isTrue);
    expect(_has('menu_wrong'), isTrue);
    expect(_has('menu_block'), isTrue);
    expect(_has('menu_cancel'), isTrue);
    expect(_has('menu_boost'), isFalse);
    expect(_has('menu_delete'), isFalse);
    expect(_has('menu_commerce'), isFalse);
    expect(find.text('Ajouter aux favoris'), findsOneWidget);
  });

  testWidgets('ma publication : booster, carte Commerce et supprimer ; jamais signaler ni bloquer', (tester) async {
    await tester.pumpWidget(_app(_post(author: 'moi'), _me()));
    expect(_has('menu_boost'), isTrue);
    expect(_has('menu_commerce'), isTrue);
    expect(_has('menu_delete'), isTrue);
    expect(_has('menu_diffusion'), isTrue);
    expect(_has('menu_report'), isFalse);
    expect(_has('menu_block'), isFalse);
  });

  testWidgets('administrateur : modérer et hors catégorie (admin) à la place de signaler ; il peut supprimer et booster', (tester) async {
    await tester.pumpWidget(_app(_post(), _me(role: UserRole.ADM.name)));
    expect(_has('menu_moderate'), isTrue);
    expect(_has('menu_wrong_admin'), isTrue);
    expect(_has('menu_report'), isFalse);
    expect(_has('menu_delete'), isTrue);
    expect(_has('menu_boost'), isTrue);
  });

  testWidgets('déjà signalé : la ligne Signaler disparaît ; en favoris : « Retirer des favoris »', (tester) async {
    final p = _post()..reporterIds = ['moi'];
    await tester.pumpWidget(_app(p, _me(), fav: true));
    expect(_has('menu_report'), isFalse);
    expect(_has('menu_wrong'), isTrue);
    expect(find.text('Retirer des favoris'), findsOneWidget);
  });

  testWidgets('une publicité n\'a ni diffusion, ni réponses en vidéo, ni booster', (tester) async {
    final p = _post(author: 'moi')..isAdvertisement = true;
    await tester.pumpWidget(_app(p, _me()));
    expect(_has('menu_diffusion'), isFalse);
    expect(_has('menu_replies'), isFalse);
    expect(_has('menu_boost'), isFalse);
  });

  testWidgets('les lignes propres à un écran (partager, republier, chat) s\'ajoutent au menu commun, clair et sombre', (tester) async {
    for (final b in [Brightness.light, Brightness.dark]) {
      await tester.pumpWidget(_app(_post(), _me(), b: b, extras: [PostMenuExtra(icon: Icons.share, label: 'Partager', onTap: () {})]));
      expect(find.text('Partager'), findsOneWidget);
      expect(_has('menu_diffusion'), isTrue);
      expect(tester.takeException(), isNull);
    }
  });

  test('les quatre écrans utilisent le même menu : plus de liste de lignes écrite à la main', () {
    for (final f in [
      'lib/pages/postDetails.dart',
      'lib/pages/postDetailsVideo.dart',
      'lib/pages/post_video_format_tel_details.dart',
      'lib/pages/userPosts/postWidgets/postWidgetPage.dart',
    ]) {
      final src = File(f).readAsStringSync();
      expect(src.contains('showPostMenuSheet('), isTrue, reason: f);
      expect(src.contains("'Bloquer cet utilisateur'") || src.contains('"Bloquer cet utilisateur"'), isFalse, reason: '$f écrit encore son propre menu');
    }
  });
}
