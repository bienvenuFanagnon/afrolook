import 'dart:async';
import 'dart:collection';

import 'package:afrotok/services/api/posts_api.dart';

import '../models/model_data.dart';

/// Une page de commentaires (avec leurs auteurs) et de quoi demander la suivante.
class CommentPage {
  CommentPage({required this.comments, required this.last, required this.hasMore});
  final List<PostComment> comments;
  final String? last;   // curseur de la page suivante (API)
  final bool hasMore;
}

/// Préchargement des commentaires : quand un post s'affiche, ses premiers commentaires sont cherchés une seule fois (cache mémoire),
/// puis la page « Commentaires » les trouve déjà prêts, auteurs compris, et lit la page suivante en avance.
///
/// Coût maîtrisé : une seule lecture par post (même si 5 écrans le demandent), 5 commentaires au lieu de 10, les auteurs des 3 premiers
/// seulement, et un cache des profils d'auteurs (les mêmes personnes commentent souvent).
class CommentsPrefetch {
  CommentsPrefetch._();
  static final CommentsPrefetch instance = CommentsPrefetch._();

  /// Taille d'une page : 5 à l'ouverture, puis 5 de plus à chaque « Voir plus » (déjà lus en avance).
  static const int pageSize = 5;

  /// Auteurs chargés d'avance dans le fil : les 3 premiers commentaires.
  static const int feedAuthors = 3;
  static const Duration _ttl = Duration(minutes: 5);
  static const int _maxPosts = 40;

  final LinkedHashMap<String, _Entry> _cache = LinkedHashMap();
  final Map<String, Future<CommentPage>> _inflight = {};

  /// Première page déjà prête et encore fraîche, sinon null.
  CommentPage? peek(String postId) {
    final e = _cache[postId];
    if (e == null) return null;
    if (DateTime.now().difference(e.at) > _ttl) {
      _cache.remove(postId);
      return null;
    }
    // Plus récent en dernier (LRU)
    _cache.remove(postId);
    _cache[postId] = e;
    return e.page;
  }

  /// Première page : depuis le cache, sinon une lecture (partagée si plusieurs écrans la demandent en même temps).
  Future<CommentPage> first(String postId) {
    final cached = peek(postId);
    if (cached != null) return Future.value(cached);
    return _inflight[postId] ??= _loadFirst(postId).whenComplete(() => _inflight.remove(postId));
  }

  /// À appeler quand un post s'affiche : prépare ses premiers commentaires sans bloquer ni lever d'erreur.
  void prefetch(String postId) {
    first(postId).then((_) {}, onError: (_) {});
  }

  Future<CommentPage> _loadFirst(String postId) async {
    final page = await loadPage(postId, limit: pageSize, authors: feedAuthors);
    _put(postId, page);
    return page;
  }

  void _put(String postId, CommentPage page) {
    _cache.remove(postId);
    _cache[postId] = _Entry(page, DateTime.now());
    while (_cache.length > _maxPosts) {
      _cache.remove(_cache.keys.first);
    }
  }

  /// Une page de commentaires, du plus récent au plus ancien (API). [after] : curseur renvoyé par la page précédente.
  /// Les auteurs viennent déjà avec les commentaires (pas de lecture de profil séparée).
  Future<CommentPage> loadPage(String postId, {String? after, int limit = pageSize, int? authors}) async {
    final page = await CommentsApi.list(postId, cursor: after, limit: limit);
    return CommentPage(comments: page.comments, last: page.nextCursor, hasMore: page.nextCursor != null);
  }

  /// Les auteurs sont fournis par l'API avec les commentaires : rien à compléter.
  Future<void> fillAuthors(Iterable<PostComment> comments) async {}

  /// Profil d'un auteur : déjà fourni par l'API avec chaque commentaire, rien à relire ici.
  Future<UserData?> user(String userId) async => null;

  /// Un commentaire vient d'être posté : il passe en tête de la page en cache (sinon la page suivante le redonnerait en double).
  void addLocal(String postId, PostComment comment) {
    final e = _cache[postId];
    if (e == null) return;
    if (comment.id != null && e.page.comments.any((c) => c.id == comment.id)) return;
    e.page.comments.insert(0, comment);
  }

  void invalidate(String postId) {
    _cache.remove(postId);
  }
}

class _Entry {
  _Entry(this.page, this.at);
  final CommentPage page;
  final DateTime at;
}
