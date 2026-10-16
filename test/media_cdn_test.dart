import 'package:afrotok/utils/media_cdn.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const fb = 'https://firebasestorage.googleapis.com/v0/b/afrolooki.appspot.com/o/artist_sound_previews%2Fabc.m4a?alt=media&token=t0k3n';

  test('extraits, pochettes et musiques gratuites passent par le CDN', () {
    expect(MediaCdn.url(fb), 'https://cdn.afrolookmedia.com/media/artist_sound_previews%2Fabc.m4a?alt=media&token=t0k3n');
  });

  test('les liens d\'écoute temporaires (titres complets) ne passent jamais par le CDN', () {
    const tmp = 'https://firebasestorage.googleapis.com/v0/b/afrolooki.appspot.com/o/artist_sound_tmp%2F123_x.m4a?alt=media&token=z';
    expect(MediaCdn.url(tmp), tmp);
  });

  test('une URL qui n\'est pas Firebase, vide ou nulle reste telle quelle', () {
    expect(MediaCdn.url('https://example.com/a.m4a'), 'https://example.com/a.m4a');
    expect(MediaCdn.url(''), '');
    expect(MediaCdn.url(null), '');
  });

  test('retour sur Firebase si le CDN ne répond pas', () {
    final cdn = MediaCdn.url(fb);
    expect(MediaCdn.original(cdn), contains('firebasestorage.googleapis.com/v0/b/'));
    expect(MediaCdn.original(cdn), endsWith('artist_sound_previews%2Fabc.m4a?alt=media&token=t0k3n'));
    expect(MediaCdn.original(fb), isNull);
  });
}
