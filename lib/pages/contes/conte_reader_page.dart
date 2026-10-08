import 'dart:async';

import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../../ads/ad_gate.dart';
import '../../providers/authProvider.dart';
import '../../l10n/tr.dart';
import '../../services/contes/conte_ambience.dart';
import '../../services/contes/contes_service.dart';
import '../../ads/module_ads.dart';
import '../../widgets/module_ad_free_card.dart';
import '../quiz/widgets/quiz_ads.dart';
import 'conte_scene.dart';
import 'conte_style.dart';
import 'conte_unlock.dart';

/// Lecture d'un conte : pages de livre (parchemin, gravure, lettrine), ouverture gratuite, page du sceau (déblocage),
/// page de fin (morale, conte suivant). L'ambiance de veillée se coupe d'une touche.
class ConteReaderPage extends StatefulWidget {
  const ConteReaderPage({super.key, required this.card});
  final ConteCard card;

  @override
  State<ConteReaderPage> createState() => _ConteReaderPageState();
}

class _ConteReaderPageState extends State<ConteReaderPage> with EtudeAdBypass, WidgetsBindingObserver {
  static double _scale = 1.0;

  final PageController _ctrl = PageController();
  ConteOpen? _open;
  bool _error = false;
  int _page = 0;
  bool _sealAsked = false;
  bool _finished = false;

  ConteCard get card => widget.card;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ConteAmbience.start();
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (!_finished && _open != null) ContesService.instance.track('leave', id: card.id, page: _page);
    ConteAmbience.stop();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ConteAmbience.resume();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      ConteAmbience.pause();
    }
  }

  Future<void> _load({bool keepPage = false}) async {
    if (!keepPage) setState(() => _error = false);
    try {
      if (ContesService.instance.state.value == null) await ContesService.instance.loadState();
      final o = await ContesService.instance.open(card.id);
      if (!mounted) return;
      setState(() => _open = o);
    } catch (_) {
      if (mounted && _open == null) setState(() => _error = true);
    }
  }

  int get _pageCount => _open?.pages.length ?? 0;
  bool get _locked => _open?.locked ?? false;
  int get _lastIndex => _pageCount; // seal ou fin
  int get _itemCount => _pageCount + 1;

  void _onPage(int i) {
    setState(() => _page = i);
    if (_locked && i == _lastIndex && !_sealAsked) {
      _sealAsked = true;
      Future<void>.delayed(const Duration(milliseconds: 500), () {
        if (mounted && _locked && _page == _lastIndex) _unlock();
      });
    }
    if (!_locked && i == _lastIndex && !_finished) {
      _finished = true;
      ContesService.instance.finish(card.id);
    }
  }

  Future<void> _unlock() async {
    final ok = await showConteUnlock(context, card: card);
    if (!ok || !mounted) return;
    final keep = _page;
    await _load(keepPage: true);
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_ctrl.hasClients) _ctrl.animateToPage(keep, duration: const Duration(milliseconds: 500), curve: Curves.easeOutCubic);
    });
  }

  Future<void> _openAdFree() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: ConteStyle.night,
      builder: (ctx) => SafeArea(child: Padding(padding: const EdgeInsets.all(16), child: Column(mainAxisSize: MainAxisSize.min, children: [const ModuleAdFreeCard(style: ModuleAdFreeStyle.conte)]))),
    );
    if (mounted) setState(() {});
  }

  ConteCard? _nextCard() {
    final cat = ContesService.instance.cachedCatalog;
    final st = ContesService.instance.state.value;
    final unread = cat.cards.where((c) => c.id != card.id && !(st?.isRead(c.id) ?? false)).toList();
    if (unread.isEmpty) return null;
    final same = unread.where((c) => c.collectionId == card.collectionId).toList();
    return (same.isNotEmpty ? same : unread).first;
  }

  void _leave(VoidCallback then) {
    final cfg = ContesService.instance.state.value?.cfg ?? const ContesCfg();
    levelEndInterstitial(context, prefix: 'contes', every: cfg.interstitialEveryStories, maxPerDay: cfg.interstitialMaxPerDay, then: () {
      if (mounted) then();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ConteStyle.night,
      body: SafeArea(
        child: Column(children: [
          _topBar(),
          Expanded(child: _body()),
        ]),
      ),
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 2, 4, 6),
      child: Row(children: [
        IconButton(icon: const Icon(Icons.arrow_back_rounded, color: ConteStyle.parch2), onPressed: () => Navigator.pop(context)),
        Expanded(
          child: Text(card.title, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: ConteStyle.label(13, color: ConteStyle.parch2)),
        ),
        IconButton(
          tooltip: context.tr('Taille du texte'),
          icon: const Icon(Icons.text_fields_rounded, color: ConteStyle.parch2),
          onPressed: () => setState(() => _scale = _scale >= 1.3 ? 0.9 : _scale + .2),
        ),
        ValueListenableBuilder<bool>(
          valueListenable: ConteAmbience.muted,
          builder: (context, muted, _) => IconButton(
            tooltip: muted ? context.tr("Activer l'ambiance sonore") : context.tr("Couper l'ambiance sonore"),
            icon: Icon(muted ? Icons.volume_off_rounded : Icons.volume_up_rounded, color: muted ? ConteStyle.ink2 : ConteStyle.gold2),
            onPressed: () {
              ContesService.instance.track(muted ? 'sound_on' : 'sound_off');
              ConteAmbience.setMuted(!muted);
            },
          ),
        ),
      ]),
    );
  }

  Widget _body() {
    if (_error) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(context.tr('Le livre ne veut pas s\'ouvrir.'), textAlign: TextAlign.center, style: ConteStyle.title(16, color: ConteStyle.parch)),
            const SizedBox(height: 8),
            Text(context.tr('Vérifie ta connexion et réessaie.'), textAlign: TextAlign.center, style: ConteStyle.body(17, color: ConteStyle.parch2)),
            const SizedBox(height: 18),
            SizedBox(width: 220, child: ConteButton(label: context.tr('Réessayer'), kind: ConteButtonKind.gold, onTap: _load)),
          ]),
        ),
      );
    }
    if (_open == null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 220,
            height: 140,
            decoration: BoxDecoration(border: Border.all(color: ConteStyle.gold2.withOpacity(.6), width: 1.5), borderRadius: BorderRadius.circular(6)),
            clipBehavior: Clip.antiAlias,
            child: ConteScene(spec: card.scene),
          ),
          const SizedBox(height: 16),
          Text(context.tr('Ouverture du livre…'), style: ConteStyle.body(18, color: ConteStyle.parch2, style: FontStyle.italic)),
          const SizedBox(height: 12),
          const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.2, color: ConteStyle.gold2)),
        ]),
      );
    }
    final o = _open!;
    return Column(children: [
      Expanded(
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), boxShadow: const [BoxShadow(color: Color(0x99000000), blurRadius: 14, offset: Offset(0, 6))]),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: PageView.builder(
              controller: _ctrl,
              itemCount: _itemCount,
              onPageChanged: _onPage,
              itemBuilder: (context, i) {
                if (i < o.pages.length) {
                  return ConteBookPage(text: o.pages[i], index: i, total: o.total, scene: _sceneFor(i), scale: _scale);
                }
                return o.locked ? ConteSealPage(card: card, onUnlock: _unlock) : ConteEndPage(card: card, morale: o.morale, next: _nextCard(), onNext: (n) => _leave(() => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ConteReaderPage(card: n)))), onBack: () => _leave(() => Navigator.pop(context)));
              },
            ),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var i = 0; i < _itemCount; i++)
            Container(
              width: i == _page ? 18 : 7,
              height: 7,
              margin: const EdgeInsets.symmetric(horizontal: 2.5),
              decoration: BoxDecoration(color: i == _page ? ConteStyle.gold2 : ConteStyle.ink2, borderRadius: BorderRadius.circular(4)),
            ),
        ]),
      ),
      const QuizAdBanner(minHeight: 720, padding: EdgeInsets.fromLTRB(16, 0, 16, 2)),
      // lien très discret, seulement quand une pub peut s'afficher dans cette page
      if (MediaQuery.of(context).size.height >= 720 && ModuleAds.shows(context.read<UserAuthProvider>().loginUserData))
        GestureDetector(
          onTap: _openAdFree,
          child: Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), child: Text(context.tr('Lire sans pub pendant 30 jours'), style: ConteStyle.body(13.5, color: ConteStyle.gold2.withOpacity(.85), style: FontStyle.italic))),
        ),
    ]);
  }

  /// Chaque page a sa propre gravure : mêmes décor et lumière, silhouettes et positions qui changent.
  SceneSpec _sceneFor(int page) {
    final s = card.scene;
    if (page == 0) return s;
    final f = [...s.figures];
    for (var k = 0; k < page % f.length; k++) {
      f.add(f.removeAt(0));
    }
    return SceneSpec(decor: s.decor, light: s.light, figures: f, seed: s.seed + page * 17);
  }
}

class ConteBookPage extends StatelessWidget {
  const ConteBookPage({required this.text, required this.index, required this.total, required this.scene, required this.scale});
  final String text;
  final int index, total;
  final SceneSpec scene;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final first = index == 0;
    final body = ConteStyle.body(19 * scale, height: 1.42);
    final trimmed = text.trim();
    final span = first && trimmed.isNotEmpty
        ? TextSpan(children: [
            TextSpan(text: trimmed.substring(0, 1), style: ConteStyle.title(46 * scale, color: ConteStyle.ember, height: 1.0)),
            TextSpan(text: trimmed.substring(1), style: body),
          ])
        : TextSpan(text: trimmed, style: body);
    return Parchment(
      seed: 3 + index,
      child: Column(children: [
        const BogolanBand(height: 9),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Container(
            decoration: BoxDecoration(border: Border.all(color: ConteStyle.ink, width: 2.2), borderRadius: BorderRadius.circular(3)),
            child: Container(
              margin: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(border: Border.all(color: ConteStyle.gold, width: 1)),
              clipBehavior: Clip.antiAlias,
              child: SizedBox(height: first ? 150 : 96, width: double.infinity, child: ConteScene(spec: scene)),
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 6),
            child: Text.rich(span, textAlign: TextAlign.justify),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 10),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('${index + 1}', style: ConteStyle.label(13)),
            if (first) Text(context.tr('Tourne la page'), style: ConteStyle.body(14, color: ConteStyle.ink2, style: FontStyle.italic)),
            Text('${index + 1} / $total', style: ConteStyle.label(13)),
          ]),
        ),
      ]),
    );
  }
}

class ConteSealPage extends StatelessWidget {
  const ConteSealPage({required this.card, required this.onUnlock});
  final ConteCard card;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    return Parchment(
      seed: 41,
      child: Column(children: [
        const BogolanBand(height: 9),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: const BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(center: Alignment(-.3, -.4), colors: [Color(0xFFE3694A), Color(0xFF8E2D18)]), boxShadow: [BoxShadow(color: Color(0x66000000), blurRadius: 8, offset: Offset(0, 4))]),
                  child: const Icon(Icons.lock_rounded, color: Color(0xFFF7D9A8), size: 34),
                ),
                const SizedBox(height: 18),
                Text(context.tr('La suite est scellée'), textAlign: TextAlign.center, style: ConteStyle.title(21)),
                const SizedBox(height: 12),
                const SizedBox(width: 160, child: ConteOrnament()),
                const SizedBox(height: 12),
                Text(card.hook, textAlign: TextAlign.center, style: ConteStyle.body(20, style: FontStyle.italic, color: ConteStyle.ink2)),
                const SizedBox(height: 22),
                ConteButton(label: context.tr('Lire la suite'), icon: Icons.lock_open_rounded, kind: ConteButtonKind.gold, onTap: onUnlock),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

class ConteEndPage extends StatelessWidget {
  const ConteEndPage({required this.card, required this.morale, required this.next, required this.onNext, required this.onBack});
  final ConteCard card;
  final String morale;
  final ConteCard? next;
  final void Function(ConteCard) onNext;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Parchment(
      seed: 77,
      child: Column(children: [
        const BogolanBand(height: 9),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(26, 22, 26, 16),
            child: Column(children: [
              Text(context.tr('FIN'), style: ConteStyle.title(30, color: ConteStyle.ember)),
              const SizedBox(height: 10),
              const SizedBox(width: 180, child: ConteOrnament()),
              const SizedBox(height: 18),
              if (morale.isNotEmpty) ...[
                Text(context.tr('Ce que dit le conte'), style: ConteStyle.label(13)),
                const SizedBox(height: 8),
                Text('« $morale »', textAlign: TextAlign.center, style: ConteStyle.body(21, style: FontStyle.italic, height: 1.4)),
                const SizedBox(height: 20),
              ],
              Container(
                decoration: BoxDecoration(border: Border.all(color: ConteStyle.ink, width: 2), borderRadius: BorderRadius.circular(3)),
                clipBehavior: Clip.antiAlias,
                child: SizedBox(height: 120, width: double.infinity, child: ConteScene(spec: SceneSpec(decor: card.scene.decor, light: 'nuit', figures: card.scene.figures, seed: card.scene.seed + 99))),
              ),
              const SizedBox(height: 8),
              Text(card.origin, textAlign: TextAlign.center, style: ConteStyle.body(14, color: ConteStyle.ink2, style: FontStyle.italic)),
              const SizedBox(height: 22),
              if (next != null) ...[
                Text(context.tr('À lire ensuite'), style: ConteStyle.label(13)),
                const SizedBox(height: 6),
                Text(next!.title, textAlign: TextAlign.center, style: ConteStyle.title(15)),
                const SizedBox(height: 4),
                Text(next!.hook, textAlign: TextAlign.center, style: ConteStyle.body(16, style: FontStyle.italic, color: ConteStyle.ink2)),
                const SizedBox(height: 12),
                ConteButton(label: context.tr('Lire ce conte'), icon: Icons.auto_stories_rounded, kind: ConteButtonKind.gold, onTap: () => onNext(next!)),
                const SizedBox(height: 8),
              ],
              ConteButton(label: context.tr('Retour à la Case aux Contes'), kind: ConteButtonKind.outline, onTap: onBack),
            ]),
          ),
        ),
      ]),
    );
  }
}
