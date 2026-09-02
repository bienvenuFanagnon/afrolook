import 'dart:convert';
import 'package:afrotok/pages/component/consoleWidget.dart';

import 'package:shared_preferences/shared_preferences.dart';

/// Service de cache local (SharedPreferences) pour le feed home.
///
/// Permet un affichage "instantané" (Facebook-style) du dernier contenu
/// chargé avec succès, pendant qu'un rafraîchissement réseau s'exécute en
/// arrière-plan.
///
/// Format stocké (JSON) :
/// ```json
/// {
///   "cachedAt": "2026-06-13T12:34:56.789Z",
///   "data": { ... } // payload fourni par l'appelant
/// }
/// ```
class FeedCacheService {
  static const String _keyPrefix = 'feed_cache_';

  /// Construit une clé de cache unique par type de feed / tri.
  /// Ex: `feed_cache_RECENT_recent`, `feed_cache_SPORT_populaire`.
  static String buildKey(String type, String? sortType) {
    return '$_keyPrefix${type}_${sortType ?? 'default'}';
  }

  /// Sauvegarde les données du feed sous forme de JSON.
  ///
  /// [data] doit être entièrement sérialisable en JSON (pas de Timestamp,
  /// DocumentReference, GeoPoint, etc. - convertir avant appel).
  static Future<void> saveFeedData(String cacheKey, Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final envelope = {
        'cachedAt': DateTime.now().toIso8601String(),
        'data': data,
      };
      await prefs.setString(cacheKey, jsonEncode(envelope));
    } catch (e) {
      // Le cache est un confort, jamais bloquant : on ignore les erreurs.
      printVm('⚠️ FeedCacheService.saveFeedData error ($cacheKey): $e');
    }
  }

  /// Charge les données mises en cache.
  ///
  /// Retourne `null` si :
  /// - aucune entrée n'existe pour [cacheKey],
  /// - la valeur stockée est invalide,
  /// - [maxAge] est fourni ET les données sont plus anciennes que [maxAge],
  /// - [dailyCacheOnly] est `true` ET le cache date d'un autre jour calendaire.
  ///
  /// [dailyCacheOnly] : si `true`, le cache n'est valide que pour le jour
  /// courant (minuit → minuit). Un cache enregistré la veille ou avant est
  /// automatiquement ignoré, forçant un rechargement réseau.
  static Future<Map<String, dynamic>?> loadFeedData(
    String cacheKey, {
    Duration? maxAge,
    bool dailyCacheOnly = false,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(cacheKey);
      if (raw == null) return null;

      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;

      final cachedAtStr = decoded['cachedAt'] as String?;
      final data = decoded['data'];
      if (data is! Map<String, dynamic>) return null;

      DateTime? cachedAt;
      if (cachedAtStr != null) {
        cachedAt = DateTime.tryParse(cachedAtStr);
      }

      // Expiration par durée fixe
      if (maxAge != null && cachedAt != null) {
        final age = DateTime.now().difference(cachedAt);
        if (age > maxAge) return null;
      }

      // Expiration journalière : cache valide seulement si même jour calendaire
      if (dailyCacheOnly && cachedAt != null) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final cacheDay = DateTime(cachedAt.year, cachedAt.month, cachedAt.day);
        if (cacheDay != today) {
          printVm('🗑️ FeedCacheService: cache expiré (jour différent) — $cacheKey');
          // Supprimer le cache périmé proprement
          try { await prefs.remove(cacheKey); } catch (_) {}
          return null;
        }
      }

      return {
        'data': data,
        'cachedAt': cachedAt,
      };
    } catch (e) {
      printVm('⚠️ FeedCacheService.loadFeedData error ($cacheKey): $e');
      return null;
    }
  }

  /// Indique si des données en cache existent et sont plus vieilles que
  /// [maxAge] (utile pour décider d'un rafraîchissement immédiat même si on
  /// affiche déjà le contenu en cache).
  static bool isStale(DateTime? cachedAt, Duration maxAge) {
    if (cachedAt == null) return true;
    return DateTime.now().difference(cachedAt) > maxAge;
  }
}
