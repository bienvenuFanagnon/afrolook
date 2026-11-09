import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart' show decodeImageFromList;
import 'package:flutter_test/flutter_test.dart';

import 'package:afrotok/pages/studio/montage/collage_template.dart';
import 'package:afrotok/pages/studio/montage/montage_catalog.dart';
import 'package:afrotok/services/collage_layouts.dart';
import 'package:afrotok/pages/studio/montage/story_render.dart';
import 'package:afrotok/pages/studio/montage/story_script.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('chaque modèle-histoire a 2 à 5 scènes, des durées valables pour le diaporama et existe dans le catalogue', () {
    for (final id in kStoryTemplateIds) {
      final s = storyScriptFor(id)!;
      expect(s.acts.length, inInclusiveRange(2, 5), reason: id);
      expect(s.total, lessThanOrEqualTo(60), reason: id);
      for (final a in s.acts) {
        expect(a.seconds, inInclusiveRange(1.5, 10), reason: '$id : ${a.text}');
        expect(a.text.trim(), isNotEmpty);
      }
      final t = kMontageTemplates.firstWhere((x) => x.id == id);
      expect(t.isStory, isTrue);
      expect(t.showsVideo, isTrue);
    }
    expect(storyScriptFor('inconnu'), isNull);
  });

  test('le temps de lecture grandit avec la phrase, entre 2,5 et 6 secondes', () {
    expect(StoryScript.readSeconds('Oui'), 2.5);
    expect(StoryScript.readSeconds('x' * 40), closeTo(2.2 + 40 * .055, .001));
    expect(StoryScript.readSeconds('x' * 400), 6.0);
  });

  test('les années du modèle suivent l\'année qui finit', () {
    final y = DateTime.now().month >= 9 ? DateTime.now().year : DateTime.now().year - 1;
    expect(storyScriptFor('fa_film')!.acts.first.text, contains('$y'));
    expect(storyScriptFor('fa_change')!.acts.last.text, contains('${y + 1}'));
  });

  testWidgets('une scène se dessine en PNG 9:16, avec ou sans photo', (tester) async {
    await tester.runAsync(() async {
      const act = StoryAct(text: 'Le triomphe 🏆', kick: 'Décembre', tone: StoryTone.gold);
      final plain = await StoryRender.png(act, width: 360);
      var img = await decodeImageFromList(plain);
      expect(img.width, 360);
      expect(img.height, 640);

      // une vraie photo (un aplat rouge) : elle remplit le cadre, donc l'image n'est pas la même que le fond uni
      final rec = ui.PictureRecorder();
      ui.Canvas(rec).drawRect(const ui.Rect.fromLTWH(0, 0, 200, 100), ui.Paint()..color = const ui.Color(0xFFCC2222));
      final src = await rec.endRecording().toImage(200, 100);
      final photo = (await src.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
      final withPhoto = await StoryRender.png(act, photo: photo, width: 360);
      img = await decodeImageFromList(withPhoto);
      expect(img.height, 640);
      expect(withPhoto, isNot(equals(plain)));

      // une photo illisible ne bloque rien : le fond uni reste
      final broken = await StoryRender.png(act, photo: Uint8List.fromList([1, 2, 3]), width: 360);
      expect((await decodeImageFromList(broken)).width, 360);
    });
  });

  test('chaque modèle collage a 2 à 5 cases, une mise en page qui convient et existe dans le catalogue', () {
    for (final id in kCollageTemplateIds) {
      final s = collageScriptFor(id)!;
      expect(s.slots, inInclusiveRange(2, 5), reason: id);
      expect(CollageLayouts.cells(s.layout, s.slots), isNotEmpty, reason: '$id : la mise en page ${s.layout} ne convient pas à ${s.slots} photos');
      final t = kMontageTemplates.firstWhere((x) => x.id == id);
      expect(t.isCollage, isTrue);
    }
    expect(collageScriptFor('inconnu'), isNull);
  });

  testWidgets('un collage se dessine en 4:5 avec des étiquettes, et une photo illisible laisse sa case sombre', (tester) async {
    await tester.runAsync(() async {
      final rec = ui.PictureRecorder();
      ui.Canvas(rec).drawRect(const ui.Rect.fromLTWH(0, 0, 100, 100), ui.Paint()..color = const ui.Color(0xFF2266CC));
      final src = await rec.endRecording().toImage(100, 100);
      final photo = (await src.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
      final s = collageScriptFor('multi_avant_apres')!;
      final a = await CollageTemplateRender.png([photo, photo], s, width: 400);
      final img = await decodeImageFromList(a);
      expect(img.width, 400);
      expect(img.height, 500);
      // l'étiquette change le dessin
      final b = await CollageTemplateRender.png([photo, photo], s, labels: const ['', ''], width: 400);
      expect(b, isNot(equals(a)));
      final broken = await CollageTemplateRender.png([photo, Uint8List(0)], s, width: 400);
      expect((await decodeImageFromList(broken)).height, 500);
    });
  });
}
