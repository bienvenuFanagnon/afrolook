import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/model_data.dart';
import '../../pages/chronique/chroniqueform.dart';
import '../../pages/component/consoleWidget.dart';

/// Cache de démarrage de la page home.
///
/// Principe :
/// 1. Avant d'ouvrir HomeConstPost, appeler [HomeBootCache.preload(userId)].
/// 2. Dans initState() de HomeConstPost, lire [HomeBootCache.instance] de
///    façon SYNCHRONE — pas d'await, pas de setState, le premier build
///    dispose déjà des données.
///
/// Clé : "home_boot_<userId>" — stable, indépendante du pays/filtre.
/// Contient au maximum [maxPosts] posts + sections légères.
class HomeBootCache {
  static const String _prefix = 'home_boot_';
  static const int maxPosts = 5;

  // ── Singleton ──────────────────────────────────────────────────────────────
  static HomeBootCache? _instance;
  static HomeBootCache get instance => _instance ??= HomeBootCache._();
  HomeBootCache._();

  // ── Données pré-chargées ──────────────────────────────────────────────────
  List<Post> posts = [];
  List<Chronique> chroniques = [];
  List<UserData> suggestedUsers = [];
  bool isReady = false;

  // ── API publique ──────────────────────────────────────────────────────────

  /// À appeler depuis le splash / la transition vers home.
  /// Rapide (< 20 ms) si le cache existe.
  static Future<void> preload(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_prefix$userId');
      if (raw == null) return;

      final decoded = jsonDecode(raw) as Map<String, dynamic>;

      final inst = HomeBootCache.instance;
      inst.posts = _parsePosts(decoded['posts']);
      inst.chroniques = _parseChroniques(decoded['chroniques']);
      inst.suggestedUsers = _parseUsers(decoded['suggestedUsers']);
      inst.isReady = inst.posts.isNotEmpty;

      printVm('⚡ HomeBootCache: ${inst.posts.length} posts, '
          '${inst.chroniques.length} chroniques, '
          '${inst.suggestedUsers.length} profils');
    } catch (e) {
      printVm('⚠️ HomeBootCache.preload error: $e');
    }
  }

  /// Sauvegarder après chaque chargement réseau réussi.
  static Future<void> save({
    required String userId,
    required List<Post> posts,
    required List<Chronique> chroniques,
    required List<UserData> suggestedUsers,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = {
        'savedAt': DateTime.now().toIso8601String(),
        'posts': posts.take(maxPosts).map(_serializePost).toList(),
        'chroniques': chroniques.map(_serializeChronique).toList(),
        'suggestedUsers': suggestedUsers.take(8).map((u) {
          final j = u.toJson();
          j['isVerify'] = u.isVerify ?? false;
          return j;
        }).toList(),
      };
      await prefs.setString('$_prefix$userId', jsonEncode(data));
    } catch (e) {
      printVm('⚠️ HomeBootCache.save error: $e');
    }
  }

  /// Réinitialiser l'instance (lors de la déconnexion par ex.)
  static void reset() {
    _instance = HomeBootCache._();
  }

  // ── Sérialisation ─────────────────────────────────────────────────────────

  static Map<String, dynamic> _serializePost(Post p) {
    final json = p.toJson(); // toJson() gère déjà les Timestamps → int
    json['id'] = p.id;
    return json;
  }

  static Map<String, dynamic> _serializeChronique(Chronique c) {
    final map = Map<String, dynamic>.from(c.toMap());
    map['id'] = c.id;
    if (map['createdAt'] is Timestamp) {
      map['createdAt'] =
          (map['createdAt'] as Timestamp).toDate().toIso8601String();
    }
    if (map['expiresAt'] is Timestamp) {
      map['expiresAt'] =
          (map['expiresAt'] as Timestamp).toDate().toIso8601String();
    }
    return map;
  }

  // ── Désérialisation ───────────────────────────────────────────────────────

  static List<Post> _parsePosts(dynamic raw) {
    if (raw == null) return [];
    final list = <Post>[];
    for (final item in raw as List<dynamic>) {
      try {
        final json = Map<String, dynamic>.from(item as Map);
        final post = Post.fromJson(json);
        post.id = json['id'] as String?;
        list.add(post);
      } catch (e) {
        printVm('⚠️ HomeBootCache: erreur parsing post: $e');
      }
    }
    return list;
  }

  static List<Chronique> _parseChroniques(dynamic raw) {
    if (raw == null) return [];
    final list = <Chronique>[];
    for (final item in raw as List<dynamic>) {
      try {
        final map = Map<String, dynamic>.from(item as Map);
        final id = map['id'] as String? ?? '';
        if (map['createdAt'] is String) {
          map['createdAt'] =
              Timestamp.fromDate(DateTime.parse(map['createdAt'] as String));
        }
        if (map['expiresAt'] is String) {
          map['expiresAt'] =
              Timestamp.fromDate(DateTime.parse(map['expiresAt'] as String));
        }
        final c = Chronique.fromMap(map, id);
        if (!c.isExpired) list.add(c);
      } catch (e) {
        printVm('⚠️ HomeBootCache: erreur parsing chronique: $e');
      }
    }
    return list;
  }

  static List<UserData> _parseUsers(dynamic raw) {
    if (raw == null) return [];
    final list = <UserData>[];
    for (final item in raw as List<dynamic>) {
      try {
        list.add(UserData.fromJson(Map<String, dynamic>.from(item as Map)));
      } catch (e) {
        printVm('⚠️ HomeBootCache: erreur parsing user: $e');
      }
    }
    return list;
  }
}
