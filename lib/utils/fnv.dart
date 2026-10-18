/// Empreinte FNV-1a 63 bits d'un texte, en base 36. Calculée avec BigInt pour compiler aussi sur le web
/// (les littéraux 64 bits n'y sont pas représentables) tout en donnant les mêmes valeurs que sur téléphone.
String fnv63(String s) {
  final prime = BigInt.parse('100000001b3', radix: 16);
  final mask = BigInt.parse('7fffffffffffffff', radix: 16);
  var h = BigInt.parse('cbf29ce484222325', radix: 16);
  for (final c in s.codeUnits) {
    h = ((h ^ BigInt.from(c)) * prime) & mask;
  }
  return h.toRadixString(36);
}
