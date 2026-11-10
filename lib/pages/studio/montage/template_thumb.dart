import 'dart:async';
import 'dart:typed_data';

import 'package:afrotok/l10n/tr.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../../widgets/draft_widgets_layer.dart' show PresetWidgetsPreview;
import 'collage_template.dart';
import 'credits_render.dart';
import 'credits_subjects.dart';
import 'montage_canvas.dart';
import 'montage_catalog.dart';
import 'montage_state.dart';
import 'story_render.dart';
import 'story_script.dart';

/// Pastille « vidéo » posée au centre de l'aperçu d'un modèle qui se fait en vidéo (modèle à vidéo d'exemple, ou à filtres de visage filmés à la caméra) : l'aperçu reste une image
/// de l'application, avec l'icône d'une vidéo par-dessus (demande du 09/11/2026).
class VideoBadge extends StatelessWidget {
  const VideoBadge({super.key, this.size = 40});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('video_badge'),
      width: size,
      height: size,
      decoration: BoxDecoration(color: const Color(0x99000000), shape: BoxShape.circle, border: Border.all(color: Colors.white70, width: 1.5)),
      child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: size * .66),
    );
  }
}

/// Pastille « Nouveau » posée en haut à gauche de l'aperçu d'un modèle récent (jaune en fond, texte noir).
class NewBadge extends StatelessWidget {
  const NewBadge({super.key, this.small = false});
  final bool small;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('new_badge'),
      padding: EdgeInsets.symmetric(horizontal: small ? 6 : 8, vertical: small ? 2 : 3),
      decoration: BoxDecoration(color: const Color(0xFFFFD400), borderRadius: BorderRadius.circular(8)),
      child: Text(tr('Nouveau'), style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: small ? 10 : 11.5)),
    );
  }
}

/// Aperçu d'un modèle : une image de l'application ([asset]) et, si le modèle se fait en vidéo ([video]), l'icône vidéo par-dessus.
class TemplateThumb extends StatelessWidget {
  const TemplateThumb({super.key, required this.asset, required this.video, this.cacheWidth = 400, this.badgeSize = 40, this.isNew = false, this.template});
  final String asset;
  final bool video;
  final int cacheWidth;
  final double badgeSize;
  final bool isNew;

  /// Le modèle : une histoire, un collage ou un duo montre alors son vrai aperçu (scènes qui défilent, disposition des photos ou des vidéos) au lieu d'une image fixe.
  final MontageTemplate? template;

  @override
  Widget build(BuildContext context) {
    final tp = template;
    final special = tp != null && TemplatePreview.handles(tp);
    return Stack(fit: StackFit.expand, alignment: Alignment.center, children: [
      special ? TemplatePreview(t: tp) : (tp != null ? TemplateCanvasThumb(t: tp) : Image.asset(asset, fit: BoxFit.cover, cacheWidth: cacheWidth)),
      if (video) Center(child: VideoBadge(size: badgeSize)),
      if (isNew) const Positioned(top: 6, left: 6, child: NewBadge(small: true)),
    ]);
  }
}

/// Aperçu FIDÈLE d'un modèle qui n'est pas une simple image avec un titre (demande du 09/11/2026) :
/// - histoire : les scènes défilent toutes seules, avec leurs vraies phrases, comme dans la vidéo ;
/// - collage : les photos dans leur mise en page, avec les étiquettes et le titre ;
/// - duo : les deux vidéos l'une sur l'autre ou côte à côte, avec leurs étiquettes.
/// Les photos sont des images d'exemple de l'application. Les aperçus calculés sont gardés en mémoire.
class TemplatePreview extends StatefulWidget {
  const TemplatePreview({super.key, required this.t});
  final MontageTemplate t;

  static bool handles(MontageTemplate t) => t.isStory || t.isCredits || t.isCollage || t.duoLayout != null;

  static const _samples = ['assets/images/intro2.jpg', 'assets/images/intro6.jpg', 'assets/images/intro1.jpg', 'assets/images/intro3.jpg', 'assets/images/intro7.jpg'];
  static final Map<String, List<Uint8List>> _cache = {};

  static Future<List<Uint8List>> _photos(int n) async => [for (var i = 0; i < n; i++) (await rootBundle.load(_samples[i % _samples.length])).buffer.asUint8List()];

  /// Les images de l'aperçu : une par scène (histoire) ou le collage entier (collage). Vide pour un duo (dessiné par des widgets).
  static Future<List<Uint8List>> frames(MontageTemplate t) async {
    final hit = _cache[t.id];
    if (hit != null) return hit;
    List<Uint8List> out = const [];
    if (t.isStory) {
      final s = storyScriptFor(t.id);
      if (s != null) {
        final photos = await _photos(5);
        out = [for (final a in s.acts) await StoryRender.png(a, photo: photos[a.photo % photos.length], width: 270)];
      }
    } else if (t.isCollage) {
      final s = collageScriptFor(t.id);
      if (s != null) out = [await CollageTemplateRender.png(await _photos(s.slots), s, width: 320)];
    }
    return _cache[t.id] = out;
  }

  @override
  State<TemplatePreview> createState() => _TemplatePreviewState();
}

class _TemplatePreviewState extends State<TemplatePreview> {
  List<Uint8List> _frames = const [];
  int _i = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.t.duoLayout != null || widget.t.isCredits) return;   // le duo est dessiné par des widgets, le générique par _CreditsPreview
    TemplatePreview.frames(widget.t).then((f) {
      if (!mounted) return;
      setState(() => _frames = f);
      // une histoire défile seule, scène après scène, au rythme de sa vidéo (le vrai temps de chaque scène)
      if (widget.t.isStory && f.length > 1) _next(storyScriptFor(widget.t.id)!);
    });
  }

  void _next(StoryScript s) {
    _timer = Timer(Duration(milliseconds: (s.acts[_i % s.acts.length].seconds * 1000).round()), () {
      if (!mounted) return;
      setState(() => _i = (_i + 1) % _frames.length);
      _next(s);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  static const _duoLabels = {
    'duo_reaction': ['Vidéo', 'Ma réaction'],
    'duo_cote': ['Moi', 'Toi'],
    'duo_avant_apres_video': ['AVANT', 'APRÈS'],
  };

  Widget _tag(String s) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: const Color(0xCC000000), borderRadius: BorderRadius.circular(6)),
        child: Text(s, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
      );

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    if (t.isCredits) return _CreditsPreview(t: t);
    if (t.duoLayout != null) {
      final labels = _duoLabels[t.id] ?? const ['1', '2'];
      final tb = t.duoLayout == 'tb';
      Widget cell(String asset, String label) => Stack(fit: StackFit.expand, children: [
            Image.asset(asset, fit: BoxFit.cover, cacheWidth: 300),
            Positioned(top: 6, left: 6, child: _tag(tr(label))),
          ]);
      final a = cell(t.sample, labels[0]);
      final b = cell(TemplatePreview._samples[1], labels[1]);
      return ColoredBox(
        color: Colors.black,
        child: tb
            ? Column(children: [Expanded(child: a), const SizedBox(height: 2), Expanded(child: b)])
            : Row(children: [Expanded(child: a), const SizedBox(width: 2), Expanded(child: b)]),
      );
    }
    if (_frames.isEmpty) return Image.asset(t.sample, fit: BoxFit.cover, cacheWidth: 300);
    if (t.isCollage) return Image.memory(_frames.first, fit: BoxFit.cover, gaplessPlayback: true);
    // histoire : la scène courante, des points pour les scènes
    return Stack(fit: StackFit.expand, children: [
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        child: Image.memory(_frames[_i % _frames.length], key: ValueKey(_i % _frames.length), fit: BoxFit.cover, gaplessPlayback: true),
      ),
      Positioned(
        bottom: 6,
        left: 0,
        right: 0,
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var k = 0; k < _frames.length; k++)
            Container(
              width: k == _i % _frames.length ? 14 : 5,
              height: 5,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(color: k == _i % _frames.length ? Colors.white : Colors.white54, borderRadius: BorderRadius.circular(3)),
            ),
        ]),
      ),
    ]);
  }
}

/// L'aperçu d'un modèle ordinaire TEL QU'IL S'OUVRIRA : le même dessin que l'éditeur (les mêmes calques, propres par défaut) et les widgets posés d'office (compte à rebours, lieu…).
/// Dessiné pour un écran entier puis réduit pour tenir dans la vignette (haut du cadre gardé).
class TemplateCanvasThumb extends StatefulWidget {
  const TemplateCanvasThumb({super.key, required this.t});
  final MontageTemplate t;

  @override
  State<TemplateCanvasThumb> createState() => _TemplateCanvasThumbState();
}

class _TemplateCanvasThumbState extends State<TemplateCanvasThumb> {
  late final MontageState _s = MontageState(widget.t);

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    final presets = t.presetWidgets?.call() ?? const [];
    const w = 180.0;
    final h = w / _s.aspect;
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: w,
          height: h,
          child: Stack(fit: StackFit.expand, children: [
            MontageCanvas(state: _s, media: Image.asset(t.sampleIsVideo ? 'assets/images/intro4.jpg' : t.sample, fit: BoxFit.cover, cacheWidth: 400)),
            if (presets.isNotEmpty) Positioned.fill(child: PresetWidgetsPreview(widgets: presets, aspect: _s.aspect)),
          ]),
        ),
      ),
    );
  }
}

/// Aperçu d'un générique de fin de film : le texte monte lentement sur des photos d'exemple qui changent, comme dans la vidéo.
class _CreditsPreview extends StatefulWidget {
  const _CreditsPreview({required this.t});
  final MontageTemplate t;

  @override
  State<_CreditsPreview> createState() => _CreditsPreviewState();
}

class _CreditsPreviewState extends State<_CreditsPreview> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(seconds: 12))..repeat();
  Uint8List? _png;
  double _h = 1;
  List<Uint8List> _bgs = const [];

  @override
  void initState() {
    super.initState();
    Future(() async {
      final lines = creditsDefaultLinesFor(widget.t.id);
      final png = await CreditsRender.png(lines, width: 270);
      final h = CreditsRender.heightFor(lines, width: 270) + 270 * (16 / 9) * .24;
      final bgs = await TemplatePreview._photos(3);
      if (mounted) {
        setState(() {
          _png = png;
          _h = h;
          _bgs = bgs;
        });
      }
    });
  }

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_png == null) return Image.asset(widget.t.sample, fit: BoxFit.cover, cacheWidth: 300);
    return AnimatedBuilder(
      animation: _a,
      builder: (_, __) => LayoutBuilder(builder: (_, box) {
        final t = _a.value;
        final imgH = _h * box.maxWidth / 270;
        final y = box.maxHeight - (box.maxHeight + imgH) * t;
        return Stack(fit: StackFit.expand, clipBehavior: Clip.hardEdge, children: [
          const ColoredBox(color: Colors.black),
          if (_bgs.isNotEmpty) Image.memory(_bgs[(t * _bgs.length).floor().clamp(0, _bgs.length - 1)], fit: BoxFit.cover, gaplessPlayback: true, color: const Color(0xB3000000), colorBlendMode: BlendMode.darken),
          Positioned(left: 0, right: 0, top: y, height: imgH, child: Image.memory(_png!, fit: BoxFit.fill, gaplessPlayback: true)),
        ]);
      }),
    );
  }
}
