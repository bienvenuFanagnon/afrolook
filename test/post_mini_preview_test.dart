import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/utils/post_time_ago.dart';
import 'package:afrotok/widgets/feed/post_mini_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Page de commentaires : la date du post ne doit plus afficher le 21/01/1970 (millisecondes lues comme des microsecondes), et un petit aperçu du post s'affiche dans l'angle.
Widget _app(Widget child) => MaterialApp(home: Scaffold(body: Center(child: child)));

Post _post({String? type, String? text, List<String>? images, String? media, String? thumb}) => Post(id: 'p1', dataType: type, description: text)
  ..images = images
  ..url_media = media
  ..thumbnail = thumb;

void main() {
  group('date d\'un post, d\'un commentaire ou d\'une réponse', () {
    final truth = DateTime.utc(2026, 11, 12, 22, 28, 2);

    test('millisecondes (API) et microsecondes (anciens écrans) donnent la MÊME date', () {
      final ms = epochToDateTime(truth.millisecondsSinceEpoch)!;
      final us = epochToDateTime(truth.microsecondsSinceEpoch)!;
      expect(ms.toUtc(), truth);
      expect(us.toUtc(), truth);
    });

    test('l\'ancien défaut : des millisecondes lues comme des microsecondes tombaient en janvier 1970', () {
      final wrong = DateTime.fromMicrosecondsSinceEpoch(truth.millisecondsSinceEpoch).toUtc();
      expect(wrong.year, 1970);
      expect(epochToDateTime(truth.millisecondsSinceEpoch)!.year, 2026);
    });

    test('date absente ou nulle : rien (jamais le 1er janvier 1970)', () {
      expect(epochToDateTime(null), isNull);
      expect(epochToDateTime(0), isNull);
      expect(epochToDateTime(-5), isNull);
      expect(postTimeAgo(0), '');
    });
  });

  group('aperçu du post', () {
    test('image : la première image ; vidéo : la miniature ; sans adresse valide : aucune image', () {
      expect(PostMiniPreview.imageUrl(_post(type: 'IMAGE', media: 'https://cdn.test/a.jpg', images: ['https://cdn.test/a.jpg', 'https://cdn.test/b.jpg'])), 'https://cdn.test/a.jpg');
      expect(PostMiniPreview.imageUrl(_post(type: 'IMAGE', images: ['', 'https://cdn.test/b.jpg'])), 'https://cdn.test/b.jpg');
      expect(PostMiniPreview.imageUrl(_post(type: 'VIDEO', media: 'https://cdn.test/v.mp4', thumb: 'https://cdn.test/t.jpg')), 'https://cdn.test/t.jpg');
      expect(PostMiniPreview.imageUrl(_post(type: 'VIDEO', media: 'https://cdn.test/v.mp4')), isNull);
      expect(PostMiniPreview.imageUrl(_post(type: 'TEXT', text: 'bonjour')), isNull);
      expect(PostMiniPreview.imageUrl(_post(type: 'IMAGE', media: 'pas-une-adresse')), isNull);
    });

    test('nombre d\'images et début du texte', () {
      expect(PostMiniPreview.imageCount(_post(type: 'IMAGE', images: ['https://a/1', 'https://a/2', 'https://a/3'])), 3);
      expect(PostMiniPreview.imageCount(_post(type: 'VIDEO', images: ['https://a/1', 'https://a/2'])), 0);
      expect(PostMiniPreview.excerpt(_post(text: '  Salut   à\ntous  ')), 'Salut à tous');
      final long = PostMiniPreview.excerpt(_post(text: 'a' * 100));
      expect(long.length, lessThanOrEqualTo(43));
      expect(long, endsWith('…'));
    });

    testWidgets('texte : l\'extrait s\'affiche dans la vignette ; la vignette est appuyable si on lui donne une action', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(_app(PostMiniPreview(post: _post(type: 'TEXT', text: 'Mon premier post'), onTap: () => tapped++)));
      expect(find.byKey(const ValueKey('post_mini_preview')), findsOneWidget);
      expect(find.text('Mon premier post'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('post_mini_preview')));
      expect(tapped, 1);
    });

    testWidgets('vidéo sans miniature : tuile avec pastille « lecture » ; audio : note de musique ; sans action : pas appuyable', (tester) async {
      await tester.pumpWidget(_app(PostMiniPreview(post: _post(type: 'VIDEO', media: 'https://cdn.test/v.mp4'))));
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      expect(find.byType(GestureDetector), findsNothing);
      await tester.pumpWidget(_app(PostMiniPreview(post: _post(type: 'AUDIO'))));
      expect(find.byIcon(Icons.music_note_rounded), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
    });
  });
}
