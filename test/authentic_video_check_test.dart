import 'package:afrotok/services/authentic_video_check.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('TikTok : une seule image avec la marque suffit (filigrane ou écran de fin)', () {
    expect(AuthenticVideoCheck.decide(['', 'TikTok @gims.vibes', '']), 'tiktok');
    expect(AuthenticVideoCheck.decide(['Tik Tok', '']), 'tiktok');
    expect(AuthenticVideoCheck.decide(['@alice.mj0 TIKTOK']), 'tiktok');
  });

  test('autres réseaux : il faut la marque sur deux images au moins', () {
    expect(AuthenticVideoCheck.decide(['Instagram', '', 'rien']), isNull);
    expect(AuthenticVideoCheck.decide(['Instagram @zuri', '', 'instagram']), 'instagram');
  });

  test('les éditeurs (CapCut, InShot…) et les vidéos propres passent', () {
    expect(AuthenticVideoCheck.decide(['CapCut', 'capcut', '']), isNull);
    expect(AuthenticVideoCheck.decide(['Snapchat', 'snapchat', '@zuri']), isNull);   // Snapchat n'est pas bloqué
    expect(AuthenticVideoCheck.decide(['InShot', 'Made with VN']), isNull);
    expect(AuthenticVideoCheck.decide(['Bonjour tout le monde', '', '']), isNull);
    expect(AuthenticVideoCheck.decide([]), isNull);
  });
}
