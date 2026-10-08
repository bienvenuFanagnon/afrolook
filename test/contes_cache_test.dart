import 'package:afrotok/l10n/tr.dart';
import 'package:afrotok/services/contes/contes_cache.dart';
import 'package:afrotok/services/contes/contes_service.dart';
import 'package:flutter_test/flutter_test.dart';

ConteCached _c({String rev = 'r1', String lang = 'fr', int until = 0, int total = 2}) => ConteCached(
      id: 'x', rev: rev, lang: lang, until: until, access: 'owned', total: total, free: 2, price: 10, pages: const ['a', 'b'], morale: 'm',
    );

void main() {
  test('copie valide tant que le texte, la langue et la date ne changent pas', () {
    expect(_c().validFor(rev: 'r1', lang: 'fr'), isTrue);
    expect(_c().validFor(rev: '', lang: 'fr'), isTrue); // fiche sans empreinte : on fait confiance à la copie
    expect(_c().validFor(rev: 'r2', lang: 'fr'), isFalse); // texte corrigé
    expect(_c(lang: 'fr').validFor(rev: 'r1', lang: 'en'), isFalse); // traduction arrivée
    expect(_c(total: 3).validFor(rev: 'r1', lang: 'fr'), isFalse); // nombre de pages différent
  });

  test('conte du jour et pass : expirés après leur date de fin', () {
    final now = DateTime.now().millisecondsSinceEpoch;
    expect(_c(until: now + 60000).validFor(rev: 'r1', lang: 'fr'), isTrue);
    expect(_c(until: now - 1).validFor(rev: 'r1', lang: 'fr'), isFalse);
  });

  test('aller-retour fichier', () {
    final back = ConteCached.fromMap(_c(until: 5).toMap())!;
    expect(back.pages, ['a', 'b']);
    expect(back.until, 5);
    expect(back.morale, 'm');
  });

  test('fiche : la langue de l\'application choisit titre et accroche', () {
    final m = {'id': 'a', 't': 'Titre', 'h': 'Accroche', 'org': 'Origine', 'rv': 'z', 'tr': {'en': {'t': 'Title', 'h': 'Hook', 'o': 'Origin'}}};
    final fr = ConteCard.fromMap(m);
    expect(fr.title, 'Titre');
    expect(fr.lang, 'fr');
    expect(fr.rev, 'z');
    trCurrentLanguage = 'en';
    final en = ConteCard.fromMap(m);
    expect([en.title, en.hook, en.origin, en.lang], ['Title', 'Hook', 'Origin', 'en']);
    trCurrentLanguage = 'es'; // pas de traduction espagnole : retombe sur le français
    expect(ConteCard.fromMap(m).title, 'Titre');
    trCurrentLanguage = 'fr';
  });
}
