// Éléments visuels de la musique : disque vinyle qui tourne, bras de lecture, anneau de progression.
// Le disque tourne quand le titre joue et s'arrête (sans revenir en arrière) en pause.

import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../pages/studio/artist_sound_common.dart';
import '../../services/music_queue.dart';

/// Pochette de repli : dégradé vert pour les musiques Afrolook, violet/rose pour les artistes.
class CoverFallback extends StatelessWidget {
  const CoverFallback({super.key, required this.free, this.size, this.radius = 0});
  final bool free;
  final double? size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final s = size ?? 40.0;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          colors: free ? const [Color(0xFF1FAA59), Color(0xFF0F6B38)] : const [Color(0xFF6A1B9A), Color(0xFFE91E63)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Text(free ? '🎵' : '🎤', style: TextStyle(fontSize: s * .45)),
    );
  }
}

/// Pochette carrée d'un titre (image ou repli).
class TrackCover extends StatelessWidget {
  const TrackCover({super.key, required this.track, required this.size, this.radius = 10});
  final MusicTrack track;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size,
        height: size,
        child: track.coverUrl != null && track.coverUrl!.isNotEmpty
            ? CachedNetworkImage(imageUrl: track.coverUrl!, fit: BoxFit.cover, errorWidget: (_, __, ___) => CoverFallback(free: track.kind == 'free', size: size))
            : CoverFallback(free: track.kind == 'free', size: size),
      ),
    );
  }
}

/// Disque vinyle : sillons, reflet fixe, pochette au centre qui tourne avec le disque.
class VinylDisc extends StatefulWidget {
  const VinylDisc({super.key, required this.size, required this.spinning, this.coverUrl, this.free = true, this.glow = true});
  final double size;
  final bool spinning;
  final String? coverUrl;
  final bool free;
  final bool glow;

  @override
  State<VinylDisc> createState() => _VinylDiscState();
}

class _VinylDiscState extends State<VinylDisc> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 4500));

  @override
  void initState() {
    super.initState();
    if (widget.spinning) _c.repeat();
  }

  @override
  void didUpdateWidget(VinylDisc old) {
    super.didUpdateWidget(old);
    if (widget.spinning && !_c.isAnimating) {
      _c.repeat();
    } else if (!widget.spinning && _c.isAnimating) {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    final primary = Theme.of(context).colorScheme.primary;
    return RepaintBoundary(
      child: SizedBox(
        width: s,
        height: s,
        child: Stack(alignment: Alignment.center, children: [
          if (widget.glow)
            Container(
              width: s,
              height: s,
              decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: primary.withValues(alpha: .35), blurRadius: s * .22, offset: Offset(0, s * .05), spreadRadius: -s * .04)]),
            ),
          RotationTransition(
            turns: _c,
            child: SizedBox(
              width: s,
              height: s,
              child: Stack(alignment: Alignment.center, children: [
                CustomPaint(size: Size(s, s), painter: _GroovesPainter()),
                SizedBox(
                  width: s * .36,
                  height: s * .36,
                  child: DecoratedBox(
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFF080B09), width: math.max(2, s * .02))),
                    child: ClipOval(
                      child: widget.coverUrl != null && widget.coverUrl!.isNotEmpty
                          ? CachedNetworkImage(imageUrl: widget.coverUrl!, fit: BoxFit.cover, errorWidget: (_, __, ___) => CoverFallback(free: widget.free))
                          : CoverFallback(free: widget.free),
                    ),
                  ),
                ),
                Container(
                  width: s * .06,
                  height: s * .06,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF030504), border: Border.all(color: Colors.white24, width: 1.5)),
                ),
              ]),
            ),
          ),
          IgnorePointer(child: CustomPaint(size: Size(s, s), painter: _SheenPainter())),
        ]),
      ),
    );
  }
}

class _GroovesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFF0A0E0C));
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(.7, r / 70);
    final step = math.max(1.6, r / 34);
    var i = 0;
    for (var rad = r * .40; rad < r - 1; rad += step) {
      p.color = i.isEven ? const Color(0xFF161C18) : const Color(0xFF0D120F);
      canvas.drawCircle(c, rad, p);
      i++;
    }
    canvas.drawCircle(c, r - .5, Paint()..style = PaintingStyle.stroke..strokeWidth = 1..color = Colors.white10);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SheenPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final shader = SweepGradient(
      startAngle: 0,
      endAngle: math.pi * 2,
      transform: const GradientRotation(.45),
      colors: [Colors.transparent, Colors.white.withValues(alpha: .20), Colors.transparent, Colors.transparent, Colors.white.withValues(alpha: .14), Colors.transparent],
      stops: const [0, .06, .14, .5, .6, .68],
    ).createShader(rect);
    canvas.drawCircle(rect.center, size.width / 2, Paint()..shader = shader..blendMode = BlendMode.screen);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Bras de lecture : se pose sur le disque quand ça joue, se relève en pause.
class Tonearm extends StatelessWidget {
  const Tonearm({super.key, required this.height, required this.playing});
  final double height;
  final bool playing;

  @override
  Widget build(BuildContext context) {
    final w = height * 60 / 110;
    return IgnorePointer(
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: playing ? 7 * math.pi / 180 : -26 * math.pi / 180),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutBack,
        builder: (_, angle, __) => Transform.rotate(
          angle: angle,
          alignment: const Alignment(.46, -.78), // pivot : 73 % en largeur, 11 % en hauteur
          child: CustomPaint(size: Size(w, height), painter: _ArmPainter()),
        ),
      ),
    );
  }
}

class _ArmPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 60, sy = size.height / 110;
    canvas.save();
    canvas.scale(sx, sy);
    canvas.drawShadow(Path()..moveTo(44, 12)..lineTo(31, 89), Colors.black54, 3, false);
    canvas.drawCircle(const Offset(44, 12), 9, Paint()..color = const Color(0xFF26302B));
    canvas.drawCircle(const Offset(44, 12), 9, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.5..color = const Color(0xFF6C7A72));
    canvas.drawCircle(const Offset(44, 12), 3.5, Paint()..color = const Color(0xFF9FB0A7));
    canvas.drawLine(const Offset(44, 12), const Offset(31, 89), Paint()..color = const Color(0xFFB8C4BD)..strokeWidth = 3.5..strokeCap = StrokeCap.round);
    canvas.save();
    canvas.translate(30, 93);
    canvas.rotate(14 * math.pi / 180);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-8, -6, 17, 12), const Radius.circular(3)), Paint()..color = const Color(0xFFDFE8E3));
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Disque du titre en cours : tourne quand CE titre joue.
class TrackDisc extends StatelessWidget {
  const TrackDisc({super.key, required this.track, required this.size, this.glow = true});
  final MusicTrack track;
  final double size;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: SoundPreview.playing,
      builder: (_, now, __) => VinylDisc(size: size, spinning: now == track.key, coverUrl: track.coverUrl, free: track.kind == 'free', glow: glow),
    );
  }
}

/// Anneau de progression autour d'un disque : avancement du titre en cours (position / durée du fichier lu).
class ProgressRing extends StatelessWidget {
  const ProgressRing({super.key, required this.size, required this.color, this.track, this.stroke = 3, this.child, this.endedColor});
  final double size;
  final Color color;
  final Color? endedColor;
  final double stroke;
  final MusicTrack? track;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(alignment: Alignment.center, children: [
        StreamBuilder<Duration>(
          stream: SoundPreview.position,
          builder: (_, p) => StreamBuilder<Duration>(
            stream: SoundPreview.duration,
            builder: (_, d) {
              final total = d.data?.inMilliseconds ?? 0;
              final v = total > 0 ? ((p.data?.inMilliseconds ?? 0) / total).clamp(0.0, 1.0) : 0.0;
              return ValueListenableBuilder<bool>(
                valueListenable: MusicQueue.previewEnded,
                builder: (_, ended, __) => CustomPaint(
                  size: Size(size, size),
                  painter: _RingPainter(ended ? 1.0 : v, ended ? (endedColor ?? color) : color, Theme.of(context).dividerColor, stroke),
                ),
              );
            },
          ),
        ),
        if (child != null) child!,
      ]),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.v, this.color, this.track, this.stroke);
  final double v;
  final Color color;
  final Color track;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset(stroke / 2, stroke / 2) & Size(size.width - stroke, size.height - stroke);
    canvas.drawArc(rect, 0, math.pi * 2, false, Paint()..style = PaintingStyle.stroke..strokeWidth = stroke..color = track);
    if (v > 0) canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * v, false, Paint()..style = PaintingStyle.stroke..strokeWidth = stroke..strokeCap = StrokeCap.round..color = color);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.v != v || old.color != color;
}
