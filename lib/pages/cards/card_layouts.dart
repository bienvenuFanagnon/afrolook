part of 'card_canvas.dart';

// Mises en page propres aux styles « moderne », « drapeaux » et « idées ». Chaque fonction reçoit les mêmes données
// ([_Args]) et remplit la place qu'on lui donne, quel que soit le format (portrait, story, carré) : on y utilise
// des proportions (`Expanded`), jamais des positions fixes. Les images sont toujours montrées en entier.

TextStyle _t(String font, double size, Color? color, {FontWeight? w, double? ls, double? h, FontStyle? italic, List<Shadow>? shadows}) =>
    TextStyle(fontFamily: font, fontSize: size, color: color, fontWeight: w, letterSpacing: ls, height: h, fontStyle: italic, shadows: shadows);

/// Texte avec un contour (bruitage manga, numéro de maillot).
Widget _outlined(String text, String font, double size, Color fill, Color stroke, {double width = 3, double? ls}) => Stack(children: [
      Text(text, style: TextStyle(fontFamily: font, fontSize: size, letterSpacing: ls, foreground: Paint()..style = PaintingStyle.stroke..strokeWidth = width..strokeJoin = StrokeJoin.round..color = stroke)),
      Text(text, style: TextStyle(fontFamily: font, fontSize: size, letterSpacing: ls, color: fill)),
    ]);

const _gray = ColorFilter.matrix(<double>[
  0.28, 0.93, 0.09, 0, -34, //
  0.28, 0.93, 0.09, 0, -34,
  0.28, 0.93, 0.09, 0, -34,
  0, 0, 0, 1, 0,
]);

String _roman(int n) {
  const t = [(10, 'X'), (9, 'IX'), (5, 'V'), (4, 'IV'), (1, 'I')];
  var out = '';
  for (final e in t) {
    while (n >= e.$1) {
      out += e.$2;
      n -= e.$1;
    }
  }
  return out;
}

int _hash(CardSource s) => (s.postId ?? s.pseudo).codeUnits.fold<int>(7, (a, b) => (a * 31 + b) & 0xFFFFFF);
String _dateOr(CardSource s, String or) => s.date == null ? or : _fmtDate(s.date!);

/// Image de l'auteur, ou son initiale : remplace une photo absente.
Widget _avatarFill(CardSource s) => s.avatar != null
    ? FitImage(image: s.avatar!)
    : ColoredBox(color: const Color(0xFF3A3A3A), child: Center(child: Text(s.pseudo.isEmpty ? '?' : s.pseudo.characters.first.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 46, fontWeight: FontWeight.w800))));

Widget _mediaOrAvatar(_Args a, {double? ratio}) => a.hasImage ? a.media(ratio: ratio) : _avatarFill(a.source);

Widget _iconStats(List<_StatItem> st, Color color, {double size = 13, double gap = 12}) => st.isEmpty
    ? const SizedBox.shrink()
    : FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          for (var i = 0; i < st.length; i++) ...[
            if (i > 0) SizedBox(width: gap),
            Icon([Icons.favorite_rounded, Icons.chat_bubble_rounded, Icons.people_alt_rounded][st[i].kind], size: size + 1, color: color),
            const SizedBox(width: 4),
            Text(st[i].text, style: TextStyle(color: color, fontSize: size, fontWeight: FontWeight.w700, fontFamily: 'Roboto')),
          ]
        ]),
      );

/// « 1,2 k vues · 214 critiques » : les statistiques avec le vocabulaire du style ([words] : j'aime, commentaires, abonnés).
Widget _wordStats(List<_StatItem> st, List<String> words, TextStyle style, {String sep = ' · ', TextAlign align = TextAlign.start}) => st.isEmpty
    ? const SizedBox.shrink()
    : FittedBox(fit: BoxFit.scaleDown, child: Text(st.map((e) => '${e.text} ${tr(words[e.kind])}').join(sep), maxLines: 1, textAlign: align, style: style));

Widget _gap(double h) => SizedBox(height: h);

// ─────────────────────────────────────────────────────────────────────────────
// Moderne
// ─────────────────────────────────────────────────────────────────────────────

Widget _layoutManga(_Args a) {
  final s = a.source;
  return Column(children: [
    if (a.spec.showAuthor)
      Align(
        alignment: Alignment.centerLeft,
        child: Transform.rotate(
          angle: -0.03,
          child: Container(color: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2), child: Text('@${s.pseudo}', style: _t('Bangers', 19, Colors.white, ls: 1))),
        ),
      ),
    _gap(8),
    if (a.hasImage) ...[
      Expanded(
        flex: 5,
        child: Stack(clipBehavior: Clip.none, children: [
          Positioned.fill(
            child: Transform.rotate(angle: -0.012, child: DecoratedBox(decoration: BoxDecoration(border: Border.all(color: Colors.black, width: 4), color: Colors.white), child: ColorFiltered(colorFilter: _gray, child: a.media()))),
          ),
          Positioned(right: 4, bottom: -4, child: Transform.rotate(angle: 0.14, child: _outlined('WOW!', 'Bangers', 40, const Color(0xFFE5484D), Colors.black, width: 5, ls: 1))),
        ]),
      ),
      _gap(10),
      Expanded(
        flex: 2,
        child: Transform.rotate(
          angle: 0.01,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.black, width: 3.5), boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(4, 4))]),
            child: Align(alignment: Alignment.centerLeft, child: _FitText(text: a.text, style: a.style(_t('Bangers', 22, Colors.black, ls: .5)), maxSize: 24, minSize: 12)),
          ),
        ),
      ),
    ] else
      Expanded(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.black, width: 4), borderRadius: BorderRadius.circular(26), boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(5, 5))]),
          child: Center(child: _FitText(text: a.text, style: a.style(_t('Bangers', 30, Colors.black, ls: .5)), maxSize: 36, minSize: 14, align: TextAlign.center)),
        ),
      ),
    _gap(8),
    Container(color: Colors.black, padding: const EdgeInsets.fromLTRB(8, 3, 0, 3), child: a.footer()),
  ]);
}

Widget _layoutAnime(_Args a) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (a.spec.showAuthor) ...[a.header(), _gap(8)],
      if (a.hasImage) Expanded(flex: 5, child: DecoratedBox(decoration: BoxDecoration(boxShadow: const [BoxShadow(color: Color(0x88000000), blurRadius: 14, offset: Offset(0, 6))], borderRadius: BorderRadius.circular(10)), child: a.media())),
      _gap(10),
      Expanded(
        flex: a.hasImage ? 2 : 6,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(color: const Color(0xCC1A0F3A), borderRadius: BorderRadius.circular(12)),
          child: Center(child: _FitText(text: a.text, style: a.style(_t('Roboto', 19, Colors.white, w: FontWeight.w800)), maxSize: a.hasImage ? 20 : 30, minSize: 12, align: TextAlign.center, shadows: const [Shadow(color: Colors.black54, blurRadius: 4)])),
        ),
      ),
      _gap(8),
      Container(decoration: BoxDecoration(color: const Color(0x661A0F3A), borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.fromLTRB(8, 2, 0, 2), child: a.footer()),
    ]);

Widget _layoutMagazine(_Args a) => LayoutBuilder(builder: (context, c) {
      final st = _statsOf(a.source, a.spec);
      final issue = 10 + _hash(a.source) % 40;
      return Stack(fit: StackFit.expand, children: [
        if (a.hasImage) Positioned.fill(child: a.media()),
        const Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xAA000000), Color(0x00000000), Color(0x00000000), Color(0xCC000000)], stops: [0, .3, .5, 1])))),
        Positioned(
          left: 16,
          right: 16,
          top: 12,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text('AFROLOOK', style: _t('AbrilFatface', 60, Colors.white, ls: -1.5, shadows: const [Shadow(color: Colors.black38, offset: Offset(0, 2))]))),
            Row(children: [
              Flexible(child: Text(tr('ÉDITION MODE'), maxLines: 1, overflow: TextOverflow.ellipsis, style: _t('Roboto', 9, Colors.white, w: FontWeight.w800, ls: 2))),
              const Spacer(),
              Flexible(child: Text('N° $issue · ${_dateOr(a.source, '')}', maxLines: 1, overflow: TextOverflow.ellipsis, style: _t('Roboto', 9, Colors.white, w: FontWeight.w800, ls: 1.5))),
            ]),
          ]),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 56,
          height: c.maxHeight * (a.hasImage ? 0.3 : 0.62),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.end, children: [
            Expanded(child: Align(alignment: Alignment.bottomLeft, child: _FitText(text: a.text, style: a.style(_t('AbrilFatface', 30, Colors.white, italic: FontStyle.italic)), maxSize: a.hasImage ? 30 : 44, minSize: 14, shadows: const [Shadow(color: Colors.black54, blurRadius: 6)]))),
            _gap(4),
            _wordStats(st, const ['j\'aime', 'commentaires', 'abonnés'], _t('Roboto', 11, Colors.white, w: FontWeight.w700, ls: .6), sep: '  ·  '),
          ]),
        ),
        Positioned(left: 0, right: 0, bottom: 0, child: Container(color: Colors.black, padding: const EdgeInsets.fromLTRB(14, 4, 0, 11), child: a.footer(hideStats: true))),
      ]);
    });

Widget _layoutCollector(_Args a) {
  final st = _statsOf(a.source, a.spec);
  const labels = ['ATQ', 'DÉF', 'PV'];
  Widget box(_StatItem e) => Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(color: const Color(0x14FFFFFF), borderRadius: BorderRadius.circular(6)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(e.text, style: _t('Rajdhani', 20, Colors.white, w: FontWeight.w700, h: 1)),
            Text(labels[e.kind], style: _t('Rajdhani', 10.5, const Color(0xFF9FB0FF), w: FontWeight.w700, ls: 1.5)),
          ]),
        ),
      );
  return DecoratedBox(
    decoration: BoxDecoration(color: const Color(0xFF10131F), borderRadius: BorderRadius.circular(16)),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
      child: Column(children: [
        Padding(
          padding: EdgeInsets.zero,
          child: Row(children: [
            Expanded(child: Text('@${a.source.pseudo}', maxLines: 1, overflow: TextOverflow.ellipsis, style: _t('Rajdhani', 20, Colors.white, w: FontWeight.w700))),
            if (a.source.verified) const Icon(Icons.verified_rounded, color: Color(0xFF2196F3), size: 16),
            const SizedBox(width: 6),
            Row(mainAxisSize: MainAxisSize.min, children: [for (var i = 0; i < 3; i++) const Icon(Icons.star_rounded, color: Color(0xFFFFC53D), size: 13)]),
          ]),
        ),
        _gap(6),
        Expanded(
          flex: 6,
          child: Stack(fit: StackFit.expand, children: [
            Container(decoration: BoxDecoration(border: Border.all(color: const Color(0xFFFFC53D), width: 3), color: const Color(0xFF1C2340)), clipBehavior: Clip.hardEdge, child: _mediaOrAvatar(a)),
            const IgnorePointer(child: Opacity(opacity: 0.28, child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0x00FFFFFF), Color(0xFFFFFFFF), Color(0xFFFF7BE6), Color(0xFF6BF0FF), Color(0x00FFFFFF)], stops: [.15, .38, .5, .62, .85]))))),
          ]),
        ),
        _gap(6),
        Expanded(
          flex: 3,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: const Color(0x14FFFFFF), borderRadius: BorderRadius.circular(8)),
            child: Align(alignment: Alignment.centerLeft, child: _FitText(text: a.text, style: a.style(_t('Rajdhani', 17, Colors.white, w: FontWeight.w600)), maxSize: 19, minSize: 11)),
          ),
        ),
        if (st.isNotEmpty) ...[_gap(6), Row(children: [for (final e in st) box(e)])],
        _gap(4),
        a.footer(hideStats: true),
      ]),
    ),
  );
}

class _ParallelogramClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size s) => Path()
    ..moveTo(0, 0)
    ..lineTo(s.width, 0)
    ..lineTo(s.width * 0.88, s.height)
    ..lineTo(0, s.height)
    ..close();
  @override
  bool shouldReclip(covariant CustomClipper<Path> old) => false;
}

Widget _layoutSport(_Args a) {
  final st = _statsOf(a.source, a.spec);
  final jersey = 1 + _hash(a.source) % 99;
  const words = ['LIKES', 'COMMENTS', 'ABONNÉS'];
  return Column(children: [
    Expanded(
      flex: 5,
      child: Stack(clipBehavior: Clip.none, children: [
        Positioned(right: 0, top: -14, child: Text('$jersey', style: TextStyle(fontFamily: 'Anton', fontSize: 130, height: 1, foreground: Paint()..style = PaintingStyle.stroke..strokeWidth = 1.5..color = const Color(0x66FFFFFF)))),
        Row(children: [
          Expanded(flex: 6, child: ClipPath(clipper: _ParallelogramClipper(), child: DecoratedBox(decoration: const BoxDecoration(color: Color(0x44000000)), child: _mediaOrAvatar(a)))),
          _gap(0),
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.only(left: 10, top: 34),
              child: Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisAlignment: MainAxisAlignment.start, children: [
                for (final e in st) ...[
                  Text(e.text.replaceAll(' ', '').toUpperCase(), style: _t('Anton', 28, Colors.white, h: 1)),
                  Text(tr(words[e.kind]), style: _t('Roboto', 9, const Color(0xCCFFFFFF), w: FontWeight.w700, ls: 1.5)),
                  _gap(8),
                ],
                if (st.isEmpty && a.spec.showAuthor) Text('@${a.source.pseudo}', textAlign: TextAlign.right, style: _t('Anton', 20, Colors.white, h: 1.1)),
              ]),
            ),
          ),
        ]),
      ]),
    ),
    _gap(8),
    Expanded(
      flex: 4,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
        decoration: const BoxDecoration(color: Color(0xE006142D), border: Border(left: BorderSide(color: Color(0xFFFF5A1F), width: 5))),
        child: Align(alignment: Alignment.centerLeft, child: _FitText(text: a.text, style: a.style(_t('Anton', 24, Colors.white, ls: .3)), maxSize: 30, minSize: 12)),
      ),
    ),
    _gap(8),
    a.footer(hideStats: true),
  ]);
}

Widget _layoutGamer(_Args a) {
  final likes = a.source.likes;
  final level = 1 + likes ~/ 25;
  final prog = (likes % 25) / 25;
  final st = _statsOf(a.source, a.spec);
  const cyan = Color(0xFF00FFC3);
  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    if (a.spec.showAuthor) a.header(),
    _gap(6),
    Row(children: [
      Text(tr('NIV.') + ' $level', style: _t('Rajdhani', 14, cyan, w: FontWeight.w700, ls: 1.5)),
      const SizedBox(width: 10),
      Expanded(
        child: Container(
          height: 7,
          decoration: BoxDecoration(color: const Color(0x22FFFFFF), borderRadius: BorderRadius.circular(4)),
          child: FractionallySizedBox(alignment: Alignment.centerLeft, widthFactor: prog.clamp(0.08, 1.0), child: Container(decoration: BoxDecoration(color: cyan, borderRadius: BorderRadius.circular(4), boxShadow: const [BoxShadow(color: cyan, blurRadius: 6)]))),
        ),
      ),
    ]),
    _gap(8),
    if (a.hasImage)
      Expanded(
        flex: 5,
        child: SizedBox.expand(child: CustomPaint(foregroundPainter: _ChamferBorderPainter(cyan, 14), child: ClipPath(clipper: _ChamferClipper(14), child: a.media()))),
      ),
    _gap(8),
    Expanded(
      flex: a.hasImage ? 3 : 6,
      child: Align(
        alignment: a.hasImage ? Alignment.centerLeft : Alignment.center,
        child: _FitText(text: a.text, style: a.style(_t('Rajdhani', 21, Colors.white, w: FontWeight.w700)), maxSize: a.hasImage ? 22 : 34, minSize: 12, shadows: const [Shadow(color: Color(0xFFFF2BD6), offset: Offset(1.3, 0)), Shadow(color: Color(0xFF00E5FF), offset: Offset(-1.3, 0))]),
      ),
    ),
    _wordStats(st, const ['j\'aime', 'comm.', 'fans'], _t('Rajdhani', 14, cyan, w: FontWeight.w700, ls: 1)),
    _gap(6),
    a.footer(hideStats: true),
  ]);
}

Widget _layoutStreet(_Args a) {
  return Column(children: [
    Row(children: [
      Transform.rotate(
        angle: -0.05,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xFF111111), width: 3), boxShadow: const [BoxShadow(color: Color(0xFFFF3D81), offset: Offset(4, 4))]),
          child: Text(tr('NEW DROP'), style: _t('PermanentMarker', 22, const Color(0xFF111111))),
        ),
      ),
      const Spacer(),
      if (a.spec.showAuthor)
        Padding(padding: EdgeInsets.zero, child: Text('@${a.source.pseudo}', style: _t('Roboto', 13, const Color(0xFF111111), w: FontWeight.w800))),
    ]),
    _gap(12),
    if (a.hasImage)
      Expanded(
        flex: 5,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Transform.rotate(
            angle: -0.035,
            child: Stack(clipBehavior: Clip.none, children: [
              Positioned.fill(child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xFF111111), width: 3), boxShadow: const [BoxShadow(color: Color(0xFF111111), offset: Offset(5, 5))]), child: a.media())),
              Positioned(top: -10, left: 0, right: 0, child: Center(child: Transform.rotate(angle: 0.05, child: Container(width: 74, height: 20, color: const Color(0xCCFF3D81))))),
            ]),
          ),
        ),
      ),
    _gap(10),
    Expanded(flex: a.hasImage ? 3 : 8, child: Align(alignment: Alignment.centerLeft, child: _FitText(text: a.text, style: a.style(_t('PermanentMarker', 20, const Color(0xFF111111))), maxSize: a.hasImage ? 22 : 34, minSize: 12))),
    a.footer(),
  ]);
}

// ─────────────────────────────────────────────────────────────────────────────
// Drapeaux
// ─────────────────────────────────────────────────────────────────────────────

Widget _flagChip(String code, {double w = 44, double h = 30}) => Container(
      width: w,
      height: h,
      decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 1.5), borderRadius: BorderRadius.circular(3), boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 2))]),
      clipBehavior: Clip.antiAlias,
      child: CardFlag(code),
    );

Widget _layoutPassport(_Args a) {
  const ink = Color(0xFF2B2A33);
  const navy = Color(0xFF16365C);
  const gold = Color(0xFFEAD7A1);
  final st = _statsOf(a.source, a.spec);
  final code = CardFlags.normalize(a.spec.country ?? a.source.country, or: '');
  final country = code.isEmpty ? tr('Monde') : CardFlags.name(code);
  Widget label(String t) => Padding(padding: const EdgeInsets.only(top: 6), child: Text(tr(t), style: _t('Roboto', 8.5, const Color(0xFF7A7360), w: FontWeight.w700, ls: 1.2)));
  final pseudo = a.source.pseudo.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '<');
  final mrz1 = 'P<${code.isEmpty ? 'AFR' : (CardFlags.iso3(code) ?? code)}<$pseudo'.padRight(34, '<').substring(0, 34);
  final mrz2 = 'AFROLOOK<<${_hash(a.source).toString().padLeft(8, '0')}<<<<<<<<<<'.padRight(34, '<').substring(0, 34);
  return Column(children: [
    Container(
      width: double.infinity,
      color: navy,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 9),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('AFROLOOK · ${tr('PASSEPORT')}', style: _t('Roboto', 12, gold, w: FontWeight.w800, ls: 3)),
        Text(tr('CITOYEN DU MONDE'), style: _t('Roboto', 8.5, gold, ls: 2.4)),
      ]),
    ),
    Expanded(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        child: Stack(children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
              width: 98,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                AspectRatio(aspectRatio: 0.78, child: Container(decoration: BoxDecoration(border: Border.all(color: ink, width: 2), color: const Color(0xFFD8D0BD)), clipBehavior: Clip.hardEdge, child: a.hasImage ? FitImage(image: a.images.first) : _avatarFill(a.source))),
                label('NATIONALITÉ'),
                const SizedBox(height: 2),
                Row(children: [
                  if (code.isNotEmpty) Container(width: 20, height: 14, margin: const EdgeInsets.only(right: 5), decoration: BoxDecoration(border: Border.all(color: ink, width: .8)), clipBehavior: Clip.hardEdge, child: CardFlag(code)),
                  Expanded(child: Text(country, maxLines: 1, overflow: TextOverflow.ellipsis, style: _t('Roboto', 12, ink, w: FontWeight.w800))),
                ]),
              ]),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                label('TITULAIRE'),
                Text('@${a.source.pseudo}${a.source.verified ? ' ✓' : ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: _t('Roboto', 15, ink, w: FontWeight.w800)),
                label('MESSAGE'),
                Expanded(child: Align(alignment: Alignment.topLeft, child: _FitText(text: a.text, style: a.style(_t('Roboto', 14, ink, w: FontWeight.w600)), maxSize: 15, minSize: 10))),
                label('DATE'),
                Text(_dateOr(a.source, '—').toUpperCase(), style: _t('Roboto', 12, ink, w: FontWeight.w800)),
                if (st.isNotEmpty) ...[
                  _gap(2),
                  Row(children: [
                    for (final e in st) ...[
                      Padding(
                        padding: const EdgeInsets.only(right: 10, top: 4),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(tr(const ['TAMPONS', 'TÉMOINS', 'VISAS'][e.kind]), style: _t('Roboto', 7.5, const Color(0xFF7A7360), w: FontWeight.w700, ls: 1)),
                          Text(e.text, style: _t('Roboto', 12, ink, w: FontWeight.w800)),
                        ]),
                      ),
                    ]
                  ]),
                ],
              ]),
            ),
          ]),
          Positioned(
            right: 0,
            bottom: 4,
            child: Transform.rotate(
              angle: -0.24,
              child: Container(
                width: 76,
                height: 76,
                alignment: Alignment.center,
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xD9B3261E), width: 3)),
                child: Text('AFROLOOK\n${tr('ARRIVÉE')}\n${_dateOr(a.source, '').toUpperCase()}', textAlign: TextAlign.center, style: _t('Roboto', 8, const Color(0xD9B3261E), w: FontWeight.w800, ls: 1, h: 1.35)),
              ),
            ),
          ),
        ]),
      ),
    ),
    Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
      child: Align(alignment: Alignment.centerLeft, child: FittedBox(fit: BoxFit.scaleDown, child: Text('$mrz1\n$mrz2', style: const TextStyle(fontFamily: 'monospace', fontSize: 11, letterSpacing: 1.6, height: 1.3, color: ink)))),
    ),
    Container(color: navy, padding: const EdgeInsets.fromLTRB(16, 4, 0, 11), child: a.footer(hideStats: true)),
  ]);
}

Widget _layoutStamp(_Args a) {
  const ink = Color(0xFF2A1D0C);
  final code = CardFlags.normalize(a.spec.country ?? a.source.country, or: '');
  final country = (code.isEmpty ? 'AFROLOOK' : CardFlags.name(code)).toUpperCase();
  final st = _statsOf(a.source, a.spec);
  return Column(children: [
    Expanded(
      child: LayoutBuilder(builder: (context, box) => Stack(children: [
        Positioned.fill(
          child: ClipPath(
            clipper: _PerforationClipper(),
            child: Container(
              color: const Color(0xFFFBF6E6),
              padding: const EdgeInsets.all(18),
              child: Column(children: [
                Row(children: [
                  Expanded(child: Text(country, maxLines: 1, overflow: TextOverflow.ellipsis, style: _t('Roboto', 10, ink, w: FontWeight.w800, ls: 3))),
                  Text('AFROLOOK', style: _t('Roboto', 10, ink, w: FontWeight.w800, ls: 3)),
                ]),
                _gap(6),
                Expanded(
                  flex: 6,
                  child: Stack(fit: StackFit.expand, children: [
                    Container(decoration: BoxDecoration(border: Border.all(color: ink, width: 1.5), color: const Color(0xFFE8DFC6)), clipBehavior: Clip.hardEdge, child: _mediaOrAvatar(a)),
                    if (code.isNotEmpty) Positioned(left: 6, top: 6, child: _flagChip(code, w: 44, h: 30)),
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1), decoration: BoxDecoration(color: const Color(0xFFFBF6E6), border: Border.all(color: ink, width: 1.5)), child: Text('100 F', style: _t('AbrilFatface', 20, ink))),
                    ),
                  ]),
                ),
                _gap(6),
                Expanded(flex: 3, child: Center(child: _FitText(text: a.text, style: a.style(_t('CrimsonText', 18, ink, w: FontWeight.w700, italic: FontStyle.italic)), maxSize: 20, minSize: 11, align: TextAlign.center))),
                _wordStats(st, const ['j\'aime', 'lettres', 'tirage'], _t('Roboto', 9.5, ink, w: FontWeight.w800, ls: 1.2), sep: '  ·  '),
              ]),
            ),
          ),
        ),
        Positioned(right: 0, top: box.maxHeight * 0.34, width: 130, height: 64, child: Transform.rotate(angle: -0.17, child: CustomPaint(painter: _PostmarkPainter(const Color(0xCC2A1D0C), 'AFROLOOK', _dateOr(a.source, '').toUpperCase())))),
      ])),
    ),
    _gap(8),
    a.footer(hideStats: true),
  ]);
}

Widget _layoutSupporter(_Args a) {
  final st = _statsOf(a.source, a.spec);
  final code = a.flag;
  final shield = Container(
    color: Colors.white,
    padding: const EdgeInsets.all(5),
    child: ClipPath(clipper: _ShieldClipper(), child: _mediaOrAvatar(a)),
  );
  return Column(children: [
    _gap(2),
    Transform.rotate(
      angle: -0.05,
      child: Column(children: [
        Container(
          height: 54,
          decoration: const BoxDecoration(boxShadow: [BoxShadow(color: Color(0x99000000), blurRadius: 8, offset: Offset(0, 4))]),
          child: Stack(fit: StackFit.expand, children: [
            CardFlag(code),
            const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x22FFFFFF), Color(0x33000000)]))),
            Center(child: FittedBox(fit: BoxFit.scaleDown, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 30), child: Text(CardFlags.name(code).toUpperCase(), style: _t('Anton', 26, Colors.white, ls: 5, shadows: const [Shadow(color: Colors.black87, offset: Offset(1.5, 2))]))))),
          ]),
        ),
        SizedBox(height: 7, child: Row(children: [for (var i = 0; i < 34; i++) Expanded(child: Container(margin: const EdgeInsets.symmetric(horizontal: 1.2), color: i.isEven ? Colors.white70 : Colors.white38))])),
      ]),
    ),
    Expanded(flex: 6, child: Center(child: Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: AspectRatio(aspectRatio: 0.92, child: ClipPath(clipper: _ShieldClipper(), child: shield))))),
    if (st.isNotEmpty)
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (final e in st)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.star_rounded, color: Color(0xFFFFD400), size: 17), const SizedBox(width: 3), Text(e.text, style: _t('Anton', 15, const Color(0xFFFFD400), ls: .5))]),
          ),
      ]),
    _gap(4),
    Expanded(flex: 3, child: Center(child: _FitText(text: a.text, style: a.style(_t('Roboto', 17, Colors.white, w: FontWeight.w800)), maxSize: 19, minSize: 11, align: TextAlign.center))),
    a.footer(hideStats: true),
  ]);
}

class _DiagClipper extends CustomClipper<Path> {
  _DiagClipper({required this.top});
  final bool top;
  @override
  Path getClip(Size s) => top
      ? (Path()
        ..moveTo(0, 0)
        ..lineTo(s.width, 0)
        ..lineTo(0, s.height)
        ..close())
      : (Path()
        ..moveTo(s.width, 0)
        ..lineTo(s.width, s.height)
        ..lineTo(0, s.height)
        ..close());
  @override
  bool shouldReclip(covariant CustomClipper<Path> old) => false;
}

Widget _duoBg(Size s, _Env e) => Stack(fit: StackFit.expand, children: [
      ClipPath(clipper: _DiagClipper(top: true), child: CardFlag(e.flags.first)),
      ClipPath(clipper: _DiagClipper(top: false), child: CardFlag(e.flags.length > 1 ? e.flags[1] : e.flags.first)),
      CustomPaint(painter: _DiagLinePainter()),
    ]);

class _DiagLinePainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    c.drawLine(Offset(s.width, 0), Offset(0, s.height), Paint()..color = Colors.white..strokeWidth = 3);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

Widget _layoutDuo(_Args a) {
  final st = _statsOf(a.source, a.spec);
  return Column(children: [
    Align(alignment: Alignment.centerLeft, child: Text(CardFlags.name(a.flag).toUpperCase(), style: _t('Anton', 15, Colors.white, ls: 3, shadows: const [Shadow(color: Colors.black87, offset: Offset(1, 1.5))]))),
    Expanded(
      flex: 6,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: AspectRatio(
            aspectRatio: 1,
            child: Container(
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 5), boxShadow: const [BoxShadow(color: Color(0x99000000), blurRadius: 16, offset: Offset(0, 6))]),
              clipBehavior: Clip.antiAlias,
              child: _mediaOrAvatar(a),
            ),
          ),
        ),
      ),
    ),
    Expanded(
      flex: 3,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 8, offset: Offset(0, 3))]),
        child: Column(children: [
          Expanded(child: Center(child: _FitText(text: a.text, style: a.style(_t('Roboto', 17, const Color(0xFF111111), w: FontWeight.w800)), maxSize: 19, minSize: 11, align: TextAlign.center))),
          if (st.isNotEmpty) _iconStats(st, const Color(0xFF111111), size: 12),
        ]),
      ),
    ),
    Align(alignment: Alignment.centerRight, child: Padding(padding: const EdgeInsets.only(top: 4, right: 0), child: Text(CardFlags.name(a.flag2).toUpperCase(), style: _t('Anton', 15, Colors.white, ls: 3, shadows: const [Shadow(color: Colors.black87, offset: Offset(1, 1.5))])))),
    Container(decoration: BoxDecoration(color: const Color(0x99000000), borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.fromLTRB(8, 2, 0, 2), child: a.footer(hideStats: true)),
  ]);
}

Widget _layoutPride(_Args a) {
  final code = a.flag;
  return Column(children: [
    Expanded(
      flex: 6,
      child: LayoutBuilder(builder: (context, c) {
        final d = math.min(c.maxWidth, c.maxHeight);
        final r = d / 2 - 14;
        const n = 22;
        return Center(
          child: SizedBox(
            width: d,
            height: d,
            child: Stack(clipBehavior: Clip.none, children: [
              for (var i = 0; i < n; i++)
                () {
                  final ang = i / n * math.pi * 2 - math.pi / 2;
                  return Positioned(
                    left: d / 2 + r * math.cos(ang) - 15,
                    top: d / 2 + r * math.sin(ang) - 10,
                    child: Transform.rotate(angle: ang + math.pi / 2, child: Container(width: 30, height: 20, decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 1.3), borderRadius: BorderRadius.circular(2), boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 3)]), clipBehavior: Clip.antiAlias, child: CardFlag(code))),
                  );
                }(),
              Center(
                child: Container(
                  width: r * 1.35,
                  height: r * 1.35,
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 4), boxShadow: const [BoxShadow(color: Color(0x88FFD400), blurRadius: 22)]),
                  clipBehavior: Clip.antiAlias,
                  child: _mediaOrAvatar(a),
                ),
              ),
            ]),
          ),
        );
      }),
    ),
    _gap(6),
    Text('@${a.source.pseudo}${a.source.verified ? ' ✓' : ''}', style: _t('Roboto', 17, Colors.white, w: FontWeight.w800)),
    Text(CardFlags.name(code).toUpperCase(), style: _t('Roboto', 10, const Color(0xFFFFD400), w: FontWeight.w700, ls: 2.5)),
    _gap(4),
    Expanded(flex: 3, child: Center(child: _FitText(text: a.text, style: a.style(_t('Roboto', 16, Colors.white, w: FontWeight.w600)), maxSize: 18, minSize: 11, align: TextAlign.center))),
    a.footer(),
  ]);
}

// ─────────────────────────────────────────────────────────────────────────────
// Idées
// ─────────────────────────────────────────────────────────────────────────────

Widget _layoutFilm(_Args a) => LayoutBuilder(builder: (context, c) {
      final st = _statsOf(a.source, a.spec);
      final h = c.maxHeight;
      return Stack(fit: StackFit.expand, children: [
        if (a.hasImage) Positioned(left: 0, right: 0, top: 0, height: h * 0.62, child: a.media()),
        Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: const [Color(0x00000000), Color(0x00000000), Color(0xFF000000), Color(0xFF000000)], stops: [0, a.hasImage ? .25 : 0, a.hasImage ? .62 : 0, 1]))),),
        if (a.spec.showAuthor) Positioned(left: 16, right: 16, top: 12, child: Text('${tr('UN POST DE')} @${a.source.pseudo.toUpperCase()}', maxLines: 1, overflow: TextOverflow.ellipsis, style: _t('Roboto', 10, Colors.white, w: FontWeight.w700, ls: 2.4, shadows: const [Shadow(color: Colors.black87, blurRadius: 4)]))),
        Positioned(
          left: 18,
          right: 18,
          top: a.hasImage ? h * 0.52 : h * 0.12,
          bottom: 110,
          child: Center(child: _FitText(text: a.text.toUpperCase(), style: a.style(_t('AbrilFatface', 34, Colors.white, shadows: const [Shadow(color: Colors.black87, blurRadius: 8)])), maxSize: a.hasImage ? 34 : 46, minSize: 14, align: TextAlign.center)),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 56,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (st.isNotEmpty) ...[
              Row(mainAxisSize: MainAxisSize.min, children: [for (var i = 0; i < 5; i++) const Icon(Icons.star_rounded, color: Color(0xFFFFD400), size: 15)]),
              _wordStats(st, const ['VUES', 'CRITIQUES', 'FANS'], _t('Roboto', 10, const Color(0xFFFFD400), w: FontWeight.w700, ls: 1.4), sep: '  ·  '),
            ],
            _gap(3),
            Text('${tr('AU CINÉMA LE')} ${_dateOr(a.source, tr('BIENTÔT')).toUpperCase()}', style: _t('Anton', 11, const Color(0xFF8E8A80), ls: 2.2)),
          ]),
        ),
        Positioned(left: 0, right: 0, bottom: 0, child: Container(color: Colors.black, padding: const EdgeInsets.fromLTRB(14, 4, 0, 11), child: a.footer(hideStats: true))),
      ]);
    });

Widget _layoutNewspaper(_Args a) {
  const ink = Color(0xFF161616);
  final st = _statsOf(a.source, a.spec);
  final issue = 2000 + _hash(a.source) % 700;
  final column = Container(
    padding: const EdgeInsets.only(left: 2),
    child: Text(
      '${tr('De notre envoyé spécial')} @${a.source.pseudo} : ${a.hasImage ? tr('une image qui fait le tour des réseaux.') : tr('un texte qui fait le tour des réseaux.')}',
      textAlign: TextAlign.justify,
      overflow: TextOverflow.fade,
      style: _t('CrimsonText', 13.5, ink, h: 1.3),
    ),
  );
  return Column(children: [
    Padding(padding: EdgeInsets.zero, child: FittedBox(fit: BoxFit.scaleDown, child: Text('L\'Afrolook Quotidien', style: _t('AbrilFatface', 30, ink, ls: -.5)))),
    Container(height: 3, margin: const EdgeInsets.only(top: 2), decoration: const BoxDecoration(border: Border.symmetric(horizontal: BorderSide(color: ink, width: 1.2)))),
    Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Flexible(child: Text('N° $issue', maxLines: 1, overflow: TextOverflow.ellipsis, style: _t('Roboto', 8.5, ink, w: FontWeight.w700, ls: 1.4))),
        Flexible(child: Text(tr('ÉDITION SPÉCIALE'), maxLines: 1, overflow: TextOverflow.ellipsis, style: _t('Roboto', 8.5, ink, w: FontWeight.w700, ls: 1.4))),
        Flexible(child: Text(_dateOr(a.source, '').toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: _t('Roboto', 8.5, ink, w: FontWeight.w700, ls: 1.4))),
      ]),
    ),
    _gap(8),
    Expanded(flex: 4, child: Align(alignment: Alignment.topLeft, child: _FitText(text: a.text, style: a.style(_t('AbrilFatface', 32, ink)), maxSize: a.hasImage ? 32 : 44, minSize: 14))),
    _gap(6),
    if (a.hasImage)
      Expanded(
        flex: 4,
        child: Row(children: [
          Expanded(flex: 5, child: Container(decoration: BoxDecoration(border: Border.all(color: ink, width: 1.2)), clipBehavior: Clip.hardEdge, child: ColorFiltered(colorFilter: _gray, child: a.media()))),
          const SizedBox(width: 10),
          Expanded(flex: 6, child: column),
        ]),
      )
    else
      SizedBox(height: 48, child: column),
    if (st.isNotEmpty)
      Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 6),
        padding: const EdgeInsets.symmetric(vertical: 3),
        decoration: const BoxDecoration(border: Border.symmetric(horizontal: BorderSide(color: ink, width: 1))),
        child: _wordStats(st, const ['applaudissements', 'lettres', 'lecteurs'], _t('Roboto', 9.5, ink, w: FontWeight.w700, ls: 1.2), sep: '  ·  ', align: TextAlign.center),
      ),
    _gap(6),
    a.footer(hideStats: true),
  ]);
}

Widget _layoutMusic(_Args a) {
  final st = _statsOf(a.source, a.spec);
  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Expanded(
      flex: 6,
      child: Center(
        child: AspectRatio(
          aspectRatio: 1,
          child: Container(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), boxShadow: const [BoxShadow(color: Color(0x99000000), blurRadius: 22, offset: Offset(0, 10))]),
            clipBehavior: Clip.antiAlias,
            child: _mediaOrAvatar(a),
          ),
        ),
      ),
    ),
    _gap(10),
    Expanded(flex: 2, child: Align(alignment: Alignment.centerLeft, child: _FitText(text: a.text, style: a.style(_t('Roboto', 22, Colors.white, w: FontWeight.w800)), maxSize: 22, minSize: 12))),
    if (a.spec.showAuthor) Text('@${a.source.pseudo}${a.spec.showDate && a.source.date != null ? ' · ${_fmtDate(a.source.date!)}' : ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: _t('Roboto', 12.5, const Color(0xBFFFFFFF), w: FontWeight.w500)),
    _gap(8),
    SizedBox(
      height: 10,
      child: Stack(alignment: Alignment.centerLeft, children: [
        Container(height: 3, decoration: BoxDecoration(color: const Color(0x44FFFFFF), borderRadius: BorderRadius.circular(2))),
        FractionallySizedBox(widthFactor: .38, child: Container(height: 3, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(2)))),
        Align(alignment: const Alignment(-0.24, 0), child: Container(width: 10, height: 10, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle))),
      ]),
    ),
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text('1:12', style: _t('Roboto', 10, const Color(0xCCFFFFFF), w: FontWeight.w600)),
      Text('3:07', style: _t('Roboto', 10, const Color(0xCCFFFFFF), w: FontWeight.w600)),
    ]),
    if (st.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: _wordStats(st, const ['j\'aime', 'commentaires', 'auditeurs'], _t('Roboto', 11.5, Colors.white, w: FontWeight.w700), sep: '   ·   ')),
    _gap(4),
    a.footer(hideStats: true),
  ]);
}

Widget _layoutBoarding(_Args a) {
  const navy = Color(0xFF0B1D3F);
  const grey = Color(0xFF6A7691);
  final st = _statsOf(a.source, a.spec);
  final code = CardFlags.normalize(a.spec.country ?? a.source.country, or: 'AFR');
  Widget field(String label, String value, {int flex = 1}) => Expanded(
        flex: flex,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tr(label), style: _t('Roboto', 7.5, grey, w: FontWeight.w700, ls: 1.2)),
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: _t('Roboto', 14, navy, w: FontWeight.w900))),
        ]),
      );
  return Column(children: [
    Expanded(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          color: Colors.white,
          child: Column(children: [
            Container(
              color: navy,
              padding: const EdgeInsets.fromLTRB(14, 9, 14, 9),
              child: Row(children: [
                Flexible(child: Text('AFROLOOK AIR', maxLines: 1, overflow: TextOverflow.ellipsis, style: _t('Roboto', 10, Colors.white, w: FontWeight.w800, ls: 2))),
                const Spacer(),
                Flexible(child: Text('BOARDING PASS', maxLines: 1, overflow: TextOverflow.ellipsis, style: _t('Roboto', 8.5, Colors.white70, w: FontWeight.w700, ls: 1.5))),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: Row(children: [
                Text(code, style: _t('Roboto', 30, navy, w: FontWeight.w900, h: 1)),
                const Expanded(child: Center(child: Icon(Icons.flight_rounded, color: navy, size: 22))),
                Text('ALL', style: _t('Roboto', 30, navy, w: FontWeight.w900, h: 1)),
              ]),
            ),
            Padding(padding: const EdgeInsets.fromLTRB(14, 0, 14, 0), child: Row(children: [Text(tr('DÉPART'), style: _t('Roboto', 7.5, grey, w: FontWeight.w700, ls: 1.5)), const Spacer(), Text(tr('POUR TOUS'), style: _t('Roboto', 7.5, grey, w: FontWeight.w700, ls: 1.5))])),
            Expanded(flex: 5, child: Padding(padding: const EdgeInsets.fromLTRB(14, 6, 14, 6), child: ClipRRect(borderRadius: BorderRadius.circular(8), child: ColoredBox(color: const Color(0xFFCFD8EA), child: _mediaOrAvatar(a))))),
            Expanded(flex: 2, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: Align(alignment: Alignment.centerLeft, child: _FitText(text: a.text, style: a.style(_t('Roboto', 15, navy, w: FontWeight.w700)), maxSize: 16, minSize: 10)))),
            SizedBox(height: 18, width: double.infinity, child: CustomPaint(painter: _PerfPainter(const Color(0xFF1550B8)))),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 2, 14, 10),
              child: Row(children: [
                field('PASSAGER', '@${a.source.pseudo}', flex: 2),
                for (final e in st) field(const ['J\'AIME', 'COMM.', 'ABONNÉS'][e.kind], e.text),
              ]),
            ),
          ]),
        ),
      ),
    ),
    _gap(8),
    a.footer(hideStats: true),
  ]);
}

Widget _layoutTarot(_Args a) {
  const gold = Color(0xFFF2D58A);
  final st = _statsOf(a.source, a.spec);
  return Column(children: [
    Text(_roman(1 + a.source.likes % 21), style: _t('CinzelDecorative', 18, gold, w: FontWeight.w700, ls: 6)),
    _gap(8),
    Expanded(
      flex: 6,
      child: Center(
        child: AspectRatio(
          aspectRatio: 0.8,
          child: LayoutBuilder(builder: (context, c) => Container(
                decoration: BoxDecoration(borderRadius: BorderRadius.vertical(top: Radius.circular(c.maxWidth / 2), bottom: const Radius.circular(4)), border: Border.all(color: gold, width: 2)),
                clipBehavior: Clip.antiAlias,
                child: _mediaOrAvatar(a),
              )),
        ),
      ),
    ),
    _gap(8),
    Text('@${a.source.pseudo.toUpperCase()}', maxLines: 1, overflow: TextOverflow.ellipsis, style: _t('CinzelDecorative', 17, gold, w: FontWeight.w700, ls: 3)),
    _gap(4),
    Expanded(flex: 3, child: Center(child: _FitText(text: a.text, style: a.style(_t('CrimsonText', 17, const Color(0xFFF7E8BE), w: FontWeight.w600, italic: FontStyle.italic)), maxSize: 19, minSize: 11, align: TextAlign.center))),
    if (st.isNotEmpty) _wordStats(st, const ['j\'aime', 'voix', 'fidèles'], _t('CinzelDecorative', 11, gold, w: FontWeight.w700, ls: 1), sep: '  ✦  '),
    _gap(6),
    a.footer(hideStats: true),
  ]);
}

Widget _layoutQuote(_Args a) {
  final st = _statsOf(a.source, a.spec);
  return Stack(children: [
    Positioned(left: -4, top: -34, child: Text('“', style: TextStyle(fontFamily: 'AbrilFatface', fontSize: 190, height: 1, color: Colors.white.withOpacity(0.22)))),
    Column(children: [
      Expanded(child: Padding(padding: const EdgeInsets.only(top: 18), child: Align(alignment: Alignment.centerLeft, child: _FitText(text: a.text, style: a.style(_t('Roboto', 30, Colors.white, w: FontWeight.w800, ls: -.3)), maxSize: a.hasImage ? 30 : 40, minSize: 13)))),
      _gap(8),
      Row(children: [
        if (a.spec.showAuthor) ...[
          Container(width: 38, height: 38, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)), clipBehavior: Clip.antiAlias, child: _avatarFill(a.source)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('@${a.source.pseudo}${a.source.verified ? ' ✓' : ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: _t('Roboto', 15, Colors.white, w: FontWeight.w800)),
              if (a.spec.showDate && a.source.date != null) Text(_fmtDate(a.source.date!), style: _t('Roboto', 10.5, const Color(0xCCFFFFFF))),
            ]),
          ),
        ] else
          const Spacer(),
        if (a.hasImage) Container(width: 64, height: 64, decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white, width: 2)), clipBehavior: Clip.antiAlias, child: FitImage(image: a.images.first)),
      ]),
      if (st.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Align(alignment: Alignment.centerLeft, child: _iconStats(st, Colors.white, size: 12.5))),
      _gap(8),
      Container(decoration: BoxDecoration(color: const Color(0x30FFFFFF), borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.fromLTRB(8, 2, 0, 2), child: a.footer(hideStats: true)),
    ]),
  ]);
}

// ─────────────────────────────────────────────────────────────────────────────
// Registre des styles à mise en page propre
// ─────────────────────────────────────────────────────────────────────────────

const _ph = EdgeInsets.fromLTRB(16, 14, 16, 16);

final Map<CardStyleId, _Look> _layoutLooks = {
  CardStyleId.manga: _Look(
    fg: Colors.white,
    accent: Colors.black,
    qrBorder: Colors.black,
    headFont: 'Bangers',
    textStyle: const TextStyle(color: Colors.black, fontFamily: 'Bangers'),
    frame: const BoxDecoration(),
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
    bg: (s, e) => CustomPaint(painter: _MangaRaysPainter(), size: s),
    layout: _layoutManga,
  ),
  CardStyleId.anime: _Look(
    fg: Colors.white,
    accent: Colors.white,
    qrBorder: Colors.white,
    textStyle: const TextStyle(color: Colors.white, fontFamily: 'Roboto', fontWeight: FontWeight.w800),
    frame: _frame(Colors.white, 3, 10),
    padding: _ph,
    bg: (s, e) => CustomPaint(painter: _SkyPainter(), size: s),
    layout: _layoutAnime,
  ),
  CardStyleId.magazine: _Look(
    fg: Colors.white,
    accent: Colors.white,
    qrBorder: Colors.white,
    headFont: 'AbrilFatface',
    textStyle: const TextStyle(color: Colors.white, fontFamily: 'AbrilFatface'),
    frame: const BoxDecoration(),
    bg: (s, e) => const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFB3202F), Color(0xFF5E0F1A)]))),
    layout: _layoutMagazine,
  ),
  CardStyleId.collector: _Look(
    fg: Colors.white,
    accent: const Color(0xFFFFC53D),
    qrBorder: const Color(0xFFFFC53D),
    headFont: 'Rajdhani',
    textStyle: const TextStyle(color: Colors.white, fontFamily: 'Rajdhani', fontWeight: FontWeight.w600),
    frame: _frame(const Color(0xFFFFC53D), 3, 0),
    padding: const EdgeInsets.fromLTRB(9, 9, 9, 15),
    bg: (s, e) => const DecoratedBox(decoration: BoxDecoration(gradient: SweepGradient(center: Alignment.center, colors: [Color(0xFFFF5E8A), Color(0xFFFFC53D), Color(0xFF5BE3A5), Color(0xFF4DB3FF), Color(0xFFB26BFF), Color(0xFFFF5E8A)]))),
    layout: _layoutCollector,
  ),
  CardStyleId.sport: _Look(
    fg: Colors.white,
    accent: const Color(0xFFFF5A1F),
    qrBorder: Colors.white,
    headFont: 'Anton',
    textStyle: const TextStyle(color: Colors.white, fontFamily: 'Anton'),
    frame: const BoxDecoration(),
    padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
    bg: (s, e) => CustomPaint(painter: _SportPainter(), size: s),
    layout: _layoutSport,
  ),
  CardStyleId.gamer: _Look(
    fg: const Color(0xFFE8F4FF),
    accent: const Color(0xFF00FFC3),
    qrBorder: const Color(0xFF00FFC3),
    headFont: 'Rajdhani',
    textStyle: const TextStyle(color: Color(0xFFE8F4FF), fontFamily: 'Rajdhani', fontWeight: FontWeight.w700),
    frame: const BoxDecoration(),
    padding: _ph,
    bg: (s, e) => CustomPaint(painter: _GamerPainter(), size: s),
    layout: _layoutGamer,
  ),
  CardStyleId.street: _Look(
    fg: const Color(0xFF111111),
    accent: const Color(0xFFFF3D81),
    qrBorder: const Color(0xFF111111),
    headFont: 'PermanentMarker',
    textStyle: const TextStyle(color: Color(0xFF111111), fontFamily: 'PermanentMarker'),
    frame: const BoxDecoration(),
    padding: _ph,
    bg: (s, e) => Stack(fit: StackFit.expand, children: [const ColoredBox(color: Color(0xFFFFD400)), CustomPaint(painter: _DotsPainter(color: const Color(0x22000000), step: 10, radius: 2.2))]),
    layout: _layoutStreet,
  ),
  CardStyleId.passport: _Look(
    fg: Colors.white,
    accent: const Color(0xFF16365C),
    qrBorder: const Color(0xFFEAD7A1),
    textStyle: const TextStyle(color: Color(0xFF2B2A33), fontFamily: 'Roboto', fontWeight: FontWeight.w600),
    frame: const BoxDecoration(),
    bg: (s, e) => Stack(fit: StackFit.expand, children: [
      const ColoredBox(color: Color(0xFFE9DFC8)),
      Padding(padding: const EdgeInsets.fromLTRB(20, 110, 20, 80), child: Opacity(opacity: 0.06, child: CardFlag(e.flags.first, fit: BoxFit.contain))),
    ]),
    layout: _layoutPassport,
  ),
  CardStyleId.stamp: _Look(
    fg: const Color(0xFF2A1D0C),
    accent: const Color(0xFF2A1D0C),
    qrBorder: const Color(0xFF2A1D0C),
    textStyle: const TextStyle(color: Color(0xFF2A1D0C), fontFamily: 'CrimsonText', fontWeight: FontWeight.w700),
    frame: const BoxDecoration(),
    padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
    bg: (s, e) => Stack(fit: StackFit.expand, children: [const ColoredBox(color: Color(0xFFCDBF9F)), CustomPaint(painter: _PaperLinesPainter(const Color(0x14000000)))]),
    layout: _layoutStamp,
  ),
  CardStyleId.supporter: _Look(
    fg: Colors.white,
    accent: const Color(0xFFFFD400),
    qrBorder: Colors.white,
    headFont: 'Anton',
    textStyle: const TextStyle(color: Colors.white, fontFamily: 'Roboto', fontWeight: FontWeight.w800),
    frame: const BoxDecoration(),
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
    bg: (s, e) => Stack(fit: StackFit.expand, children: [
      const DecoratedBox(decoration: BoxDecoration(gradient: RadialGradient(center: Alignment(0, -0.2), radius: 1.1, colors: [Color(0xFF22324D), Color(0xFF0B1220)]))),
      CustomPaint(painter: _ConfettiPainter()),
    ]),
    layout: _layoutSupporter,
  ),
  CardStyleId.duo: _Look(
    fg: Colors.white,
    accent: Colors.white,
    qrBorder: Colors.white,
    textStyle: const TextStyle(color: Colors.white, fontFamily: 'Roboto', fontWeight: FontWeight.w800),
    frame: const BoxDecoration(),
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
    bg: _duoBg,
    layout: _layoutDuo,
  ),
  CardStyleId.pride: _Look(
    fg: Colors.white,
    accent: const Color(0xFFFFD400),
    qrBorder: const Color(0xFFFFD400),
    textStyle: const TextStyle(color: Colors.white, fontFamily: 'Roboto', fontWeight: FontWeight.w600),
    frame: const BoxDecoration(),
    padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
    bg: (s, e) => const DecoratedBox(decoration: BoxDecoration(gradient: RadialGradient(center: Alignment(0, -0.3), radius: 1.0, colors: [Color(0xFF1C3B2B), Color(0xFF08140D)]))),
    layout: _layoutPride,
  ),
  CardStyleId.film: _Look(
    fg: Colors.white,
    accent: const Color(0xFFFFD400),
    qrBorder: Colors.white,
    headFont: 'AbrilFatface',
    textStyle: const TextStyle(color: Colors.white, fontFamily: 'AbrilFatface'),
    frame: const BoxDecoration(),
    bg: (s, e) => const ColoredBox(color: Colors.black),
    layout: _layoutFilm,
  ),
  CardStyleId.newspaper: _Look(
    fg: const Color(0xFF161616),
    accent: const Color(0xFF161616),
    qrBorder: const Color(0xFF161616),
    headFont: 'AbrilFatface',
    textStyle: const TextStyle(color: Color(0xFF161616), fontFamily: 'AbrilFatface'),
    frame: _frame(const Color(0xFF161616), 1.2, 0),
    padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
    bg: (s, e) => Stack(fit: StackFit.expand, children: [const ColoredBox(color: Color(0xFFE8E2D2)), CustomPaint(painter: _PaperLinesPainter(const Color(0x0F000000)))]),
    layout: _layoutNewspaper,
  ),
  CardStyleId.music: _Look(
    fg: Colors.white,
    accent: Colors.white,
    qrBorder: Colors.white,
    textStyle: const TextStyle(color: Colors.white, fontFamily: 'Roboto', fontWeight: FontWeight.w800),
    frame: const BoxDecoration(),
    padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
    bg: (s, e) => _blurBg(e, fallback: const [Color(0xFF4B1D8F), Color(0xFFB0306E)], dark: 0.55, blur: 34),
    layout: _layoutMusic,
  ),
  CardStyleId.boarding: _Look(
    fg: Colors.white,
    accent: Colors.white,
    qrBorder: Colors.white,
    textStyle: const TextStyle(color: Color(0xFF0B1D3F), fontFamily: 'Roboto', fontWeight: FontWeight.w700),
    frame: const BoxDecoration(),
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
    bg: (s, e) => const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF0E3B8C), Color(0xFF1E63D6)]))),
    layout: _layoutBoarding,
  ),
  CardStyleId.tarot: _Look(
    fg: const Color(0xFFF2D58A),
    accent: const Color(0xFFF2D58A),
    qrBorder: const Color(0xFFF2D58A),
    headFont: 'CinzelDecorative',
    textStyle: const TextStyle(color: Color(0xFFF7E8BE), fontFamily: 'CrimsonText', fontWeight: FontWeight.w600),
    frame: const BoxDecoration(),
    padding: const EdgeInsets.fromLTRB(30, 26, 30, 22),
    bg: (s, e) => Stack(fit: StackFit.expand, children: [
      const DecoratedBox(decoration: BoxDecoration(gradient: RadialGradient(center: Alignment(0, -0.35), radius: 1.0, colors: [Color(0xFF4B1D6B), Color(0xFF1A0B2E)]))),
      CustomPaint(painter: _DotsPainter(color: const Color(0x66F2D58A), step: 26, radius: 1.1)),
      CustomPaint(painter: _DotsPainter(color: const Color(0x33F2D58A), step: 26, radius: 0.8, offset: const Offset(13, 13))),
      CustomPaint(painter: _GoldFramePainter()),
    ]),
    layout: _layoutTarot,
  ),
  CardStyleId.quote: _Look(
    fg: Colors.white,
    accent: Colors.white,
    qrBorder: Colors.white,
    textStyle: const TextStyle(color: Colors.white, fontFamily: 'Roboto', fontWeight: FontWeight.w800),
    frame: _frame(Colors.white, 2, 10),
    padding: const EdgeInsets.fromLTRB(22, 26, 22, 16),
    bg: (s, e) => const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFFB86B), Color(0xFFFF6FA3), Color(0xFF7C5CFF)]))),
    layout: _layoutQuote,
  ),
};
