import 'package:afrotok/utils/fnv.dart';
import 'package:flutter_test/flutter_test.dart';

// Ancienne version (entiers 64 bits natifs) : les noms de fichiers déjà en cache sur les téléphones doivent rester identiques.
String _old(String s) {
  var h = 0xcbf29ce484222325;
  for (final c in s.codeUnits) {
    h = ((h ^ c) * 0x100000001b3) & 0x7fffffffffffffff;
  }
  return h.toRadixString(36);
}

void main() {
  test('même empreinte que l\'ancien calcul 64 bits', () {
    for (final s in ['a', 'https://cdn.afrolookmedia.com/media/musique/abc.m4a', 'Éléphant 🎵 chanson', 'x' * 500]) {
      expect(fnv63(s), _old(s));
    }
  });
}
