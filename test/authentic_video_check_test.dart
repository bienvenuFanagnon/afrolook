import 'package:afrotok/services/authentic_video_check.dart';
import 'package:afrotok/services/authenticity_watcher.dart';
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
    // Un @pseudo ne bloque JAMAIS à lui seul (décision du 09/11/2026 : seuls les noms de plateformes comptent) : le pseudo de la personne, d'une boutique, d'un ami…
    expect(AuthenticVideoCheck.decide(['@zuri.style', 'bonjour', '@zuri.style']), isNull);
    expect(AuthenticVideoCheck.decide(['@zuri.style', 'bonjour', '@zuri.styIe']), isNull);
    expect(AuthenticVideoCheck.decide(['@zuri.style', 'bonjour', '@autre_nom']), isNull);
    expect(AuthenticVideoCheck.decide(['@zuri.style']), isNull);
    expect(AuthenticVideoCheck.decide(['Fait sur Afrolook\n@zuri', 'Fait sur Afrolook\n@zuri']), isNull);
    expect(AuthenticVideoCheck.decide(['Je suis très content de vous voir @zuri', 'Je suis très content de vous voir @zuri']), isNull);
    expect(AuthenticVideoCheck.decide(['@zuri', '@zuri', '@zuri', '@zuri', '@zuri']), isNull);   // même pseudo sur toutes les images : toujours accepté
    // image isolée : le nom du réseau seulement
    expect(AuthenticVideoCheck.decideImage('Instagram\nzuri'), 'instagram');
    expect(AuthenticVideoCheck.decideImage('@zuri.style'), isNull);
    expect(AuthenticVideoCheck.decideImage('Suivez-nous sur @boutique'), isNull);
    expect(AuthenticVideoCheck.decideImage('Fait sur Afrolook @zuri'), isNull);
    expect(AuthenticVideoCheck.decideImage('Promo de fin d\'année'), isNull);
    expect(AuthenticVideoCheck.decide(['InShot', 'Made with VN']), isNull);
    expect(AuthenticVideoCheck.decide(['Bonjour tout le monde', '', '']), isNull);
    expect(AuthenticVideoCheck.decide([]), isNull);
  });

  test('pendant une lecture : 3 images seulement (début, milieu, fin), contrôle dès 3 s, 12 vidéos par séance, 20 s au plus', () {
    expect(AuthenticVideoCheck.frameTimes(30000), [300, 15000, 28800]);   // l'écran de fin de TikTok : 1,2 s avant la fin
    expect(AuthenticVideoCheck.frameTimes(2000), [300, 1000, 1700]);   // vidéo très courte : 85 % de la durée
    expect(AuthenticVideoCheck.frameTimes(500).length, lessThanOrEqualTo(3));
    expect(AuthenticityWatcher.startAfterSeconds, 3);
    expect(AuthenticityWatcher.maxScansPerSession, 12);
    expect(AuthenticVideoCheck.scanMaxDuration, const Duration(seconds: 20));
  });
}
