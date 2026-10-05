import 'package:flutter/material.dart';

import '../../l10n/tr.dart';
import '../../services/etude/etude_service.dart';
import '../../theme/app_colors.dart';
import '../quiz/widgets/hawk_mascot.dart';
import '../quiz/widgets/quiz_loading.dart';
import 'etude_flow.dart';

/// Un chapitre : fiche de cours courte, puis 3 niveaux d'exercices.
class EtudeChapterPage extends StatefulWidget {
  const EtudeChapterPage({super.key, required this.chapter});
  final EtudeChapter chapter;

  @override
  State<EtudeChapterPage> createState() => _EtudeChapterPageState();
}

class _EtudeChapterPageState extends State<EtudeChapterPage> {
  EtudeLesson? _lesson;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final l = await EtudeService.instance.openChapter(widget.chapter.id);
      if (mounted) setState(() => _lesson = l);
    } on EtudeException catch (e) {
      if (!mounted) return;
      if (e.code.contains('LOCKED')) {
        final ok = await showEtudeUnlock(context, item: 'ch:${widget.chapter.id}', title: widget.chapter.title);
        if (!mounted) return;
        if (ok) return _load();
        Navigator.pop(context);
        return;
      }
      setState(() => _error = e.code);
    } catch (_) {
      if (mounted) setState(() => _error = 'NETWORK');
    }
  }

  Future<void> _play(int level) async {
    final done = await etudeLaunch(context, kind: 'level', id: '${widget.chapter.id}:$level', item: 'ch:${widget.chapter.id}', title: widget.chapter.title);
    if (done && mounted) {
      final l = await EtudeService.instance.openChapter(widget.chapter.id).catchError((Object _) => _lesson!);
      if (mounted) setState(() => _lesson = l);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l = _lesson;
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        elevation: 0,
        iconTheme: IconThemeData(color: c.textPrimary),
        title: Text(widget.chapter.title, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w900, fontSize: 17)),
      ),
      body: _error != null
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              const HawkMascot(mood: HawkMood.sad, size: 110),
              const SizedBox(height: 10),
              Text(context.tr('Une erreur est survenue, réessaie.'), style: TextStyle(color: c.textSecondary)),
              TextButton(onPressed: _load, child: Text(context.tr('Réessayer'))),
            ]))
          : l == null
              ? const QuizLoading(kind: QuizLoadingKind.level)
              : ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 28), children: [
                  _lessonCard(c, l),
                  const SizedBox(height: 18),
                  Text(context.tr('Exercices'), style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w900, fontSize: 18)),
                  const SizedBox(height: 8),
                  for (var k = 1; k <= l.levels; k++) _levelTile(c, l, k),
                ]),
    );
  }

  Widget _lessonCard(AppColors c, EtudeLesson l) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: c.border, width: 1.4)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.menu_book_rounded, color: c.info),
          const SizedBox(width: 8),
          Text(context.tr('Fiche de cours'), style: TextStyle(color: c.info, fontWeight: FontWeight.w900, fontSize: 14)),
        ]),
        const SizedBox(height: 10),
        for (final b in l.blocks) _block(c, b),
      ]),
    );
  }

  Widget _block(AppColors c, Map<String, String> b) {
    final t = b['t'];
    final x = b['x'] ?? '';
    if (t == 'li') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.only(top: 7, right: 8), child: Icon(Icons.circle, size: 6, color: c.primary)),
          Expanded(child: Text(x, style: TextStyle(color: c.textPrimary, fontSize: 14.5, height: 1.45))),
        ]),
      );
    }
    if (t == 'note') {
      return Container(
        margin: const EdgeInsets.only(top: 4, bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: c.accent.withOpacity(0.16), borderRadius: BorderRadius.circular(12), border: Border(left: BorderSide(color: c.accent, width: 4))),
        child: Text(x, style: TextStyle(color: c.textPrimary, fontSize: 14, height: 1.45, fontWeight: FontWeight.w600)),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(x, style: TextStyle(color: c.textPrimary, fontSize: 15, height: 1.5)),
    );
  }

  Widget _levelTile(AppColors c, EtudeLesson l, int k) {
    final done = l.done >= k;
    final open = k <= l.done + 1;
    final color = done ? c.primary : (open ? c.info : c.textSecondary);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: open ? () => _play(k) : null,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: done ? c.primary : c.border, width: 1.6),
          ),
          child: Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
              child: Icon(done ? Icons.check_rounded : (open ? Icons.play_arrow_rounded : Icons.lock_rounded), color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(context.tr('Niveau {n}', {'n': '$k'}), style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 16)),
                Text(
                  done ? context.tr('Réussi · tu peux le rejouer') : (open ? context.tr('5 questions') : context.tr('Réussis le niveau précédent')),
                  style: TextStyle(color: c.textSecondary, fontSize: 12.5),
                ),
              ]),
            ),
            if (open) Icon(Icons.chevron_right_rounded, color: c.textSecondary),
          ]),
        ),
      ),
    );
  }
}
