import 'package:afrotok/services/api/live_display.dart';
import 'package:afrotok/services/api/live_stage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('scène : places, personnes sur scène et demandes lues depuis l\'API', () {
    final st = LiveStageState.fromJson({
      'enabled': true,
      'limits': {'video': 4, 'audio': 5},
      'used': {'video': 3, 'audio': 2},
      'place_coins': 250,
      'host_agora_uid': 99,
      'speakers': [
        {'user': {'id': 'u1', 'username': 'sika.b', 'avatar_url': null}, 'media': 'video', 'agora_uid': 11},
        {'user': {'id': 'u2', 'username': 'kofi_tv'}, 'media': 'audio', 'agora_uid': null},
      ],
      'requests': [
        {'id': 'r1', 'source': 'request', 'media': 'video', 'coins': 250, 'status': 'pending', 'user': {'id': 'u3', 'username': 'awa.k'}, 'expires_at': '2026-11-13T10:00:00Z'}
      ],
      'invited': ['u9'],
    });
    expect(st.placesLabel, '3 vidéo sur 4 · 2 audio sur 5');
    expect(st.videoFull, isFalse);
    expect(st.videoSpeakers.single.agoraUid, 11);
    expect(st.audioSpeakers.single.user.username, 'kofi_tv');
    expect(st.requests.single.coins, 250);
    expect(st.hostAgoraUid, 99);
    expect(st.invited, ['u9']);
    expect(st.mine, isNull);
    expect(st.onStage, isFalse);
  });

  test('scène : la demande et l\'invitation du spectateur', () {
    final st = LiveStageState.fromJson({
      'limits': {'video': 2, 'audio': 2},
      'used': {'video': 2, 'audio': 0},
      'mine': {'id': 'i1', 'source': 'invite', 'media': 'audio', 'coins': 0, 'status': 'pending', 'user': {'id': 'me', 'username': 'moi'}},
      'on_stage': false,
    });
    expect(st.videoFull, isTrue);
    expect(st.audioFull, isFalse);
    expect(st.mine!.isInvite, isTrue);
  });

  test('affichage : « Essentiel » par défaut, anciens lives sans réglage = tout affiché', () {
    expect(LiveDisplay.byName('inconnu'), LiveDisplay.essential);
    expect(LiveDisplay.fromJson(null), LiveDisplay.complete);
    expect(LiveDisplay.fromJson({'preset': 'clean'}).messages, isFalse);
    final d = LiveDisplay.essential.copyWith(reactions: true);
    expect(d.preset, 'custom');
    expect(d.reactions, isTrue);
    expect(LiveDisplay.fromJson(d.toJson()), d);
    expect(LiveDisplay.shop.coins, isFalse);
  });
}
