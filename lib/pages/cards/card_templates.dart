part of 'card_canvas.dart';

/// Couleurs lisibles de l'affiche : le style donne sa palette, sauf pour les fonds clairs ou chargés où l'on corrige.
class _PosterInk {
  const _PosterInk(this.fg, this.accent, this.scrim);
  final Color fg;
  final Color accent;

  /// Fond très chargé (drapeaux, rayons manga) : un panneau sombre translucide passe derrière le texte.
  final bool scrim;

  static _PosterInk of(_ThemeOf theme) {
    switch (theme.id) {
      case CardStyleId.passport:
        return const _PosterInk(Color(0xFF14233D), Color(0xFF1E3A8A), false);
      case CardStyleId.duo:
      case CardStyleId.manga:
        return const _PosterInk(Colors.white, Color(0xFFF2B705), true);
      default:
        return _PosterInk(theme.fg, theme.accent, false);
    }
  }
}

/// Noir ou blanc, selon ce qui se lit le mieux sur [c].
Color _onColor(Color c) =>
    c.computeLuminance() > 0.45 ? const Color(0xFF121212) : Colors.white;

/// Mise en page « affiche » des cartes à modèle (événement, promo, annonce, citation).
/// Elle est la même pour tous les styles : le style apporte le fond, le cadre, les couleurs et la police.
class _TemplateContent extends StatelessWidget {
  const _TemplateContent({required this.args});
  final _Args args;

  @override
  Widget build(BuildContext context) {
    final spec = args.spec, theme = args.theme, source = args.source;
    final t = spec.template!;
    final compact = spec.format == CardFormat.square && args.hasImage;
    final ink = _PosterInk.of(theme);
    final body = t == CardTemplateId.quote
        ? _QuoteBody(args: args, ink: ink)
        : _PosterBody(args: args, compact: compact, ink: ink);
    final header = spec.showAuthor && !compact
        ? _Header(source: source, spec: spec, theme: theme)
        : null;
    final footer =
        args.footer(showPseudo: compact && spec.showAuthor, hideStats: true);
    final Widget content = ink.scrim
        // fond très chargé : le pseudo et le texte passent ensemble sur un panneau sombre
        ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: const Color(0xCC000000),
                    borderRadius: BorderRadius.circular(14)),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (header != null) ...[
                        header,
                        const SizedBox(height: 8)
                      ],
                      Expanded(child: body),
                    ]),
              ),
            ),
            const SizedBox(height: 8),
            footer,
          ])
        : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (header != null) ...[header, const SizedBox(height: 8)],
            Expanded(child: body),
            const SizedBox(height: 8),
            footer,
          ]);
    // certains styles (passeport) dessinent leur cadre eux-mêmes et n'ont pas de marge : on en ajoute une
    return theme.padding == EdgeInsets.zero
        ? Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8), child: content)
        : content;
  }
}

/// Événement, promo, annonce : pastille du modèle, grand titre, offre, lignes d'information, image facultative.
class _PosterBody extends StatelessWidget {
  const _PosterBody(
      {required this.args, required this.compact, required this.ink});
  final _Args args;
  final bool compact;
  final _PosterInk ink;

  @override
  Widget build(BuildContext context) {
    final spec = args.spec, theme = args.theme;
    final t = spec.template!;
    final title = spec.field('title');
    final offer = spec.field('offer');
    final rows = [
      for (final f in t.fields)
        if (!f.main && f.key != 'offer' && spec.field(f.key).isNotEmpty) f,
    ];
    final headStyle = args.style(TextStyle(
        fontFamily: theme.headFont,
        color: ink.fg,
        fontWeight: FontWeight.w900));
    final body = TextStyle(
        color: ink.fg,
        fontSize: 14.5,
        fontWeight: FontWeight.w600,
        height: 1.25);
    return LayoutBuilder(builder: (context, box) {
      // Place disponible : on garde la photo seulement s'il reste de quoi la montrer après le titre et les lignes d'information.
      final fixed = 34.0 +
          (offer.isNotEmpty ? (compact ? 42.0 : 54.0) : 0) +
          rows.length * 24.0 +
          (rows.any((f) => f.lines > 1) ? 20.0 : 0);
      final showImage = args.hasImage && box.maxHeight - fixed - 40 >= 62;
      // hauteur prise par le bandeau et l'offre : les lignes d'information se coupent proprement si la place manque
      final fixedNoRows =
          34.0 + 6 + (offer.isNotEmpty ? (compact ? 42.0 : 54.0) : 0);
      return ClipRect(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
              color: ink.accent, borderRadius: BorderRadius.circular(6)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(t.icon, size: 14, color: _onColor(ink.accent)),
            const SizedBox(width: 5),
            Text(tr(t.label).toUpperCase(),
                style: TextStyle(
                    color: _onColor(ink.accent),
                    fontWeight: FontWeight.w900,
                    fontSize: 11.5,
                    letterSpacing: 1,
                    fontFamily: 'Roboto')),
          ]),
        ),
        const SizedBox(height: 8),
        Expanded(
          flex: showImage ? 3 : 5,
          child: Align(
              alignment: Alignment.centerLeft,
              child: _FitText(
                  text: title,
                  style: headStyle,
                  maxSize: 34,
                  minSize: 15,
                  glow: theme.glow)),
        ),
        if (offer.isNotEmpty) ...[
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(offer,
                maxLines: 1,
                style: TextStyle(
                    color: ink.accent,
                    fontFamily: theme.headFont,
                    fontWeight: FontWeight.w900,
                    fontSize: compact ? 34 : 46,
                    height: 1.05)),
          ),
        ],
        if (rows.isNotEmpty) ...[
          const SizedBox(height: 6),
          // si la place manque (format carré), les dernières lignes sont coupées proprement au lieu de déborder
          ConstrainedBox(
            constraints: BoxConstraints(
                maxHeight: math.max(0.0,
                    box.maxHeight - fixedNoRows - 40 - (showImage ? 66 : 0))),
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final f in rows)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                  padding: const EdgeInsets.only(top: 1),
                                  child: Icon(f.icon,
                                      size: 16, color: ink.accent)),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: Text(spec.field(f.key),
                                      maxLines: f.lines > 1 ? 3 : 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: body)),
                            ]),
                      ),
                  ]),
            ),
          ),
        ],
        if (showImage) ...[
          const SizedBox(height: 4),
          Expanded(flex: 3, child: args.media(ratio: null)),
        ],
      ]));
    });
  }
}

/// Citation : grands guillemets, texte ajusté à l'espace, auteur.
class _QuoteBody extends StatelessWidget {
  const _QuoteBody({required this.args, required this.ink});
  final _Args args;
  final _PosterInk ink;

  @override
  Widget build(BuildContext context) {
    final spec = args.spec, theme = args.theme;
    final quote = spec.field('quote');
    final author = spec.field('author');
    final style = args.style(TextStyle(
        fontFamily: theme.headFont,
        color: ink.fg,
        fontWeight: FontWeight.w800));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('“',
          style: TextStyle(
              color: ink.accent,
              fontSize: 64,
              height: 0.8,
              fontWeight: FontWeight.w900,
              fontFamily: 'Roboto')),
      Expanded(
        flex: args.hasImage ? 2 : 4,
        child: Align(
            alignment: Alignment.centerLeft,
            child: _FitText(
                text: quote,
                style: style,
                maxSize: 30,
                minSize: 14,
                glow: theme.glow)),
      ),
      if (author.isNotEmpty) ...[
        const SizedBox(height: 6),
        Row(children: [
          Container(
              width: 26,
              height: 3,
              decoration: BoxDecoration(
                  color: ink.accent, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Expanded(
              child: Text(author,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: ink.accent,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      fontFamily: theme.headFont))),
        ]),
      ],
      if (args.hasImage) ...[
        const SizedBox(height: 8),
        Expanded(flex: 2, child: args.media(ratio: null)),
      ],
    ]);
  }
}
