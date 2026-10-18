import 'dart:typed_data';

import 'package:afrotok/services/music_head.dart';
import 'package:afrotok/services/offline_music_service.dart';
import 'package:afrotok/utils/audio_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final key = List<int>.generate(32, (i) => (i * 11 + 3) % 256);
  final head = Uint8List.fromList(List<int>.generate(20000, (i) => (i * 13 + 5) % 256));

  test('le début d’un titre se range puis se relit à l’identique', () async {
    final sealed = await OfflineMusic.seal(head, key);
    final raw = MusicHead.encode(sealed, 4812345, AudioKind.mp3);
    // rien de lisible dans le fichier rangé
    expect(raw.sublist(40, 80), isNot(head.sublist(0, 40)));
    final back = await MusicHead.decode(raw, key);
    expect(back, isNotNull);
    expect(back!.bytes, head);
    expect(back.total, 4812345);
    expect(back.kind, AudioKind.mp3);
  });

  test('mauvaise clé, fichier abîmé ou trop court : refusé', () async {
    final raw = MusicHead.encode(await OfflineMusic.seal(head, key), 1000000, AudioKind.m4a);
    expect(await MusicHead.decode(raw, List<int>.generate(32, (i) => i)), isNull);
    final bad = Uint8List.fromList(raw)..[200] ^= 1;
    expect(await MusicHead.decode(bad, key), isNull);
    expect(await MusicHead.decode(Uint8List(12), key), isNull);
    final notOurs = Uint8List.fromList(raw)..[0] = 0x00;
    expect(await MusicHead.decode(notOurs, key), isNull);
  });

  test('taille totale lue dans Content-Range', () {
    expect(MusicHead.totalOf('bytes 0-655359/4812345', 655360), 4812345);
    expect(MusicHead.totalOf(null, 123456), 123456);
  });

  test('la source “début local” sert le début sans réseau, par morceaux', () async {
    final src = HeadStartSource(head: head, total: 5000000, kind: AudioKind.mp3, urlProvider: () async => fail('le réseau ne doit pas être appelé'));
    final r = await src.request(100, 600);
    expect(r.sourceLength, 5000000);
    expect(r.contentLength, 500);
    expect(r.offset, 100);
    expect(r.contentType, 'audio/mpeg');
    final got = <int>[];
    await for (final c in r.stream) {
      got.addAll(c);
    }
    expect(got, head.sublist(100, 600));
  });
}
