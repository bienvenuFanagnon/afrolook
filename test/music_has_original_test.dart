import 'package:afrotok/pages/studio/montage/montage_music.dart';
import 'package:afrotok/services/api/music_api.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _sound(Map<String, dynamic> extra) => {
      'id': 's1',
      'artist_id': 'a1',
      'artist': {'id': 'a1', 'username': 'kofi'},
      'title': 'Mood Vibes',
      'preview_url': 'https://cdn.test/u/p.m4a',
      'preview_sec': 20,
      'use_coins': 5,
      'created_at': '2026-11-11T10:00:00Z',
      ...extra,
    };

void main() {
  test('un titre sans original (« bientôt disponible ») s\'écoute mais n\'est pas utilisable dans un montage', () {
    final soon = MusicApi.soundFromApi(_sound({'has_original': false}));
    expect(soon.hasOriginal, isFalse);
    expect(MontageMusic.artist(soon).usable, isFalse);
    expect(MontageMusic.artist(soon).url, isNotNull);   // l'extrait public reste écoutable
  });

  test('un titre avec original, ou un ancien serveur qui n\'envoie pas le champ, reste utilisable comme avant', () {
    expect(MusicApi.soundFromApi(_sound({'has_original': true})).hasOriginal, isTrue);
    final old = MusicApi.soundFromApi(_sound({}));
    expect(old.hasOriginal, isTrue);
    expect(MontageMusic.artist(old).usable, isTrue);
  });
}
