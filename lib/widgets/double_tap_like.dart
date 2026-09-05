import 'package:flutter/material.dart';

/// Enveloppe n'importe quel widget avec un double-tap qui affiche un grand
/// cœur animé à l'endroit du toucher (style Instagram/TikTok).
///
/// Usage :
///   DoubleTapLike(
///     onDoubleTap: _handleLike,    // appelé seulement si non déjà liké
///     alreadyLiked: _isLiked,
///     child: myImageWidget,
///   )
class DoubleTapLike extends StatefulWidget {
  final Widget child;

  /// Appelé quand l'utilisateur double-tape. N'appelez PAS _handleLike si
  /// `alreadyLiked` est vrai — le double-tap ne sert qu'à liker, jamais à unliker.
  final VoidCallback onDoubleTap;

  /// Si vrai, l'animation cœur reste blanche/rouge mais on n'appelle pas onDoubleTap.
  final bool alreadyLiked;

  const DoubleTapLike({
    super.key,
    required this.child,
    required this.onDoubleTap,
    this.alreadyLiked = false,
  });

  @override
  State<DoubleTapLike> createState() => _DoubleTapLikeState();
}

class _DoubleTapLikeState extends State<DoubleTapLike>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  Offset _tapPos = Offset.zero;
  bool _show = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    // Scale : 0 → 1.35 (élastique) → 1.1 (settle) → 1.2 (fade out)
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.35)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 55,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.35, end: 1.1)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.1, end: 1.15)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 30,
      ),
    ]).animate(_ctrl);

    // Opacity : plein 65% du temps, puis fondu
    _opacity = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 62),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 38,
      ),
    ]).animate(_ctrl);

    _ctrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (mounted) setState(() => _show = false);
        _ctrl.reset();
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onDoubleTapDown(TapDownDetails d) {
    _tapPos = d.localPosition;
  }

  void _onDoubleTap() {
    if (!mounted) return;
    setState(() => _show = true);
    _ctrl.forward(from: 0);
    if (!widget.alreadyLiked) {
      widget.onDoubleTap();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTapDown: _onDoubleTapDown,
      onDoubleTap: _onDoubleTap,
      behavior: HitTestBehavior.translucent,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          widget.child,
          if (_show)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _ctrl,
                  builder: (_, __) => CustomPaint(
                    painter: _HeartPainter(
                      position: _tapPos,
                      scale: _scale.value,
                      opacity: _opacity.value,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HeartPainter extends CustomPainter {
  final Offset position;
  final double scale;
  final double opacity;

  _HeartPainter({
    required this.position,
    required this.scale,
    required this.opacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0 || scale <= 0) return;

    final center = Offset(
      position.dx.clamp(0, size.width),
      position.dy.clamp(0, size.height),
    );

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(scale);

    // Ombre douce
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: opacity * 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    _drawHeart(canvas, shadowPaint, 54, Offset(3, 4));

    // Cœur rouge
    final heartPaint = Paint()
      ..color = const Color(0xFFFF3B5C).withValues(alpha: opacity)
      ..style = PaintingStyle.fill;
    _drawHeart(canvas, heartPaint, 52, Offset.zero);

    // Reflet blanc (brillance)
    final shinePaint = Paint()
      ..color = Colors.white.withValues(alpha: opacity * 0.35)
      ..style = PaintingStyle.fill;
    _drawHeart(canvas, shinePaint, 24, const Offset(-10, -14));

    canvas.restore();
  }

  void _drawHeart(Canvas canvas, Paint paint, double size, Offset offset) {
    final path = Path();
    final s = size;
    path.moveTo(offset.dx, offset.dy + s * 0.3);
    path.cubicTo(
      offset.dx, offset.dy,
      offset.dx - s * 0.5, offset.dy,
      offset.dx - s * 0.5, offset.dy + s * 0.3,
    );
    path.cubicTo(
      offset.dx - s * 0.5, offset.dy + s * 0.6,
      offset.dx, offset.dy + s * 0.85,
      offset.dx, offset.dy + s,
    );
    path.cubicTo(
      offset.dx, offset.dy + s * 0.85,
      offset.dx + s * 0.5, offset.dy + s * 0.6,
      offset.dx + s * 0.5, offset.dy + s * 0.3,
    );
    path.cubicTo(
      offset.dx + s * 0.5, offset.dy,
      offset.dx, offset.dy,
      offset.dx, offset.dy + s * 0.3,
    );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_HeartPainter old) =>
      old.scale != scale || old.opacity != opacity || old.position != position;
}
