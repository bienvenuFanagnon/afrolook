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
}
