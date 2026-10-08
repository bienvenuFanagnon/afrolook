import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

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
  });
  final String id, title, hook, collectionId, tag, origin, region, kind;
  final int minutes, pages, freePages, order;
  final bool featured;
  final SceneSpec scene;
  final int? priceOverride;

  factory ConteCard.fromMap(Map m) => ConteCard(
        id: (m['id'] ?? '').toString(),
        title: (m['t'] ?? '').toString(),
        hook: (m['h'] ?? '').toString(),
        collectionId: (m['c'] ?? '').toString(),
        tag: (m['tag'] ?? '').toString(),
        origin: (m['org'] ?? '').toString(),
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
  const ConteOpen({required this.id, required this.access, required this.locked, required this.price, required this.total, required this.free, required this.pages, required this.adsPaid, this.morale = ''});
  final String id, access, morale;
  final bool locked;
  final int price, total, free, adsPaid;
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
      );
}

/// « La Case aux Contes » : catalogue (lu dans Firestore, mis en cache), état du lecteur et appels au serveur.
class ContesService {
  ContesService._();
  static final ContesService instance = ContesService._();

  final ValueNotifier<ContesState?> state = ValueNotifier<ContesState?>(null);
  ContesCatalog _catalog = const ContesCatalog();
  DateTime? _catalogAt;
  Future<ContesCatalog>? _catalogFuture;
  final Map<String, ConteOpen> _fullCache = {};

  String? get uid => FirebaseAuth.instance.currentUser?.uid;
  ContesCatalog get cachedCatalog => _catalog;

  static const _refused = {'resource-exhausted', 'unavailable'};
  // refus voulus par le serveur (jamais rejoués) : solde, limites, pubs, quota de lectures offertes
  static final _business = RegExp(r'insuffisant|imite|rapide|FREE_USED|NO_ADS|CONTES_OFF', caseSensitive: false);

  Future<Map<String, dynamic>> _call(String name, [Map<String, dynamic>? data]) async {
    // Serveur momentanément saturé : la requête est refusée avant d'être exécutée, on la rejoue (1 s puis 2 s).
    for (var attempt = 0;; attempt++) {
      try {
        final res = await FirebaseFunctions.instance.httpsCallable(name).call(data ?? {});
        return Map<String, dynamic>.from(res.data as Map);
      } on FirebaseFunctionsException catch (e) {
        if (_refused.contains(e.code) && attempt < 2 && !_business.hasMatch(e.message ?? '')) {
          await Future<void>.delayed(Duration(seconds: attempt + 1));
          continue;
        }
        throw ConteException((e.message ?? e.code).trim());
      }
    }
  }

  /// Recueils et fiches : une lecture pour la liste des recueils, puis un document par bloc de 40 contes.
  Future<ContesCatalog> catalog({bool force = false}) {
    final at = _catalogAt;
    if (!force && at != null && _catalog.cards.isNotEmpty && DateTime.now().difference(at).inMinutes < 15) return Future.value(_catalog);
    return _catalogFuture ??= _loadCatalog().whenComplete(() => _catalogFuture = null);
  }

  Future<ContesCatalog> _loadCatalog() async {
    final fs = FirebaseFirestore.instance;
    final meta = await fs.collection('ContesIndex').doc('meta').get();
    final m = meta.data() ?? {};
    final chunks = (m['chunks'] as num?)?.toInt() ?? 0;
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
    final docs = await Future.wait([for (var i = 0; i < chunks; i++) fs.collection('ContesIndex').doc('c$i').get()]);
    final cards = <ConteCard>[];
    for (final d in docs) {
      for (final raw in ((d.data()?['cards'] as List?) ?? const [])) {
        final c = raw as Map;
        if (c['active'] == false) continue;
        cards.add(ConteCard.fromMap(c));
      }
    }
    cards.sort((a, b) => a.order.compareTo(b.order));
    _catalog = ContesCatalog(collections: collections, cards: cards);
    _catalogAt = DateTime.now();
    return _catalog;
  }

  DateTime? _stateAt;
  Future<ContesState>? _stateFuture;

  Future<ContesState> loadState() async {
    final m = await _call('conteGetState');
    final s = ContesState.fromMap(m);
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
  Future<ConteOpen> open(String id) async {
    final cached = _fullCache[id];
    if (cached != null && !cached.locked) {
      // l'historique du lecteur est mis à jour en arrière-plan
      unawaited(_call('conteOpen', {'id': id}).catchError((_) => <String, dynamic>{}));
      return cached;
    }
    final m = await _call('conteOpen', {'id': id});
    final o = ConteOpen.fromMap(m);
    if (!o.locked) _fullCache[id] = o;
    final s = state.value;
    if (s != null) {
      final reads = Map<String, int>.from(s.reads)..[id] = DateTime.now().millisecondsSinceEpoch;
      state.value = ContesState(
        reads: reads, done: s.done, unlockedStories: s.unlockedStories, unlockedCollections: s.unlockedCollections,
        adsPaid: s.adsPaid, passUntil: s.passUntil, freeLeft: s.freeLeft, dailyId: s.dailyId, cfg: s.cfg,
      );
    }
    return o;
  }

  /// Déblocage (item « st:<id> », « co:<recueil> » ou « pass »). Retourne true quand le contenu est débloqué.
  Future<bool> unlock(String item, {String via = 'coins', String format = 'rewarded'}) async {
    final m = await _call('conteUnlock', {'item': item, 'via': via, 'format': format});
    if (m['state'] is Map) state.value = ContesState.fromMap(m['state'] as Map);
    final unlocked = m['unlocked'] == true;
    if (unlocked && item.startsWith('st:')) _fullCache.remove(item.substring(3));
    if (unlocked) _fullCache.clear();
    return unlocked;
  }

  Future<void> finish(String id) async {
    try {
      await _call('conteFinish', {'id': id});
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
    unawaited(_call('conteTrack', {'event': event, if (id != null) 'id': id, if (page != null) 'page': page}).catchError((e) {
      debugPrint('[Contes] track $event : $e');
      return <String, dynamic>{};
    }));
  }

  /// Admin : tableau de bord et réglages d'un conte.
  Future<Map<String, dynamic>> admin() => _call('conteAdmin');
  Future<void> adminStory(String id, Map<String, dynamic> patch) async {
    await _call('conteAdminStory', {'id': id, 'patch': patch});
    _catalogAt = null;
  }
}
