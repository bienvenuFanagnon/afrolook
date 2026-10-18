import 'package:afrotok/services/read_meter.dart';
import 'dart:async';
import 'dart:collection';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/model_data.dart';

/// Une page de commentaires (avec leurs auteurs) et de quoi demander la suivante.
class CommentPage {
  CommentPage({required this.comments, required this.last, required this.hasMore});
  final List<PostComment> comments;
  final DocumentSnapshot? last;
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
  static const Duration _userTtl = Duration(minutes: 10);
  static const int _maxPosts = 40;
  static const int _maxUsers = 300;

  final LinkedHashMap<String, _Entry> _cache = LinkedHashMap();
  final Map<String, Future<CommentPage>> _inflight = {};
  final LinkedHashMap<String, _CachedUser> _users = LinkedHashMap();

  FirebaseFirestore get _db => FirebaseFirestore.instance;

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

  /// Une page de commentaires, du plus récent au plus ancien. [authors] : combien d'auteurs charger tout de suite (le reste suit à la demande).
  Future<CommentPage> loadPage(String postId, {DocumentSnapshot? after, int limit = pageSize, int? authors}) async {
    Query<Map<String, dynamic>> q = _db
        .collection('PostComments')
        .where('post_id', isEqualTo: postId)
        .orderBy('created_at', descending: true)
        .limit(limit);
    if (after != null) q = q.startAfterDocument(after);
    final snap = await q.getM('comments_prefetch.dart:89');
    final comments = snap.docs.map((d) {
      final data = Map<String, dynamic>.from(d.data());
      data['id'] = d.id;
      return PostComment.fromJson(data);
    }).toList();
    final upTo = authors == null ? comments.length : authors.clamp(0, comments.length);
    await fillAuthors(comments.take(upTo));
    return CommentPage(comments: comments, last: snap.docs.isEmpty ? null : snap.docs.last, hasMore: snap.docs.length >= limit);
  }

  /// Renseigne `comment.user` (profils en cache, un seul appel par auteur, en parallèle).
  Future<void> fillAuthors(Iterable<PostComment> comments) async {
    final list = comments.where((c) => c.user == null && (c.user_id ?? '').isNotEmpty).toList();
    if (list.isEmpty) return;
    final ids = list.map((c) => c.user_id!).toSet();
    final loaded = <String, UserData?>{};
    await Future.wait(ids.map((id) async => loaded[id] = await user(id)));
    for (final c in list) {
      c.user = loaded[c.user_id];
    }
  }

  /// Profil d'un auteur, avec cache (10 minutes).
  Future<UserData?> user(String userId) async {
    if (userId.isEmpty) return null;
    final hit = _users[userId];
    if (hit != null && DateTime.now().difference(hit.at) < _userTtl) return hit.user;
    try {
      final doc = await _db.collection('Users').doc(userId).getM('comments_prefetch.dart:118');
      final u = doc.exists ? UserData.fromJson(doc.data()!) : null;
      _users.remove(userId);
      _users[userId] = _CachedUser(u, DateTime.now());
      while (_users.length > _maxUsers) {
        _users.remove(_users.keys.first);
      }
      return u;
    } catch (_) {
      return null;
    }
  }

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

class _CachedUser {
  _CachedUser(this.user, this.at);
  final UserData? user;
  final DateTime at;
}
