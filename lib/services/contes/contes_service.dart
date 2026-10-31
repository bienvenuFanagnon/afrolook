import 'package:afrotok/services/api/jeux_api.dart';
import 'package:afrolook_api_client/afrolook_api_client.dart';
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../l10n/tr.dart';
import 'contes_cache.dart';

/// Erreur renvoyée par le serveur des Contes (le texte contient un code : NO_ADS, FREE_USED, insuffisant, limite…).
class ConteException implements Exception {
  ConteException(this.code);
  final String code;
  @override
  String toString() => 'ConteException($code)';
}

/// Décor, lumière et silhouettes d'un conte : le peintre de gravures en tire l'illustration.
class SceneSpec {
  const SceneSpec({this.decor = 'savane', this.light = 'crepuscule', this.figures = const ['lievre'], this.seed = 1});
  final String decor, light;
  final List<String> figures;
  final int seed;

  factory SceneSpec.fromMap(Map? m) {
    if (m == null) return const SceneSpec();
    return SceneSpec(
      decor: (m['d'] ?? 'savane').toString(),
      light: (m['l'] ?? 'crepuscule').toString(),
      figures: ((m['f'] as List?) ?? const ['lievre']).map((e) => e.toString()).toList(),
      seed: (m['s'] as num?)?.toInt() ?? 1,
    );
  }
}

class ConteCollection {
  const ConteCollection({required this.id, required this.title, required this.category, required this.desc, required this.order, required this.count, required this.price, required this.scene});
  final String id, title, category, desc;
  final int order, count;
  final int? price;
  final SceneSpec scene;
}

/// Fiche légère d'un conte (liste, étagère, carte du fil). Le texte n'en fait pas partie.
class ConteCard {
  const ConteCard({
    required this.id,
    required this.title,
    required this.hook,
    required this.collectionId,
    required this.tag,
    required this.origin,
    required this.region,
    required this.minutes,
    required this.pages,
    required this.freePages,
    required this.kind,
    required this.order,
    required this.featured,
    required this.scene,
    this.priceOverride,
    this.rev = '',
    this.lang = 'fr',
  });
  final String id, title, hook, collectionId, tag, origin, region, kind;
  /// Empreinte du texte français (change quand il est corrigé) et langue dans laquelle la fiche et le texte sont servis.
  final String rev, lang;
  final int minutes, pages, freePages, order;
  final bool featured;
  final SceneSpec scene;
  final int? priceOverride;

  /// Langue dans laquelle ce conte est servi : la langue de l'application si une traduction complète existe, sinon le français.
  static String servedLang(Map m) {
    final want = trCurrentLanguage;
    final trs = m['tr'];
    return want != 'fr' && trs is Map && trs[want] is Map ? want : 'fr';
  }

  factory ConteCard.fromMap(Map m) {
    final lang = servedLang(m);
    final t = lang == 'fr' ? null : (m['tr'] as Map)[lang] as Map;
    return ConteCard._build(m, lang, t);
  }

  factory ConteCard._build(Map m, String lang, Map? t) => ConteCard(
        id: (m['id'] ?? '').toString(),
        title: ((t?['t']) ?? m['t'] ?? '').toString(),
        hook: ((t?['h']) ?? m['h'] ?? '').toString(),
        rev: (m['rv'] ?? '').toString(),
        lang: lang,
        collectionId: (m['c'] ?? '').toString(),
        tag: (m['tag'] ?? '').toString(),
        origin: ((t?['o']) ?? m['org'] ?? '').toString(),
        region: (m['rg'] ?? '').toString(),
        minutes: (m['m'] as num?)?.toInt() ?? 3,
        pages: (m['p'] as num?)?.toInt() ?? 5,
        freePages: (m['f'] as num?)?.toInt() ?? 2,
        kind: (m['k'] ?? 'court').toString(),
        order: (m['o'] as num?)?.toInt() ?? 0,
        featured: m['feat'] == true,
        scene: SceneSpec.fromMap(m['sc'] as Map?),
        priceOverride: (m['pr'] as num?)?.toInt(),
      );
}

class ContesCatalog {
  const ContesCatalog({this.collections = const [], this.cards = const []});
  final List<ConteCollection> collections;
  final List<ConteCard> cards;

  ConteCard? byId(String id) {
    for (final c in cards) {
      if (c.id == id) return c;
    }
    return null;
  }

  ConteCollection? collection(String id) {
    for (final c in collections) {
      if (c.id == id) return c;
    }
    return null;
  }

  List<ConteCard> inCollection(String id) => cards.where((c) => c.collectionId == id).toList()..sort((a, b) => a.order.compareTo(b.order));
}

class ContesCfg {
  const ContesCfg({
    this.enabled = true,
    this.adValueCoins = 10,
    this.interstitialValueCoins = 7,
    this.priceCourt = 10,
    this.priceLong = 20,
    this.priceChapitre = 20,
    this.priceRecueil = 70,
    this.pricePass = 80,
    this.passHours = 24,
    this.interstitialEveryStories = 2,
    this.interstitialMaxPerDay = 6,
    this.feedEnabled = true,
    this.feedFirstAfter = 7,
    this.feedSecondAfter = 22,
  });
  final bool enabled, feedEnabled;
  final int adValueCoins, interstitialValueCoins, priceCourt, priceLong, priceChapitre, priceRecueil, pricePass, passHours;
  final int interstitialEveryStories, interstitialMaxPerDay, feedFirstAfter, feedSecondAfter;

  factory ContesCfg.fromMap(Map? m) {
    if (m == null) return const ContesCfg();
    int n(String k, int d) => (m[k] as num?)?.toInt() ?? d;
    return ContesCfg(
      enabled: m['enabled'] != false,
      feedEnabled: m['feedEnabled'] != false,
      adValueCoins: n('adValueCoins', 10),
      interstitialValueCoins: n('interstitialValueCoins', 7),
      priceCourt: n('priceCourt', 10),
      priceLong: n('priceLong', 20),
      priceChapitre: n('priceChapitre', 20),
      priceRecueil: n('priceRecueil', 70),
      pricePass: n('pricePass', 80),
      passHours: n('passHours', 24),
      interstitialEveryStories: n('interstitialEveryStories', 2),
      interstitialMaxPerDay: n('interstitialMaxPerDay', 6),
      feedFirstAfter: n('feedFirstAfter', 7),
      feedSecondAfter: n('feedSecondAfter', 22),
    );
  }

  int priceOf(ConteCard c) {
    if (c.priceOverride != null) return c.priceOverride!;
    switch (c.kind) {
      case 'gratuit':
        return 0;
      case 'long':
        return priceLong;
      case 'chapitre':
        return priceChapitre;
      default:
        return priceCourt;
    }
  }

  int rewardedFor(int coins) => coins <= 0 ? 0 : (coins / (adValueCoins <= 0 ? 1 : adValueCoins)).ceil();
  int interstitialFor(int coins) => coins <= 0 ? 0 : (coins / (interstitialValueCoins <= 0 ? 1 : interstitialValueCoins)).ceil();
}

class ContesState {
  const ContesState({
    this.reads = const {},
    this.done = const {},
    this.unlockedStories = const {},
    this.unlockedCollections = const {},
    this.adsPaid = const {},
    this.passUntil = 0,
    this.freeLeft = 0,
    this.dailyId = '',
    this.cfg = const ContesCfg(),
  });
  final Map<String, int> reads, done;
  final Set<String> unlockedStories, unlockedCollections;
  final Map<String, int> adsPaid;
  final int passUntil, freeLeft;
  final String dailyId;
  final ContesCfg cfg;

  bool get passActive => passUntil > DateTime.now().millisecondsSinceEpoch;
  bool isRead(String id) => reads.containsKey(id);
  bool isDone(String id) => done.containsKey(id);

  /// Le lecteur peut lire ce conte en entier (gratuit, conte du jour, acheté, recueil acheté, ou Pass actif).
  bool canReadFully(ConteCard c) =>
      cfg.priceOf(c) <= 0 || c.id == dailyId || unlockedStories.contains(c.id) || unlockedCollections.contains(c.collectionId) || passActive;

  factory ContesState.fromMap(Map m) {
    Map<String, int> ints(dynamic v) => v is Map ? v.map((k, x) => MapEntry(k.toString(), (x as num).toInt())) : <String, int>{};
    Set<String> strs(dynamic v) => v is List ? v.map((e) => e.toString()).toSet() : <String>{};
    return ContesState(
      reads: ints(m['reads']),
      done: ints(m['done']),
      unlockedStories: strs(m['unlockedStories']),
      unlockedCollections: strs(m['unlockedCollections']),
      adsPaid: ints(m['adsPaid']),
      passUntil: (m['passUntil'] as num?)?.toInt() ?? 0,
      freeLeft: (m['freeLeft'] as num?)?.toInt() ?? 0,
      dailyId: (m['dailyId'] ?? '').toString(),
      cfg: ContesCfg.fromMap(m['cfg'] as Map?),
    );
  }
}

class ConteOpen {
  const ConteOpen({required this.id, required this.access, required this.locked, required this.price, required this.total, required this.free, required this.pages, required this.adsPaid, this.morale = '', this.lang = 'fr', this.rev = '', this.cacheUntil = -1});
  final String id, access, morale, lang, rev;
  final bool locked;
  final int price, total, free, adsPaid;
  /// Validité de la copie sur le téléphone : -1 = ne pas garder, 0 = sans limite, sinon date de fin.
  final int cacheUntil;
  final List<String> pages;

  factory ConteOpen.fromMap(Map m) => ConteOpen(
        id: (m['id'] ?? '').toString(),
        access: (m['access'] ?? 'locked').toString(),
        locked: m['locked'] == true,
        price: (m['price'] as num?)?.toInt() ?? 0,
        total: (m['total'] as num?)?.toInt() ?? 0,
        free: (m['free'] as num?)?.toInt() ?? 1,
        pages: ((m['pages'] as List?) ?? const []).map((e) => e.toString()).toList(),
        adsPaid: (m['adsPaid'] as num?)?.toInt() ?? 0,
        morale: (m['morale'] ?? '').toString(),
        lang: (m['lang'] ?? 'fr').toString(),
        rev: (m['rev'] ?? '').toString(),
        cacheUntil: (m['cacheUntil'] as num?)?.toInt() ?? -1,
      );
}

/// « La Case aux Contes » : catalogue (lu dans Firestore, mis en cache), état du lecteur et appels au serveur.
class ContesService {
  ContesService._();
  static final ContesService instance = ContesService._();

  final ValueNotifier<ContesState?> state = ValueNotifier<ContesState?>(null);
  ContesCatalog _catalog = const ContesCatalog();
  DateTime? _catalogAt;
  String _catalogLang = 'fr';
  Future<ContesCatalog>? _catalogFuture;
  final Map<String, ConteOpen> _fullCache = {};

  String? get uid => FirebaseAuth.instance.currentUser?.uid;
  ContesCatalog get cachedCatalog => _catalog;

  static const _alias = {'contes_off': 'CONTES_OFF', 'free_used': 'FREE_USED', 'no_ads': 'NO_ADS'};

  ConteException _fail(ApiException e) => ConteException('${e.code.toUpperCase()} ${_alias[e.code.toLowerCase()] ?? ''} ${e.message}'.trim());

  /// Appel de l'API ; renvoie le champ `data`. Pas de retour à Firebase : l'erreur est remontée à l'écran.
  Future<Map<String, dynamic>> _api(String method, String path, {Map<String, dynamic>? body, Map<String, dynamic>? query, bool pay = false}) async {
    try {
      final c = JeuxApi.client;
      final dynamic r = switch (method) {
        'GET' => await c.get(path, query: query),
        _ => pay ? await c.pay(path, body: body) : await c.post(path, body: body),
      };
      return JeuxApi.map(r);
    } on ApiException catch (e) {
      throw _fail(e);
    }
  }

  /// Recueils et fiches : une seule requête (les textes ne sont pas dedans).
  Future<ContesCatalog> catalog({bool force = false}) {
    final at = _catalogAt;
    if (_catalogLang != trCurrentLanguage) force = true; // la langue a changé : titres et accroches à relire
    if (!force && at != null && _catalog.cards.isNotEmpty && DateTime.now().difference(at).inMinutes < 15) return Future.value(_catalog);
    return _catalogFuture ??= _loadCatalog().whenComplete(() => _catalogFuture = null);
  }

  Future<ContesCatalog> _loadCatalog() async {
    final m = await _api('GET', '/contes/catalog');
    final collections = ((m['collections'] as List?) ?? const []).map((e) {
      final c = e as Map;
      return ConteCollection(
        id: (c['id'] ?? '').toString(),
        title: (c['title'] ?? '').toString(),
        category: (c['category'] ?? '').toString(),
        desc: (c['desc'] ?? '').toString(),
        order: (c['order'] as num?)?.toInt() ?? 99,
        count: (c['count'] as num?)?.toInt() ?? 0,
        price: (c['price'] as num?)?.toInt(),
        scene: SceneSpec.fromMap(c['sc'] as Map?),
      );
    }).toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    final cards = <ConteCard>[];
    for (final raw in ((m['stories'] as List?) ?? const [])) {
      final c = Map<String, dynamic>.from(raw as Map);
      if (c['active'] == false) continue;
      if ((c['c'] ?? '').toString().isEmpty && c['collection_id'] != null) c['c'] = c['collection_id'];
      cards.add(ConteCard.fromMap(c));
    }
    cards.sort((a, b) => a.order.compareTo(b.order));
    _catalog = ContesCatalog(collections: collections, cards: cards);
    _catalogAt = DateTime.now();
    _catalogLang = trCurrentLanguage;
    return _catalog;
  }

  /// Adapte l'état de l'API au format de [ContesState].
  Map<String, dynamic> _stateJson(Map<String, dynamic> m) {
    final c = (m['config'] is Map) ? Map<String, dynamic>.from(m['config'] as Map) : <String, dynamic>{};
    return {
      'reads': m['reads'],
      'done': m['done'],
      'unlockedStories': m['unlocked_stories'],
      'unlockedCollections': m['unlocked_collections'],
      'adsPaid': m['ads_paid'],
      'passUntil': m['pass_until'],
      'freeLeft': m['free_left'],
      'dailyId': m['daily_id'],
      'cfg': {
        'enabled': c['enabled'],
        'feedEnabled': c['feed_enabled'],
        'priceCourt': c['price_court'],
        'priceLong': c['price_long'],
        'priceChapitre': c['price_chapitre'],
        'priceRecueil': c['price_recueil'],
        'pricePass': c['price_pass'],
        'passHours': c['pass_hours'],
        'feedFirstAfter': c['feed_first_after'],
        'feedSecondAfter': c['feed_second_after'],
      },
    };
  }

  DateTime? _stateAt;
  Future<ContesState>? _stateFuture;

  Future<ContesState> loadState() async {
    final m = await _api('GET', '/contes/state');
    final s = ContesState.fromMap(_stateJson(m));
    state.value = s;
    _stateAt = DateTime.now();
    return s;
  }

  /// État du lecteur sans rappeler le serveur à chaque carte du fil : rechargé s'il a plus de 10 minutes.
  Future<ContesState> ensureState() {
    final s = state.value;
    final at = _stateAt;
    if (s != null && at != null && DateTime.now().difference(at).inMinutes < 10) return Future.value(s);
    return _stateFuture ??= loadState().whenComplete(() => _stateFuture = null);
  }

  /// Ouvre un conte. Les contes lus en entier restent en mémoire pour la session (pas de nouvelle lecture).
  /// Ouvre un conte. Un conte déjà débloqué est relu depuis la mémoire, puis depuis le disque du téléphone : le serveur
  /// n'enregistre alors que la lecture (`conteTouch`), sans relire le texte.
  Future<ConteOpen> open(ConteCard card) async {
    final id = card.id;
    final u = uid;
    final cached = _fullCache[id];
    if (cached != null && !cached.locked && cached.lang == card.lang && (cached.cacheUntil <= 0 || cached.cacheUntil > DateTime.now().millisecondsSinceEpoch)) {
      unawaited(_api('POST', '/contes/$id/touch').catchError((_) => <String, dynamic>{}));
      _markRead(id);
      return cached;
    }
    if (u != null) {
      final disk = await ContesCache.read(u, id);
      if (disk != null && disk.validFor(rev: card.rev, lang: card.lang)) {
        final o = ConteOpen(
          id: id, access: disk.access, locked: false, price: disk.price, total: disk.total, free: disk.free,
          pages: disk.pages, adsPaid: 0, morale: disk.morale, lang: disk.lang, rev: disk.rev, cacheUntil: disk.until,
        );
        _fullCache[id] = o;
        unawaited(_api('POST', '/contes/$id/touch').catchError((_) => <String, dynamic>{}));
        _markRead(id);
        return o;
      }
      if (disk != null) unawaited(ContesCache.remove(u, id));
    }
    final m = await _api('GET', '/contes/$id', query: {'lang': trCurrentLanguage});
    final o = ConteOpen.fromMap({...m, 'cacheUntil': m['cache_until']});
    if (!o.locked) {
      _fullCache[id] = o;
      if (u != null && o.cacheUntil >= 0) {
        unawaited(ContesCache.write(u, ConteCached(
          id: id, rev: o.rev, lang: o.lang, until: o.cacheUntil, access: o.access, total: o.total, free: o.free, price: o.price, pages: o.pages, morale: o.morale,
        )));
      }
    }
    _markRead(id);
    return o;
  }

  void _markRead(String id) {
    final s = state.value;
    if (s == null) return;
    final reads = Map<String, int>.from(s.reads)..[id] = DateTime.now().millisecondsSinceEpoch;
    state.value = ContesState(
      reads: reads, done: s.done, unlockedStories: s.unlockedStories, unlockedCollections: s.unlockedCollections,
      adsPaid: s.adsPaid, passUntil: s.passUntil, freeLeft: s.freeLeft, dailyId: s.dailyId, cfg: s.cfg,
    );
  }

  /// Déblocage (item « st:<id> », « co:<recueil> » ou « pass »). Retourne true quand le contenu est débloqué.
  Future<bool> unlock(String item, {String via = 'coins', String format = 'rewarded'}) async {
    final m = await _api('POST', '/contes/unlock', body: {'item': item, 'via': via}, pay: via == 'coins');
    if (m['state'] is Map) state.value = ContesState.fromMap(_stateJson(Map<String, dynamic>.from(m['state'] as Map)));
    final unlocked = m['unlocked'] == true;
    if (unlocked && item.startsWith('st:')) _fullCache.remove(item.substring(3));
    if (unlocked) _fullCache.clear();
    return unlocked;
  }

  Future<void> finish(String id) async {
    try {
      await _api('POST', '/contes/$id/finish');
    } catch (_) {}
    final s = state.value;
    if (s != null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      state.value = ContesState(
        reads: Map<String, int>.from(s.reads)..[id] = now, done: Map<String, int>.from(s.done)..[id] = now,
        unlockedStories: s.unlockedStories, unlockedCollections: s.unlockedCollections, adsPaid: s.adsPaid,
        passUntil: s.passUntil, freeLeft: s.freeLeft, dailyId: s.dailyId, cfg: s.cfg,
      );
    }
  }

  /// Mesure légère (carte du fil, page d'abandon, son) : jamais bloquante.
  void track(String event, {String? id, int? page}) {
    unawaited(_api('POST', '/contes/track', body: {'event': event}).catchError((e) {
      debugPrint('[Contes] track $event : $e');
      return <String, dynamic>{};
    }));
  }

  /// Admin : pas encore dans l'API (voir lacunes_api_jeux_medias.md).
  Future<Map<String, dynamic>> admin() async => throw ConteException('UNAVAILABLE Les outils d administration des contes ne sont pas encore disponibles.');
  Future<void> adminStory(String id, Map<String, dynamic> patch) async =>
      throw ConteException('UNAVAILABLE Les outils d administration des contes ne sont pas encore disponibles.');
}
