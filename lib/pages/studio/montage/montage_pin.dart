import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// La vidéo d'un autre à épingler (avant d'être posée dans le montage) : son identifiant, sa vignette, son créateur et sa durée.
class MontagePinSource {
  const MontagePinSource({required this.postId, required this.thumbUrl, required this.authorPseudo, required this.durationSec, this.localVideoPath, this.previewUrl});

  /// Adresse de lecture de la vidéo d'un autre (aperçu en direct dans le Studio) ; vide pour une vidéo de galerie (on lit le fichier).
  final String? previewUrl;

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

/// Aperçu EN DIRECT de la disposition à deux vidéos dans l'éditeur : la vidéo ajoutée et la tienne jouent chacune dans leur place (collées), avec leur zoom, comme le rendra le serveur.
/// Sans lecteur (vidéo d'un autre sans adresse, erreur), la vignette est affichée à la place.
class MontageLayoutPreview extends StatefulWidget {
  const MontageLayoutPreview({super.key, required this.state});

  final dynamic state;   // MontageState (évite une dépendance circulaire)

  @override
  State<MontageLayoutPreview> createState() => _MontageLayoutPreviewState();
}

class _MontageLayoutPreviewState extends State<MontageLayoutPreview> {
  VideoPlayerController? _origin;
  VideoPlayerController? _me;
  String? _originKey;
  String? _meKey;

  MontagePin? get _pin => widget.state.pins.isEmpty ? null : widget.state.pins.first as MontagePin;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(MontageLayoutPreview old) {
    super.didUpdateWidget(old);
    _sync();
  }

  Future<VideoPlayerController?> _open(VideoPlayerController c) async {
    try {
      await c.initialize();
      await c.setVolume(0);
      await c.setLooping(true);
      await c.play();
      return c;
    } catch (_) {
      await c.dispose();
      return null;
    }
  }

  void _sync() {
    final pin = _pin;
    final originKey = pin == null ? null : (pin.source.localVideoPath ?? pin.source.previewUrl);
    if (originKey != _originKey) {
      _originKey = originKey;
      final old = _origin;
      _origin = null;
      old?.dispose();
      if (originKey != null && originKey.isNotEmpty) {
        final c = pin!.source.isLocal ? VideoPlayerController.file(File(originKey)) : VideoPlayerController.networkUrl(Uri.parse(originKey), videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true));
        _open(c).then((v) {
          if (!mounted || _originKey != originKey) {
            v?.dispose();
            return;
          }
          setState(() => _origin = v);
        });
      }
    }
    final String? meKey = widget.state.videoPath as String?;
    if (meKey != _meKey) {
      _meKey = meKey;
      final old = _me;
      _me = null;
      old?.dispose();
      if (meKey != null && File(meKey).existsSync()) {
        _open(VideoPlayerController.file(File(meKey), videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true))).then((v) {
          if (!mounted || _meKey != meKey) {
            v?.dispose();
            return;
          }
          setState(() => _me = v);
        });
      }
    }
  }

  @override
  void dispose() {
    _origin?.dispose();
    _me?.dispose();
    super.dispose();
  }

  Widget _cover(VideoPlayerController? v, double zoom, Widget fallback) {
    if (v == null || !v.value.isInitialized) return fallback;
    return ClipRect(
      child: Transform.scale(
        scale: zoom,
        child: FittedBox(fit: BoxFit.cover, clipBehavior: Clip.hardEdge, child: SizedBox(width: v.value.size.width, height: v.value.size.height, child: VideoPlayer(v))),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.state.layoutFracs as ({Rect origin, Rect me})?;
    final pin = _pin;
    if (f == null || pin == null) return const SizedBox.shrink();
    return LayoutBuilder(builder: (context, box) {
      Rect px(Rect r) => Rect.fromLTWH(r.left * box.maxWidth, r.top * box.maxHeight, r.width * box.maxWidth, r.height * box.maxHeight);
      final o = px(f.origin);
      final m = px(f.me);
      final thumb = pinThumb(pin.source.thumbUrl);
      final oz = (widget.state.originZoom as num).toDouble();
      final mz = (widget.state.meZoom as num).toDouble();
      return Stack(children: [
        const Positioned.fill(child: ColoredBox(color: Colors.black)),
        Positioned.fromRect(
          rect: o,
          child: Stack(fit: StackFit.expand, children: [
            _cover(_origin, oz, thumb),
            Positioned(left: 6, bottom: 4, child: Text(pin.source.authorPseudo.isEmpty ? '' : '@${pin.source.authorPseudo}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800, shadows: [Shadow(color: Colors.black87, blurRadius: 4)]))),
          ]),
        ),
        Positioned.fromRect(
          rect: m,
          child: Stack(fit: StackFit.expand, children: [
            _cover(_me, mz, const ColoredBox(color: Color(0xFF1B1B1B))),
            Positioned(left: 6, top: 6, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)), child: const Text('Ta vidéo', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)))),
          ]),
        ),
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
