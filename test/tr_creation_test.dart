import 'package:afrotok/l10n/tr.dart';
import 'package:afrotok/l10n/tr_creation.dart';
import 'package:flutter_test/flutter_test.dart';

Set<String> _vars(String s) => RegExp(r'\{(\w+)\}').allMatches(s).map((m) => m.group(1)!).toSet();

void main() {
  test('chaque texte du parcours a une traduction anglaise qui garde les mêmes variables', () {
    for (final e in kTrCreation.entries) {
      final en = e.value['en'];
      expect(en, isNotNull, reason: e.key);
      expect(en!.trim(), isNotEmpty, reason: e.key);
      expect(_vars(en), _vars(e.key), reason: 'variables de « ${e.key} »');
    }
  });

  test('les écrans du parcours se traduisent, avec leurs variables', () {
    expect(trFor('en', 'Nouveau post'), 'New post');
    expect(trFor('en', 'Voix modifiée'), 'Voice changed');
    expect(trFor('en', 'En réponse à {who}', {'who': '@kofi'}), 'In reply to @kofi');
    expect(trFor('en', '{n} s gardées', {'n': '3.0'}), '3.0 s kept');
    expect(trFor('fr', 'Nouveau post'), 'Nouveau post');
    // les six autres langues sont traduites, avec leurs variables
    expect(trFor('sw', 'Pochette'), 'Jalada');
    expect(trFor('es', 'En réponse à {who}', {'who': '@kofi'}), contains('@kofi'));
    expect(trFor('ar', '{n} s gardées', {'n': '3'}), contains('3'));
    // texte inconnu : jamais vide, le français est rendu tel quel
    expect(trFor('sw', 'Un texte jamais traduit'), 'Un texte jamais traduit');
  });
}
