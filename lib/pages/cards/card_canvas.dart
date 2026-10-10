import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../l10n/tr.dart';
import 'card_flags.dart';
import 'card_models.dart';
import 'card_text.dart';

part 'card_layouts.dart';
part 'card_looks.dart';
part 'card_painters.dart';
part 'card_templates.dart';

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
/// - la signature Afrolook (bande tricolore, sceau « Créé sur Afrolook », QR) est identique sur tous les styles.
class CardCanvas extends StatelessWidget {
  const CardCanvas(
      {super.key,
      required this.source,
      required this.spec,
      this.text,
      this.onAdjust});

  /// Aperçu du studio : pincer ou glisser une image la recadre (clé : indice dans [CardSource.images]).
  /// Null (export, miniatures) : les images sont seulement dessinées avec leur cadrage.
  final void Function(int imageIndex, ImageAdjust adjust)? onAdjust;

  final CardSource source;
  final CardSpec spec;

  /// Texte à afficher (si null : découpe automatique du texte du post selon [spec]).
  final String? text;

  @override
  Widget build(BuildContext context) {
    final size = spec.format.size;
    final selectedIdx = _selectedIndices();
    final selected = [for (final i in selectedIdx) source.images[i]];
    final hasMedia = selected.isNotEmpty;
    final theme = _ThemeOf(
        spec.style,
        _Env(
            source: source,
            spec: spec,
            flags: CardFlags.flagsOf(source, spec),
            images: selected,
            imageIdx: selectedIdx,
            onAdjust: onAdjust));
    final cut = text == null
        ? cardText(source.text, spec, hasMedia: hasMedia)
        : CardCut(text!, false);
    final tags = separateTags(source.text).tags;
    final args = _Args(
        source: source,
        spec: spec,
        theme: theme,
        text: cut.text,
        truncated: cut.truncated,
        images: selected,
        tags: tags);
    final content = spec.template != null
        ? _TemplateContent(args: args)
        : theme.look.layout != null
            ? theme.look.layout!(args)
            : _Content(args: args);

    // la carte est une image : elle ne suit pas la taille de texte choisie dans les réglages du téléphone
    return MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Stack(
              fit: StackFit.expand,
              children: [
                theme.background(size),
                Padding(padding: theme.padding, child: theme.wrap(content)),
                const Positioned(
                    left: 0, right: 0, bottom: 0, child: _TriBand()),
              ],
            ),
          ),
        ));
  }

  List<int> _selectedIndices() {
    if (source.images.isEmpty) return const [];
    final idx = spec.imageOrder
        .where((i) => i >= 0 && i < source.images.length)
        .toList();
    final order = idx.isEmpty
        ? List<int>.generate(math.min(3, source.images.length), (i) => i)
        : idx;
    final list = order.take(CardSpec.maxImages).toList();
    return spec.layout == CardLayout.single ? [list.first] : list;
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Contenu : en-tête, texte, média, pied
// ═════════════════════════════════════════════════════════════════════════════

class _Content extends StatelessWidget {
  const _Content({required this.args});
  final _Args args;

  @override
  Widget build(BuildContext context) {
    final source = args.source,
        spec = args.spec,
        theme = args.theme,
        images = args.images,
        tags = args.tags;
    // Carré avec média : pas de place pour un en-tête, le pseudo passe dans le pied de carte
    final compact = spec.format == CardFormat.square && images.isNotEmpty;
    final style = args.style(theme.textStyle);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (spec.showAuthor && !compact)
          _Header(source: source, spec: spec, theme: theme),
        if (spec.showAuthor && !compact) const SizedBox(height: 8),
        Expanded(
          child: Column(
            children: [
              Expanded(
                child: Align(
                  alignment:
                      images.isEmpty ? Alignment.center : Alignment.centerLeft,
                  child: _FitText(
                      text: args.text,
                      style: style,
                      maxSize: images.isEmpty ? 30 : 22,
                      minSize: 13,
                      glow: theme.glow),
                ),
              ),
              if (images.isNotEmpty) ...[
                const SizedBox(height: 8),
                _MediaFrame(
                    images: images,
                    layout: spec.layout,
                    ratio: spec.format.frameRatio,
                    isVideo: source.isVideo,
                    theme: theme),
              ],
            ],
          ),
        ),
        if (tags.isNotEmpty && spec.format != CardFormat.square)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(tags.take(3).join('  '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: theme.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
        const SizedBox(height: 8),
        args.footer(showPseudo: compact && spec.showAuthor),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(
      {required this.source, required this.spec, required this.theme});
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
        decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: theme.accent, width: 2),
            color: const Color(0xFF3A3A3A)),
        child: ClipOval(
          child: source.avatar != null
              ? Image(
                  image: source.avatar!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _initial())
              : _initial(),
        ),
      ),
      const SizedBox(width: 9),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Flexible(
              child: Text('@${source.pseudo}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: theme.fg,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      fontFamily: theme.headFont)),
            ),
            if (source.verified)
              const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Icon(Icons.verified_rounded,
                      color: Color(0xFF2196F3), size: 17)),
          ]),
          if (sub.isNotEmpty)
            Text(sub,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: theme.muted, fontSize: 11)),
        ]),
      ),
    ]);
  }

  Widget _initial() => Center(
        child: Text(
            source.pseudo.isEmpty
                ? '?'
                : source.pseudo.characters.first.toUpperCase(),
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 16)),
      );
}

const _months = [
  'janv.',
  'févr.',
  'mars',
  'avr.',
  'mai',
  'juin',
  'juil.',
  'août',
  'sept.',
  'oct.',
  'nov.',
  'déc.'
];
String _fmtDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

String _compact(int n) {
  if (n >= 1000000)
    return '${(n / 1000000).toStringAsFixed(n >= 10000000 ? 0 : 1).replaceAll('.0', '')} M';
  if (n >= 1000)
    return '${(n / 1000).toStringAsFixed(n >= 10000 ? 0 : 1).replaceAll('.0', '')} k';
  return '$n';
}

class _Footer extends StatelessWidget {
  const _Footer(
      {required this.source,
      required this.spec,
      required this.theme,
      required this.truncated,
      this.showPseudo = false,
      this.hideStats = false});
  final bool showPseudo;

  /// Les statistiques sont déjà montrées ailleurs dans la mise en page du style.
  final bool hideStats;
  final CardSource source;
  final CardSpec spec;
  final _ThemeOf theme;
  final bool truncated;

  @override
  Widget build(BuildContext context) {
    final link = spec.linkFor(source);
    return SizedBox(
      height: 40,
      child: Row(children: [
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showPseudo)
                    Text('@${source.pseudo}',
                        maxLines: 1,
                        style: TextStyle(
                            color: theme.fg,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            fontFamily: theme.headFont)),
                  if (!hideStats &&
                      (spec.showStats ||
                          (spec.showFollowers &&
                              (spec.followersOverride != null ||
                                  source.followers > 0))))
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      if (spec.showStats) ...[
                        Icon(Icons.favorite_rounded, size: 15, color: theme.fg),
                        const SizedBox(width: 4),
                        Text(spec.likesOverride ?? _compact(source.likes),
                            style: TextStyle(
                                color: theme.fg,
                                fontSize: 13,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(width: 12),
                        Icon(Icons.chat_bubble_rounded,
                            size: 14, color: theme.fg),
                        const SizedBox(width: 4),
                        Text(spec.commentsOverride ?? _compact(source.comments),
                            style: TextStyle(
                                color: theme.fg,
                                fontSize: 13,
                                fontWeight: FontWeight.w700)),
                      ],
                      if (spec.showFollowers &&
                          (spec.followersOverride != null ||
                              source.followers > 0)) ...[
                        if (spec.showStats) const SizedBox(width: 12),
                        Icon(Icons.people_alt_rounded,
                            size: 16, color: theme.fg),
                        const SizedBox(width: 4),
                        Text(spec.followersOverride ?? _compact(source.followers),
                            style: TextStyle(
                                color: theme.fg,
                                fontSize: 13,
                                fontWeight: FontWeight.w700)),
                      ],
                    ]),
                  if (truncated)
                    Text('Lire la suite sur Afrolook ↗',
                        maxLines: 1,
                        style: TextStyle(
                            color: theme.fg.withOpacity(0.9),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700)),
                ]),
          ),
        ),
        Container(
          width: 40,
          height: 40,
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.all(2.5),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: theme.qrBorder, width: 2)),
          child: QrImageView(
              data: link,
              padding: EdgeInsets.zero,
              backgroundColor: Colors.white,
              eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square, color: Color(0xFF111111)),
              dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Color(0xFF111111))),
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
        decoration: BoxDecoration(
            color: _ink,
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: _green, width: 2)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 22,
            height: 22,
            decoration:
                const BoxDecoration(color: _green, shape: BoxShape.circle),
            child: ClipOval(
              child: Image.asset('assets/logo/afrolook_logo.png',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Center(
                      child: Text('A',
                          style: TextStyle(
                              color: _ink,
                              fontWeight: FontWeight.w900,
                              fontSize: 15)))),
            ),
          ),
          const SizedBox(width: 5),
          Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr('Créé sur'),
                    style: const TextStyle(
                        color: Color(0xFFBDBDBD),
                        fontSize: 7.5,
                        fontWeight: FontWeight.w600,
                        height: 1,
                        fontFamily: 'Roboto')),
                const SizedBox(height: 1),
                const Text.rich(
                    TextSpan(children: [
                      TextSpan(
                          text: 'Afro', style: TextStyle(color: Colors.white)),
                      TextSpan(text: 'look', style: TextStyle(color: _yellow)),
                    ]),
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .2,
                        height: 1,
                        fontFamily: 'Roboto')),
              ]),
        ]),
      );
}

class _TriBand extends StatelessWidget {
  const _TriBand();
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 7,
        child: Row(children: const [
          Expanded(
              flex: 60,
              child: ColoredBox(color: _green, child: SizedBox.expand())),
          Expanded(
              flex: 25,
              child: ColoredBox(color: _yellow, child: SizedBox.expand())),
          Expanded(
              flex: 15,
              child: ColoredBox(color: _red, child: SizedBox.expand())),
        ]),
      );
}

// ═════════════════════════════════════════════════════════════════════════════
// Texte qui s'adapte à la place
// ═════════════════════════════════════════════════════════════════════════════

/// Texte dont la taille diminue jusqu'à tenir dans l'espace disponible ; au minimum, il est tronqué proprement.
class _FitText extends StatelessWidget {
  const _FitText(
      {required this.text,
      required this.style,
      required this.maxSize,
      required this.minSize,
      this.glow = false,
      this.shadows,
      this.align = TextAlign.start});
  final String text;
  final TextStyle style;
  final double maxSize;
  final double minSize;
  final bool glow;
  final List<Shadow>? shadows;
  final TextAlign align;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        if (text.trim().isEmpty) return const SizedBox.shrink();
        var size = maxSize;
        // le texte affiché hérite du style par défaut (espacement des lettres…) : on mesure avec le même
        final style = DefaultTextStyle.of(context).style.merge(this.style);
        final w = c.maxWidth;
        final h = c.maxHeight.isFinite ? c.maxHeight : 10000.0;
        double measure(double s, {int? maxLines}) {
          final tp = TextPainter(
            text: TextSpan(
                text: text, style: style.copyWith(fontSize: s, height: 1.22)),
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
        final sh = shadows ??
            (glow
                ? [Shadow(color: _green.withOpacity(0.85), blurRadius: 14)]
                : null);
        return Text(text,
            textAlign: align,
            maxLines: maxLines,
            overflow:
                maxLines == null ? TextOverflow.visible : TextOverflow.ellipsis,
            style: style.copyWith(fontSize: size, height: 1.22, shadows: sh));
      });
}

// ═════════════════════════════════════════════════════════════════════════════
// Médias : toujours entiers, bords flous
// ═════════════════════════════════════════════════════════════════════════════

/// Une image montrée EN ENTIER (contain), les bords étant remplis par un flou de la même image.
/// [adjust] la zoome et la décale ; avec [onAdjust], un pincement ou un glissement la recadre (aperçu du studio).
class FitImage extends StatefulWidget {
  const FitImage({super.key, required this.image, this.adjust, this.onAdjust});
  final ImageProvider image;
  final ImageAdjust? adjust;
  final ValueChanged<ImageAdjust>? onAdjust;

  @override
  State<FitImage> createState() => _FitImageState();
}

class _FitImageState extends State<FitImage> {
  ImageAdjust _start = const ImageAdjust();
  Offset _startFocal = Offset.zero;

  ImageAdjust get _cur => widget.adjust ?? const ImageAdjust();

  @override
  Widget build(BuildContext context) {
    final image = widget.image;
    final a = _cur;
    Widget view = ClipRect(
      child: Stack(fit: StackFit.expand, children: [
        const ColoredBox(color: Color(0xFF111111)),
        Transform.scale(
          scale: 1.3,
          child: ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Image(
                image: image,
                fit: BoxFit.cover,
                color: const Color(0x99000000),
                colorBlendMode: BlendMode.darken,
                errorBuilder: (_, __, ___) => const SizedBox.shrink()),
          ),
        ),
        LayoutBuilder(
          builder: (_, c) => Transform.translate(
            offset: Offset(a.dx * c.maxWidth, a.dy * c.maxHeight),
            child: Transform.scale(
              scale: a.zoom,
              child: Image(
                  image: image,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Center(
                      child: Icon(Icons.image_not_supported_rounded,
                          color: Colors.white54))),
            ),
          ),
        ),
      ]),
    );
    final on = widget.onAdjust;
    if (on == null) return view;
    return LayoutBuilder(
      builder: (_, c) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onScaleStart: (d) {
          _start = _cur;
          _startFocal = d.localFocalPoint;
        },
        onScaleUpdate: (d) {
          final w = c.maxWidth == 0 ? 1.0 : c.maxWidth;
          final h = c.maxHeight == 0 ? 1.0 : c.maxHeight;
          final move = d.localFocalPoint - _startFocal;
          on(_start
              .copyWith(
                  zoom: _start.zoom * d.scale,
                  dx: _start.dx + move.dx / w,
                  dy: _start.dy + move.dy / h)
              .clamped());
        },
        onDoubleTap: () => on(const ImageAdjust()),
        child: view,
      ),
    );
  }
}

class _MediaFrame extends StatelessWidget {
  const _MediaFrame(
      {required this.images,
      required this.layout,
      this.ratio,
      required this.isVideo,
      required this.theme});
  final List<ImageProvider> images;
  final CardLayout layout;

  /// Forme (largeur / hauteur) du cadre ; null : le cadre remplit tout l'espace donné.
  final double? ratio;
  final bool isVideo;
  final _ThemeOf theme;

  @override
  Widget build(BuildContext context) {
    final multi = images.length > 1;
    Widget inner;
    if (!multi) {
      inner = theme.env.fit(0);
    } else {
      switch (layout) {
        case CardLayout.polaroid:
          inner = _Polaroids(images: images, fit: theme.env.fit);
        case CardLayout.film:
          inner = Row(children: [
            for (var i = 0; i < images.length; i++) ...[
              if (i > 0) const SizedBox(width: 3),
              Expanded(
                  child: ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: theme.env.fit(i))),
            ]
          ]);
        default:
          inner = _Mosaic(images: images, fit: theme.env.fit);
      }
    }
    final frame = Container(
      decoration: theme.frameDecoration,
      clipBehavior: Clip.antiAlias,
      child: Stack(fit: StackFit.expand, children: [
        if (layout == CardLayout.polaroid && multi)
          const ColoredBox(color: Color(0x22000000)),
        inner,
        if (isVideo) const _PlayBadge(),
      ]),
    );
    return ratio == null
        ? frame
        : AspectRatio(aspectRatio: ratio!, child: frame);
  }
}

class _PlayBadge extends StatelessWidget {
  const _PlayBadge();
  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.92),
              shape: BoxShape.circle,
              boxShadow: const [
                BoxShadow(color: Colors.black38, blurRadius: 10)
              ]),
          child: const Icon(Icons.play_arrow_rounded,
              color: Color(0xFF1B1B1B), size: 36),
        ),
      );
}

class _Mosaic extends StatelessWidget {
  const _Mosaic({required this.images, required this.fit});
  final List<ImageProvider> images;
  final Widget Function(int pos) fit;
  Widget _c(int i) =>
      ClipRRect(borderRadius: BorderRadius.circular(5), child: fit(i));

  @override
  Widget build(BuildContext context) {
    const gap = 3.0;
    switch (images.length) {
      case 2:
        return Row(children: [
          Expanded(child: _c(0)),
          const SizedBox(width: gap),
          Expanded(child: _c(1))
        ]);
      case 3:
        return Row(children: [
          Expanded(flex: 2, child: _c(0)),
          const SizedBox(width: gap),
          Expanded(
              child: Column(children: [
            Expanded(child: _c(1)),
            const SizedBox(height: gap),
            Expanded(child: _c(2))
          ])),
        ]);
      default:
        return Column(children: [
          Expanded(
              child: Row(children: [
            Expanded(child: _c(0)),
            const SizedBox(width: gap),
            Expanded(child: _c(1))
          ])),
          const SizedBox(height: gap),
          Expanded(
              child: Row(children: [
            Expanded(child: _c(2)),
            const SizedBox(width: gap),
            Expanded(child: _c(3))
          ])),
        ]);
    }
  }
}

class _Polaroids extends StatelessWidget {
  const _Polaroids({required this.images, required this.fit});
  final List<ImageProvider> images;
  final Widget Function(int pos) fit;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final n = images.length;
        final side = math.min(c.maxHeight * 0.74, c.maxWidth * 0.46);
        // position (centre, en fraction de la zone) et angle de chaque polaroïd
        final spots = switch (n) {
          2 => const [(-0.24, -0.04, -0.09), (0.24, 0.02, 0.08)],
          3 => const [
              (-0.3, -0.02, -0.1),
              (0.3, 0.04, 0.09),
              (0.0, -0.01, -0.02)
            ],
          _ => const [
              (-0.3, -0.12, -0.1),
              (0.3, -0.08, 0.09),
              (-0.12, 0.12, 0.05),
              (0.14, 0.1, -0.07)
            ],
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
                  decoration: const BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black54,
                            blurRadius: 8,
                            offset: Offset(0, 3))
                      ]),
                  child: AspectRatio(
                      aspectRatio: 1, child: fit(i)),
                ),
              ),
            ),
        ]);
      });
}
