import 'package:flutter/material.dart';

import '../../l10n/tr.dart';
import '../../theme/app_colors.dart';
import 'card_canvas.dart';
import 'card_entry.dart';
import 'card_models.dart';

/// Tutoriel du Studio Cartes : des exemples réels, dessinés avec les images de l'application, pour montrer ce que
/// l'on peut créer. Ouvert au premier usage du studio, depuis « Tous les tutoriels » et depuis le bouton d'aide.
class CardTutorialPage extends StatefulWidget {
  const CardTutorialPage({super.key, this.fromStudio = false});

  /// Ouvert depuis le studio : le dernier bouton referme simplement le tutoriel.
  final bool fromStudio;

  @override
  State<CardTutorialPage> createState() => _CardTutorialPageState();
}

/// Exemples du tutoriel (images fournies avec l'application).
class CardDemo {
  CardDemo._();
  static const _avatar = AssetImage('assets/images/intro3.jpg');
  static const _portrait = AssetImage('assets/images/intro1.jpg');
  static const _selfie = AssetImage('assets/images/intro3.jpg');
  static const _yellow = AssetImage('assets/images/intro2.jpg');
  static const _bench = AssetImage('assets/images/intro7.jpg');
  static const _red = AssetImage('assets/images/intro6.jpg');

  static CardSource post({List<ImageProvider>? images, String? text, bool video = false}) => CardSource(
        pseudo: 'aminata_k',
        avatar: _avatar,
        verified: true,
        text: text ?? 'Coucher de soleil sur la corniche de Dakar 🌅 La plus belle séance photo de ma semaine.',
        images: images ?? const [_portrait],
        isVideo: video,
        postId: 'demo',
        date: DateTime(2026, 10, 10),
        likes: 1200,
        comments: 214,
      );

  static CardSource multi() => post(images: const [_portrait, _selfie, _bench, _yellow], text: 'Ma journée à Abidjan, en quatre images 🎉');
  static CardSource landscape() => post(images: const [_bench], text: 'Pause au parc après le travail 🍃');
  static CardSource textOnly() => post(images: const [], text: 'On dit que l’argent ne fait pas le bonheur. Mais il paie le transport pour aller le chercher. 😂');
  static CardSource longText() => post(
        images: const [],
        text:
            'Hier, j’ai pris le car de cinq heures pour rejoindre ma tante à Bouaké. Le chauffeur a mis une musique que je n’entendais plus depuis mon enfance, et tout le monde s’est mis à chanter. Une dame près de moi a sorti des beignets qu’elle a partagés avec tout le car. À l’arrivée, personne ne voulait descendre. #voyage',
      );
  static CardSource video() => post(images: const [_red], video: true, text: 'Mon premier pas de danse en public 💃🏾');
}

class _CardTutorialPageState extends State<CardTutorialPage> {
  final PageController _pc = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  late final List<_Slide> _slides = [
    _Slide(
      title: 'Un post devient une carte',
      body: 'Appuie longtemps sur un post, ou ouvre son menu « ⋯ » puis « Créer une carte ». Le studio te propose une carte au style africain, prête à partager.',
      visual: (c) => _pair(c),
    ),
    _Slide(
      title: 'Choisis ton style',
      body: 'Kente, Wax, Néon Lagos, Bogolan… Chaque style a sa couleur, sa police et son motif. Trois sont inclus, d\'autres sont en Pro.',
      visual: (c) => _row([
        _card(CardDemo.post(), CardSpec(style: CardStyleId.kente)),
        _card(CardDemo.post(), CardSpec(style: CardStyleId.wax)),
        _card(CardDemo.post(), CardSpec(style: CardStyleId.neon)),
        _card(CardDemo.post(), CardSpec(style: CardStyleId.bogolan)),
      ], names: ['Kente', 'Wax', 'Néon Lagos', 'Bogolan']),
    ),
    _Slide(
      title: 'Aucune image n\'est coupée',
      body: 'Photo verticale, horizontale ou vidéo : la carte montre toujours l\'image en entier. Les bords sont remplis par un flou de la même image.',
      visual: (c) => _row([
        _card(CardDemo.post(), CardSpec(style: CardStyleId.wax)),
        _card(CardDemo.landscape(), CardSpec(style: CardStyleId.neon)),
        _card(CardDemo.video(), CardSpec(style: CardStyleId.kente)),
      ], names: ['Photo verticale', 'Photo horizontale', 'Vidéo']),
    ),
    _Slide(
      title: 'Plusieurs images : tu choisis',
      body: 'Dans un post à plusieurs images, touche celles que tu veux (4 au plus) et choisis la disposition : mosaïque, polaroïds, bande ou une seule.',
      visual: (c) => _row([
        _card(CardDemo.multi(), CardSpec(style: CardStyleId.wax, layout: CardLayout.mosaic, imageOrder: [0, 1, 2, 3])),
        _card(CardDemo.multi(), CardSpec(style: CardStyleId.wax, layout: CardLayout.polaroid, imageOrder: [0, 1, 2])),
        _card(CardDemo.multi(), CardSpec(style: CardStyleId.neon, layout: CardLayout.film, imageOrder: [0, 1, 2])),
      ], names: ['Mosaïque', 'Polaroïds', 'Bande']),
    ),
    _Slide(
      title: 'Un texte trop long ? On le coupe proprement',
      body: 'La carte garde le début, coupé à la fin d\'une phrase, avec « Lire la suite ». Tu peux aussi choisir toi-même les phrases à garder.',
      visual: (c) => _row([
        _card(CardDemo.textOnly(), CardSpec(style: CardStyleId.kente)),
        _card(CardDemo.longText(), CardSpec(style: CardStyleId.bogolan, format: CardFormat.portrait)),
      ], names: ['Texte court', 'Texte long']),
    ),
    _Slide(
      title: 'Publie ou partage partout',
      body: 'Enregistre la carte, envoie-la sur WhatsApp, Instagram ou TikTok, ou publie-la directement en Chronique ou en post sur Afrolook. Chaque carte porte la signature Afrolook et un QR qui ramène vers le post.',
      visual: (c) => _row([
        _card(CardDemo.post(), CardSpec(style: CardStyleId.neon, format: CardFormat.story)),
      ], names: ['Format Story pour les chroniques']),
      footer: (c) => _plans(c),
    ),
  ];

  Widget _card(CardSource s, CardSpec spec) => FittedBox(fit: BoxFit.contain, child: CardCanvas(source: s, spec: spec));

  /// Les cartes d'exemple, toutes visibles à l'écran (2 × 2 pour quatre cartes), chacune avec son nom.
  Widget _row(List<Widget> cards, {List<String>? names}) => LayoutBuilder(builder: (context, cs) {
        final c2 = AppColors.of(context);
        final n = cards.length;
        final perRow = n == 4 ? 2 : n;
        const gap = 12.0;
        final w = ((cs.maxWidth - 40 - gap * (perRow - 1)) / perRow).clamp(80.0, 200.0);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: gap,
            runSpacing: 14,
            children: [
              for (var i = 0; i < n; i++)
                SizedBox(
                  width: w,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    cards[i],
                    if (names != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(context.tr(names[i]), textAlign: TextAlign.center, style: TextStyle(color: c2.textSecondary, fontSize: 12, fontWeight: FontWeight.w700)),
                      ),
                  ]),
                ),
            ],
          ),
        );
      });

  /// Avant / après : le post tel qu'il est dans le fil, puis sa carte.
  Widget _pair(BuildContext context) {
    final c = AppColors.of(context);
    return SizedBox(
      height: 300,
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 150,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.border)),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const CircleAvatar(radius: 14, backgroundImage: AssetImage('assets/images/intro3.jpg')),
              const SizedBox(width: 6),
              Expanded(child: Text('@aminata_k', style: TextStyle(color: c.textPrimary, fontSize: 11.5, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis)),
              Icon(Icons.more_horiz, size: 18, color: c.textSecondary),
            ]),
            const SizedBox(height: 8),
            Text('Coucher de soleil sur la corniche de Dakar 🌅', maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textPrimary, fontSize: 11.5)),
            const SizedBox(height: 8),
            ClipRRect(borderRadius: BorderRadius.circular(8), child: AspectRatio(aspectRatio: 1, child: Image.asset('assets/images/intro1.jpg', fit: BoxFit.cover))),
          ]),
        ),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Icon(Icons.arrow_forward_rounded, color: c.primary, size: 28)),
        SizedBox(width: 170, height: 300, child: _card(CardDemo.post(), CardSpec(style: CardStyleId.neon))),
      ]),
    );
  }

  Widget _plans(BuildContext context) {
    final c = AppColors.of(context);
    Widget line(String a, String b) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            Expanded(flex: 2, child: Text(a, style: TextStyle(color: c.textSecondary, fontSize: 13))),
            Expanded(flex: 3, child: Text(b, textAlign: TextAlign.end, style: TextStyle(color: c.textPrimary, fontSize: 13, fontWeight: FontWeight.w800))),
          ]),
        );
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.border)),
      child: Column(children: [
        line(context.tr('Gratuit'), context.tr('1 carte d\'essai, puis pièces ou 1 pub')),
        line('Premium ⭐', context.tr('2 captures + 3 publications par mois')),
        line('Gold 👑', context.tr('5 captures + 20 publications par mois')),
        line(context.tr('Pass Studio'), context.tr('tout à volonté pendant 30 jours')),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final last = _page == _slides.length - 1;
    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
            child: Row(children: [
              IconButton(icon: Icon(Icons.close_rounded, color: c.textPrimary), onPressed: () => Navigator.of(context).maybePop()),
              const Spacer(),
              if (!last) TextButton(onPressed: () => Navigator.of(context).maybePop(), child: Text(context.tr('Passer'), style: TextStyle(color: c.textSecondary))),
            ]),
          ),
          Expanded(
            child: PageView.builder(
              controller: _pc,
              itemCount: _slides.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (_, i) {
                final s = _slides[i];
                return LayoutBuilder(builder: (context, cs) => SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: cs.maxHeight),
                    child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    s.visual(context),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 26),
                      child: Column(children: [
                        Text(context.tr(s.title), textAlign: TextAlign.center, style: TextStyle(color: c.textPrimary, fontSize: 21, fontWeight: FontWeight.w800, height: 1.2)),
                        const SizedBox(height: 10),
                        Text(context.tr(s.body), textAlign: TextAlign.center, style: TextStyle(color: c.textSecondary, fontSize: 14.5, height: 1.45)),
                      ]),
                    ),
                    if (s.footer != null) s.footer!(context),
                    const SizedBox(height: 12),
                  ])),
                  ),
                ));
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                for (var i = 0; i < _slides.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _page ? 18 : 7,
                    height: 7,
                    decoration: BoxDecoration(color: i == _page ? c.primary : c.border, borderRadius: BorderRadius.circular(4)),
                  ),
              ]),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28))),
                  onPressed: () {
                    if (!last) {
                      _pc.nextPage(duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
                    } else if (widget.fromStudio) {
                      Navigator.of(context).maybePop();
                    } else {
                      final nav = Navigator.of(context);
                      nav.pop();
                      CardEntry.composeOn(nav);
                    }
                  },
                  child: Text(last ? (widget.fromStudio ? context.tr('C\'est parti') : context.tr('Créer ma première carte')) : context.tr('Suivant'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Slide {
  _Slide({required this.title, required this.body, required this.visual, this.footer});
  final String title;
  final String body;
  final Widget Function(BuildContext) visual;
  final Widget Function(BuildContext)? footer;
}
