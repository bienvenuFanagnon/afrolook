import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/services/authenticity_watcher.dart';
import 'package:flutter_test/flutter_test.dart';

Post _post({String? id = 'p1', String? url = 'https://x/v.mp4', String? author = 'a1', String? authenticity, bool? ad}) => Post()
  ..id = id
  ..url_media = url
  ..user_id = author
  ..authenticity = authenticity
  ..isAdvertisement = ad;

void main() {
  test('contrôle d\'une vidéo regardée : seulement une vidéo d\'un autre, non encore validée ni marquée, qui n\'est pas une pub', () {
    expect(AuthenticityWatcher.needsCheck(_post(), 'moi'), isTrue);
    expect(AuthenticityWatcher.needsCheck(_post(author: 'moi'), 'moi'), isFalse);      // sa propre vidéo
    expect(AuthenticityWatcher.needsCheck(_post(authenticity: 'validated'), 'moi'), isFalse);
    expect(AuthenticityWatcher.needsCheck(_post(authenticity: 'flagged'), 'moi'), isFalse);
    expect(AuthenticityWatcher.needsCheck(_post(ad: true), 'moi'), isFalse);           // une pub
    expect(AuthenticityWatcher.needsCheck(_post(id: null), 'moi'), isFalse);
    expect(AuthenticityWatcher.needsCheck(_post(url: null), 'moi'), isFalse);
  });
}
