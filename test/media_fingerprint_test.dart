import 'dart:typed_data';

import 'package:afrotok/services/media_fingerprint.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// Image de test : un dégradé avec un bloc clair à une position donnée.
Uint8List _pic(int w, int h, {int blockX = 10, int shift = 0}) {
  final im = img.Image(width: w, height: h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final v = ((x * 255) ~/ w + shift).clamp(0, 255);
      im.setPixelRgb(x, y, v, v, v);
    }
  }
  for (var y = h ~/ 3; y < h ~/ 2; y++) {
    for (var x = blockX; x < blockX + w ~/ 4; x++) {
      im.setPixelRgb(x, y, 255, 255, 255);
    }
  }
  return Uint8List.fromList(img.encodeJpg(im, quality: 90));
}

int _dist(String a, String b) {
  var d = 0;
  for (var i = 0; i < 16; i += 8) {
    final x = int.parse(a.substring(i, i + 8), radix: 16) ^ int.parse(b.substring(i, i + 8), radix: 16);
    d += x.toRadixString(2).replaceAll('0', '').length;
  }
  return d;
}

void main() {
  test('la même image réduite ou recompressée garde une empreinte presque identique ; une autre image est bien différente', () async {
    final big = _pic(640, 480);
    final small = _pic(160, 120, blockX: 2);   // même scène, plus petite
    final other = _pic(640, 480, blockX: 400);
    final h1 = (await MediaFingerprint.hashBytes(big))!;
    final h2 = (await MediaFingerprint.hashBytes(small))!;
    final h3 = (await MediaFingerprint.hashBytes(other))!;
    expect(h1.length, 16);
    expect(RegExp(r'^[0-9a-f]{16}$').hasMatch(h1), isTrue);
    expect(_dist(h1, h2), lessThanOrEqualTo(10));
    expect(_dist(h1, h3), greaterThan(0));
  });

  test('un fichier qui n\'est pas une image ne donne aucune empreinte (aucun contrôle)', () async {
    expect(await MediaFingerprint.hashBytes(Uint8List.fromList([1, 2, 3])), isNull);
    expect(await MediaFingerprint.ofImageBytes(Uint8List.fromList([1, 2, 3])), isEmpty);
  });

  test('l\'empreinte du parcours est lue une seule fois', () {
    PostFingerprintLink.set(['0123456789abcdef']);
    expect(PostFingerprintLink.take(), ['0123456789abcdef']);
    expect(PostFingerprintLink.take(), isNull);
  });
}
