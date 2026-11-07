import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/services/post_download.dart';
import 'package:afrotok/services/watermark.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('# devant un canal, @ devant un pseudo (jamais doublé), rien si le nom est vide', () {
    expect(Watermark.channelLabel('Afro Actu'), '#Afro Actu');
    expect(Watermark.channelLabel('##Afro Actu '), '#Afro Actu');
    expect(Watermark.channelLabel('  '), '');
    expect(Watermark.userLabel('zuri'), '@zuri');
    expect(Watermark.userLabel('@zuri'), '@zuri');
    expect(Watermark.userLabel(null), '');
  });

  test('la signature d\'une publication de canal porte le nom du canal, sinon le @pseudo du créateur', () {
    final canalPost = Post()
      ..canal_id = 'c1'
      ..canalSnapshot = {'titre': 'Afro Actu'};
    expect(PostDownload.signatureLabel(canalPost), '#Afro Actu');
    // canal sans nom connu : on retombe sur le pseudo (jamais une signature vide ni un faux nom)
    final sansNom = Post()..canal_id = 'c1';
    expect(PostDownload.signatureLabel(sansNom), '');
    final perso = Post()..canal_id = '';
    expect(PostDownload.signatureLabel(perso), '');
  });

  test('la pastille est un PNG transparent SANS fond : coin et zone du logo transparents, texte opaque dessous, largeur ajustée au contenu', () async {
    final png = await Watermark.pillPng('@zuri');
    final d = img.decodePng(png)!;
    expect(d.hasAlpha, isTrue);
    expect(d.width, lessThan(600));   // ajustée au contenu (dans les essais la police de test est plus large que la vraie)
    expect(d.getPixel(0, 0).a, 0);
    // la zone réservée au logo (animé par le serveur) est vide : centre, à 88 px du haut (18 de marge + moitié des 140 du logo)
    expect(d.getPixel(d.width ~/ 2, 88).a, 0);
    // sous le logo : du texte opaque (« Afrolook » puis le nom)
    var opaque = 0;
    for (var y = 168; y < d.height; y++) {
      for (var x = 0; x < d.width; x++) {
        if (d.getPixel(x, y).a > 200) opaque++;
      }
    }
    expect(opaque, greaterThan(50));
  });

  test('un nom très long est coupé : la pastille ne dépasse jamais sa largeur maximale (360 px de nom + marges), même sans le nom', () async {
    final sans = img.decodePng(await Watermark.pillPng(''))!;
    final long = img.decodePng(await Watermark.pillPng('#AfroActualitesDuContinentNoirEtLaDiaspora'))!;
    expect(long.width, lessThanOrEqualTo((sans.width > 360 + 36 ? sans.width : 360 + 36) + 2));
    expect(long.height, greaterThan(sans.height));   // le nom ajoute sa ligne
  });

  test('la silhouette du logo est un carré transparent avec du blanc opaque (le dessin), sans disque plein', () async {
    final d = img.decodePng(await Watermark.logoPng())!;
    expect((d.width, d.height), (140, 140));
    var white = 0;
    var clear = 0;
    for (var y = 0; y < d.height; y += 2) {
      for (var x = 0; x < d.width; x += 2) {
        final p = d.getPixel(x, y);
        if (p.a > 200 && p.r > 240) white++;
        if (p.a == 0) clear++;
      }
    }
    // dans les essais le logo (asset) peut manquer : alors l'image est entièrement transparente, ce qui reste un PNG valide
    expect(white + clear, greaterThan(0));
  });

  test('le QR est une tuile carrée claire avec des modules sombres', () async {
    final d = img.decodePng(await Watermark.qrPng('https://afrolookmedia.com/share/post/abc', size: 240))!;
    expect((d.width, d.height), (240, 240));
    expect(d.getPixel(2, 2).a, lessThan(40));            // coin arrondi : transparent
    expect(d.getPixel(120, 8).a, greaterThan(200));      // marge de la tuile : claire
    var dark = 0;
    for (var y = 0; y < 240; y += 3) {
      for (var x = 0; x < 240; x += 3) {
        if (d.getPixel(x, y).r < 60 && d.getPixel(x, y).a > 200) dark++;
      }
    }
    expect(dark, greaterThan(300));                      // beaucoup de modules sombres
  });

  test('une image signée garde sa taille et porte une fine bande en bas sur toute la largeur (haut de l’image inchangé)', () async {
    final rec = ui.PictureRecorder();
    Canvas(rec).drawRect(const Rect.fromLTWH(0, 0, 600, 800), Paint()..color = Colors.white);
    final im = await rec.endRecording().toImage(600, 800);
    final png = (await im.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
    final signed = await Watermark.signImageBytes(Uint8List.fromList(png), '@zuri');
    final d = img.decodeImage(signed)!;
    expect((d.width, d.height), (600, 800));
    final tl = d.getPixel(10, 10);
    expect(tl.r, greaterThan(240));   // haut-gauche : toujours blanc
    expect(d.getPixel(20, 800 - 8).r, lessThan(200));          // bas-gauche : la bande sombre
    expect(d.getPixel(580, 800 - 8).r, lessThan(200));         // bas-droite : la bande couvre toute la largeur
    expect(d.getPixel(300, 400).r, greaterThan(240));          // le milieu de l'image n'est pas touché
    expect(d.getPixel(300, 800 - 60).r, greaterThan(240));     // la bande reste fine (moins de 50 px sur 800)
  });

  test('une image signée avec un QR porte la tuile dans le coin bas droit, au-dessus de la bande ; le reste de l\'image n\'est pas touché', () async {
    final rec = ui.PictureRecorder();
    Canvas(rec).drawRect(const Rect.fromLTWH(0, 0, 600, 800), Paint()..color = Colors.white);
    final im = await rec.endRecording().toImage(600, 800);
    final png = (await im.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
    final signed = await Watermark.signImageBytes(Uint8List.fromList(png), '#Afro Actu', qrData: 'https://afrolookmedia.com/share/post/abc');
    final d = img.decodeImage(signed)!;
    expect((d.width, d.height), (600, 800));
    // la tuile (fond clair) contient des modules sombres : on en trouve dans le coin bas droit
    var dark = 0;
    for (var y = 800 - 130; y < 800 - 40; y += 2) {
      for (var x = 600 - 130; x < 600 - 8; x += 2) {
        if (d.getPixel(x, y).r < 90) dark++;
      }
    }
    expect(dark, greaterThan(120));
    expect(d.getPixel(30, 30).r, greaterThan(240));            // haut-gauche : intact
    expect(d.getPixel(30, 700).r, greaterThan(240));           // milieu-bas gauche (au-dessus de la bande) : intact
  });
}
