import 'package:flutter/material.dart';

import '../../l10n/tr.dart';
import '../../services/coin_checkout.dart';
import '../../services/etude/etude_service.dart';
import '../../theme/app_colors.dart';
import '../quiz/widgets/quiz_widgets.dart';
import 'etude_chapter_page.dart';
import 'etude_flow.dart';

IconData etudeIcon(String name) {
  switch (name) {
    case 'calculate':
      return Icons.calculate_rounded;
    case 'menu_book':
      return Icons.menu_book_rounded;
    case 'translate':
      return Icons.translate_rounded;
    case 'eco':
      return Icons.eco_rounded;
    case 'science':
      return Icons.science_rounded;
    case 'public':
      return Icons.public_rounded;
    case 'account_tree':
      return Icons.account_tree_rounded;
    case 'code':
      return Icons.code_rounded;
    case 'storage':
      return Icons.storage_rounded;
    case 'work':
      return Icons.work_rounded;
    default:
      return Icons.school_rounded;
  }
}

/// Une classe (ou un module d'attestation) : matières, chapitres et composition de fin d'année.
class EtudeClassPage extends StatefulWidget {
  const EtudeClassPage({super.key, required this.track, required this.cls});
  final EtudeTrack track;
  final EtudeClass cls;

  @override
  State<EtudeClassPage> createState() => _EtudeClassPageState();
}

class _EtudeClassPageState extends State<EtudeClassPage> {
  @override
  void initState() {
    super.initState();
    EtudeService.instance.refresh().catchError((Object _) => const EtudeState());
  }

  bool _chapterDone(EtudeState s, EtudeChapter ch) => (s.levels[ch.id] ?? 0) >= ch.levels;

  bool _accessible(EtudeState s, EtudeChapter ch) => ch.free || s.unlocked['ch:${ch.id}'] == true || s.unlocked['cls:${widget.cls.id}'] == true;

  Future<void> _openChapter(EtudeChapter ch) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => EtudeChapterPage(chapter: ch)));
    if (mounted) await EtudeService.instance.refresh().catchError((Object _) => const EtudeState());
  }

  Future<void> _compo() async {
    final id = widget.cls.id;
    final ok = await etudeLaunch(context, kind: 'compo', id: id, item: 'compo:$id', title: context.tr('Composition · {c}', {'c': widget.cls.title}));
    if (ok && mounted) await EtudeService.instance.refresh().catchError((Object _) => const EtudeState());
  }

  Future<void> _classPass() async {
    final ok = await showEtudeUnlock(context, item: 'cls:${widget.cls.id}', title: context.tr('Pass {c}', {'c': widget.cls.title}));
    if (ok && mounted) await EtudeService.instance.refresh().catchError((Object _) => const EtudeState());
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        elevation: 0,
        iconTheme: IconThemeData(color: c.textPrimary),
        title: Text(widget.cls.title, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w900)),
      ),
      body: ValueListenableBuilder<EtudeState?>(
        valueListenable: EtudeService.instance.state,
        builder: (context, s, _) {
          final st = s ?? const EtudeState();
          final chapters = widget.cls.chapters;
          final allDone = chapters.isNotEmpty && chapters.every((ch) => _chapterDone(st, ch));
          final validated = st.classes.containsKey(widget.cls.id);
          final locked = chapters.any((ch) => !_accessible(st, ch));
          return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 28), children: [
            if (locked && widget.track.isCycle) _passCard(c, st),
            for (final sub in widget.cls.subjects) _subject(c, st, sub),
            if (widget.track.isCycle) _compoCard(c, st, allDone, validated),
          ]);
        },
      ),
    );
  }

  Widget _passCard(AppColors c, EtudeState st) {
    final price = st.priceOf('cls:${widget.cls.id}');
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: c.accent.withOpacity(0.14), borderRadius: BorderRadius.circular(16), border: Border.all(color: c.accent.withOpacity(0.6))),
      child: Row(children: [
        Icon(Icons.key_rounded, color: c.supportAccent, size: 28),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(context.tr('Pass de la classe'), style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w900)),
            Text(context.tr('Tous les chapitres et la composition : {p}', {'p': CoinCheckout.coinsLabel(price)}), style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
          ]),
        ),
        TextButton(onPressed: _classPass, child: Text(context.tr('Débloquer'))),
      ]),
    );
  }

  Widget _subject(AppColors c, EtudeState st, EtudeSubject sub) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: c.border, width: 1.4)),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
          child: Row(children: [
            Icon(etudeIcon(sub.icon), color: c.primary),
            const SizedBox(width: 10),
            Expanded(child: Text(sub.title, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w900, fontSize: 16))),
          ]),
        ),
        for (final ch in sub.chapters) _chapterRow(c, st, ch),
        const SizedBox(height: 6),
      ]),
    );
  }

  Widget _chapterRow(AppColors c, EtudeState st, EtudeChapter ch) {
    final done = _chapterDone(st, ch);
    final lv = (st.levels[ch.id] ?? 0).clamp(0, ch.levels);
    final open = _accessible(st, ch);
    final paid = st.adsPaid['ch:${ch.id}'] ?? 0;
    return InkWell(
      onTap: () => _openChapter(ch),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Row(children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: (done ? c.primary : (open ? c.info : c.textSecondary)).withOpacity(0.15), shape: BoxShape.circle),
            child: Icon(done ? Icons.check_rounded : (open ? Icons.menu_book_rounded : Icons.lock_rounded), size: 18, color: done ? c.primary : (open ? c.info : c.textSecondary)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(ch.title, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 14.5)),
              const SizedBox(height: 3),
              if (open)
                Row(children: [
                  for (var k = 0; k < ch.levels; k++)
                    Container(margin: const EdgeInsets.only(right: 4), width: 22, height: 5, decoration: BoxDecoration(color: k < lv ? c.primary : c.surfaceVariant, borderRadius: BorderRadius.circular(3))),
                  if (ch.free) Padding(padding: const EdgeInsets.only(left: 6), child: Text(context.tr('Gratuit'), style: TextStyle(color: c.primary, fontSize: 11, fontWeight: FontWeight.w800))),
                ])
              else
                Text(
                  paid > 0
                      ? context.tr('{p} · jauge {a}/{n}', {'p': CoinCheckout.coinsLabel(st.priceOf('ch:${ch.id}')), 'a': '$paid', 'n': '${st.priceOf('ch:${ch.id}')}'})
                      : CoinCheckout.coinsLabel(st.priceOf('ch:${ch.id}')),
                  style: TextStyle(color: c.textSecondary, fontSize: 12),
                ),
            ]),
          ),
          Icon(Icons.chevron_right_rounded, color: c.textSecondary),
        ]),
      ),
    );
  }

  Widget _compoCard(AppColors c, EtudeState st, bool allDone, bool validated) {
    final id = widget.cls.id;
    final free = st.freeEpreuve[widget.track.id];
    final paidAccess = st.unlocked['compo:$id'] == true || st.unlocked['cls:$id'] == true || free == 'compo:$id' || free == null;
    final color = validated ? c.primary : (allDone ? c.warning : c.textSecondary);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: color, width: 2)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(validated ? Icons.verified_rounded : Icons.assignment_rounded, color: color, size: 30),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(context.tr('Composition de fin d\'année'), style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w900, fontSize: 16)),
              Text(
                validated
                    ? context.tr('Classe validée avec {p} %', {'p': '${(st.classes[id] as Map)['pct']}'})
                    : allDone
                        ? context.tr('20 questions, il faut 50 % pour valider la classe')
                        : context.tr('Termine tous les chapitres pour la passer'),
                style: TextStyle(color: c.textSecondary, fontSize: 12.5),
              ),
            ]),
          ),
        ]),
        if (!validated) ...[
          const SizedBox(height: 12),
          QuizChunkyButton(
            label: !allDone
                ? context.tr('Chapitres à terminer')
                : (paidAccess ? context.tr(free == null ? 'Passer la composition (offerte)' : 'Passer la composition') : context.tr('Débloquer la composition')),
            icon: allDone ? Icons.edit_note_rounded : Icons.lock_rounded,
            color: allDone ? c.warning : c.surfaceVariant,
            textColor: allDone ? Colors.white : c.textSecondary,
            onPressed: allDone ? _compo : null,
          ),
        ],
      ]),
    );
  }
}
