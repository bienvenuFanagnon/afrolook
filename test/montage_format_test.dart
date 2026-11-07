import 'package:afrotok/pages/studio/montage/montage_catalog.dart';
import 'package:afrotok/pages/studio/montage/montage_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formats du montage : story 9:16, post 4:5, paysage 16:9 — le serveur reçoit le bon nom et la bonne taille', () {
    final s = MontageState(kMontageTemplates.first);
    expect((s.format, s.aspect, s.filmSize), ('story', 9 / 16, (720, 1280)));
    s.setFormat('post');
    expect((s.format, s.aspect, s.filmSize), ('post', 4 / 5, (720, 900)));
    s.setFormat('landscape');
    expect((s.format, s.aspect, s.filmSize), ('landscape', 16 / 9, (1280, 720)));
    expect(s.post, isFalse);   // un seul format à la fois
    s.setFormat('story');
    expect(s.landscape, isFalse);
    expect(s.format, 'story');
  });
}
