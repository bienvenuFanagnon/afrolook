import 'package:afrotok/pages/LiveAgora/live_game_ui.dart';
import 'package:afrotok/pages/LiveAgora/live_stage_ui.dart';
import 'package:afrotok/services/api/live_stage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const ama = StageUser(id: 'u1', username: 'ama');
  const kofi = StageUser(id: 'u2', username: 'kofi');

  Widget strip({required LiveStageState stage, required bool isHost, Set<String> speaking = const {}, void Function(StageSpeaker)? onMute}) => MaterialApp(
        home: Scaffold(
          body: LiveStageStrip(stage: stage, isHost: isHost, myUserId: 'me', videoTile: (_) => null, onRemove: (_) {}, onFreeSlot: () {}, speaking: speaking, onMute: onMute),
        ),
      );

  testWidgets('scène : une personne qui parle montre l\'animation de voix, les autres non', (tester) async {
    final stage = LiveStageState(maxVideo: 4, maxAudio: 5, usedVideo: 2, speakers: [
      const StageSpeaker(user: ama, media: 'video'),
      const StageSpeaker(user: kofi, media: 'video'),
    ]);
    await tester.pumpWidget(strip(stage: stage, isHost: false, speaking: {'u1'}));
    expect(find.byKey(const ValueKey('speaking_bars')), findsOneWidget);
    await tester.pumpWidget(strip(stage: stage, isHost: false));
    expect(find.byKey(const ValueKey('speaking_bars')), findsNothing);
  });

  testWidgets('scène : l\'hôte voit un bouton micro sur chaque invité (vidéo et audio) et peut le couper ; un invité coupé est en rouge', (tester) async {
    final muted = <String>[];
    final stage = LiveStageState(maxVideo: 4, maxAudio: 5, usedVideo: 1, usedAudio: 1, speakers: [
      const StageSpeaker(user: ama, media: 'video'),
      const StageSpeaker(user: kofi, media: 'audio', hostMuted: true),
    ]);
    await tester.pumpWidget(strip(stage: stage, isHost: true, onMute: (s) => muted.add(s.user.id)));
    expect(find.byIcon(Icons.mic_rounded), findsOneWidget);       // ama : micro ouvert, bouton pour le couper
    expect(find.byIcon(Icons.mic_off_rounded), findsOneWidget);   // kofi : coupé (rouge), bouton pour le rétablir
    await tester.tap(find.byIcon(Icons.mic_rounded));
    await tester.tap(find.byIcon(Icons.mic_off_rounded));
    expect(muted, ['u1', 'u2']);
  });

  testWidgets('scène : un invité ou un spectateur voit qu\'un micro est coupé mais n\'a aucun bouton pour le couper', (tester) async {
    final stage = LiveStageState(maxVideo: 4, usedVideo: 2, speakers: [
      const StageSpeaker(user: ama, media: 'video'),
      const StageSpeaker(user: kofi, media: 'video', hostMuted: true),
    ]);
    await tester.pumpWidget(strip(stage: stage, isHost: false));
    expect(find.byIcon(Icons.mic_rounded), findsNothing);
    expect(find.byIcon(Icons.mic_off_rounded), findsOneWidget);
  });

  test('scène : host_muted est lu depuis l\'API', () {
    final st = LiveStageState.fromJson({
      'speakers': [
        {'user': {'id': 'u1', 'username': 'ama'}, 'media': 'video', 'agora_uid': 7, 'host_muted': true},
        {'user': {'id': 'u2', 'username': 'kofi'}, 'media': 'audio'},
      ],
    });
    expect(st.speakers[0].hostMuted, isTrue);
    expect(st.speakers[1].hostMuted, isFalse);
  });

  Map<String, dynamic> challenge() => {
        'id': 'g1', 'kind': 'challenge', 'status': 'active', 'config': {'players': ['u1', 'u2'], 'goal': 1000}, 'started_at': '2026-11-14T12:00:00Z',
        'players': [
          {'id': 'u1', 'username': 'ama'},
          {'id': 'u2', 'username': 'kofi'},
        ],
        'scores': {'u1': 300, 'u2': 100},
        'top_givers': {
          'u1': [
            {'username': 'zoe', 'coins': 200},
            {'username': 'yao', 'coins': 100},
          ],
          'u2': [
            {'username': 'max', 'coins': 100},
          ],
        },
      };

  testWidgets('défi à plusieurs : les meilleurs donateurs de chaque présentateur s\'affichent sous sa barre', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: LiveGameCard(game: LiveGame(challenge()), isHost: false, target: null, onTarget: (_) {}, onVote: (_) {}))));
    expect(find.textContaining('🥇 @zoe 200'), findsOneWidget);
    expect(find.textContaining('🥈 @yao 100'), findsOneWidget);
    expect(find.textContaining('🥇 @max 100'), findsOneWidget);
  });

  testWidgets('duel : les meilleurs donateurs s\'affichent en deux colonnes sous les totaux', (tester) async {
    final duel = challenge()..['kind'] = 'duel';
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: LiveGameCard(game: LiveGame(duel), isHost: false, target: null, onTarget: (_) {}, onVote: (_) {}))));
    expect(find.text('🥇 @zoe 200'), findsOneWidget);
    expect(find.text('🥇 @max 100'), findsOneWidget);
  });

  testWidgets('historique des jeux : un tirage au sort montre le gagnant, le lot et le nombre de personnes', (tester) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    final draw = {
      'id': 'd1', 'kind': 'draw', 'status': 'ended', 'started_at': '2026-11-14T12:30:00Z', 'config': {'coins': 100},
      'result': {'winner_id': 'u2', 'coins': 90, 'staked': 100, 'candidates': 7}, 'winner': {'id': 'u2', 'username': 'kofi'},
    };
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: LiveGamesHistorySheet(future: Future.value([draw])))));
    await tester.pumpAndSettle();
    expect(find.textContaining('Tirage au sort'), findsWidgets);
    expect(find.textContaining('🎉 @kofi gagne 90'), findsOneWidget);
    expect(find.textContaining('parmi 7'), findsOneWidget);
  });
}
