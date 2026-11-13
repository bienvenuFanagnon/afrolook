import 'package:afrotok/pages/LiveAgora/live_game_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('duel : scores et gagnant lus depuis l\'API', () {
    final g = LiveGame({
      'id': 'g1',
      'kind': 'duel',
      'status': 'ended',
      'config': {'players': ['a', 'b']},
      'players': [
        {'id': 'a', 'username': 'moi.hote'},
        {'id': 'b', 'username': 'kofi_tv'}
      ],
      'scores': {'a': 1240, 'b': 760},
      'result': {'winner_id': 'a'},
    });
    expect(g.isMatch, isTrue);
    expect(g.active, isFalse);
    expect(g.score('a'), 1240);
    expect(g.score('zz'), 0);
    expect(g.winnerId, 'a');
    expect(g.players.map((p) => p.username), ['moi.hote', 'kofi_tv']);
  });

  test('défi : objectif en pièces ; sondage : choix, voix et mon vote', () {
    final d = LiveGame({'id': 'g2', 'kind': 'challenge', 'status': 'active', 'config': {'goal': 2000, 'players': ['a']}});
    expect(d.goal, 2000);
    final p = LiveGame({
      'id': 'g3',
      'kind': 'poll',
      'status': 'active',
      'config': {'question': 'Quelle chanson ?', 'options': ['Afrobeat', 'Rumba']},
      'votes': [3, 1],
      'my_vote': 1,
      'ends_at': DateTime.now().add(const Duration(seconds: 90)).toUtc().toIso8601String(),
    });
    expect(p.options, ['Afrobeat', 'Rumba']);
    expect(p.votes, [3, 1]);
    expect(p.myVote, 1);
    expect(p.secondsLeft, inInclusiveRange(85, 90));
    expect(clock(75), '01:15');
  });

  test('quiz : saisie de l\'hôte, une question par ligne, étoile = bonne réponse', () {
    final qs = QuizDraft.parse('Capitale du Ghana ? | Kumasi | Accra* | Lomé\n\n2 + 2 ? | 3 | 4*')!;
    expect(qs, hasLength(2));
    expect(qs[0].options, ['Kumasi', 'Accra', 'Lomé']);
    expect(qs[0].correct, 1);
    expect(qs[1].toJson(), {'text': '2 + 2 ?', 'options': ['3', '4'], 'correct': 1});
    expect(QuizDraft.parse('Sans bonne réponse ? | a | b'), isNull);
    expect(QuizDraft.parse('Deux bonnes ? | a* | b*'), isNull);
    expect(QuizDraft.parse('Un seul choix ? | a*'), isNull);
    expect(QuizDraft.parse(''), isNull);
  });

  test('conte : voix en pièces et choix gagnant', () {
    final g = LiveGame({'id': 'g4', 'kind': 'story', 'status': 'ended', 'config': {'question': 'Que fait-il ?', 'options': ['A', 'B']}, 'votes': [30, 10], 'my_coins': 20, 'vote_coins': 10, 'winner_option': 0});
    expect(g.votes, [30, 10]);
    expect(g.myCoins, 20);
    expect(g.voteCoins, 10);
    expect(g.winnerOption, 0);
  });
}
