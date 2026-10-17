// Musique dans le fil : trois présentations qui reviennent de temps en temps, à des endroits différents (jamais figées en haut) :
//  - [FeedSoundCard]     l'affiche : pochette plein cadre, disque vinyle qui déborde, bouton « Post avec ce son » ;
//  - [FeedSoundCarousel] « Sons du moment » : pochettes dont le disque sort, avec lecture et « Post » ;
//  - [FeedSoundList]     « Top 5 du pays » : classement, chaque ligne avec « Post » et lecture.
// Un toucher sur « lecture » lance la file : le lecteur flottant prend le relais, avec suivant et aléatoire.
// Aucune carte n'apparaît s'il n'y a pas de titre proposé dans le pays de la personne.

import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/music_queue.dart';
import '../../theme/app_colors.dart';
import '../../widgets/music/vinyl.dart';
import '../music/music_page.dart';
import 'artist_marketplace.dart';
import 'artist_sound_common.dart';
import 'montage/montage_music.dart';
import 'sound_countries.dart';

/// Titres proposés dans le fil (chargés une fois toutes les 10 minutes, filtrés par pays, partagés par toutes les cartes).
class _FeedSounds {
  _FeedSounds._();
  static Future<List<ArtistSound>>? _cache;
  static DateTime? _cachedAt;

  static Future<List<ArtistSound>> load() {
    final fresh = _cachedAt != null && DateTime.now().difference(_cachedAt!).inMinutes < 10;
    if (_cache != null && fresh) return _cache!;
    _cachedAt = DateTime.now();
    return _cache = FirebaseFirestore.instance
        .collection('artist_sounds')
        .where('status', isEqualTo: 'validated')
        .orderBy('validatedAt', descending: true)
        .limit(60)
        .get()
        .then((s) => [for (final d in s.docs) ArtistSound.fromMap(d.data(), d.id)].where((x) => x.previewUrl != null).toList())
        .catchError((_) => <ArtistSound>[]);
  }

  /// [count] titres pour la carte numéro [slot] : chaque carte du fil propose d'autres titres que la précédente.
  static List<ArtistSound> pick(BuildContext context, List<ArtistSound> all, int slot, int count) {
    final list = SoundCountries.forViewer<ArtistSound>(all, countries: (x) => x.availableCountries, owner: (x) => x.userId, viewerCountry: SoundCountries.viewerCountry(context));
    if (list.isEmpty) return const [];
    final n = math.min(count, list.length);
    return [for (var i = 0; i < n; i++) list[(slot * count + i) % list.length]];
  }
}

List<MusicTrack> _tracks(List<ArtistSound> l) => [for (final s in l) MusicTrack.fromSound(s)];

/// Lance (ou met en pause) un titre de la rangée ; la file enchaîne ensuite les autres titres de la rangée.
Future<void> _play(List<MusicTrack> list, int i) async {
  final t = list[i];
  if (MusicQueue.current.value?.key == t.key) {
    await MusicQueue.togglePlay();
  } else {
    await MusicQueue.play(list, i);
  }
}

Future<void> _openDetail(BuildContext context, ArtistSound s) async {
  await Navigator.push(context, MaterialPageRoute(builder: (_) => ArtistSoundDetailPage(sound: s)));
}

Future<void> _openMusic(BuildContext context) async {
  await Navigator.push(context, MaterialPageRoute(builder: (_) => const MusicPage()));
}

// ── éléments communs ────────────────────────────────────────────────────────

const _fallbackGradients = [
  [Color(0xFF6A1B9A), Color(0xFFE91E63)],
  [Color(0xFF0F6B38), Color(0xFF1FAA59)],
  [Color(0xFFFF6F00), Color(0xFFE53935)],
  [Color(0xFF1565C0), Color(0xFF00ACC1)],
  [Color(0xFF283593), Color(0xFF8E24AA)],
];

/// Pochette plein cadre ; sans pochette, un dégradé de couleur (propre à chaque titre) avec une note de musique.
class _Cover extends StatelessWidget {
  const _Cover(this.s, {this.iconSize = 56});
  final ArtistSound s;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    if (s.coverImageUrl != null) {
      return CachedNetworkImage(
        imageUrl: s.coverImageUrl!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        fadeInDuration: const Duration(milliseconds: 150),
        placeholder: (_, __) => _grad(),
        errorWidget: (_, __, ___) => _grad(),
      );
    }
    return _grad();
  }

  Widget _grad() {
    final g = _fallbackGradients[s.id.codeUnits.fold<int>(0, (a, b) => a + b) % _fallbackGradients.length];
    return Container(
      decoration: BoxDecoration(gradient: LinearGradient(colors: g, begin: Alignment.topLeft, end: Alignment.bottomRight)),
      alignment: Alignment.center,
      child: iconSize <= 0 ? null : Icon(Icons.music_note_rounded, color: Colors.white.withValues(alpha: .85), size: iconSize),
    );
  }
}

/// Prix pour utiliser le titre dans un post : « Gratuit » ou « 🪙 5 ».
Widget _priceBadge(ArtistSound s, {bool onPhoto = false}) {
  final free = s.isFree;
  final color = free ? const Color(0xFF2ECC71) : const Color(0xFFFFB400);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(color: onPhoto ? Colors.black.withValues(alpha: .45) : color.withValues(alpha: .16), borderRadius: BorderRadius.circular(99), border: onPhoto ? Border.all(color: color.withValues(alpha: .8)) : null),
    child: Text(free ? 'Gratuit' : '🪙 ${s.unitPrice}', style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w800)),
  );
}

/// Bouton rond lecture / pause d'un titre.
class _PlayDot extends StatelessWidget {
  const _PlayDot({required this.track, required this.onTap, this.size = 34, this.glass = false});
  final MusicTrack track;
  final VoidCallback onTap;
  final double size;
  final bool glass;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return ValueListenableBuilder<String?>(
      valueListenable: SoundPreview.playing,
      builder: (_, now, __) => ValueListenableBuilder<bool>(
        valueListenable: MusicQueue.loading,
        builder: (_, ld, __) {
          final on = now == track.key;
          final loading = ld && MusicQueue.current.value?.key == track.key;
          return GestureDetector(
            onTap: onTap,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(color: glass ? Colors.white.withValues(alpha: .22) : c.primary, shape: BoxShape.circle, border: glass ? Border.all(color: Colors.white30) : null),
              child: loading
                  ? Padding(padding: EdgeInsets.all(size * .28), child: CircularProgressIndicator(strokeWidth: 2, color: glass ? Colors.white : c.onPrimary))
                  : Icon(on ? Icons.pause_rounded : Icons.play_arrow_rounded, color: glass ? Colors.white : c.onPrimary, size: size * .62),
            ),
          );
        },
      ),
    );
  }
}

/// Bouton « Post » : créer un post avec ce son (dégradé vert → jaune).
class _PostPill extends StatelessWidget {
  const _PostPill({required this.sound, this.label = 'Post', this.big = false, this.expand = false});
  final ArtistSound sound;
  final String label;
  final bool big;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final h = big ? 42.0 : 30.0;
    return GestureDetector(
      onTap: () => startPostWithMusic(context, MontageMusic.artist(sound)),
      child: Container(
        height: h,
        padding: EdgeInsets.symmetric(horizontal: big ? 10 : 9),
        alignment: expand ? Alignment.center : null,
        decoration: BoxDecoration(gradient: LinearGradient(colors: [c.primary, c.accent]), borderRadius: BorderRadius.circular(big ? 12 : 99)),
        child: Row(mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.videocam_rounded, size: big ? 18 : 16, color: c.onAccent),
          const SizedBox(width: 5),
          Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.onAccent, fontWeight: FontWeight.w900, fontSize: big ? 12.5 : 11.5))),
        ]),
      ),
    );
  }
}

// ── 1. L'affiche ────────────────────────────────────────────────────────────

class FeedSoundCard extends StatefulWidget {
  const FeedSoundCard({super.key, required this.slot, this.preset});

  /// Titre fourni d'avance (tests et aperçus) : aucun chargement.
  final ArtistSound? preset;

  /// Rang de la carte dans le fil : chaque carte propose un titre différent.
  final int slot;

  @override
  State<FeedSoundCard> createState() => _FeedSoundCardState();
}

class _FeedSoundCardState extends State<FeedSoundCard> {
  ArtistSound? _sound;

  @override
  void initState() {
    super.initState();
    ArtistSoundPricing.load().then((_) {
      if (mounted) setState(() {});
    });
    if (widget.preset != null) {
      _sound = widget.preset;
      return;
    }
    _FeedSounds.load().then((all) {
      if (!mounted) return;
      final l = _FeedSounds.pick(context, all, widget.slot, 1);
      if (l.isNotEmpty) {
        MusicCache.warm(l.first.previewUrl!); // départ immédiat au toucher
        setState(() => _sound = l.first);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = _sound;
    if (s == null) return const SizedBox.shrink();
    final c = AppColors.of(context);
    final t = MusicTrack.fromSound(s);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      height: 236,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: c.border)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.black,
          child: InkWell(
            onTap: () => _openDetail(context, s),
            child: Stack(fit: StackFit.expand, children: [
              _Cover(s, iconSize: 0),
              const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x00000000), Color(0x33000000), Color(0xE6030605)], stops: [.2, .5, 1]))),
              // Disque vinyle qui déborde à droite
              Positioned(right: -52, top: 22, child: TrackDisc(track: t, size: 170)),
              Positioned(
                left: 14,
                right: 14,
                bottom: 14,
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(('NOUVEAU${s.genre != null && s.genre!.isNotEmpty ? ' · ${s.genre}' : ''}').toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.accent, fontWeight: FontWeight.w800, fontSize: 10, letterSpacing: 1.4)),
                  const SizedBox(height: 3),
                  SizedBox(
                    width: 175,
                    child: Text(s.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w900, height: 1.04, shadows: [Shadow(color: Colors.black54, blurRadius: 12)])),
                  ),
                  const SizedBox(height: 4),
                  Row(children: [
                    Flexible(child: Text('@${s.userPseudo}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFFDBE4DE), fontSize: 12))),
                    const SizedBox(width: 8),
                    _priceBadge(s, onPhoto: true),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    _PlayDot(track: t, size: 42, glass: true, onTap: () => _play([t], 0)),
                    const SizedBox(width: 8),
                    Expanded(child: _PostPill(sound: s, label: s.isFree ? 'Post avec ce son' : 'Post avec ce son · 🪙 ${s.unitPrice}', big: true, expand: true)),
                  ]),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── 2. Sons du moment (rangée) ──────────────────────────────────────────────

class FeedSoundCarousel extends StatefulWidget {
  const FeedSoundCarousel({super.key, required this.slot, this.presets});
  final int slot;

  /// Titres fournis d'avance (tests et aperçus) : aucun chargement.
  final List<ArtistSound>? presets;

  @override
  State<FeedSoundCarousel> createState() => _FeedSoundCarouselState();
}

class _FeedSoundCarouselState extends State<FeedSoundCarousel> {
  List<ArtistSound> _sounds = const [];

  @override
  void initState() {
    super.initState();
    ArtistSoundPricing.load().then((_) {
      if (mounted) setState(() {});
    });
    if (widget.presets != null) {
      _sounds = widget.presets!;
      return;
    }
    _FeedSounds.load().then((all) {
      if (!mounted) return;
      final l = _FeedSounds.pick(context, all, widget.slot, 6);
      if (l.isNotEmpty) {
        MusicQueue.warmList(_tracks(l), max: 4);
        setState(() => _sounds = l);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_sounds.isEmpty) return const SizedBox.shrink();
    final c = AppColors.of(context);
    final list = _tracks(_sounds);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
        child: Row(children: [
          Expanded(child: Text('🎵 Sons du moment', style: TextStyle(color: c.textPrimary, fontSize: 16, fontWeight: FontWeight.w900))),
          GestureDetector(onTap: () => _openMusic(context), child: Text('Voir tout', style: TextStyle(color: c.primary, fontWeight: FontWeight.w800, fontSize: 11.5))),
        ]),
      ),
      SizedBox(
        height: 226,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          scrollDirection: Axis.horizontal,
          itemCount: _sounds.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (_, i) => _CarouselTile(sound: _sounds[i], list: list, index: i),
        ),
      ),
    ]);
  }
}

class _CarouselTile extends StatelessWidget {
  const _CarouselTile({required this.sound, required this.list, required this.index});
  final ArtistSound sound;
  final List<MusicTrack> list;
  final int index;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final t = list[index];
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _openDetail(context, sound),
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: c.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            height: 98,
            child: Stack(clipBehavior: Clip.none, children: [
              Positioned(left: 46, top: 8, child: TrackDisc(track: t, size: 82, glow: false)),
              Positioned(left: 0, top: 0, child: ClipRRect(borderRadius: BorderRadius.circular(12), child: SizedBox(width: 98, height: 98, child: _Cover(sound, iconSize: 36)))),
            ]),
          ),
          const SizedBox(height: 8),
          Text(sound.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 13)),
          const SizedBox(height: 1),
          Text('@${sound.userPseudo}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textSecondary, fontSize: 11)),
          const SizedBox(height: 5),
          Align(alignment: Alignment.centerLeft, child: _priceBadge(sound)),
          const Spacer(),
          Row(children: [
            _PlayDot(track: t, size: 30, onTap: () => _play(list, index)),
            const SizedBox(width: 6),
            Expanded(child: _PostPill(sound: sound, expand: true)),
          ]),
        ]),
      ),
    );
  }
}

// ── 3. Top 5 du pays (liste) ────────────────────────────────────────────────

class FeedSoundList extends StatefulWidget {
  const FeedSoundList({super.key, required this.slot, this.presets});
  final int slot;

  /// Titres fournis d'avance (tests et aperçus) : aucun chargement.
  final List<ArtistSound>? presets;

  @override
  State<FeedSoundList> createState() => _FeedSoundListState();
}

class _FeedSoundListState extends State<FeedSoundList> {
  List<ArtistSound> _sounds = const [];

  @override
  void initState() {
    super.initState();
    ArtistSoundPricing.load().then((_) {
      if (mounted) setState(() {});
    });
    if (widget.presets != null) {
      _sounds = widget.presets!;
      return;
    }
    _FeedSounds.load().then((all) {
      if (!mounted) return;
      final l = _FeedSounds.pick(context, all, widget.slot, 5);
      if (l.isNotEmpty) {
        MusicQueue.warmList(_tracks(l), max: 3);
        setState(() => _sounds = l);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_sounds.isEmpty) return const SizedBox.shrink();
    final c = AppColors.of(context);
    final list = _tracks(_sounds);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
        child: Row(children: [
          Expanded(child: Text('🔥 Top ${_sounds.length} du pays', style: TextStyle(color: c.textPrimary, fontSize: 16, fontWeight: FontWeight.w900))),
          Text('EN DIRECT', style: TextStyle(color: c.primary, fontWeight: FontWeight.w800, fontSize: 11.5)),
        ]),
      ),
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: c.border)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(children: [
            for (var i = 0; i < _sounds.length; i++) _ListRow(sound: _sounds[i], rank: i + 1, list: list, index: i),
            InkWell(
              onTap: () => _openMusic(context),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(border: Border(top: BorderSide(color: c.border, width: .5))),
                child: Text('Ouvrir la page Musique ›', textAlign: TextAlign.center, style: TextStyle(color: c.primary, fontWeight: FontWeight.w800, fontSize: 12)),
              ),
            ),
          ]),
        ),
      ),
    ]);
  }
}

class _ListRow extends StatelessWidget {
  const _ListRow({required this.sound, required this.rank, required this.list, required this.index});
  final ArtistSound sound;
  final int rank;
  final List<MusicTrack> list;
  final int index;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final t = list[index];
    return ValueListenableBuilder<MusicTrack?>(
      valueListenable: MusicQueue.current,
      builder: (_, cur, __) {
        final on = cur?.key == t.key;
        return Container(
          decoration: BoxDecoration(color: on ? c.primary.withValues(alpha: .10) : null, border: index == 0 ? null : Border(top: BorderSide(color: c.border, width: .5))),
          child: InkWell(
            onTap: () => _openDetail(context, sound),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Row(children: [
                SizedBox(width: 16, child: Text('$rank', textAlign: TextAlign.center, style: TextStyle(color: on ? c.primary : c.textSecondary, fontWeight: FontWeight.w900, fontSize: 15))),
                const SizedBox(width: 10),
                ClipRRect(borderRadius: BorderRadius.circular(10), child: SizedBox(width: 42, height: 42, child: _Cover(sound, iconSize: 20))),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(sound.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: on ? c.primary : c.textPrimary, fontWeight: FontWeight.w800, fontSize: 13)),
                    const SizedBox(height: 2),
                    Row(children: [
                      _priceBadge(sound),
                      const SizedBox(width: 6),
                      Flexible(child: Text('@${sound.userPseudo}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textSecondary, fontSize: 11))),
                    ]),
                  ]),
                ),
                const SizedBox(width: 6),
                _PostPill(sound: sound),
                const SizedBox(width: 6),
                _PlayDot(track: t, onTap: () => _play(list, index)),
              ]),
            ),
          ),
        );
      },
    );
  }
}
