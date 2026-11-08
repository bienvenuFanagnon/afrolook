import 'package:afrotok/services/api/post_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

/// Interactions affichées sur un post (08/11/2026) : j'aime + commentaires + partages + republications, calculées depuis les compteurs de l'API
/// (l'ancien compteur du serveur n'était pas envoyé : tous les posts affichaient 0).
void main() {
  Map<String, dynamic> row(Map<String, dynamic> counts) => {'id': 'p1', 'author': {'id': 'a1', 'username': 'ama'}, 'description': 'x', 'counts': counts};

  test('un post avec des j\'aime et des commentaires n\'affiche plus 0', () {
    final p = postFromApi(row({'likes': 12, 'comments': 5, 'shares': 3, 'views': 400, 'reposts': 2}));
    expect(p.interactionsCount, 22);   // 12 + 5 + 3 + 2, sans les 400 vues
  });

  test('un post sans rien affiche 0', () {
    expect(postFromApi(row({})).interactionsCount, 0);
  });

  test('un j\'aime ou un commentaire fait sur le téléphone se voit tout de suite', () {
    final p = postFromApi(row({'likes': 1, 'comments': 0}));
    expect(p.interactionsCount, 1);
    p.loves = (p.loves ?? 0) + 1;
    p.comments = (p.comments ?? 0) + 1;
    expect(p.interactionsCount, 3);
  });
}
