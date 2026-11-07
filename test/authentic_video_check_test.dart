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
    expect(AuthenticVideoCheck.decide(['Snapchat', 'snapchat', '@zuri']), 'snapchat');   // Snapchat est bloqué comme TikTok (décision du 07/11)
    expect(AuthenticVideoCheck.decide(['Snapchat', 'une photo']), isNull);   // un seul mot isolé ne suffit pas
    // Instagram affiche le logo et le pseudo du créateur, sans le nom : le même @pseudo sur deux images suffit
    expect(AuthenticVideoCheck.decide(['@zuri.style', 'bonjour', '@zuri.style']), 'other');
    expect(AuthenticVideoCheck.decide(['@zuri.style', 'bonjour', '@zuri.styIe']), 'other');   // une lettre mal lue
    expect(AuthenticVideoCheck.decide(['@zuri.style', 'bonjour', '@autre_nom']), isNull);   // pseudos différents : pas de filigrane
    expect(AuthenticVideoCheck.decide(['@zuri.style']), isNull);   // une seule image : pas assez
    expect(AuthenticVideoCheck.decide(['Fait sur Afrolook\n@zuri', 'Fait sur Afrolook\n@zuri']), isNull);   // nos propres fins animées et modèles
    expect(AuthenticVideoCheck.decide(['Je suis très content de vous voir @zuri', 'Je suis très content de vous voir @zuri']), isNull);   // une phrase n'est pas un filigrane
    // image isolée : nom du réseau, ou @pseudo seul sur sa ligne
    expect(AuthenticVideoCheck.decideImage('Instagram\nzuri'), 'instagram');
    expect(AuthenticVideoCheck.decideImage('@zuri.style'), 'other');
    expect(AuthenticVideoCheck.decideImage('Suivez-nous sur @boutique'), isNull);
    expect(AuthenticVideoCheck.decideImage('Fait sur Afrolook @zuri'), isNull);
    expect(AuthenticVideoCheck.decideImage('Promo de fin d\'année'), isNull);
    expect(AuthenticVideoCheck.decide(['InShot', 'Made with VN']), isNull);
    expect(AuthenticVideoCheck.decide(['Bonjour tout le monde', '', '']), isNull);
    expect(AuthenticVideoCheck.decide([]), isNull);
  });
}
