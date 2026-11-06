import 'package:afrotok/services/api/commerce_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('carte Commerce : lecture de la réponse API, WhatsApp avec message prêt, appel, envoi sans champs vides', () {
    final c = PostCommerce.fromJson({
      'postId': 'p1',
      'title': 'Robes wax',
      'priceText': '15 000 F',
      'place': 'Lomé, Tokoin',
      'whatsapp': '+228 90 00 00 00',
      'phone': null,
      'linkUrl': 'https://boutique.example.com/robes',
      'linkLabel': 'Commander maintenant',
      'linkTitle': '',
      'collapsed': true,
    });
    expect(c.priceText, '15 000 F');
    expect(c.phone, isNull);
    expect(c.linkTitle, isNull); // un texte vide n'est pas un titre
    expect(c.collapsed, isTrue);
    final wa = c.whatsappUri('Bonjour, c\'est pour les robes');
    expect(wa.host, 'wa.me');
    expect(wa.path, '/22890000000'); // seuls les chiffres du numéro
    expect(wa.queryParameters['text'], 'Bonjour, c\'est pour les robes');
    final body = c.toBody();
    expect(body['title'], 'Robes wax');
    expect(body.containsKey('phone'), isFalse);
    expect(body['link_label'], 'Commander maintenant');
    expect(PostCommerce.fromJson({'postId': 'p2', 'title': 'X', 'phone': '+22891111111'}).callUri().toString(), 'tel:+22891111111');
    expect(PostCommerce.fromJson({'postId': 'p2', 'title': 'X', 'phone': '+22891111111', 'collapsed': false}).collapsed, isFalse);
  });
}
