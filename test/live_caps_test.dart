import 'package:afrotok/pages/LiveAgora/live_caps.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('vente en direct : vitrine oui, étals non, et seulement les jeux qui ne prennent pas de place', () {
    final c = LiveCaps.of('shopping');
    expect(c.showcase, isTrue);
    expect(c.marketPanel, isFalse);
    expect(c.games, {'goal', 'draw', 'questions', 'clips'});
    for (final g in ['poll', 'story', 'quiz', 'duel', 'challenge']) {
      expect(c.allows(g), isFalse, reason: '$g prendrait la place de la vitrine');
    }
    expect(c.allows('end'), isTrue);   // on peut toujours arrêter
  });

  test('marché : vitrine et étals oui, mêmes jeux légers seulement', () {
    final c = LiveCaps.of('market');
    expect(c.showcase, isTrue);
    expect(c.marketPanel, isTrue);
    expect(c.games, LiveCaps.of('shopping').games);
  });

  test('duel, défi, conte, quiz : leur jeu et les aides légères, pas de vitrine ni d\'étals ni un autre jeu à grande carte', () {
    for (final t in ['duel', 'challenge', 'story', 'quiz']) {
      final c = LiveCaps.of(t);
      expect(c.showcase, isFalse);
      expect(c.marketPanel, isFalse);
      expect(c.allows(t), isTrue);
      expect(c.allows('poll'), isFalse, reason: 'un sondage arrêterait le $t en cours');
      expect(c.allows('draw'), isTrue);
    }
  });

  test('discussion : tous les jeux ; sans caméra ou en salon audio, plus de duel ni de défi ; jamais de vitrine', () {
    final talk = LiveCaps.of('talk');
    expect(talk.showcase, isFalse);
    expect(talk.games, containsAll(['goal', 'poll', 'story', 'quiz', 'duel', 'challenge', 'draw', 'questions', 'clips']));
    expect(LiveCaps.of('talk', noCamera: true).allows('duel'), isFalse);
    expect(LiveCaps.of('talk', audioOnly: true).allows('challenge'), isFalse);
    expect(LiveCaps.of('talk', audioOnly: true).allows('quiz'), isTrue);
    expect(LiveCaps.of(null).type, 'talk');
    expect(LiveCaps.of('shopping', audioOnly: true).showcase, isFalse);
  });

  test('bande vidéo de la scène : pas en salon audio, pas sans caméra', () {
    expect(LiveCaps.of('talk').videoStage, isTrue);
    expect(LiveCaps.of('talk', audioOnly: true).videoStage, isFalse);
    expect(LiveCaps.of('talk', noCamera: true).videoStage, isFalse);
  });
}
