import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../l10n/tr.dart';
import '../../../pages/contes/conte_reader_page.dart';
import '../../../pages/contes/conte_scene.dart';
import '../../../pages/contes/conte_style.dart';
import '../../../pages/contes/contes_home_page.dart';
import '../../../services/contes/contes_service.dart';

/// Un conte dans le fil : carte compacte (de la taille d'un post) avec le conte du jour, gratuit en entier.
/// La deuxième carte du fil propose un autre conte non lu, et seulement si le premier a été ouvert.
/// La croix masque la carte jusqu'à demain. Elle laisse la place si le lecteur a déjà lu le conte proposé.
class ContesFeedCard extends StatefulWidget {
  const ContesFeedCard({super.key, this.slot = 1});

  /// 1 : conte du jour ; 2 : un autre conte non lu (seulement si le conte du jour a été ouvert).
  final int slot;

  @override
  State<ContesFeedCard> createState() => _ContesFeedCardState();
}

class _ContesFeedCardState extends State<ContesFeedCard> {
  static const _kHidden = 'contes_feed_hidden_day';
  static final Set<String> _viewed = {};

  ConteCard? _card;

  static String _today() {
    final n = DateTime.now();
    return '${n.year}-${n.month}-${n.day}';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final sp = await SharedPreferences.getInstance();
      if (sp.getString('${_kHidden}_${widget.slot}') == _today()) return;
    } catch (_) {}
    try {
      final r = await Future.wait([ContesService.instance.catalog(), ContesService.instance.ensureState()]);
      final cat = r[0] as ContesCatalog;
      final st = r[1] as ContesState;
      if (!st.cfg.enabled || !st.cfg.feedEnabled || cat.cards.isEmpty) return;
      ConteCard? pick;
      if (widget.slot == 1) {
        pick = cat.byId(st.dailyId);
        // conte du jour déjà lu : la carte laisse la place à un post
        if (pick != null && st.isRead(pick.id)) pick = null;
      } else {
        if (!st.isRead(st.dailyId)) return;
        final unread = cat.cards.where((c) => !st.isRead(c.id) && c.id != st.dailyId).toList();
        if (unread.isNotEmpty) pick = unread[(DateTime.now().day + 3) % unread.length];
      }
      if (pick == null || !mounted) return;
      setState(() => _card = pick);
      final key = '${_today()}_${widget.slot}';
      if (_viewed.add(key)) ContesService.instance.track('feed_view');
    } catch (_) {}
  }

  Future<void> _hide() async {
    ContesService.instance.track('feed_dismiss');
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString('${_kHidden}_${widget.slot}', _today());
    } catch (_) {}
    if (mounted) setState(() => _card = null);
  }

  void _open(ConteCard c) {
    ContesService.instance.track('feed_click');
    Navigator.push(context, MaterialPageRoute(builder: (_) => ConteReaderPage(card: c)));
  }

  @override
  Widget build(BuildContext context) {
    final c = _card;
    if (c == null) return const SizedBox.shrink();
    final free = widget.slot == 1;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: GestureDetector(
        onTap: () => _open(c),
        child: Container(
          decoration: BoxDecoration(
            color: ConteStyle.night2,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ConteStyle.gold.withOpacity(.75), width: 1.3),
            boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 8, offset: Offset(0, 3))],
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(children: [
            SizedBox(width: 108, height: 132, child: ConteScene(spec: c.scene)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 6, 10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(free ? context.tr('Conte du jour') : context.tr('À lire ensuite'), style: ConteStyle.label(12, color: ConteStyle.gold2))),
                    InkWell(onTap: _hide, borderRadius: BorderRadius.circular(20), child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.close_rounded, size: 18, color: ConteStyle.parch2))),
                  ]),
                  Text(c.title, maxLines: 3, overflow: TextOverflow.ellipsis, style: ConteStyle.body(18, color: ConteStyle.parch, weight: FontWeight.w600, height: 1.12)),
                  const SizedBox(height: 4),
                  Text(c.hook, maxLines: 2, overflow: TextOverflow.ellipsis, style: ConteStyle.body(14.5, color: ConteStyle.parch2, style: FontStyle.italic, height: 1.15)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: ConteStyle.gold, borderRadius: BorderRadius.circular(9)),
                      child: Text(free ? context.tr('Lire gratuitement') : context.tr('Lire ce conte'), style: ConteStyle.body(14.5, color: Colors.white, weight: FontWeight.w600, height: 1)),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ContesHomePage())),
                      child: Text(context.tr('Tous les contes'), style: ConteStyle.body(14, color: ConteStyle.gold2, weight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 6),
                  ]),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
