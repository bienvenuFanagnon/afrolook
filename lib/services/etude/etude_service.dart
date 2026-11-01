import 'package:afrotok/services/api/api_identity.dart';
import 'package:afrotok/services/api/jeux_api.dart';
import 'package:afrotok/services/api/learning_admin_api.dart';
import 'package:afrolook_api_client/afrolook_api_client.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Erreur renvoyée par le serveur d'Étude ; [code] est un mot-clé stable (LOCKED, CHAPTERS_TODO, NEED_PREVIOUS…).
class EtudeException implements Exception {
  EtudeException(this.code);
  final String code;
  @override
  String toString() => 'EtudeException($code)';
}

int _i(dynamic v, [int def = 0]) => v is num ? v.toInt() : def;
List<dynamic> _l(dynamic v) => v is List ? v : const [];
Map<String, dynamic> _m(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

class EtudeChapter {
  const EtudeChapter(this.id, this.title, this.levels, this.free);
  final String id, title;
  final int levels;
  final bool free;
}

class EtudeSubject {
  const EtudeSubject(this.id, this.title, this.icon, this.chapters);
  final String id, title, icon;
  final List<EtudeChapter> chapters;
}

class EtudeClass {
  const EtudeClass(this.id, this.title, this.subjects);
  final String id, title;
  final List<EtudeSubject> subjects;
  List<EtudeChapter> get chapters => [for (final s in subjects) ...s.chapters];
}

class EtudeTrack {
  const EtudeTrack({required this.id, required this.kind, required this.title, required this.order, required this.after, required this.classes, this.exam, this.cert, this.featured = 0, this.badge = '', this.pitch = ''});
  final String id, kind, title;
  final int order;
  final List<String> after;
  final List<EtudeClass> classes;
  final Map<String, dynamic>? exam; // id, title, diploma, count, passPct, seconds
  final Map<String, dynamic>? cert; // id, title, from, count, passPct
  final int featured; // rang « à la une » (1 = en premier ; 0 = non mis en avant)
  final String badge, pitch; // pastille et accroche de la une

  bool get isCycle => kind == 'cycle';

  factory EtudeTrack.fromMap(Map<String, dynamic> d) => EtudeTrack(
        id: '${d['id']}',
        kind: '${d['kind']}',
        title: '${d['title']}',
        order: _i(d['order']),
        after: _l(d['after']).map((e) => '$e').toList(),
        classes: _l(d['classes']).map((c) {
          final cm = _m(c);
          return EtudeClass(
            '${cm['id']}',
            '${cm['title']}',
            _l(cm['subjects']).map((s) {
              final sm = _m(s);
              return EtudeSubject(
                '${sm['id']}',
                '${sm['title']}',
                '${sm['icon'] ?? ''}',
                _l(sm['chapters']).map((h) {
                  final hm = _m(h);
                  return EtudeChapter('${hm['id']}', '${hm['title']}', _i(hm['levels'], 3), hm['free'] == true);
                }).toList(),
              );
            }).toList(),
          );
        }).toList(),
        exam: d['exam'] is Map ? _m(d['exam']) : null,
        cert: d['cert'] is Map ? _m(d['cert']) : null,
        featured: _i(d['featured']),
        badge: '${d['badge'] ?? ''}',
        pitch: '${d['pitch'] ?? ''}',
      );
}

/// Situation d'une classe dans un parcours commencé : validated, open, locked, soon ou skipped.
class EtudeClassStatus {
  const EtudeClassStatus(this.status, this.done, this.total, this.pct);
  final String status;
  final int done, total;
  final int? pct;
}

class EtudeTrackStatus {
  const EtudeTrackStatus(this.entry, this.classes, this.examReady, this.diploma);
  final String entry;
  final Map<String, EtudeClassStatus> classes;
  final bool examReady;
  final Map<String, dynamic>? diploma;
}

class EtudeState {
  const EtudeState({
    this.xp = 0,
    this.level = 1,
    this.streak = 0,
    this.levels = const {},
    this.classes = const {},
    this.unlocked = const {},
    this.adsPaid = const {},
    this.diplomas = const [],
    this.tracks = const {},
    this.certs = const {},
    this.freeEpreuve = const {},
    this.pendingAds = 0,
    this.dailyFreeLeft = 0,
    this.adValueCoins = 3,
    this.interstitialValueCoins = 2,
    this.config = const {},
  });

  final int xp, level, streak, pendingAds, adValueCoins, interstitialValueCoins, dailyFreeLeft;
  final Map<String, dynamic> config;
  final Map<String, int> levels, adsPaid;
  final Map<String, bool> unlocked;
  final Map<String, dynamic> classes, certs, freeEpreuve;
  final List<Map<String, dynamic>> diplomas;
  final Map<String, EtudeTrackStatus> tracks;

  int get xpInLevel => xp - ((level - 1) * (level - 1) * 50);
  int get xpForLevel => (level * level - (level - 1) * (level - 1)) * 50;

  /// Prix en pièces d'un contenu à débloquer (ch:…, cls:…, compo:…, exam:…, cert:…).
  int priceOf(String item) {
    final prices = _m(config['prices']);
    if (prices[item] is num) return _i(prices[item]);
    switch (item.split(':').first) {
      case 'cls':
        return _i(config['classPassPrice'], 54);
      case 'compo':
        return _i(config['compoPrice'], 15);
      case 'exam':
        return _i(config['examPrice'], 24);
      case 'cert':
        return _i(config['certPrice'], 18);
      default:
        return _i(config['chapterPrice'], 9);
    }
  }

  /// Nombre de pubs avec récompense qui valent [coins] pièces.
  int rewardedFor(int coins) => ((coins + adValueCoins - 1) ~/ adValueCoins).clamp(1, 1000);

  /// Nombre de pubs plein écran qui valent [coins] pièces.
  int interstitialFor(int coins) => ((coins + interstitialValueCoins - 1) ~/ interstitialValueCoins).clamp(1, 1000);

  factory EtudeState.fromMap(Map<String, dynamic> m) {
    final tracks = <String, EtudeTrackStatus>{};
    _m(m['tracks']).forEach((id, v) {
      final t = _m(v);
      final cls = <String, EtudeClassStatus>{};
      _m(t['classes']).forEach((cid, cv) {
        final c = _m(cv);
        cls[cid] = EtudeClassStatus('${c['status']}', _i(c['done']), _i(c['total']), c['pct'] is num ? _i(c['pct']) : null);
      });
      tracks[id] = EtudeTrackStatus('${t['entry']}', cls, t['examReady'] == true, t['diploma'] is Map ? _m(t['diploma']) : null);
    });
    return EtudeState(
      xp: _i(m['xp']),
      level: _i(m['level'], 1),
      streak: _i(m['streak']),
      levels: _m(m['levels']).map((k, v) => MapEntry(k, _i(v))),
      classes: _m(m['classes']),
      unlocked: _m(m['unlocked']).map((k, v) => MapEntry(k, v == true)),
      adsPaid: _m(m['adsPaid']).map((k, v) => MapEntry(k, _i(v))),
      diplomas: _l(m['diplomas']).map(_m).toList()..sort((a, b) => _i(b['at']).compareTo(_i(a['at']))),
      tracks: tracks,
      certs: _m(m['certs']),
      freeEpreuve: _m(m['freeEpreuve']),
      pendingAds: _i(m['pendingAds']),
      dailyFreeLeft: _i(m['dailyFreeLeft']),
      adValueCoins: _i(_m(m['config'])['adValueCoins'], 3).clamp(1, 1000),
      interstitialValueCoins: _i(_m(m['config'])['interstitialValueCoins'], 2).clamp(1, 1000),
      config: _m(m['config']),
    );
  }
}

class EtudeQuestion {
  const EtudeQuestion(this.q, this.o);
  final String q;
  final List<String> o;
}

class EtudeStart {
  const EtudeStart({required this.sid, required this.kind, required this.id, required this.title, required this.total, required this.passPct, required this.seconds, required this.practice, required this.questions});
  final String sid, kind, id, title;
  final int total, seconds;
  final double passPct;
  final bool practice;
  final List<EtudeQuestion> questions;
}

class EtudeAnswerResult {
  const EtudeAnswerResult(this.correct, this.correctIndex, this.explanation);
  final bool correct;
  final int correctIndex;
  final String explanation;
}

class EtudeFinish {
  const EtudeFinish({required this.pass, required this.correct, required this.total, required this.pct, required this.need, required this.xp, required this.chapterFinished, required this.classValidated, required this.diploma, required this.kind});
  final bool pass, chapterFinished;
  final int correct, total, pct, need, xp;
  final String classValidated, kind;
  final Map<String, dynamic>? diploma;
}

class EtudeLesson {
  const EtudeLesson(this.id, this.title, this.blocks, this.levels, this.done);
  final String id, title;
  final List<Map<String, String>> blocks;
  final int levels, done;
}

class EtudeService {
  EtudeService._();
  static final EtudeService instance = EtudeService._();

  final ValueNotifier<EtudeState?> state = ValueNotifier(null);
  List<EtudeTrack> _catalog = const [];
  DateTime? _catalogAt;

  String? get uid => ApiIdentity.myId;

  static const _alias = {'etude_off': 'QUIZ_OFF', 'need_previous': 'NEED_PREVIOUS', 'chapters_todo': 'CHAPTERS_TODO', 'no_ads': 'NO_ADS'};

  EtudeException _fail(ApiException e) => EtudeException('${e.code.toUpperCase()} ${_alias[e.code.toLowerCase()] ?? ''} ${e.message}'.trim());

  /// Appel de l'API ; les clés de premier niveau passent en camelCase (les identifiants à l'intérieur des tables restent intacts).
  Future<Map<String, dynamic>> _api(String method, String path, {Map<String, dynamic>? body, bool pay = false}) async {
    try {
      final c = JeuxApi.client;
      final dynamic r = switch (method) {
        'GET' => await c.get(path),
        _ => pay ? await c.pay(path, body: body) : await c.post(path, body: body),
      };
      return JeuxApi.map(r);
    } on ApiException catch (e) {
      throw _fail(e);
    }
  }

  /// Adapte l'état de l'API au format attendu par [EtudeState] (série, prix).
  Map<String, dynamic> _stateJson(Map<String, dynamic> m) {
    final streak = m['streak'];
    final prices = _m(m['prices']);
    return {
      'xp': m['xp'],
      'level': m['level'],
      'streak': streak is Map ? streak['count'] : streak,
      'levels': m['levels'],
      'classes': m['classes'],
      'unlocked': m['unlocked'],
      'adsPaid': m['ads_paid'],
      'diplomas': m['diplomas'],
      'tracks': m['tracks'],
      'certs': m['certs'],
      'freeEpreuve': m['free_epreuve'],
      'dailyFreeLeft': m['daily_free_left'],
      'config': {
        if (prices['chapter'] != null) 'chapterPrice': prices['chapter'],
        if (prices['class_pass'] != null) 'classPassPrice': prices['class_pass'],
        if (prices['compo'] != null) 'compoPrice': prices['compo'],
        if (prices['exam'] != null) 'examPrice': prices['exam'],
        if (prices['cert'] != null) 'certPrice': prices['cert'],
      },
    };
  }

  Future<List<EtudeTrack>> catalog({bool force = false}) async {
    final at = _catalogAt;
    if (!force && at != null && _catalog.isNotEmpty && DateTime.now().difference(at).inMinutes < 10) return _catalog;
    await refresh(); // le catalogue arrive avec l'état du joueur
    return _catalog;
  }

  EtudeState _publish(Map<String, dynamic> m) {
    final s = EtudeState.fromMap(m);
    state.value = s;
    return s;
  }

  Future<EtudeState> refresh() async {
    final m = await _api('GET', '/etude/state');
    _catalog = _l(m['catalog']).map((d) => EtudeTrack.fromMap(_m(d))).toList()..sort((a, b) => a.order.compareTo(b.order));
    _catalogAt = DateTime.now();
    return _publish(_stateJson(m));
  }

  /// Commence un parcours à la classe [entry]. [declared] : le diplôme d'avant est déclaré déjà obtenu.
  Future<EtudeState> startTrack(String track, {String? entry, bool declared = false}) async =>
      _publish(_stateJson(await _api('POST', '/etude/tracks/start', body: {'track': track, if (entry != null) 'entry': entry, 'declared': declared})));

  Future<EtudeLesson> openChapter(String chapterId) async {
    final m = await _api('GET', '/etude/chapters/$chapterId');
    return EtudeLesson(
      '${m['id']}',
      '${m['title']}',
      _l(m['lesson']).map((b) => {'t': '${_m(b)['t']}', 'x': '${_m(b)['x']}'}).toList(),
      _i(m['levels'], 3),
      _i(m['done']),
    );
  }

  /// kind : level (id = « chapitre:niveau »), compo (id = classe), exam (id = parcours), cert (id = attestation).
  Future<EtudeStart> start(String kind, String id) async {
    final m = await _api('POST', '/etude/sessions', body: {'kind': kind, 'id': id});
    return EtudeStart(
      sid: '${m['sid']}',
      kind: '${m['kind']}',
      id: '${m['id']}',
      title: '${m['title']}',
      total: _i(m['total']),
      passPct: (m['pass_pct'] as num?)?.toDouble() ?? 0.5,
      seconds: _i(m['seconds']),
      practice: m['practice'] == true,
      questions: _l(m['questions']).map((q) {
        final qm = _m(q);
        return EtudeQuestion('${qm['q']}', _l(qm['o']).map((o) => '$o').toList());
      }).toList(),
    );
  }

  Future<EtudeAnswerResult> answer(String sid, int i, int choice) async {
    final m = await _api('POST', '/etude/sessions/answer', body: {'sid': sid, 'i': i, 'choice': choice});
    return EtudeAnswerResult(m['correct'] == true, _i(m['correct_index']), '${m['explanation'] ?? ''}');
  }

  Future<EtudeFinish> finish(String sid) async {
    final m = await _api('POST', '/etude/sessions/finish', body: {'sid': sid});
    await refresh().catchError((Object _) => state.value ?? const EtudeState());
    return EtudeFinish(
      pass: m['pass'] == true,
      correct: _i(m['correct']),
      total: _i(m['total']),
      pct: _i(m['pct']),
      need: _i(m['need']),
      xp: _i(m['xp']),
      chapterFinished: m['chapter_finished'] == true,
      classValidated: '${m['class_validated'] ?? ''}',
      diploma: m['diploma'] is Map ? _m(m['diploma']) : null,
      kind: '${m['kind']}',
    );
  }

  /// Débloque un contenu avec des pièces ou des pubs en réserve. Retourne true quand il est débloqué.
  /// [format] pour les pubs : rewarded (avec récompense) ou interstitial (plein écran).
  Future<bool> unlock(String item, {required String via, String format = 'rewarded'}) async {
    final m = await _api('POST', '/etude/unlock', body: {'item': item, 'via': via == 'coins' ? 'coins' : (via == 'daily' ? 'daily' : 'ads')}, pay: via == 'coins');
    if (m['state'] is Map) _publish(_stateJson(_m(m['state'])));
    return m['unlocked'] == true;
  }

  /// Vue d'ensemble pour l'équipe : `GET /admin/etude/overview`. Les erreurs sont des [ApiException] (message en français).
  Future<Map<String, dynamic>> admin() => LearningAdminApi.etudeOverview();

  Future<Map<String, dynamic>> verifyDiploma(String serial) async {
    try {
      final r = await JeuxApi.client.get('/etude/diplomas/verify', query: {'serial': serial});
      return JeuxApi.map(r);
    } on ApiException catch (e) {
      throw _fail(e);
    }
  }
}
