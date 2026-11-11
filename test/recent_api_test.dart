import 'package:afrotok/services/api/recent_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('onglet Récents : la réponse de l\'API devient des posts dans l\'ordre reçu, avec le curseur suivant', () {
    final page = RecentApi.parse({
      'data': [
        {'id': 'p1', 'author': {'id': 'a1', 'username': 'ama'}, 'description': 'un look'},
        {'id': 'p2', 'author': {'id': 'a2', 'username': 'kofi'}, 'description': 'une sortie'},
        {'description': 'sans identifiant : ignoré'},
      ],
      'next_cursor': 'abc',
    });
    expect(page.posts.map((e) => e.id), ['p1', 'p2']);
    expect(page.next, 'abc');
    final end = RecentApi.parse({'data': [], 'next_cursor': null});
    expect(end.posts, isEmpty);
    expect(end.next, isNull);
  });
}
