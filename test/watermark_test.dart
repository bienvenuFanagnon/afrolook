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
    expect(d.getPixel(d.width ~/ 2, d.height ~/ 2).a, greaterThan(40));   // fond léger : visible mais transparent
  });

  test('une image signée garde sa taille et porte une fine bande en bas sur toute la largeur (haut de l’image inchangé)', () async {
    final rec = ui.PictureRecorder();
    Canvas(rec).drawRect(const Rect.fromLTWH(0, 0, 600, 800), Paint()..color = Colors.white);
    final im = await rec.endRecording().toImage(600, 800);
    final png = (await im.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
    final signed = await Watermark.signImageBytes(Uint8List.fromList(png), 'zuri');
    final d = img.decodeImage(signed)!;
    expect((d.width, d.height), (600, 800));
    final tl = d.getPixel(10, 10);
    expect(tl.r, greaterThan(240));   // haut-gauche : toujours blanc
    expect(d.getPixel(20, 800 - 8).r, lessThan(200));          // bas-gauche : la bande sombre
    expect(d.getPixel(580, 800 - 8).r, lessThan(200));         // bas-droite : la bande couvre toute la largeur
    expect(d.getPixel(300, 400).r, greaterThan(240));          // le milieu de l'image n'est pas touché
    expect(d.getPixel(300, 800 - 60).r, greaterThan(240));     // la bande reste fine (moins de 50 px sur 800)
  });
}
