import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../utils/media_cdn.dart';
import '../../widgets/video_poster_image.dart';
import 'chroniqueform.dart';

/// Éléments visuels communs des chroniques : anneaux (fil), cartes (liste), aperçus.
/// Aucun flou ni effet coûteux : les listes restent fluides sur les téléphones modestes.

const Color kRingGreen = Color(0xFF2ECC71);
const Color kRingLime = Color(0xFFB6F04A);
const Color kRingYellow = Color(0xFFFFE14D);

/// Fond d'une chronique texte (couleur enregistrée en hexadécimal), gris sombre si illisible.
Color chroniqueBackground(Chronique c) {
  try {
    final v = c.backgroundColor;
    if (v != null && v.isNotEmpty) return Color(int.parse(v, radix: 16));
  } catch (_) {}
  return const Color(0xFF1A1A2E);
}

/// Toutes les chroniques de cette personne ont-elles déjà été vues par [uid] ?
bool chroniqueGroupSeen(List<Chronique> group, String? uid) => uid != null && group.isNotEmpty && group.every((c) => c.viewers.contains(uid));

IconData chroniqueTypeIcon(ChroniqueType t) {
  switch (t) {
    case ChroniqueType.TEXT:
      return Icons.notes_rounded;
    case ChroniqueType.IMAGE:
      return Icons.image_rounded;
    case ChroniqueType.VIDEO:
      return Icons.play_arrow_rounded;
    case ChroniqueType.AUDIO:
      return Icons.mic_rounded;
  }
}

String chroniqueTypeLabel(ChroniqueType t) {
  switch (t) {
    case ChroniqueType.TEXT:
      return 'TEXTE';
    case ChroniqueType.IMAGE:
      return 'IMAGE';
    case ChroniqueType.VIDEO:
      return 'VIDÉO';
    case ChroniqueType.AUDIO:
      return 'AUDIO';
  }
}

String chroniqueCount(int n) {
  if (n < 1000) return '$n';
  if (n < 1000000) return '${(n / 1000).toStringAsFixed(n < 10000 ? 1 : 0).replaceAll('.0', '')}K';
  return '${(n / 1000000).toStringAsFixed(1)}M';
}

/// Durée affichée d'une chronique ('0:14'), vide pour une image ou un texte.
String chroniqueDurationLabel(Chronique c) {
  if (c.type != ChroniqueType.VIDEO && c.type != ChroniqueType.AUDIO) return '';
  final s = c.type == ChroniqueType.AUDIO && c.audioEndMs != null ? ((c.audioEndMs! - (c.audioStartMs ?? 0)) / 1000).round() : c.duration;
  if (s <= 0) return '';
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

/// Remplit son espace avec l'aperçu de la chronique : texte sur sa couleur, image, aperçu de la vidéo, pochette du son.
class ChroniquePreviewFill extends StatelessWidget {
  const ChroniquePreviewFill({super.key, required this.chronique, this.textSize = 13.5, this.maxTextLines = 5});
  final Chronique chronique;
  final double textSize;
  final int maxTextLines;

  @override
  Widget build(BuildContext context) {
    final c = chronique;
    final colors = AppColors.of(context);
    switch (c.type) {
      case ChroniqueType.TEXT:
        final bg = chroniqueBackground(c);
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [bg, Color.lerp(bg, Colors.black, .45)!]),
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 40, 12, 40),
              child: Text(
                c.textContent ?? '',
                maxLines: maxTextLines,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: textSize, fontWeight: FontWeight.w800, height: 1.25),
              ),
            ),
          ),
        );
      case ChroniqueType.IMAGE:
        return CachedNetworkImage(
          imageUrl: MediaCdn.url(c.mediaUrl),
          fit: BoxFit.cover,
          memCacheWidth: 480,
          fadeInDuration: const Duration(milliseconds: 100),
          placeholder: (_, __) => ColoredBox(color: colors.shimmerBase),
          errorWidget: (_, __, ___) => ColoredBox(color: colors.shimmerBase, child: Icon(Icons.broken_image_rounded, color: colors.textSecondary)),
        );
      case ChroniqueType.VIDEO:
        return VideoPosterImage(
          cacheKey: 'chronique_${c.id}',
          posterUrl: c.posterUrl,
          videoUrl: c.mediaUrl,
          placeholder: ColoredBox(color: colors.shimmerBase, child: Icon(Icons.play_circle_fill_rounded, color: colors.accent.withValues(alpha: .8), size: 30)),
        );
      case ChroniqueType.AUDIO:
        if ((c.coverImageUrl ?? '').isNotEmpty) {
          return CachedNetworkImage(
            imageUrl: MediaCdn.url(c.coverImageUrl),
            fit: BoxFit.cover,
            memCacheWidth: 480,
            placeholder: (_, __) => const ColoredBox(color: Color(0xFF1A0A2A)),
            errorWidget: (_, __, ___) => const ColoredBox(color: Color(0xFF1A0A2A)),
          );
        }
        return const DecoratedBox(
          decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF6A4CC7), Color(0xFF2A1B6D)])),
          child: Center(child: Icon(Icons.music_note_rounded, color: Colors.white54, size: 36)),
        );
    }
  }
}

/// Avatar rond d'une personne (photo, sinon initiale).
class ChroniqueAvatar extends StatelessWidget {
  const ChroniqueAvatar({super.key, required this.imageUrl, required this.name, required this.size});
  final String imageUrl;
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [kRingGreen, kRingYellow])),
      child: Text(name.isEmpty ? '?' : name.substring(0, 1).toUpperCase(), style: TextStyle(color: const Color(0xFF07120B), fontWeight: FontWeight.w800, fontSize: size * .4)),
    );
    if (imageUrl.isEmpty) return fallback;
    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: MediaCdn.url(imageUrl),
        width: size,
        height: size,
        fit: BoxFit.cover,
        memCacheWidth: (size * 3).round(),
        placeholder: (_, __) => Container(width: size, height: size, color: colors.shimmerBase),
        errorWidget: (_, __, ___) => fallback,
      ),
    );
  }
}

// ── Anneaux ──────────────────────────────────────────────────────────────────

class _RingPainter extends CustomPainter {
  _RingPainter({required this.segments, required this.seen, required this.rotation, required this.dim}) : super();
  final int segments;
  final bool seen;
  final double rotation;
  final Color dim;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 3.4;
    final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: size.width / 2 - stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = seen
          ? LinearGradient(colors: [dim, dim.withValues(alpha: .6)]).createShader(rect)
          : SweepGradient(colors: const [kRingGreen, kRingLime, kRingYellow, kRingLime, kRingGreen], transform: GradientRotation(rotation)).createShader(rect);
    final n = segments.clamp(1, 8);
    if (n == 1) {
      canvas.drawArc(rect, 0, math.pi * 2, false, paint);
      return;
    }
    final gap = 0.22;
    final sweep = (math.pi * 2) / n - gap;
    for (var i = 0; i < n; i++) {
      canvas.drawArc(rect, -math.pi / 2 + i * (sweep + gap) + gap / 2, sweep, false, paint);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.segments != segments || old.seen != seen || old.rotation != rotation;
}

class _DashedPainter extends CustomPainter {
  _DashedPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = color;
    final r = size.width / 2 - 1;
    const dashes = 22;
    for (var i = 0; i < dashes; i++) {
      final a = i * 2 * math.pi / dashes;
      canvas.drawArc(Rect.fromCircle(center: size.center(Offset.zero), radius: r), a, math.pi * 2 / dashes * .55, false, paint);
    }
  }

  @override
  bool shouldRepaint(_DashedPainter old) => old.color != color;
}

/// Une personne dans la rangée d'anneaux : avatar, anneau (un segment par chronique, qui tourne doucement tant qu'il y a du neuf), type en pastille.
class ChroniqueRing extends StatelessWidget {
  const ChroniqueRing({super.key, required this.group, required this.seen, required this.onTap, this.spin, this.size = 68, this.label, this.addBadge = false});
  final List<Chronique> group;
  final bool seen;
  final VoidCallback onTap;
  final Animation<double>? spin;
  final double size;
  final String? label;

  /// Petit « + » sur l'anneau (ma propre chronique : ajouter une autre).
  final bool addBadge;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final first = group.first;
    final inner = size - 12;
    Widget ring = SizedBox(
      width: size,
      height: size,
      child: Stack(alignment: Alignment.center, children: [
        Positioned.fill(
          child: seen || spin == null
              ? CustomPaint(painter: _RingPainter(segments: group.length, seen: seen, rotation: 0, dim: colors.textSecondary.withValues(alpha: .55)))
              : AnimatedBuilder(
                  animation: spin!,
                  builder: (_, __) => CustomPaint(painter: _RingPainter(segments: group.length, seen: false, rotation: spin!.value * math.pi * 2, dim: Colors.grey)),
                ),
        ),
        ChroniqueAvatar(imageUrl: first.userImageUrl, name: first.userPseudo, size: inner),
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            width: 21,
            height: 21,
            decoration: BoxDecoration(color: colors.background, shape: BoxShape.circle),
            padding: const EdgeInsets.all(2),
            child: DecoratedBox(
              decoration: BoxDecoration(shape: BoxShape.circle, gradient: addBadge ? null : const LinearGradient(colors: [kRingGreen, kRingYellow]), color: addBadge ? colors.accent : null),
              child: Icon(addBadge ? Icons.add_rounded : chroniqueTypeIcon(first.type), size: 12, color: const Color(0xFF07120B)),
            ),
          ),
        ),
      ]),
    );
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: size + 4,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ring,
          const SizedBox(height: 5),
          Text(
            label ?? first.userPseudo.split('_').first,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(color: seen ? colors.textSecondary : colors.textPrimary, fontSize: 10.5, fontWeight: seen ? FontWeight.w500 : FontWeight.w700),
          ),
        ]),
      ),
    );
  }
}

/// « Moi » sans chronique active : anneau en pointillés avec un « + » pour en créer une.
class ChroniqueAddRing extends StatelessWidget {
  const ChroniqueAddRing({super.key, required this.onTap, this.size = 68, this.label = 'Ma chronique'});
  final VoidCallback onTap;
  final double size;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: size + 4,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            width: size,
            height: size,
            child: CustomPaint(
              painter: _DashedPainter(colors.textSecondary.withValues(alpha: .7)),
              child: Center(
                child: Container(
                  width: size - 14,
                  height: size - 14,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: colors.surface),
                  child: Icon(Icons.add_rounded, color: colors.primary, size: 26),
                ),
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: colors.textSecondary, fontSize: 10.5, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

class ChroniqueRingsSkeleton extends StatelessWidget {
  const ChroniqueRingsSkeleton({super.key, this.count = 6, this.size = 68});
  final int count;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return SizedBox(
      height: size + 28,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: count,
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Column(children: [
            Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, color: colors.shimmerBase)),
            const SizedBox(height: 7),
            Container(width: size - 20, height: 9, decoration: BoxDecoration(color: colors.shimmerBase, borderRadius: BorderRadius.circular(4))),
          ]),
        ),
      ),
    );
  }
}

// ── Carte de la liste ────────────────────────────────────────────────────────

/// Carte d'une personne dans la liste : aperçu de sa chronique la plus récente, pseudo, type, musique, vues et j'aime en bas.
class ChroniqueCard extends StatelessWidget {
  const ChroniqueCard({super.key, required this.group, required this.seen, required this.height, required this.onTap});
  final List<Chronique> group;
  final bool seen;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final newest = group.first;
    final colors = AppColors.of(context);
    final views = group.fold<int>(0, (a, c) => a + c.viewCount);
    final likes = group.fold<int>(0, (a, c) => a + c.likeCount + c.loveCount);
    final dur = chroniqueDurationLabel(newest);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: seen ? null : Border.all(color: colors.primary, width: 1.6),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(seen ? 18 : 16.5),
          child: Stack(fit: StackFit.expand, children: [
            ChroniquePreviewFill(chronique: newest),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x73000000), Color(0x00000000), Color(0x00000000), Color(0x99000000)], stops: [0, .34, .55, 1]),
              ),
            ),
            if (seen) Container(color: Colors.black.withValues(alpha: .18)),
            Positioned(
              top: 8,
              left: 8,
              right: 8,
              child: Row(children: [
                Container(
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)),
                  child: ChroniqueAvatar(imageUrl: newest.userImageUrl, name: newest.userPseudo, size: 24),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(newest.userPseudo, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800, shadows: [Shadow(blurRadius: 3, color: Colors.black54)])),
                ),
                if (group.length > 1)
                  Container(
                    margin: const EdgeInsets.only(right: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: .55), borderRadius: BorderRadius.circular(9)),
                    child: Text('+${group.length - 1}', style: TextStyle(color: colors.accent, fontSize: 10, fontWeight: FontWeight.w800)),
                  ),
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: .45), shape: BoxShape.circle),
                  child: Icon(chroniqueTypeIcon(newest.type), color: Colors.white, size: 12),
                ),
              ]),
            ),
            if (newest.hasMusic)
              Positioned(
                left: 8,
                right: 8,
                bottom: 38,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: .5), borderRadius: BorderRadius.circular(99)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.music_note_rounded, color: Colors.white, size: 11),
                      const SizedBox(width: 4),
                      Flexible(child: Text(newest.musicTitle ?? 'Musique', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w600))),
                    ]),
                  ),
                ),
              ),
            Positioned(
              left: 6,
              right: 6,
              bottom: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: .5), borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  const Icon(Icons.remove_red_eye_rounded, color: Colors.white, size: 11),
                  const SizedBox(width: 3),
                  Text(chroniqueCount(views), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 8),
                  const Icon(Icons.favorite_rounded, color: Colors.white, size: 11),
                  const SizedBox(width: 3),
                  Text(chroniqueCount(likes), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                  if (dur.isNotEmpty) ...[const Spacer(), Text(dur, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700))],
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
