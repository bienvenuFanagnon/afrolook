import 'dart:async';

import 'package:afrotok/services/feed/feed_stock.dart';
import 'package:flutter_test/flutter_test.dart';

class MemStore implements FeedStockStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String json) async => value = json;
}

Map<String, dynamic> post(String id, {String reason = 'taste'}) => {'id': id, 'reason': reason};

/// Faux serveur : renvoie les pages dans l'ordre ; `cold` et les curseurs demandés sont enregistrés.
class FakeServer {
  FakeServer(this.pages);
  final List<List<Map<String, dynamic>>> pages;
  final List<bool> colds = [];
  final List<String?> cursors = [];
  int i = 0;

  Future<Map<String, dynamic>> call({String? cursor, required int limit, required bool cold}) async {
    colds.add(cold);
    cursors.add(cursor);
    final rows = i < pages.length ? pages[i] : <Map<String, dynamic>>[];
    i++;
    return {'data': rows, 'next_cursor': rows.isEmpty ? null : 'c$i'};
  }
}

List<String> ids(List<Map<String, dynamic>> l) => l.map((m) => m['id'] as String).toList();

void main() {
  test('premier lancement sans stock : on attend le serveur, le stock est enregistré, « cold » n\'est demandé qu\'une fois', () async {
    final store = MemStore();
    final server = FakeServer([[post('a'), post('b'), post('c')], [post('d')]]);
    final stock = FeedStock(fetch: server.call, store: store);
    final out = await stock.next(limit: 2, reset: true);
    expect(ids(out), ['a', 'b']);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(server.colds.first, isTrue);
    expect(server.colds.skip(1).every((c) => !c), isTrue);
    await stock.saveNow();
    expect(store.value, contains('"delivered"'));
  });

  test('réouverture : les posts non vus s\'affichent TOUT DE SUITE (même si le serveur ne répond pas), sans « cold »', () async {
    final store = MemStore();
    final first = FeedStock(fetch: FakeServer([[post('a'), post('b'), post('c'), post('d')]]).call, store: store);
    await first.next(limit: 2, reset: true);   // a, b remis à l'écran ; c, d en attente
    await first.saveNow();

    final never = Completer<Map<String, dynamic>>();   // serveur injoignable ou très lent
    var coldSeen = true;
    final second = FeedStock(fetch: ({String? cursor, required int limit, required bool cold}) {
      coldSeen = cold;
      return never.future;
    }, store: store);
    final sw = Stopwatch()..start();
    final out = await second.next(limit: 3, reset: true);
    expect(ids(out), ['a', 'b', 'c']);   // a, b (remis mais pas vus) puis c
    expect(sw.elapsedMilliseconds, lessThan(1500));
    expect(coldSeen, isFalse);
  });

  test('les nouveaux posts des ABONNEMENTS passent devant le stock et devant la découverte', () async {
    final store = MemStore();
    final first = FeedStock(fetch: FakeServer([[post('a'), post('b'), post('c')]]).call, store: store);
    await first.next(limit: 1, reset: true);   // a remis ; b, c en attente
    await first.saveNow();

    final fresh = FakeServer([[post('x1'), post('f1', reason: 'following'), post('f2', reason: 'following'), post('b')]]);
    final second = FeedStock(fetch: fresh.call, store: store);
    final out = await second.next(limit: 6, reset: true);
    expect(ids(out).take(2), ['f1', 'f2']);        // abonnements en tête
    expect(ids(out), ['f1', 'f2', 'a', 'b', 'c', 'x1']);   // puis le stock, puis la découverte ; « b » n'est pas en double
  });

  test('un post VU quitte le stock pour toujours et n\'est plus jamais reservi', () async {
    final store = MemStore();
    final stock = FeedStock(fetch: FakeServer([[post('a'), post('b'), post('c')]]).call, store: store);
    await stock.next(limit: 3, reset: true);
    stock.markViewed('b');
    await stock.saveNow();

    final again = FeedStock(fetch: FakeServer([[post('b'), post('d')]]).call, store: store);
    final out = await again.next(limit: 10, reset: true);
    expect(ids(out), isNot(contains('b')));
    expect(ids(out).toSet(), {'a', 'c', 'd'});
  });

  test('stock expiré (plus de 48 h) : abandonné', () async {
    final store = MemStore();
    var now = DateTime(2026, 11, 1, 10);
    final old = FeedStock(fetch: FakeServer([[post('a'), post('b')]]).call, store: store, now: () => now);
    await old.next(limit: 1, reset: true);
    await old.saveNow();

    now = now.add(const Duration(hours: 49));
    final server = FakeServer([[post('z')]]);
    final fresh = FeedStock(fetch: server.call, store: store, now: () => now);
    final out = await fresh.next(limit: 5, reset: true);
    expect(ids(out), ['z']);
    expect(server.colds.first, isTrue);   // plus rien en cache : le serveur doit tout reservir
  });

  test('file infinie : une fin de fil n\'est pas définitive, on repart après le délai d\'attente', () async {
    var now = DateTime(2026, 11, 1, 10);
    final server = FakeServer([[post('a')], [], [post('n1')]]);
    final stock = FeedStock(fetch: server.call, store: MemStore(), now: () => now);
    expect(ids(await stock.next(limit: 5, reset: true)), ['a']);
    stock.markViewed('a');
    expect(await stock.next(limit: 5), isEmpty);       // épuisé
    now = now.add(const Duration(seconds: 10));
    expect(await stock.next(limit: 5), isEmpty);       // délai d'attente : pas de nouvelle demande en boucle
    final calls = server.i;
    now = now.add(const Duration(seconds: 60));
    expect(ids(await stock.next(limit: 5)), ['n1']);   // le serveur a de nouveau des posts : on repart
    expect(server.i, greaterThan(calls));
  });

  test('aucun doublon entre les pages, et les posts déjà vus ne reviennent pas', () async {
    final stock = FeedStock(fetch: FakeServer([[post('a'), post('b')], [post('b'), post('c')], [post('c'), post('a'), post('d')]]).call, store: MemStore());
    final out = [...await stock.next(limit: 2, reset: true)];
    stock.markViewed('a');
    out.addAll(await stock.next(limit: 3));
    expect(ids(out).toSet().length, ids(out).length);
    expect(ids(out).where((x) => x == 'a').length, 1);   // « a » vu : le serveur a beau le renvoyer, il n'est pas reservi
  });

  test('jamais plus de 2 posts de suite du même créateur ni du même canal, y compris entre deux pages', () async {
    Map<String, dynamic> p(String id, String author, {String? channel}) => {'id': id, 'reason': 'taste', 'author': {'id': author}, if (channel != null) 'channel_id': channel};
    final pages = [
      [p('a1', 'A'), p('a2', 'A'), p('a3', 'A'), p('a4', 'A'), p('b1', 'B'), p('c1', 'C'), p('d1', 'D', channel: 'X'), p('e1', 'E', channel: 'X'), p('f1', 'F', channel: 'X'), p('g1', 'G', channel: 'X')],
      [p('a5', 'A'), p('h1', 'H'), p('i1', 'I')],
    ];
    final stock = FeedStock(fetch: FakeServer(pages).call, store: MemStore());
    final seq = [...await stock.next(limit: 6, reset: true), ...await stock.next(limit: 8)];
    int maxRun(String? Function(Map<String, dynamic>) keyOf) {
      var best = 0, run = 0;
      String? prev;
      for (final m in seq) {
        final k = keyOf(m);
        run = (k != null && k == prev) ? run + 1 : 1;
        prev = k;
        if (run > best) best = run;
      }
      return best;
    }
    expect(seq.length, greaterThan(10));
    expect(maxRun((m) => (m['author'] as Map)['id'] as String?), lessThanOrEqualTo(2));
    expect(maxRun((m) => m['channel_id'] as String?), lessThanOrEqualTo(2));
  });

}
