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
}
