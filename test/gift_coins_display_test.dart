import 'package:afrotok/services/api/post_mapper.dart';
import 'package:afrotok/services/api/posts_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('le total de pièces envoyées en cadeau (le montant payé) remplace le nombre de cadeaux sur la publication', () {
    final p = postFromApi({
      'id': 'p1',
      'author': {'id': 'a1', 'username': 'ama'},
      'description': 'un post',
      'counts': {'likes': 3, 'gift_coins': 65},   // un cadeau de 55 pièces + un de 10 pièces
    });
    expect(p.totalGiftCoinsSentOnThisPost, 65);
    expect(postFromApi({'id': 'p2', 'author': {'id': 'a1'}, 'counts': {}}).totalGiftCoinsSentOnThisPost, 0);
  });

  test('chaque commentaire et chaque réponse porte le total de pièces reçues en cadeau', () {
    final c = commentFromApi({'id': 'c1', 'post_id': 'p1', 'author': {'id': 'a2', 'username': 'kofi'}, 'body': 'bravo', 'gift_coins': 120});
    expect(c.giftCoins, 120);
    final r = replyFromApi({'id': 'r1', 'parent_id': 'c1', 'author': {'id': 'a3', 'username': 'esi'}, 'body': 'merci', 'gift_coins': 5});
    expect(r.giftCoins, 5);
    expect(commentFromApi({'id': 'c2', 'post_id': 'p1', 'author': {'id': 'a2'}}).giftCoins, 0);
  });
}
