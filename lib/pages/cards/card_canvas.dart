import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'card_models.dart';
import 'card_text.dart';

const _green = Color(0xFF2ECC71);
const _yellow = Color(0xFFFFE14D);
const _red = Color(0xFFE5484D);
const _ink = Color(0xFF0E0E0E);

/// La carte Afrolook : un post mis en forme dans un des styles, à taille fixe selon le format (voir [CardFormatX.size]).
/// Dessinée en entier par Flutter, donc exportable en PNG avec un [RepaintBoundary].
///
/// Règles de mise en page :
/// - un média n'est jamais recadré : il est montré en entier dans un cadre de forme fixe, les bords étant remplis
///   par un flou de la même image ;
/// - le texte s'adapte à la place restante (la police diminue, puis le texte est coupé proprement) ;
/// - la signature Afrolook (coin plié, bande tricolore, sceau, QR) est identique sur tous les styles.
class CardCanvas extends StatelessWidget {
  const CardCanvas({super.key, required this.source, required this.spec, this.text});

  final CardSource source;
  final CardSpec spec;

  /// Texte à afficher (si null : découpe automatique du texte du post selon [spec]).
  final String? text;

  @override
  Widget build(BuildContext context) {
    final size = spec.format.size;
    final theme = _ThemeOf(spec.style);
    final selected = _selectedImages();
    final hasMedia = selected.isNotEmpty;
    final cut = text == null ? cardText(source.text, spec, hasMedia: hasMedia) : CardCut(text!, false);
    final tags = separateTags(source.text).tags;

    final content = _Content(source: source, spec: spec, theme: theme, text: cut.text, truncated: cut.truncated, images: selected, tags: tags);

    return SizedBox(
      width: size.width,
      height: size.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          fit: StackFit.expand,
          children: [
            theme.background(size),
            Padding(padding: theme.padding, child: theme.wrap(content)),
            const Positioned(right: 0, top: 0, child: _Fold()),
            const Positioned(left: 0, right: 0, bottom: 0, child: _TriBand()),
          ],
        ),
      ),
    );
  }

  List<ImageProvider> _selectedImages() {
    if (source.images.isEmpty) return const [];
    final idx = spec.imageOrder.where((i) => i >= 0 && i < source.images.length).toList();
    final order = idx.isEmpty ? List<int>.generate(math.min(3, source.images.length), (i) => i) : idx;
    final list = [for (final i in order.take(CardSpec.maxImages)) source.images[i]];
    return spec.layout == CardLayout.single ? [list.first] : list;
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Contenu : en-tête, texte, média, pied
// ═════════════════════════════════════════════════════════════════════════════

class _Content extends StatelessWidget {
  const _Content({required this.source, required this.spec, required this.theme, required this.text, required this.truncated, required this.images, required this.tags});
  final CardSource source;
  final CardSpec spec;
  final _ThemeOf theme;
  final String text;
  final bool truncated;
  final List<ImageProvider> images;
  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    // Carré avec média : pas de place pour un en-tête, le pseudo passe dans le pied de carte
    final compact = spec.format == CardFormat.square && images.isNotEmpty;
    final family = spec.font.family;
    final base = theme.textStyle;
    final style = family == null ? base : base.copyWith(fontFamily: family, fontWeight: spec.font.weight);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (spec.showAuthor && !compact) _Header(source: source, spec: spec, theme: theme),
        if (spec.showAuthor && !compact) const SizedBox(height: 8),
        Expanded(
          child: Column(
            children: [
              Expanded(
                child: Align(
                  alignment: images.isEmpty ? Alignment.center : Alignment.centerLeft,
                  child: _FitText(text: text, style: style, maxSize: images.isEmpty ? 30 : 22, minSize: 13, glow: theme.glow),
                ),
              ),
              if (images.isNotEmpty) ...[
                const SizedBox(height: 8),
                _MediaFrame(images: images, layout: spec.layout, ratio: spec.format.frameRatio, isVideo: source.isVideo, theme: theme),
              ],
            ],
          ),
        ),
        if (tags.isNotEmpty && spec.format != CardFormat.square)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(tags.take(3).join('  '), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.muted, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        const SizedBox(height: 8),
        _Footer(source: source, spec: spec, theme: theme, truncated: truncated, showPseudo: compact && spec.showAuthor),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.source, required this.spec, required this.theme});
  final CardSource source;
  final CardSpec spec;
  final _ThemeOf theme;

  @override
  Widget build(BuildContext context) {
    final sub = [
      if (spec.showDate && source.date != null) _fmtDate(source.date!),
      if (source.credit != null) source.credit!,
    ].join(' · ');
    return Row(children: [
      Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: theme.accent, width: 2), color: const Color(0xFF3A3A3A)),
        child: ClipOval(
          child: source.avatar != null
              ? Image(image: source.avatar!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _initial())
              : _initial(),
        ),
      ),
      const SizedBox(width: 9),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Flexible(
              child: Text('@${source.pseudo}',
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.fg, fontSize: 15, fontWeight: FontWeight.w800, fontFamily: theme.headFont)),
            ),
            if (source.verified) const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.verified_rounded, color: Color(0xFF2196F3), size: 17)),
          ]),
          if (sub.isNotEmpty) Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.muted, fontSize: 11)),
        ]),
      ),
      const SizedBox(width: 40), // place du coin plié
    ]);
  }

  Widget _initial() => Center(
        child: Text(source.pseudo.isEmpty ? '?' : source.pseudo.characters.first.toUpperCase(),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
      );
}

const _months = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];
String _fmtDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

String _compact(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(n >= 10000000 ? 0 : 1).replaceAll('.0', '')} M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(n >= 10000 ? 0 : 1).replaceAll('.0', '')} k';
  return '$n';
}

class _Footer extends StatelessWidget {
  const _Footer({required this.source, required this.spec, required this.theme, required this.truncated, this.showPseudo = false});
  final bool showPseudo;
  final CardSource source;
  final CardSpec spec;
  final _ThemeOf theme;
  final bool truncated;

  @override
  Widget build(BuildContext context) {
    final link = source.link ?? 'https://afrolookmedia.com';
    return SizedBox(
      height: 40,
      child: Row(children: [
        Expanded(
          child: showPseudo
              ? Text('@${source.pseudo}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.fg, fontSize: 14, fontWeight: FontWeight.w800, fontFamily: theme.headFont))
              : truncated
              ? Text('Lire la suite sur Afrolook ↗', maxLines: 2, style: TextStyle(color: theme.fg.withOpacity(0.9), fontSize: 12, fontWeight: FontWeight.w700))
              : (spec.showStats
                  ? FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Row(children: [
                      Icon(Icons.favorite_rounded, size: 15, color: theme.fg),
                      const SizedBox(width: 4),
                      Text(_compact(source.likes), style: TextStyle(color: theme.fg, fontSize: 13, fontWeight: FontWeight.w700)),
                      const SizedBox(width: 12),
                      Icon(Icons.chat_bubble_rounded, size: 14, color: theme.fg),
                      const SizedBox(width: 4),
                      Text(_compact(source.comments), style: TextStyle(color: theme.fg, fontSize: 13, fontWeight: FontWeight.w700)),
                    ]))
                  : const SizedBox.shrink()),
        ),
        if (spec.showQr)
          Container(
            width: 40,
            height: 40,
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.all(2.5),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: theme.qrBorder, width: 2)),
            child: QrImageView(data: link, padding: EdgeInsets.zero, backgroundColor: Colors.white, eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF111111)), dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Color(0xFF111111))),
          ),
        const _Seal(),
      ]),
    );
  }
}

/// Sceau Afrolook : pastille noire cerclée de vert, avec le logo et le nom. Identique sur tous les styles.
class _Seal extends StatelessWidget {
  const _Seal();
  @override
  Widget build(BuildContext context) => Container(
        height: 30,
        padding: const EdgeInsets.fromLTRB(2, 2, 10, 2),
        decoration: BoxDecoration(color: _ink, borderRadius: BorderRadius.circular(99), border: Border.all(color: _green, width: 2)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(color: _green, shape: BoxShape.circle),
            child: ClipOval(
              child: Image.asset('assets/logo/afrolook_logo.png', fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Center(child: Text('A', style: TextStyle(color: _ink, fontWeight: FontWeight.w900, fontSize: 15)))),
            ),
          ),
          const SizedBox(width: 5),
          const Text.rich(TextSpan(children: [
            TextSpan(text: 'afro', style: TextStyle(color: Colors.white)),
            TextSpan(text: 'look', style: TextStyle(color: _yellow)),
          ]), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: .2, fontFamily: 'Roboto')),
        ]),
      );
}

/// Coin plié jaune « A » en haut à droite : le repère de la marque.
class _Fold extends StatelessWidget {
  const _Fold();
  @override
  Widget build(BuildContext context) => SizedBox(
        width: 64,
        height: 64,
        child: CustomPaint(
          painter: _FoldPainter(),
          child: const Align(
            alignment: Alignment(0.55, -0.62),
            child: Text('A', style: TextStyle(color: _ink, fontWeight: FontWeight.w900, fontSize: 19, fontFamily: 'Roboto')),
          ),
        ),
      );
}

class _FoldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final p = Path()
      ..moveTo(0, 0)
      ..lineTo(s.width, 0)
      ..lineTo(s.width, s.height)
      ..close();
    canvas.drawShadow(p, Colors.black, 4, true);
    canvas.drawPath(p, Paint()..color = _yellow);
    // pli : un triangle plus clair le long de l'hypoténuse
    final fold = Path()
      ..moveTo(0, 0)
      ..lineTo(s.width * 0.34, s.height * 0.34)
      ..lineTo(0, s.height * 0.34 * 0.0)
      ..close();
    canvas.drawPath(fold, Paint()..color = const Color(0x22FFFFFF));
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _TriBand extends StatelessWidget {
  const _TriBand();
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 7,
        child: Row(children: const [
          Expanded(flex: 60, child: ColoredBox(color: _green, child: SizedBox.expand())),
          Expanded(flex: 25, child: ColoredBox(color: _yellow, child: SizedBox.expand())),
          Expanded(flex: 15, child: ColoredBox(color: _red, child: SizedBox.expand())),
        ]),
      );
}

// ═════════════════════════════════════════════════════════════════════════════
// Texte qui s'adapte à la place
// ═════════════════════════════════════════════════════════════════════════════

/// Texte dont la taille diminue jusqu'à tenir dans l'espace disponible ; au minimum, il est tronqué proprement.
class _FitText extends StatelessWidget {
  const _FitText({required this.text, required this.style, required this.maxSize, required this.minSize, this.glow = false});
  final String text;
  final TextStyle style;
  final double maxSize;
  final double minSize;
  final bool glow;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        if (text.trim().isEmpty) return const SizedBox.shrink();
        var size = maxSize;
        final w = c.maxWidth;
        final h = c.maxHeight.isFinite ? c.maxHeight : 10000.0;
        double measure(double s, {int? maxLines}) {
          final tp = TextPainter(
            text: TextSpan(text: text, style: style.copyWith(fontSize: s, height: 1.22)),
            textDirection: TextDirection.ltr,
            maxLines: maxLines,
          )..layout(maxWidth: w);
          return tp.height;
        }

        while (size > minSize && measure(size) > h - 6) {
          size -= 1;
        }
        // Plus petit que le minimum lisible : on limite le nombre de lignes plutôt que de réduire encore
        int? maxLines;
        if (measure(size) > h - 6) {
          final lineH = size * 1.22;
          maxLines = math.max(1, ((h - 6) / lineH).floor());
        }
        final shadows = glow ? [Shadow(color: _green.withOpacity(0.85), blurRadius: 14)] : null;
        return Text(text,
            maxLines: maxLines,
            overflow: maxLines == null ? TextOverflow.visible : TextOverflow.ellipsis,
            style: style.copyWith(fontSize: size, height: 1.22, shadows: shadows));
      });
}

// ═════════════════════════════════════════════════════════════════════════════
// Médias : toujours entiers, bords flous
// ═════════════════════════════════════════════════════════════════════════════

/// Une image montrée EN ENTIER (contain), les bords étant remplis par un flou de la même image.
class FitImage extends StatelessWidget {
  const FitImage({super.key, required this.image});
  final ImageProvider image;

  @override
  Widget build(BuildContext context) => ClipRect(
        child: Stack(fit: StackFit.expand, children: [
          const ColoredBox(color: Color(0xFF111111)),
          Transform.scale(
            scale: 1.3,
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Image(image: image, fit: BoxFit.cover, color: const Color(0x99000000), colorBlendMode: BlendMode.darken, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
            ),
          ),
          Image(image: image, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.image_not_supported_rounded, color: Colors.white54))),
        ]),
      );
}

class _MediaFrame extends StatelessWidget {
  const _MediaFrame({required this.images, required this.layout, required this.ratio, required this.isVideo, required this.theme});
  final List<ImageProvider> images;
  final CardLayout layout;
  final double ratio;
  final bool isVideo;
  final _ThemeOf theme;

  @override
  Widget build(BuildContext context) {
    final multi = images.length > 1;
    Widget inner;
    if (!multi) {
      inner = FitImage(image: images.first);
    } else {
      switch (layout) {
        case CardLayout.polaroid:
          inner = _Polaroids(images: images);
        case CardLayout.film:
          inner = Row(children: [
            for (var i = 0; i < images.length; i++) ...[
              if (i > 0) const SizedBox(width: 3),
              Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(5), child: FitImage(image: images[i]))),
            ]
          ]);
        default:
          inner = _Mosaic(images: images);
      }
    }
    return AspectRatio(
      aspectRatio: ratio,
      child: Container(
        decoration: theme.frameDecoration,
        clipBehavior: Clip.antiAlias,
        child: Stack(fit: StackFit.expand, children: [
          if (layout == CardLayout.polaroid && multi) const ColoredBox(color: Color(0x22000000)),
          inner,
          if (isVideo) const _PlayBadge(),
        ]),
      ),
    );
  }
}

class _PlayBadge extends StatelessWidget {
  const _PlayBadge();
  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.92), shape: BoxShape.circle, boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 10)]),
          child: const Icon(Icons.play_arrow_rounded, color: Color(0xFF1B1B1B), size: 36),
        ),
      );
}

class _Mosaic extends StatelessWidget {
  const _Mosaic({required this.images});
  final List<ImageProvider> images;
  Widget _c(ImageProvider p) => ClipRRect(borderRadius: BorderRadius.circular(5), child: FitImage(image: p));

  @override
  Widget build(BuildContext context) {
    const gap = 3.0;
    switch (images.length) {
      case 2:
        return Row(children: [Expanded(child: _c(images[0])), const SizedBox(width: gap), Expanded(child: _c(images[1]))]);
      case 3:
        return Row(children: [
          Expanded(flex: 2, child: _c(images[0])),
          const SizedBox(width: gap),
          Expanded(child: Column(children: [Expanded(child: _c(images[1])), const SizedBox(height: gap), Expanded(child: _c(images[2]))])),
        ]);
      default:
        return Column(children: [
          Expanded(child: Row(children: [Expanded(child: _c(images[0])), const SizedBox(width: gap), Expanded(child: _c(images[1]))])),
          const SizedBox(height: gap),
          Expanded(child: Row(children: [Expanded(child: _c(images[2])), const SizedBox(width: gap), Expanded(child: _c(images[3]))])),
        ]);
    }
  }
}

class _Polaroids extends StatelessWidget {
  const _Polaroids({required this.images});
  final List<ImageProvider> images;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final n = images.length;
        final side = math.min(c.maxHeight * 0.74, c.maxWidth * 0.46);
        // position (centre, en fraction de la zone) et angle de chaque polaroïd
        final spots = switch (n) {
          2 => const [(-0.24, -0.04, -0.09), (0.24, 0.02, 0.08)],
          3 => const [(-0.3, -0.02, -0.1), (0.3, 0.04, 0.09), (0.0, -0.01, -0.02)],
          _ => const [(-0.3, -0.12, -0.1), (0.3, -0.08, 0.09), (-0.12, 0.12, 0.05), (0.14, 0.1, -0.07)],
        };
        return Stack(children: [
          for (var i = 0; i < n; i++)
            Positioned(
              left: c.maxWidth / 2 + spots[i].$1 * c.maxWidth - side / 2,
              top: c.maxHeight / 2 + spots[i].$2 * c.maxHeight - side / 2 - 4,
              child: Transform.rotate(
                angle: spots[i].$3,
                child: Container(
                  width: side,
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 14),
                  decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 3))]),
                  child: AspectRatio(aspectRatio: 1, child: FitImage(image: images[i])),
                ),
              ),
            ),
        ]);
      });
}

// ═════════════════════════════════════════════════════════════════════════════
// Les quatre styles
// ═════════════════════════════════════════════════════════════════════════════

class _ThemeOf {
  _ThemeOf(this.id);
  final CardStyleId id;

  Color get fg => switch (id) {
        CardStyleId.kente => const Color(0xFFFBF0D4),
        CardStyleId.wax => const Color(0xFF2A1400),
        CardStyleId.neon => const Color(0xFFE8FFF2),
        CardStyleId.bogolan => const Color(0xFF2B1608),
      };
  Color get muted => fg.withOpacity(0.7);
  Color get accent => switch (id) {
        CardStyleId.kente => const Color(0xFFF2B705),
        CardStyleId.wax => const Color(0xFF2A1400),
        CardStyleId.neon => _green,
        CardStyleId.bogolan => const Color(0xFF3A200C),
      };
  Color get qrBorder => switch (id) {
        CardStyleId.kente => const Color(0xFFF2B705),
        CardStyleId.wax => const Color(0xFF2A1400),
        CardStyleId.neon => _green,
        CardStyleId.bogolan => const Color(0xFF3A200C),
      };
  bool get glow => id == CardStyleId.neon;
  String get headFont => switch (id) {
        CardStyleId.kente => 'CrimsonText',
        CardStyleId.wax => 'Righteous',
        CardStyleId.neon => 'Audiowide',
        CardStyleId.bogolan => 'Arvo',
      };

  TextStyle get textStyle => switch (id) {
        CardStyleId.kente => TextStyle(color: fg, fontFamily: 'CrimsonText', fontWeight: FontWeight.w600),
        CardStyleId.wax => TextStyle(color: fg, fontFamily: 'Righteous'),
        CardStyleId.neon => TextStyle(color: fg, fontFamily: 'Audiowide'),
        CardStyleId.bogolan => TextStyle(color: fg, fontFamily: 'Arvo', fontWeight: FontWeight.w700),
      };

  EdgeInsets get padding => switch (id) {
        CardStyleId.kente => const EdgeInsets.fromLTRB(22, 42, 22, 44),
        CardStyleId.wax => const EdgeInsets.all(0),
        CardStyleId.neon => const EdgeInsets.fromLTRB(30, 26, 30, 24),
        CardStyleId.bogolan => const EdgeInsets.all(0),
      };

  BoxDecoration get frameDecoration => switch (id) {
        CardStyleId.kente => BoxDecoration(border: Border.all(color: const Color(0xFFF2B705), width: 3), borderRadius: BorderRadius.circular(14)),
        CardStyleId.wax => BoxDecoration(border: Border.all(color: const Color(0xFF2A1400), width: 4), borderRadius: BorderRadius.circular(16)),
        CardStyleId.neon => BoxDecoration(border: Border.all(color: _green, width: 1.5), borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: _green.withOpacity(0.5), blurRadius: 16)]),
        CardStyleId.bogolan => BoxDecoration(border: Border.all(color: const Color(0xFF3A200C), width: 4), borderRadius: BorderRadius.circular(6)),
      };

  Widget background(Size s) => switch (id) {
        CardStyleId.kente => Stack(fit: StackFit.expand, children: [
            const ColoredBox(color: Color(0xFF17120D)),
            Positioned(left: 0, right: 0, top: 0, height: 30, child: CustomPaint(painter: _KentePainter())),
            Positioned(left: 0, right: 0, top: 30, height: 4, child: const ColoredBox(color: Color(0xFFF2B705))),
            Positioned(left: 0, right: 0, bottom: 7, height: 4, child: const ColoredBox(color: Color(0xFFF2B705))),
            Positioned(left: 0, right: 0, bottom: 11, height: 30, child: CustomPaint(painter: _KentePainter())),
          ]),
        CardStyleId.wax => CustomPaint(painter: _WaxPainter(), size: s),
        CardStyleId.neon => CustomPaint(painter: _NeonPainter(), size: s),
        CardStyleId.bogolan => CustomPaint(painter: _BogolanPainter(), size: s),
      };

  /// Enveloppe le contenu : un panneau intérieur pour Wax et Bogolan.
  Widget wrap(Widget content) => switch (id) {
        CardStyleId.wax => Padding(
            padding: const EdgeInsets.fromLTRB(17, 17, 17, 25),
            child: DecoratedBox(
              decoration: BoxDecoration(color: const Color(0xFFFFFAF0), borderRadius: BorderRadius.circular(22), boxShadow: const [BoxShadow(color: Color(0xFF2A1400), offset: Offset(0, 8))]),
              child: Padding(padding: const EdgeInsets.fromLTRB(18, 18, 18, 16), child: content),
            ),
          ),
        CardStyleId.bogolan => Padding(
            padding: const EdgeInsets.all(22),
            child: DecoratedBox(
              decoration: BoxDecoration(color: const Color(0xFFF3E3C4), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF3A200C), width: 4)),
              child: Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 14), child: content),
            ),
          ),
        CardStyleId.neon => DecoratedBox(
            decoration: const BoxDecoration(),
            child: content,
          ),
        _ => content,
      };
}

class _KentePainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    const colors = [Color(0xFFF2B705), Color(0xFF1AA24E), Color(0xFFC8321E), Color(0xFF121212)];
    const w = 26.0;
    var i = 0;
    for (double x = 0; x < s.width; x += w, i++) {
      c.drawRect(Rect.fromLTWH(x, 0, w, s.height), Paint()..color = colors[i % 4]);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _WaxPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    c.drawRect(Offset.zero & s, Paint()..color = const Color(0xFFE8590C));
    const cell = 121.0;
    const rings = [
      (60.5, Color(0xFFC2255C)),
      (46.0, Color(0xFFFFF3BF)),
      (32.0, Color(0xFF0B7285)),
      (16.0, Color(0xFFFFD43B)),
    ];
    for (double y = cell / 2 - cell; y < s.height + cell; y += cell) {
      for (double x = cell / 2 - cell; x < s.width + cell; x += cell) {
        for (final r in rings) {
          c.drawCircle(Offset(x, y), r.$1, Paint()..color = r.$2);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _NeonPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    c.drawRect(Offset.zero & s, Paint()..color = const Color(0xFF04070A));
    final glow = Paint()
      ..shader = ui.Gradient.radial(Offset(s.width / 2, s.height * 1.08), s.width * 0.9, [_green.withOpacity(0.55), Colors.transparent]);
    c.drawRect(Offset.zero & s, glow);
    final line = Paint()
      ..color = _green.withOpacity(0.14)
      ..strokeWidth = 1;
    for (double x = 0; x < s.width; x += 32) {
      c.drawLine(Offset(x, 0), Offset(x, s.height), line);
    }
    for (double y = 0; y < s.height; y += 32) {
      c.drawLine(Offset(0, y), Offset(s.width, y), line);
    }
    final rr = RRect.fromRectAndRadius(Rect.fromLTWH(12, 12, s.width - 24, s.height - 24), const Radius.circular(20));
    c.drawRRect(rr, Paint()..color = _green.withOpacity(0.5)..style = PaintingStyle.stroke..strokeWidth = 6..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    c.drawRRect(rr, Paint()..color = _green..style = PaintingStyle.stroke..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _BogolanPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    c.drawRect(Offset.zero & s, Paint()..color = const Color(0xFFC98B4B));
    final p = Paint()
      ..color = const Color(0xFF3A200C)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.square;
    const step = 37.0;
    for (double y = 0; y < s.height + step; y += step) {
      for (double x = 0; x < s.width + step; x += step) {
        c.drawLine(Offset(x, y), Offset(x + step, y + step), p);
        c.drawLine(Offset(x + step, y), Offset(x, y + step), p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
