// Dessin d'un montage : la photo/vidéo de la personne + le template.
// Les calques sont séparés (fond, teintes, effet, avant-plan) pour que l'export vidéo les assemble à l'identique.

import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../cards/card_flags.dart';
import 'montage_catalog.dart';
import 'montage_fx.dart';
import 'montage_state.dart';

/// Repères de capture : chaque calque est un RepaintBoundary distinct.
class MontageKeys {
  final all = GlobalKey();
  final background = GlobalKey();
  final underlay = GlobalKey();
  final fx = GlobalKey();
  final foreground = GlobalKey();
}

class MontageCanvas extends StatelessWidget {
  const MontageCanvas({
    super.key,
    required this.state,
    this.t = .3,
    this.animation,
    required this.media,
    this.secondMedia,
    this.pseudo = '',
    this.keys,
  });

  final MontageState state;

  /// Instant de l'effet quand [animation] est null (export image par image).
  final double t;
  final Animation<double>? animation;

  /// Photo ou vidéo (déjà en BoxFit.cover).
  final Widget media;

  /// 2e photo : moitié droite (Fiancé·e) ou rond (Nouveau parent).
  final Widget? secondMedia;
  final String pseudo;
  final MontageKeys? keys;

  Widget _rb(GlobalKey? k, Widget child) => k == null ? child : RepaintBoundary(key: k, child: child);

  @override
  Widget build(BuildContext context) {
    final s = state;
    final tp = s.template;
    return AspectRatio(
      aspectRatio: s.post ? 4 / 5 : 9 / 16,
      child: LayoutBuilder(builder: (context, c) {
        final cq = c.maxWidth / 100;
        final texts = resolveMontageTexts(s);
        return _rb(
          keys?.all,
          ClipRect(
            child: Stack(fit: StackFit.expand, children: [
              _rb(
                keys?.background,
                Stack(fit: StackFit.expand, children: [
                  ColoredBox(color: Colors.black, child: _media(cq)),
                  _rb(keys?.underlay, _underlay(cq)),
                ]),
              ),
              _rb(keys?.fx, s.fxActive ? CustomPaint(painter: MontageFxPainter(tp.fx, anim: animation, fixedT: t), size: Size.infinite) : const SizedBox.expand()),
              _rb(keys?.foreground, _foreground(cq, texts)),
            ]),
          ),
        );
      }),
    );
  }

  Widget _filtered(Widget w) {
    final tp = state.template;
    if (tp.saturation == 1 && tp.brightness == 0) return w;
    return ColorFiltered(colorFilter: ColorFilter.matrix(_matrix(tp.saturation, tp.brightness)), child: w);
  }

  Widget _media(double cq) {
    final tp = state.template;
    if (tp.dualSample != null) {
      return Row(children: [
        Expanded(child: _filtered(media)),
        Container(width: .8 * cq, color: Colors.white),
        Expanded(child: _filtered(secondMedia ?? const ColoredBox(color: Color(0xFF333333)))),
      ]);
    }
    return _filtered(media);
  }

  /// Teintes posées sur la photo/vidéo (exportées à part quand la base est une vidéo).
  Widget _underlay(double cq) {
    final s = state;
    final tp = s.template;
    return Stack(fit: StackFit.expand, children: [
      if (tp.country && s.shows(MontageLayer.flag))
        Opacity(
          opacity: .42,
          child: ImageFiltered(
            imageFilter: _blur(7 * cq),
            child: Transform.scale(scale: 1.25, child: CardFlag(s.country, fit: BoxFit.fill)),
          ),
        ),
      if (s.shows(MontageLayer.tint))
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: tp.tint, stops: tp.tintStops),
          ),
        ),
    ]);
  }

  Widget _foreground(double cq, MontageTexts texts) {
    final s = state;
    final tp = s.template;
    final shadow = [Shadow(color: const Color(0x99000000), blurRadius: 2 * cq, offset: Offset(0, .4 * cq))];
    final showKick = s.shows(MontageLayer.kick) && texts.kick.trim().isNotEmpty;
    final showTitle = s.shows(MontageLayer.title) && texts.title.trim().isNotEmpty;
    final showWish = s.shows(MontageLayer.wish) && texts.wish.trim().isNotEmpty;
    final showFlag = tp.country && s.shows(MontageLayer.flag);

    final titleStyle = switch (tp.font) {
      MontageFont.anton => TextStyle(fontFamily: 'Anton', fontSize: (tp.longTitle ? 11 : 15) * cq, height: .98, color: Colors.white, shadows: shadow),
      MontageFont.script => TextStyle(fontFamily: 'PermanentMarker', fontSize: (tp.longTitle ? 8 : 10) * cq, height: 1.15, color: Colors.white, shadows: shadow),
      MontageFont.bold => TextStyle(fontFamily: 'NunitoBold', fontSize: (tp.longTitle ? 7.6 : 10.5) * cq, height: 1.05, color: Colors.white, shadows: shadow),
    };

    final block = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: tp.pos == MontagePos.center ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        if (showKick || showFlag)
          Padding(
            padding: EdgeInsets.only(bottom: 2.2 * cq),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (showFlag)
                Container(
                  width: 8 * cq,
                  height: 8 * cq,
                  margin: EdgeInsets.only(right: showKick ? 2.2 * cq : 0),
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: .5 * cq)),
                  child: ClipOval(child: CardFlag(s.country)),
                ),
              if (showKick)
                Flexible(
                  child: Text(
                    frSpaces(texts.kick).toUpperCase(),
                    style: TextStyle(fontFamily: 'NunitoBold', fontSize: 3.3 * cq, letterSpacing: .66 * cq, color: tp.accent, shadows: shadow),
                  ),
                ),
            ]),
          ),
        if (showTitle)
          Text(
            frSpaces(tp.font == MontageFont.anton ? texts.title.toUpperCase() : texts.title),
            textAlign: tp.pos == MontagePos.center ? TextAlign.center : TextAlign.start,
            style: titleStyle,
          ),
        if (showWish)
          Container(
            margin: EdgeInsets.only(top: 2.4 * cq),
            padding: EdgeInsets.symmetric(horizontal: 3.2 * cq, vertical: 2.4 * cq),
            decoration: BoxDecoration(
              color: const Color.fromRGBO(10, 10, 22, .55),
              borderRadius: BorderRadius.circular(3 * cq),
              border: Border.all(color: const Color.fromRGBO(255, 255, 255, .14)),
            ),
            child: Text(
              frSpaces(texts.wish),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              textAlign: tp.pos == MontagePos.center ? TextAlign.center : TextAlign.start,
              style: TextStyle(fontFamily: 'Nunito', fontSize: 4.3 * cq, height: 1.38, color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
      ],
    );

    return Stack(fit: StackFit.expand, children: [
      if (tp.frame != MontageFrame.none && s.shows(MontageLayer.frame)) CustomPaint(painter: _FramePainter(tp.frame, cq)),
      if (showFlag)
        Positioned(left: 0, right: 0, bottom: 0, height: 3.6 * cq, child: CardFlag(s.country, fit: BoxFit.fill)),
      if (tp.baby)
        Positioned(
          right: 7 * cq,
          top: 24 * cq,
          width: 27 * cq,
          height: 27 * cq,
          child: secondMedia != null
              ? Container(
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: .7 * cq)),
                  child: ClipOval(child: secondMedia),
                )
              : CustomPaint(
                  painter: _DashedCircle(cq),
                  child: Center(
                    child: Text('📷\nPhoto\nde bébé', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'NunitoBold', fontSize: 2.9 * cq, height: 1.25, color: Colors.white)),
                  ),
                ),
        ),
      if (s.shows(MontageLayer.brand))
        Positioned(
          top: 4.5 * cq,
          left: 5 * cq,
          child: Container(
            padding: EdgeInsets.fromLTRB(.9 * cq, .9 * cq, 2.6 * cq, .9 * cq),
            decoration: BoxDecoration(color: const Color(0x66000000), borderRadius: BorderRadius.circular(99)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Image.asset('assets/logo/afrolook_logo.png', width: 5.4 * cq, height: 5.4 * cq),
              SizedBox(width: 1.6 * cq),
              Text('Afrolook', style: TextStyle(fontFamily: 'NunitoBold', fontSize: 3.3 * cq, color: Colors.white)),
            ]),
          ),
        ),
      if (tp.chip != null && s.shows(MontageLayer.chip))
        Positioned(
          top: 4.5 * cq,
          right: 5 * cq,
          child: Container(
            constraints: BoxConstraints(maxWidth: 52 * cq),
            padding: EdgeInsets.symmetric(horizontal: 2.4 * cq, vertical: 1 * cq),
            decoration: BoxDecoration(
              color: const Color(0x94000000),
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: const Color(0x38FFFFFF)),
            ),
            child: Text(frSpaces(tp.chip!), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: 'NunitoBold', fontSize: 3.1 * cq, color: Colors.white)),
          ),
        ),
      Positioned(
        left: 7 * cq,
        right: 7 * cq,
        top: tp.pos == MontagePos.top ? 15 * cq : null,
        bottom: tp.pos == MontagePos.bottom ? 17 * cq : null,
        child: tp.pos == MontagePos.center ? const SizedBox.shrink() : block,
      ),
      if (tp.pos == MontagePos.center) Positioned(left: 7 * cq, right: 7 * cq, top: 0, bottom: 0, child: Center(child: block)),
      if (s.shows(MontageLayer.pseudo) && pseudo.isNotEmpty)
        Positioned(left: 7 * cq, bottom: 6 * cq, child: _PseudoCapsule(pseudo: pseudo, cq: cq)),
      // Filigrane : toujours présent, même publié dans l'app
      Positioned(
        right: 1.6 * cq,
        bottom: (showFlag ? 3.6 : 0) * cq + 1.2 * cq,
        child: Text('Créé sur Afrolook', style: TextStyle(fontFamily: 'NunitoBold', fontSize: 2.3 * cq, color: const Color.fromRGBO(255, 255, 255, .45))),
      ),
    ]);
  }
}

class _PseudoCapsule extends StatelessWidget {
  const _PseudoCapsule({required this.pseudo, required this.cq});
  final String pseudo;
  final double cq;

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFFFD400);
    final base = TextStyle(fontFamily: 'NunitoBold', fontSize: 3.5 * cq, color: Colors.white);
    final clean = pseudo.startsWith('@') ? pseudo.substring(1) : pseudo;
    final spans = <TextSpan>[TextSpan(text: '@', style: base.copyWith(color: gold))];
    final parts = clean.split('.');
    for (var i = 0; i < parts.length; i++) {
      if (i > 0) spans.add(TextSpan(text: '.', style: base.copyWith(color: gold)));
      spans.add(TextSpan(text: parts[i]));
    }
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 3.2 * cq, vertical: 1.3 * cq),
      decoration: BoxDecoration(
        color: const Color(0x9E000000),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: const Color(0x80FFD400)),
      ),
      child: Text.rich(TextSpan(style: base, children: spans), maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}

class _FramePainter extends CustomPainter {
  _FramePainter(this.frame, this.cq);
  final MontageFrame frame;
  final double cq;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    if (frame == MontageFrame.gold) {
      final w = 2 * cq;
      canvas.drawRect(
        rect.deflate(w / 2),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFF1B8), Color(0xFFC9932B), Color(0xFFFFE58A), Color(0xFFA86F12), Color(0xFFFFF1B8)],
            stops: [0, .3, .55, .8, 1],
          ).createShader(rect),
      );
      return;
    }
    // Wax : bande à motif sur les 4 bords
    final w = 3.2 * cq;
    canvas.save();
    final band = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(rect)
      ..addRect(rect.deflate(w));
    canvas.clipPath(band);
    const colors = [Color(0xFFE84B3C), Color(0xFFF5A623), Color(0xFF1FAA59), Color(0xFF1B1B2F)];
    final step = 1.8 * cq;
    final p = Paint()..strokeWidth = step * 1.05;
    var i = 0;
    for (var d = -size.height; d < size.width + size.height; d += step) {
      p.color = colors[i++ % colors.length];
      canvas.drawLine(Offset(d, 0), Offset(d + size.height, size.height), p);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FramePainter old) => old.frame != frame || old.cq != cq;
}

class _DashedCircle extends CustomPainter {
  _DashedCircle(this.cq);
  final double cq;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - .4 * cq;
    canvas.drawCircle(c, r, Paint()..color = const Color(0x59000000));
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .6 * cq
      ..color = const Color(0xD9FFFFFF);
    const n = 28;
    for (var i = 0; i < n; i += 2) {
      canvas.drawArc(Rect.fromCircle(center: c, radius: r), i * 2 * 3.14159 / n, 2 * 3.14159 / n, false, p);
    }
  }

  @override
  bool shouldRepaint(_DashedCircle old) => old.cq != cq;
}

List<double> _matrix(double sat, double bri) {
  const lr = .2126, lg = .7152, lb = .0722;
  final s = sat;
  final b = bri * 255;
  return [
    lr * (1 - s) + s, lg * (1 - s), lb * (1 - s), 0, b,
    lr * (1 - s), lg * (1 - s) + s, lb * (1 - s), 0, b,
    lr * (1 - s), lg * (1 - s), lb * (1 - s) + s, 0, b,
    0, 0, 0, 1, 0,
  ];
}

ui.ImageFilter _blur(double sigma) => ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma, tileMode: TileMode.decal);
