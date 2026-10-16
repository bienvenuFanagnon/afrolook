// Musique dans le fil : trois présentations qui reviennent de temps en temps, à des endroits différents (jamais figées en haut) :
//  - [FeedSoundCard]     l'affiche : la pochette occupe toute la carte, lecture immédiate d'un extrait, boutons d'action ;
//  - [FeedSoundCarousel] « Musiques du moment » : rangée de pochettes verticales à faire défiler ;
//  - [FeedSoundList]     « Top titres » : liste de morceaux façon lecteur de musique (pochette, titre, durée, lecture).
// Pas de pseudo de l'artiste dans le fil. Aucune carte n'apparaît s'il n'y a pas de titre proposé dans le pays de la personne.

import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
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

String _mmss(int ms) {
  if (ms <= 0) return '';
  final s = (ms / 1000).round();
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

Future<void> _openDetail(BuildContext context, ArtistSound s) async {
  await SoundPreview.stop();
  if (context.mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => ArtistSoundDetailPage(sound: s)));
}

Future<void> _openMusic(BuildContext context) async {
  await SoundPreview.stop();
  if (context.mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => const MusicPage()));
}

/// Lance (ou arrête) l'extrait d'un titre depuis le fil.
Future<void> _togglePreview(BuildContext context, ArtistSound s, String key) async {
  if (SoundPreview.playing.value == key) {
    await SoundPreview.pause();
    return;
  }
  final ok = await SoundPreview.play(key, s.previewUrl!, meta: NowPlaying(key: key, title: s.title, subtitle: 'Extrait de 30 s', coverUrl: s.coverImageUrl));
  if (!ok && context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Impossible de lire ce son. Vérifie ta connexion et réessaie.')));
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
      child: Icon(Icons.music_note_rounded, color: Colors.white.withValues(alpha: .85), size: iconSize),
    );
  }
}

/// Barres d'égaliseur animées quand le titre joue.
class _Equalizer extends StatefulWidget {
  const _Equalizer({required this.color, this.height = 16});
  final Color color;
  final double height;

  @override
  State<_Equalizer> createState() => _EqualizerState();
}

class _EqualizerState extends State<_Equalizer> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
          for (var i = 0; i < 4; i++)
            Padding(
              padding: const EdgeInsets.only(right: 2.5),
              child: Container(
                width: 3.2,
                height: widget.height * (.3 + .7 * (.5 + .5 * math.sin((_c.value * 2 * math.pi) + i * 1.4)).abs()),
                decoration: BoxDecoration(color: widget.color, borderRadius: BorderRadius.circular(2)),
              ),
            ),
        ]),
      ),
    );
  }
}

Widget _priceChip(ArtistSound s, {bool dark = true}) {
  final free = s.isFree;
  final color = free ? const Color(0xFF2ECC71) : const Color(0xFFFFB400);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
    decoration: BoxDecoration(color: dark ? Colors.black.withValues(alpha: .45) : color.withValues(alpha: .16), borderRadius: BorderRadius.circular(99), border: Border.all(color: color.withValues(alpha: .8), width: .8)),
    child: Text(free ? 'Gratuit' : '🪙 ${s.unitPrice}', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900)),
  );
}

/// Bouton de lecture rond, en verre, avec le cercle d'avancement pendant l'écoute.
class _PlayGlass extends StatelessWidget {
  const _PlayGlass({required this.playKey, required this.onTap, this.size = 64, this.progress});
  final String playKey;
  final VoidCallback onTap;
  final double size;
  final ValueListenable<double>? progress;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: SoundPreview.playing,
      builder: (_, now, __) {
        final on = now == playKey;
        return GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            width: size,
            height: size,
            child: Stack(alignment: Alignment.center, children: [
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black.withValues(alpha: .42), border: Border.all(color: Colors.white.withValues(alpha: .85), width: 2)),
                child: Icon(on ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: size * .6),
              ),
              if (on && progress != null)
                ValueListenableBuilder<double>(
                  valueListenable: progress!,
                  builder: (_, v, __) => SizedBox(width: size + 6, height: size + 6, child: CircularProgressIndicator(value: v, strokeWidth: 3, color: Colors.white, backgroundColor: Colors.white24)),
                ),
            ]),
          ),
        );
      },
    );
  }
}

/// Avancement de l'extrait en cours (0 à 1) pour un titre donné.
class _Progress extends ValueNotifier<double> {
  _Progress(this.key) : super(0) {
    _p = SoundPreview.position.listen((p) {
      if (SoundPreview.playing.value == key && _dur.inMilliseconds > 0) value = (p.inMilliseconds / _dur.inMilliseconds).clamp(0.0, 1.0);
    });
    _d = SoundPreview.duration.listen((d) {
      if (d.inMilliseconds > 0) _dur = d;
    });
  }
  final String key;
  Duration _dur = const Duration(seconds: 30);
  late final StreamSubscription<Duration> _p;
  late final StreamSubscription<Duration> _d;

  @override
  void dispose() {
    _p.cancel();
    _d.cancel();
    super.dispose();
  }
}

// ── 1. L'affiche : une carte, la pochette en plein cadre ─────────────────────

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
  _Progress? _prog;

  String get _key => 'feedcard_${_sound?.id}';

  @override
  void initState() {
    super.initState();
    ArtistSoundPricing.load().then((_) {
      if (mounted) setState(() {});
    });
    if (widget.preset != null) {
      _sound = widget.preset;
      _prog = _Progress('feedcard_${widget.preset!.id}');
      return;
    }
    _FeedSounds.load().then((all) {
      if (!mounted) return;
      final l = _FeedSounds.pick(context, all, widget.slot, 1);
      if (l.isEmpty) return;
      setState(() {
        _sound = l.first;
        _prog = _Progress('feedcard_${l.first.id}');
      });
      // l'extrait est préchargé : le toucher sur ▶ démarre sans attente
      if (l.first.previewUrl != null) MusicCache.warm(l.first.previewUrl!);
    });
  }

  @override
  void dispose() {
    _prog?.dispose();
    if (SoundPreview.playing.value == _key) SoundPreview.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = _sound;
    if (s == null) return const SizedBox.shrink();
    final c = AppColors.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .22), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      clipBehavior: Clip.antiAlias,
      child: AspectRatio(
        aspectRatio: 4 / 5,
        child: Stack(fit: StackFit.expand, children: [
          // pochette en plein cadre
          GestureDetector(onTap: () => _openDetail(context, s), child: _Cover(s, iconSize: 96)),
          // voiles pour la lisibilité (haut léger, bas marqué)
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withValues(alpha: .45), Colors.transparent, Colors.transparent, Colors.black.withValues(alpha: .86)],
                  stops: const [0, .22, .45, 1],
                ),
              ),
            ),
          ),
          // en-tête : étiquette + prix
          Positioned(
            left: 14,
            right: 14,
            top: 14,
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: .45), borderRadius: BorderRadius.circular(99)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  ValueListenableBuilder<String?>(
                    valueListenable: SoundPreview.playing,
                    builder: (_, now, __) => now == _key ? const _Equalizer(color: Colors.white, height: 12) : const Icon(Icons.graphic_eq_rounded, size: 14, color: Colors.white),
                  ),
                  const SizedBox(width: 6),
                  const Text('MUSIQUE', style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w900, letterSpacing: 1.3)),
                ]),
              ),
              const Spacer(),
              _priceChip(s),
            ]),
          ),
          // grand bouton de lecture au centre
          Center(child: _PlayGlass(playKey: _key, size: 74, progress: _prog, onTap: () => _togglePreview(context, s, _key))),
          // titre et actions en bas
          Positioned(
            left: 16,
            right: 16,
            bottom: 14,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, height: 1.1, shadows: [Shadow(color: Colors.black54, blurRadius: 8)])),
              const SizedBox(height: 4),
              Text(
                [if (s.genre != null && s.genre!.isNotEmpty) s.genre!, if (_mmss(s.durationMs).isNotEmpty) _mmss(s.durationMs), if (s.postCount > 0) '🎬 ${s.postCount} post${s.postCount > 1 ? 's' : ''}'].join('  ·  '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => startPostWithSound(context, s),
                    icon: const Icon(Icons.add_circle_rounded, size: 18),
                    label: const Text('Créer un post', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5)),
                    style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  ),
                ),
                const SizedBox(width: 8),
                _roundAction(Icons.videocam_rounded, 'Ma vidéo avec ce son', () => startPostWithMusic(context, MontageMusic.artist(s), ownVideo: true)),
                const SizedBox(width: 6),
                _roundAction(Icons.library_music_rounded, 'Toute la musique', () => _openMusic(context)),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _roundAction(IconData icon, String tip, VoidCallback onTap) => Tooltip(
        message: tip,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: .18), border: Border.all(color: Colors.white54)),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
        ),
      );
}

// ── 2. « Musiques du moment » : rangée de pochettes verticales ───────────────

class FeedSoundCarousel extends StatefulWidget {
  const FeedSoundCarousel({super.key, required this.slot, this.presets});
  final int slot;

  /// Titres fournis d'avance (tests et aperçus) : aucun chargement.
  final List<ArtistSound>? presets;

  @override
  State<FeedSoundCarousel> createState() => _FeedSoundCarouselState();
}

class _FeedSoundCarouselState extends State<FeedSoundCarousel> {
  List<ArtistSound> _items = const [];

  @override
  void initState() {
    super.initState();
    ArtistSoundPricing.load();
    if (widget.presets != null) {
      _items = widget.presets!;
      return;
    }
    _FeedSounds.load().then((all) {
      if (!mounted) return;
      final l = _FeedSounds.pick(context, all, widget.slot, 6);
      if (l.length < 2) return; // une rangée d'un seul titre n'a pas de sens : l'affiche prend le relais
      setState(() => _items = l);
      MusicCache.warmAll(l.map((x) => x.previewUrl ?? '').where((u) => u.isNotEmpty), max: 4);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) return const SizedBox.shrink();
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
          child: Row(children: [
            const Text('🎵', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 6),
            Expanded(child: Text('Musiques du moment', style: TextStyle(color: c.textPrimary, fontSize: 16, fontWeight: FontWeight.w900))),
            TextButton(onPressed: () => _openMusic(context), child: Text('Tout voir', style: TextStyle(color: c.primary, fontWeight: FontWeight.w800))),
          ]),
        ),
        SizedBox(
          height: 230,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            scrollDirection: Axis.horizontal,
            itemCount: _items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) => _CarouselTile(sound: _items[i]),
          ),
        ),
      ]),
    );
  }
}

class _CarouselTile extends StatefulWidget {
  const _CarouselTile({required this.sound});
  final ArtistSound sound;

  @override
  State<_CarouselTile> createState() => _CarouselTileState();
}

class _CarouselTileState extends State<_CarouselTile> {
  late final _Progress _prog = _Progress(_key);
  String get _key => 'feedtile_${widget.sound.id}';

  @override
  void dispose() {
    _prog.dispose();
    if (SoundPreview.playing.value == _key) SoundPreview.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.sound;
    return GestureDetector(
      onTap: () => _openDetail(context, s),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          width: 158,
          child: Stack(fit: StackFit.expand, children: [
            _Cover(s, iconSize: 52),
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black.withValues(alpha: .35), Colors.transparent, Colors.black.withValues(alpha: .85)], stops: const [0, .35, 1])),
              ),
            ),
            Positioned(left: 8, top: 8, child: _priceChip(s)),
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text(s.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w900, height: 1.1)),
                    if (s.genre != null && s.genre!.isNotEmpty) Text(s.genre!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                  ]),
                ),
                const SizedBox(width: 6),
                _PlayGlass(playKey: _key, size: 40, progress: _prog, onTap: () => _togglePreview(context, s, _key)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── 3. « Top titres » : liste façon lecteur de musique ────────────────────────

class FeedSoundList extends StatefulWidget {
  const FeedSoundList({super.key, required this.slot, this.presets});
  final int slot;

  /// Titres fournis d'avance (tests et aperçus) : aucun chargement.
  final List<ArtistSound>? presets;

  @override
  State<FeedSoundList> createState() => _FeedSoundListState();
}

class _FeedSoundListState extends State<FeedSoundList> {
  List<ArtistSound> _items = const [];

  @override
  void initState() {
    super.initState();
    ArtistSoundPricing.load();
    if (widget.presets != null) {
      _items = widget.presets!;
      return;
    }
    _FeedSounds.load().then((all) {
      if (!mounted) return;
      final l = _FeedSounds.pick(context, all, widget.slot, 4);
      if (l.length < 2) return;
      setState(() => _items = l);
      MusicCache.warmAll(l.map((x) => x.previewUrl ?? '').where((u) => u.isNotEmpty), max: 4);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) return const SizedBox.shrink();
    final c = AppColors.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      padding: const EdgeInsets.fromLTRB(14, 14, 8, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [c.surface, c.primary.withValues(alpha: .10)]),
        border: Border.all(color: c.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(shape: BoxShape.circle, color: c.primary.withValues(alpha: .16)),
            child: Icon(Icons.graphic_eq_rounded, color: c.primary, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text('Top titres', style: TextStyle(color: c.textPrimary, fontSize: 17, fontWeight: FontWeight.w900))),
          TextButton(onPressed: () => _openMusic(context), child: Text('Tout voir', style: TextStyle(color: c.primary, fontWeight: FontWeight.w800))),
        ]),
        const SizedBox(height: 4),
        for (var i = 0; i < _items.length; i++) _ListRow(rank: i + 1, sound: _items[i]),
      ]),
    );
  }
}

class _ListRow extends StatefulWidget {
  const _ListRow({required this.rank, required this.sound});
  final int rank;
  final ArtistSound sound;

  @override
  State<_ListRow> createState() => _ListRowState();
}

class _ListRowState extends State<_ListRow> {
  String get _key => 'feedrow_${widget.sound.id}';

  @override
  void dispose() {
    if (SoundPreview.playing.value == _key) SoundPreview.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.sound;
    final c = AppColors.of(context);
    return ValueListenableBuilder<String?>(
      valueListenable: SoundPreview.playing,
      builder: (_, now, __) {
        final on = now == _key;
        return InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _togglePreview(context, s, _key),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
            child: Row(children: [
              SizedBox(width: 20, child: Text('${widget.rank}', textAlign: TextAlign.center, style: TextStyle(color: on ? c.primary : c.textSecondary, fontWeight: FontWeight.w900, fontSize: 14))),
              const SizedBox(width: 8),
              ClipRRect(borderRadius: BorderRadius.circular(10), child: SizedBox(width: 54, height: 54, child: _Cover(s, iconSize: 26))),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: on ? c.primary : c.textPrimary, fontSize: 15, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Row(children: [
                    if (on) ...[const _Equalizer(color: Color(0xFF2ECC71), height: 11), const SizedBox(width: 6)],
                    Flexible(
                      child: Text(
                        [if (s.genre != null && s.genre!.isNotEmpty) s.genre!, if (_mmss(s.durationMs).isNotEmpty) _mmss(s.durationMs)].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: c.textSecondary, fontSize: 12),
                      ),
                    ),
                  ]),
                ]),
              ),
              _priceChip(s, dark: false),
              IconButton(
                tooltip: 'Créer un post avec ce son',
                visualDensity: VisualDensity.compact,
                onPressed: () => startPostWithSound(context, s),
                icon: Icon(Icons.add_circle_outline_rounded, color: c.textSecondary),
              ),
              Icon(on ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded, color: c.primary, size: 38),
              const SizedBox(width: 4),
            ]),
          ),
        );
      },
    );
  }
}
