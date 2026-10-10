import 'package:afrotok/pages/cards/card_models.dart';
import 'package:afrotok/pages/cards/card_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('styles Pro par défaut : 21 styles Pro, 5 gratuits', () {
    expect(CardStyleIdX.defaultPro.length, 21);
    expect(CardStyleIdX.freeStyles.length, 5);
    for (final f in CardStyleIdX.freeStyles) {
      expect(CardStyleIdX.defaultPro.contains(f.name), false);
    }
    expect(CardStyleId.values.length, 26);
  });

  test('chaque style appartient à une famille et a un nom', () {
    for (final s in CardStyleId.values) {
      expect(s.label.isNotEmpty && s.subtitle.isNotEmpty, true);
    }
    expect(CardPack.values.expand((p) => p.styles).length, CardStyleId.values.length);
  });

  test('fête nationale : les styles drapeau ne sont plus Pro, les autres le restent', () {
    final normal = CardQuote.fallback();
    expect(normal.isPro(CardStyleId.passport), true);
    final promo = CardQuote.fromMap({
      'prices': {'capture': 25, 'publish': 10, 'proStyle': 20, 'pass': 400, 'passDays': 30},
      'promo': {'flagFree': true, 'country': 'TG'},
    });
    expect(promo.promoFlagCountry, 'TG');
    expect(promo.isPro(CardStyleId.passport), false);
    expect(promo.isPro(CardStyleId.duo), false);
    expect(promo.isPro(CardStyleId.manga), true);
    expect(promo.isPro(CardStyleId.neon), false);
  });
}
