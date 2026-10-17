import 'dart:math';

import 'package:afrotok/pages/music/music_page.dart';
import 'package:afrotok/pages/music/playlists_pages.dart';
import 'package:afrotok/services/stream_counts.dart';
import 'package:afrotok/widgets/music/music_overlay.dart';
import 'package:afrotok/widgets/music/streams_text.dart';
import 'package:afrotok/pages/studio/artist_marketplace.dart';
import 'package:afrotok/services/music_playlists.dart';
import 'package:afrotok/pages/studio/montage/montage_music.dart';
import 'package:afrotok/services/music_queue.dart';
import 'package:afrotok/services/music_voice.dart';
import 'package:afrotok/widgets/music/preview_end_sheet.dart';
import 'package:afrotok/widgets/music/vinyl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

ArtistSound _sound({bool free = false, int sale = 100, int use = 5}) => ArtistSound.fromMap({
      'userId': 'u1', 'userPseudo': 'kofi_aya', 'title': 'Soleil d’Abidjan', 'genre': 'Afrobeat', 'previewUrl': 'https://example.com/a.m4a',
      'pricing': free ? 'free' : 'paid', 'useCoins': use, 'saleCoins': sale, 'durationMs': 204000, 'status': 'validated',
      'usageCount': 0, 'totalEarningsCoins': 0, 'postCount': 0, 'createdAt': Timestamp.now(),
    }, 's1');

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('com.ryanheise.just_audio.methods'), (c) async => null);
  });

  group('prix en pièces d’un titre', () {
    test('titre payant : prix d’utilisation et d’achat, part de l’artiste 60 %', () {
      final t = MusicTrack.fromSound(_sound(sale: 100, use: 5));
      expect(t.useCoins, 5);
      expect(t.saleCoins, 100);
      expect(t.saleShare, 60);
      expect(t.isFree, isFalse);
      expect(t.key, 'music_artist:s1');
    });

    test('titre gratuit : rien à payer, pas en vente', () {
      final t = MusicTrack.fromSound(_sound(free: true));
      expect(t.useCoins, 0);
      expect(t.saleCoins, 0);
      expect(t.isFree, isTrue);
    });

    test('un titre acheté (bibliothèque) n’est pas « gratuit » mais n’a plus de prix', () {
      final t = MusicTrack.fromLibrary({'soundId': 'x1', 'title': 'Calabash', 'genre': 'Highlife'});
      expect(t.owned, isTrue);
      expect(t.isFree, isFalse);
      expect(t.saleCoins, 0);
    });
  });

  group('voix de fin d’extrait', () {
    test('dit que l’extrait est fini et le prix en pièces', () {
      expect(MusicVoice.endOfPreview(100, code: 'fr'), 'Extrait gratuit terminé. Pour écouter la suite, achetez ce titre pour 100 pièces.');
      expect(MusicVoice.endOfPreview(100, code: 'en'), 'Free preview over. To hear the rest, buy this track for 100 coins.');
    });
    test('sans prix de vente : seulement « extrait terminé »', () {
      expect(MusicVoice.endOfPreview(0, code: 'fr'), 'Extrait gratuit terminé.');
    });
  });

  group('titre suivant', () {
    test('dans l’ordre, en boucle', () {
      expect(MusicQueue.pickNext(4, 0, false, [], Random(1)), 1);
      expect(MusicQueue.pickNext(4, 3, false, [], Random(1)), 0);
      expect(MusicQueue.pickNext(1, 0, false, [], Random(1)), 0);
    });

    test('aléatoire : jamais le titre en cours ni les 3 derniers joués', () {
      final r = Random(7);
      for (var n = 0; n < 300; n++) {
        final idx = r.nextInt(8);
        final hist = [for (var i = 0; i < 3; i++) (idx + 1 + i) % 8];
        final next = MusicQueue.pickNext(8, idx, true, hist, r);
        expect(next, isNot(idx));
        expect(hist.contains(next), isFalse);
      }
    });

    test('aléatoire avec 2 titres : l’autre titre', () {
      expect(MusicQueue.pickNext(2, 0, true, [1], Random(3)), 1);
      expect(MusicQueue.pickNext(2, 1, true, [0], Random(3)), 0);
    });
  });

  group('feuille de fin d’extrait', () {
    Future<void> show(WidgetTester tester, {required int balance, bool canAd = true, ArtistSound? s}) async {
      await tester.binding.setSurfaceSize(const Size(380, 800));
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(body: Align(alignment: Alignment.bottomCenter, child: PreviewEndSheet(track: MusicTrack.fromSound(s ?? _sound()), balance: balance, canAd: canAd))),
      ));
      await tester.pump(const Duration(milliseconds: 200));
    }

    testWidgets('solde suffisant : acheter, pub, post, plus tard, et le soutien de l’artiste', (tester) async {
      await show(tester, balance: 240);
      expect(find.text('Tu aimes ce titre ?'), findsOneWidget);
      expect(find.textContaining('Acheter le titre · 100 🪙'), findsOneWidget);
      expect(find.text('Ton solde : 240 pièces → 140 après'), findsOneWidget);
      expect(find.text('Écouter en entier avec une pub'), findsOneWidget);
      expect(find.textContaining('Créer un post avec ce son · 5 🪙'), findsOneWidget);
      expect(find.text('Plus tard'), findsOneWidget);
      expect(find.textContaining('60 pièces', findRichText: true), findsOneWidget);
      expect(find.textContaining('@kofi_aya', findRichText: true), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('solde insuffisant : le bouton devient « Recharger mes pièces »', (tester) async {
      await show(tester, balance: 40);
      expect(find.text('Recharger mes pièces'), findsOneWidget);
      expect(find.textContaining('Acheter le titre'), findsNothing);
      expect(find.textContaining('coûte 100 pièces, il t’en reste 40'), findsOneWidget);
    });

    testWidgets('sans pub récompensée disponible : pas de bouton pub', (tester) async {
      await show(tester, balance: 240, canAd: false);
      expect(find.text('Écouter en entier avec une pub'), findsNothing);
    });

    testWidgets('titre qui n’est pas en vente : pas de bouton d’achat, on invite à l’utiliser dans un post', (tester) async {
      await show(tester, balance: 240, s: _sound(sale: 0));
      expect(find.textContaining('Acheter le titre'), findsNothing);
      expect(find.textContaining('dans ton prochain post', findRichText: true), findsOneWidget);
    });
  });

  group('disque vinyle', () {
    for (final spinning in [true, false]) {
      testWidgets('se dessine (${spinning ? 'en lecture' : 'en pause'})', (tester) async {
        await tester.pumpWidget(MaterialApp(theme: ThemeData.dark(), home: Scaffold(body: Center(child: Stack(children: [VinylDisc(size: 160, spinning: spinning), const Tonearm(height: 100, playing: true)])))));
        await tester.pump(const Duration(milliseconds: 600));
        expect(tester.takeException(), isNull);
        // le disque change d’état sans erreur
        await tester.pumpWidget(MaterialApp(theme: ThemeData.dark(), home: Scaffold(body: Center(child: VinylDisc(size: 160, spinning: !spinning)))));
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('playlists', () {
    MusicPlaylist pl({bool paid = false, int price = 0, int paidCount = 0, List<String>? ids}) => MusicPlaylist.fromMap({
          'ownerId': 'o1', 'ownerPseudo': 'tobi_ade', 'title': 'Amapiano Vibes', 'access': paid ? 'paid' : 'free', 'priceCoins': price,
          'trackIds': ids ?? ['a:s1', 'f:amapiano'], 'paidCount': paidCount, 'streamCount': 3150,
        }, 'p1');

    test('accès, prix et part du créateur (60 %)', () {
      final p = pl(paid: true, price: 80, paidCount: 1);
      expect(p.isPaid, isTrue);
      expect(p.ownerShare, 48);
      expect(p.hasPaidTracks, isTrue);
      expect(p.trackCount, 2);
      expect(pl().isPaid, isFalse);
    });

    test('limites de prix de 20 à 500 pièces', () {
      expect(kPlaylistMinPrice, 20);
      expect(kPlaylistMaxPrice, 500);
      expect(pl(paid: true, price: 500).ownerShare, 300);
      expect(pl(paid: true, price: 20).ownerShare, 12);
    });

    test('référence d’un titre : « a: » pour un artiste, « f: » pour une musique gratuite', () {
      expect(MusicPlaylists.ref(MusicTrack.fromSound(_sound())), 'a:s1');
      expect(MusicPlaylists.ref(MusicTrack.fromStudio(kStudioTracks.first)), 'f:${kStudioTracks.first.id}');
    });

    test('écoutes en notation courte', () {
      expect(compactCount(0), '0');
      expect(compactCount(999), '999');
      expect(compactCount(1234), '1,2 k');
      expect(compactCount(12400), '12 k');
      expect(compactCount(1500000), '1,5 M');
    });

    testWidgets('page d’une playlist payante : avertissement, lecture bloquée, bouton d’ajout au prix', (tester) async {
      final p = pl(paid: true, price: 80, paidCount: 1);
      final tracks = [MusicTrack.fromSound(_sound()), MusicTrack.fromStudio(kStudioTracks.first)];
      await tester.pumpWidget(MaterialApp(home: PlaylistDetailPage(playlist: p, preview: (load: PlaylistLoad(tracks, 1), inLibrary: false, mine: false))));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('1 titre payant dans cette playlist'), findsOneWidget);
      expect(find.textContaining('Ajouter à ma bibliothèque · 🪙 80'), findsOneWidget);
      expect(find.textContaining('1 titre n’est plus disponible'), findsOneWidget);
      final play = tester.widget<ButtonStyleButton>(find.widgetWithText(FilledButton, 'Lecture'));
      expect(play.onPressed, isNull); // pas ajoutée : lecture de toute la playlist indisponible
    });

    testWidgets('playlist gratuite : lecture possible, pas d’avertissement', (tester) async {
      final p = pl();
      final tracks = [MusicTrack.fromStudio(kStudioTracks.first)];
      await tester.pumpWidget(MaterialApp(home: PlaylistDetailPage(playlist: p, preview: (load: PlaylistLoad(tracks, 0), inLibrary: false, mine: false))));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('titre payant'), findsNothing);
      final play = tester.widget<ButtonStyleButton>(find.widgetWithText(FilledButton, 'Lecture'));
      expect(play.onPressed, isNotNull);
      expect(find.textContaining('Ajouter à ma bibliothèque · gratuit'), findsOneWidget);
    });
  });

  group('écoutes affichées partout', () {
    test('format : 0 écoute, 1 écoute, 950 écoutes, 1,2 k écoutes', () {
      expect(StreamCounts.label(0), '0 écoute');
      expect(StreamCounts.label(1), '1 écoute');
      expect(StreamCounts.label(950), '950 écoutes');
      expect(StreamCounts.label(1234), '1,2 k écoutes');
      expect(StreamCounts.label(12400), '12 k écoutes');
    });

    test('l\'écoute compte après 10 secondes', () {
      expect(MusicQueue.streamAfterSeconds, 10);
    });

    test('durée de l\'extrait lue dans le son (30 s pour un ancien son)', () {
      expect(_sound().previewSec, 30);
      final s = ArtistSound.fromMap({'userId': 'u', 'userPseudo': 'a', 'title': 't', 'previewSec': 8, 'durationMs': 30000, 'status': 'validated', 'usageCount': 0, 'totalEarningsCoins': 0, 'createdAt': Timestamp.now()}, 'x');
      expect(s.previewSec, 8);
      expect(MusicTrack.fromSound(s).previewSec, 8);
      expect(MusicTrack.fromStudio(kStudioTracks.first).previewSec, 30);
    });

    testWidgets('chaque titre montre ses écoutes, même à zéro, et se met à jour en direct', (tester) async {
      final t = MusicTrack.fromSound(_sound());
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: StreamsText(track: t, color: Colors.black))));
      expect(find.text('0 écoute'), findsOneWidget);
      StreamCounts.counts.value = {...StreamCounts.counts.value, t.key: 1500};
      await tester.pump();
      expect(find.text('1,5 k écoutes'), findsOneWidget);
      // une musique gratuite d'Afrolook aussi
      final f = MusicTrack.fromStudio(kStudioTracks.first);
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: StreamsText(track: f, color: Colors.black))));
      expect(find.text('0 écoute'), findsOneWidget);
      StreamCounts.counts.value = const {};
    });
  });

  testWidgets('page Musique : le lecteur flottant revient quand une autre page s\'ouvre par-dessus', (tester) async {
    MusicOverlay.hidden.value = 0;
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(navigatorKey: nav, home: MusicPage(preview: (sounds: [MusicTrack.fromSound(_sound())], free: const []), previewPlaylists: (mine: const [], discover: const []))));
    await tester.pump(const Duration(milliseconds: 100));
    expect(MusicOverlay.hidden.value, 1); // « Pour toi » : le disque fait office de lecteur
    nav.currentState!.push(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('autre page'))));
    await tester.pumpAndSettle();
    expect(MusicOverlay.hidden.value, 0); // la page est cachée sous une autre : la capsule doit se voir
    nav.currentState!.pop();
    await tester.pumpAndSettle();
    expect(MusicOverlay.hidden.value, 1);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(MusicOverlay.hidden.value, 0);
  });
}
