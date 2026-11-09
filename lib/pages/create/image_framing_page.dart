import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../l10n/tr.dart';
import '../../services/image_framing.dart';
import '../../theme/app_colors.dart';

/// Une image du téléphone, avec sa taille réelle lue (réduite à 1600 px au plus de large pour rester légère).
class FramedSource {
  FramedSource(this.image);
  final ui.Image image;

  double get w => image.width.toDouble();
  double get h => image.height.toDouble();

  static final Map<String, Future<FramedSource?>> _cache = {};

  /// Lit l'image (une seule fois par fichier).
  static Future<FramedSource?> load(String path) => _cache[path] ??= () async {
        try {
          final codec = await ui.instantiateImageCodec(await File(path).readAsBytes(), targetWidth: 1600);
          return FramedSource((await codec.getNextFrame()).image);
        } catch (_) {
          return null;
        }
      }();
}

/// L'image dessinée dans un cadre de rapport [aspect] avec son cadrage : exactement la partie qui sera publiée. Sert aux aperçus (collage, diaporama, carrousel).
class FramedImage extends StatefulWidget {
  const FramedImage({super.key, required this.path, required this.aspect, this.framing = const ImageFraming()});

  final String path;

  /// Rapport largeur / hauteur du cadre.
  final double aspect;
  final ImageFraming framing;

  @override
  State<FramedImage> createState() => _FramedImageState();
}

class _FramedImageState extends State<FramedImage> {
  FramedSource? _src;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(FramedImage old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path) _load();
  }

  Future<void> _load() async {
    final s = await FramedSource.load(widget.path);
    if (mounted) setState(() => _src = s);
  }

  @override
  Widget build(BuildContext context) {
    final s = _src;
    if (s == null) return const ColoredBox(color: Color(0xFF111111));
    return CustomPaint(painter: _FramedPainter(s, widget.aspect, widget.framing), size: Size.infinite);
  }
}

class _FramedPainter extends CustomPainter {
  _FramedPainter(this.src, this.aspect, this.framing);
  final FramedSource src;
  final double aspect;
  final ImageFraming framing;

  @override
  void paint(Canvas canvas, Size size) {
    final r = FramingMath.sourceRect(src.w, src.h, aspect, framing);
    canvas.drawImageRect(src.image, r, Offset.zero & size, Paint()..filterQuality = FilterQuality.medium);
  }

  @override
  bool shouldRepaint(_FramedPainter old) => old.src != src || old.aspect != aspect || old.framing != framing;
}

/// Écran « Cadrer l'image » : on pince pour zoomer, on glisse pour déplacer, on touche deux fois pour remettre. Rend le nouveau cadrage (null si on annule).
class ImageFramingPage extends StatefulWidget {
  const ImageFramingPage({super.key, required this.path, required this.aspect, this.initial = const ImageFraming(), this.title});

  final String path;
  final double aspect;
  final ImageFraming initial;
  final String? title;

  @override
  State<ImageFramingPage> createState() => _ImageFramingPageState();
}

class _ImageFramingPageState extends State<ImageFramingPage> {
  late ImageFraming _f = widget.initial;
  FramedSource? _src;
  ImageFraming _start = const ImageFraming();
  final _frameKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    FramedSource.load(widget.path).then((s) {
      if (mounted) setState(() => _src = s);
    });
  }

  double get _frameW => (_frameKey.currentContext?.findRenderObject() as RenderBox?)?.size.width ?? 300;

  void _onScaleStart(ScaleStartDetails d) => _start = _f;

  void _onScaleUpdate(ScaleUpdateDetails d) {
    final s = _src;
    if (s == null) return;
    var f = _f.copyWith(zoom: _start.zoom * d.scale);
    f = FramingMath.pan(f, d.focalPointDelta, s.w, s.h, widget.aspect, _frameW);
    setState(() => _f = f);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(widget.title ?? context.tr('Cadrer l\'image'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      ),
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: AspectRatio(
                  aspectRatio: widget.aspect,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: GestureDetector(
                      key: const ValueKey('framing_frame'),
                      behavior: HitTestBehavior.opaque,
                      onScaleStart: _onScaleStart,
                      onScaleUpdate: _onScaleUpdate,
                      onDoubleTap: () => setState(() => _f = const ImageFraming()),
                      child: Container(
                        key: _frameKey,
                        decoration: BoxDecoration(border: Border.all(color: Colors.white54)),
                        child: _src == null ? const ColoredBox(color: Color(0xFF111111)) : CustomPaint(painter: _FramedPainter(_src!, widget.aspect, _f), size: Size.infinite),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(context.tr('Pince pour zoomer, glisse pour déplacer, touche deux fois pour remettre.'), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(children: [
              const Icon(Icons.zoom_out_rounded, color: Colors.white70, size: 20),
              Expanded(child: Slider(key: const ValueKey('framing_zoom'), value: _f.zoom, min: 1, max: ImageFraming.maxZoom, onChanged: (v) {
                final s = _src;
                setState(() => _f = s == null ? _f.copyWith(zoom: v) : _keepInside(_f.copyWith(zoom: v), s));
              })),
              const Icon(Icons.zoom_in_rounded, color: Colors.white70, size: 20),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
            child: Row(children: [
              Expanded(
                child: OutlinedButton(
                  key: const ValueKey('framing_reset'),
                  onPressed: _f.isDefault ? null : () => setState(() => _f = const ImageFraming()),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white38), padding: const EdgeInsets.symmetric(vertical: 13)),
                  child: Text(context.tr('Remettre')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton(
                  key: const ValueKey('framing_ok'),
                  onPressed: () => Navigator.of(context).pop(_f),
                  style: FilledButton.styleFrom(backgroundColor: c.accent, foregroundColor: c.onAccent, padding: const EdgeInsets.symmetric(vertical: 13)),
                  child: Text(context.tr('Valider'), style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  /// Après un changement de zoom au curseur, le centre est ramené pour que la partie visible reste dans l'image.
  ImageFraming _keepInside(ImageFraming f, FramedSource s) {
    final r = FramingMath.sourceRect(s.w, s.h, widget.aspect, f);
    return f.copyWith(cx: r.center.dx / s.w, cy: r.center.dy / s.h);
  }
}
