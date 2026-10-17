import 'dart:io';
import 'dart:typed_data';

import 'package:afrotok/services/media_shrink.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('les petits fichiers et les octets non image sont renvoyés tels quels (sans plugin)', () async {
    final small = Uint8List.fromList(List.filled(1000, 7));
    expect(identical(await MediaShrink.bytes(small), small), isTrue);

    final notImage = Uint8List.fromList(List.filled(MediaShrink.imageMinBytes + 10, 1)); // ni JPEG, ni PNG, ni WebP
    expect(identical(await MediaShrink.bytes(notImage), notImage), isTrue);

    final dir = await Directory.systemTemp.createTemp('shrink');
    addTearDown(() => dir.delete(recursive: true));
    final audio = File('${dir.path}/a.m4a')..writeAsBytesSync(List.filled(2000000, 3));
    expect((await MediaShrink.file(audio)).path, audio.path); // audio : jamais touché
    final tiny = File('${dir.path}/b.jpg')..writeAsBytesSync(List.filled(1000, 3));
    expect((await MediaShrink.file(tiny)).path, tiny.path); // vignette : jamais touchée
  });
}
