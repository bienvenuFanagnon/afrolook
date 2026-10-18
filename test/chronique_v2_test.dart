import 'package:afrotok/pages/chronique/chronique_filters.dart';
import 'package:afrotok/pages/chronique/chronique_music.dart';
import 'package:afrotok/pages/chronique/chronique_text_view.dart';
import 'package:afrotok/pages/chronique/chronique_widgets.dart';
import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/pages/chronique/chroniqueform.dart';
import 'package:afrotok/services/chat_request.dart';
import 'package:afrotok/theme/app_colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Chronique _c(String user, {ChroniqueType type = ChroniqueType.IMAGE, int minutesAgo = 5, int views = 0, int likes = 0, String? music, List<String> viewers = const [], String? text}) => Chronique(
      id: '${user}_$minutesAgo',
      userId: user,
      userPseudo: user,
      userImageUrl: '',
      type: type,
      textContent: text,
      mediaUrl: 'https://example.com/m',
      backgroundColor: 'ff1a1a2e',
      createdAt: Timestamp.fromDate(DateTime.now().subtract(Duration(minutes: minutesAgo))),
      expiresAt: Timestamp.fromDate(DateTime.now().add(const Duration(hours: 20))),
      viewCount: views,
      likeCount: likes,
      viewers: viewers,
      musicUrl: music,
      musicTitle: music == null ? null : 'Soleil',
    );

Widget _host(Widget child) => MaterialApp(theme: ThemeData.dark(), home: Scaffold(body: Center(child: child)));

void main() {
  group('filtres de la liste', () {
    final groups = [
      [_c('aicha', type: ChroniqueType.VIDEO, minutesAgo: 10, views: 50, likes: 10)],
      [_c('kofi', minutesAgo: 3, views: 5)],
      [_c('mariam', type: ChroniqueType.TEXT, minutesAgo: 30, music: 'https://example.com/a.m4a', views: 200, likes: 40)],
      [_c('yao', minutesAgo: 60)],
    ];

    test('Pour toi : tout, les plus récents d\'abord', () {
      final r = applyChroniqueFilter(groups, ChroniqueFilter.forYou);
      expect(r.map((g) => g.first.userId), ['kofi', 'aicha', 'mariam', 'yao']);
    });

    test('Populaires : par score, sans les chroniques que personne n\'a vues', () {
      final r = applyChroniqueFilter(groups, ChroniqueFilter.popular);
      expect(r.map((g) => g.first.userId), ['mariam', 'aicha', 'kofi']);
    });

    test('Vidéos, Musique, Abonnements et recherche par pseudo', () {
      expect(applyChroniqueFilter(groups, ChroniqueFilter.videos).single.first.userId, 'aicha');
      expect(applyChroniqueFilter(groups, ChroniqueFilter.music).single.first.userId, 'mariam');
      expect(applyChroniqueFilter(groups, ChroniqueFilter.following, followedIds: {'yao', 'kofi'}).map((g) => g.first.userId), ['kofi', 'yao']);
      expect(applyChroniqueFilter(groups, ChroniqueFilter.forYou, query: '@MAR').single.first.userId, 'mariam');
    });
  });

  group('texte long', () {
    test('taille et durée selon la longueur', () {
      expect(chroniqueTextSize(40), 28);
      expect(chroniqueTextSize(1000), lessThan(chroniqueTextSize(100)));
      expect(chroniqueTextDurationMs(0), 5000);
      expect(chroniqueTextDurationMs(100), 9000);
      expect(chroniqueTextDurationMs(5000), 45000);
    });

    testWidgets('un texte court n\'a ni défilement ni pastille', (t) async {
      await t.pumpWidget(_host(SizedBox(width: 340, height: 640, child: ChroniqueTextView(chronique: _c('mariam', type: ChroniqueType.TEXT, text: 'Bonne fête papa')))));
      await t.pumpAndSettle();
      expect(find.text('Faire défiler'), findsNothing);
    });

    testWidgets('un texte long défile : la pastille disparaît en bas et le geste est signalé', (t) async {
      var touches = 0;
      final long = List.generate(60, (i) => 'Ligne $i : un récit assez long pour dépasser l\'écran.').join(' ');
      await t.pumpWidget(_host(SizedBox(width: 340, height: 640, child: ChroniqueTextView(chronique: _c('mariam', type: ChroniqueType.TEXT, text: long), onTouch: () => touches++))));
      await t.pumpAndSettle();
      expect(find.text('Faire défiler'), findsOneWidget);
      await t.drag(find.byType(SingleChildScrollView), const Offset(0, -6000));
      await t.pumpAndSettle();
      expect(touches, greaterThan(0));
      final fade = t.widget<AnimatedOpacity>(find.ancestor(of: find.text('Faire défiler'), matching: find.byType(AnimatedOpacity)).first);
      expect(fade.opacity, 0);
    });
  });

  group('musique d\'une chronique', () {
    ChroniqueMusic music({int duration = 30000}) => ChroniqueMusic(kind: 'free', id: 'afrobeat', title: 'Afrobeat', artist: 'Musique Afrolook', url: 'https://example.com/a.m4a', startMs: 0, endMs: duration, durationMs: duration);

    test('l\'extrait reste entre 5 et 30 secondes et dans la durée du titre', () {
      final m = music(duration: 60000)..startMs = 10000..endMs = 12000;
      m.clamp();
      expect(m.clipMs, 5000);
      m.startMs = 0;
      m.endMs = 60000;
      m.clamp();
      expect(m.clipMs, 30000);
      final short = music(duration: 3000)..startMs = 0..endMs = 3000;
      short.clamp();
      expect(short.clipMs, 3000);
      final tail = music(duration: 40000)..startMs = 39000..endMs = 40000;
      tail.clamp();
      expect(tail.endMs, 40000);
      expect(tail.clipMs, 5000);
    });

    test('la musique et le dernier commentaire font l\'aller-retour dans Firestore', () {
      final c = _c('kofi', music: 'https://example.com/a.m4a')
        ..musicKind = 'artist'
        ..musicId = 's1'
        ..musicStartMs = 12000
        ..musicEndMs = 32000
        ..musicVolume = .5
        ..videoSoundKept = true
        ..lastCommentPseudo = 'fatou'
        ..lastCommentText = 'Magnifique';
      final back = Chronique.fromMap(c.toMap(), 'x');
      expect(back.hasMusic, isTrue);
      expect(back.musicEndMs, 32000);
      expect(back.musicVolume, .5);
      expect(back.videoSoundKept, isTrue);
      expect(back.lastCommentText, 'Magnifique');
      // sans musique, aucun champ musique n'est écrit
      final plain = _c('kofi').toMap();
      expect(plain.containsKey('musicUrl'), isFalse);
      expect(Chronique.fromMap(plain, 'y').hasMusic, isFalse);
    });
  });

  group('demande de discussion', () {
    test('l\'état de la demande fait l\'aller-retour, et un chat ordinaire n\'en écrit jamais', () {
      final plain = Chat(id: 'c1', docId: 'ab', senderId: 'a', receiverId: 'b').toJson();
      expect(plain.containsKey('request_status'), isFalse); // une mise à jour complète ne peut pas effacer une demande
      final chat = Chat.fromJson({'id': 'c1', 'docId': 'ab', 'sender_id': 'a', 'receiver_id': 'b', 'request_status': 'pending', 'request_from': 'a', 'request_invitation_id': 'i1'});
      expect(ChatRequestService.isPending(chat), isTrue);
      expect(ChatRequestService.iAmRequester(chat, 'a'), isTrue);
      expect(ChatRequestService.iAmRequester(chat, 'b'), isFalse);
      final out = chat.toJson();
      expect(out['request_status'], 'pending');
      expect(out['request_invitation_id'], 'i1');
      chat.requestStatus = 'refused';
      expect(ChatRequestService.isRefused(chat), isTrue);
      expect(ChatRequestService.isPending(chat), isFalse);
    });

    test('l\'invitation garde la chronique et le message, sans les réécrire', () {
      final inv = Invitation.fromJson({'id': 'i1', 'sender_id': 'a', 'receiver_id': 'b', 'status': 'ENCOURS', 'message': 'Bonjour', 'chronique_id': 'ch1', 'chronique_thumb': 'https://x/y.jpg'});
      expect(inv.chroniqueId, 'ch1');
      expect(inv.message, 'Bonjour');
      // acceptInvitation réécrit toJson() : les champs de la chronique n'y sont pas, ils ne sont donc jamais effacés
      expect(inv.toJson().containsKey('chronique_id'), isFalse);
    });
  });

  group('anneaux et cartes', () {
    test('compteurs lisibles', () {
      expect(chroniqueCount(999), '999');
      expect(chroniqueCount(1200), '1.2K');
      expect(chroniqueCount(15000), '15K');
      expect(chroniqueCount(2500000), '2.5M');
    });

    test('groupe vu seulement si toutes les chroniques sont vues', () {
      final g = [_c('a', minutesAgo: 1, viewers: ['me']), _c('a', minutesAgo: 2)];
      expect(chroniqueGroupSeen(g, 'me'), isFalse);
      expect(chroniqueGroupSeen([_c('a', viewers: ['me'])], 'me'), isTrue);
      expect(chroniqueGroupSeen([], 'me'), isFalse);
    });

    testWidgets('anneau, anneau « + » et carte se dessinent (clair et sombre)', (t) async {
      for (final dark in [false, true]) {
        await t.pumpWidget(MaterialApp(
          theme: ThemeData(brightness: dark ? Brightness.dark : Brightness.light),
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(children: [
                ChroniqueRing(group: [_c('aicha_dakar', type: ChroniqueType.VIDEO), _c('aicha_dakar', minutesAgo: 9)], seen: false, onTap: () {}),
                ChroniqueRing(group: [_c('yao')], seen: true, onTap: () {}),
                ChroniqueAddRing(onTap: () {}),
                SizedBox(width: 160, child: ChroniqueCard(group: [_c('mariam', type: ChroniqueType.TEXT, text: 'Bonne fête papa', music: 'https://example.com/a.m4a', views: 1200, likes: 40)], seen: false, height: 176, onTap: () {})),
              ]),
            ),
          ),
        ));
        await t.pump();
        expect(find.text('aicha'), findsOneWidget);
        expect(find.text('Ma chronique'), findsOneWidget);
        expect(find.text('Soleil'), findsOneWidget);
        expect(find.text('1.2K'), findsOneWidget);
        expect(tester(t), isNull);
      }
    });
  });
}

Object? tester(WidgetTester t) => t.takeException();
