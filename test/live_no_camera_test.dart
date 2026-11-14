import 'package:afrotok/pages/LiveAgora/livesAgora.dart';
import 'package:afrotok/services/api/lives_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> api({bool noCamera = true, String? kind = 'video', String? url = 'https://cdn.afrolook/apercu.mp4'}) => {
        'id': 'L1', 'host_id': 'H1', 'title': 'Quiz du soir', 'started_at': '2026-11-14T12:00:00Z', 'is_live': true, 'type_session': 'quiz',
        'no_camera': noCamera, 'preview_kind': kind, 'preview_url': url,
      };

  test('un live sans caméra de l\'API garde son aperçu (type et adresse)', () {
    final l = postLiveFromApi(api());
    expect(l.noCamera, isTrue);
    expect(l.previewKind, 'video');
    expect(l.previewUrl, 'https://cdn.afrolook/apercu.mp4');
    expect(l.typeSession, 'quiz');
  });

  test('un live normal n\'est pas sans caméra et n\'a pas d\'aperçu', () {
    final l = postLiveFromApi(api(noCamera: false, kind: null, url: null));
    expect(l.noCamera, isFalse);
    expect(l.previewKind, isNull);
    expect(l.previewUrl, isNull);
  });

  test('les champs d\'aperçu survivent à la copie du live (copyWith)', () {
    final l = postLiveFromApi(api());
    final back = l.copyWith(isPaused: true);
    expect(back.noCamera, isTrue);
    expect(back.previewKind, 'video');
    expect(back.previewUrl, 'https://cdn.afrolook/apercu.mp4');
  });
}
