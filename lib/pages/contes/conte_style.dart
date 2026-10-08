import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Palette et styles de « La Case aux Contes » : parchemin, encre brune, or et braise. Identiques en thème clair et sombre
/// (c'est un livre, pas un écran de l'application).
class ConteStyle {
  ConteStyle._();
  static const night = Color(0xFF17110C);
  static const night2 = Color(0xFF241A12);
  static const parch = Color(0xFFEAD9B3);
  static const parch2 = Color(0xFFDCC79A);
  static const ink = Color(0xFF2C1D12);
  static const ink2 = Color(0xFF5A4330);
  static const gold = Color(0xFFB07A1F);
  static const gold2 = Color(0xFFE6B758);
  static const ember = Color(0xFFC4512F);
  static const green = Color(0xFF4D7A4A);

  static TextStyle title(double size, {Color color = ink, double height = 1.15}) =>
      TextStyle(fontFamily: 'CinzelDecorative', fontWeight: FontWeight.w700, fontSize: size, color: color, height: height, letterSpacing: .3);

  static TextStyle body(double size, {Color color = ink, FontWeight weight = FontWeight.w400, FontStyle style = FontStyle.normal, double height = 1.38}) =>
      TextStyle(fontFamily: 'CrimsonText', fontWeight: weight, fontStyle: style, fontSize: size, color: color, height: height);

  static TextStyle label(double size, {Color color = ink2}) =>
      TextStyle(fontFamily: 'CrimsonText', fontWeight: FontWeight.w600, fontSize: size, color: color, letterSpacing: 1.2);
}

/// Fond de parchemin : grain, fibres, bords vieillis.
class ParchmentPainter extends CustomPainter {
  const ParchmentPainter({this.seed = 3, this.base = ConteStyle.parch});
  final int seed;
  final Color base;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = base);
    final r = math.Random(seed);
    final speck = Paint();
    final count = (size.width * size.height / 520).clamp(80, 900).toInt();
    for (var i = 0; i < count; i++) {
      speck.color = Color.fromARGB(10 + r.nextInt(26), 90, 60, 20);
      canvas.drawCircle(Offset(r.nextDouble() * size.width, r.nextDouble() * size.height), .4 + r.nextDouble() * 1.1, speck);
    }
    final fiber = Paint()..color = const Color(0x16784C1E)..strokeWidth = .6..style = PaintingStyle.stroke;
    for (var i = 0; i < 26; i++) {
      final x = r.nextDouble() * size.width;
      final y = r.nextDouble() * size.height;
      canvas.drawLine(Offset(x, y), Offset(x + 10 + r.nextDouble() * 28, y + (r.nextDouble() - .5) * 6), fiber);
    }
    // taches claires et sombres
    for (var i = 0; i < 4; i++) {
      final c = Offset(r.nextDouble() * size.width, r.nextDouble() * size.height);
      final rad = 40 + r.nextDouble() * 70;
      canvas.drawCircle(
        c,
        rad,
        Paint()..shader = RadialGradient(colors: [i.isEven ? const Color(0x22FFF7DC) : const Color(0x1A8A5A22), const Color(0x00000000)]).createShader(Rect.fromCircle(center: c, radius: rad)),
      );
    }
    // bords brunis
    canvas.drawRect(
      rect,
      Paint()..shader = const RadialGradient(radius: 1.0, colors: [Color(0x00000000), Color(0x00000000), Color(0x55472A0D)], stops: [0, .62, 1]).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(ParchmentPainter old) => old.seed != seed || old.base != base;
}

class Parchment extends StatelessWidget {
  const Parchment({super.key, this.seed = 3, this.child, this.radius = 0, this.base = ConteStyle.parch});
  final int seed;
  final Widget? child;
  final double radius;
  final Color base;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: CustomPaint(painter: ParchmentPainter(seed: seed, base: base), child: child),
    );
  }
}

/// Bande de motifs inspirés du bogolan : zigzags dorés sur fond d'encre.
class BogolanBand extends StatelessWidget {
  const BogolanBand({super.key, this.height = 10});
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(height: height, width: double.infinity, child: CustomPaint(painter: _BogolanPainter()));
}

class _BogolanPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = ConteStyle.ink);
    final p = Paint()..color = ConteStyle.gold2..style = PaintingStyle.stroke..strokeWidth = 1.4;
    final h = size.height;
    final step = h * 1.1;
    final path = Path()..moveTo(0, h * .7);
    var up = true;
    for (var x = 0.0; x <= size.width + step; x += step / 2) {
      path.lineTo(x, up ? h * .22 : h * .78);
      up = !up;
    }
    canvas.drawPath(path, p);
    final dot = Paint()..color = ConteStyle.ember;
    for (var x = step / 2; x < size.width; x += step * 2) {
      canvas.drawCircle(Offset(x, h * .5), 1.2, dot);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// Filet orné (séparateur) : deux traits et un losange d'or.
class ConteOrnament extends StatelessWidget {
  const ConteOrnament({super.key, this.color = ConteStyle.gold});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: Container(height: 1, color: color.withOpacity(.6))),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Transform.rotate(angle: math.pi / 4, child: Container(width: 7, height: 7, color: color))),
      Expanded(child: Container(height: 1, color: color.withOpacity(.6))),
    ]);
  }
}

enum ConteButtonKind { ink, gold, outline, quiet }

class ConteButton extends StatelessWidget {
  const ConteButton({super.key, required this.label, required this.onTap, this.icon, this.kind = ConteButtonKind.ink, this.loading = false, this.compact = false});
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final ConteButtonKind kind;
  final bool loading, compact;

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    final BorderSide side;
    switch (kind) {
      case ConteButtonKind.gold:
        bg = ConteStyle.gold;
        fg = Colors.white;
        side = BorderSide.none;
        break;
      case ConteButtonKind.outline:
        bg = Colors.transparent;
        fg = ConteStyle.ink;
        side = const BorderSide(color: ConteStyle.ink, width: 1.5);
        break;
      case ConteButtonKind.quiet:
        bg = Colors.transparent;
        fg = ConteStyle.ink2;
        side = BorderSide.none;
        break;
      case ConteButtonKind.ink:
        bg = ConteStyle.ink;
        fg = ConteStyle.gold2;
        side = BorderSide.none;
        break;
    }
    return Opacity(
      opacity: onTap == null && !loading ? .5 : 1,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: loading ? null : onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: compact ? 9 : 13),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: side == BorderSide.none ? null : Border.fromBorderSide(side)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
              if (loading)
                SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: fg))
              else ...[
                if (icon != null) ...[Icon(icon, size: 18, color: fg), const SizedBox(width: 8)],
                Flexible(child: Text(label, textAlign: TextAlign.center, style: ConteStyle.body(compact ? 15 : 16.5, color: fg, weight: FontWeight.w600, height: 1.1))),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

/// Petite étiquette arrondie (durée, « Gratuit », catégorie).
class ConteTag extends StatelessWidget {
  const ConteTag(this.text, {super.key, this.free = false, this.dark = true});
  final String text;
  final bool free, dark;

  @override
  Widget build(BuildContext context) {
    final bg = free ? ConteStyle.green : (dark ? ConteStyle.ink : Colors.transparent);
    final fg = free ? Colors.white : (dark ? ConteStyle.gold2 : ConteStyle.ink2);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99), border: dark ? null : Border.all(color: ConteStyle.ink2.withOpacity(.6))),
      child: Text(text.toUpperCase(), style: ConteStyle.label(10.5, color: fg)),
    );
  }
}
