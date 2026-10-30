import 'package:afrotok/widgets/feed/feed_slot_planner.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Widget w(String k) => SizedBox(key: ValueKey(k));

/// Simule 40 publications ; renvoie les numéros de publication après lesquels un élément est inséré.
List<int> run(FeedSlotPlanner p, void Function(FeedSlotPlanner, int) offers) {
  final slots = <int>[];
  for (var n = 1; n <= 40; n++) {
    offers(p, n);
    if (p.takeAfter(n).isNotEmpty) slots.add(n);
  }
  return slots;
}

void main() {
  test('les 3 premières publications sont libres, puis au plus un élément toutes les 4 publications', () {
    final slots = run(FeedSlotPlanner(), (p, n) {
      p.offer(FeedSlotPriority.engagement, w('q$n'), n); // beaucoup d'éléments proposés à chaque publication
      p.offer(FeedSlotPriority.discovery, w('d$n'), n);
    });
    expect(slots.first, greaterThan(3));
    for (var i = 1; i < slots.length; i++) {
      expect(slots[i] - slots[i - 1], greaterThanOrEqualTo(4));
    }
    expect(slots.length, lessThanOrEqualTo(10)); // au plus 1 pour 4 sur 40 publications
  });

  test('les pubs passent avant l\'engagement, puis la découverte', () {
    final p = FeedSlotPlanner();
    p.offer(FeedSlotPriority.discovery, w('disc'), 1);
    p.offer(FeedSlotPriority.engagement, w('eng'), 1);
    p.offer(FeedSlotPriority.ad, w('ad'), 1);
    final order = <String>[];
    for (var n = 1; n <= 40 && order.length < 3; n++) {
      for (final x in p.takeAfter(n)) {
        order.add((x.key as ValueKey<String>).value);
      }
    }
    expect(order, ['ad', 'eng', 'disc']);
  });

  test('un élément qui attend trop longtemps est abandonné ; rien à insérer = rien', () {
    final p = FeedSlotPlanner(maxWait: 5);
    p.offer(FeedSlotPriority.discovery, w('vieux'), 1);
    expect(p.takeAfter(2), isEmpty);
    expect(p.takeAfter(7), isEmpty); // 7 - 1 > 5 : abandonné
    expect(p.takeAfter(8), isEmpty);
  });
}
