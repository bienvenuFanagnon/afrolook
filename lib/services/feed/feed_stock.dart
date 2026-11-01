import 'dart:async';
import 'dart:convert';

/// Lecture / écriture du stock sur le téléphone (SharedPreferences en production, mémoire dans les tests).
abstract class FeedStockStore {
  Future<String?> read();
  Future<void> write(String json);
}

/// Récupère une page du fil « pour vous » (`GET /feed/for-you`). [cold] = le téléphone n'a rien en cache : le serveur oublie ce qu'il a déjà servi.
typedef FeedPageFetcher = Future<Map<String, dynamic>> Function({String? cursor, required int limit, required bool cold});

/// Stock de publications NON VUES gardé sur le téléphone (demande du propriétaire, 01/11/2026) :
///  - tout ce que le serveur envoie attend ici jusqu'à ce que la personne l'ait VU ; à la réouverture de l'application, ces posts s'affichent
///    tout de suite (aucune attente réseau) pendant que le serveur en prépare d'autres ;
///  - les NOUVEAUX posts des abonnements arrivés entre-temps passent TOUJOURS devant le reste (priorité aux abonnements, avant la découverte) ;
///  - une page d'avance est préparée en arrière-plan : le défilement ne attend jamais ;
///  - le stock est borné (60 / 80 éléments) et expire après 48 h (les posts supprimés ou périmés ne s'accumulent pas).
class FeedStock {
  FeedStock({required this.fetch, required this.store, DateTime Function()? now}) : _now = now ?? DateTime.now;

  final FeedPageFetcher fetch;
  final FeedStockStore store;
  final DateTime Function() _now;

  static const int maxDelivered = 60;
  static const int maxQueue = 80;
  static const Duration maxAge = Duration(hours: 48);
  static const Duration headWait = Duration(milliseconds: 700);
  static const Duration emptyCooldown = Duration(seconds: 45);

  /// Remis à l'écran mais pas encore VUS : gardés pour le prochain lancement.
  final List<Map<String, dynamic>> _delivered = [];

  /// En attente, pas encore remis à l'écran.
  final List<Map<String, dynamic>> _queue = [];

  /// Déjà vus (ne reviennent jamais) ; enregistrés aussi, au cas où une vue n'aurait pas atteint le serveur.
  final Set<String> _gone = {};
  static const int maxGone = 300;

  String? _cursor;
  bool _cursorMoved = false; // une page autre que la première a été lue : le curseur de la première page ne doit plus l'écraser
  bool _exhausted = false;
  bool _cold = false;
  DateTime? _emptyAt;
  Future<void>? _loading;
  Future<Map<String, dynamic>>? _head;
  Future<void>? _topUpRunning;
  Timer? _saveTimer;

  int get delivered => _delivered.length;
  int get queued => _queue.length;
  bool get exhausted => _exhausted;

  // ── Chargement du stock enregistré ──────────────────────────────────────────

  Future<void> load() => _loading ??= _load();

  Future<void> _load() async {
    try {
      final raw = await store.read();
      if (raw != null && raw.isNotEmpty) {
        final d = jsonDecode(raw) as Map<String, dynamic>;
        final savedAt = DateTime.fromMillisecondsSinceEpoch((d['t'] as num?)?.toInt() ?? 0);
        if (_now().difference(savedAt) <= maxAge) {
          for (final m in (d['delivered'] as List? ?? const [])) {
            if (m is Map) _delivered.add(Map<String, dynamic>.from(m));
          }
          for (final m in (d['queue'] as List? ?? const [])) {
            if (m is Map) _queue.add(Map<String, dynamic>.from(m));
          }
          _gone.addAll((d['gone'] as List? ?? const []).map((e) => e.toString()));
          // Un post vu dont la vue n'est pas arrivée au serveur ne doit pas revenir de sa part
          _delivered.removeWhere((m) => _gone.contains(_id(m)));
          _queue.removeWhere((m) => _gone.contains(_id(m)));
        }
      }
    } catch (_) {/* stock illisible : on repart de zéro, rien n'est perdu côté serveur */}
    _cold = _delivered.isEmpty && _queue.isEmpty;
  }

  // ── Préparation ─────────────────────────────────────────────────────────────

  /// À lancer dès le début du chargement de l'application : la première page fraîche se prépare PENDANT le lancement.
  void prefetch() {
    () async {
      await load();
      _head ??= _fetchHead();
      _head!.then((_) {}, onError: (_) {});
    }();
  }

  Future<Map<String, dynamic>> _fetchHead() {
    final cold = _cold;
    return fetch(cursor: null, limit: 20, cold: cold).then((p) {
      _cold = false;
      return p;
    });
  }

  // ── Service des pages ───────────────────────────────────────────────────────

  /// Prochaines [limit] publications. [reset] = ouverture de l'application ou « tirer pour rafraîchir ».
  /// Lève l'erreur réseau uniquement quand il n'y a RIEN à montrer (ni stock, ni réponse du serveur).
  Future<List<Map<String, dynamic>>> next({required int limit, bool reset = false}) async {
    await load();
    if (reset) {
      _cursor = null;
      _exhausted = false;
      _cursorMoved = false;
      _queue.insertAll(0, _delivered); // les posts remis mais pas vus repassent en tête de ce qui reste à voir
      _delivered.clear();
      final headFuture = _head ?? _fetchHead();
      _head = null;
      if (_queue.isNotEmpty) {
        // Du stock existe : affichage immédiat. Si la page fraîche arrive vite, ses posts d'abonnements passent devant ; sinon elle s'ajoute plus tard.
        try {
          _mergeHead(await headFuture.timeout(headWait));
        } catch (_) {
          headFuture.then(_mergeHead, onError: (_) {});
        }
      } else {
        _mergeHead(await headFuture); // rien en stock : on attend le serveur (l'erreur remonte à l'écran)
      }
    } else if (_exhausted && _queue.isEmpty && (_emptyAt == null || _now().difference(_emptyAt!) > emptyCooldown)) {
      _cursor = null; // une fin de fil n'est jamais définitive : on repart à zéro (le serveur ne ressert pas ce qu'il vient de servir)
      _exhausted = false;
      _cursorMoved = false;
    }

    while (_queue.length < limit && !_exhausted) {
      await _fetchMore();
    }
    final out = _takeDiverse(limit);
    for (final m in out) {
      _delivered.add(m);
    }
    _trim();
    _topUp();
    _scheduleSave();
    return out;
  }

  // ── Diversité : jamais plus de 2 posts de suite du même créateur ni du même canal (règle du propriétaire, 01/11/2026) ──

  static String? _author(Map<String, dynamic> m) {
    final a = m['author'];
    final id = a is Map ? a['id'] : m['author_id'];
    return id == null ? null : 'a:$id';
  }

  static String? _channel(Map<String, dynamic> m) {
    final c = m['channel_id'];
    return c == null || '$c'.isEmpty ? null : 'c:$c';
  }

  /// Longueur de la série finale de [seq] ayant la même clé [key].
  static int _run(List<Map<String, dynamic>> seq, String? Function(Map<String, dynamic>) keyOf, String key) {
    var n = 0;
    for (var i = seq.length - 1; i >= 0 && keyOf(seq[i]) == key; i--) {
      n++;
    }
    return n;
  }

  /// Prend [limit] posts dans la file en respectant la règle, en tenant compte des deux derniers posts déjà remis à l'écran.
  /// Première passe : pas deux fois de suite le même créateur ; seconde : au plus 2 de suite ; sinon l'ordre d'origine.
  List<Map<String, dynamic>> _takeDiverse(int limit) {
    final seq = <Map<String, dynamic>>[..._delivered.length > 2 ? _delivered.sublist(_delivered.length - 2) : _delivered];
    final out = <Map<String, dynamic>>[];
    while (out.length < limit && _queue.isNotEmpty) {
      var pick = -1;
      for (final maxAuthor in const [1, 2]) {
        for (var i = 0; i < _queue.length; i++) {
          final a = _author(_queue[i]);
          final c = _channel(_queue[i]);
          if ((a == null || _run(seq, _author, a) < maxAuthor) && (c == null || _run(seq, _channel, c) < 2)) {
            pick = i;
            break;
          }
        }
        if (pick >= 0) break;
      }
      final m = _queue.removeAt(pick >= 0 ? pick : 0);
      out.add(m);
      seq.add(m);
    }
    return out;
  }

  /// Fusionne la première page fraîche : les posts des ABONNEMENTS en tête, le reste à la suite. Aucun doublon.
  void _mergeHead(Map<String, dynamic> page) {
    final rows = _fresh((page['data'] as List? ?? const []).whereType<Map>().map((m) => Map<String, dynamic>.from(m)));
    final following = rows.where((m) => m['reason'] == 'following').toList();
    final others = rows.where((m) => m['reason'] != 'following').toList();
    _queue.insertAll(0, following);
    _queue.addAll(others);
    if (!_cursorMoved) {
      _cursor = page['next_cursor'] as String?;
      _exhausted = rows.isEmpty && _cursor == null;
      if (rows.isEmpty && _cursor == null) _emptyAt = _now();
    }
    _trim();
    _scheduleSave();
  }

  Future<void> _fetchMore() async {
    final page = await fetch(cursor: _cursor, limit: 20, cold: false);
    _cursorMoved = true;
    final rows = _fresh((page['data'] as List? ?? const []).whereType<Map>().map((m) => Map<String, dynamic>.from(m)));
    _queue.addAll(rows);
    _cursor = page['next_cursor'] as String?;
    final empty = (page['data'] as List? ?? const []).isEmpty;
    if (empty || _cursor == null) _exhausted = true;
    if (empty) _emptyAt = _now();
  }

  /// Écarte les posts déjà vus, déjà en stock ou déjà remis.
  List<Map<String, dynamic>> _fresh(Iterable<Map<String, dynamic>> rows) {
    final known = <String>{..._gone, ..._delivered.map(_id), ..._queue.map(_id)};
    final out = <Map<String, dynamic>>[];
    for (final m in rows) {
      final id = _id(m);
      if (id.isNotEmpty && known.add(id)) out.add(m);
    }
    return out;
  }

  static String _id(Map<String, dynamic> m) => (m['id'] ?? '').toString();

  /// Garde toujours de quoi tenir deux pages (30 au moins) sur le téléphone : la page suivante se prépare pendant que la personne regarde.
  void _topUp() {
    if (_exhausted || _topUpRunning != null || _queue.length >= 30) return;
    _topUpRunning = () async {
      try {
        await _fetchMore();
        _trim();
        _scheduleSave();
      } catch (_) {/* sans gravité : la page sera demandée au moment voulu */} finally {
        _topUpRunning = null;
      }
    }();
  }

  // ── Vues ────────────────────────────────────────────────────────────────────

  /// Un post vu quitte le stock pour toujours.
  void markViewed(String postId) {
    _gone.add(postId);
    _delivered.removeWhere((m) => _id(m) == postId);
    _queue.removeWhere((m) => _id(m) == postId);
    _scheduleSave();
  }

  // ── Enregistrement ──────────────────────────────────────────────────────────

  void _trim() {
    if (_delivered.length > maxDelivered) _delivered.removeRange(0, _delivered.length - maxDelivered);
    if (_queue.length > maxQueue) _queue.removeRange(maxQueue, _queue.length);
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 1), saveNow);
  }

  Future<void> saveNow() async {
    _saveTimer?.cancel();
    try {
      final gone = _gone.length > maxGone ? _gone.skip(_gone.length - maxGone).toList() : _gone.toList();
      await store.write(jsonEncode({'t': _now().millisecondsSinceEpoch, 'delivered': _delivered, 'queue': _queue, 'gone': gone}));
    } catch (_) {/* le stock est un confort : une écriture ratée n'est pas une erreur */}
  }

  /// Vide le stock (déconnexion, personnalisation réinitialisée).
  Future<void> clear() async {
    _delivered.clear();
    _queue.clear();
    _cursor = null;
    _exhausted = false;
    await saveNow();
  }
}
