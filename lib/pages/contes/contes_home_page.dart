
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../ads/ad_gate.dart';
import '../../l10n/tr.dart';
import '../../providers/authProvider.dart';
import '../../services/coin_checkout.dart';
import '../../services/contes/contes_service.dart';
import '../../widgets/module_ad_free_card.dart';
import '../quiz/widgets/quiz_ads.dart';
import 'conte_reader_page.dart';
import 'conte_scene.dart';
import 'conte_style.dart';

/// « La Case aux Contes » : le conte du jour, ce que le lecteur n'a pas encore lu en premier, les recueils, et son historique.
class ContesHomePage extends StatefulWidget {
  const ContesHomePage({super.key});

  @override
  State<ContesHomePage> createState() => _ContesHomePageState();
}

class _ContesHomePageState extends State<ContesHomePage> with EtudeAdBypass {
  ContesCatalog? _catalog;
  bool _error = false;
  String _category = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool force = false}) async {
    setState(() => _error = false);
    try {
      final r = await Future.wait([ContesService.instance.catalog(force: force), ContesService.instance.loadState()]);
      if (mounted) setState(() => _catalog = r[0] as ContesCatalog);
    } catch (_) {
      if (mounted && _catalog == null) setState(() => _error = true);
    }
  }

  Future<void> _open(ConteCard c) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => ConteReaderPage(card: c)));
    if (mounted) {
      ContesService.instance.loadState().catchError((_) => const ContesState());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ConteStyle.night,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 12, 0),
            child: Row(children: [
              IconButton(icon: const Icon(Icons.arrow_back_rounded, color: ConteStyle.parch2), onPressed: () => Navigator.pop(context)),
              Expanded(child: Text(context.tr('La Case aux Contes'), style: ConteStyle.title(20, color: ConteStyle.parch))),
            ]),
          ),
          Expanded(child: _content()),
        ]),
      ),
    );
  }

  Widget _content() {
    if (_error) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(context.tr('La Case aux Contes est fermée pour le moment.'), textAlign: TextAlign.center, style: ConteStyle.title(15, color: ConteStyle.parch)),
            const SizedBox(height: 8),
            Text(context.tr('Vérifie ta connexion et réessaie.'), textAlign: TextAlign.center, style: ConteStyle.body(17, color: ConteStyle.parch2)),
            const SizedBox(height: 16),
            SizedBox(width: 220, child: ConteButton(label: context.tr('Réessayer'), kind: ConteButtonKind.gold, onTap: () => _load(force: true))),
          ]),
        ),
      );
    }
    final cat = _catalog;
    if (cat == null) return const Center(child: CircularProgressIndicator(color: ConteStyle.gold2));
    if (cat.cards.isEmpty) {
      return Center(child: Text(context.tr('Les premiers contes arrivent bientôt.'), style: ConteStyle.body(18, color: ConteStyle.parch2, style: FontStyle.italic)));
    }
    return ValueListenableBuilder<ContesState?>(
      valueListenable: ContesService.instance.state,
      builder: (context, st, _) => RefreshIndicator(
        color: ConteStyle.gold,
        onRefresh: () => _load(force: true),
        child: _list(cat, st ?? const ContesState()),
      ),
    );
  }

  List<ConteCard> _unreadFirst(ContesCatalog cat, ContesState st) {
    final unread = cat.cards.where((c) => !st.isRead(c.id) && c.id != st.dailyId).toList();
    // un conte de chaque recueil à tour de rôle, les « à la une » d'abord
    final byCol = <String, List<ConteCard>>{};
    for (final c in unread) {
      byCol.putIfAbsent(c.collectionId, () => []).add(c);
    }
    final feat = unread.where((c) => c.featured).toList();
    final out = <ConteCard>[...feat];
    var i = 0;
    var added = true;
    while (added && out.length < 14) {
      added = false;
      for (final col in cat.collections) {
        final l = byCol[col.id];
        if (l != null && i < l.length && !out.contains(l[i])) {
          out.add(l[i]);
          added = true;
        }
      }
      i++;
    }
    return out.take(14).toList();
  }

  Widget _list(ContesCatalog cat, ContesState st) {
    final daily = cat.byId(st.dailyId);
    final first = _unreadFirst(cat, st);
    final categories = <String>{...cat.collections.map((c) => c.category)}.toList();
    final cols = cat.collections.where((c) => _category.isEmpty || c.category == _category).toList();
    final history = cat.cards.where((c) => st.isRead(c.id)).toList()..sort((a, b) => (st.reads[b.id] ?? 0).compareTo(st.reads[a.id] ?? 0));
    final children = <Widget>[];

    if (daily != null) children.add(_dailyCard(daily, st));
    children.add(_passBanner(st));
    children.add(const ModuleAdFreeCard(style: ModuleAdFreeStyle.conte, margin: EdgeInsets.fromLTRB(14, 0, 14, 12)));

    children.add(
      SizedBox(
        height: 36,
        child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 14), children: [
          _chip(context.tr('Tous'), _category.isEmpty, () => setState(() => _category = '')),
          for (final c in categories) _chip(c, _category == c, () => setState(() => _category = c)),
        ]),
      ),
    );

    if (first.isNotEmpty && _category.isEmpty) {
      children.add(_sectionTitle(context.tr('À lire en premier'), context.tr('Tu ne les as pas encore lus')));
      children.add(_shelf(first, st));
      children.add(const _AdBlock());
    }

    var shown = 0;
    for (final col in cols) {
      final list = cat.inCollection(col.id);
      if (list.isEmpty) continue;
      // les contes non lus d'abord, les contes lus à la fin de l'étagère
      final ordered = [...list.where((c) => !st.isRead(c.id)), ...list.where((c) => st.isRead(c.id))];
      final readCount = list.where((c) => st.isRead(c.id)).length;
      children.add(_sectionTitle(col.title, '${col.desc}  ·  ${context.tr('{a}/{b} lus', {'a': '$readCount', 'b': '${list.length}'})}'));
      children.add(_shelf(ordered, st));
      if (++shown % 2 == 0) children.add(const _AdBlock());
    }

    if (history.isNotEmpty && _category.isEmpty) {
      children.add(_sectionTitle(context.tr('Mon historique'), context.tr('Les contes que tu as déjà ouverts')));
      for (final c in history.take(30)) {
        children.add(_historyRow(c, st));
      }
    }
    children.add(const SizedBox(height: 28));
    return ListView(padding: const EdgeInsets.only(bottom: 12), children: children);
  }

  Widget _chip(String text, bool on, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(color: on ? ConteStyle.gold2 : Colors.transparent, borderRadius: BorderRadius.circular(99), border: Border.all(color: on ? ConteStyle.gold2 : ConteStyle.ink2)),
          child: Text(text, style: ConteStyle.body(15.5, color: on ? ConteStyle.ink : ConteStyle.parch2, weight: FontWeight.w600, height: 1)),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, String sub) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: ConteStyle.title(16, color: ConteStyle.gold2)),
          const SizedBox(height: 2),
          Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: ConteStyle.body(14.5, color: ConteStyle.parch2.withOpacity(.8), style: FontStyle.italic, height: 1.2)),
        ]),
      );

  Widget _shelf(List<ConteCard> cards, ContesState st) {
    return SizedBox(
      height: 196,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: cards.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) => ConteCover(card: cards[i], st: st, onTap: () => _open(cards[i])),
      ),
    );
  }

  Widget _dailyCard(ConteCard c, ContesState st) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
      child: GestureDetector(
        onTap: () => _open(c),
        child: Container(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Color(0x88000000), blurRadius: 12, offset: Offset(0, 5))]),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Parchment(
              seed: 9,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const BogolanBand(height: 9),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                  child: Container(
                    decoration: BoxDecoration(border: Border.all(color: ConteStyle.ink, width: 2.2), borderRadius: BorderRadius.circular(3)),
                    child: Container(
                      margin: const EdgeInsets.all(2.5),
                      decoration: BoxDecoration(border: Border.all(color: ConteStyle.gold)),
                      clipBehavior: Clip.antiAlias,
                      child: AspectRatio(aspectRatio: 300 / 150, child: ConteScene(spec: c.scene)),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      ConteTag(context.tr('Conte du jour')),
                      const SizedBox(width: 6),
                      ConteTag(context.tr('Gratuit aujourd\'hui'), free: true),
                      const SizedBox(width: 6),
                      ConteTag(context.tr('{n} min', {'n': '${c.minutes}'}), dark: false),
                    ]),
                    const SizedBox(height: 10),
                    Text(c.title, style: ConteStyle.title(19)),
                    const SizedBox(height: 4),
                    Text(c.hook, style: ConteStyle.body(17, style: FontStyle.italic, color: ConteStyle.ink2)),
                    const SizedBox(height: 12),
                    ConteButton(label: st.isRead(c.id) ? context.tr('Relire') : context.tr('Ouvrir le livre'), icon: Icons.auto_stories_rounded, onTap: () => _open(c)),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _passBanner(ContesState st) {
    final cfg = st.cfg;
    if (st.passActive) {
      final left = Duration(milliseconds: st.passUntil - DateTime.now().millisecondsSinceEpoch);
      final h = left.inHours;
      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: ConteStyle.green.withOpacity(.25), borderRadius: BorderRadius.circular(12), border: Border.all(color: ConteStyle.green)),
          child: Row(children: [
            const Icon(Icons.nights_stay_rounded, color: ConteStyle.gold2),
            const SizedBox(width: 10),
            Expanded(child: Text(context.tr('Pass Veillée actif : tous les contes sont ouverts, encore {h} h.', {'h': '${h < 1 ? 1 : h}'}), style: ConteStyle.body(16, color: ConteStyle.parch))),
          ]),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      child: GestureDetector(
        onTap: _buyPass,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: ConteStyle.night2, borderRadius: BorderRadius.circular(12), border: Border.all(color: ConteStyle.gold.withOpacity(.7))),
          child: Row(children: [
            const Icon(Icons.nights_stay_rounded, color: ConteStyle.gold2),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(context.tr('Pass Veillée {h} h', {'h': '${cfg.passHours}'}), style: ConteStyle.body(17, color: ConteStyle.parch, weight: FontWeight.w600)),
                Text(context.tr('Tous les contes ouverts, sans pub à regarder'), style: ConteStyle.body(14.5, color: ConteStyle.parch2, style: FontStyle.italic)),
              ]),
            ),
            Text(context.tr('{a} pièces', {'a': CoinCheckout.fmt(cfg.pricePass)}), style: ConteStyle.body(16, color: ConteStyle.gold2, weight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }

  Future<void> _buyPass() async {
    final cfg = ContesService.instance.state.value?.cfg ?? const ContesCfg();
    final user = context.read<UserAuthProvider>().loginUserData;
    if ((user.giftCoinsBalance ?? 0) < cfg.pricePass) {
      await CoinCheckout.insufficient(context, cfg.pricePass);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ConteStyle.parch,
        title: Text(context.tr('Pass Veillée {h} h', {'h': '${cfg.passHours}'}), style: ConteStyle.title(17)),
        content: Text(context.tr('Ouvrir tous les contes pendant {h} h pour {p} pièces ?', {'h': '${cfg.passHours}', 'p': CoinCheckout.fmt(cfg.pricePass)}), style: ConteStyle.body(18)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.tr('Annuler'), style: ConteStyle.body(17, color: ConteStyle.ink2))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(context.tr('Payer'), style: ConteStyle.body(17, color: ConteStyle.ember, weight: FontWeight.w600))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ContesService.instance.unlock('pass', via: 'coins');
      if (mounted) await CoinCheckout.refreshBalance(context);
    } on ConteException catch (e) {
      if (mounted && e.code.toLowerCase().contains('insuffisant')) await CoinCheckout.insufficient(context, cfg.pricePass);
    } catch (_) {}
  }

  Widget _historyRow(ConteCard c, ContesState st) {
    final ms = st.reads[c.id] ?? 0;
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    final diff = DateTime.now().difference(d);
    final when = diff.inMinutes < 60
        ? context.tr('à l\'instant')
        : diff.inHours < 24
            ? context.tr('il y a {n} h', {'n': '${diff.inHours}'})
            : context.tr('il y a {n} j', {'n': '${diff.inDays}'});
    return InkWell(
      onTap: () => _open(c),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(children: [
          ClipRRect(borderRadius: BorderRadius.circular(6), child: SizedBox(width: 64, height: 48, child: ConteScene(spec: c.scene))),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: ConteStyle.body(17, color: ConteStyle.parch, weight: FontWeight.w600, height: 1.15)),
              Text('${st.isDone(c.id) ? context.tr('Terminé') : context.tr('Commencé')}  ·  $when', style: ConteStyle.body(14, color: ConteStyle.parch2.withOpacity(.8), style: FontStyle.italic)),
            ]),
          ),
          Icon(st.isDone(c.id) ? Icons.check_circle_rounded : Icons.bookmark_rounded, color: st.isDone(c.id) ? ConteStyle.green : ConteStyle.gold2, size: 20),
        ]),
      ),
    );
  }
}

class _AdBlock extends StatelessWidget {
  const _AdBlock();
  @override
  Widget build(BuildContext context) => const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: QuizAdInline());
}

/// Couverture de livre : gravure, titre, pastille « Gratuit », « Lu » ou cadenas.
class ConteCover extends StatelessWidget {
  const ConteCover({required this.card, required this.st, required this.onTap});
  final ConteCard card;
  final ContesState st;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final read = st.isRead(card.id);
    final free = st.cfg.priceOf(card) <= 0 || card.id == st.dailyId;
    final open = st.canReadFully(card);
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: read ? .72 : 1,
        child: Container(
          width: 128,
          decoration: BoxDecoration(
            color: ConteStyle.ink,
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(3), right: Radius.circular(9)),
            border: const Border(left: BorderSide(color: Color(0xFF120B06), width: 6)),
            boxShadow: const [BoxShadow(color: Color(0x88000000), blurRadius: 6, offset: Offset(3, 4))],
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(
                child: Stack(fit: StackFit.expand, children: [
                  ConteScene(spec: card.scene),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: free
                        ? const ConteTag('Gratuit', free: true)
                        : read
                            ? const Icon(Icons.check_circle_rounded, color: ConteStyle.gold2, size: 20)
                            : open
                                ? const SizedBox.shrink()
                                : Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Color(0xAA000000), shape: BoxShape.circle), child: const Icon(Icons.lock_rounded, color: ConteStyle.gold2, size: 14)),
                  ),
                ]),
              ),
              Container(
                height: 62,
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                color: ConteStyle.ink,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(card.title, maxLines: 3, overflow: TextOverflow.ellipsis, style: ConteStyle.body(13.5, color: ConteStyle.parch, weight: FontWeight.w600, height: 1.12)),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
