import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/services/comments_prefetch.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('addLocal et invalidate sont sans effet ni erreur quand rien n\'est en cache', () {
    final svc = CommentsPrefetch.instance;
    expect(svc.peek('p1'), isNull);
    svc.addLocal('p1', PostComment(id: 'c1')); // rien en cache : sans effet, sans erreur
    expect(svc.peek('p1'), isNull);
    svc.invalidate('p1'); // inoffensif
  });

  test('tailles de page : 5 commentaires, auteurs des 3 premiers', () {
    expect(CommentsPrefetch.pageSize, 5);
    expect(CommentsPrefetch.feedAuthors, 3);
  });
}
