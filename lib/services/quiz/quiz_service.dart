import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Erreur renvoyée par le serveur du quiz ; [code] est un mot-clé stable (NO_HEARTS, LEVEL_LOCKED, TOO_FAST…).
class QuizException implements Exception {
  QuizException(this.code);
  final String code;
  @override
  String toString() => 'QuizException($code)';
}

int _i(dynamic v, [int def = 0]) => v is num ? v.toInt() : def;
bool _b(dynamic v, [bool def = false]) => v is bool ? v : def;

/// Progression du joueur (calculée par le serveur).
class QuizState {
  const QuizState({
    this.level = 1,
    this.completed = 0,
    this.points = 0,
    this.lifetime = 0,
    this.weeklyPoints = 0,
    this.streak = 0,
    this.playedToday = false,
    this.shields = 0,
    this.hearts = 5,
    this.heartsMax = 5,
    this.nextHeartInSec = 0,
    this.inventory = const {},
    this.equipped = const {},
    this.dailyDone = false,
    this.dailyPoints = 0,
    this.dailyCap = 400,
    this.refillsLeft = 0,
    this.doublesLeft = 0,
    this.levels = 200,
    this.challengeLeft = 0,
    this.challengeBest = 0,
    this.enabled = true,
  });

  final int level, completed, points, lifetime, weeklyPoints, streak, shields, hearts, heartsMax, nextHeartInSec;
  final int dailyPoints, dailyCap, refillsLeft, doublesLeft, levels, challengeLeft, challengeBest;
  final bool playedToday, dailyDone, enabled;
  final Map<String, bool> inventory;
  final Map<String, String> equipped;

  bool get finishedAll => level > levels;

  factory QuizState.fromMap(Map<String, dynamic> m, {bool enabled = true}) {
    final daily = m['daily'];
    return QuizState(
      level: _i(m['level'], 1),
      completed: _i(m['completed']),
      points: _i(m['points']),
      lifetime: _i(m['lifetime']),
      weeklyPoints: _i(m['weeklyPoints']),
      streak: _i(m['streak']),
      playedToday: _b(m['playedToday']),
      shields: _i(m['shields']),
      hearts: _i(m['hearts'], 5),
      heartsMax: _i(m['heartsMax'], 5),
      nextHeartInSec: _i(m['nextHeartInSec']),
      inventory: (m['inventory'] is Map) ? Map<String, bool>.from((m['inventory'] as Map).map((k, v) => MapEntry('$k', v == true))) : const {},
      equipped: (m['equipped'] is Map) ? Map<String, String>.from((m['equipped'] as Map).map((k, v) => MapEntry('$k', '$v'))) : const {},
      dailyDone: daily is Map ? _b(daily['done']) : false,
      dailyPoints: _i(m['dailyPoints']),
      dailyCap: _i(m['dailyCap'], 400),
      refillsLeft: _i(m['refillsLeft']),
      doublesLeft: _i(m['doublesLeft']),
      levels: _i(m['levels'], 200),
      challengeLeft: _i(m['challengeLeft']),
      challengeBest: _i(m['challengeBest']),
      enabled: m.containsKey('enabled') ? _b(m['enabled'], true) : enabled,
    );
  }
}

class QuizQuestion {
  const QuizQuestion(this.q, this.o);
  final String q;
  final List<String> o;
  factory QuizQuestion.fromMap(Map<String, dynamic> m) =>
      QuizQuestion('${m['q']}', (m['o'] as List).map((e) => '$e').toList());
}

class QuizAnswerResult {
  const QuizAnswerResult(this.correct, this.correctIndex, this.explanation, this.hearts);
  final bool correct;
  final int correctIndex;
  final String explanation;
  final int hearts;
}

class QuizLevelStart {
  const QuizLevelStart(this.n, this.practice, this.theme, this.unit, this.questions, this.state);
  final int n, unit;
  final bool practice;
  final String theme;
  final List<QuizQuestion> questions;
  final QuizState state;
}

class QuizFinish {
  const QuizFinish({
    required this.pass,
    required this.correct,
    required this.total,
    required this.gain,
    required this.capped,
    required this.perfect,
    required this.practice,
    required this.canDouble,
    required this.state,
  });
  final bool pass, capped, perfect, practice, canDouble;
  final int correct, total, gain;
  final QuizState state;
}

/// Réglages du quiz lisibles par l'app (Firestore AppConfig/quiz).
class QuizConfig {
  const QuizConfig({
    this.enabled = true,
    this.adsEnabled = true,
    this.feedCardEnabled = true,
    this.interstitialEveryLevels = 3,
    this.interstitialMaxPerDay = 6,
    this.shop = const {},
  });
  final bool enabled, adsEnabled, feedCardEnabled;
  final int interstitialEveryLevels, interstitialMaxPerDay;
  final Map<String, Map<String, dynamic>> shop;

  factory QuizConfig.fromMap(Map<String, dynamic> d) => QuizConfig(
        enabled: d['enabled'] != false,
        adsEnabled: d['adsEnabled'] != false,
        feedCardEnabled: d['feedCardEnabled'] != false,
        interstitialEveryLevels: _i(d['interstitialEveryLevels'], 3).clamp(1, 20),
        interstitialMaxPerDay: _i(d['interstitialMaxPerDay'], 6).clamp(0, 50),
        shop: d['shop'] is Map
            ? (d['shop'] as Map).map((k, v) => MapEntry('$k', v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{}))
            : const {},
      );
}

class QuizDaily {
  const QuizDaily({required this.day, required this.questions, required this.results, required this.done});
  final int day;
  final List<QuizQuestion> questions;
  final List<QuizAnswerResult> results;
  final bool done;
  int get answered => results.length;
}

/// Question du Grand Défi telle que le serveur la donne (sans la réponse).
class QuizChalQuestion {
  const QuizChalQuestion({required this.step, required this.q, required this.o, required this.hide, required this.j50, required this.swap, required this.rescue, required this.prize});
  final int step, prize;
  final String q;
  final List<String> o;
  final List<int> hide;
  final bool j50, swap, rescue;
  factory QuizChalQuestion.fromMap(Map<String, dynamic> m) => QuizChalQuestion(
        step: _i(m['step']),
        q: '${m['q']}',
        o: (m['o'] as List).map((e) => '$e').toList(),
        hide: (m['hide'] is List) ? (m['hide'] as List).map((e) => _i(e)).toList() : const [],
        j50: _b(m['j50']),
        swap: _b(m['swap']),
        rescue: _b(m['rescue']),
        prize: _i(m['prize']),
      );
}

/// Réponse du serveur à une action du Grand Défi.
class QuizChalReply {
  const QuizChalReply({
    this.question,
    this.correct = false,
    this.late = false,
    this.correctIndex = -1,
    this.explanation = '',
    this.pending = false,
    this.canRescue = false,
    this.floor = 0,
    this.win = false,
    this.ended = false,
    this.expired = false,
    this.gain = 0,
    this.reached = 0,
    this.prize = 0,
    this.prizes = const [],
    this.seconds = 30,
    this.attemptsLeft = 0,
    this.extraLeft = 0,
    this.best = 0,
    this.wins = 0,
    this.capLeft = 0,
    this.active = false,
  });
  final QuizChalQuestion? question;
  final bool correct, late, pending, canRescue, win, ended, expired, active;
  final int correctIndex, floor, gain, reached, prize, seconds, attemptsLeft, extraLeft, best, wins, capLeft;
  final String explanation;
  final List<int> prizes;

  factory QuizChalReply.fromMap(Map<String, dynamic> m) {
    final at = m['attempts'] is Map ? Map<String, dynamic>.from(m['attempts'] as Map) : <String, dynamic>{};
    return QuizChalReply(
      question: m['question'] is Map ? QuizChalQuestion.fromMap(Map<String, dynamic>.from(m['question'] as Map)) : null,
      correct: _b(m['correct']),
      late: _b(m['late']),
      correctIndex: _i(m['correctIndex'], -1),
      explanation: '${m['explanation'] ?? ''}',
      pending: _b(m['pending']),
      canRescue: _b(m['canRescue']),
      floor: _i(m['floor']),
      win: _b(m['win']),
      ended: _b(m['ended']),
      expired: _b(m['expired']),
      gain: _i(m['gain']),
      reached: _i(m['reached']),
      prize: _i(m['prize']),
      prizes: (m['prizes'] is List) ? (m['prizes'] as List).map((e) => _i(e)).toList() : const [],
      seconds: _i(m['seconds'], 30),
      attemptsLeft: _i(at['left']),
      extraLeft: _i(at['extraLeft']),
      best: _i(m['best']),
      wins: _i(m['wins']),
      capLeft: _i(m['capLeft']),
      active: _b(m['active']),
    );
  }
}

class QuizWeeklyEntry {
  const QuizWeeklyEntry({
    required this.uid,
    required this.name,
    required this.photo,
    required this.country,
    required this.points,
    this.frame = '',
    this.title = '',
  });
  final String uid, name, photo, country, frame, title;
  final int points;
}

class QuizCountryRow {
  const QuizCountryRow(this.code, this.name, this.points);
  final String code, name;
  final int points;
}

class QuizAttempt {
  const QuizAttempt({required this.n, required this.theme, required this.passed, required this.correct, required this.gain, required this.at, required this.details});
  final int n, correct, gain, at;
  final String theme;
  final bool passed;
  final List<Map<String, dynamic>> details;
}

/// Accès au serveur du quiz : toutes les règles (corrections, points, cœurs, série) sont côté serveur.
class QuizService {
  QuizService._();
  static final QuizService instance = QuizService._();

  /// Dernière progression connue (partagée entre la page, le fil et la boutique).
  final ValueNotifier<QuizState?> state = ValueNotifier<QuizState?>(null);

  QuizConfig _config = const QuizConfig();
  DateTime? _configAt;
  QuizConfig get config => _config;

  String? get uid => FirebaseAuth.instance.currentUser?.uid;

  Future<Map<String, dynamic>> _call(String name, [Map<String, dynamic>? data]) async {
    try {
      final res = await FirebaseFunctions.instance.httpsCallable(name).call(data ?? {});
      return Map<String, dynamic>.from(res.data as Map);
    } on FirebaseFunctionsException catch (e) {
      throw QuizException((e.message ?? e.code).trim());
    }
  }

  Future<QuizConfig> loadConfig({bool force = false}) async {
    final at = _configAt;
    if (!force && at != null && DateTime.now().difference(at).inMinutes < 10) return _config;
    try {
      final snap = await FirebaseFirestore.instance.collection('AppConfig').doc('quiz').get();
      _config = QuizConfig.fromMap(snap.data() ?? {});
      _configAt = DateTime.now();
    } catch (e) {
      debugPrint('[Quiz] config : $e');
    }
    return _config;
  }

  QuizState _publish(Map<String, dynamic> m) {
    final s = QuizState.fromMap(m, enabled: _config.enabled);
    state.value = s;
    return s;
  }

  Future<QuizState> refresh() async {
    await loadConfig();
    final m = await _call('quizGetState');
    return _publish(m);
  }

  Future<QuizLevelStart> startLevel(int n) async {
    final m = await _call('quizStartLevel', {'n': n});
    final s = _publish(m);
    return QuizLevelStart(
      n,
      _b(m['practice']),
      '${m['theme']}',
      _i(m['unit'], 1),
      (m['questions'] as List).map((e) => QuizQuestion.fromMap(Map<String, dynamic>.from(e as Map))).toList(),
      s,
    );
  }

  Future<QuizAnswerResult> answer(int n, int i, int choice) async {
    final m = await _call('quizAnswer', {'n': n, 'i': i, 'choice': choice});
    final cur = state.value;
    if (cur != null) state.value = QuizState.fromMap({..._toMap(cur), 'hearts': m['hearts']}, enabled: cur.enabled);
    return QuizAnswerResult(_b(m['correct']), _i(m['correctIndex']), '${m['explanation']}', _i(m['hearts']));
  }

  Map<String, dynamic> _toMap(QuizState s) => {
        'level': s.level, 'completed': s.completed, 'points': s.points, 'lifetime': s.lifetime,
        'weeklyPoints': s.weeklyPoints, 'streak': s.streak, 'playedToday': s.playedToday, 'shields': s.shields,
        'hearts': s.hearts, 'heartsMax': s.heartsMax, 'nextHeartInSec': s.nextHeartInSec,
        'inventory': s.inventory, 'equipped': s.equipped, 'daily': {'done': s.dailyDone},
        'dailyPoints': s.dailyPoints, 'dailyCap': s.dailyCap, 'refillsLeft': s.refillsLeft,
        'doublesLeft': s.doublesLeft, 'levels': s.levels,
      };

  Future<QuizFinish> finishLevel(int n) async {
    final m = await _call('quizFinishLevel', {'n': n});
    final s = _publish(m);
    return QuizFinish(
      pass: _b(m['pass']),
      correct: _i(m['correct']),
      total: _i(m['total'], 5),
      gain: _i(m['gain']),
      capped: _b(m['capped']),
      perfect: _b(m['perfect']),
      practice: _b(m['practice']),
      canDouble: _b(m['canDouble']),
      state: s,
    );
  }

  Future<int> doublePoints(int n) async {
    final m = await _call('quizDoublePoints', {'n': n});
    _publish(m);
    return _i(m['extra']);
  }

  Future<QuizState> refillHeart() async => _publish(await _call('quizRefillHeart'));

  // ── Grand Défi ──
  Future<QuizChalReply> _chal(String action, [Map<String, dynamic>? extra]) async {
    final m = await _call('quizChallenge', {'action': action, ...?extra});
    final st = m['state'];
    if (st is Map) _publish(Map<String, dynamic>.from(st));
    return QuizChalReply.fromMap(m);
  }

  Future<QuizChalReply> challengeInfo() => _chal('info');
  Future<QuizChalReply> challengeStart({bool extra = false}) => _chal('start', {'extra': extra});
  Future<QuizChalReply> challengeResume() => _chal('resume');
  Future<QuizChalReply> challengeAnswer(int choice) => _chal('answer', {'choice': choice});
  Future<QuizChalReply> challengeFiftyFifty() => _chal('j50');
  Future<QuizChalReply> challengeSwap() => _chal('swap');
  Future<QuizChalReply> challengeRescue() => _chal('rescue');
  Future<QuizChalReply> challengeGiveUp() => _chal('giveup');
  Future<QuizChalReply> challengeCashOut() => _chal('cashout');

  Future<QuizDaily> dailyGet() async {
    final m = await _call('quizDailyGet');
    return QuizDaily(
      day: _i(m['day']),
      done: _b(m['done']),
      questions: (m['questions'] as List).map((e) => QuizQuestion.fromMap(Map<String, dynamic>.from(e as Map))).toList(),
      results: (m['results'] as List)
          .map((e) {
            final r = Map<String, dynamic>.from(e as Map);
            return QuizAnswerResult(_b(r['correct']), _i(r['correctIndex']), '${r['explanation']}', 0);
          })
          .toList(),
    );
  }

  /// Retourne le résultat de la réponse ; [gain] > 0 quand c'était la dernière question du jour.
  Future<({QuizAnswerResult result, bool finished, int gain, int correctCount})> dailyAnswer(int i, int choice) async {
    final m = await _call('quizDailyAnswer', {'i': i, 'choice': choice});
    final st = m['state'];
    if (st is Map) _publish(Map<String, dynamic>.from(st));
    return (
      result: QuizAnswerResult(_b(m['correct']), _i(m['correctIndex']), '${m['explanation']}', 0),
      finished: _b(m['finished']),
      gain: _i(m['gain']),
      correctCount: _i(m['correctCount']),
    );
  }

  Future<QuizState> buy(String itemId) async => _publish(await _call('quizShopBuy', {'itemId': itemId}));

  Future<QuizState> equip(String slot, String? itemId) async =>
      _publish(await _call('quizEquip', {'slot': slot, 'itemId': itemId}));

  /// Rang de la semaine ; 0 si aucun point.
  Future<({int rank, int points, String weekId})> myRank() async {
    final m = await _call('quizMyRank');
    return (rank: _i(m['rank']), points: _i(m['points']), weekId: '${m['weekId']}');
  }

  // ── Lectures directes (règles Firestore : classement public, historique du joueur) ──────────

  static String currentWeekId() {
    final now = DateTime.now().toUtc();
    final date = DateTime.utc(now.year, now.month, now.day);
    final dayNum = date.weekday; // 1..7
    final thursday = date.add(Duration(days: 4 - dayNum));
    final yearStart = DateTime.utc(thursday.year, 1, 1);
    final week = ((thursday.difference(yearStart).inDays) / 7).floor() + 1;
    return '${thursday.year}-W${week.toString().padLeft(2, '0')}';
  }

  Future<List<QuizWeeklyEntry>> weeklyTop({int limit = 50}) async {
    final snap = await FirebaseFirestore.instance
        .collection('QuizWeekly')
        .where('weekId', isEqualTo: currentWeekId())
        .orderBy('points', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map((d) {
      final x = d.data();
      return QuizWeeklyEntry(
        uid: '${x['uid']}',
        name: '${x['name'] ?? ''}',
        photo: '${x['photo'] ?? ''}',
        country: '${x['country'] ?? ''}',
        points: _i(x['points']),
        frame: '${x['frame'] ?? ''}',
        title: '${x['title'] ?? ''}',
      );
    }).toList();
  }

  Future<List<QuizCountryRow>> countryBoard() async {
    final snap = await FirebaseFirestore.instance.collection('QuizCountryBoard').doc(currentWeekId()).get();
    final list = (snap.data()?['countries'] as List?) ?? const [];
    return list.map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return QuizCountryRow('${m['code']}', '${m['name']}', _i(m['points']));
    }).toList();
  }

  Future<List<QuizAttempt>> history({int limit = 100}) async {
    final u = uid;
    if (u == null) return const [];
    final snap = await FirebaseFirestore.instance
        .collection('QuizAttempts')
        .where('uid', isEqualTo: u)
        .orderBy('at', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map((d) {
      final x = d.data();
      return QuizAttempt(
        n: _i(x['n']),
        theme: '${x['theme'] ?? ''}',
        passed: x['passed'] == true,
        correct: _i(x['correct']),
        gain: _i(x['gain']),
        at: _i(x['at']),
        details: ((x['details'] as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList(),
      );
    }).toList();
  }
}
