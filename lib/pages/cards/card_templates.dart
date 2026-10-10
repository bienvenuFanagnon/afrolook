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
    final body = t.isWish
        ? _WishBody(args: args, ink: ink)
        : t == CardTemplateId.quote
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

/// Carte de vœux (anniversaire, mariage, félicitations, condoléances) : intitulé, photo ronde, prénom en grand, message, signature.
/// La photo se zoome et se déplace au doigt comme sur les autres cartes.
class _WishBody extends StatelessWidget {
  const _WishBody({required this.args, required this.ink});
  final _Args args;
  final _PosterInk ink;

  @override
  Widget build(BuildContext context) {
    final spec = args.spec, theme = args.theme;
    final t = spec.template!;
    final heading = spec.field('heading');
    final name = spec.field('name');
    final date = spec.field('date');
    final message = spec.field('message');
    final from = spec.field('from');
    final sober = t == CardTemplateId.condolence;
    final headStyle = args.style(TextStyle(
        fontFamily: theme.headFont,
        color: ink.fg,
        fontWeight: FontWeight.w800));
    final nameStyle = args.style(TextStyle(
        fontFamily: theme.headFont,
        color: ink.accent,
        fontWeight: FontWeight.w900));
    final bodyStyle = args.style(TextStyle(
        color: ink.fg.withOpacity(0.92),
        fontWeight: FontWeight.w500,
        fontStyle: FontStyle.italic));
    return LayoutBuilder(builder: (context, box) {
      final tall = box.maxHeight > 250;
      return ClipRect(
        child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(t.icon, size: 20, color: ink.accent),
            if (!sober) ...[
              const SizedBox(width: 6),
              Icon(Icons.auto_awesome_rounded, size: 14, color: ink.accent)
            ],
          ]),
          const SizedBox(height: 4),
          if (heading.isNotEmpty)
            SizedBox(
              height: tall ? 46 : 34,
              width: double.infinity,
              child: _FitText(
                  text: heading,
                  style: headStyle,
                  maxSize: sober ? 22 : 26,
                  minSize: 13,
                  align: TextAlign.center,
                  glow: theme.glow),
            ),
          if (args.hasImage) ...[
            const SizedBox(height: 6),
            Expanded(
              flex: 5,
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: ink.accent, width: 3)),
                    clipBehavior: Clip.antiAlias,
                    child: ClipOval(child: args.fit(0)),
                  ),
                ),
              ),
            ),
          ],
          if (args.hasImage)
            SizedBox(
              height: tall ? 44 : 34,
              width: double.infinity,
              child: _FitText(
                  text: name,
                  style: nameStyle,
                  maxSize: 34,
                  minSize: 14,
                  align: TextAlign.center,
                  glow: theme.glow),
            )
          else
            Expanded(
              flex: 3,
              child: Align(
                alignment: Alignment.center,
                child: SizedBox(
                    width: double.infinity,
                    child: _FitText(
                        text: name,
                        style: nameStyle,
                        maxSize: 44,
                        minSize: 16,
                        align: TextAlign.center,
                        glow: theme.glow)),
              ),
            ),
          if (date.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(date,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: ink.fg.withOpacity(0.8),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4)),
            ),
          if (message.isNotEmpty)
            Expanded(
              flex: args.hasImage ? 3 : 4,
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Align(
                    alignment: Alignment.center,
                    child: _FitText(
                        text: message,
                        style: bodyStyle,
                        maxSize: 16,
                        minSize: 11,
                        align: TextAlign.center)),
              ),
            )
          else
            const Spacer(),
          if (from.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child:
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(width: 18, height: 2, color: ink.accent),
                const SizedBox(width: 8),
                Flexible(
                    child: Text(from,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: ink.accent,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            fontFamily: theme.headFont))),
                const SizedBox(width: 8),
                Container(width: 18, height: 2, color: ink.accent),
              ]),
            ),
        ]),
      );
    });
  }
}
