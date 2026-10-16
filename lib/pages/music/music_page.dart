// Page Musique d'Afrolook : écouter, aimer et utiliser les musiques gratuites d'Afrolook et les sons des artistes.
// Onglets : Pour toi · Gratuites · Artistes · Favoris. Lecteur réduit en bas. Thèmes clair et sombre (AppColors).
// Phases faites : achat et bibliothèque, lecture en arrière-plan, téléchargement protégé, pays des titres, pubs.

import 'dart:async';
import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../../ads/ad_slot.dart';
import '../../ads/music_ads.dart';
import '../../providers/authProvider.dart';
import '../../services/offline_music_service.dart';
import '../pub/afrolook_inline_ad.dart';
import '../../theme/app_colors.dart';
import '../studio/artist_marketplace.dart';
import '../studio/artist_sound_common.dart';
import '../studio/sound_countries.dart';
import '../studio/montage/montage_music.dart';
import 'music_favorites.dart';

enum _Kind { free, artist }

class _Item {
  _Item.free(StudioTrack t)
      : kind = _Kind.free,
        id = t.id,
        title = t.title,
        subtitle = '${t.mood} · Musique Afrolook',
        emoji = t.emoji,
        coverUrl = null,
        previewUrl = null,
        paid = false,
        owned = false,
        track = t,
        sound = null;

  _Item.artist(ArtistSound s)
      : kind = _Kind.artist,
        id = s.id,
        title = s.title,
        subtitle = s.genre != null && s.genre!.isNotEmpty ? s.genre! : 'Artiste Afrolook',
        emoji = '🎤',
        coverUrl = s.coverImageUrl,
        previewUrl = s.previewUrl,
        paid = !s.isFree,
        owned = false,
        track = null,
        sound = s;

  /// Titre acheté (bibliothèque) : on garde l'essentiel du document MusicLibrary ; le titre complet se charge à la demande.
  _Item.library(Map<String, dynamic> d)
      : kind = _Kind.artist,
        id = '${d['soundId']}',
        title = '${d['title'] ?? 'Titre'}',
        subtitle = (d['genre'] ?? '').toString().isNotEmpty ? '${d['genre']}' : 'Acheté',
        emoji = '🎤',
        coverUrl = d['coverImageUrl'] as String?,
        previewUrl = null,
        paid = true,
        owned = true,
        track = null,
        sound = null;

  final _Kind kind;
  final String id;
  final String title;
  final String subtitle;
  final String emoji;
  final String? coverUrl;
  final String? previewUrl;
  final bool paid;
  final bool owned;
  final StudioTrack? track;
  final ArtistSound? sound;

  String get kindName => kind == _Kind.free ? 'free' : 'artist';
  String get playKey => 'music_$kindName:$id';
  bool get isFree => !paid;
}

class MusicPage extends StatefulWidget {
  const MusicPage({super.key});

  @override
  State<MusicPage> createState() => _MusicPageState();
}

class _MusicPageState extends State<MusicPage> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 5, vsync: this);
  final _search = TextEditingController();
  bool _searching = false;
  String _q = '';
  Duration _pos = Duration.zero;
  Duration _dur = const Duration(seconds: 30);
  StreamSubscription<Duration>? _p;
  StreamSubscription<Duration>? _d;
  String? _loadingKey;

  @override
  void initState() {
    super.initState();
    MusicFavorites.start();
    OfflineMusic.refresh();
    ArtistSoundPricing.load().then((_) {
      if (mounted) setState(() {});
    });
    _p = SoundPreview.position.listen((p) {
      if (mounted && SoundPreview.playing.value != null) setState(() => _pos = p);
    });
    _d = SoundPreview.duration.listen((d) {
      if (mounted && d.inMilliseconds > 0) setState(() => _dur = d);
    });
  }

  @override
  void dispose() {
    _p?.cancel();
    _d?.cancel();
    _tabs.dispose();
    _search.dispose();
    // La musique continue quand on quitte la page (notification et écran verrouillé), sauf si on la met en pause.
    super.dispose();
  }

  // ── Lecture ──

  Future<void> _play(_Item it) async {
    final key = it.playKey;
    if (SoundPreview.playing.value == key) {
      await SoundPreview.pause();
      return;
    }
    if (SoundPreview.now.value?.key == key) {
      await SoundPreview.resume();
      if (SoundPreview.playing.value == key) return;
    }
    setState(() => _loadingKey = key);
    // Pub plein écran rare, seulement entre deux titres (jamais pendant l'écoute)
    await MusicAds.beforeTrack(context.read<UserAuthProvider>().loginUserData);
    if (!mounted) return;
    // Titre téléchargé : lu depuis l'espace privé (fonctionne sans internet)
    if (it.kind == _Kind.artist && OfflineMusic.has(it.id)) {
      final err = await OfflineMusic.play(it.id, title: it.title, key: key);
      if (!mounted) return;
      setState(() {
        _loadingKey = null;
        _pos = Duration.zero;
      });
      if (err != null) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    String? url = it.previewUrl;
    var full = false;
    if (url == null && it.track != null) url = await MontageMusicPlayer.urlOf(MontageMusic.free(it.track!));
    // Titre complet : acheté, gratuit d'un artiste, ou à soi ; sinon extrait de 30 s
    final own = it.sound?.userId == FirebaseAuth.instance.currentUser?.uid;
    if (it.kind == _Kind.artist && (it.owned || (it.sound != null && (it.sound!.isFree || own)))) {
      final f = await fetchFullListenUrl(it.id);
      if (f != null) {
        url = f;
        full = true;
      }
    }
    if (!mounted) return;
    var ok = false;
    if (url != null) {
      setState(() => _pos = Duration.zero);
      ok = await SoundPreview.play(key, url, meta: NowPlaying(key: key, title: it.title, subtitle: full ? 'Titre complet' : (it.kind == _Kind.artist ? 'Extrait de 30 s' : it.subtitle), coverUrl: it.coverUrl));
    }
    if (!mounted) return;
    setState(() => _loadingKey = null);
    if (!ok) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Impossible de lire ce titre. Vérifie ta connexion.')));
  }

  /// Droit de télécharger : titre acheté, gratuit d'un artiste, ou à soi.
  bool _canDownload(_Item it) {
    if (!OfflineMusic.supported || it.kind != _Kind.artist) return false;
    final own = it.sound?.userId == FirebaseAuth.instance.currentUser?.uid;
    return it.owned || own || (it.sound?.isFree ?? false);
  }

  Future<void> _download(_Item it) async {
    final c = AppColors.of(context);
    final progress = ValueNotifier<double>(0);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        title: Text('Téléchargement…', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 16)),
        content: ValueListenableBuilder<double>(
          valueListenable: progress,
          builder: (_, v, __) => Column(mainAxisSize: MainAxisSize.min, children: [
            LinearProgressIndicator(value: v <= 0 ? null : v, color: c.primary, backgroundColor: c.border),
            const SizedBox(height: 10),
            Text('« ${it.title} » sera rangé de façon sécurisée dans Afrolook.', style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
          ]),
        ),
      ),
    );
    final r = await OfflineMusic.download(it.id, onProgress: (v) => progress.value = v);
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    progress.dispose();
    if (r.ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Titre disponible hors ligne dans Afrolook ✅')));
    } else if (r.needsPurchase && it.sound != null) {
      buyTrack(context, it.sound!);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r.message ?? 'Téléchargement impossible.')));
    }
  }

  Future<void> _removeDownload(_Item it) async {
    final c = AppColors.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        title: Text('Retirer du téléphone ?', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 16)),
        content: Text('« ${it.title} » restera dans ta bibliothèque, tu pourras le retélécharger.', style: TextStyle(color: c.textSecondary, fontSize: 13.5)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Annuler', style: TextStyle(color: c.textSecondary))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Retirer', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok != true) return;
    if (SoundPreview.now.value?.key == it.playKey) await SoundPreview.stop();
    await OfflineMusic.remove(it.id);
  }

  /// Titre payant pas encore acheté : l'écouter en entier, une fois, après une pub récompensée.
  Future<void> _playWithAd(_Item it) async {
    final c = AppColors.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        title: Text('Écouter en entier ?', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 16)),
        content: Text('Regarde une courte pub pour écouter « ${it.title} » en entier, une fois. Pour le garder dans ta bibliothèque et l’écouter quand tu veux, achète-le.',
            style: TextStyle(color: c.textSecondary, fontSize: 13.5, height: 1.4)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Non merci', style: TextStyle(color: c.textSecondary))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Regarder la pub', style: TextStyle(color: c.primary, fontWeight: FontWeight.w800))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _loadingKey = it.playKey);
    final r = await MusicAds.listenWithAd(it.id, userId: FirebaseAuth.instance.currentUser?.uid ?? '');
    if (!mounted) return;
    if (r.outcome != MusicAdOutcome.ok || r.url == null) {
      setState(() => _loadingKey = null);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(MusicAds.message(r.outcome))));
      return;
    }
    setState(() => _pos = Duration.zero);
    final played = await SoundPreview.play(it.playKey, r.url!, meta: NowPlaying(key: it.playKey, title: it.title, subtitle: 'Titre complet · écoute avec pub', coverUrl: it.coverUrl));
    if (!mounted) return;
    setState(() => _loadingKey = null);
    if (!played) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Impossible de lire ce titre. Vérifie ta connexion.')));
  }

  bool _canListenWithAd(_Item it) =>
      it.kind == _Kind.artist &&
      it.sound != null &&
      !it.sound!.isFree &&
      !it.owned &&
      it.sound!.userId != FirebaseAuth.instance.currentUser?.uid &&
      MusicAds.canOfferRewarded(context.read<UserAuthProvider>().loginUserData);

  void _createOwnVideo(_Item it) async {
    final music = it.sound != null ? MontageMusic.artist(it.sound!) : (it.track != null ? MontageMusic.free(it.track!) : null);
    if (music != null) return startPostWithMusic(context, music, ownVideo: true);
    try {
      final d = await FirebaseFirestore.instance.collection('artist_sounds').doc(it.id).get();
      if (!mounted) return;
      if (!d.exists || d.data()!['status'] != 'validated') {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ce titre n’est plus disponible.')));
        return;
      }
      startPostWithMusic(context, MontageMusic.artist(ArtistSound.fromMap(d.data()!, d.id)), ownVideo: true);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chargement impossible. Vérifie ta connexion.')));
    }
  }

  void _create(_Item it) async {
    if (it.sound == null && it.track == null) {
      // titre de la bibliothèque : on charge le document du son
      try {
        final d = await FirebaseFirestore.instance.collection('artist_sounds').doc(it.id).get();
        if (!mounted) return;
        if (!d.exists || d.data()!['status'] != 'validated') {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ce titre n’est plus disponible.')));
          return;
        }
        startPostWithMusic(context, MontageMusic.artist(ArtistSound.fromMap(d.data()!, d.id)));
      } catch (_) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chargement impossible. Vérifie ta connexion.')));
      }
      return;
    }
    final music = it.sound != null ? MontageMusic.artist(it.sound!) : MontageMusic.free(it.track!);
    startPostWithMusic(context, music);
  }

  void _open(_Item it) async {
    if (it.sound == null && it.track == null) {
      openArtistSoundById(context, it.id);
      return;
    }
    if (it.sound == null) {
      _play(it);
      return;
    }
    await Navigator.push(context, MaterialPageRoute(builder: (_) => ArtistSoundDetailPage(sound: it.sound!)));
  }

  bool _match(_Item it) {
    if (_q.isEmpty) return true;
    final q = _q.toLowerCase();
    return it.title.toLowerCase().contains(q) || it.subtitle.toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        elevation: 0,
        iconTheme: IconThemeData(color: c.textPrimary),
        title: _searching
            ? TextField(
                controller: _search,
                autofocus: true,
                onChanged: (v) => setState(() => _q = v.trim()),
                style: TextStyle(color: c.textPrimary),
                decoration: InputDecoration(hintText: 'Titre, genre…', hintStyle: TextStyle(color: c.textSecondary), border: InputBorder.none),
              )
            : Text('Musique', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w900, fontSize: 24)),
        actions: [
          IconButton(
            icon: Icon(_searching ? Icons.close_rounded : Icons.search_rounded, color: c.textPrimary),
            onPressed: () => setState(() {
              _searching = !_searching;
              if (!_searching) {
                _q = '';
                _search.clear();
              }
            }),
          ),
          IconButton(
            tooltip: 'Espace artiste',
            icon: Icon(Icons.mic_rounded, color: c.primary),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyArtistSoundsPage())),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: c.primary,
          unselectedLabelColor: c.textSecondary,
          indicatorColor: c.primary,
          labelStyle: const TextStyle(fontWeight: FontWeight.w800),
          tabs: const [Tab(text: 'Pour toi'), Tab(text: 'Gratuites'), Tab(text: 'Artistes'), Tab(text: 'Ma bibliothèque'), Tab(text: 'Favoris')],
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('artist_sounds').where('status', isEqualTo: 'validated').orderBy('validatedAt', descending: true).limit(150).snapshots(),
        builder: (_, snap) {
          final loading = !snap.hasData && !snap.hasError;
          // Titres proposés dans le pays de la personne (ou à tous) ; ceux visés pour son pays passent devant
          final sounds = SoundCountries.forViewer<ArtistSound>(
            [for (final d in snap.data?.docs ?? const <QueryDocumentSnapshot>[]) ArtistSound.fromMap(d.data() as Map<String, dynamic>, d.id)].where((s) => s.previewUrl != null),
            countries: (s) => s.availableCountries,
            owner: (s) => s.userId,
            viewerCountry: SoundCountries.viewerCountry(context),
          ).map(_Item.artist).toList();
          final free = kStudioTracks.map(_Item.free).toList();
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseAuth.instance.currentUser == null ? null : FirebaseFirestore.instance.collection('MusicLibrary').where('uid', isEqualTo: FirebaseAuth.instance.currentUser!.uid).snapshots(),
            builder: (_, libSnap) {
              final libDocs = [for (final d in libSnap.data?.docs ?? const <QueryDocumentSnapshot>[]) d.data() as Map<String, dynamic>]
                ..sort((a, b) => ((b['createdAt'] as num?) ?? 0).compareTo((a['createdAt'] as num?) ?? 0));
              final library = libDocs.map(_Item.library).toList();
              return ValueListenableBuilder<Set<String>>(
            valueListenable: MusicFavorites.keys,
            builder: (_, favs, __) {
              final all = [...sounds, ...free];
              final favItems = all.where((i) => favs.contains('${i.kindName}:${i.id}')).toList();
              return TabBarView(controller: _tabs, children: [
                _forYou(c, sounds, free, loading),
                _list(c, [...free, ...sounds.where((s) => s.isFree)].where(_match).toList(), 'Aucune musique gratuite trouvée.'),
                _list(c, sounds.where(_match).toList(), loading ? '' : 'Aucun son d’artiste pour l’instant.', loading: loading, artistsCta: true),
                _list(c, library.where(_match).toList(), 'Achète un titre : il reste ici, lisible en entier dans Afrolook.'),
                _list(c, favItems.where(_match).toList(), 'Touche le ♡ d’un titre pour le retrouver ici.'),
              ]);
            },
          );
            },
          );
        },
      ),
      bottomNavigationBar: Column(mainAxisSize: MainAxisSize.min, children: [
        // Bannière sous la liste, seulement sur un écran assez haut
        if (MediaQuery.of(context).size.height >= 700)
          AdSlot(key: const ValueKey('music_banner'), kind: AdSlotKind.musicBanner, own: () => const AfrolookInlineAd(compact: true), admobFirst: true),
        if (_miniPlayer(c) != null) _miniPlayer(c)!,
      ]),
    );
  }

  // ── Onglets ──

  Widget _forYou(AppColors c, List<_Item> sounds, List<_Item> free, bool loading) {
    final all = [...sounds, ...free];
    if (_q.isNotEmpty) return _list(c, all.where(_match).toList(), 'Aucun résultat.');
    return ListView(padding: const EdgeInsets.fromLTRB(16, 10, 16, 24), children: [
      // Carte d'accueil : lecture au hasard
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(colors: [Color(0xFF6A1B9A), Color(0xFFE91E63), Color(0xFFFFB400)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        ),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Mix Afrolook', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text('${all.length} titres : afrobeat, amapiano, calme, fête…', style: const TextStyle(color: Colors.white, fontSize: 13)),
            ]),
          ),
          FilledButton.icon(
            onPressed: all.isEmpty ? null : () => _play(all[Random().nextInt(all.length)]),
            icon: const Icon(Icons.shuffle_rounded, size: 18),
            label: const Text('Au hasard'),
            style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF6A1B9A)),
          ),
        ]),
      ),
      if (sounds.isNotEmpty) ...[
        _section(c, '🎤 Nouveautés des artistes'),
        for (final it in sounds.take(8)) _row(c, it),
      ],
      _section(c, '🎵 Musiques Afrolook'),
      for (final it in free.take(8)) _row(c, it),
      const SizedBox(height: 10),
      Center(child: TextButton(onPressed: () => _tabs.animateTo(1), child: Text('Voir toutes les musiques gratuites', style: TextStyle(color: c.primary, fontWeight: FontWeight.w800)))),
      if (loading) Padding(padding: const EdgeInsets.all(16), child: Center(child: CircularProgressIndicator(color: c.primary))),
    ]);
  }

  Widget _list(AppColors c, List<_Item> items, String empty, {bool loading = false, bool artistsCta = false}) {
    return ListView(padding: const EdgeInsets.fromLTRB(16, 10, 16, 24), children: [
      if (artistsCta) _artistCta(c),
      if (loading) Padding(padding: const EdgeInsets.all(24), child: Center(child: CircularProgressIndicator(color: c.primary))),
      if (!loading && items.isEmpty)
        Padding(padding: const EdgeInsets.symmetric(vertical: 40), child: Center(child: Text(empty, textAlign: TextAlign.center, style: TextStyle(color: c.textSecondary)))),
      for (var i = 0; i < items.length; i++) ...[
        _row(c, items[i]),
        // Pub native tous les 6 titres (AdMob d'abord, pub Afrolook en repli ; aucune place vide, jamais pour Gold)
        if ((i + 1) % 6 == 0 && i != items.length - 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AdSlot(key: ValueKey('music_ad_$i'), kind: AdSlotKind.musicList, own: () => const AfrolookInlineAd(compact: true), admobFirst: true),
          ),
      ],
    ]);
  }

  Widget _artistCta(AppColors c) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: InkWell(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyArtistSoundsPage())),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.border)),
            child: Row(children: [
              const Text('🎤', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 10),
              Expanded(child: Text('Tu es artiste ? Propose ton son et gagne des pièces.', style: TextStyle(color: c.textPrimary, fontSize: 13, fontWeight: FontWeight.w700))),
              Icon(Icons.chevron_right_rounded, color: c.textSecondary),
            ]),
          ),
        ),
      );

  Widget _section(AppColors c, String t) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 20, 2, 8),
        child: Text(t, style: TextStyle(color: c.textPrimary, fontSize: 17, fontWeight: FontWeight.w900)),
      );

  // ── Ligne d'un titre ──

  Widget _row(AppColors c, _Item it) {
    final playing = SoundPreview.playing;
    return ValueListenableBuilder<Set<String>>(
      valueListenable: OfflineMusic.ids,
      builder: (_, offline, __) => _rowBody(c, it, playing, offline.contains(it.id) && it.kind == _Kind.artist),
    );
  }

  Widget _rowBody(AppColors c, _Item it, ValueNotifier<String?> playing, bool downloaded) {
    return ValueListenableBuilder<String?>(
      valueListenable: playing,
      builder: (_, now, __) {
        final on = now == it.playKey;
        final fav = MusicFavorites.isFav(it.kindName, it.id);
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: on ? c.primary.withValues(alpha: .1) : c.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: on ? c.primary : c.border),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _open(it),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
              child: Row(children: [
                _cover(c, it),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(it.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: on ? c.primary : c.textPrimary, fontWeight: FontWeight.w800, fontSize: 14.5)),
                    const SizedBox(height: 2),
                    Row(children: [
                      _badge(it),
                      if (downloaded) ...[
                        const SizedBox(width: 4),
                        Icon(Icons.download_done_rounded, size: 15, color: c.primary),
                      ],
                      const SizedBox(width: 6),
                      Expanded(child: Text(it.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textSecondary, fontSize: 12))),
                    ]),
                  ]),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: fav ? 'Retirer des favoris' : 'Ajouter aux favoris',
                  onPressed: () => MusicFavorites.toggle(it.kindName, it.id, title: it.title),
                  icon: Icon(fav ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: fav ? const Color(0xFFFF4D6D) : c.textSecondary, size: 22),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _play(it),
                  icon: _loadingKey == it.playKey
                      ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: c.primary))
                      : Icon(on ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded, color: c.primary, size: 34),
                ),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert_rounded, color: c.textSecondary, size: 20),
                  color: c.surface,
                  onSelected: (v) {
                    if (v == 'create') _create(it);
                    if (v == 'video') _createOwnVideo(it);
                    if (v == 'adlisten') _playWithAd(it);
                    if (v == 'open') _open(it);
                    if (v == 'buy' && it.sound != null) buyTrack(context, it.sound!);
                    if (v == 'download') _download(it);
                    if (v == 'undownload') _removeDownload(it);
                    if (v == 'report' && it.sound != null) reportArtistSound(context, it.sound!.id, it.title);
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'create', child: Text(it.sound != null && it.paid ? '🎬 Créer un post (${it.sound!.unitPrice} 🪙)' : '🎬 Créer un post avec ce son')),
                    PopupMenuItem(value: 'video', child: Text(it.sound != null && it.paid ? '🎥 Ma vidéo avec ce son (${it.sound!.unitPrice} 🪙)' : '🎥 Ma vidéo avec ce son')),
                    if (it.sound != null && it.sound!.forSale && it.sound!.userId != FirebaseAuth.instance.currentUser?.uid) PopupMenuItem(value: 'buy', child: Text('🛒 Acheter le titre · ${it.sound!.saleCoins} 🪙')),
                    if (_canListenWithAd(it)) const PopupMenuItem(value: 'adlisten', child: Text('🎧 Écouter en entier (une pub)')),
                    if (_canDownload(it))
                      PopupMenuItem(value: OfflineMusic.has(it.id) ? 'undownload' : 'download', child: Text(OfflineMusic.has(it.id) ? '🗑️ Retirer du téléphone' : '⬇️ Télécharger (écouter sans internet)')),
                    if (it.kind == _Kind.artist) const PopupMenuItem(value: 'open', child: Text('📄 Voir le titre et ses posts')),
                    if (it.sound != null && it.sound!.userId != FirebaseAuth.instance.currentUser?.uid) const PopupMenuItem(value: 'report', child: Text('🚩 Signaler')),
                  ],
                ),
              ]),
            ),
          ),
        );
      },
    );
  }

  Widget _cover(AppColors c, _Item it) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 54,
        height: 54,
        child: it.coverUrl != null
            ? CachedNetworkImage(imageUrl: it.coverUrl!, fit: BoxFit.cover)
            : Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: it.kind == _Kind.free ? const [Color(0xFF1FAA59), Color(0xFF0F6B38)] : const [Color(0xFF6A1B9A), Color(0xFFE91E63)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Text(it.emoji, style: const TextStyle(fontSize: 26)),
              ),
      ),
    );
  }

  Widget _badge(_Item it) {
    final color = it.isFree || it.owned ? const Color(0xFF2ECC71) : const Color(0xFFFFB400);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
      decoration: BoxDecoration(color: color.withValues(alpha: .16), borderRadius: BorderRadius.circular(99)),
      child: Text(it.owned ? '✓ Acheté' : (it.isFree ? 'Gratuit' : '🪙 ${it.sound?.unitPrice ?? ArtistSoundPricing.price}'), style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w800)),
    );
  }

  // ── Lecteur réduit ──

  Widget? _miniPlayer(AppColors c) {
    return ValueListenableBuilder<NowPlaying?>(
      valueListenable: SoundPreview.now,
      builder: (_, n, __) {
        if (n == null) return const SizedBox.shrink();
        return ValueListenableBuilder<String?>(
          valueListenable: SoundPreview.playing,
          builder: (_, playingKey, __) {
            final on = playingKey == n.key;
            return SafeArea(
              top: false,
              child: Container(
                margin: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: c.border),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .18), blurRadius: 14, offset: const Offset(0, 4))],
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 4, 4),
                    child: Row(children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 42,
                          height: 42,
                          child: n.coverUrl != null
                              ? CachedNetworkImage(imageUrl: n.coverUrl!, fit: BoxFit.cover)
                              : Container(color: c.primary.withValues(alpha: .2), child: Icon(Icons.music_note_rounded, color: c.primary)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(n.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 13.5)),
                          if (n.subtitle != null) Text(n.subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textSecondary, fontSize: 11.5)),
                        ]),
                      ),
                      IconButton(
                        onPressed: () => on ? SoundPreview.pause() : SoundPreview.resume(),
                        icon: Icon(on ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded, color: c.primary, size: 38),
                      ),
                      IconButton(
                        onPressed: () async {
                          await SoundPreview.stop();
                          SoundPreview.now.value = null;
                        },
                        icon: Icon(Icons.close_rounded, color: c.textSecondary, size: 20),
                      ),
                    ]),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(value: (_pos.inMilliseconds / _dur.inMilliseconds).clamp(0.0, 1.0), minHeight: 3, backgroundColor: c.border, valueColor: AlwaysStoppedAnimation<Color>(c.primary)),
                    ),
                  ),
                ]),
              ),
            );
          },
        );
      },
    );
  }
}
