import 'dart:convert';
import 'package:afrotok/services/api/startup_trace.dart';

import 'package:afrolook_api_client/afrolook_api_client.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../feed/feed_stock.dart';

import '../../widgets/email_verification_gate.dart';
import '../nav_cache_service.dart';

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

  // ── Feed « pour vous » : le serveur choisit des publications NON VUES (abonnements d'abord, puis goûts, découverte, nouveaux créateurs) ──
  // Le téléphone garde un STOCK persistant de posts non vus ([FeedStock]) : à la réouverture ils s'affichent tout de suite, pendant que le serveur en prépare d'autres.
  FeedStock? _stock;
  String? _stockUid;

  FeedStock get _feedStock {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (_stock == null || _stockUid != uid) {
      _stockUid = uid;
      _stock = FeedStock(
        fetch: ({String? cursor, required int limit, required bool cold}) => _fetchForYou(cursor: cursor, limit: limit, cold: cold),
        store: _PrefsFeedStockStore('feed_stock_v1_$uid'),
      );
    }
    return _stock!;
  }

  // Stock des VIDÉOS (page des vidéos verticales) : même algorithme que l'accueil (abonnements d'abord, goûts, nouveaux créateurs), un seul type de média.
  FeedStock? _videoStock;
  String? _videoStockUid;

  FeedStock get _videoFeedStock {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (_videoStock == null || _videoStockUid != uid) {
      _videoStockUid = uid;
      _videoStock = FeedStock(
        fetch: ({String? cursor, required int limit, required bool cold}) => _fetchForYou(cursor: cursor, limit: limit, cold: cold, media: 'video'),
        store: _PrefsFeedStockStore('feed_stock_video_v1_$uid'),
      );
    }
    return _videoStock!;
  }

  /// Prépare les vidéos pendant que la personne est encore sur l'accueil : la page verticale les trouve prêtes.
  void prefetchVideos() {
    if (!useApi('feed')) return;
    _videoFeedStock.prefetch();
  }

  /// Prochaines vidéos du flux infini de la page verticale (posts bruts de l'API).
  Future<List<Map<String, dynamic>>> forYouVideos({required int limit, bool reset = false}) async {
    await flushPendingViews(maxWait: const Duration(seconds: 2));
    return _videoFeedStock.next(limit: limit, reset: reset);
  }

  /// Un post vu (n'importe où) quitte les deux stocks du téléphone ; aucune requête.
  void noteSeen(String postId) {
    _feedStock.markViewed(postId);
    _videoFeedStock.markViewed(postId);
  }

  /// Vues qui n'ont pas pu partir (réseau, serveur occupé) : rejouées avant la prochaine page du fil, pour ne jamais revoir les mêmes posts.
  final Map<String, int> _pendingViews = {};
  bool _flushingViews = false;

  Future<Map<String, dynamic>> _fetchForYou({String? cursor, int limit = 20, bool cold = false, String? media}) async {
    final r = await StartupTrace.time('API /feed/for-you${media == null ? '' : ' ($media)'} (${cursor == null ? 'page 1' : 'page suivante'})',
        () => client.get('/feed/for-you', query: {'limit': limit, if (cursor != null) 'cursor': cursor, if (cold) 'cold': 1, if (media != null) 'media': media}));
    return Map<String, dynamic>.from(r as Map);
  }

  /// À appeler dès le début de l'écran de lancement : le stock enregistré est relu et la première page fraîche se prépare PENDANT le chargement.
  void prefetchHome() {
    if (!useApi('feed')) return;
    StartupTrace.mark('préchargement du feed lancé');
    _feedStock.prefetch();
    Future<void>.delayed(const Duration(seconds: 3), prefetchVideos);   // les vidéos de la page verticale se préparent juste après, sans gêner l'accueil
  }

  /// Prochaines [limit] publications du feed. [reset] = nouvelle session de lecture (ouverture, tirer pour rafraîchir) : les posts non vus déjà
  /// en stock s'affichent d'abord ; les nouveaux posts des abonnements passent devant.
  Future<List<Map<String, dynamic>>> forYou({required int limit, bool reset = false}) async {
    await flushPendingViews(maxWait: const Duration(seconds: 2));
    return _feedStock.next(limit: limit, reset: reset);
  }

  /// Rejoue les vues perdues. Une vue qui échoue 3 fois est au moins déclarée « vue » en lot (`POST /feed/seen`) : le post ne revient plus.
  Future<void> flushPendingViews({Duration maxWait = const Duration(seconds: 4)}) async {
    if (_flushingViews || _pendingViews.isEmpty) return;
    _flushingViews = true;
    try {
      await () async {
        final lost = <String>[];
        for (final id in _pendingViews.keys.take(10).toList()) {
          try {
            await client.post('/posts/$id/view');
            _pendingViews.remove(id);
          } catch (_) {
            final n = (_pendingViews[id] ?? 0) + 1;
            _pendingViews[id] = n;
            if (n >= 3) lost.add(id);
          }
        }
        if (lost.isNotEmpty) {
          try {
            await client.post('/feed/seen', body: {'post_ids': lost});
            lost.forEach(_pendingViews.remove);
          } catch (_) {/* sera retenté à la prochaine page */}
        }
      }().timeout(maxWait);
    } catch (_) {/* délai dépassé : le reste sera rejoué plus tard */} finally {
      _flushingViews = false;
    }
  }

  /// Marque une publication comme vue (et compte la vue, gains compris, côté serveur). Une seule fois par publication et par session.
  /// Aucun retour à Firebase : une erreur est affichée en clair dans le journal.
  Future<void> markViewed(String postId) async {
    if (!_viewed.add(postId)) return;
    noteSeen(postId);   // un post vu quitte les stocks du téléphone pour toujours
    try {
      await client.post('/posts/$postId/view');
    } catch (e) {
      _pendingViews.putIfAbsent(postId, () => 0); // rejouée avant la prochaine page du fil (la vue ne se perd plus)
      debugPrint('❌ API VUE EN ÉCHEC pour $postId — mise en attente, nouvel essai avant la prochaine page : $e');
    }
  }

  Future<bool>? _emailPrompt;

  Future<bool> _askEmailConfirmation() {
    final running = _emailPrompt;
    if (running != null) return running; // plusieurs requêtes refusées en même temps : une seule fenêtre
    final ctx = NavigationCacheService().navigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) return Future.value(false);
    final f = EmailVerificationGate.confirm(ctx).whenComplete(() => _emailPrompt = null);
    return _emailPrompt = f;
  }

  ApiClient get client => _client ??= ApiClient(
        baseUrl: _baseUrl,
        token: ({bool forceRefresh = false}) async => FirebaseAuth.instance.currentUser?.getIdToken(forceRefresh),
        // 403 `email_unverified` sur n'importe quelle route d'argent (cadeaux, achats, pubs récompensées, boosts…) : fenêtre « Confirme ton
        // e-mail » ouverte ici, une seule à la fois ; une fois l'e-mail confirmé, la requête est rejouée sans que l'écran ait à le gérer.
        onEmailUnverified: _askEmailConfirmation,
        appCheck: () async {
          try {
            return await FirebaseAppCheck.instance.getToken();
          } catch (_) {
            return null;
          }
        },
      );
}

/// Stock du fil enregistré dans les préférences de l'application (une clé par compte).
class _PrefsFeedStockStore implements FeedStockStore {
  _PrefsFeedStockStore(this.key);
  final String key;

  @override
  Future<String?> read() async => (await SharedPreferences.getInstance()).getString(key);

  @override
  Future<void> write(String json) async => (await SharedPreferences.getInstance()).setString(key, json);
}
