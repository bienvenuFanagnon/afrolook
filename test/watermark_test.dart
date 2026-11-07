import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:afrotok/services/watermark.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('la pastille Afrolook est une image PNG transparente de la largeur demandée', () async {
    final png = await Watermark.pillPng('zuri', width: 420);
    final d = img.decodePng(png)!;
    expect(d.width, 420);
    expect(d.height, greaterThan(60));
    expect(d.hasAlpha, isTrue);
    // le coin haut-gauche est transparent (pastille arrondie), le centre est opaque
    expect(d.getPixel(0, 0).a, 0);
    expect(d.getPixel(d.width ~/ 2, d.height ~/ 2).a, greaterThan(100));
  });

  test('une image signée garde sa taille et porte la pastille en bas à droite (coin haut-gauche inchangé)', () async {
    final rec = ui.PictureRecorder();
    Canvas(rec).drawRect(const Rect.fromLTWH(0, 0, 600, 800), Paint()..color = Colors.white);
    final im = await rec.endRecording().toImage(600, 800);
    final png = (await im.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
    final signed = await Watermark.signImageBytes(Uint8List.fromList(png), 'zuri');
    final d = img.decodeImage(signed)!;
    expect((d.width, d.height), (600, 800));
    final tl = d.getPixel(10, 10);
    expect(tl.r, greaterThan(240));   // haut-gauche : toujours blanc
    final br = d.getPixel(600 - 40, 800 - 40);
    expect(br.r, lessThan(200));      // bas-droite : la pastille sombre est passée par là
  });
}
