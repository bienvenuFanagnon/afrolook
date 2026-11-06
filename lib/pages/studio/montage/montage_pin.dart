import 'package:flutter/material.dart';

/// La vidéo d'un autre à épingler (avant d'être posée dans le montage) : son identifiant, sa vignette, son créateur et sa durée.
class MontagePinSource {
  const MontagePinSource({required this.postId, required this.thumbUrl, required this.authorPseudo, required this.durationSec});

  final String postId;
  final String thumbUrl;
  final String authorPseudo;

  /// Durée de la vidéo d'origine en secondes (0 si inconnue : l'extrait est alors pris au début).
  final double durationSec;
}

/// Une vidéo épinglée dans le montage : un EXTRAIT (1 à 15 s) de la vidéo d'un autre, posé dans le cadre à la taille, à l'endroit et au créneau choisis.
/// Le serveur découpe et réduit l'extrait (360 px, sans son) : le téléphone ne télécharge jamais la vidéo entière.
class MontagePin {
  MontagePin({required this.id, required this.source, this.center = const Offset(.78, .22), this.scale = 1, this.circle = false, this.clipStartSec = 0, double? clipEndSec, this.startSec = 0, double? endSec})
      : clipEndSec = clipEndSec ?? _defaultClipEnd(source.durationSec),
        endSec = endSec ?? 6;

  final String id;
  final MontagePinSource source;

  /// Centre dans le cadre (fraction de la largeur et de la hauteur).
  Offset center;

  /// Taille relative (1 = 30 % de la largeur du cadre), entre 0,5 et 2.
  double scale;
  bool circle;

  /// Extrait pris dans la vidéo d'origine (secondes).
  double clipStartSec;
  double clipEndSec;

  /// Créneau d'affichage dans NOTRE vidéo (secondes).
  double startSec;
  double endSec;

  static double _defaultClipEnd(double duration) => duration <= 0 ? 6 : duration.clamp(1, 6).toDouble();

  /// Largeur à l'écran, en fraction de la largeur du cadre (0,15 à 0,6).
  double get widthFrac => (.3 * scale).clamp(.15, .6).toDouble();

  double get clipSeconds => clipEndSec - clipStartSec;

  Map<String, dynamic> toApi() => {
        'post_id': source.postId,
        'clip_start_ms': (clipStartSec * 1000).round(),
        'clip_end_ms': (clipEndSec * 1000).round(),
        'x': center.dx.clamp(0, 1),
        'y': center.dy.clamp(0, 1),
        'w': widthFrac,
        'shape': circle ? 'circle' : 'rect',
        'start': startSec,
        'end': endSec,
      };
}

/// Aperçu d'une vidéo épinglée dans l'éditeur : la vignette de la vidéo d'origine (rectangle ou rond), « ▶ » et le nom du créateur. N'apparaît jamais dans le fichier final
/// (la vraie vidéo est posée par le serveur).
class MontagePinView extends StatelessWidget {
  const MontagePinView({super.key, required this.pin, required this.cq, this.selected = false});

  final MontagePin pin;
  final double cq;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final w = .3 * 100 * cq;   // taille de base ; le zoom (pincement) est appliqué par le cadre qui contient l'élément
    final h = pin.circle ? w : w * 9 / 16;
    Widget thumb = pin.source.thumbUrl.startsWith('http')
        ? Image.network(pin.source.thumbUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFF3A3A3A)))
        : const ColoredBox(color: Color(0xFF3A3A3A));
    thumb = pin.circle ? ClipOval(child: thumb) : ClipRRect(borderRadius: BorderRadius.circular(w * .06), child: thumb);
    return SizedBox(
      width: w,
      height: h,
      child: Stack(fit: StackFit.expand, children: [
        DecoratedBox(
          decoration: BoxDecoration(
            shape: pin.circle ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: pin.circle ? null : BorderRadius.circular(w * .06),
            border: Border.all(color: selected ? const Color(0xFFFFC400) : Colors.white, width: selected ? 2 : 1.4),
            boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 8)],
          ),
          child: thumb,
        ),
        Center(child: Icon(Icons.play_circle_fill_rounded, color: Colors.white70, size: w * .3)),
        Positioned(
          left: 0,
          right: 0,
          bottom: pin.circle ? h * .1 : 2,
          child: Text('@${pin.source.authorPseudo}', maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: (w * .09).clamp(7, 12).toDouble(), fontWeight: FontWeight.w800, shadows: const [Shadow(color: Colors.black, blurRadius: 3)])),
        ),
      ]),
    );
  }
}
