import 'package:flutter/material.dart';

import '../../l10n/tr.dart';
import '../../services/quiz/quiz_service.dart';
import '../../theme/app_colors.dart';
import 'widgets/hawk_mascot.dart';
import 'widgets/quiz_widgets.dart';

/// « Mes questions » : ce qu'il reste à répondre dans le parcours, et tout ce qui a déjà été répondu.
class QuizHistoryPage extends StatefulWidget {
  const QuizHistoryPage({super.key});

  @override
  State<QuizHistoryPage> createState() => _QuizHistoryPageState();
}

class _QuizHistoryPageState extends State<QuizHistoryPage> {
  late Future<List<QuizAttempt>> _history = QuizService.instance.history();

  String _date(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final s = QuizService.instance.state.value ?? const QuizState();
    final remainingLevels = (s.levels - (s.level - 1)).clamp(0, s.levels);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: c.background,
        appBar: AppBar(
          backgroundColor: c.background,
          elevation: 0,
          iconTheme: IconThemeData(color: c.textPrimary),
          title: Text(context.tr('Mes questions'), style: TextStyle(fontWeight: FontWeight.w900, color: c.textPrimary)),
          bottom: TabBar(
            indicatorColor: c.primary,
            labelColor: c.primary,
            unselectedLabelColor: c.textSecondary,
            labelStyle: const TextStyle(fontWeight: FontWeight.w800),
            tabs: [
              Tab(text: context.tr('À répondre · {n}', {'n': remainingLevels * 5})),
              Tab(text: context.tr('Déjà répondu · {n}', {'n': s.completed * 5})),
            ],
          ),
        ),
        body: TabBarView(children: [_todo(c, s, remainingLevels), _done(c)]),
      ),
    );
  }

  Widget _todo(AppColors c, QuizState s, int remaining) {
    if (s.finishedAll) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const HawkMascot(mood: HawkMood.cheer, size: 130),
            const SizedBox(height: 10),
            Text(context.tr("Tu as tout répondu ! De nouvelles questions arrivent bientôt."),
                textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: c.textPrimary)),
          ]),
        ),
      );
    }
    final firstUnit = quizUnitOf(s.level);
    final units = s.levels ~/ 5;
    final shown = (units - firstUnit).clamp(0, 8);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          context.tr('Il te reste {n} niveaux à jouer, soit {q} questions.', {'n': remaining, 'q': remaining * 5}),
          style: TextStyle(color: c.textSecondary, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        for (var k = 0; k < shown; k++) _unitCard(c, s, firstUnit + k),
        if (units - firstUnit > shown)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              context.tr('… et {n} autres unités à débloquer', {'n': units - firstUnit - shown}),
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textSecondary, fontWeight: FontWeight.w700),
            ),
          ),
      ],
    );
  }

  Widget _unitCard(AppColors c, QuizState s, int u) {
    final theme = quizThemeOfUnit(u);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border, width: 1.5),
      ),
      child: Row(children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: theme.color, borderRadius: BorderRadius.circular(13)),
          child: Icon(theme.icon, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(theme.name(context), style: TextStyle(fontWeight: FontWeight.w900, color: c.textPrimary)),
            Text(context.tr('Unité {n}', {'n': u + 1}), style: TextStyle(fontSize: 12, color: c.textSecondary)),
            const SizedBox(height: 6),
            Row(children: [
              for (var j = 0; j < 5; j++)
                Container(
                  width: 24,
                  height: 8,
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    color: (u * 5 + j + 1) < s.level
                        ? c.accent
                        : (u * 5 + j + 1) == s.level
                            ? theme.color
                            : c.surfaceVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _done(AppColors c) {
    return RefreshIndicator(
      onRefresh: () async {
        setState(() => _history = QuizService.instance.history());
        await _history;
      },
      child: FutureBuilder<List<QuizAttempt>>(
        future: _history,
        builder: (_, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          final list = snap.data ?? const <QuizAttempt>[];
          if (snap.hasError || list.isEmpty) {
            return ListView(children: [
              const SizedBox(height: 60),
              const Center(child: HawkMascot(size: 120)),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: Text(
                  snap.hasError
                      ? context.tr("Impossible de charger l'historique.")
                      : context.tr("Ton historique apparaîtra ici dès ton premier niveau."),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w800, color: c.textSecondary),
                ),
              ),
            ]);
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            itemBuilder: (_, i) => _attemptTile(c, list[i]),
          );
        },
      ),
    );
  }

  Widget _attemptTile(AppColors c, QuizAttempt a) {
    final theme = quizThemeByKey(a.theme);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border, width: 1.5),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: theme.color, borderRadius: BorderRadius.circular(12)),
            child: Icon(theme.icon, color: Colors.white, size: 22),
          ),
          title: Text(context.tr('Niveau {n}', {'n': a.n}), style: TextStyle(fontWeight: FontWeight.w900, color: c.textPrimary)),
          subtitle: Text(
            '${theme.name(context)}  ·  ${_date(a.at)}',
            style: TextStyle(fontSize: 12, color: c.textSecondary),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: (a.passed ? c.primary : c.danger).withOpacity(0.16),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '${a.correct}/5',
              style: TextStyle(fontWeight: FontWeight.w900, color: a.passed ? c.primary : c.danger),
            ),
          ),
          children: [
            for (final d in a.details)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(d['ok'] == true ? Icons.check_circle_rounded : Icons.cancel_rounded,
                      size: 20, color: d['ok'] == true ? c.primary : c.danger),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${d['q']}', style: TextStyle(fontWeight: FontWeight.w700, color: c.textPrimary, height: 1.3)),
                      const SizedBox(height: 2),
                      Text(
                        d['ok'] == true
                            ? '${d['a']}'
                            : context.tr('Ta réponse : {a}. Bonne réponse : {b}', {'a': '${d['c']}', 'b': '${d['a']}'}),
                        style: TextStyle(fontSize: 12.5, color: c.textSecondary),
                      ),
                    ]),
                  ),
                ]),
              ),
          ],
        ),
      ),
    );
  }
}
