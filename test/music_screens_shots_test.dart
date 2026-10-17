// Captures d'écran des vrais écrans Musique (widgets de l'application, sans Firebase) : MUSIC_OUT=dossier MATERIAL_FONT=MaterialIcons-Regular.otf flutter test test/music_screens_shots_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:afrotok/pages/music/music_page.dart';
import 'package:afrotok/pages/studio/artist_marketplace.dart';
import 'package:afrotok/pages/studio/artist_sound_common.dart';
import 'package:afrotok/pages/studio/feed_sound_card.dart';
import 'package:afrotok/pages/studio/montage/montage_music.dart';
import 'package:afrotok/services/music_queue.dart';
import 'package:afrotok/theme/app_theme.dart';
import 'package:afrotok/widgets/music/music_overlay.dart';
import 'package:afrotok/widgets/music/preview_end_sheet.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

ArtistSound _s(String id, String title, String pseudo, {bool free = false, String genre = 'Afrobeat', int use = 5, int sale = 100}) => ArtistSound.fromMap({
      'userId': 'u_$id', 'userPseudo': pseudo, 'title': title, 'genre': genre, 'previewUrl': 'https://example.com/$id.m4a', 'pricing': free ? 'free' : 'paid',
      'useCoins': use, 'saleCoins': free ? 0 : sale, 'durationMs': 204000, 'status': 'validated', 'usageCount': 0, 'totalEarningsCoins': 0, 'postCount': 12,
      'createdAt': Timestamp.now(),
    }, id);

Future<void> _loadFont(String family, String path) async {
  final f = File(path);
  if (!f.existsSync()) return;
  final l = FontLoader(family)..addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
  await l.load();
}

void main() {
  final out = Platform.environment['MUSIC_OUT'];
  if (out == null) {
    test('captures désactivées (MUSIC_OUT absent)', () {});
    return;
  }
  final sounds = [
    _s('a1', 'Soleil d’Abidjan', 'kofi_aya'),
    _s('b2', 'Nuits de Cotonou', 'mawuli_k', free: true, genre: 'Zouk'),
    _s('c3', 'Lagos Midnight', 'tobi_ade', genre: 'Afro-house', use: 10, sale: 150),
    _s('d4', 'Zémidjan Flow', 'senam', genre: 'Rap'),
    _s('e5', 'Dakar Vibes', 'awa_ndiaye', genre: 'Mbalax', use: 8, sale: 120),
  ];
  final tracks = sounds.map((s) => MusicTrack.fromSound(s)).toList();
  final free = kStudioTracks.take(4).map(MusicTrack.fromStudio).toList();

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _loadFont('Nunito', 'assets/fonts/Nunito-Regular.ttf');
    final mf = Platform.environment['MATERIAL_FONT'];
    if (mf != null) await _loadFont('MaterialIcons', mf);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('com.ryanheise.just_audio.methods'), (c) async => null);
  });

  void playing(MusicTrack t, {bool preview = true, bool ended = false}) {
    MusicQueue.current.value = t;
    MusicQueue.previewMode.value = preview;
    MusicQueue.previewEnded.value = ended;
    SoundPreview.now.value = NowPlaying(key: t.key, title: t.title, subtitle: t.artist);
    SoundPreview.playing.value = ended ? null : t.key;
  }

  Future<void> shot(WidgetTester tester, String name, bool dark, Widget Function() build, {bool overlay = false, double scroll = 0}) async {
    await tester.binding.setSurfaceSize(const Size(360, 744));
    tester.view.devicePixelRatio = 1;
    final key = GlobalKey();
    final app = MaterialApp(debugShowCheckedModeBanner: false, theme: dark ? AppTheme.dark : AppTheme.light, home: build(), builder: overlay ? (c, child) => MusicOverlayHost(child: child!) : null);
    await tester.pumpWidget(RepaintBoundary(key: key, child: app));
    await tester.pump(const Duration(milliseconds: 500));
    if (scroll != 0) {
      await tester.drag(find.byType(Scrollable).first, Offset(0, -scroll));
      await tester.pump(const Duration(milliseconds: 500));
    }
    await tester.pump(const Duration(milliseconds: 500));
    await tester.runAsync(() async {
      final b = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final img = await b.toImage(pixelRatio: 2.5);
      final data = await img.toByteData(format: ui.ImageByteFormat.png);
      await File('$out/${name}_${dark ? 'sombre' : 'clair'}.png').writeAsBytes(data!.buffer.asUint8List());
    });
    expect(tester.takeException(), isNull);
  }

  for (final dark in [false, true]) {
    testWidgets('page Musique (${dark ? 'sombre' : 'clair'})', (t) async {
      playing(tracks.first);
      await shot(t, '1_page_musique', dark, () => MusicPage(preview: (sounds: tracks, free: free)));
    });
    testWidgets('page Musique, liste (${dark ? 'sombre' : 'clair'})', (t) async {
      playing(tracks.first);
      await shot(t, '1b_page_musique_liste', dark, () => MusicPage(preview: (sounds: tracks, free: free)), scroll: 520);
    });
    testWidgets('fiche du titre (${dark ? 'sombre' : 'clair'})', (t) async {
      playing(tracks.first);
      await shot(t, '2_fiche_titre', dark, () => ArtistSoundDetailPage(sound: sounds.first, preview: true));
    });
    testWidgets('fin d’extrait (${dark ? 'sombre' : 'clair'})', (t) async {
      playing(tracks.first, ended: true);
      await shot(t, '3_fin_extrait', dark, () => Builder(builder: (ctx) => Stack(children: [
            ArtistSoundDetailPage(sound: sounds.first, preview: true),
            Positioned.fill(child: ColoredBox(color: Colors.black.withValues(alpha: .55))),
            Align(alignment: Alignment.bottomCenter, child: Material(type: MaterialType.transparency, child: PreviewEndSheet(track: tracks.first, balance: 240, canAd: true))),
          ])));
    });
    testWidgets('fin d’extrait, solde insuffisant (${dark ? 'sombre' : 'clair'})', (t) async {
      playing(tracks[2], ended: true);
      await shot(t, '4_fin_extrait_solde_faible', dark, () => Builder(builder: (ctx) => Stack(children: [
            ArtistSoundDetailPage(sound: sounds[2], preview: true),
            Positioned.fill(child: ColoredBox(color: Colors.black.withValues(alpha: .55))),
            Align(alignment: Alignment.bottomCenter, child: Material(type: MaterialType.transparency, child: PreviewEndSheet(track: tracks[2], balance: 40, canAd: true))),
          ])));
    });
    testWidgets('widgets du fil (${dark ? 'sombre' : 'clair'})', (t) async {
      playing(tracks.first);
      await shot(t, '5_widgets_du_fil', dark, () => Scaffold(body: ListView(padding: const EdgeInsets.only(top: 30), children: [
            FeedSoundCard(slot: 0, preset: sounds[0]),
            FeedSoundCarousel(slot: 0, presets: sounds),
            FeedSoundList(slot: 0, presets: sounds),
          ])));
    });
    testWidgets('lecteur flottant (${dark ? 'sombre' : 'clair'})', (t) async {
      playing(tracks.first);
      await shot(t, '6_lecteur_flottant', dark, () => Scaffold(appBar: AppBar(title: const Text('Quiz & Étude')), body: const Center(child: Text('Une page quelconque de l’application'))),
          overlay: true);
    });
    testWidgets('lecteur flottant, extrait terminé (${dark ? 'sombre' : 'clair'})', (t) async {
      playing(tracks.first, ended: true);
      await shot(t, '7_lecteur_flottant_fin', dark, () => Scaffold(appBar: AppBar(title: const Text('Quiz & Étude')), body: const Center(child: Text('Une page quelconque de l’application'))),
          overlay: true);
    });
  }
}
