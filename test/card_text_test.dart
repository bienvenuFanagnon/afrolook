import 'package:afrotok/pages/cards/card_models.dart';
import 'package:afrotok/pages/cards/card_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('separateTags', () {
    test('sort les hashtags et les liens du texte', () {
      final p = separateTags('Belle journée à Dakar #corniche #Dakar2026 https://afrolookmedia.com/share/post/abc  voir ici');
      expect(p.tags, ['#corniche', '#Dakar2026']);
      expect(p.links, ['https://afrolookmedia.com/share/post/abc']);
      expect(p.body, 'Belle journée à Dakar voir ici');
    });
    test('garde les accents dans les hashtags et nettoie les sauts de ligne', () {
      final p = separateTags('Salut\n\n\n\nà tous #été');
      expect(p.tags, ['#été']);
      expect(p.body, 'Salut\n\nà tous');
    });
  });

  group('splitSentences', () {
    test('découpe sur . ! ? … et les sauts de ligne', () {
      expect(splitSentences('Bonjour tout le monde. Ça va ? Super !\nMerci…'), ['Bonjour tout le monde.', 'Ça va ?', 'Super !', 'Merci…']);
    });
  });

  group('cutText', () {
    const text = 'Hier, j’ai pris le car de cinq heures pour rejoindre ma tante à Bouaké. Le chauffeur a mis une musique que je n’entendais plus depuis mon enfance. Tout le monde s’est mis à chanter.';
    test('ne coupe pas un texte qui tient', () {
      final c = cutText('Court et net.', 140);
      expect(c.truncated, false);
      expect(c.text, 'Court et net.');
    });
    test('coupe à la dernière phrase entière qui tient et ajoute « … »', () {
      final c = cutText(text, 100);
      expect(c.truncated, true);
      expect(c.text, 'Hier, j’ai pris le car de cinq heures pour rejoindre ma tante à Bouaké. …');
    });
    test('une seule phrase trop longue : coupe à un mot, jamais au milieu', () {
      final c = cutText('Une très longue phrase sans aucune ponctuation qui continue encore et encore pour dépasser largement le budget', 40);
      expect(c.truncated, true);
      expect(c.text.endsWith(' …'), true);
      expect(c.text.length <= 40, true);
      expect(c.text.replaceAll(' …', '').split(' ').every((w) => 'Une très longue phrase sans aucune ponctuation qui continue'.split(' ').contains(w)), true);
    });
    test('le budget est respecté', () {
      for (final b in [30, 60, 90, 140, 260, 380]) {
        expect(cutText(text * 4, b).text.length <= b + 2, true, reason: 'budget $b');
      }
    });
  });

  group('cardText', () {
    test('budget selon le format et le média', () {
      expect(cardCharBudget(CardFormat.portrait, hasMedia: true), 140);
      expect(cardCharBudget(CardFormat.portrait, hasMedia: false), 380);
      expect(cardCharBudget(CardFormat.story, hasMedia: true), 260);
      expect(cardCharBudget(CardFormat.square, hasMedia: true), 90);
    });
    test('mode « choisir les phrases » : assemble les phrases retenues', () {
      final spec = CardSpec(textMode: CardTextMode.pick, pickedSentences: {1, 3});
      final c = cardText('Une. Deux. Trois. Quatre.', spec, hasMedia: false);
      expect(c.text, 'Deux. Quatre.');
      expect(c.truncated, false);
    });
    test('mode « choisir » sans sélection : retombe sur le début', () {
      final spec = CardSpec(textMode: CardTextMode.pick);
      expect(cardText('Une. Deux.', spec, hasMedia: false).text, 'Une. Deux.');
    });
    test('les hashtags ne comptent pas dans le texte de la carte', () {
      final c = cardText('Bonne fête ! #tabaski #fete', CardSpec(), hasMedia: true);
      expect(c.text, 'Bonne fête !');
    });
  });

  test('lien de partage du post', () {
    expect(cardPostLink('abc'), 'https://afrolookmedia.com/share/post/abc');
  });
}
