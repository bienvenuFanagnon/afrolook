import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/tr.dart';
import '../../providers/authProvider.dart';
import '../../services/quiz/quiz_service.dart';
import '../../theme/app_colors.dart';
import 'widgets/hawk_mascot.dart';
import 'widgets/quiz_loading.dart';
import 'widgets/quiz_widgets.dart';

/// Classement de la semaine : joueurs et pays. Les points ne valent pas d'argent : seulement la fierté.
class QuizLeaderboardPage extends StatefulWidget {
  const QuizLeaderboardPage({super.key});

  @override
  State<QuizLeaderboardPage> createState() => _QuizLeaderboardPageState();
}

class _QuizLeaderboardPageState extends State<QuizLeaderboardPage> {
  late Future<List<QuizWeeklyEntry>> _top = QuizService.instance.weeklyTop();
  late Future<List<QuizCountryRow>> _countries = QuizService.instance.countryBoard();
  late Future<({int rank, int points, String weekId})> _me = QuizService.instance.myRank();

  void _reload() {
    setState(() {
      _top = QuizService.instance.weeklyTop();
      _countries = QuizService.instance.countryBoard();
      _me = QuizService.instance.myRank();
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: c.background,
        appBar: AppBar(
          backgroundColor: c.background,
          elevation: 0,
          iconTheme: IconThemeData(color: c.textPrimary),
          title: Text(context.tr('Classement'), style: TextStyle(fontWeight: FontWeight.w900, color: c.textPrimary)),
          bottom: TabBar(
            indicatorColor: c.primary,
            labelColor: c.primary,
            unselectedLabelColor: c.textSecondary,
            labelStyle: const TextStyle(fontWeight: FontWeight.w800),
            tabs: [Tab(text: context.tr('Joueurs')), Tab(text: context.tr('Pays'))],
          ),
        ),
        body: TabBarView(children: [_players(c), _countriesTab(c)]),
      ),
    );
  }

  Widget _frameAvatar(AppColors c, QuizWeeklyEntry e, double size) {
    Color? ring;
    double w = 3;
    if (e.frame == 'frame_gold') {
      ring = c.accent;
      w = 4;
    } else if (e.frame == 'frame_green') {
      ring = c.primary;
    }
    final initial = e.name.isEmpty ? '?' : e.name.characters.first.toUpperCase();
    final avatar = CircleAvatar(
      radius: size / 2,
      backgroundColor: c.surfaceVariant,
      backgroundImage: e.photo.isNotEmpty ? NetworkImage(e.photo) : null,
      child: e.photo.isEmpty ? Text(initial, style: TextStyle(color: c.textSecondary, fontWeight: FontWeight.w900)) : null,
    );
    if (ring == null) return avatar;
    return Container(
      padding: EdgeInsets.all(w - 1),
      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: ring, width: w)),
      child: avatar,
    );
  }

  String? _titleText(BuildContext context, String t) {
    switch (t) {
      case 'title_lion':
        return context.tr('Lion du savoir');
      case 'title_scholar':
        return context.tr('Érudit');
    }
    return null;
  }

  Widget _players(AppColors c) {
    final me = QuizService.instance.uid;
    return RefreshIndicator(
      onRefresh: () async {
        _reload();
        await _top;
      },
      child: FutureBuilder<List<QuizWeeklyEntry>>(
        future: _top,
        builder: (_, snap) {
          if (snap.connectionState != ConnectionState.done) return const QuizLoading(kind: QuizLoadingKind.ranking);
          final list = snap.data ?? const <QuizWeeklyEntry>[];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              FutureBuilder<({int rank, int points, String weekId})>(
                future: _me,
                builder: (_, ms) {
                  final r = ms.data;
                  final rank = r?.rank ?? 0;
                  return Container(
                    padding: const EdgeInsets.all(14),
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [c.accent.withOpacity(0.25), c.surface]),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: c.accent, width: 1.5),
                    ),
                    child: Row(children: [
                      const HawkMascot(size: 64),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(
                            rank > 0 ? context.tr('Ta place cette semaine : {n}', {'n': rank}) : context.tr("Tu n'as pas encore de points cette semaine."),
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: c.textPrimary),
                          ),
                          Text(
                            context.tr('{n} points gagnés cette semaine', {'n': r?.points ?? 0}),
                            style: TextStyle(color: c.textSecondary, fontSize: 12.5),
                          ),
                          Text(context.tr('Le classement repart à zéro chaque lundi.'), style: TextStyle(color: c.textSecondary, fontSize: 11.5)),
                        ]),
                      ),
                    ]),
                  );
                },
              ),
              if (snap.hasError)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(context.tr('Impossible de charger le classement.'), textAlign: TextAlign.center, style: TextStyle(color: c.textSecondary)),
                )
              else if (list.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(context.tr('Sois le premier de la semaine !'), textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.w800, color: c.textSecondary)),
                ),
              for (var i = 0; i < list.length; i++) _playerRow(c, list[i], i + 1, list[i].uid == me),
            ],
          );
        },
      ),
    );
  }

  Widget _playerRow(AppColors c, QuizWeeklyEntry e, int rank, bool mine) {
    final medal = rank == 1 ? const Color(0xFFFFD43B) : rank == 2 ? const Color(0xFFC0C6D0) : rank == 3 ? const Color(0xFFD9904F) : null;
    final title = _titleText(context, e.title);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: mine ? c.primary.withOpacity(0.12) : c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: mine ? c.primary : c.border, width: 1.5),
      ),
      child: Row(children: [
        SizedBox(
          width: 30,
          child: medal != null
              ? Icon(Icons.workspace_premium_rounded, color: medal, size: 26)
              : Text('$rank', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w900, color: c.textSecondary)),
        ),
        const SizedBox(width: 8),
        _frameAvatar(c, e, 40),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              '${quizFlag(e.country)}  ${e.name.isEmpty ? context.tr('Joueur') : e.name}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.w800, color: c.textPrimary),
            ),
            if (title != null) Text(title, style: TextStyle(fontSize: 11.5, color: c.supportAccent, fontWeight: FontWeight.w800)),
          ]),
        ),
        Text('${e.points}', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: c.supportAccent)),
        const SizedBox(width: 2),
        Icon(Icons.star_rounded, size: 16, color: c.accent),
      ]),
    );
  }

  Widget _countriesTab(AppColors c) {
    final myCode = (context.read<UserAuthProvider>().loginUserData.countryData?['countryCode'] ?? '').toUpperCase();
    return RefreshIndicator(
      onRefresh: () async {
        _reload();
        await _countries;
      },
      child: FutureBuilder<List<QuizCountryRow>>(
        future: _countries,
        builder: (_, snap) {
          if (snap.connectionState != ConnectionState.done) return const QuizLoading(kind: QuizLoadingKind.ranking);
          final list = snap.data ?? const <QuizCountryRow>[];
          if (snap.hasError || list.isEmpty) {
            return ListView(children: [
              const SizedBox(height: 50),
              const Center(child: HawkMascot(size: 120)),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Text(
                  snap.hasError ? context.tr('Impossible de charger le classement.') : context.tr('Le classement des pays apparaît dès que des joueurs marquent des points.'),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w800, color: c.textSecondary),
                ),
              ),
            ]);
          }
          final max = list.first.points == 0 ? 1 : list.first.points;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                context.tr('Chaque point gagné rapporte aussi à ton pays. Invite tes amis !'),
                style: TextStyle(color: c.textSecondary, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < list.length; i++)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: list[i].code.toUpperCase() == myCode ? c.primary.withOpacity(0.12) : c.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: list[i].code.toUpperCase() == myCode ? c.primary : c.border, width: 1.5),
                  ),
                  child: Column(children: [
                    Row(children: [
                      SizedBox(width: 26, child: Text('${i + 1}', style: TextStyle(fontWeight: FontWeight.w900, color: c.textSecondary))),
                      Text(quizFlag(list[i].code), style: const TextStyle(fontSize: 24)),
                      const SizedBox(width: 10),
                      Expanded(child: Text(list[i].name, style: TextStyle(fontWeight: FontWeight.w800, color: c.textPrimary))),
                      Text('${list[i].points}', style: TextStyle(fontWeight: FontWeight.w900, color: c.supportAccent)),
                      const SizedBox(width: 2),
                      Icon(Icons.star_rounded, size: 16, color: c.accent),
                    ]),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: list[i].points / max,
                        minHeight: 8,
                        backgroundColor: c.surfaceVariant,
                        valueColor: AlwaysStoppedAnimation(i == 0 ? c.accent : c.primary),
                      ),
                    ),
                  ]),
                ),
            ],
          );
        },
      ),
    );
  }
}
