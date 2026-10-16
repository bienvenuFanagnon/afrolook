// Carte « musique » insérée dans le fil : lecture immédiate d'un extrait (comme Spotify), bouton pour créer un post
// avec ce son (modèles du Studio, son déjà choisi) et accès à la page du son avec les posts faits avec lui.
// Pas de pseudo de l'artiste dans le fil.

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'artist_marketplace.dart';
import 'artist_sound_common.dart';

class FeedSoundCard extends StatefulWidget {
  const FeedSoundCard({super.key, required this.slot});

  /// Rang de la carte dans le fil : chaque carte propose un son différent.
  final int slot;

  static Future<List<ArtistSound>>? _cache;
  static DateTime? _cachedAt;

  static Future<List<ArtistSound>> _sounds() {
    final fresh = _cachedAt != null && DateTime.now().difference(_cachedAt!).inMinutes < 10;
    if (_cache != null && fresh) return _cache!;
    _cachedAt = DateTime.now();
    return _cache = FirebaseFirestore.instance
        .collection('artist_sounds')
        .where('status', isEqualTo: 'validated')
        .orderBy('validatedAt', descending: true)
        .limit(30)
        .get()
        .then((s) => [for (final d in s.docs) ArtistSound.fromMap(d.data(), d.id)].where((x) => x.previewUrl != null).toList())
        .catchError((_) => <ArtistSound>[]);
  }

  @override
  State<FeedSoundCard> createState() => _FeedSoundCardState();
}

class _FeedSoundCardState extends State<FeedSoundCard> {
  ArtistSound? _sound;
  Duration _pos = Duration.zero;
  Duration _dur = const Duration(seconds: 30);
  StreamSubscription<Duration>? _p;
  StreamSubscription<Duration>? _d;

  String get _key => 'feedcard_${_sound?.id}';

  @override
  void initState() {
    super.initState();
    ArtistSoundPricing.load().then((_) {
      if (mounted) setState(() {});
    });
    FeedSoundCard._sounds().then((list) {
      if (!mounted || list.isEmpty) return;
      setState(() => _sound = list[widget.slot % list.length]);
    });
    _p = SoundPreview.position.listen((p) {
      if (mounted && SoundPreview.playing.value == _key) setState(() => _pos = p);
    });
    _d = SoundPreview.duration.listen((d) {
      if (mounted && d.inMilliseconds > 0) setState(() => _dur = d);
    });
  }

  @override
  void dispose() {
    _p?.cancel();
    _d?.cancel();
    if (SoundPreview.playing.value == _key) SoundPreview.stop();
    super.dispose();
  }

  Future<void> _toggle(ArtistSound s) async {
    if (SoundPreview.playing.value == _key) {
      await SoundPreview.stop();
      return;
    }
    setState(() => _pos = Duration.zero);
    final ok = await SoundPreview.play(_key, s.previewUrl!);
    if (!ok && mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Impossible de lire ce son. Vérifie ta connexion.')));
  }

  @override
  Widget build(BuildContext context) {
    final s = _sound;
    if (s == null) return const SizedBox.shrink();
    final c = AppColors.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .08), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        InkWell(
          onTap: () async {
            await SoundPreview.stop();
            if (context.mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => ArtistSoundDetailPage(sound: s)));
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 84,
                  height: 84,
                  child: s.coverImageUrl != null
                      ? CachedNetworkImage(imageUrl: s.coverImageUrl!, fit: BoxFit.cover)
                      : Container(
                          decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF6A1B9A), Color(0xFFE91E63)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
                          child: const Icon(Icons.music_note_rounded, color: Colors.white, size: 40),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(Icons.graphic_eq_rounded, size: 15, color: c.primary),
                    const SizedBox(width: 4),
                    Text('MUSIQUE', style: TextStyle(color: c.primary, fontSize: 10.5, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                    const SizedBox(width: 8),
                    _badge(s),
                  ]),
                  const SizedBox(height: 5),
                  Text(s.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textPrimary, fontSize: 16, fontWeight: FontWeight.w900, height: 1.15)),
                  if (s.genre != null && s.genre!.isNotEmpty) Text(s.genre!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textSecondary, fontSize: 12)),
                  if (s.postCount > 0) Text('🎬 ${s.postCount} post${s.postCount > 1 ? 's' : ''} créé${s.postCount > 1 ? 's' : ''}', style: TextStyle(color: c.textSecondary, fontSize: 11.5)),
                ]),
              ),
              // Lecture immédiate d'un extrait
              ValueListenableBuilder<String?>(
                valueListenable: SoundPreview.playing,
                builder: (_, now, __) => IconButton(
                  onPressed: () => _toggle(s),
                  iconSize: 52,
                  padding: EdgeInsets.zero,
                  icon: Icon(now == _key ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded, color: c.primary),
                ),
              ),
            ]),
          ),
        ),
        ValueListenableBuilder<String?>(
          valueListenable: SoundPreview.playing,
          builder: (_, now, __) {
            final on = now == _key;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(value: on ? (_pos.inMilliseconds / _dur.inMilliseconds).clamp(0.0, 1.0) : 0, minHeight: 3, backgroundColor: c.border, valueColor: AlwaysStoppedAnimation<Color>(c.primary)),
              ),
            );
          },
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Row(children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () => startPostWithSound(context, s),
                icon: const Icon(Icons.add_circle_rounded, size: 18),
                label: const Text('Créer un post avec ce son', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                style: FilledButton.styleFrom(backgroundColor: c.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () async {
                await SoundPreview.stop();
                if (context.mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => ArtistSoundDetailPage(sound: s)));
              },
              style: OutlinedButton.styleFrom(side: BorderSide(color: c.border), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: Text('Voir', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _badge(ArtistSound s) {
    final free = s.isFree;
    final color = free ? const Color(0xFF2ECC71) : const Color(0xFFFFB400);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
      decoration: BoxDecoration(color: color.withValues(alpha: .16), borderRadius: BorderRadius.circular(99)),
      child: Text(free ? 'Gratuit' : '🪙 ${ArtistSoundPricing.price}', style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w800)),
    );
  }
}
