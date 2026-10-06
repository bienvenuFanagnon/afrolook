/// Phrases de défi de la mascotte : culture, niveau, points. Une par jour, qui change selon `salt`.
/// Les textes sont traduits dans `tr_defi.dart` : toute modification doit y être reportée.
const List<String> kQuizDefiLines = [
  'On ne peut pas célébrer notre culture sans la connaître. Teste ton niveau !',
  'Tu te crois capable de répondre à 3 questions sans faute ?',
  'Teste ton niveau d\'intello ici !',
  'Gagne des points avec ta connaissance !',
  'Trois questions, zéro erreur : prouve-le !',
  'Tes amis savent beaucoup… et toi ? Grimpe au classement !',
  'Connaître l\'Afrique, c\'est la faire briller. À toi de jouer !',
  'Un cerveau bien rempli vaut de l\'or : fais le plein de points !',
];

/// Phrases tournées vers les cours (pages et cartes Étude).
const List<String> kEtudeDefiLines = [
  'Savoir, c\'est pouvoir : lis ce cours et teste-toi !',
  'Tu crois tout savoir ? Lis ce cours, puis prouve-le au quiz !',
  'Un cours lu, un quiz réussi : gagne tes points de savoir !',
  'Ton diplôme se gagne avec ta tête : montre ce que tu vaux !',
];

String pickDefiLine(List<String> lines, [int salt = 0]) {
  final d = DateTime.now();
  return lines[(d.year * 372 + d.month * 31 + d.day + salt) % lines.length];
}
