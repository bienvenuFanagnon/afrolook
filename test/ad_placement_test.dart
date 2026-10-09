import 'package:afrotok/ads/ad_placement.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pub après la 4e ligne puis toutes les 10 lignes', () {
    expect(AdPlacement.afterRows(30, startAt: 4, every: 10), [4, 14, 24]);
  });

  test('aucune pub après la dernière ligne ni sur une liste trop courte', () {
    expect(AdPlacement.afterRows(4, startAt: 4, every: 10), isEmpty);
    expect(AdPlacement.afterRows(5, startAt: 4, every: 10), [4]);
    expect(AdPlacement.afterRows(0, startAt: 4, every: 10), isEmpty);
  });

  test('les conversations épinglées restent en tête', () {
    expect(AdPlacement.afterRows(30, startAt: 4, every: 10, pinned: 6), [7, 17, 27]);
    expect(AdPlacement.afterRows(30, startAt: 4, every: 10, pinned: 2), [4, 14, 24]);
  });
}
