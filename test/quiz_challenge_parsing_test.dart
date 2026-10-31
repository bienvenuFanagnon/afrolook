import 'package:afrotok/services/api/learning_admin_api.dart';
import 'package:afrotok/services/contes/contes_service.dart';
import 'package:afrotok/services/quiz/quiz_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Formats de réponse de l'API (voir les tests `QuizChallengeTest`, `QuizAdminTest` et `LearningAdminTest` de l'API).
void main() {
  group('Grand Défi', () {
    test('une partie qui commence : question sans réponse, parties restantes en camelCase', () {
      final r = QuizService.parseChallenge({
        'ended': false,
        'gain': 0,
        'prizes': [10, 20, 30, 50, 100, 150, 200, 300, 400, 600, 800, 1000, 1500, 2000, 3000],
        'seconds': 30,
        'cap_left': 1500,
        'best': 4,
        'wins': 1,
        'attempts': {'free': 1, 'extra_max': 2, 'used': 1, 'left': 0, 'extra_left': 2},
        'state': {'level': 3, 'points': 120, 'challenge_left': 0, 'challenge_best': 4},
        'week_id': '2026-W44',
        'question': {'step': 0, 'q': 'Capitale du Togo ?', 'o': ['Accra', 'Lomé', 'Cotonou', 'Abuja'], 'hide': [], 'j50': false, 'swap': false, 'rescue': false, 'prize': 0, 'seconds_left': 30},
      });
      expect(r.question, isNotNull);
      expect(r.question!.o, hasLength(4));
      expect(r.question!.step, 0);
      expect(r.question!.secondsLeft, 30);
      expect(r.prizes, hasLength(15));
      expect(r.capLeft, 1500);
      expect(r.attemptsLeft, 0);
      expect(r.extraLeft, 2);
      expect(r.best, 4);
      expect(r.wins, 1);
      // la bonne réponse n'est jamais connue avant la réponse
      expect(r.correctIndex, -1);
      expect(r.explanation, '');
      expect(r.ended, isFalse);
    });

    test('une mauvaise réponse ouvre la seconde chance', () {
      final r = QuizService.parseChallenge({
        'ended': false, 'gain': 0, 'seconds': 30, 'attempts': {'left': 0, 'extra_left': 1},
        'correct': false, 'late': false, 'correct_index': 2, 'explanation': 'Parce que.', 'pending': true, 'can_rescue': true, 'floor': 100,
      });
      expect(r.correct, isFalse);
      expect(r.pending, isTrue);
      expect(r.canRescue, isTrue);
      expect(r.floor, 100);
      expect(r.correctIndex, 2);
      expect(r.explanation, 'Parce que.');
      expect(r.question, isNull);
    });

    test('fin de partie (victoire, encaissement rejoué, temps écoulé)', () {
      final win = QuizService.parseChallenge({'ended': true, 'gain': 1500, 'win': true, 'reached': 15, 'prize': 3000, 'cap_left': 0, 'best': 15, 'wins': 2, 'correct': true, 'correct_index': 1});
      expect(win.win, isTrue);
      expect(win.ended, isTrue);
      expect(win.reached, 15);
      expect(win.prize, 3000);
      expect(win.gain, 1500);
      expect(win.gain < win.prize, isTrue); // plafond du jour
      expect(win.question, isNull);

      final replay = QuizService.parseChallenge({'replayed': true, 'ended': true, 'gain': 50, 'reached': 4, 'prize': 50});
      expect(replay.replayed, isTrue);
      expect(replay.gain, 50);

      final expired = QuizService.parseChallenge({'ended': true, 'gain': 0, 'expired': true, 'reached': 4, 'prize': 0});
      expect(expired.expired, isTrue);
    });

    test('le 50/50 donne les choix cachés', () {
      final r = QuizService.parseChallenge({
        'question': {'step': 3, 'q': 'Q ?', 'o': ['a', 'b', 'c', 'd'], 'hide': [0, 2], 'j50': true, 'swap': false, 'rescue': false, 'prize': 50, 'seconds_left': 12},
      });
      expect(r.question!.hide, [0, 2]);
      expect(r.question!.j50, isTrue);
      expect(r.question!.secondsLeft, 12);
    });

    test('information sans partie en cours', () {
      final r = QuizService.parseChallenge({'ended': false, 'gain': 0, 'active': false, 'seconds': 25, 'attempts': {'free': 1, 'extra_max': 2, 'used': 0, 'left': 1, 'extra_left': 2}});
      expect(r.active, isFalse);
      expect(r.seconds, 25);
      expect(r.attemptsLeft, 1);
      expect(r.question, isNull);
    });
  });

  group('Historique des niveaux', () {
    test('GET /quiz/attempts', () {
      final list = QuizAttempt.listFrom([
        {
          'n': 2, 'theme': 'culture', 'unit': 1, 'passed': true, 'correct': 5, 'gain': 70, 'at': 1761900000000, 'doubled': false,
          'details': [
            {'q': 'Question ?', 'a': 'bonne réponse', 'c': 'faux A', 'ok': false},
            {'q': 'Autre ?', 'a': 'oui', 'c': 'oui', 'ok': true},
          ],
        },
        {'n': 1, 'theme': 'culture', 'unit': 1, 'passed': false, 'correct': 2, 'gain': 0, 'at': 1761800000000, 'doubled': false, 'details': []},
      ]);
      expect(list, hasLength(2));
      expect(list.first.n, 2);
      expect(list.first.passed, isTrue);
      expect(list.first.gain, 70);
      expect(list.first.details, hasLength(2));
      expect(list.first.details.first['ok'], false);
      expect(list.last.passed, isFalse);
      expect(QuizAttempt.listFrom(null), isEmpty);
    });
  });

  group('Administration', () {
    test('statistiques du quiz : clés en camelCase, réglages intacts', () {
      final s = LearningAdminApi.parseQuizStats({
        'today': '20261031',
        'days': [
          {'day': '20261030', 'players': 3, 'sec': 600, 'levels': 5, 'passed': 4, 'avg_sec': 200},
        ],
        'overview': {
          'by_region': {'af': 10, 'eu': 2, 'as': 0, 'am': 0, 'mx': 1},
          'total': 13, 'played_today': 4, 'daily_done': 2, 'chal_players': 1, 'chal_today': 1, 'pts_today': 120, 'lifetime': 9000, 'streak3': 3, 'chal_wins': 1,
          'level_buckets': [1, 2, 3, 4, 5, 6], 'chal_best': List.filled(16, 0),
        },
        'retention': {'yesterday': 5, 'back': 2},
        'top': [
          {'user_id': 'u1', 'sec': 300, 'name': null, 'photo': null, 'country': 'TG'},
        ],
        'config': {'challengeDailyCap': 1500, 'shop': {'frame_gold': {'price': 10}}},
      });
      expect(((s['days'] as List).first as Map)['avgSec'], 200);
      final ov = s['overview'] as Map;
      expect(ov['playedToday'], 4);
      expect(ov['chalWins'], 1);
      expect((ov['byRegion'] as Map)['af'], 10);
      expect((ov['levelBuckets'] as List), hasLength(6));
      expect(((s['top'] as List).first as Map)['userId'], 'u1');
      expect((s['config'] as Map)['challengeDailyCap'], 1500);
      expect(((s['config'] as Map)['shop'] as Map).containsKey('frame_gold'), isTrue);
    });

    test('signalements : qHash en camelCase, motifs intacts', () {
      final r = LearningAdminApi.parseQuizReports({
        'total': 1,
        'reports': [
          {'q_hash': '0123456789abcdef', 'q': 'Q ?', 'options': ['a', 'b'], 'shown': 'a', 'count': 2, 'reasons': {'wrong': 2}, 'comments': ['non'], 'last': 1761900000},
        ],
      });
      final first = (r['reports'] as List).first as Map;
      expect(first['qHash'], '0123456789abcdef');
      expect((first['reasons'] as Map)['wrong'], 2);
    });

    test('Étude : vue d\'ensemble', () {
      final d = LearningAdminApi.parseEtudeOverview({
        'learners': 45, 'active_today': 3, 'active7': 10, 'avg_xp': 120, 'success_rate': 70,
        'started': {'bac_d': 4}, 'classes': <String, dynamic>{}, 'diplomas': {}, 'unlocks': {'ch': 5, 'cls': 0, 'compo': 0, 'exam': 1, 'cert': 0},
        'top_chapters': [
          {'id': 'c1', 'title': 'Chapitre 1', 'n': 8},
        ],
        'coins7': 40,
        'tracks': [
          {'id': 'bac_d', 'title': 'Bac D', 'kind': 'bac', 'classes': 3, 'chapters': 40},
        ],
        'config': {'ad_value_coins': 3, 'chapter_price': 10},
        'truncated': false,
      });
      expect(d['activeToday'], 3);
      expect(d['successRate'], 70);
      expect((d['started'] as Map)['bac_d'], 4);
      expect((d['topChapters'] as List), hasLength(1));
      expect((d['config'] as Map)['adValueCoins'], 3);
      expect((d['tracks'] as List).first['chapters'], 40);
    });

    test('Contes : vue d\'ensemble, réglages absents (liste vide) ramenés à un dictionnaire', () {
      final d = LearningAdminApi.parseContesOverview({
        'readers': 210, 'active_today': 4, 'active7': 30, 'reads': 500, 'done': 200, 'pass_active': 2, 'ad_free_active': 0, 'completion_rate': 40,
        'week': {'opens': 20, 'cached_opens': 5, 'finishes': 8, 'unlock_coins': 2, 'unlock_ads': 3, 'unlock_free': 1, 'ads_rewarded': 3, 'ads_interstitial': 0, 'coins_spent': 20, 'feed_view': 9, 'feed_click': 3, 'feed_dismiss': 1, 'sound_off': 0, 'sound_on': 2},
        'coins7': 20,
        'per_day': [
          {'day': '20261031', 'opens': 3, 'finishes': 1},
        ],
        'top_opened': [
          {'id': 's1', 'title': 'Conte 1', 'opens': 9, 'finishes': 4, 'locked_opens': 1, 'drop_page': 3},
        ],
        'top_finished': [],
        'worst_drop': [
          {'id': 's2', 'title': 'Conte 2', 'opens': 9, 'finishes': 1, 'locked_opens': 0, 'drop_page': 5},
        ],
        'collections': [],
        'catalog': {'stories': 136, 'active': 130},
        'config': [],
      });
      expect(d['activeToday'], 4);
      expect(d['completionRate'], 40);
      expect((d['week'] as Map)['unlockAds'], 3);
      expect((d['week'] as Map)['feedView'], 9);
      expect(((d['perDay'] as List).first as Map)['opens'], 3);
      expect(((d['worstDrop'] as List).first as Map)['dropPage'], 5);
      expect(d['config'], isA<Map>());
      expect(ContesCfg.fromMap(d['config'] as Map).priceLong, 20);
    });

    test('abandon d\'un conte : id et page sont envoyés ; les autres mesures restent sans id', () {
      expect(ContesService.contesTrackBody('leave', id: 'conte_1', page: 3), {'event': 'leave', 'id': 'conte_1', 'page': 3});
      expect(ContesService.contesTrackBody('leave', id: 'conte_1', page: 99)['page'], 40);
      expect(ContesService.contesTrackBody('leave'), {'event': 'leave'});
      expect(ContesService.contesTrackBody('feed_view'), {'event': 'feed_view'});
    });
  });
}
