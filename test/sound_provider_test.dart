import 'package:afrotok/providers/sound_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Son des vidéos (16/11/2026) : activé par défaut ; le choix de la personne (coupé) est retenu.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('jamais touché : son activé', () async {
    SharedPreferences.setMockInitialValues({});
    final p = SoundProvider();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(p.isMuted, isFalse);
  });

  test('ancien réglage « coupé » (mis par la carte vidéo du fil, pas par la personne) : ignoré, son activé', () async {
    SharedPreferences.setMockInitialValues({'global_sound_muted': true});
    final p = SoundProvider();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(p.isMuted, isFalse);
  });

  test('son coupé par la personne : reste coupé', () async {
    SharedPreferences.setMockInitialValues({'global_sound_muted_v2': true});
    final p = SoundProvider();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(p.isMuted, isTrue);
  });

  test('son coupé : monter le volume du téléphone le réactive ; baisser ne change rien', () async {
    SharedPreferences.setMockInitialValues({'global_sound_muted_v2': true});
    final p = SoundProvider();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(p.isMuted, isTrue);
    p.onVolume(.5);            // volume actuel : simple référence
    expect(p.isMuted, isTrue);
    p.onVolume(.4);            // baisse
    expect(p.isMuted, isTrue);
    p.onVolume(.47);           // hausse
    expect(p.isMuted, isFalse);
  });

  test('pub vidéo avec le son (19/11/2026) : les autres vidéos se taisent pendant la pub, puis le réglage de la personne revient', () async {
    AdSoundFocus.reset();
    SharedPreferences.setMockInitialValues({});
    final p = SoundProvider();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    var notified = 0;
    p.addListener(() => notified++);
    expect(p.isMuted, isFalse);
    final pub1 = Object(), pub2 = Object();
    AdSoundFocus.hold(pub1);
    expect(p.isMuted, isTrue);
    expect(notified, 1);
    AdSoundFocus.hold(pub2);
    AdSoundFocus.release(pub1);
    expect(p.isMuted, isTrue);   // une autre pub joue encore avec le son
    AdSoundFocus.set(pub2, false);
    expect(p.isMuted, isFalse);
    expect(notified, 2);
    AdSoundFocus.reset();
  });
}
