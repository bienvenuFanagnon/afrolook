part of 'card_canvas.dart';

/// Ce dont un style a besoin pour se dessiner en plus de la taille : la source, les réglages, les drapeaux et les images retenues.
class _Env {
  const _Env({required this.source, required this.spec, required this.flags, required this.images});
  final CardSource source;
  final CardSpec spec;
  final List<String> flags;
  final List<ImageProvider> images;
}

/// Tout ce que reçoit une mise en page propre à un style.
class _Args {
  const _Args({required this.source, required this.spec, required this.theme, required this.text, required this.truncated, required this.images, required this.tags});
  final CardSource source;
  final CardSpec spec;
  final _ThemeOf theme;
  final String text;
  final bool truncated;
  final List<ImageProvider> images;
  final List<String> tags;

  bool get hasImage => images.isNotEmpty;
  String get flag => theme.env.flags.first;
  String get flag2 => theme.env.flags.length > 1 ? theme.env.flags[1] : theme.env.flags.first;

  /// Police choisie par la personne (sinon celle du style).
  TextStyle style(TextStyle base) => spec.font.family == null ? base : base.copyWith(fontFamily: spec.font.family, fontWeight: spec.font.weight);

  /// Pied de carte : statistiques générales, QR et sceau Afrolook.
  Widget footer({bool showPseudo = false, bool hideStats = false}) =>
      _Footer(source: source, spec: spec, theme: theme, truncated: truncated, showPseudo: showPseudo, hideStats: hideStats);

  Widget header() => _Header(source: source, spec: spec, theme: theme);

  Widget media({double? ratio, bool? isVideo}) => _MediaFrame(images: images, layout: spec.layout, ratio: ratio, isVideo: isVideo ?? source.isVideo, theme: theme);
}

/// Les trois statistiques d'une carte, déjà filtrées par les interrupteurs du studio.
class _StatItem {
  const _StatItem(this.kind, this.text);
  final int kind; // 0 j'aime, 1 commentaires, 2 abonnés
  final String text;
}

List<_StatItem> _statsOf(CardSource s, CardSpec spec) => [
      if (spec.showStats)
        _StatItem(0, spec.likesOverride ?? _compact(s.likes)),
      if (spec.showStats)
        _StatItem(1, spec.commentsOverride ?? _compact(s.comments)),
      if (spec.showFollowers &&
          (spec.followersOverride != null || s.followers > 0))
        _StatItem(2, spec.followersOverride ?? _compact(s.followers)),
    ];

/// Description complète d'un style.
class _Look {
  const _Look({
    required this.fg,
    required this.accent,
    required this.qrBorder,
    required this.textStyle,
    required this.frame,
    required this.bg,
    this.headFont = 'Roboto',
    this.padding = EdgeInsets.zero,
    this.glow = false,
    this.wrap,
    this.layout,
  });
  final Color fg;
  final Color accent;
  final Color qrBorder;
  final TextStyle textStyle;
  final BoxDecoration frame;
  final String headFont;
  final EdgeInsets padding;
  final bool glow;
  final Widget Function(Size size, _Env env) bg;

  /// Panneau autour du contenu standard (Wax, Bogolan, Glass…).
  final Widget Function(Widget content, _Env env)? wrap;

  /// Mise en page propre au style ; absente : en-tête, texte, média, pied.
  final Widget Function(_Args a)? layout;
}

class _ThemeOf {
  _ThemeOf(this.id, this.env) : look = _lookOf(id);
  final CardStyleId id;
  final _Env env;
  final _Look look;

  Color get fg => look.fg;
  Color get muted => fg.withOpacity(0.7);
  Color get accent => look.accent;
  Color get qrBorder => look.qrBorder;
  bool get glow => look.glow;
  String get headFont => look.headFont;
  TextStyle get textStyle => look.textStyle;
  EdgeInsets get padding => look.padding;
  BoxDecoration get frameDecoration => look.frame;
  Widget background(Size s) => look.bg(s, env);
  Widget wrap(Widget content) => look.wrap == null ? content : look.wrap!(content, env);
}

BoxDecoration _frame(Color c, double w, double r, {List<BoxShadow>? shadow}) => BoxDecoration(border: Border.all(color: c, width: w), borderRadius: BorderRadius.circular(r), boxShadow: shadow);

/// Panneau intérieur plein (Wax, Bogolan) ou translucide (Glass).
Widget _panel(Widget content, {required EdgeInsets margin, required EdgeInsets padding, required BoxDecoration deco}) =>
    Padding(padding: margin, child: DecoratedBox(decoration: deco, child: Padding(padding: padding, child: content)));

/// Panneau de verre : le fond de la carte est flouté derrière lui.
Widget _glass(Widget content, {required EdgeInsets margin, double radius = 22, Color tint = const Color(0x55000000), Color border = const Color(0x66FFFFFF)}) => Padding(
      padding: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(radius), border: Border.all(color: border, width: 1.2)),
            child: content,
          ),
        ),
      ),
    );

/// Fond flou de la première image (Glass, Musique), ou un dégradé à défaut d'image.
Widget _blurBg(_Env env, {required List<Color> fallback, double dark = 0.35, double blur = 28, Color tint = const Color(0x00000000)}) => Stack(fit: StackFit.expand, children: [
      if (env.images.isEmpty)
        DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: fallback)))
      else ...[
        const ColoredBox(color: Color(0xFF111111)),
        Transform.scale(
          scale: 1.4,
          child: ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
            child: Image(image: env.images.first, fit: BoxFit.cover, color: Color.fromRGBO(0, 0, 0, dark), colorBlendMode: BlendMode.darken, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
          ),
        ),
      ],
      ColoredBox(color: tint),
    ]);

const _kenteLook = _Look(
  fg: Color(0xFFFBF0D4),
  accent: Color(0xFFF2B705),
  qrBorder: Color(0xFFF2B705),
  headFont: 'CrimsonText',
  textStyle: TextStyle(color: Color(0xFFFBF0D4), fontFamily: 'CrimsonText', fontWeight: FontWeight.w600),
  padding: EdgeInsets.fromLTRB(22, 42, 22, 44),
  frame: BoxDecoration(border: Border.fromBorderSide(BorderSide(color: Color(0xFFF2B705), width: 3)), borderRadius: BorderRadius.all(Radius.circular(14))),
  bg: _kenteBg,
);

Widget _kenteBg(Size s, _Env e) => Stack(fit: StackFit.expand, children: [
      const ColoredBox(color: Color(0xFF17120D)),
      Positioned(left: 0, right: 0, top: 0, height: 30, child: CustomPaint(painter: _KentePainter())),
      const Positioned(left: 0, right: 0, top: 30, height: 4, child: ColoredBox(color: Color(0xFFF2B705))),
      const Positioned(left: 0, right: 0, bottom: 7, height: 4, child: ColoredBox(color: Color(0xFFF2B705))),
      Positioned(left: 0, right: 0, bottom: 11, height: 30, child: CustomPaint(painter: _KentePainter())),
    ]);

_Look _lookOf(CardStyleId id) => switch (id) {
      CardStyleId.kente => _kenteLook,
      CardStyleId.wax => _Look(
          fg: const Color(0xFF2A1400),
          accent: const Color(0xFF2A1400),
          qrBorder: const Color(0xFF2A1400),
          headFont: 'Righteous',
          textStyle: const TextStyle(color: Color(0xFF2A1400), fontFamily: 'Righteous'),
          frame: _frame(const Color(0xFF2A1400), 4, 16),
          bg: (s, e) => CustomPaint(painter: _WaxPainter(), size: s),
          wrap: (c, e) => _panel(c,
              margin: const EdgeInsets.fromLTRB(17, 17, 17, 25),
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
              deco: BoxDecoration(color: const Color(0xFFFFFAF0), borderRadius: BorderRadius.circular(22), boxShadow: const [BoxShadow(color: Color(0xFF2A1400), offset: Offset(0, 8))])),
        ),
      CardStyleId.neon => _Look(
          fg: const Color(0xFFE8FFF2),
          accent: _green,
          qrBorder: _green,
          headFont: 'Audiowide',
          textStyle: const TextStyle(color: Color(0xFFE8FFF2), fontFamily: 'Audiowide'),
          glow: true,
          padding: const EdgeInsets.fromLTRB(30, 26, 30, 24),
          frame: BoxDecoration(border: Border.all(color: _green, width: 1.5), borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: _green.withOpacity(0.5), blurRadius: 16)]),
          bg: (s, e) => CustomPaint(painter: _NeonPainter(), size: s),
        ),
      CardStyleId.bogolan => _Look(
          fg: const Color(0xFF2B1608),
          accent: const Color(0xFF3A200C),
          qrBorder: const Color(0xFF3A200C),
          headFont: 'Arvo',
          textStyle: const TextStyle(color: Color(0xFF2B1608), fontFamily: 'Arvo', fontWeight: FontWeight.w700),
          frame: _frame(const Color(0xFF3A200C), 4, 6),
          bg: (s, e) => CustomPaint(painter: _BogolanPainter(), size: s),
          wrap: (c, e) => _panel(c,
              margin: const EdgeInsets.all(22),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              deco: BoxDecoration(color: const Color(0xFFF3E3C4), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF3A200C), width: 4))),
        ),
      CardStyleId.glass => _Look(
          fg: Colors.white,
          accent: const Color(0xFFFFFFFF),
          qrBorder: const Color(0xFFFFFFFF),
          textStyle: const TextStyle(color: Colors.white, fontFamily: 'Roboto', fontWeight: FontWeight.w600),
          frame: _frame(const Color(0x88FFFFFF), 1.5, 16),
          bg: (s, e) => _blurBg(e, fallback: const [Color(0xFF7C5CFF), Color(0xFFFF6FA3), Color(0xFFFFB86B)], dark: 0.28, blur: 30),
          wrap: (c, e) => _glass(c, margin: const EdgeInsets.fromLTRB(16, 16, 16, 24)),
        ),
      CardStyleId.pro => _Look(
          fg: const Color(0xFF0F1B2D),
          accent: const Color(0xFF2B6CB0),
          qrBorder: const Color(0xFF0F1B2D),
          textStyle: const TextStyle(color: Color(0xFF0F1B2D), fontFamily: 'Roboto', fontWeight: FontWeight.w600),
          frame: _frame(const Color(0xFFD5DAE2), 1.5, 8),
          bg: (s, e) => Stack(fit: StackFit.expand, children: [
            const ColoredBox(color: Color(0xFFF7F8FA)),
            const Positioned(left: 0, top: 0, bottom: 0, width: 10, child: ColoredBox(color: Color(0xFF0F1B2D))),
            const Positioned(left: 10, top: 0, bottom: 0, width: 3, child: ColoredBox(color: Color(0xFF2B6CB0))),
          ]),
          padding: const EdgeInsets.fromLTRB(32, 22, 22, 22),
        ),
      CardStyleId.y2k => _Look(
          fg: const Color(0xFF2B1B5A),
          accent: const Color(0xFF7C5CFF),
          qrBorder: const Color(0xFF2B1B5A),
          textStyle: const TextStyle(color: Color(0xFF2B1B5A), fontFamily: 'Roboto', fontWeight: FontWeight.w700),
          frame: _frame(const Color(0xFF2B1B5A), 2.5, 4),
          bg: (s, e) => Stack(fit: StackFit.expand, children: [
            const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFC9B8FF), Color(0xFFFFC9E6), Color(0xFFFFE9F5)]))),
            CustomPaint(painter: _DotsPainter(color: const Color(0x99FFFFFF), step: 22, radius: 2)),
          ]),
          wrap: (c, e) => Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: DecoratedBox(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF2B1B5A), width: 3), boxShadow: const [BoxShadow(color: Color(0xFF2B1B5A), offset: Offset(6, 6))]),
              child: Column(children: [
                Container(
                  height: 26,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF7C5CFF), Color(0xFFFF6BC1)]), borderRadius: BorderRadius.vertical(top: Radius.circular(6))),
                  child: const Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('post.exe', style: TextStyle(color: Colors.white, fontFamily: 'PressStart2P', fontSize: 9)),
                    Text('_ □ ✕', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                  ]),
                ),
                Expanded(child: Padding(padding: const EdgeInsets.fromLTRB(14, 12, 14, 10), child: c)),
              ]),
            ),
          ),
        ),
      CardStyleId.flag => _Look(
          fg: Colors.white,
          accent: Colors.white,
          qrBorder: Colors.white,
          textStyle: const TextStyle(color: Colors.white, fontFamily: 'Roboto', fontWeight: FontWeight.w700),
          frame: _frame(const Color(0x99FFFFFF), 1.5, 14),
          bg: (s, e) => Stack(fit: StackFit.expand, children: [CardFlag(e.flags.first), CustomPaint(painter: _WavePainter())]),
          wrap: (c, e) => _glass(c, margin: const EdgeInsets.fromLTRB(16, 16, 16, 24), tint: const Color(0x66000000)),
        ),
      _ => _layoutLooks[id]!,
    };
