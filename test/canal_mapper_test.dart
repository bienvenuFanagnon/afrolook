import 'package:afrotok/services/api/canal_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('un canal privé mensuel de l API devient un Canal de l application', () {
    final c = canalFromApi({
      'id': 'c1', 'owner_id': 'u1', 'title': 'Club', 'description': 'd', 'image_url': 'https://cdn/x.jpg', 'cover_url': null,
      'is_verified': true, 'is_private': true, 'subscription_type': 'monthly', 'price_coins': 500, 'main_category': 'MODE',
      'score': 12.5, 'is_blocked': false, 'followers_count': 40, 'posts_count': 3, 'allow_all_members_to_post': false,
      'categories': ['MODE'], 'created_at': '2026-10-30T10:00:00+00:00',
    });
    expect(c.titre, 'Club');
    expect(c.subscriptionType, 'mensuel');
    expect(c.subscriptionPriceCoins, 500);
    expect(c.isPrivate, isTrue);
    expect(c.suivi, 40);
    expect(c.canalScore, 12.5);
    expect(c.urlCouverture, '');
    expect(c.createdAt, greaterThan(0));
  });

  test('un canal public est gratuit', () {
    final c = canalFromApi({'id': 'c2', 'owner_id': 'u1', 'title': 'Mode', 'is_private': false, 'subscription_type': 'free'});
    expect(c.subscriptionType, 'gratuit');
    expect(c.isBlocked, isFalse);
  });
}
