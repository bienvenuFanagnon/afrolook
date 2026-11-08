import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Nombre de médias épinglés au plus (décision du propriétaire, 08/11/2026) : le 1er peut être une vidéo ou une image, les suivants sont des IMAGES de la galerie posées librement.
const int kMaxPins = 5;

/// Les 5 places proposées pour poser un média épinglé : haut droite, haut gauche, bas gauche, bas droite, centre (centre dans le cadre, 0 à 1).
const List<(String, Offset)> kPinSpots = [
  ('Haut droite', Offset(.78, .22)),
  ('Haut gauche', Offset(.22, .22)),
  ('Bas gauche', Offset(.22, .78)),
  ('Bas droite', Offset(.78, .78)),
  ('Centre', Offset(.5, .5)),
];

/// La vidéo d'un autre à épingler (avant d'être posée dans le montage) : son identifiant, sa vignette, son créateur et sa durée.
class MontagePinSource {
  const MontagePinSource({required this.postId, required this.thumbUrl, required this.authorPseudo, required this.durationSec, this.localVideoPath, this.localImagePath, this.previewUrl});

  /// Adresse de lecture de la vidéo d'un autre (aperçu en direct dans le Studio) ; vide pour une vidéo de galerie (on lit le fichier).
  final String? previewUrl;

  /// Vidéo de la GALERIE de la personne (aucune publication) : envoyée au serveur avant le montage. [postId] est alors vide.
  final String? localVideoPath;

  /// IMAGE de la galerie (pas une vidéo) : posée comme une vidéo fixe ; envoyée au serveur avant le montage, sans son.
  final String? localImagePath;

  bool get isImage => localImagePath != null;

  bool get isLocal => localVideoPath != null || localImagePath != null;

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

  /// Taille relative (1 = 30 % de la largeur du cadre), entre 0,5 et 3,3 (jusqu'à toute la largeur).
  double scale;
  bool circle;

  /// Extrait pris dans la vidéo d'origine (secondes).
  double clipStartSec;
  double clipEndSec;

  /// Créneau d'affichage dans NOTRE vidéo (secondes).
  double startSec;
  double endSec;

  static double _defaultClipEnd(double duration) => duration <= 0 ? 6 : duration.clamp(1, 6).toDouble();

  /// Largeur à l'écran, en fraction de la largeur du cadre (0,15 à 1).
  double get widthFrac => (.3 * scale).clamp(.15, 1.0).toDouble();

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
class MontagePinView extends StatefulWidget {
  const MontagePinView({super.key, required this.pin, required this.cq, this.selected = false, this.volume = 0, this.loop = true});

  final MontagePin pin;
  final double cq;
  final bool selected;

  /// Volume de l'aperçu (0 = muet) : le son d'origine, réglé dans l'éditeur.
  final double volume;

  /// L'extrait recommence quand il se termine (sinon il reste sur sa dernière image), comme dans la vidéo finale.
  final bool loop;

  @override
  State<MontagePinView> createState() => _MontagePinViewState();
}

class _MontagePinViewState extends State<MontagePinView> {
  VideoPlayerController? _v;
  String? _key;
  double? _imgAspect;   // format réel d'une image épinglée

  @override
  void initState() {
    super.initState();
    _open();
    final img = widget.pin.source.localImagePath;
    if (img != null) {
      File(img).readAsBytes().then(decodeImageFromList).then((i) {
        if (mounted && i.height > 0) setState(() => _imgAspect = i.width / i.height);
      }).catchError((_) {});
    }
  }

  @override
  void didUpdateWidget(MontagePinView old) {
    super.didUpdateWidget(old);
    if (_playKey(widget.pin) != _key) {
      _open();
    } else {
      _v?.setVolume(widget.volume.clamp(0.0, 1.0));
    }
  }

  /// Garde l'aperçu dans l'extrait choisi : à la fin de l'extrait, il recommence (ou s'arrête sur sa dernière image).
  void _watchClip() {
    final c = _v;
    final pin = widget.pin;
    if (c == null || !c.value.isInitialized || pin.clipEndSec - pin.clipStartSec < .5) return;
    final pos = c.value.position.inMilliseconds / 1000;
    if (pos >= pin.clipEndSec - .05) {
      if (widget.loop) {
        c.seekTo(Duration(milliseconds: (pin.clipStartSec * 1000).round()));
        if (!c.value.isPlaying) c.play();
      } else if (c.value.isPlaying) {
        c.pause();
      }
    }
  }

  static String? _playKey(MontagePin p) => p.source.isImage ? null : (p.source.localVideoPath ?? p.source.previewUrl);

  Future<void> _open() async {
    final key = _playKey(widget.pin);
    _key = key;
    final old = _v;
    _v = null;
    await old?.dispose();
    if (key == null || key.isEmpty) return;
    final src = widget.pin.source;
    final c = src.isLocal ? VideoPlayerController.file(File(key)) : VideoPlayerController.networkUrl(Uri.parse(key), videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true));
    try {
      await c.initialize();
      await c.setLooping(false);   // la vidéo se joue une fois puis reste sur sa dernière image
      await c.setVolume(widget.volume.clamp(0.0, 1.0));
      // l'extrait commence là où la personne l'a réglé
      if (widget.pin.clipStartSec > 0) await c.seekTo(Duration(milliseconds: (widget.pin.clipStartSec * 1000).round()));
      await c.play();
      if (!mounted || _key != key) {
        await c.dispose();
        return;
      }
      c.addListener(_watchClip);
      setState(() => _v = c);
    } catch (_) {
      await c.dispose();
    }
  }

  @override
  void dispose() {
    _v?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pin = widget.pin;
    final w = pin.widthFrac * 100 * widget.cq;   // la taille réelle (30 % de la largeur x le zoom) : elle grandit quand on pince ou qu'on touche « + »
    final v = _v;
    final playing = v != null && v.value.isInitialized;
    // le format RÉEL de la mini-vidéo (portrait, carré ou paysage) ; 16:9 le temps qu'on le connaisse
    final aspect = pin.source.isImage ? (_imgAspect ?? 16 / 9) : (playing && v.value.size.height > 0 ? v.value.aspectRatio : 16 / 9);
    final h = pin.circle ? w : w / aspect;
    Widget thumb = pin.source.isImage
        ? Image.file(File(pin.source.localImagePath!), fit: BoxFit.cover, errorBuilder: (_, __, ___) => pinThumb(pin.source.thumbUrl))
        : playing
        ? FittedBox(fit: BoxFit.cover, clipBehavior: Clip.hardEdge, child: SizedBox(width: v.value.size.width, height: v.value.size.height, child: VideoPlayer(v)))
        : pinThumb(pin.source.thumbUrl);
    thumb = pin.circle ? ClipOval(child: thumb) : ClipRRect(borderRadius: BorderRadius.circular(w * .06), child: thumb);
    return SizedBox(
      width: w,
      height: h,
      child: Stack(fit: StackFit.expand, children: [
        DecoratedBox(
          decoration: BoxDecoration(
            shape: pin.circle ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: pin.circle ? null : BorderRadius.circular(w * .06),
            border: Border.all(color: widget.selected ? const Color(0xFFFFC400) : Colors.white, width: widget.selected ? 2 : 1.4),
            boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 8)],
          ),
          child: thumb,
        ),
        if (!playing && !pin.source.isImage) Center(child: Icon(Icons.play_circle_fill_rounded, color: Colors.white70, size: w * .3)),
        if (!pin.source.isLocal && pin.source.authorPseudo.isNotEmpty)   // jamais de pseudo sur un média de la galerie (le tien)
        Positioned(
          left: 0,
          right: 0,
          bottom: pin.circle ? h * .1 : 2,
          child: Text('@${pin.source.authorPseudo}', maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: (w * .09).clamp(7, 12).toDouble(), fontWeight: FontWeight.w800, shadows: const [Shadow(color: Colors.black87, blurRadius: 3)])),
        ),
      ]),
    );
  }
}

/// Aperçu EN DIRECT de la disposition à deux vidéos dans l'éditeur : la vidéo ajoutée et la tienne jouent chacune dans leur place (collées), avec leur zoom, comme le rendra le serveur.
/// UNE SEULE horloge : ta vidéo (le lecteur de l'éditeur, qui boucle). La vidéo ajoutée se cale dessus : elle recommence avec son extrait (ou reste figée sur sa dernière image si « Reboucler » est coupé),
/// exactement comme dans la vidéo finale. Sans lecteur (vidéo d'un autre sans adresse, erreur), la vignette est affichée à la place.
class MontageLayoutPreview extends StatefulWidget {
  const MontageLayoutPreview({super.key, required this.state, this.meVideo});

  final dynamic state;   // MontageState (évite une dépendance circulaire)

  /// Le lecteur de ta vidéo (celui de l'éditeur) : il fait office d'horloge.
  final VideoPlayerController? meVideo;

  @override
  State<MontageLayoutPreview> createState() => _MontageLayoutPreviewState();
}

class _MontageLayoutPreviewState extends State<MontageLayoutPreview> {
  VideoPlayerController? _origin;
  String? _originKey;
  VideoPlayerController? _clock;   // le lecteur écouté (ta vidéo)

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
    _origin?.setVolume(_originVol);
  }

  double get _originVol => (widget.state.originAudio as bool) ? (widget.state.originVolume as num).toDouble().clamp(0.0, 1.0) : 0.0;

  /// Cale la vidéo ajoutée sur l'horloge : position = début de l'extrait + temps écoulé (modulo la durée de l'extrait si elle reboucle).
  void _follow() {
    final me = widget.meVideo;
    final o = _origin;
    final pin = _pin;
    if (me == null || o == null || pin == null || !me.value.isInitialized || !o.value.isInitialized) return;
    final len = pin.clipEndSec - pin.clipStartSec;
    if (len < .5) return;
    final t = me.value.position.inMilliseconds / 1000;
    final loop = widget.state.originLoop as bool;
    final rel = loop ? t % len : (t > len ? len : t);
    final target = pin.clipStartSec + rel;
    final actual = o.value.position.inMilliseconds / 1000;
    final frozen = !loop && t >= len;   // fini : dernière image figée
    if ((actual - target).abs() > .4 && !frozen) o.seekTo(Duration(milliseconds: (target * 1000).round()));
    if (frozen) {
      if (o.value.isPlaying) o.pause();
    } else if (me.value.isPlaying && !o.value.isPlaying) {
      o.play();
    } else if (!me.value.isPlaying && o.value.isPlaying) {
      o.pause();
    }
  }

  void _sync() {
    if (!identical(_clock, widget.meVideo)) {
      _clock?.removeListener(_follow);
      _clock = widget.meVideo;
      _clock?.addListener(_follow);
    }
    final pin = _pin;
    final originKey = pin == null || pin.source.isImage ? null : (pin.source.localVideoPath ?? pin.source.previewUrl);
    if (originKey != _originKey) {
      _originKey = originKey;
      final old = _origin;
      _origin = null;
      old?.dispose();
      if (originKey != null && originKey.isNotEmpty) {
        final c = pin!.source.isLocal ? VideoPlayerController.file(File(originKey), videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true)) : VideoPlayerController.networkUrl(Uri.parse(originKey), videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true));
        () async {
          try {
            await c.initialize();
            await c.setVolume(_originVol);
            await c.setLooping(false);   // c'est l'horloge de ta vidéo qui le fait recommencer
            await c.seekTo(Duration(milliseconds: (pin.clipStartSec * 1000).round()));
            await c.play();
            if (!mounted || _originKey != originKey) {
              await c.dispose();
              return;
            }
            setState(() => _origin = c);
          } catch (_) {
            await c.dispose();
          }
        }();
      }
    }
  }

  @override
  void dispose() {
    _clock?.removeListener(_follow);
    _origin?.dispose();
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
            pin.source.isImage
                ? ClipRect(child: Transform.scale(scale: oz, child: Image.file(File(pin.source.localImagePath!), fit: BoxFit.cover, errorBuilder: (_, __, ___) => thumb)))
                : _cover(_origin, oz, thumb),
            if (!pin.source.isLocal && pin.source.authorPseudo.isNotEmpty)   // jamais de pseudo sur un média de la galerie (le tien)
              Positioned(left: 6, bottom: 4, child: Text('@${pin.source.authorPseudo}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800, shadows: [Shadow(color: Colors.black87, blurRadius: 4)]))),
          ]),
        ),
        Positioned.fromRect(
          rect: m,
          child: Stack(fit: StackFit.expand, children: [
            _cover(widget.meVideo, mz, const ColoredBox(color: Color(0xFF1B1B1B))),
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
