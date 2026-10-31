import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/services/api/publications_api.dart';

/// Listes de vidéos / vibes via l'API (pages par curseur). Aucun retour à Firebase.
/// Le serveur ne filtre pas encore le fil par type de média ni par thème (voir lacunes_api_publications_restantes.md) :
/// le filtre est appliqué ici, sur quelques pages à la suite, pour remplir un lot.
class PubVideosApi {
  PubVideosApi._();

  /// Un lot de vidéos non vues. [category] : par exemple `VIBE` (thème). [exclude] : identifiants déjà affichés.
  static Future<({List<Post> posts, String? next})> videos({String? category, String? cursor, int limit = 10, Set<String> exclude = const {}, int maxPages = 4, int tier = 3}) async {
    final out = <Post>[];
    var cur = cursor;
    var pages = 0;
    do {
      final r = await PubApi.discover(cursor: cur, limit: 30, tier: tier);
      cur = r.next;
      pages++;
      for (final p in r.posts) {
        if (p.dataType != 'VIDEO') continue;
        if (category != null && p.categorie != category && p.typeTabbar != category) continue;
        if (p.id == null || exclude.contains(p.id) || out.any((e) => e.id == p.id)) continue;
        out.add(p);
      }
    } while (out.length < limit && cur != null && pages < maxPages);
    return (posts: out, next: cur);
  }
}
