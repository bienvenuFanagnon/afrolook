import 'dart:math' as math;
import 'dart:ui' as ui;

import 'face_filters.dart';

/// Réglage « Beauté » : peau plus douce, teint lumineux, couleurs chaudes et nettes (comme les téléphones récents), sans effet plastique.
/// Chaque valeur va de 0 (rien) à 1 (fort). Le niveau naturel par défaut est volontairement léger.
class BeautyLevel {
  const BeautyLevel({this.smooth = .35, this.glow = .3, this.warm = .2});
  const BeautyLevel.off() : this(smooth: 0, glow: 0, warm: 0);

  /// Adoucit la peau du visage (les yeux et la bouche restent nets).
  final double smooth;

  /// Teint lumineux : un peu plus de lumière, de contraste et de couleur.
  final double glow;

  /// Chaleur des couleurs : tons de peau plus dorés.
  final double warm;

  bool get isOff => smooth <= 0 && glow <= 0 && warm <= 0;
  bool get hasColor => glow > 0 || warm > 0;

  BeautyLevel copyWith({double? smooth, double? glow, double? warm}) => BeautyLevel(smooth: smooth ?? this.smooth, glow: glow ?? this.glow, warm: warm ?? this.warm);

  Map<String, dynamic> toJson() => {'smooth': smooth, 'glow': glow, 'warm': warm};

  /// Réglage des couleurs en matrice 4×5 (utilisable sur l'aperçu de la caméra et sur la photo). Identité si [hasColor] est faux.
  List<double> get colorMatrix {
    if (!hasColor) return const [1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0];
    final sat = 1 + .12 * glow; // couleurs un peu plus vives
    const lr = .2126, lg = .7152, lb = .0722;
    final sr = (1 - sat) * lr, sg = (1 - sat) * lg, sb = (1 - sat) * lb;
    final c = 1 + .06 * glow; // contraste doux
    final o = 255 * (.035 * glow + .01 * warm); // un peu de lumière
    final rm = c * (1 + .06 * warm), bm = c * (1 - .07 * warm);
    return [
      (sr + sat) * rm, sg * rm, sb * rm, 0, o,
      sr * c, (sg + sat) * c, sb * c, 0, o,
      sr * bm, sg * bm, (sb + sat) * bm, 0, o,
      0, 0, 0, 1, 0,
    ];
  }

  ui.ColorFilter get colorFilter => ui.ColorFilter.matrix(colorMatrix);
}

/// Dessin de la beauté sur une image (séparé pour pouvoir être testé sans téléphone).
class BeautyPainter {
  BeautyPainter._();

  /// Dessine [img] avec les couleurs de [b], puis adoucit la peau de chaque visage de [faces].
  static void paint(ui.Canvas canvas, ui.Image img, List<FaceBox> faces, BeautyLevel b) {
    final base = ui.Paint()..colorFilter = b.colorFilter;
    canvas.drawImage(img, ui.Offset.zero, base);
    if (b.smooth <= 0) return;
    for (final f in faces) {
      final face = f.rect;
      final bounds = face.inflate(face.width * .1).intersect(ui.Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()));
      if (bounds.isEmpty) continue;
      final sigma = math.max(1.5, face.width * .018 * (.4 + b.smooth));
      final alpha = (.9 * b.smooth).clamp(0.0, 1.0);
      canvas.saveLayer(bounds, ui.Paint());
      // la peau floutée…
      canvas.saveLayer(bounds, ui.Paint()..imageFilter = ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma, tileMode: ui.TileMode.clamp));
      canvas.drawImage(img, ui.Offset.zero, base);
      canvas.restore();
      // …gardée seulement au centre du visage, avec des bords doux
      canvas.drawRect(
        bounds,
        ui.Paint()
          ..blendMode = ui.BlendMode.dstIn
          ..shader = ui.Gradient.radial(bounds.center, math.max(bounds.width, bounds.height) * .55, [ui.Color.fromRGBO(0, 0, 0, alpha), ui.Color.fromRGBO(0, 0, 0, alpha), const ui.Color(0x00000000)], const [0, .55, 1]),
      );
      // les yeux et la bouche restent nets
      void keep(ui.Offset c, double rx, double ry) {
        final r = ui.Rect.fromCenter(center: c, width: rx * 2, height: ry * 2);
        canvas.drawOval(r, ui.Paint()..blendMode = ui.BlendMode.dstOut..shader = ui.Gradient.radial(c, math.max(rx, ry), const [ui.Color(0xCC000000), ui.Color(0x00000000)]));
      }

      final span = (f.leftEye != null && f.rightEye != null) ? (f.leftEye! - f.rightEye!).distance : face.width * .4;
      if (f.leftEye != null) keep(f.leftEye!, span * .32, span * .22);
      if (f.rightEye != null) keep(f.rightEye!, span * .32, span * .22);
      keep(f.nose != null ? f.nose! + ui.Offset(0, face.height * .2) : ui.Offset(face.center.dx, face.top + face.height * .8), span * .42, span * .2);
      canvas.restore();
    }
  }
}
