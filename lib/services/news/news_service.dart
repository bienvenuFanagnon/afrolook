import 'package:afrotok/services/api/jeux_api.dart';
import 'package:afrolook_api_client/afrolook_api_client.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/news_article.dart';
import '../../models/news_digest.dart';
import '../../utils/country_continent.dart';

/// Réglages des actualités (AppConfig/news) : `enabled` (défaut : oui) coupe tout ; `feedEnabled` (défaut : non) montre les cartes dans le fil.
class NewsConfig {
  final bool enabled;
  final bool feedEnabled;

  /// Pays qui ont leurs propres articles (codes à 2 lettres).
  final List<String> countries;
  const NewsConfig({this.enabled = true, this.feedEnabled = false, this.countries = const []});
}

/// Accès aux actualités. Peu de lectures : l'index du fil tient en 3 documents par session (pays, continent, monde), chaque carte affichée lit
/// son article (compteurs et j'aime) et la page de détail le relit.
class NewsService {
  NewsService._();
  static final NewsService instance = NewsService._();

  static const _kSeen = 'news_seen_ids';
  static const _kHiddenDay = 'news_feed_hidden_day';
  static const _maxSeen = 80;
  static const _maxAgeMs = 5 * 24 * 3600 * 1000; // une carte du fil ne montre pas un article de plus de 5 jours

  NewsConfig? _cfg;
  DateTime? _cfgAt;
  List<NewsFeedItem>? _feed;
  String? _feedCountry;
  DateTime? _feedAt;
  final Map<String, String> _slotItem = {}; // emplacement du fil → article (stable pendant la session, même si la carte est recréée)
  final Set<String> _shown = {};
  final Set<String> _viewed = {}; // articles dont la vue a déjà été comptée pendant cette session
  final Map<String, _CachedArticle> _articles = {}; // articles déjà lus : une carte recréée en défilant ne relit pas le document

  Future<NewsConfig> loadConfig() async {
    final now = DateTime.now();
    if (_cfg != null && _cfgAt != null && now.difference(_cfgAt!).inMinutes < 10) return _cfg!;
    try {
      final d = JeuxApi.map(await JeuxApi.client.get('/config'))['news'];
      final cfgMap = d is Map ? Map<String, dynamic>.from(d) : const <String, dynamic>{};
      _cfg = NewsConfig(
        enabled: cfgMap['enabled'] != false,
        feedEnabled: cfgMap['feedEnabled'] == true || cfgMap['feed_enabled'] == true,
        countries: ((cfgMap['countries'] as List?) ?? const [
            'TG', 'BJ', 'CI', 'SN', 'CM', 'BF', 'MG', 'CG', 'CD', 'ML', 'NE', 'GN', 'GA', 'GH', 'NG', 'TD', 'ZM', 'KE', 'ZA', //
            'FR', 'BE', 'CH', 'GB', 'DE', 'ES', 'US', 'CA', 'BR', 'HT', 'MX',
          ]).map((e) => e.toString().toUpperCase()).toList(),
      );
    } catch (_) {
      _cfg = const NewsConfig();
    }
    _cfgAt = now;
    return _cfg!;
  }

  /// Articles récents, du plus proche au plus large : pays de la personne, son continent, le monde (15 minutes de cache).
  Future<List<NewsFeedItem>> feedFor(String? country) async {
    final now = DateTime.now();
    final code = (country ?? '').toUpperCase();
    if (_feed != null && _feedCountry == code && _feedAt != null && now.difference(_feedAt!).inMinutes < 15) return _feed!;
    final out = <NewsFeedItem>[];
    final ids = <String>{};
    try {
      final byScope = await _fetchFeed(country: code);
      for (final scope in newsScopesForCountry(code)) {
        for (final item in (byScope[scope] ?? const <NewsFeedItem>[])) {
          final alive = item.exp == 0 || item.exp > now.millisecondsSinceEpoch; // fin de vie dépassée : l'article ne s'affiche plus
          if (item.id.isNotEmpty && alive && ids.add(item.id) && now.millisecondsSinceEpoch - item.at < _maxAgeMs) out.add(item);
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('NewsService.feedFor : $e');
    }
    _feed = out;
    _feedCountry = code;
    _feedAt = now;
    return out;
  }

  final Map<String, _Timed<List<NewsFeedItem>>> _live = {};
  final Map<String, _Timed<NewsDigest?>> _digests = {};

  /// Articles d'un périmètre (`country_TG`, `continent_AF`, `world`) : un seul document (10 minutes de cache), sans les articles périmés.
  Future<List<NewsFeedItem>> liveScope(String scope, {bool fresh = false}) async {
    final c = _live[scope];
    if (!fresh && c != null && DateTime.now().difference(c.at).inMinutes < 10) return c.value;
    final out = <NewsFeedItem>[];
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final byScope = await _fetchFeed(scope: scope);
      for (final item in (byScope[scope] ?? const <NewsFeedItem>[])) {
        if (item.id.isNotEmpty && (item.exp == 0 || item.exp > now)) out.add(item);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('NewsService.liveScope($scope) : $e');
    }
    _live[scope] = _Timed(out);
    return out;
  }

  /// Résumé d'une période (un document, 30 minutes de cache) ; null s'il n'existe pas (pas encore paru, ou aucun article ce jour-là).
  Future<NewsDigest?> digest(String scope, String period, String key, {bool fresh = false}) async {
    final id = '${scope}_${period}_$key';
    final c = _digests[id];
    if (!fresh && c != null && DateTime.now().difference(c.at).inMinutes < 30) return c.value;
    // Les résumés par période ne sont pas encore dans l'API (voir lacunes_api_jeux_medias.md) : aucun résumé n'est affiché.
    const NewsDigest? out = null;
    _digests[id] = _Timed(out);
    return out;
  }

  /// Oublie les lectures en mémoire (tirer pour actualiser).
  void clearCache() {
    _live.clear();
    _digests.clear();
    _feed = null;
    _articles.clear();
  }

  Future<Set<String>> _seen() async {
    try {
      return ((await SharedPreferences.getInstance()).getStringList(_kSeen) ?? const []).toSet();
    } catch (_) {
      return <String>{};
    }
  }

  Future<void> markSeen(String id) async {
    try {
      final sp = await SharedPreferences.getInstance();
      final list = [...(sp.getStringList(_kSeen) ?? const <String>[]).where((e) => e != id), id];
      await sp.setStringList(_kSeen, list.length > _maxSeen ? list.sublist(list.length - _maxSeen) : list);
    } catch (_) {}
  }

  /// Article à montrer à un emplacement du fil : le plus proche non vu (pays avant continent avant monde), sans doublon dans la session.
  /// [category] limite à un domaine (la page Sport demande « sport »). Retourne toujours le même article pour un même emplacement.
  Future<NewsFeedItem?> pickForSlot({required String slotKey, required String? country, String? category}) async {
    final items = await feedFor(country);
    final fixed = _slotItem[slotKey];
    if (fixed != null) {
      final same = items.where((i) => i.id == fixed);
      if (same.isNotEmpty) return same.first;
    }
    final seen = await _seen();
    NewsFeedItem? pick;
    for (final i in items) {
      if (category != null && i.category != category) continue;
      if (seen.contains(i.id) || _shown.contains(i.id)) continue;
      pick = i;
      break;
    }
    if (pick == null) return null;
    _shown.add(pick.id);
    _slotItem[slotKey] = pick.id;
    markSeen(pick.id);
    return pick;
  }

  Future<bool> hiddenToday() async {
    try {
      return (await SharedPreferences.getInstance()).getString(_kHiddenDay) == _today();
    } catch (_) {
      return false;
    }
  }

  Future<void> hideUntilTomorrow() async {
    try {
      await (await SharedPreferences.getInstance()).setString(_kHiddenDay, _today());
    } catch (_) {}
  }

  String _today() {
    final n = DateTime.now();
    return '${n.year}-${n.month}-${n.day}';
  }

  /// Fiche de l'API -> élément d'affichage du fil.
  NewsFeedItem _itemOf(Map c) => NewsFeedItem(
        id: '${c['id'] ?? ''}',
        agentKey: '${c['agent_key'] ?? ''}',
        category: '${c['category'] ?? ''}',
        level: '${c['level'] ?? 'world'}',
        country: c['country']?.toString(),
        continent: c['continent']?.toString(),
        title: '${c['title'] ?? ''}',
        chapo: '${c['chapo'] ?? ''}',
        image: '${c['image'] ?? ''}',
        sourceCount: JeuxApi.asInt(c['source_count'], 1),
        sourceNames: ((c['source_names'] as List?) ?? const []).map((e) => '$e').toList(),
        at: JeuxApi.ms(c['at']),
        score: JeuxApi.asInt(c['score']),
        exp: JeuxApi.ms(c['expires_at']),
      );

  /// Fil de l'API : un tableau d'articles par périmètre (pays, continent, monde).
  Future<Map<String, List<NewsFeedItem>>> _fetchFeed({String? country, String? scope}) async {
    final r = JeuxApi.map(await JeuxApi.client.get('/news/feed', query: {if (scope != null) 'scope': scope, if (scope == null && country != null && country.length == 2) 'country': country}));
    final feed = r['feed'] is Map ? r['feed'] as Map : const {};
    return {for (final e in feed.entries) '${e.key}': ((e.value as List?) ?? const []).whereType<Map>().map(_itemOf).toList()};
  }

  /// Lit un article (5 minutes de cache) ; [fresh] force une nouvelle lecture (page de détail, après un commentaire).
  Future<NewsArticle?> article(String id, {bool fresh = false}) async {
    final cached = _articles[id];
    if (!fresh && cached != null && DateTime.now().difference(cached.at).inMinutes < 5) return cached.article;
    try {
      final r = await Future.wait<dynamic>([
        JeuxApi.client.get('/news/articles/$id'),
        JeuxApi.client.get('/posts/$id').catchError((Object _) => null), // compteurs (j'aime, commentaires, vues)
      ]);
      final d = JeuxApi.map(r[0]);
      if (d.isEmpty) return null;
      final counts = (r[1] != null && JeuxApi.map(r[1])['counts'] is Map) ? Map<String, dynamic>.from(JeuxApi.map(r[1])['counts'] as Map) : const <String, dynamic>{};
      final item = _itemOf(d);
      final a = NewsArticle(
        id: item.id,
        agentKey: item.agentKey,
        category: item.category,
        level: item.level,
        country: item.country,
        continent: item.continent,
        title: item.title,
        chapo: item.chapo,
        sections: ((d['sections'] as List?) ?? const []).whereType<Map>().map((e) => NewsSection('${e['titre'] ?? ''}', '${e['texte'] ?? ''}')).toList(),
        retenir: ((d['retenir'] as List?) ?? const []).map((e) => '$e').toList(),
        sources: ((d['sources'] as List?) ?? const []).whereType<Map>().map((e) => NewsSource('${e['name'] ?? ''}', '${e['url'] ?? ''}')).toList(),
        image: item.image,
        createdAtMs: item.at,
        loves: JeuxApi.asInt(counts['likes']),
        comments: JeuxApi.asInt(counts['comments']),
        views: JeuxApi.asInt(counts['views']),
        gifts: 0,
        expiresAt: item.exp,
        lovedBy: const [],
        viewedBy: const [],
        raw: {'news': {'score': item.score}},
      );
      if (a.isExpired) return null;
      _articles[id] = _CachedArticle(a);
      return a;
    } catch (e) {
      if (kDebugMode) debugPrint('NewsService.article($id) : $e');
      return null;
    }
  }

  /// Compte une vue par personne et par article (le serveur dédoublonne) : la première fois que la carte est visible dans le fil, qu'on aime
  /// l'article depuis le fil ou qu'on ouvre sa page de détail. Retourne true si une vue vient d'être comptée.
  Future<bool> recordView(NewsArticle a) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || a.viewedBy.contains(uid) || !_viewed.add(a.id)) return false; // _viewed : déjà compté pendant cette session
    try {
      await JeuxApi.client.post('/posts/${a.id}/view');
      return true;
    } catch (_) {
      _viewed.remove(a.id); // l'appel a échoué : on réessaiera à la prochaine occasion
      return false;
    }
  }

  /// J'aime (gratuit sur les articles). Retourne false en cas d'échec.
  Future<bool> like(String postId) async {
    try {
      await JeuxApi.client.put('/posts/$postId/reaction');
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Suppression d'un article par un administrateur (route réservée à l'équipe côté serveur).
  Future<bool> adminDelete(String postId) async {
    try {
      await JeuxApi.client.delete('/admin/news/articles/$postId');
      _articles.remove(postId);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Signalement d'un article (une fois par personne). Retourne « ok », « already-exists » ou un code d'erreur.
  Future<String> report(String postId) async {
    try {
      await JeuxApi.client.post('/posts/$postId/report', body: {'type': 'standard'});
      return 'ok';
    } on ApiException catch (e) {
      return e.code == 'already_reported' ? 'already-exists' : e.code;
    } catch (_) {
      return 'error';
    }
  }
}

class _CachedArticle {
  final NewsArticle article;
  final DateTime at = DateTime.now();
  _CachedArticle(this.article);
}

class _Timed<T> {
  final T value;
  final DateTime at = DateTime.now();
  _Timed(this.value);
}
