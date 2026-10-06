import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../l10n/tr.dart';
import '../../../pages/etude/etude_chapter_page.dart';
import '../../../pages/etude/etude_home_page.dart';
import '../../../pages/quiz/quiz_defi_lines.dart';
import '../../../pages/quiz/widgets/hawk_mascot.dart';
import '../../../pages/quiz/widgets/quiz_widgets.dart';
import '../../../services/etude/etude_service.dart';
import '../../../theme/app_colors.dart';

/// Un extrait de cours universitaire dans le fil : un chapitre gratuit change chaque jour, avec un court résumé
/// et un bouton pour lire le cours. La croix masque la carte jusqu'à demain.
class EtudeFeedCard extends StatefulWidget {
  const EtudeFeedCard({super.key, this.slot = 1});

  /// 1 ou 2 : deux cartes du même fil montrent des cours différents.
  final int slot;

  @override
  State<EtudeFeedCard> createState() => _EtudeFeedCardState();
}

class _Pick {
  const _Pick(this.track, this.chapter, this.teaser);
  final EtudeTrack track;
  final EtudeChapter chapter;
  final String teaser;
}

class _EtudeFeedCardState extends State<EtudeFeedCard> {
  static const _kHidden = 'etude_feed_hidden_day';
  static final Map<int, Future<_Pick?>> _picks = {};

  _Pick? _pick;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  static String _today() {
    final n = DateTime.now();
    return '${n.year}-${n.month}-${n.day}';
  }

  Future<_Pick?> _choose(int slot) async {
    final tracks = await EtudeService.instance.catalog();
    final free = <(EtudeTrack, EtudeChapter)>[];
    for (final t in tracks) {
      if (!t.isCycle || !t.id.startsWith('univ')) continue;
      for (final cls in t.classes) {
        for (final sub in cls.subjects) {
          for (final ch in sub.chapters) {
            if (ch.free) free.add((t, ch));
          }
        }
      }
    }
    if (free.isEmpty) return null;
    final d = DateTime.now();
    final i = (d.year * 372 + d.month * 31 + d.day + slot * 7) % free.length;
    final (track, chapter) = free[i];
    final lesson = await EtudeService.instance.openChapter(chapter.id);
    final p = lesson.blocks.where((b) => b['t'] == 'p').map((b) => b['x'] ?? '').firstWhere((x) => x.isNotEmpty, orElse: () => '');
    final teaser = p.length > 170 ? '${p.substring(0, 167).trimRight()}…' : p;
    return _Pick(track, chapter, teaser);
  }

  Future<void> _load() async {
    try {
      final sp = await SharedPreferences.getInstance();
      if (sp.getString(_kHidden) == _today()) {
        if (mounted) setState(() => _ready = true);
        return;
      }
    } catch (_) {}
    try {
      final pick = await _picks.putIfAbsent(widget.slot, () => _choose(widget.slot));
      if (mounted) {
        setState(() {
          _pick = pick;
          _ready = true;
        });
      }
    } catch (_) {
      _picks.remove(widget.slot);
      if (mounted) setState(() => _ready = true);
    }
  }

  Future<void> _hide() async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(_kHidden, _today());
    } catch (_) {}
    if (mounted) setState(() => _pick = null);
  }

  @override
  Widget build(BuildContext context) {
    final p = _pick;
    if (!_ready || p == null) return const SizedBox.shrink();
    final c = AppColors.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [c.info.withOpacity(0.18), c.surface], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.info.withOpacity(0.5), width: 1.4),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.menu_book_rounded, color: c.info, size: 20),
          const SizedBox(width: 6),
          Expanded(child: Text(context.tr('Cours du jour'), style: TextStyle(color: c.info, fontWeight: FontWeight.w900, fontSize: 13))),
          InkWell(
            onTap: _hide,
            borderRadius: BorderRadius.circular(20),
            child: Padding(padding: const EdgeInsets.all(4), child: Icon(Icons.close_rounded, size: 18, color: c.textSecondary)),
          ),
        ]),
        const SizedBox(height: 6),
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          const HawkMascot(mood: HawkMood.wave, size: 54, accessory: 'acc_glasses'),
          const SizedBox(width: 8),
          Expanded(
            child: QuizBubble(
              child: Text(
                context.tr(pickDefiLine([...kEtudeDefiLines, ...kQuizDefiLines], p.chapter.title.length)),
                style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 13, height: 1.3),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        Text(p.chapter.title, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w900, fontSize: 17, height: 1.25)),
        const SizedBox(height: 2),
        Text(p.track.title, style: TextStyle(color: c.textSecondary, fontSize: 12, fontWeight: FontWeight.w700)),
        if (p.teaser.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(p.teaser, style: TextStyle(color: c.textPrimary, fontSize: 14, height: 1.4)),
        ],
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            flex: 3,
            child: QuizChunkyButton(
              label: context.tr('Lire le cours'),
              icon: Icons.menu_book_rounded,
              color: c.info,
              textColor: Colors.white,
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EtudeChapterPage(chapter: p.chapter))),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EtudeHomePage())),
              child: Text(context.tr('Tous les parcours'), textAlign: TextAlign.center, style: TextStyle(color: c.info, fontWeight: FontWeight.w800, fontSize: 12.5)),
            ),
          ),
        ]),
      ]),
    );
  }
}
