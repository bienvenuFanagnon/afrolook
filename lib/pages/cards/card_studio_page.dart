import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/tr.dart';
import '../../models/model_data.dart';
import '../../providers/authProvider.dart';
import '../../theme/app_colors.dart';
import '../coins/coin_recharge_screen.dart';
import 'card_canvas.dart';
import 'card_export.dart';
import 'card_flow.dart';
import 'card_models.dart';
import 'card_service.dart';
import 'card_text.dart';
import 'card_tutorial_page.dart';

/// Studio Cartes : un post (ou un brouillon) devient une carte Afrolook à enregistrer, partager ou publier.
///
/// - [compose] = false : on part d'un post existant ; les boutons sont Enregistrer, Partager, Publier.
/// - [compose] = true : on part d'un brouillon (page de création de post) ; l'écran se ferme en renvoyant un
///   [CardResult] que la page de création publie ensuite avec les règles des posts.
class CardStudioPage extends StatefulWidget {
  const CardStudioPage({super.key, required this.source, this.compose = false, this.canal, this.defiPostId});

  final CardSource source;
  final bool compose;
  final Canal? canal;
  final String? defiPostId;

  @override
  State<CardStudioPage> createState() => _CardStudioPageState();
}

class _CardStudioPageState extends State<CardStudioPage> {
  late CardSource _source = widget.source;
  late final CardSpec _spec;
  final GlobalKey _boundaryKey = GlobalKey();
  final TextEditingController _textCtl = TextEditingController();
  CardQuote _quote = CardQuote.fallback();
  int _tab = 0;
  bool _busy = false;

  /// Capture déjà réglée pour cette carte (enregistrer puis partager ne se paie qu'une fois), avec le niveau de style payé.
  bool _captureDone = false;
  bool _capturePaidPro = false;

  static const _tabs = ['Médias', 'Style', 'Texte', 'Format'];

  @override
  void initState() {
    super.initState();
    _spec = CardSpec(
      style: CardStyleId.neon,
      format: CardFormat.portrait,
      imageOrder: List<int>.generate(_source.images.length.clamp(0, 3), (i) => i),
    );
    _textCtl.text = _source.text;
    _loadQuote();
    WidgetsBinding.instance.addPostFrameCallback((_) => _firstUseTutorial());
  }

  @override
  void dispose() {
    _textCtl.dispose();
    super.dispose();
  }

  Future<void> _loadQuote() async {
    final q = await CardService.quote();
    if (mounted) setState(() => _quote = q);
  }

  /// Au premier usage, la visite guidée s'ouvre une fois.
  Future<void> _firstUseTutorial() async {
    try {
      final sp = await SharedPreferences.getInstance();
      if (sp.getBool('cards_tuto_seen') == true || !mounted) return;
      await sp.setBool('cards_tuto_seen', true);
      if (!mounted) return;
      await Navigator.push(context, MaterialPageRoute(builder: (_) => const CardTutorialPage(fromStudio: true)));
    } catch (_) {}
  }

  bool get _isPro => _quote.proStyles.contains(_spec.style.name);
  bool get _hasMedia => _source.images.isNotEmpty;
  void _say(String t) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(t), duration: const Duration(seconds: 3)));
  }

  // ── Sorties ───────────────────────────────────────────────────────────────

  /// Paie la capture si besoin, puis fabrique l'image PNG.
  Future<Uint8List?> _captureImage() async {
    final needsPay = !_captureDone || (_isPro && !_capturePaidPro);
    if (needsPay) {
      final ok = await CardFlow.commit(context, CardKind.capture, pro: _isPro, quote: _quote);
      if (!ok || !mounted) return null;
      _captureDone = true;
      _capturePaidPro = _isPro;
      _loadQuote();
    }
    await CardExport.precache(context, _source, _spec);
    return CardExport.toPng(_boundaryKey, format: _spec.format);
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final png = await _captureImage();
      if (png == null) return;
      final ok = await CardExport.saveToGallery(png);
      _say(ok ? tr('Carte enregistrée dans ta galerie ✅') : tr('Autorise l\'accès aux photos pour enregistrer la carte.'));
    } catch (_) {
      _say(tr('Impossible de créer la carte. Réessaie.'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final png = await _captureImage();
      if (png == null) return;
      await CardExport.share(png, text: _source.link == null ? 'afrolookmedia.com' : '${_source.link}');
    } catch (_) {
      _say(tr('Impossible de partager la carte. Réessaie.'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Compose le résultat pour une publication : le format est ajusté à l'endroit où la carte sera publiée
  /// (Portrait 4:5 pour un post, Story 9:16 pour une chronique) afin qu'aucune image ne soit coupée dans le fil.
  Future<CardResult?> _render(CardFormat format) async {
    if (_spec.format != format) {
      setState(() => _spec.format = format);
      _say(tr('Format ajusté à {f} pour la publication.', {'f': format.label}));
      await WidgetsBinding.instance.endOfFrame;
    }
    if (!mounted) return null;
    await CardExport.precache(context, _source, _spec);
    final png = await CardExport.toPng(_boundaryKey, format: format);
    final jpeg = await CardFlow.toJpeg(png);
    return CardResult(image: jpeg, caption: CardFlow.postCaption(_source), pro: _isPro, format: format);
  }

  Future<void> _publish() async {
    if (_busy) return;
    final c = AppColors.of(context);
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        final cost = _quote.cost(CardKind.publish, pro: _isPro);
        Widget opt(IconData i, String t, String sub, String v) => ListTile(
              leading: Icon(i, color: c.primary),
              title: Text(t, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700)),
              subtitle: Text(sub, style: TextStyle(color: c.textSecondary, fontSize: 12)),
              trailing: _PriceChip(cost: cost),
              onTap: () => Navigator.pop(ctx, v),
            );
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 14, 8, 10),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(ctx.tr('Où publier ta carte ?'), style: TextStyle(color: c.textPrimary, fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(ctx.tr('Mêmes règles que tes publications habituelles.'), style: TextStyle(color: c.textSecondary, fontSize: 12)),
              const SizedBox(height: 6),
              opt(Icons.add_circle_outline_rounded, ctx.tr('Publier en Chronique'), ctx.tr('Format Story · visible 24 h'), 'chronique'),
              opt(Icons.article_outlined, ctx.tr('Publier en post'), ctx.tr('Sur ton profil, avec légende'), 'post'),
            ]),
          ),
        );
      },
    );
    if (choice == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final r = await _render(choice == 'chronique' ? CardFormat.story : CardFormat.portrait);
      if (r == null || !mounted) return;
      final done = choice == 'chronique'
          ? await CardFlow.publishAsChronique(context, r, _quote, caption: CardFlow.chroniqueCaption(_source))
          : await CardFlow.publishAsPost(context, r, _quote, canal: widget.canal, defiPostId: widget.defiPostId);
      if (done && mounted) Navigator.of(context).pop(true);
    } catch (_) {
      _say(tr('Impossible de créer la carte. Réessaie.'));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _loadQuote();
      }
    }
  }

  Future<void> _useCard() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final r = await _render(CardFormat.portrait);
      if (r != null && mounted) Navigator.of(context).pop(r);
    } catch (_) {
      _say(tr('Impossible de créer la carte. Réessaie.'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── Interface ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        foregroundColor: c.textPrimary,
        elevation: 0,
        title: Text(context.tr('Carte Afrolook'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        actions: [
          IconButton(
            tooltip: context.tr('Comment ça marche'),
            icon: const Icon(Icons.help_outline_rounded),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CardTutorialPage())),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(children: [
          Expanded(child: _preview(c)),
          _quotaBanner(c),
          _tabBar(c),
          SizedBox(height: (MediaQuery.of(context).size.height * 0.27).clamp(168.0, 230.0), child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(14, 10, 14, 6), child: _panel(c))),
          _actions(c),
        ]),
      ),
    );
  }

  Widget _preview(AppColors c) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(gradient: RadialGradient(center: const Alignment(0, -0.2), radius: 0.9, colors: [c.primary.withOpacity(0.08), Colors.transparent])),
        child: Center(
          child: FittedBox(
            fit: BoxFit.contain,
            child: DecoratedBox(
              decoration: BoxDecoration(boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 26, offset: const Offset(0, 12))], borderRadius: BorderRadius.circular(28)),
              child: RepaintBoundary(key: _boundaryKey, child: CardCanvas(source: _source, spec: _spec)),
            ),
          ),
        ),
      );

  String _quotaLine() {
    final q = _quote;
    if (q.passActive) {
      final d = DateTime.fromMillisecondsSinceEpoch(q.passUntil);
      return tr('Pass Studio actif jusqu\'au {d}', {'d': '${d.day}/${d.month}'});
    }
    if (q.plan != 'free') {
      final capLeft = (q.capturesMax - q.captures).clamp(0, 999);
      final pubLeft = (q.publishesMax - q.publishes).clamp(0, 999);
      return tr('Ce mois-ci : {a} capture(s) et {b} publication(s) gratuites', {'a': capLeft, 'b': pubLeft});
    }
    if (q.trialLeft > 0) return tr('1 carte d\'essai offerte');
    if (q.adCredits > 0) return tr('{n} capture(s) gagnée(s) avec une pub', {'n': q.adCredits});
    return tr('Capture {a} 🪙 · Publication {b} 🪙', {'a': q.priceCapture, 'b': q.pricePublish});
  }

  Widget _quotaBanner(AppColors c) => InkWell(
        onTap: _showPlanSheet,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(children: [
            Icon(Icons.auto_awesome_rounded, size: 16, color: c.supportAccent),
            const SizedBox(width: 8),
            Expanded(child: Text(_quotaLine(), style: TextStyle(color: c.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w600))),
            Text(context.tr('Détails'), style: TextStyle(color: c.primary, fontSize: 12, fontWeight: FontWeight.w700)),
            Icon(Icons.chevron_right_rounded, size: 18, color: c.primary),
          ]),
        ),
      );

  void _showPlanSheet() {
    final c = AppColors.of(context);
    final q = _quote;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(ctx.tr('Mes cartes'), style: TextStyle(color: c.textPrimary, fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            _line(c, ctx.tr('Plan'), q.plan == 'gold' ? 'Gold 👑' : (q.plan == 'premium' ? 'Premium ⭐' : ctx.tr('Gratuit'))),
            if (q.plan != 'free') ...[
              _line(c, ctx.tr('Captures ce mois-ci'), '${q.captures} / ${q.capturesMax}'),
              _line(c, ctx.tr('Publications ce mois-ci'), '${q.publishes} / ${q.publishesMax}'),
            ],
            if (q.trialLeft > 0) _line(c, ctx.tr('Carte d\'essai'), ctx.tr('1 offerte')),
            if (q.adCredits > 0) _line(c, ctx.tr('Captures gagnées avec une pub'), '${q.adCredits}'),
            _line(c, ctx.tr('Ton solde'), '${q.balance} 🪙'),
            const Divider(height: 24),
            _line(c, ctx.tr('Capture (enregistrer, partager)'), '${q.priceCapture} 🪙'),
            _line(c, ctx.tr('Publication (post ou Chronique)'), '${q.pricePublish} 🪙'),
            _line(c, ctx.tr('Style Pro en plus'), '+${q.priceProStyle} 🪙'),
            const SizedBox(height: 14),
            if (q.passActive)
              Text(ctx.tr('Ton Pass Studio est actif : tout est gratuit, styles Pro compris.'), style: TextStyle(color: c.primary, fontWeight: FontWeight.w700))
            else
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _buyPass();
                  },
                  icon: const Icon(Icons.workspace_premium_rounded),
                  label: Text(ctx.tr('Pass Studio {d} jours · {p} 🪙', {'d': q.passDays, 'p': q.passPrice})),
                ),
              ),
            const SizedBox(height: 4),
            Text(ctx.tr('Captures, publications et styles Pro à volonté pendant {d} jours.', {'d': q.passDays}), style: TextStyle(color: c.textSecondary, fontSize: 12)),
          ]),
        ),
      ),
    );
  }

  Widget _line(AppColors c, String a, String b) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(child: Text(a, style: TextStyle(color: c.textSecondary, fontSize: 14))),
          Text(b, style: TextStyle(color: c.textPrimary, fontSize: 14, fontWeight: FontWeight.w800)),
        ]),
      );

  Future<void> _buyPass() async {
    try {
      await CardService.buyPass();
      if (!mounted) return;
      context.read<UserAuthProvider>().refreshUserData();
      _say(tr('Pass Studio activé 🎉'));
      _loadQuote();
    } on CardInsufficient catch (e) {
      if (!mounted) return;
      final c = AppColors.of(context);
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: c.surface,
          title: Text(ctx.tr('Il te faut {n} 🪙', {'n': e.coins})),
          content: Text(ctx.tr('Ton solde est de {b} 🪙. Recharge tes pièces pour continuer.', {'b': e.balance})),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.tr('Annuler'))),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(ctx.tr('Recharger'))),
          ],
        ),
      );
      if (ok == true && mounted) {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => const CoinRechargeScreen()));
        if (mounted) _loadQuote();
      }
    } catch (_) {
      _say(tr('Impossible d\'activer le pass pour le moment.'));
    }
  }

  Widget _tabBar(AppColors c) => Container(
        decoration: BoxDecoration(border: Border(top: BorderSide(color: c.border.withOpacity(0.5)))),
        child: Row(children: [
          for (var i = 0; i < _tabs.length; i++)
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _tab = i),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: _tab == i ? c.primary : Colors.transparent, width: 2))),
                  child: Text(context.tr(_tabs[i]), textAlign: TextAlign.center, style: TextStyle(color: _tab == i ? c.primary : c.textSecondary, fontWeight: _tab == i ? FontWeight.w800 : FontWeight.w500, fontSize: 13)),
                ),
              ),
            ),
        ]),
      );

  Widget _panel(AppColors c) => switch (_tab) {
        0 => _mediaPanel(c),
        1 => _stylePanel(c),
        2 => _textPanel(c),
        _ => _formatPanel(c),
      };

  // ── Onglet Médias ─────────────────────────────────────────────────────────

  Future<void> _addImages() async {
    final picked = await ImagePicker().pickMultiImage(imageQuality: 88, maxWidth: 1600, maxHeight: 1600, limit: CardSpec.maxImages);
    if (picked.isEmpty) return;
    final bytes = <Uint8List>[for (final x in picked.take(CardSpec.maxImages)) await x.readAsBytes()];
    setState(() {
      _source = _source.copyWith(images: [for (final b in bytes) MemoryImage(b)]);
      _spec.imageOrder = List<int>.generate(bytes.length.clamp(0, 3), (i) => i);
      _captureDone = false;
    });
  }

  Widget _mediaPanel(AppColors c) {
    final imgs = _source.images;
    if (imgs.isEmpty) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(context.tr(widget.compose ? 'Ajoute jusqu\'à 4 images à ta carte (facultatif).' : 'Ce post n\'a pas d\'image : la carte est un texte mis en forme.'), style: TextStyle(color: c.textSecondary, height: 1.4)),
        if (widget.compose) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(onPressed: _addImages, icon: const Icon(Icons.add_photo_alternate_rounded), label: Text(context.tr('Ajouter des images'))),
        ],
      ]);
    }
    final multi = imgs.length > 1 && !_source.isVideo;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (multi)
        Text(context.tr('Touche pour choisir (4 max). Les chiffres donnent l\'ordre.'), style: TextStyle(color: c.textSecondary, fontSize: 12)),
      if (multi) const SizedBox(height: 8),
      if (multi)
        SizedBox(
          height: 58,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: imgs.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final pos = _spec.imageOrder.indexOf(i);
              final on = pos >= 0;
              return GestureDetector(
                onTap: () => setState(() {
                  if (on) {
                    if (_spec.imageOrder.length > 1) _spec.imageOrder.remove(i);
                  } else if (_spec.imageOrder.length < CardSpec.maxImages) {
                    _spec.imageOrder.add(i);
                  } else {
                    _say(tr('4 images au maximum.'));
                  }
                  _captureDone = false;
                }),
                child: Opacity(
                  opacity: on ? 1 : 0.5,
                  child: Container(
                    width: 58,
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(9), border: Border.all(color: on ? c.primary : Colors.transparent, width: 2)),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(fit: StackFit.expand, children: [
                      Image(image: imgs[i], fit: BoxFit.cover, errorBuilder: (_, __, ___) => const ColoredBox(color: Colors.black26)),
                      if (on)
                        Positioned(right: 3, top: 3, child: CircleAvatar(radius: 8, backgroundColor: c.primary, child: Text('${pos + 1}', style: TextStyle(color: c.onPrimary, fontSize: 10, fontWeight: FontWeight.w800)))),
                    ]),
                  ),
                ),
              );
            },
          ),
        ),
      if (multi && _spec.imageOrder.length > 1) ...[
        const SizedBox(height: 10),
        Wrap(spacing: 8, children: [
          for (final l in CardLayout.values)
            ChoiceChip(
              label: Text(context.tr(l.label)),
              selected: _spec.layout == l,
              onSelected: (_) => setState(() => _spec.layout = l),
              visualDensity: VisualDensity.compact,
            ),
        ]),
      ],
      if (!multi)
        Text(
          _source.isVideo
              ? context.tr('Vidéo : la carte montre l\'image de couverture avec un bouton lecture, et le QR ouvre la vidéo dans Afrolook.')
              : context.tr('L\'image est montrée en entier : les bords sont remplis par un flou, jamais par un recadrage.'),
          style: TextStyle(color: c.textSecondary, height: 1.4, fontSize: 13),
        ),
      if (widget.compose) ...[
        const SizedBox(height: 8),
        TextButton.icon(onPressed: _addImages, icon: const Icon(Icons.swap_horiz_rounded, size: 18), label: Text(context.tr('Changer les images'))),
      ],
    ]);
  }

  // ── Onglet Style ──────────────────────────────────────────────────────────

  Widget _stylePanel(AppColors c) {
    Widget thumb(CardStyleId s) {
      final on = _spec.style == s;
      final pro = _quote.proStyles.contains(s.name);
      final deco = switch (s) {
        CardStyleId.kente => const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFFF2B705), Color(0xFF1AA24E), Color(0xFFC8321E), Color(0xFF121212)], stops: [0, .35, .7, 1])),
        CardStyleId.wax => const BoxDecoration(color: Color(0xFFE8590C), gradient: RadialGradient(colors: [Color(0xFFFFD43B), Color(0xFF0B7285), Color(0xFFC2255C), Color(0xFFE8590C)], stops: [.15, .4, .65, .9])),
        CardStyleId.neon => BoxDecoration(color: const Color(0xFF04070A), border: Border.all(color: const Color(0xFF2ECC71), width: 2), boxShadow: const [BoxShadow(color: Color(0x662ECC71), blurRadius: 10)]),
        CardStyleId.bogolan => const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFC98B4B), Color(0xFF3A200C), Color(0xFFC98B4B), Color(0xFF3A200C)], stops: [0, .35, .65, 1])),
      };
      return GestureDetector(
        onTap: () => setState(() {
          _spec.style = s;
        }),
        child: Padding(
          padding: const EdgeInsets.only(right: 10),
          child: Column(children: [
            Container(
              width: 64,
              height: 80,
              decoration: deco.copyWith(borderRadius: BorderRadius.circular(12), border: on ? Border.all(color: c.primary, width: 3) : deco.border),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(color: pro ? c.accent : c.primary, borderRadius: BorderRadius.circular(5)),
                    child: Text(pro ? '+${_quote.priceProStyle} 🪙' : tr('INCLUS'), style: TextStyle(color: pro ? const Color(0xFF1F1F1F) : c.onPrimary, fontSize: 8.5, fontWeight: FontWeight.w800)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(s.label, style: TextStyle(color: on ? c.primary : c.textSecondary, fontSize: 11, fontWeight: on ? FontWeight.w800 : FontWeight.w500)),
          ]),
        ),
      );
    }

    Widget toggle(String label, bool v, ValueChanged<bool> f) => FilterChip(label: Text(label), selected: v, onSelected: (x) => setState(() => f(x)), visualDensity: VisualDensity.compact);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(height: 108, child: ListView(scrollDirection: Axis.horizontal, children: [for (final s in CardStyleId.values) thumb(s)])),
      Wrap(spacing: 8, children: [
        toggle(context.tr('Pseudo'), _spec.showAuthor, (v) => _spec.showAuthor = v),
        toggle(context.tr('Statistiques'), _spec.showStats, (v) => _spec.showStats = v),
        toggle(context.tr('Date'), _spec.showDate, (v) => _spec.showDate = v),
      ]),
    ]);
  }

  // ── Onglet Texte ──────────────────────────────────────────────────────────

  Widget _textPanel(AppColors c) {
    final body = separateTags(_source.text).body;
    final sentences = splitSentences(body);
    final budget = cardCharBudget(_spec.format, hasMedia: _spec.imageOrder.isNotEmpty && _hasMedia);
    final cut = cardText(_source.text, _spec, hasMedia: _hasMedia);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextField(
        controller: _textCtl,
        minLines: 2,
        maxLines: 4,
        style: TextStyle(color: c.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          isDense: true,
          hintText: context.tr('Le texte de ta carte'),
          filled: true,
          fillColor: c.surfaceVariant,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        ),
        onChanged: (v) => setState(() {
          _source = _source.copyWith(text: v);
          _spec.pickedSentences.clear();
          _captureDone = false;
        }),
      ),
      const SizedBox(height: 6),
      Text(
        cut.truncated
            ? context.tr('Texte coupé proprement ({n} caractères au maximum) : « Lire la suite » est ajouté.', {'n': budget})
            : context.tr('Le texte tient en entier ({n} caractères au maximum sur ce format).', {'n': budget}),
        style: TextStyle(color: cut.truncated ? c.warning : c.textSecondary, fontSize: 12),
      ),
      const SizedBox(height: 8),
      Wrap(spacing: 8, children: [
        ChoiceChip(label: Text(context.tr('Début')), selected: _spec.textMode == CardTextMode.start, onSelected: (_) => setState(() => _spec.textMode = CardTextMode.start), visualDensity: VisualDensity.compact),
        if (sentences.length > 1)
          ChoiceChip(label: Text(context.tr('Choisir les phrases')), selected: _spec.textMode == CardTextMode.pick, onSelected: (_) => setState(() => _spec.textMode = CardTextMode.pick), visualDensity: VisualDensity.compact),
      ]),
      if (_spec.textMode == CardTextMode.pick && sentences.length > 1) ...[
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (var i = 0; i < sentences.length; i++)
            FilterChip(
              label: Text(sentences[i].length > 34 ? '${sentences[i].substring(0, 34)}…' : sentences[i], style: const TextStyle(fontSize: 12)),
              selected: _spec.pickedSentences.contains(i),
              onSelected: (v) => setState(() => v ? _spec.pickedSentences.add(i) : _spec.pickedSentences.remove(i)),
              visualDensity: VisualDensity.compact,
            ),
        ]),
      ],
      const SizedBox(height: 10),
      Text(context.tr('Police'), style: TextStyle(color: c.textSecondary, fontSize: 12, fontWeight: FontWeight.w700)),
      const SizedBox(height: 4),
      Wrap(spacing: 8, children: [
        for (final f in CardFont.values)
          ChoiceChip(
            label: Text(f == CardFont.auto ? context.tr('Du style') : f.label, style: TextStyle(fontFamily: f.family, fontWeight: f.weight)),
            selected: _spec.font == f,
            onSelected: (_) => setState(() => _spec.font = f),
            visualDensity: VisualDensity.compact,
          ),
      ]),
    ]);
  }

  // ── Onglet Format ─────────────────────────────────────────────────────────

  Widget _formatPanel(AppColors c) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 8, children: [
          for (final f in CardFormat.values)
            ChoiceChip(label: Text(f.label), selected: _spec.format == f, onSelected: (_) => setState(() => _spec.format = f), visualDensity: VisualDensity.compact),
        ]),
        const SizedBox(height: 10),
        Text(
          context.tr('Portrait 4:5 s\'affiche sans être coupé dans le fil ; Story 9:16 est le format des chroniques. Le cadre média se règle tout seul pour ne rien couper.'),
          style: TextStyle(color: c.textSecondary, fontSize: 13, height: 1.4),
        ),
      ]);

  // ── Boutons d'action ──────────────────────────────────────────────────────

  static const _btnStyle = ButtonStyle(padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 8, vertical: 10)), textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 13, fontWeight: FontWeight.w700)));

  Widget _actions(AppColors c) {
    Widget btn(IconData i, String label, CardCost? cost, VoidCallback f, {bool primary = false, String? done}) => Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(
                width: double.infinity,
                child: (primary
                    ? FilledButton.icon(style: _btnStyle, onPressed: _busy ? null : f, icon: Icon(i, size: 16), label: FittedBox(fit: BoxFit.scaleDown, child: Text(label, maxLines: 1)))
                    : OutlinedButton.icon(style: _btnStyle, onPressed: _busy ? null : f, icon: Icon(i, size: 16), label: FittedBox(fit: BoxFit.scaleDown, child: Text(label, maxLines: 1)))),
              ),
              const SizedBox(height: 3),
              Text(done ?? (cost == null ? '' : cost.label), style: TextStyle(color: (done != null || (cost?.free ?? false)) ? c.primary : c.supportAccent, fontSize: 11.5, fontWeight: FontWeight.w800)),
            ]),
          ),
        );

    final capDone = _captureDone && (!_isPro || _capturePaidPro);
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: BoxDecoration(color: c.surface, border: Border(top: BorderSide(color: c.border.withOpacity(0.5)))),
      child: Row(children: [
        if (widget.compose)
          btn(Icons.check_circle_rounded, context.tr('Utiliser cette carte'), _quote.cost(CardKind.publish, pro: _isPro), _useCard, primary: true)
        else ...[
          btn(Icons.download_rounded, context.tr('Enregistrer'), _quote.cost(CardKind.capture, pro: _isPro), _save, done: capDone ? tr('Déjà réglé') : null),
          btn(Icons.ios_share_rounded, context.tr('Partager'), _quote.cost(CardKind.capture, pro: _isPro), _share, done: capDone ? tr('Déjà réglé') : null),
          btn(Icons.rocket_launch_rounded, context.tr('Publier'), _quote.cost(CardKind.publish, pro: _isPro), _publish, primary: true),
        ],
      ]),
    );
  }
}

class _PriceChip extends StatelessWidget {
  const _PriceChip({required this.cost});
  final CardCost cost;
  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: (cost.free ? c.primary : c.accent).withOpacity(0.18), borderRadius: BorderRadius.circular(8)),
      child: Text(cost.label, style: TextStyle(color: cost.free ? c.primary : c.supportAccent, fontWeight: FontWeight.w800, fontSize: 12)),
    );
  }
}
