import 'package:flutter/services.dart';

/// Longueur d'un pseudo : 3 à 20 caractères (pseudos courts).
const int kPseudoMinLength = 3;
const int kPseudoMaxLength = 20;

/// Nom d'un canal : même règle de format, 3 à 30 caractères.
const int kCanalMinLength = 3;
const int kCanalMaxLength = 30;

/// Règle des pseudos : minuscules, mots séparés par un point (ex. « olivier.bernard »).
/// Espaces, tirets et underscores deviennent des points ; accents retirés ; seuls a-z, 0-9 et « . » restent ;
/// pas de point au début, à la fin ni doublé.
/// La même règle est appliquée par la migration serveur (functions/src/users/pseudoMigration.ts).
String normalizePseudo(String input) {
  const from = 'àáâãäåçèéêëìíîïñòóôõöùúûüýÿœæ';
  const to = ['a', 'a', 'a', 'a', 'a', 'a', 'c', 'e', 'e', 'e', 'e', 'i', 'i', 'i', 'i', 'n', 'o', 'o', 'o', 'o', 'o', 'u', 'u', 'u', 'u', 'y', 'y', 'oe', 'ae'];
  final b = StringBuffer();
  for (final ch in input.trim().toLowerCase().split('')) {
    final i = from.indexOf(ch);
    b.write(i >= 0 ? to[i] : ch);
  }
  var s = b.toString().replaceAll(RegExp(r'[\s_\-]+'), '.').replaceAll(RegExp(r'[^a-z0-9.]'), '');
  s = s.replaceAll(RegExp(r'\.{2,}'), '.');
  return s.replaceAll(RegExp(r'^\.+|\.+$'), '');
}

/// Applique la règle pendant la saisie (le point final est toléré pour pouvoir écrire « olivier. »).
class PseudoInputFormatter extends TextInputFormatter {
  final int maxLength;
  PseudoInputFormatter({this.maxLength = kPseudoMaxLength});

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final trailingDot = RegExp(r'[\s_\-.]$').hasMatch(newValue.text);
    var t = normalizePseudo(newValue.text);
    if (trailingDot && t.isNotEmpty) t = '$t.';
    if (t.length > maxLength) t = t.substring(0, maxLength);
    return TextEditingValue(text: t, selection: TextSelection.collapsed(offset: t.length));
  }
}
