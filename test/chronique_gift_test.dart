import 'package:afrotok/services/api/chroniques_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

/// Cadeaux sur les chroniques (20/11/2026) : le total des pièces offertes envoyé par l'API arrive sur la chronique (affiché à tous sous l'icône cadeau).
void main() {
  Map<String, dynamic> row(Map<String, dynamic> extra) => {
        'id': 'c1', 'author': {'id': 'a1', 'username': 'ama'}, 'type': 'text', 'text': 'salut',
        'created_at': '2026-11-20T10:00:00Z', 'expires_at': '2026-11-21T10:00:00Z', ...extra,
      };

  test('le total des pièces offertes est lu depuis l\'API', () {
    expect(chroniqueFromApi(row({'gift_coins': 1500})).giftCoins, 1500);
  });

  test('sans cadeau : 0', () {
    expect(chroniqueFromApi(row({})).giftCoins, 0);
  });
}
