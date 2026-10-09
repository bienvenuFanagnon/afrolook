import 'package:afrotok/ads/rewards_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('clé de semaine ISO identique à celle du serveur', () {
    expect(RewardsService.weekKey(DateTime.utc(2026, 10, 9, 16)), '2026W41');
    expect(RewardsService.weekKey(DateTime.utc(2026, 1, 1)), '2026W01');
    expect(RewardsService.weekKey(DateTime.utc(2025, 12, 29)), '2026W01'); // lundi rattaché à la semaine 1 de 2026
    expect(RewardsService.weekKey(DateTime.utc(2027, 1, 3)), '2026W53'); // dimanche : encore la semaine 53 de 2026
  });
}
