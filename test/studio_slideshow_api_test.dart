import 'package:afrolook_api_client/afrolook_api_client.dart' show ApiException;
import 'package:afrotok/services/api/studio_slideshow_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('diaporama : le suivi attend tant que le travail tourne, rend la vidéo quand elle est prête', () {
    expect(StudioSlideshowApi.outcome({'status': 'running'}), isNull);
    final done = StudioSlideshowApi.outcome({'status': 'done', 'data': {'url': 'https://cdn.test/u/1/studio/slideshow_x.mp4', 'duration_ms': 20000}});
    expect(done!['url'], 'https://cdn.test/u/1/studio/slideshow_x.mp4');
    expect(done['duration_ms'], 20000);
  });

  test('diaporama : un échec rend le message précis du serveur ; « done » sans adresse est une erreur claire', () {
    expect(
      () => StudioSlideshowApi.outcome({'status': 'failed', 'http': 422, 'code': 'image_unreadable', 'message': 'L\'image 2 est illisible : choisis-en une autre.'}),
      throwsA(isA<ApiException>().having((e) => e.status, 'status', 422).having((e) => e.code, 'code', 'image_unreadable').having((e) => e.message, 'message', contains('illisible'))),
    );
    expect(() => StudioSlideshowApi.outcome({'status': 'failed'}), throwsA(isA<ApiException>().having((e) => e.status, 'status', 500)));
    expect(() => StudioSlideshowApi.outcome({'status': 'done', 'data': {}}), throwsA(isA<ApiException>().having((e) => e.code, 'code', 'slideshow_failed')));
  });
}
