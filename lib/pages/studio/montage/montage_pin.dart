import 'dart:io';

import 'package:flutter/material.dart';

/// La vidéo d'un autre à épingler (avant d'être posée dans le montage) : son identifiant, sa vignette, son créateur et sa durée.
class MontagePinSource {
  const MontagePinSource({required this.postId, required this.thumbUrl, required this.authorPseudo, required this.durationSec, this.localVideoPath});

  /// Vidéo de la GALERIE de la personne (aucune publication) : envoyée au serveur avant le montage. [postId] est alors vide.
  final String? localVideoPath;

  bool get isLocal => localVideoPath != null;

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

  /// Ce qui est gardé avec la publication : de quelle vidéo, où et quand (un toucher sur la vidéo épinglée ouvre l'original).
  Map<String, dynamic> toLink() => {'post_id': source.postId, 'x': center.dx.clamp(0, 1), 'y': center.dy.clamp(0, 1), 'w': widthFrac, 'shape': circle ? 'circle' : 'rect', 'start': startSec, 'end': endSec};

  /// Identifiant d'envoi de la vidéo de galerie (rempli au moment de l'export).
  String? uploadId;

  Map<String, dynamic> toApi() => {
        if (source.isLocal) 'upload_id': uploadId else 'post_id': source.postId,
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
    Widget thumb = pinThumb(pin.source.thumbUrl);
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

/// Aperçu de la disposition à deux vidéos dans l'éditeur : la vignette de la vidéo d'origine dans sa place, et « Ta vidéo » dans l'autre (la vraie vidéo est assemblée par le serveur).
class MontageLayoutPreview extends StatelessWidget {
  const MontageLayoutPreview({super.key, required this.state});

  final dynamic state;   // MontageState (évite une dépendance circulaire)

  @override
  Widget build(BuildContext context) {
    final f = state.layoutFracs as ({Rect origin, Rect me})?;
    final pin = state.pins.isEmpty ? null : state.pins.first as MontagePin;
    if (f == null || pin == null) return const SizedBox.shrink();
    return LayoutBuilder(builder: (context, box) {
      Rect px(Rect r) => Rect.fromLTWH(r.left * box.maxWidth, r.top * box.maxHeight, r.width * box.maxWidth, r.height * box.maxHeight);
      final o = px(f.origin);
      final m = px(f.me);
      final thumb = pinThumb(pin.source.thumbUrl);
      return Stack(children: [
        Positioned.fromRect(rect: o, child: Stack(fit: StackFit.expand, children: [
          thumb,
          const Center(child: Icon(Icons.play_circle_fill_rounded, color: Colors.white70, size: 36)),
          Positioned(left: 6, bottom: 4, child: Text('@${pin.source.authorPseudo}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800, shadows: [Shadow(color: Colors.black87, blurRadius: 4)]))),
        ])),
        Positioned.fromRect(rect: m, child: IgnorePointer(child: Align(alignment: Alignment.topLeft, child: Container(margin: const EdgeInsets.all(6), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)), child: const Text('Ta vidéo', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)))))),
      ]);
    });
  }
}

/// Vignette d'une vidéo épinglée : adresse du réseau, fichier local (vidéo de galerie) ou fond gris.
Widget pinThumb(String thumb) {
  const grey = ColoredBox(color: Color(0xFF3A3A3A));
  if (thumb.startsWith('http')) return Image.network(thumb, fit: BoxFit.cover, errorBuilder: (_, __, ___) => grey);
  if (thumb.isNotEmpty && File(thumb).existsSync()) return Image.file(File(thumb), fit: BoxFit.cover, errorBuilder: (_, __, ___) => grey);
  return grey;
}
