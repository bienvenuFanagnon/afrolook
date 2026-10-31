import 'dart:convert';
import 'package:afrotok/services/api/startup_trace.dart';

import 'package:afrolook_api_client/afrolook_api_client.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

/// Point d'accès unique à la nouvelle API (Laravel). Tout est éteint par défaut : tant que Remote Config n'active pas un module
/// (clé `api_modules`, ex. {"channels": true}), l'application continue de lire Firebase comme avant.
class ApiGateway {
  ApiGateway._();
  static final ApiGateway instance = ApiGateway._();

  static const _defaultBaseUrl = 'https://api.afrolookmedia.com/v1';

  final ApiModules modules = ApiModules();
  ApiClient? _client;

  /// À appeler après `RemoteConfigService.initialize()` (et à chaque rafraîchissement de Remote Config).
  void refresh() {
    // Essais en debug : `flutter run --dart-define=API_MODULES={"feed":true} --dart-define=API_BASE_URL=http://192.168.1.20:8000/v1`
    if (!kReleaseMode && const String.fromEnvironment('API_MODULES').isNotEmpty) {   // essais (test et profile) ; jamais en version publiée
      modules.update(Map<String, dynamic>.from(jsonDecode(const String.fromEnvironment('API_MODULES')) as Map));
      const u = String.fromEnvironment('API_BASE_URL');
      _client = null;
      _baseUrl = u.isEmpty ? _defaultBaseUrl : u;
      return;
    }
    try {
      final rc = FirebaseRemoteConfig.instance;
      final raw = rc.getString('api_modules');
      modules.update(raw.isEmpty ? <String, dynamic>{} : Map<String, dynamic>.from(jsonDecode(raw) as Map));
      final url = rc.getString('api_base_url');
      _client = null; // recréé avec l'adresse à jour
      _baseUrl = url.isEmpty ? _defaultBaseUrl : url;
    } catch (e) {
      modules.update(const {}); // en cas de doute : ancien système
      if (kDebugMode) debugPrint('ApiGateway: configuration illisible, ancien système conservé ($e)');
    }
  }

  String _baseUrl = _defaultBaseUrl;

  bool useApi(String module) => FirebaseAuth.instance.currentUser != null && modules.useApi(module);

  final Set<String> _viewed = {};

  // ── Feed « pour vous » : le serveur choisit des publications NON VUES (abonnements, goûts, découverte, nouveaux créateurs) ──
  final List<Map<String, dynamic>> _queue = [];
  String? _cursor;
  bool _exhausted = false;
  Future<Map<String, dynamic>>? _prefetched;
  DateTime? _prefetchedAt;

  Future<Map<String, dynamic>> _fetchForYou({String? cursor, int limit = 20}) async {
    final r = await StartupTrace.time('API /feed/for-you (${cursor == null ? 'page 1' : 'page suivante'})', () => client.get('/feed/for-you', query: {'limit': limit, if (cursor != null) 'cursor': cursor}));
    return Map<String, dynamic>.from(r as Map);
  }

  /// À appeler dès le début de l'écran de lancement : la première page du feed se prépare PENDANT le chargement, l'accueil l'affiche ensuite sans attendre.
  void prefetchHome() {
    if (!useApi('feed') || _prefetched != null) return;
    StartupTrace.mark('préchargement du feed lancé');
    _prefetchedAt = DateTime.now();
    _prefetched = _fetchForYou().then((v) {
      StartupTrace.mark('préchargement du feed terminé');
      return v;
    });
    _prefetched!.catchError((e) {
      debugPrint('❌ API PRÉCHARGEMENT DU FEED EN ÉCHEC — aucun retour à Firebase : $e');
      return <String, dynamic>{};
    });
  }

  /// Prochaines [limit] publications du feed. [reset] = nouvelle session de lecture (ouverture, tirer pour rafraîchir).
  Future<List<Map<String, dynamic>>> forYou({required int limit, bool reset = false}) async {
    if (reset) {
      _queue.clear();
      _cursor = null;
      _exhausted = false;
      final pre = _prefetched;
      final fresh = _prefetchedAt != null && DateTime.now().difference(_prefetchedAt!) < const Duration(seconds: 90);
      _prefetched = null;
      if (pre != null && fresh) {
        try {
          final first = await pre;
          _queue.addAll((first['data'] as List? ?? const []).cast<Map<String, dynamic>>());
          _cursor = first['next_cursor'] as String?;
          _exhausted = _cursor == null;
        } catch (_) {/* échec déjà journalisé : on redemande ci-dessous */}
      }
    }
    while (_queue.length < limit && !_exhausted) {
      final page = await _fetchForYou(cursor: _cursor, limit: limit < 20 ? 20 : limit);
      final rows = (page['data'] as List? ?? const []).cast<Map<String, dynamic>>();
      _queue.addAll(rows);
      _cursor = page['next_cursor'] as String?;
      if (rows.isEmpty || _cursor == null) _exhausted = true;
    }
    final n = _queue.length < limit ? _queue.length : limit;
    final out = List<Map<String, dynamic>>.from(_queue.take(n));
    _queue.removeRange(0, n);
    return out;
  }

  /// Marque une publication comme vue (et compte la vue, gains compris, côté serveur). Une seule fois par publication et par session.
  /// Aucun retour à Firebase : une erreur est affichée en clair dans le journal.
  Future<void> markViewed(String postId) async {
    if (!_viewed.add(postId)) return;
    try {
      await client.post('/posts/$postId/view');
    } catch (e) {
      _viewed.remove(postId); // sera retenté à la prochaine visibilité
      debugPrint('❌ API VUE EN ÉCHEC pour $postId — aucun retour à Firebase : $e');
    }
  }

  ApiClient get client => _client ??= ApiClient(
        baseUrl: _baseUrl,
        token: ({bool forceRefresh = false}) async => FirebaseAuth.instance.currentUser?.getIdToken(forceRefresh),
        appCheck: () async {
          try {
            return await FirebaseAppCheck.instance.getToken();
          } catch (_) {
            return null;
          }
        },
      );
}
