import 'package:flutter/material.dart';

import '../../l10n/tr.dart';
import '../../services/contes/contes_service.dart';
import '../../services/etude/etude_service.dart';
import '../../widgets/module_ad_free_card.dart';
import '../contes/contes_home_page.dart';
import '../contes/conte_style.dart';
import '../../services/quiz/quiz_service.dart';
import '../../theme/app_colors.dart';
import '../etude/etude_home_page.dart';
import 'quiz_home_page.dart';
import 'widgets/hawk_mascot.dart';
import 'widgets/quiz_widgets.dart';

/// Module « Quiz & Étude » : le jeu de culture (niveaux, jour, Grand Défi) et les parcours scolaires (classes, diplômes).
class QuizEtudeHubPage extends StatelessWidget {
  const QuizEtudeHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        elevation: 0,
        iconTheme: IconThemeData(color: c.textPrimary),
        title: Text(context.tr('Quiz & Étude'), style: TextStyle(fontWeight: FontWeight.w900, color: c.textPrimary)),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 28), children: [
        const Center(child: HawkMascot(mood: HawkMood.wave, size: 120)),
        const SizedBox(height: 6),
        Center(
          child: Text(
            context.tr('Joue pour gagner des points, étudie pour décrocher tes diplômes.'),
            textAlign: TextAlign.center,
            style: TextStyle(color: c.textSecondary, fontWeight: FontWeight.w700, fontSize: 14, height: 1.35),
          ),
        ),
        const SizedBox(height: 18),
        const ModuleAdFreeCard(margin: EdgeInsets.only(bottom: 14)),
        ValueListenableBuilder<QuizState?>(
          valueListenable: QuizService.instance.state,
          builder: (context, q, _) => _bigCard(
            context,
            c,
            color: c.primary,
            icon: Icons.quiz_rounded,
            title: context.tr('Quiz'),
            text: context.tr('Questions de culture, quiz du jour, Grand Défi, classement et boutique de points.'),
            pills: q == null
                ? const []
                : [
                    QuizPill(icon: Icons.flag_rounded, label: context.tr('Niveau {n}', {'n': '${q.level}'}), color: c.primary),
                    if (q.streak > 0) QuizPill(icon: Icons.local_fire_department_rounded, label: context.tr('{n} jours', {'n': '${q.streak}'}), color: c.warning),
                  ],
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QuizHomePage())),
          ),
        ),
        const SizedBox(height: 14),
        ValueListenableBuilder<EtudeState?>(
          valueListenable: EtudeService.instance.state,
          builder: (context, e, _) => _bigCard(
            context,
            c,
            color: c.info,
            icon: Icons.school_rounded,
            title: context.tr('Étude'),
            text: context.tr("Collège, lycée, université, entretien d'embauche : valide tes classes et décroche ton diplôme."),
            pills: e == null
                ? const []
                : [
                    QuizPill(icon: Icons.bolt_rounded, label: '${e.xp} XP', color: c.accent),
                    if (e.diplomas.isNotEmpty) QuizPill(icon: Icons.workspace_premium_rounded, label: context.tr('{n} diplôme(s)', {'n': '${e.diplomas.length}'}), color: const Color(0xFFD4A017)),
                  ],
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EtudeHomePage())),
          ),
        ),
        const SizedBox(height: 14),
        ValueListenableBuilder<ContesState?>(
          valueListenable: ContesService.instance.state,
          builder: (context, k, _) => _bigCard(
            context,
            c,
            color: ConteStyle.gold,
            icon: Icons.auto_stories_rounded,
            title: context.tr('La Case aux Contes'),
            text: context.tr('Contes et récits africains : légendes, ruses, mystères. Lis à la veillée, un conte à la fois.'),
            pills: k == null || k.reads.isEmpty ? const [] : [QuizPill(icon: Icons.menu_book_rounded, label: context.tr('{n} lus', {'n': '${k.reads.length}'}), color: ConteStyle.gold)],
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ContesHomePage())),
          ),
        ),
      ]),
    );
  }

  Widget _bigCard(BuildContext context, AppColors c, {required Color color, required IconData icon, required String title, required String text, required List<Widget> pills, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [color.withOpacity(0.22), c.surface], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: color, width: 1.8),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16)),
              child: Icon(icon, color: Colors.white, size: 30),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w900, fontSize: 22))),
            Icon(Icons.chevron_right_rounded, color: color, size: 32),
          ]),
          const SizedBox(height: 10),
          Text(text, style: TextStyle(color: c.textSecondary, fontSize: 13.5, height: 1.4)),
          if (pills.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 6, children: pills),
          ],
        ]),
      ),
    );
  }
}
