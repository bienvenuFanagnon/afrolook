import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:afrotok/services/beauty.dart';
import 'package:afrotok/services/face_filters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<ui.Image> _noisy(int w, int h) async {
  final r = math.Random(3);
  final px = Uint8List(w * h * 4);
  for (var i = 0; i < w * h; i++) {
    final v = 120 + r.nextInt(80);
    px[i * 4] = v;
    px[i * 4 + 1] = v - 10;
    px[i * 4 + 2] = v - 25;
    px[i * 4 + 3] = 255;
  }
  final c = await ui.ImmutableBuffer.fromUint8List(px);
  final d = ui.ImageDescriptor.raw(c, width: w, height: h, pixelFormat: ui.PixelFormat.rgba8888);
  return (await (await d.instantiateCodec()).getNextFrame()).image;
}

double _variance(Uint8List rgba, int w, ui.Rect r) {
  final vals = <double>[];
  for (var y = r.top.toInt(); y < r.bottom.toInt(); y++) {
    for (var x = r.left.toInt(); x < r.right.toInt(); x++) {
      vals.add(rgba[(y * w + x) * 4].toDouble());
    }
  }
  final m = vals.reduce((a, b) => a + b) / vals.length;
  return vals.map((v) => (v - m) * (v - m)).reduce((a, b) => a + b) / vals.length;
}

void main() {
  test('le niveau naturel est léger, « off » ne change rien, la matrice de couleur est neutre sans réglage', () {
    const b = BeautyLevel();
    expect(b.smooth, inInclusiveRange(.2, .5));
    expect(const BeautyLevel.off().isOff, isTrue);
    expect(const BeautyLevel.off().colorMatrix, [1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0]);
    final m = const BeautyLevel(smooth: 0, glow: 1, warm: 1).colorMatrix;
    expect(m.length, 20);
    expect(m[0], greaterThan(m[12]), reason: 'plus de rouge que de bleu : tons chauds');
  });

  testWidgets('la peau est adoucie au centre du visage, le reste de l\'image n\'est pas touché', (tester) async {
    await tester.runAsync(() async {
      const w = 300, h = 300;
      final img = await _noisy(w, h);
      const face = FaceBox(rect: Rect.fromLTWH(90, 90, 120, 140), leftEye: Offset(125, 130), rightEye: Offset(175, 130), nose: Offset(150, 165));
      final rec = ui.PictureRecorder();
      BeautyPainter.paint(ui.Canvas(rec), img, const [face], const BeautyLevel(smooth: 1, glow: 0, warm: 0));
      final out = await rec.endRecording().toImage(w, h);
      final before = (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
      final after = (await out.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
      const cheek = Rect.fromLTWH(105, 180, 40, 30);
      const far = Rect.fromLTWH(10, 10, 60, 60);
      expect(_variance(after, w, cheek), lessThan(_variance(before, w, cheek) * .5), reason: 'la joue est nettement plus douce');
      expect(_variance(after, w, far), closeTo(_variance(before, w, far), 1), reason: 'le fond reste identique');
    });
  });
}
