import 'package:flutter/material.dart';

/// Position par défaut d'un texte posé sur une image ou une vidéo (centre horizontal, bas du premier tiers inférieur).
const double kOverlayDefaultX = 0.5;
const double kOverlayDefaultY = 0.74;

/// Texte posé sur une chronique image ou vidéo. [x] et [y] (0 à 1) donnent le centre du texte dans l'espace disponible, ce qui
/// garde la même place sur tous les écrans. Avec [onMove], la personne le fait glisser où elle veut (création).
class ChroniqueOverlayText extends StatelessWidget {
  const ChroniqueOverlayText({super.key, required this.text, required this.x, required this.y, this.onMove});
  final String text;
  final double x;
  final double y;
  final void Function(double x, double y)? onMove;

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth;
      final h = box.maxHeight;
      final label = Container(
        padding: EdgeInsets.symmetric(horizontal: w * .035, vertical: w * .02),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: onMove != null ? .5 : .42),
          borderRadius: BorderRadius.circular(w * .035),
          border: onMove != null ? Border.all(color: Colors.white.withValues(alpha: .55), width: 1) : null,
        ),
        child: Text(
          text.trim(),
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontSize: (w * .058).clamp(13, 28).toDouble(), fontWeight: FontWeight.w800, height: 1.2),
        ),
      );
      final movable = onMove == null
          ? label
          : GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanUpdate: (d) => onMove!((x + d.delta.dx / w).clamp(0.0, 1.0), (y + d.delta.dy / h).clamp(0.0, 1.0)),
              child: label,
            );
      return IgnorePointer(
        ignoring: onMove == null,
        child: CustomSingleChildLayout(delegate: _CenterAt(x, y, w * .86), child: movable),
      );
    });
  }
}

class _CenterAt extends SingleChildLayoutDelegate {
  _CenterAt(this.x, this.y, this.maxWidth);
  final double x;
  final double y;
  final double maxWidth;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) => BoxConstraints(maxWidth: maxWidth);

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final dx = (x * size.width - childSize.width / 2).clamp(0.0, (size.width - childSize.width).clamp(0.0, double.infinity));
    final dy = (y * size.height - childSize.height / 2).clamp(0.0, (size.height - childSize.height).clamp(0.0, double.infinity));
    return Offset(dx, dy);
  }

  @override
  bool shouldRelayout(_CenterAt old) => old.x != x || old.y != y || old.maxWidth != maxWidth;
}
