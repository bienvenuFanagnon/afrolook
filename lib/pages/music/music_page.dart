// Page Musique d'Afrolook : écouter, aimer et utiliser les musiques gratuites d'Afrolook et les sons des artistes.
// Onglets : Pour toi · Gratuites · Artistes · Playlists · Ma bibliothèque · Favoris. Thèmes clair et sombre (AppColors).
// Dans « Pour toi », la carte « en lecture » (disque vinyle) fait office de lecteur ; dans les autres onglets, le lecteur flottant reste visible.
// Chaque ligne a son bouton « Post » (créer un post avec ce son) et son bouton lecture ; la file d'attente enchaîne les titres.

import 'package:afrotok/services/read_meter.dart';
import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../../ads/ad_slot.dart';
import '../../ads/music_ads.dart';
import '../../providers/authProvider.dart';
import '../../services/music_queue.dart';
import '../../services/offline_music_service.dart';
import '../../utils/media_cdn.dart';
import '../../widgets/music/music_overlay.dart';
import '../../widgets/music/streams_text.dart';
import '../../widgets/music/vinyl.dart';
import '../pub/afrolook_inline_ad.dart';
import '../../theme/app_colors.dart';
import '../studio/artist_marketplace.dart';
import '../studio/artist_sound_common.dart';
import '../studio/sound_countries.dart';
import '../studio/montage/montage_music.dart';
import 'music_favorites.dart';
import 'playlists_pages.dart';
import '../../services/music_playlists.dart';

class MusicPage extends StatefulWidget {
  const MusicPage({super.key, this.preview, this.previewPlaylists});

  /// Aperçu avec des titres fournis d'avance (captures d'écran et tests) : aucune connexion à Firebase.
  @visibleForTesting
  final ({List<MusicTrack> sounds, List<MusicTrack> free})? preview;

  /// Playlists de l'aperçu (onglet Playlists).
  @visibleForTesting
  final ({List<MusicPlaylist> mine, List<MusicPlaylist> discover})? previewPlaylists;

  @override
  State<MusicPage> createState() => _MusicPageState();
}

class _MusicPageState extends State<MusicPage> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 6, vsync: this);
  final _search = TextEditingController();
  bool _searching = false;
  String _q = '';
  bool _hidingOverlay = false;

  @override
  void initState() {
    super.initState();
    MusicQueue.start();
    if (widget.preview == null) {
      MusicFavorites.start();
      OfflineMusic.refresh();
      ArtistSoundPricing.load().then((_) {
        if (mounted) setState(() {});
      });
    }
    // Le lecteur flottant est masqué dans « Pour toi » (la carte « en lecture » le remplace), visible dans les autres onglets.
    _tabs.addListener(_syncOverlay);
    _syncOverlay();
  }

  bool _routeCurrent = true;

  void _syncOverlay() {
    // « Pour toi » a son propre lecteur (le disque) : le lecteur flottant n'y est masqué que si la page est celle qu'on voit.
    // Quand une autre page s'ouvre par-dessus (fiche d'un titre, éditeur, fil…), la capsule revient.
    final hide = _tabs.index == 0 && _routeCurrent;
    if (hide == _hidingOverlay) return;
    _hidingOverlay = hide;
    MusicOverlay.hidden.value = (MusicOverlay.hidden.value + (hide ? 1 : -1)).clamp(0, 99);
  }

  @override
  void dispose() {
    if (_hidingOverlay) {
      final v = MusicOverlay.hidden.value - 1;
      WidgetsBinding.instance.addPostFrameCallback((_) => MusicOverlay.hidden.value = (v < 0 ? 0 : v));
    }
    _tabs.removeListener(_syncOverlay);
    _tabs.dispose();
    _search.dispose();
    // La musique continue quand on quitte la page (lecteur flottant, notification et écran verrouillé).
    super.dispose();
  }

  // ── Lecture ──

  /// Lit [list] à partir de [index] : la file enchaîne ensuite les titres de la liste (ou au hasard).
  Future<void> _playFrom(List<MusicTrack> list, int index) async {
    final t = list[index];
    if (MusicQueue.current.value?.key == t.key) {
      await MusicQueue.togglePlay();
      return;
    }
    await MusicQueue.play(list, index);
  }

  /// Droit de télécharger : titre acheté, gratuit d'un artiste, ou à soi.
  bool _canDownload(MusicTrack t) {
    if (!OfflineMusic.supported || !t.isArtist) return false;
    return MusicQueue.isOwned(t) || t.isMine || (t.sound?.isFree ?? false);
  }

  Future<void> _download(MusicTrack it) async {
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

  Future<void> _removeDownload(MusicTrack it) async {
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
    if (SoundPreview.now.value?.key == it.key) await MusicQueue.close();
    await OfflineMusic.remove(it.id);
  }

  /// Titre payant pas encore acheté : l'écouter en entier, une fois, après une pub récompensée.
  Future<void> _playWithAd(MusicTrack it) async {
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
    final r = await MusicAds.listenWithAd(it.id, userId: FirebaseAuth.instance.currentUser?.uid ?? '');
    if (!mounted) return;
    if (r.outcome != MusicAdOutcome.ok || r.url == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(MusicAds.message(r.outcome))));
      return;
    }
    await MusicQueue.playGranted(it, r.url!);
  }

  bool _canListenWithAd(MusicTrack it) =>
      it.isArtist &&
      it.sound != null &&
      !it.sound!.isFree &&
      !MusicQueue.isOwned(it) &&
      !it.isMine &&
      MusicAds.canOfferRewarded(context.read<UserAuthProvider>().loginUserData);

  /// Le son (document artist_sounds) d'un titre qui n'a que son identifiant (bibliothèque).
  Future<ArtistSound?> _soundOf(MusicTrack it) async {
    if (it.sound != null) return it.sound;
    try {
      final d = await FirebaseFirestore.instance.collection('artist_sounds').doc(it.id).getM('music_page.dart:203');
      if (!d.exists || d.data()!['status'] != 'validated') {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ce titre n’est plus disponible.')));
        return null;
      }
      return ArtistSound.fromMap(d.data()!, d.id);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chargement impossible. Vérifie ta connexion.')));
      return null;
    }
  }

  Future<void> _create(MusicTrack it, {bool ownVideo = false}) async {
    MontageMusic? music = it.sound != null ? MontageMusic.artist(it.sound!) : (it.studio != null ? MontageMusic.free(it.studio!) : null);
    if (music == null) {
      final s = await _soundOf(it);
      if (s == null || !mounted) return;
      music = MontageMusic.artist(s);
    }
    startPostWithMusic(context, music, ownVideo: ownVideo);
  }

  void _open(MusicTrack it, List<MusicTrack> list) async {
    if (it.sound == null && it.studio == null) {
      openArtistSoundById(context, it.id);
      return;
    }
    if (it.sound == null) {
      _playFrom(list, list.indexWhere((x) => x.key == it.key).clamp(0, list.length - 1));
      return;
    }
    await Navigator.push(context, MaterialPageRoute(builder: (_) => ArtistSoundDetailPage(sound: it.sound!)));
  }

  bool _match(MusicTrack it) {
    if (_q.isEmpty) return true;
    final q = _q.toLowerCase();
    return it.title.toLowerCase().contains(q) || it.artist.toLowerCase().contains(q) || (it.genre ?? '').toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final current = ModalRoute.of(context)?.isCurrent ?? true;
    if (current != _routeCurrent) {
      _routeCurrent = current;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _syncOverlay();
      });
    }
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
                decoration: InputDecoration(hintText: 'Titre, artiste, genre…', hintStyle: TextStyle(color: c.textSecondary), border: InputBorder.none),
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
          tabs: const [Tab(text: 'Pour toi'), Tab(text: 'Gratuites'), Tab(text: 'Artistes'), Tab(text: 'Playlists'), Tab(text: 'Ma bibliothèque'), Tab(text: 'Favoris')],
        ),
      ),
      body: widget.preview != null
          ? _tabsView(c, widget.preview!.sounds, widget.preview!.free, const [], false)
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('artist_sounds').where('status', isEqualTo: 'validated').orderBy('validatedAt', descending: true).limit(150).snapshotsM('music_page.dart:299'),
              builder: (_, snap) {
                final loading = !snap.hasData && !snap.hasError;
                // Titres proposés dans le pays de la personne (ou à tous) ; ceux visés pour son pays passent devant
                final sounds = SoundCountries.forViewer<ArtistSound>(
                  [for (final d in snap.data?.docs ?? const <QueryDocumentSnapshot>[]) ArtistSound.fromMap(d.data() as Map<String, dynamic>, d.id)].where((s) => s.previewUrl != null),
                  countries: (s) => s.availableCountries,
                  owner: (s) => s.userId,
                  viewerCountry: SoundCountries.viewerCountry(context),
                ).map((s) => MusicTrack.fromSound(s)).toList();
                final free = kStudioTracks.map(MusicTrack.fromStudio).toList();
                WidgetsBinding.instance.addPostFrameCallback((_) => MusicQueue.warmList([...sounds, ...free]));
                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseAuth.instance.currentUser == null ? null : FirebaseFirestore.instance.collection('MusicLibrary').where('uid', isEqualTo: FirebaseAuth.instance.currentUser!.uid).snapshotsM('music_page.dart:312'),
                  builder: (_, libSnap) {
                    final libDocs = [for (final d in libSnap.data?.docs ?? const <QueryDocumentSnapshot>[]) d.data() as Map<String, dynamic>]
                      ..sort((a, b) => ((b['createdAt'] as num?) ?? 0).compareTo((a['createdAt'] as num?) ?? 0));
                    final library = libDocs.map((d) => MusicTrack.fromLibrary(d, cover: d['coverImageUrl'] == null ? null : MediaCdn.url(d['coverImageUrl'] as String))).toList();
                    return _tabsView(c, sounds, free, library, loading);
                  },
                );
              },
            ),
      bottomNavigationBar: widget.preview == null && MediaQuery.of(context).size.height >= 700
          ? AdSlot(key: const ValueKey('music_banner'), kind: AdSlotKind.musicBanner, own: () => const AfrolookInlineAd(compact: true), admobFirst: true)
          : null,
    );
  }

  Widget _tabsView(AppColors c, List<MusicTrack> sounds, List<MusicTrack> free, List<MusicTrack> library, bool loading) {
    return ValueListenableBuilder<Set<String>>(
      valueListenable: MusicFavorites.keys,
      builder: (_, favs, __) {
        final all = [...sounds, ...free];
        final favItems = all.where((i) => favs.contains('${i.kind}:${i.id}')).toList();
        return TabBarView(controller: _tabs, children: [
          _forYou(c, sounds, free, loading),
          _list(c, [...free, ...sounds.where((s) => s.isFree)].where(_match).toList(), 'Aucune musique gratuite trouvée.'),
          _list(c, sounds.where(_match).toList(), loading ? '' : 'Aucun son d’artiste pour l’instant.', loading: loading, artistsCta: true),
          PlaylistsTab(preview: widget.previewPlaylists ?? (widget.preview != null ? (mine: const [], discover: const []) : null), query: _q),
          _list(c, library.where(_match).toList(), 'Achète un titre : il reste ici, lisible en entier dans Afrolook.', header: widget.preview == null ? const LibraryPlaylists() : null),
          _list(c, favItems.where(_match).toList(), 'Touche le ♡ d’un titre pour le retrouver ici.'),
        ]);
      },
    );
  }

  // ── Onglets ──

  Widget _forYou(AppColors c, List<MusicTrack> sounds, List<MusicTrack> free, bool loading) {
    final all = [...sounds, ...free];
    if (_q.isNotEmpty) return _list(c, all.where(_match).toList(), 'Aucun résultat.');
    return ListView(padding: const EdgeInsets.fromLTRB(12, 10, 12, 24), children: [
      // Carte « en lecture » (disque) ; sans lecture, carte d'accueil « Mix » qui lance l'aléatoire
      ValueListenableBuilder<MusicTrack?>(
        valueListenable: MusicQueue.current,
        builder: (_, t, __) => t == null ? _mix(c, all) : _NowHero(track: t, onOpen: () => _open(t, all), onBuy: _afterBuy),
      ),
      if (sounds.isNotEmpty) ...[
        _section(c, '🎤 Nouveautés des artistes'),
        SizedBox(
          height: 166,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: min(10, sounds.length),
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) => _railCard(c, sounds, i),
          ),
        ),
      ],
      _artistCta(c),
      _section(c, '🎵 Musiques Afrolook'),
      for (var i = 0; i < min(8, free.length); i++) _row(c, free.take(8).toList(), i),
      const SizedBox(height: 10),
      Center(child: TextButton(onPressed: () => _tabs.animateTo(1), child: Text('Voir toutes les musiques gratuites', style: TextStyle(color: c.primary, fontWeight: FontWeight.w800)))),
      if (loading) Padding(padding: const EdgeInsets.all(16), child: Center(child: CircularProgressIndicator(color: c.primary))),
    ]);
  }

  Future<void> _afterBuy(MusicTrack t) async {
    final s = t.sound;
    if (s == null) return;
    final ok = await buyTrack(context, s);
    if (ok) await MusicQueue.playTrack(MusicTrack.fromSound(s, owned: true), interstitial: false);
  }

  Widget _mix(AppColors c, List<MusicTrack> all) => Container(
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
            onPressed: all.isEmpty
                ? null
                : () {
                    MusicQueue.shuffle.value = true;
                    MusicQueue.play(all, Random().nextInt(all.length));
                  },
            icon: const Icon(Icons.shuffle_rounded, size: 18),
            label: const Text('Au hasard'),
            style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF6A1B9A)),
          ),
        ]),
      );

  Widget _railCard(AppColors c, List<MusicTrack> list, int i) {
    final t = list[i];
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _playFrom(list, i),
      child: SizedBox(
        width: 104,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Stack(children: [
            TrackCover(track: t, size: 104, radius: 14),
            Positioned(right: 6, bottom: 6, child: _playBadge(t, c)),
          ]),
          const SizedBox(height: 6),
          Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 12)),
          Text(t.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textSecondary, fontSize: 11)),
          StreamsText(track: t, color: c.textSecondary, fontSize: 10),
        ]),
      ),
    );
  }

  Widget _playBadge(MusicTrack t, AppColors c) => ValueListenableBuilder<String?>(
        valueListenable: SoundPreview.playing,
        builder: (_, now, __) => Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(color: c.primary, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .3), blurRadius: 6)]),
          child: Icon(now == t.key ? Icons.pause_rounded : Icons.play_arrow_rounded, color: c.onPrimary, size: 20),
        ),
      );

  Widget _list(AppColors c, List<MusicTrack> items, String empty, {bool loading = false, bool artistsCta = false, Widget? header}) {
    return ListView(padding: const EdgeInsets.fromLTRB(12, 10, 12, 24), children: [
      if (header != null) header,
      if (artistsCta) _artistCta(c),
      if (loading) Padding(padding: const EdgeInsets.all(24), child: Center(child: CircularProgressIndicator(color: c.primary))),
      if (!loading && items.isEmpty)
        Padding(padding: const EdgeInsets.symmetric(vertical: 40), child: Center(child: Text(empty, textAlign: TextAlign.center, style: TextStyle(color: c.textSecondary)))),
      for (var i = 0; i < items.length; i++) ...[
        _row(c, items, i),
        // Pub native tous les 6 titres (AdMob d'abord, pub Afrolook en repli ; aucune place vide, jamais pour Gold)
        if ((i + 1) % 6 == 0 && i != items.length - 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AdSlot(key: ValueKey('music_ad_$i'), kind: AdSlotKind.musicList, own: () => const AfrolookInlineAd(compact: true), admobFirst: true),
          ),
      ],
    ]);
  }

  /// Appel à l'action pour les artistes : mettre en ligne SA musique, seulement si les droits sont détenus.
  Widget _artistCta(AppColors c) => Container(
        margin: const EdgeInsets.only(top: 18, bottom: 2),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: c.surface,
          border: Border.all(color: c.primary.withValues(alpha: .45), width: 1.4),
          gradient: LinearGradient(colors: [c.primary.withValues(alpha: .12), c.accent.withValues(alpha: .08)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(gradient: LinearGradient(colors: [c.primary, c.accent]), borderRadius: BorderRadius.circular(14)),
              child: Icon(Icons.cloud_upload_rounded, color: c.onAccent, size: 26),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Mets ta musique en ligne', style: TextStyle(color: c.textPrimary, fontSize: 16, fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text('Tu touches 60 % à chaque utilisation et chaque vente, en pièces.', style: TextStyle(color: c.textSecondary, fontSize: 12.5, height: 1.3)),
              ]),
            ),
          ]),
          const SizedBox(height: 10),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.verified_user_rounded, size: 16, color: c.supportAccent),
            const SizedBox(width: 6),
            Expanded(child: Text('Seulement une musique dont tu es l’auteur ou dont tu détiens tous les droits. Tu le certifies avant l’envoi.', style: TextStyle(color: c.textSecondary, fontSize: 12, height: 1.35))),
          ]),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: FilledButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ArtistSoundSubmitPage())),
              icon: const Icon(Icons.upload_rounded, size: 20),
              label: const Text('Mettre ma musique en ligne', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5)),
              style: FilledButton.styleFrom(backgroundColor: c.primary, foregroundColor: c.onPrimary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyArtistSoundsPage())),
              child: Text('Voir mes sons et mes gains', style: TextStyle(color: c.primary, fontWeight: FontWeight.w800, fontSize: 12.5)),
            ),
          ),
        ]),
      );

  Widget _section(AppColors c, String t) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 20, 2, 8),
        child: Text(t, style: TextStyle(color: c.textPrimary, fontSize: 17, fontWeight: FontWeight.w900)),
      );

  // ── Ligne d'un titre : pochette, titre, prix, bouton « Post », lecture, menu ──

  Widget _row(AppColors c, List<MusicTrack> list, int i) {
    final it = list[i];
    return ValueListenableBuilder<Set<String>>(
      valueListenable: OfflineMusic.ids,
      builder: (_, offline, __) => ValueListenableBuilder<Set<String>>(
        valueListenable: MusicQueue.ownedIds,
        builder: (_, owned, __) => ValueListenableBuilder<String?>(
          valueListenable: SoundPreview.playing,
          builder: (_, now, __) => _rowBody(c, list, i, now == it.key, offline.contains(it.id) && it.isArtist, owned.contains(it.id) || it.owned),
        ),
      ),
    );
  }

  Widget _rowBody(AppColors c, List<MusicTrack> list, int i, bool on, bool downloaded, bool owned) {
    final it = list[i];
    final fav = MusicFavorites.isFav(it.kind, it.id);
    final current = MusicQueue.current.value?.key == it.key;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: current ? c.primary.withValues(alpha: .1) : c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: current ? c.primary : c.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _open(it, list),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 2, 8),
          child: Row(children: [
            TrackCover(track: it, size: 52),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(it.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: current ? c.primary : c.textPrimary, fontWeight: FontWeight.w800, fontSize: 14)),
                const SizedBox(height: 2),
                Row(children: [
                  _badge(it, owned),
                  if (downloaded) ...[
                    const SizedBox(width: 4),
                    Icon(Icons.download_done_rounded, size: 14, color: c.primary),
                  ],
                  const SizedBox(width: 6),
                  Expanded(child: Text(it.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textSecondary, fontSize: 11.5))),
                  const SizedBox(width: 6),
                  Flexible(child: StreamsText(track: it, color: c.textSecondary, fontSize: 10.5)),
                ]),
              ]),
            ),
            const SizedBox(width: 4),
            _postButton(c, it),
            const SizedBox(width: 6),
            ValueListenableBuilder<bool>(
              valueListenable: MusicQueue.loading,
              builder: (_, ld, __) => GestureDetector(
                onTap: () => _playFrom(list, i),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(color: c.primary, shape: BoxShape.circle),
                  child: ld && current
                      ? Padding(padding: const EdgeInsets.all(9), child: CircularProgressIndicator(strokeWidth: 2, color: c.onPrimary))
                      : Icon(on ? Icons.pause_rounded : Icons.play_arrow_rounded, color: c.onPrimary, size: 22),
                ),
              ),
            ),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert_rounded, color: c.textSecondary, size: 20),
              padding: EdgeInsets.zero,
              color: c.surface,
              onSelected: (v) {
                if (v == 'fav') MusicFavorites.toggle(it.kind, it.id, title: it.title);
                if (v == 'playlist') showAddToPlaylistSheet(context, it);
                if (v == 'create') _create(it);
                if (v == 'video') _create(it, ownVideo: true);
                if (v == 'adlisten') _playWithAd(it);
                if (v == 'open') _open(it, list);
                if (v == 'buy') _afterBuy(it);
                if (v == 'download') _download(it);
                if (v == 'undownload') _removeDownload(it);
                if (v == 'report' && it.sound != null) reportArtistSound(context, it.sound!.id, it.title);
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'fav', child: Text(fav ? '💔 Retirer des favoris' : '❤️ Ajouter aux favoris')),
                const PopupMenuItem(value: 'playlist', child: Text('📃 Ajouter à une playlist')),
                PopupMenuItem(value: 'create', child: Text(it.useCoins > 0 ? '🎬 Créer un post (${it.useCoins} 🪙)' : '🎬 Créer un post avec ce son')),
                PopupMenuItem(value: 'video', child: Text(it.useCoins > 0 ? '🎥 Ma vidéo avec ce son (${it.useCoins} 🪙)' : '🎥 Ma vidéo avec ce son')),
                if (it.saleCoins > 0 && !it.isMine && !owned) PopupMenuItem(value: 'buy', child: Text('🛒 Acheter le titre · ${it.saleCoins} 🪙')),
                if (_canListenWithAd(it)) const PopupMenuItem(value: 'adlisten', child: Text('🎧 Écouter en entier (une pub)')),
                if (_canDownload(it))
                  PopupMenuItem(value: OfflineMusic.has(it.id) ? 'undownload' : 'download', child: Text(OfflineMusic.has(it.id) ? '🗑️ Retirer du téléphone' : '⬇️ Télécharger (écouter sans internet)')),
                if (it.isArtist) const PopupMenuItem(value: 'open', child: Text('📄 Voir le titre et ses posts')),
                if (it.sound != null && !it.isMine) const PopupMenuItem(value: 'report', child: Text('🚩 Signaler')),
              ],
            ),
          ]),
        ),
      ),
    );
  }

  /// Bouton visible « Post » : créer un post avec ce son.
  Widget _postButton(AppColors c, MusicTrack it) => GestureDetector(
        onTap: () => _create(it),
        child: Container(
          height: 30,
          padding: const EdgeInsets.only(left: 8, right: 10),
          decoration: BoxDecoration(gradient: LinearGradient(colors: [c.primary, c.accent]), borderRadius: BorderRadius.circular(99)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.videocam_rounded, size: 16, color: c.onAccent),
            const SizedBox(width: 4),
            Text('Post', style: TextStyle(color: c.onAccent, fontWeight: FontWeight.w900, fontSize: 11.5)),
          ]),
        ),
      );

  Widget _badge(MusicTrack it, bool owned) {
    final free = it.isFree || (it.sound?.isFree ?? false);
    final color = free || owned ? const Color(0xFF2ECC71) : const Color(0xFFFFB400);
    final label = owned && !free ? '✓ Acheté' : (free ? 'Gratuit' : '🪙 ${it.useCoins > 0 ? it.useCoins : ArtistSoundPricing.price}');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
      decoration: BoxDecoration(color: color.withValues(alpha: .16), borderRadius: BorderRadius.circular(99)),
      child: Text(label, style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w800)),
    );
  }
}

/// Carte « en lecture » : disque vinyle qui tourne, bras de lecture, commandes, et les deux actions : utiliser dans un post / acheter.
class _NowHero extends StatelessWidget {
  const _NowHero({required this.track, required this.onOpen, required this.onBuy});
  final MusicTrack track;
  final VoidCallback onOpen;
  final Future<void> Function(MusicTrack) onBuy;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final t = track;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: c.surface,
        border: Border.all(color: c.border),
        gradient: RadialGradient(center: const Alignment(0, -.5), radius: 1.0, colors: [c.primary.withValues(alpha: .18), c.surface]),
      ),
      child: Column(children: [
        SizedBox(
          width: 190,
          height: 156,
          child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
            Positioned(left: 21, top: 4, child: TrackDisc(track: t, size: 148)),
            Positioned(
              right: 0,
              top: -6,
              child: ValueListenableBuilder<String?>(valueListenable: SoundPreview.playing, builder: (_, now, __) => Tonearm(height: 94, playing: now == t.key)),
            ),
          ]),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: onOpen,
          child: Text(t.title, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textPrimary, fontSize: 19, fontWeight: FontWeight.w900, height: 1.15)),
        ),
        const SizedBox(height: 2),
        Text('${t.artist}${t.genre != null && t.genre!.isNotEmpty ? ' · ${t.genre}' : ''}', textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textSecondary, fontSize: 12)),
        const SizedBox(height: 4),
        Center(child: StreamsText(track: t, color: c.textSecondary, fontSize: 12)),
        const SizedBox(height: 6),
        _status(c),
        const SizedBox(height: 6),
        const MusicControls(size: 1.0),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _postBtn(context, c)),
          if (t.saleCoins > 0 && !t.isMine && !MusicQueue.isOwned(t)) ...[
            const SizedBox(width: 8),
            Expanded(child: _buyBtn(c)),
          ],
        ]),
      ]),
    );
  }

  Widget _status(AppColors c) => ValueListenableBuilder<bool>(
        valueListenable: MusicQueue.previewEnded,
        builder: (_, ended, __) => ValueListenableBuilder<bool>(
          valueListenable: MusicQueue.previewMode,
          builder: (_, pv, __) {
            if (ended) return _tag(c.warning, Icons.lock_rounded, 'Extrait terminé');
            if (!pv) return const SizedBox(height: 0);
            return StreamBuilder<Duration>(
              stream: SoundPreview.position,
              builder: (_, p) => _tag(c.primary, Icons.lock_rounded, 'Extrait gratuit · encore ${(track.previewSec - (p.data?.inSeconds ?? 0)).clamp(0, track.previewSec)} s'),
            );
          },
        ),
      );

  Widget _tag(Color color, IconData icon, String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(color: color.withValues(alpha: .14), borderRadius: BorderRadius.circular(99)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 11)),
        ]),
      );

  Widget _postBtn(BuildContext context, AppColors c) => GestureDetector(
        onTap: () {
          final s = track.sound;
          if (s != null) {
            startPostWithMusic(context, MontageMusic.artist(s));
          } else if (track.studio != null) {
            startPostWithMusic(context, MontageMusic.free(track.studio!));
          } else {
            openArtistSoundById(context, track.id);
          }
        },
        child: Container(
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(gradient: LinearGradient(colors: [c.primary, c.accent]), borderRadius: BorderRadius.circular(12)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.videocam_rounded, size: 18, color: c.onAccent),
            const SizedBox(width: 6),
            Text(track.useCoins > 0 ? 'Post · ${track.useCoins} 🪙' : 'Post · Gratuit', style: TextStyle(color: c.onAccent, fontWeight: FontWeight.w900, fontSize: 12.5)),
          ]),
        ),
      );

  Widget _buyBtn(AppColors c) => GestureDetector(
        onTap: () => onBuy(track),
        child: Container(
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: c.primary, borderRadius: BorderRadius.circular(12)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.library_add_rounded, size: 18, color: c.onPrimary),
            const SizedBox(width: 6),
            Text('Acheter · ${track.saleCoins} 🪙', style: TextStyle(color: c.onPrimary, fontWeight: FontWeight.w900, fontSize: 12.5)),
          ]),
        ),
      );
}

/// Commandes de la musique : aléatoire, précédent, lecture/pause, suivant.
class MusicControls extends StatelessWidget {
  const MusicControls({super.key, this.size = 1.0, this.track});
  final double size;

  /// Titre de la page (fiche d'un titre) : s'il n'est pas encore celui en cours, « lecture » le lance.
  final MusicTrack? track;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final big = 46.0 * size;
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      ValueListenableBuilder<bool>(
        valueListenable: MusicQueue.shuffle,
        builder: (_, sh, __) => IconButton(
          tooltip: 'Aléatoire',
          onPressed: MusicQueue.toggleShuffle,
          icon: Icon(Icons.shuffle_rounded, color: sh ? c.primary : c.textPrimary, size: 22 * size),
          style: IconButton.styleFrom(backgroundColor: sh ? c.primary.withValues(alpha: .16) : null),
        ),
      ),
      IconButton(tooltip: 'Précédent', onPressed: MusicQueue.previous, icon: Icon(Icons.skip_previous_rounded, color: c.textPrimary, size: 28 * size)),
      ValueListenableBuilder<String?>(
        valueListenable: SoundPreview.playing,
        builder: (_, now, __) => ValueListenableBuilder<bool>(
          valueListenable: MusicQueue.loading,
          builder: (_, ld, __) {
            final key = track?.key ?? MusicQueue.current.value?.key;
            final on = key != null && now == key;
            return GestureDetector(
              onTap: () {
                if (track != null && MusicQueue.current.value?.key != track!.key) {
                  MusicQueue.playTrack(track!);
                } else {
                  MusicQueue.togglePlay();
                }
              },
              child: Container(
                width: big,
                height: big,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(color: c.primary, shape: BoxShape.circle, boxShadow: [BoxShadow(color: c.primary.withValues(alpha: .4), blurRadius: 14, offset: const Offset(0, 4))]),
                child: ld
                    ? Padding(padding: EdgeInsets.all(big * .28), child: CircularProgressIndicator(strokeWidth: 2.5, color: c.onPrimary))
                    : Icon(on ? Icons.pause_rounded : Icons.play_arrow_rounded, color: c.onPrimary, size: big * .6),
              ),
            );
          },
        ),
      ),
      IconButton(tooltip: 'Suivant', onPressed: () => MusicQueue.next(), icon: Icon(Icons.skip_next_rounded, color: c.textPrimary, size: 28 * size)),
      const SizedBox(width: 40),
    ]);
  }
}
