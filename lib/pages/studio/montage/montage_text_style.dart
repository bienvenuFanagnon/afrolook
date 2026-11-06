import 'package:flutter/material.dart';

import 'montage_look.dart' show kFreeTextColors;

/// Style d'écriture du texte libre (polices déjà embarquées dans l'application, libres de droits).
class FreeTextFont {
  const FreeTextFont({required this.id, required this.name, required this.family, this.upper = false, this.spacing = 0, this.size = 1, this.glow = false});

  final String id;
  final String name;
  final String family;

  /// Tout en majuscules (style « affiche »).
  final bool upper;
  final double spacing;

  /// Facteur de taille : certaines polices sont plus petites que d'autres à corps égal.
  final double size;

  /// Halo lumineux de la couleur du texte (style néon).
  final bool glow;
}

const List<FreeTextFont> kFreeTextFonts = [
  FreeTextFont(id: 'classic', name: 'Classique', family: 'NunitoBold'),
  FreeTextFont(id: 'poster', name: 'Affiche', family: 'Anton', upper: true, spacing: 1.2, size: 1.12),
  FreeTextFont(id: 'marker', name: 'Marqueur', family: 'PermanentMarker', size: 1.05),
  FreeTextFont(id: 'elegant', name: 'Élégant', family: 'AbrilFatface', size: 1.05),
  FreeTextFont(id: 'neon', name: 'Néon', family: 'Audiowide', glow: true, size: .95),
  FreeTextFont(id: 'retro', name: 'Rétro', family: 'Righteous'),
  FreeTextFont(id: 'comic', name: 'BD', family: 'Bangers', spacing: .8, size: 1.1),
  FreeTextFont(id: 'tech', name: 'Tech', family: 'Rajdhani', upper: true, spacing: 1.6, size: 1.1),
];

/// Arrière-plan du texte (plan arrière pour le rendre plus visible) : 0 aucun, 1 plein, 2 semi-transparent, 3 contour épais.
const List<String> kFreeBgModes = ['Sans fond', 'Plein', 'Transparent', 'Contour'];

/// Cadre autour du texte : 0 aucun, 1 cadre fin, 2 double trait, 3 bulle arrondie, 4 trait sous le texte.
const List<String> kFreeFrames = ['Sans cadre', 'Cadre fin', 'Double trait', 'Bulle', 'Soulignement'];

/// Texte libre prêt à poser : police, couleur, arrière-plan et cadre au choix. Les tailles sont en fraction de la largeur du cadre ([cq]).
class FreeTextView extends StatelessWidget {
  const FreeTextView({super.key, required this.text, required this.cq, this.font = 0, this.color = 0, this.bg = 0, this.bgColor = 2, this.frame = 0});

  final String text;
  final double cq;
  final int font;
  final int color;
  final int bg;
  final int bgColor;
  final int frame;

  @override
  Widget build(BuildContext context) {
    final f = kFreeTextFonts[font.clamp(0, kFreeTextFonts.length - 1)];
    final fg = kFreeTextColors[color.clamp(0, kFreeTextColors.length - 1)];
    final back = kFreeTextColors[bgColor.clamp(0, kFreeTextColors.length - 1)];
    final shown = f.upper ? text.toUpperCase() : text;
    final base = TextStyle(fontFamily: f.family, fontSize: 6.4 * cq * f.size, height: 1.15, letterSpacing: f.spacing * cq * .25, color: fg);

    List<Shadow>? shadows;
    if (f.glow) {
      shadows = [Shadow(color: fg.withValues(alpha: .95), blurRadius: 1.2 * cq), Shadow(color: fg.withValues(alpha: .7), blurRadius: 3 * cq)];
    } else if (bg == 0 || bg == 3) {
      shadows = [Shadow(color: const Color(0xCC000000), blurRadius: .9 * cq, offset: Offset(0, .25 * cq))];
    }

    Widget label = Text(shown, textAlign: TextAlign.center, maxLines: 5, overflow: TextOverflow.ellipsis, style: base.copyWith(shadows: shadows));
    if (bg == 3) {
      // contour épais de la couleur d'arrière-plan derrière le texte
      label = Stack(children: [
        Text(shown, textAlign: TextAlign.center, maxLines: 5, overflow: TextOverflow.ellipsis, style: base.copyWith(foreground: Paint()..style = PaintingStyle.stroke..strokeWidth = 1.3 * cq..strokeJoin = StrokeJoin.round..color = back)),
        label,
      ]);
    }

    final filled = bg == 1 || bg == 2;
    final radius = frame == 3 ? 20 * cq : 1.4 * cq;
    final decoration = BoxDecoration(
      color: filled ? back.withValues(alpha: bg == 2 ? .55 : 1) : null,
      borderRadius: BorderRadius.circular(radius),
      border: frame == 1 || frame == 3 ? Border.all(color: fg, width: .45 * cq) : null,
    );
    Widget box = Container(
      padding: EdgeInsets.symmetric(horizontal: (filled || frame != 0 ? 3.2 : 0) * cq, vertical: (filled || frame != 0 ? 1.6 : 0) * cq),
      decoration: filled || frame == 1 || frame == 3 ? decoration : null,
      child: label,
    );
    if (frame == 2) {
      // double trait : un second cadre fin, légèrement plus large
      box = Container(
        padding: EdgeInsets.all(.9 * cq),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(2 * cq), border: Border.all(color: fg, width: .35 * cq)),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 2.8 * cq, vertical: 1.4 * cq),
          decoration: BoxDecoration(color: filled ? back.withValues(alpha: bg == 2 ? .55 : 1) : null, borderRadius: BorderRadius.circular(1 * cq), border: Border.all(color: fg, width: .35 * cq)),
          child: label,
        ),
      );
    }
    if (frame == 4) {
      box = Column(mainAxisSize: MainAxisSize.min, children: [
        box,
        SizedBox(height: .8 * cq),
        Container(width: 22 * cq, height: .9 * cq, decoration: BoxDecoration(color: fg, borderRadius: BorderRadius.circular(cq))),
      ]);
    }
    return box;
  }
}
