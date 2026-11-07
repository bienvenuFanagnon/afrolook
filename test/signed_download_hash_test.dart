import 'dart:convert';
import 'dart:typed_data';

import 'package:afrotok/services/api/studio_watermark_api.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List _b(String s) => Uint8List.fromList(utf8.encode(s));

void main() {
  test('empreinte des calques : sha1 de « role:sha1(octets) » dans l\'ordre fixe (la même formule que le serveur)', () {
    final layers = {'story_pill': _b('c'), 'pill': _b('a'), 'qr': _b('b')};   // l'ordre d'insertion ne compte pas
    final expected = sha1.convert(utf8.encode('pill:${sha1.convert(_b('a'))}|qr:${sha1.convert(_b('b'))}|story_pill:${sha1.convert(_b('c'))}')).toString();
    expect(StudioWatermarkApi.layersHash(layers), expected);
    expect(StudioWatermarkApi.layersHash(layers), hasLength(40));
  });

  test('empreinte : deux dessins identiques donnent la même copie gardée, un dessin différent une autre', () {
    final a = StudioWatermarkApi.layersHash({'pill': _b('zuri'), 'logo': _b('L')});
    final same = StudioWatermarkApi.layersHash({'logo': _b('L'), 'pill': _b('zuri')});
    final other = StudioWatermarkApi.layersHash({'pill': _b('kofi'), 'logo': _b('L')});
    expect(same, a);
    expect(other, isNot(a));
    // un calque inconnu est ignoré, comme sur le serveur
    expect(StudioWatermarkApi.layersHash({'pill': _b('zuri'), 'logo': _b('L'), 'autre': _b('x')}), a);
  });
}
