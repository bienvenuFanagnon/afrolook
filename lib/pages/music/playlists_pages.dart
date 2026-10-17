// Playlists d'Afrolook : découvrir, créer, ajouter à sa bibliothèque (gratuit ou payant) et lire.
// Tout le monde voit le contenu d'une playlist. Acheter une playlist ne débloque PAS ses titres payants :
// ils restent en extrait de 30 s tant qu'ils ne sont pas achetés séparément. Cet avertissement est toujours visible.

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/authProvider.dart';
import '../../services/music_playlists.dart';
import '../../services/music_queue.dart';
import '../../theme/app_colors.dart';
import '../../widgets/music/vinyl.dart';
import '../coins/coin_recharge_screen.dart';
import '../studio/artist_marketplace.dart';
import '../studio/artist_sound_common.dart';
import '../studio/montage/montage_music.dart';

void _snack(BuildContext context, String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

String _plural(int n, String one, [String? many]) => '$n ${n > 1 ? (many ?? '${one}s') : one}';

/// Pochette d'une playlist : image du premier titre, sinon dégradé avec une icône.
class PlaylistCover extends StatelessWidget {
  const PlaylistCover({super.key, required this.playlist, required this.size, this.radius = 12});
  final MusicPlaylist playlist;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF6A1B9A), Color(0xFFE91E63)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
      child: Icon(Icons.queue_music_rounded, color: Colors.white, size: size * .46),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size,
        height: size,
        child: playlist.coverUrl != null && playlist.coverUrl!.isNotEmpty
            ? CachedNetworkImage(imageUrl: playlist.coverUrl!, fit: BoxFit.cover, errorWidget: (_, __, ___) => fallback)
            : fallback,
      ),
    );
  }
}

/// Pastille d'accès : « Gratuite » ou « 🪙 prix ».
class _AccessBadge extends StatelessWidget {
  const _AccessBadge(this.p);
  final MusicPlaylist p;

  @override
  Widget build(BuildContext context) {
    final color = p.isPaid ? const Color(0xFFFFB400) : const Color(0xFF2ECC71);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
      decoration: BoxDecoration(color: color.withValues(alpha: .16), borderRadius: BorderRadius.circular(99)),
      child: Text(p.isPaid ? '🪙 ${p.priceCoins}' : 'Gratuite', style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w800)),
    );
  }
}

// ─── Onglet « Playlists » de la page Musique ─────────────────────────────────

class PlaylistsTab extends StatelessWidget {
  const PlaylistsTab({super.key, this.preview, this.query = ''});

  /// Aperçu avec des playlists fournies d'avance (captures et tests) : aucune connexion à Firebase.
  @visibleForTesting
  final ({List<MusicPlaylist> mine, List<MusicPlaylist> discover})? preview;
  final String query;

  bool _match(MusicPlaylist p) => query.isEmpty || p.title.toLowerCase().contains(query.toLowerCase()) || p.ownerPseudo.toLowerCase().contains(query.toLowerCase());

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    if (preview != null) return _body(context, c, preview!.mine, preview!.discover, true);
    return StreamBuilder<List<MusicPlaylist>>(
      stream: MusicPlaylists.mine(),
      builder: (_, mineSnap) => StreamBuilder<List<MusicPlaylist>>(
        stream: MusicPlaylists.discover(),
        builder: (_, discSnap) => _body(context, c, mineSnap.data ?? const [], discSnap.data ?? const [], discSnap.hasData || discSnap.hasError),
      ),
    );
  }

  Widget _body(BuildContext context, AppColors c, List<MusicPlaylist> mine, List<MusicPlaylist> discover, bool loaded) {
    final myIds = {for (final p in mine) p.id};
    final others = discover.where((p) => !myIds.contains(p.id)).where(_match).toList();
    final mineShown = mine.where(_match).toList();
    return ListView(padding: const EdgeInsets.fromLTRB(12, 10, 12, 24), children: [
      _createCard(context, c),
      if (mineShown.isNotEmpty) ...[
        _title(c, 'Mes playlists'),
        for (final p in mineShown) PlaylistCard(playlist: p, preview: preview != null),
      ],
      _title(c, 'À découvrir'),
      if (!loaded) Padding(padding: const EdgeInsets.all(24), child: Center(child: CircularProgressIndicator(color: c.primary))),
      if (loaded && others.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 30),
          child: Center(child: Text('Aucune playlist pour l’instant. Crée la première !', textAlign: TextAlign.center, style: TextStyle(color: c.textSecondary))),
        ),
      for (final p in others) PlaylistCard(playlist: p, preview: preview != null),
    ]);
  }

  Widget _title(AppColors c, String t) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 18, 2, 8),
        child: Text(t, style: TextStyle(color: c.textPrimary, fontSize: 17, fontWeight: FontWeight.w900)),
      );

  Widget _createCard(BuildContext context, AppColors c) => InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PlaylistEditorPage())),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: c.primary.withValues(alpha: .45), width: 1.4),
            gradient: LinearGradient(colors: [c.primary.withValues(alpha: .12), c.accent.withValues(alpha: .08)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          ),
          child: Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(gradient: LinearGradient(colors: [c.primary, c.accent]), borderRadius: BorderRadius.circular(14)),
              child: Icon(Icons.playlist_add_rounded, color: c.onAccent, size: 26),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Crée ta playlist', style: TextStyle(color: c.textPrimary, fontSize: 16, fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text('Gratuite, ou payante : tu touches 60 % à chaque ajout.', style: TextStyle(color: c.textSecondary, fontSize: 12.5, height: 1.3)),
              ]),
            ),
            Icon(Icons.chevron_right_rounded, color: c.textSecondary),
          ]),
        ),
      );
}

class PlaylistCard extends StatelessWidget {
  const PlaylistCard({super.key, required this.playlist, this.preview = false});
  final MusicPlaylist playlist;
  final bool preview;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final p = playlist;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.border)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PlaylistDetailPage(playlist: p))),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(children: [
            PlaylistCover(playlist: p, size: 56),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 14)),
                const SizedBox(height: 3),
                Row(children: [
                  _AccessBadge(p),
                  if (p.hasPaidTracks) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(color: c.warning.withValues(alpha: .16), borderRadius: BorderRadius.circular(99)),
                      child: Text('${p.paidCount} payant${p.paidCount > 1 ? 's' : ''}', style: TextStyle(color: c.warning, fontSize: 10.5, fontWeight: FontWeight.w800)),
                    ),
                  ],
                  const SizedBox(width: 6),
                  Expanded(child: Text('${_plural(p.trackCount, 'titre')} · @${p.ownerPseudo}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textSecondary, fontSize: 11.5))),
                ]),
                if (p.streamCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text('${compactCount(p.streamCount)} écoutes', style: TextStyle(color: c.textSecondary, fontSize: 11)),
                  ),
              ]),
            ),
            Icon(Icons.chevron_right_rounded, color: c.textSecondary),
          ]),
        ),
      ),
    );
  }
}

/// Playlists de ma bibliothèque, en tête de l'onglet « Ma bibliothèque ».
class LibraryPlaylists extends StatelessWidget {
  const LibraryPlaylists({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return StreamBuilder<List<({String id, String title, int price})>>(
      stream: MusicPlaylists.library(),
      builder: (_, snap) {
        final l = snap.data ?? const [];
        if (l.isEmpty) return const SizedBox.shrink();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
            child: Text('Mes playlists ajoutées', style: TextStyle(color: c.textPrimary, fontSize: 17, fontWeight: FontWeight.w900)),
          ),
          for (final x in l)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.border)),
              child: ListTile(
                dense: true,
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF6A1B9A), Color(0xFFE91E63)]), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.queue_music_rounded, color: Colors.white, size: 22),
                ),
                title: Text(x.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 14)),
                subtitle: Text(x.price > 0 ? 'Ajoutée · 🪙 ${x.price}' : 'Ajoutée · gratuite', style: TextStyle(color: c.textSecondary, fontSize: 11.5)),
                trailing: Icon(Icons.chevron_right_rounded, color: c.textSecondary),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PlaylistDetailPage(playlistId: x.id))),
              ),
            ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 6, 2, 8),
            child: Text('Mes titres achetés', style: TextStyle(color: c.textPrimary, fontSize: 17, fontWeight: FontWeight.w900)),
          ),
        ]);
      },
    );
  }
}

// ─── Page d'une playlist ─────────────────────────────────────────────────────

class PlaylistDetailPage extends StatefulWidget {
  const PlaylistDetailPage({super.key, this.playlist, this.playlistId, this.preview});
  final MusicPlaylist? playlist;
  final String? playlistId;

  /// Aperçu sans Firebase : titres déjà chargés, et état « dans ma bibliothèque ».
  @visibleForTesting
  final ({PlaylistLoad load, bool inLibrary, bool mine})? preview;

  @override
  State<PlaylistDetailPage> createState() => _PlaylistDetailPageState();
}

class _PlaylistDetailPageState extends State<PlaylistDetailPage> {
  MusicPlaylist? _p;
  Future<PlaylistLoad>? _load;
  bool _busy = false;
  bool _notFound = false;

  @override
  void initState() {
    super.initState();
    MusicQueue.start();
    _p = widget.playlist;
    if (widget.preview != null) {
      _load = Future.value(widget.preview!.load);
    } else if (_p != null) {
      _load = MusicPlaylists.tracksOf(_p!);
      _refresh();
    } else {
      _refresh();
    }
  }

  /// Recharge la playlist (prix, titres, compteurs peuvent avoir changé).
  Future<void> _refresh() async {
    final id = widget.playlistId ?? _p?.id;
    if (id == null) return;
    final p = await MusicPlaylists.get(id);
    if (!mounted) return;
    if (p == null || p.status != 'active') {
      setState(() => _notFound = _p == null);
      return;
    }
    setState(() {
      _p = p;
      _load = MusicPlaylists.tracksOf(p);
    });
  }

  bool get _mine => widget.preview?.mine ?? _p?.isMine ?? false;

  Stream<bool> get _inLib => widget.preview != null ? Stream.value(widget.preview!.inLibrary) : MusicPlaylists.inLibrary(_p!.id);

  /// Lecture de la playlist entière autorisée : à moi, gratuite, ou ajoutée à ma bibliothèque.
  bool _canPlayAll(bool inLib) => _mine || !(_p!.isPaid) || inLib;

  Future<void> _play(PlaylistLoad l, int index, bool all) async {
    if (l.tracks.isEmpty) return;
    final t = l.tracks[index];
    if (all && MusicQueue.current.value?.key == t.key && MusicQueue.playlistId == _p!.id) {
      await MusicQueue.togglePlay();
      return;
    }
    if (all) {
      await MusicQueue.play(l.tracks, index, playlistId: _p!.id);
    } else {
      await MusicQueue.play([t], 0);
    }
  }

  Future<void> _shuffle(PlaylistLoad l) async {
    if (l.tracks.isEmpty) return;
    MusicQueue.shuffle.value = true;
    await MusicQueue.play(l.tracks, DateTime.now().millisecond % l.tracks.length, playlistId: _p!.id);
  }

  Future<void> _add() async {
    final p = _p!;
    final c = AppColors.of(context);
    if (FirebaseAuth.instance.currentUser == null) {
      _snack(context, 'Connecte-toi pour ajouter une playlist.');
      return;
    }
    if (p.isPaid) {
      final balance = Provider.of<UserAuthProvider>(context, listen: false).loginUserData.giftCoinsBalance ?? 0;
      if (balance < p.priceCoins) {
        final recharge = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: c.surface,
            title: Text('Solde insuffisant', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800)),
            content: Text('La playlist « ${p.title} » coûte ${p.priceCoins} pièces et tu en as $balance.', style: TextStyle(color: c.textSecondary, height: 1.4)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Plus tard', style: TextStyle(color: c.textSecondary))),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Recharger mes pièces')),
            ],
          ),
        );
        if (recharge == true && mounted) await Navigator.push(context, MaterialPageRoute(builder: (_) => const CoinRechargeScreen()));
        return;
      }
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: c.surface,
          title: Text('Ajouter cette playlist ?', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800)),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('« ${p.title} » · @${p.ownerPseudo}', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Text('Prix : ${p.priceCoins} pièces', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700)),
            Text('${p.ownerShare} pièces vont directement à @${p.ownerPseudo}.', style: TextStyle(color: c.textSecondary, height: 1.35)),
            const SizedBox(height: 8),
            Text('Ton solde : $balance pièces → ${balance - p.priceCoins} après.', style: TextStyle(color: c.textSecondary)),
            if (p.hasPaidTracks) ...[
              const SizedBox(height: 10),
              _noticeBox(c, '${_plural(p.paidCount, 'titre payant', 'titres payants')} dans cette playlist. Les acheter reste à ta charge : sans achat, seul l’extrait de 30 s est lu.'),
            ],
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Annuler', style: TextStyle(color: c.textSecondary))),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Ajouter (${p.priceCoins} 🪙)')),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    setState(() => _busy = true);
    try {
      final r = await MusicPlaylists.add(p.id);
      if (mounted) _snack(context, r['already'] == true ? 'Cette playlist est déjà dans ta bibliothèque.' : 'Playlist ajoutée à ta bibliothèque ✅');
      _refresh();
    } catch (e) {
      if (mounted) _snack(context, MusicPlaylists.message(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removeFromLibrary() async {
    final c = AppColors.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        title: Text('Retirer de ma bibliothèque ?', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 16)),
        content: Text(_p!.isPaid ? 'Tu ne seras pas remboursé·e : pour la réécouter en entier, il faudra la racheter.' : 'Tu pourras la rajouter quand tu veux.', style: TextStyle(color: c.textSecondary, height: 1.4)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Annuler', style: TextStyle(color: c.textSecondary))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Retirer', style: TextStyle(color: c.danger))),
        ],
      ),
    );
    if (ok != true) return;
    await MusicPlaylists.removeFromLibrary(_p!.id);
  }

  Future<void> _delete() async {
    final c = AppColors.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        title: Text('Supprimer cette playlist ?', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 16)),
        content: Text('Elle disparaît de Découvrir. Les personnes qui l’ont déjà ajoutée ne la verront plus non plus.', style: TextStyle(color: c.textSecondary, height: 1.4)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Annuler', style: TextStyle(color: c.textSecondary))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Supprimer', style: TextStyle(color: c.danger))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await MusicPlaylists.delete(_p!.id);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) _snack(context, MusicPlaylists.message(e));
    }
  }

  Widget _noticeBox(AppColors c, String text) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: c.warning.withValues(alpha: .12), borderRadius: BorderRadius.circular(12), border: Border.all(color: c.warning.withValues(alpha: .5))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.info_outline_rounded, size: 18, color: c.warning),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(color: c.textPrimary, fontSize: 12.5, height: 1.35))),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final p = _p;
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        elevation: 0,
        iconTheme: IconThemeData(color: c.textPrimary),
        title: Text('Playlist', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w900)),
        actions: [
          if (p != null && _mine) ...[
            IconButton(
              tooltip: 'Modifier',
              icon: Icon(Icons.edit_rounded, color: c.textPrimary),
              onPressed: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => PlaylistEditorPage(playlist: p)));
                _refresh();
              },
            ),
            IconButton(tooltip: 'Supprimer', icon: Icon(Icons.delete_outline_rounded, color: c.danger), onPressed: _delete),
          ],
        ],
      ),
      body: p == null
          ? Center(child: _notFound ? Text('Cette playlist n’est plus disponible.', style: TextStyle(color: c.textSecondary)) : CircularProgressIndicator(color: c.primary))
          : StreamBuilder<bool>(
              stream: _inLib,
              builder: (_, libSnap) => FutureBuilder<PlaylistLoad>(
                future: _load,
                builder: (_, snap) => _content(c, p, snap.data, libSnap.data ?? false),
              ),
            ),
    );
  }

  Widget _content(AppColors c, MusicPlaylist p, PlaylistLoad? l, bool inLib) {
    final canAll = _canPlayAll(inLib);
    return ListView(padding: const EdgeInsets.fromLTRB(14, 6, 14, 28), children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        PlaylistCover(playlist: p, size: 104, radius: 16),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.title, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textPrimary, fontSize: 21, fontWeight: FontWeight.w900, height: 1.1)),
            const SizedBox(height: 4),
            Text('par @${p.ownerPseudo}', style: TextStyle(color: c.textSecondary, fontSize: 13)),
            const SizedBox(height: 6),
            Row(children: [
              _AccessBadge(p),
              const SizedBox(width: 8),
              Flexible(child: Text('${_plural(p.trackCount, 'titre')} · ${compactCount(p.streamCount)} écoutes', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textSecondary, fontSize: 12))),
            ]),
          ]),
        ),
      ]),
      if (p.description.isNotEmpty) ...[
        const SizedBox(height: 12),
        Text(p.description, style: TextStyle(color: c.textSecondary, fontSize: 13.5, height: 1.4)),
      ],
      if (p.hasPaidTracks) ...[
        const SizedBox(height: 12),
        _noticeBox(c, '${_plural(p.paidCount, 'titre payant', 'titres payants')} dans cette playlist. Ajouter la playlist ne les débloque pas : sans achat de chaque titre, seul l’extrait de 30 s est lu.'),
      ],
      const SizedBox(height: 14),
      // Lecture / aléatoire : réservés à la playlist ajoutée, gratuite ou à soi
      Row(children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: canAll && l != null && l.tracks.isNotEmpty ? () => _play(l, 0, true) : null,
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Lecture', style: TextStyle(fontWeight: FontWeight.w900)),
            style: FilledButton.styleFrom(backgroundColor: c.primary, foregroundColor: c.onPrimary, minimumSize: const Size(0, 46), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: canAll && l != null && l.tracks.isNotEmpty ? () => _shuffle(l) : null,
            icon: Icon(Icons.shuffle_rounded, color: canAll ? c.primary : null),
            label: Text('Aléatoire', style: TextStyle(fontWeight: FontWeight.w900, color: canAll ? c.primary : null)),
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46), side: BorderSide(color: c.primary.withValues(alpha: canAll ? .6 : .2)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          ),
        ),
      ]),
      const SizedBox(height: 10),
      if (_mine)
        _ownerBox(c, p)
      else if (inLib)
        OutlinedButton.icon(
          onPressed: _removeFromLibrary,
          icon: Icon(Icons.check_circle_rounded, color: c.primary),
          label: Text('Dans ma bibliothèque · Retirer', style: TextStyle(color: c.primary, fontWeight: FontWeight.w800)),
          style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 46), side: BorderSide(color: c.primary.withValues(alpha: .5)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
        )
      else
        FilledButton.icon(
          onPressed: _busy ? null : _add,
          icon: _busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.library_add_rounded),
          label: Text(p.isPaid ? 'Ajouter à ma bibliothèque · 🪙 ${p.priceCoins}' : 'Ajouter à ma bibliothèque · gratuit', style: const TextStyle(fontWeight: FontWeight.w900)),
          style: FilledButton.styleFrom(backgroundColor: c.accent, foregroundColor: c.onAccent, minimumSize: const Size(double.infinity, 46), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
        ),
      if (!canAll)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text('Tout le monde voit les titres et peut en écouter un à la fois. Pour lancer toute la playlist (même en quittant l’application), ajoute-la à ta bibliothèque.', style: TextStyle(color: c.textSecondary, fontSize: 12, height: 1.35)),
        ),
      const SizedBox(height: 14),
      if (l == null)
        Padding(padding: const EdgeInsets.all(24), child: Center(child: CircularProgressIndicator(color: c.primary)))
      else ...[
        for (var i = 0; i < l.tracks.length; i++) _TrackRow(track: l.tracks[i], onTap: () => _play(l, i, canAll)),
        if (l.missing > 0)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('${_plural(l.missing, 'titre')} n’${l.missing > 1 ? 'sont' : 'est'} plus disponible${l.missing > 1 ? 's' : ''} (retiré${l.missing > 1 ? 's' : ''} par ${l.missing > 1 ? 'leurs artistes' : 'son artiste'}).', style: TextStyle(color: c.textSecondary, fontSize: 12)),
          ),
      ],
    ]);
  }

  /// Pour le créateur : combien la playlist a rapporté.
  Widget _ownerBox(AppColors c, MusicPlaylist p) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.border)),
        child: Row(children: [
          Expanded(child: _ownerStat(c, '${p.addCount}', 'Ajouts')),
          Expanded(child: _ownerStat(c, compactCount(p.streamCount), 'Écoutes')),
          Expanded(child: _ownerStat(c, '🪙 ${p.earnedCoins}', p.isPaid ? 'Gagnées (60 %)' : 'Gagnées')),
        ]),
      );

  Widget _ownerStat(AppColors c, String v, String label) => Column(children: [
        Text(v, style: TextStyle(color: c.primary, fontSize: 17, fontWeight: FontWeight.w900)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: c.textSecondary, fontSize: 11)),
      ]);
}

/// Ligne d'un titre dans une playlist : pochette, titre, pastille (Gratuit · 🪙 payant · ✓ Acheté), écoutes, lecture.
class _TrackRow extends StatelessWidget {
  const _TrackRow({required this.track, required this.onTap, this.onRemove, this.handle});
  final MusicTrack track;
  final VoidCallback onTap;
  final VoidCallback? onRemove;
  final Widget? handle;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final t = track;
    return ValueListenableBuilder<Set<String>>(
      valueListenable: MusicQueue.ownedIds,
      builder: (_, owned, __) => ValueListenableBuilder<String?>(
        valueListenable: SoundPreview.playing,
        builder: (_, now, __) {
          final on = now == t.key;
          final free = t.isFree || (t.sound?.isFree ?? false);
          final mine = owned.contains(t.id) || t.owned || t.isMine;
          final color = free || mine ? const Color(0xFF2ECC71) : const Color(0xFFFFB400);
          final label = free ? 'Gratuit' : (mine ? '✓ Acheté' : '🪙 Titre payant');
          final streams = t.sound?.streamCount ?? 0;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: on ? c.primary.withValues(alpha: .1) : c.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: on ? c.primary : c.border),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                child: Row(children: [
                  TrackCover(track: t, size: 48),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: on ? c.primary : c.textPrimary, fontWeight: FontWeight.w800, fontSize: 14)),
                      const SizedBox(height: 2),
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(color: color.withValues(alpha: .16), borderRadius: BorderRadius.circular(99)),
                          child: Text(label, style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w800)),
                        ),
                        const SizedBox(width: 6),
                        Expanded(child: Text(streams > 0 ? '${t.artist} · ${compactCount(streams)} écoutes' : t.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textSecondary, fontSize: 11.5))),
                      ]),
                      if (!free && !mine)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text('Extrait de 30 s tant qu’il n’est pas acheté', style: TextStyle(color: c.textSecondary, fontSize: 10.5)),
                        ),
                    ]),
                  ),
                  if (handle != null) handle!,
                  if (onRemove != null)
                    IconButton(visualDensity: VisualDensity.compact, tooltip: 'Retirer', onPressed: onRemove, icon: Icon(Icons.remove_circle_outline_rounded, color: c.danger, size: 22))
                  else
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(color: c.primary, shape: BoxShape.circle),
                      child: Icon(on ? Icons.pause_rounded : Icons.play_arrow_rounded, color: c.onPrimary, size: 22),
                    ),
                ]),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Créer / modifier une playlist ───────────────────────────────────────────

class PlaylistEditorPage extends StatefulWidget {
  const PlaylistEditorPage({super.key, this.playlist, this.firstTrack, this.previewCatalog});
  final MusicPlaylist? playlist;

  /// Titre à mettre d'office dans la nouvelle playlist (depuis le menu « Ajouter à une playlist »).
  final MusicTrack? firstTrack;

  /// Catalogue fourni d'avance pour le sélecteur (captures et tests) : aucune connexion à Firebase.
  @visibleForTesting
  final List<MusicTrack>? previewCatalog;

  @override
  State<PlaylistEditorPage> createState() => _PlaylistEditorPageState();
}

class _PlaylistEditorPageState extends State<PlaylistEditorPage> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  bool _paid = false;
  int _price = 50;
  List<MusicTrack> _tracks = [];
  bool _loading = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.playlist;
    if (p != null) {
      _title.text = p.title;
      _desc.text = p.description;
      _paid = p.isPaid;
      _price = p.isPaid ? p.priceCoins : 50;
      _loading = true;
      MusicPlaylists.tracksOf(p, refresh: true).then((l) {
        if (mounted) {
          setState(() {
            _tracks = [...l.tracks];
            _loading = false;
          });
        }
      });
    } else if (widget.firstTrack != null) {
      _tracks = [widget.firstTrack!];
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  int get _paidTracks => _tracks.where((t) => !t.isFree && !(t.sound?.isFree ?? false)).length;

  Future<void> _pick() async {
    final chosen = await showModalBottomSheet<List<MusicTrack>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.of(context).surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => _TrackPicker(selected: _tracks, catalog: widget.previewCatalog),
    );
    if (chosen != null) setState(() => _tracks = chosen);
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.length < 2) return _snack(context, 'Donne un nom à ta playlist (2 caractères au moins).');
    if (_tracks.isEmpty) return _snack(context, 'Ajoute au moins un titre.');
    if (_paid && (_price < kPlaylistMinPrice || _price > kPlaylistMaxPrice)) return _snack(context, 'Le prix va de $kPlaylistMinPrice à $kPlaylistMaxPrice pièces.');
    setState(() => _saving = true);
    try {
      final id = await MusicPlaylists.save(
        playlistId: widget.playlist?.id,
        title: title,
        description: _desc.text.trim(),
        paid: _paid,
        price: _paid ? _price : 0,
        trackIds: [for (final t in _tracks) MusicPlaylists.ref(t)],
      );
      if (!mounted) return;
      _snack(context, widget.playlist == null ? 'Playlist créée ✅' : 'Playlist enregistrée ✅');
      if (widget.playlist == null) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => PlaylistDetailPage(playlistId: id)));
      } else {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) _snack(context, MusicPlaylists.message(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    InputDecoration deco(String hint) => InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: c.textSecondary),
          filled: true,
          fillColor: c.surface,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.border)),
        );
    final share = (_price * 60) ~/ 100;
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        elevation: 0,
        iconTheme: IconThemeData(color: c.textPrimary),
        title: Text(widget.playlist == null ? 'Nouvelle playlist' : 'Modifier la playlist', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w900)),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(14, 6, 14, 32), children: [
        TextField(controller: _title, maxLength: 60, style: TextStyle(color: c.textPrimary), decoration: deco('Nom de la playlist')),
        const SizedBox(height: 4),
        TextField(controller: _desc, maxLength: 300, maxLines: 3, minLines: 2, style: TextStyle(color: c.textPrimary), decoration: deco('Description (facultatif)')),
        const SizedBox(height: 10),
        Text('ACCÈS', style: TextStyle(color: c.textSecondary, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.1)),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(child: _accessChoice(c, false, 'Gratuite', 'Tout le monde l’ajoute sans payer')),
          const SizedBox(width: 10),
          Expanded(child: _accessChoice(c, true, 'Payante', 'Tu fixes un prix en pièces')),
        ]),
        if (_paid) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.border)),
            child: Column(children: [
              Row(children: [
                IconButton.filledTonal(onPressed: _price > kPlaylistMinPrice ? () => setState(() => _price = (_price - 10).clamp(kPlaylistMinPrice, kPlaylistMaxPrice)) : null, icon: const Icon(Icons.remove_rounded)),
                Expanded(child: Center(child: Text('🪙 $_price', style: TextStyle(color: c.textPrimary, fontSize: 26, fontWeight: FontWeight.w900)))),
                IconButton.filledTonal(onPressed: _price < kPlaylistMaxPrice ? () => setState(() => _price = (_price + 10).clamp(kPlaylistMinPrice, kPlaylistMaxPrice)) : null, icon: const Icon(Icons.add_rounded)),
              ]),
              Slider(value: _price.toDouble(), min: kPlaylistMinPrice.toDouble(), max: kPlaylistMaxPrice.toDouble(), divisions: (kPlaylistMaxPrice - kPlaylistMinPrice) ~/ 10, activeColor: c.primary, onChanged: (v) => setState(() => _price = v.round())),
              Text('Prix de $kPlaylistMinPrice à $kPlaylistMaxPrice pièces · tu touches 🪙 $share (60 %) à chaque ajout.', textAlign: TextAlign.center, style: TextStyle(color: c.textSecondary, fontSize: 12, height: 1.35)),
            ]),
          ),
        ],
        const SizedBox(height: 18),
        Row(children: [
          Expanded(child: Text('TITRES (${_tracks.length}/$kPlaylistMaxTracks)', style: TextStyle(color: c.textSecondary, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.1))),
          TextButton.icon(onPressed: _pick, icon: const Icon(Icons.add_rounded, size: 18), label: const Text('Ajouter des titres')),
        ]),
        if (_paidTracks > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: c.warning.withValues(alpha: .12), borderRadius: BorderRadius.circular(12), border: Border.all(color: c.warning.withValues(alpha: .5))),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.info_outline_rounded, size: 18, color: c.warning),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${_plural(_paidTracks, 'titre payant', 'titres payants')} : c’est signalé dans ta playlist. Ceux qui l’ajoutent doivent acheter chaque titre payant pour l’écouter en entier ; sinon seul l’extrait de 30 s est lu — même si tu l’as acheté toi-même.',
                    style: TextStyle(color: c.textPrimary, fontSize: 12.5, height: 1.35),
                  ),
                ),
              ]),
            ),
          ),
        if (_loading)
          Padding(padding: const EdgeInsets.all(24), child: Center(child: CircularProgressIndicator(color: c.primary)))
        else if (_tracks.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text('Ta playlist est vide. Ajoute des musiques gratuites ou des titres d’artistes.', textAlign: TextAlign.center, style: TextStyle(color: c.textSecondary))),
          )
        else
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            onReorderItem: (a, b) => setState(() => _tracks.insert(b, _tracks.removeAt(a))),
            children: [
              for (var i = 0; i < _tracks.length; i++)
                KeyedSubtree(
                  key: ValueKey(_tracks[i].key),
                  child: _TrackRow(
                    track: _tracks[i],
                    onTap: () {},
                    onRemove: () => setState(() => _tracks.removeAt(i)),
                    handle: ReorderableDragStartListener(index: i, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Icon(Icons.drag_handle_rounded, color: c.textSecondary))),
                  ),
                ),
            ],
          ),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: _saving ? null : _save,
          style: FilledButton.styleFrom(backgroundColor: c.primary, foregroundColor: c.onPrimary, minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          child: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(widget.playlist == null ? 'Créer la playlist' : 'Enregistrer', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
        ),
      ]),
    );
  }

  Widget _accessChoice(AppColors c, bool paid, String label, String hint) {
    final on = _paid == paid;
    return GestureDetector(
      onTap: () => setState(() => _paid = paid),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: on ? c.primary.withValues(alpha: .12) : c.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: on ? c.primary : c.border, width: on ? 1.6 : 1),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(on ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, size: 18, color: on ? c.primary : c.textSecondary),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w900, fontSize: 14)),
          ]),
          const SizedBox(height: 4),
          Text(hint, style: TextStyle(color: c.textSecondary, fontSize: 11.5, height: 1.3)),
        ]),
      ),
    );
  }
}

/// Sélecteur de titres : musiques gratuites d'Afrolook et sons d'artistes validés, avec recherche et pastille « payant ».
class _TrackPicker extends StatefulWidget {
  const _TrackPicker({required this.selected, this.catalog});
  final List<MusicTrack> selected;
  final List<MusicTrack>? catalog;

  @override
  State<_TrackPicker> createState() => _TrackPickerState();
}

class _TrackPickerState extends State<_TrackPicker> {
  late final List<MusicTrack> _chosen = [...widget.selected];
  List<MusicTrack>? _catalog;
  String _q = '';

  @override
  void initState() {
    super.initState();
    if (widget.catalog != null) {
      _catalog = widget.catalog;
    } else {
      _loadCatalog();
    }
  }

  Future<void> _loadCatalog() async {
    var sounds = <MusicTrack>[];
    try {
      final q = await FirebaseFirestore.instance.collection('artist_sounds').where('status', isEqualTo: 'validated').orderBy('validatedAt', descending: true).limit(150).get();
      sounds = [for (final d in q.docs) MusicTrack.fromSound(ArtistSound.fromMap(d.data(), d.id))].where((t) => t.previewUrl != null).toList();
    } catch (_) {}
    if (!mounted) return;
    setState(() => _catalog = [...kStudioTracks.map(MusicTrack.fromStudio), ...sounds]);
  }

  bool _has(MusicTrack t) => _chosen.any((x) => x.key == t.key);

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final all = _catalog;
    final q = _q.toLowerCase();
    final shown = (all ?? const <MusicTrack>[]).where((t) => q.isEmpty || t.title.toLowerCase().contains(q) || t.artist.toLowerCase().contains(q) || (t.genre ?? '').toLowerCase().contains(q)).toList();
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * .82,
          child: Column(children: [
            const SizedBox(height: 10),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(99))),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(children: [
                Expanded(child: Text('Choisir des titres', style: TextStyle(color: c.textPrimary, fontSize: 18, fontWeight: FontWeight.w900))),
                FilledButton(onPressed: () => Navigator.pop(context, _chosen), style: FilledButton.styleFrom(backgroundColor: c.primary, foregroundColor: c.onPrimary), child: Text('Valider (${_chosen.length})', style: const TextStyle(fontWeight: FontWeight.w900))),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                onChanged: (v) => setState(() => _q = v.trim()),
                style: TextStyle(color: c.textPrimary),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Titre, artiste, genre…',
                  hintStyle: TextStyle(color: c.textSecondary),
                  prefixIcon: Icon(Icons.search_rounded, color: c.textSecondary),
                  filled: true,
                  fillColor: c.surfaceVariant,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ),
            Expanded(
              child: all == null
                  ? Center(child: CircularProgressIndicator(color: c.primary))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                      itemCount: shown.length,
                      itemBuilder: (_, i) {
                        final t = shown[i];
                        final on = _has(t);
                        final free = t.isFree || (t.sound?.isFree ?? false);
                        return ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                          leading: TrackCover(track: t, size: 42, radius: 8),
                          title: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 14)),
                          subtitle: Text('${t.artist} · ${free ? 'Gratuit' : '🪙 Titre payant'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: free ? c.textSecondary : c.warning, fontSize: 11.5)),
                          trailing: Icon(on ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded, color: on ? c.primary : c.textSecondary),
                          onTap: () => setState(() {
                            if (on) {
                              _chosen.removeWhere((x) => x.key == t.key);
                            } else if (_chosen.length < kPlaylistMaxTracks) {
                              _chosen.add(t);
                            } else {
                              _snack(context, 'Une playlist contient $kPlaylistMaxTracks titres au plus.');
                            }
                          }),
                        );
                      },
                    ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─── « Ajouter à une playlist » depuis le menu d'un titre ─────────────────────

Future<void> showAddToPlaylistSheet(BuildContext context, MusicTrack track) async {
  final c = AppColors.of(context);
  if (FirebaseAuth.instance.currentUser == null) {
    _snack(context, 'Connecte-toi pour créer des playlists.');
    return;
  }
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: c.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (ctx) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * .7),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 10),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(99))),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Align(alignment: Alignment.centerLeft, child: Text('Ajouter « ${track.title} »', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textPrimary, fontSize: 17, fontWeight: FontWeight.w900))),
          ),
          ListTile(
            leading: Container(width: 40, height: 40, decoration: BoxDecoration(gradient: LinearGradient(colors: [c.primary, c.accent]), borderRadius: BorderRadius.circular(10)), child: Icon(Icons.add_rounded, color: c.onAccent)),
            title: Text('Nouvelle playlist', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800)),
            onTap: () {
              Navigator.pop(ctx);
              Navigator.push(context, MaterialPageRoute(builder: (_) => PlaylistEditorPage(firstTrack: track)));
            },
          ),
          Flexible(
            child: StreamBuilder<List<MusicPlaylist>>(
              stream: MusicPlaylists.mine(),
              builder: (_, snap) {
                final l = snap.data ?? const [];
                if (!snap.hasData) return Padding(padding: const EdgeInsets.all(20), child: CircularProgressIndicator(color: c.primary));
                return ListView(shrinkWrap: true, children: [
                  for (final p in l)
                    ListTile(
                      leading: PlaylistCover(playlist: p, size: 40, radius: 10),
                      title: Text(p.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800)),
                      subtitle: Text(_plural(p.trackCount, 'titre'), style: TextStyle(color: c.textSecondary, fontSize: 12)),
                      trailing: p.trackIds.contains(MusicPlaylists.ref(track)) ? Icon(Icons.check_circle_rounded, color: c.primary) : null,
                      onTap: () async {
                        final ref = MusicPlaylists.ref(track);
                        if (p.trackIds.contains(ref)) {
                          Navigator.pop(ctx);
                          _snack(context, 'Ce titre est déjà dans « ${p.title} ».');
                          return;
                        }
                        Navigator.pop(ctx);
                        try {
                          await MusicPlaylists.save(playlistId: p.id, title: p.title, description: p.description, paid: p.isPaid, price: p.priceCoins, trackIds: [...p.trackIds, ref]);
                          if (context.mounted) _snack(context, 'Ajouté à « ${p.title} » ✅');
                        } catch (e) {
                          if (context.mounted) _snack(context, MusicPlaylists.message(e));
                        }
                      },
                    ),
                ]);
              },
            ),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    ),
  );
}
