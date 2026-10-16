import 'dart:typed_data';

import 'package:afrotok/services/offline_music_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final key = List<int>.generate(32, (i) => i * 7 % 256);
  final data = Uint8List.fromList(List<int>.generate(300000, (i) => (i * 31 + 7) % 256));

  test('chiffre puis déchiffre sans perte', () async {
    final sealed = await OfflineMusic.seal(data, key);
    expect(sealed.length, data.length + 4 + 12 + 16);
    expect(sealed.sublist(0, 4), [0x41, 0x46, 0x4d, 0x31]);
    // rien de lisible : le début du fichier chiffré ne ressemble pas au clair
    expect(sealed.sublist(16, 48), isNot(data.sublist(0, 32)));
    expect(await OfflineMusic.open(sealed, key), data);
  });

  test('mauvaise clé ou fichier modifié : refus', () async {
    final sealed = await OfflineMusic.seal(data, key);
    final other = List<int>.generate(32, (i) => i);
    expect(await OfflineMusic.open(sealed, other), isNull);
    final tampered = Uint8List.fromList(sealed)..[1000] ^= 1;
    expect(await OfflineMusic.open(tampered, key), isNull);
    expect(await OfflineMusic.open(Uint8List(10), key), isNull);
  });

  test('deux chiffrements du même fichier sont différents (nonce aléatoire)', () async {
    final a = await OfflineMusic.seal(data, key);
    final b = await OfflineMusic.seal(data, key);
    expect(a, isNot(b));
  });
}
