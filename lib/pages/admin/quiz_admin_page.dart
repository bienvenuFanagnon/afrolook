import 'package:flutter/material.dart';

import '../../services/quiz/quiz_service.dart';
import '../../theme/app_colors.dart';
import '../quiz/widgets/quiz_widgets.dart';

String _dur(num sec) {
  final s = sec.round();
  if (s < 60) return '$s s';
  final m = s ~/ 60;
  if (m < 60) return '$m min ${(s % 60).toString().padLeft(2, '0')}';
  return '${m ~/ 60} h ${(m % 60).toString().padLeft(2, '0')}';
}

int _n(dynamic v) => v is num ? v.toInt() : 0;

String _dayLabel(String d) => d.length == 8 ? '${d.substring(6)}/${d.substring(4, 6)}' : d;

/// Admin du Quiz : qui joue aujourd'hui, combien de temps, sur quels jours, et toutes les questions
/// (avec leur taux de réussite). Les données viennent de la fonction `quizAdmin` (réservée aux admins).
class QuizAdminPage extends StatefulWidget {
  const QuizAdminPage({super.key});

  @override
  State<QuizAdminPage> createState() => _QuizAdminPageState();
}

class _QuizAdminPageState extends State<QuizAdminPage> {
  Map<String, dynamic>? _stats;
  String? _error;
  bool _loading = true;
  int _days = 7;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final m = await QuizService.instance.admin({'action': 'stats', 'days': _days});
      if (mounted) setState(() => _stats = m);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: c.background,
        appBar: AppBar(
          backgroundColor: c.background,
          elevation: 0,
          iconTheme: IconThemeData(color: c.textPrimary),
          title: Text('Quiz · administration', style: TextStyle(fontWeight: FontWeight.w900, color: c.textPrimary)),
          actions: [IconButton(onPressed: _load, icon: Icon(Icons.refresh_rounded, color: c.textPrimary))],
          bottom: TabBar(
            indicatorColor: c.primary,
            labelColor: c.primary,
            unselectedLabelColor: c.textSecondary,
            labelStyle: const TextStyle(fontWeight: FontWeight.w800),
            isScrollable: true,
            tabs: const [Tab(text: "Aujourd'hui"), Tab(text: 'Jours'), Tab(text: 'Questions'), Tab(text: 'Signalements')],
          ),
        ),
        body: _loading && _stats == null
            ? const Center(child: CircularProgressIndicator())
            : _error != null && _stats == null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: c.danger)),
                        TextButton(onPressed: _load, child: const Text('Réessayer')),
                      ]),
                    ),
                  )
                : TabBarView(children: [_today(c), _daysTab(c), const _QuestionsTab(), const _ReportsTab()]),
      ),
    );
  }

  Widget _card(AppColors c, {required Widget child}) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: c.border, width: 1.2)),
        child: child,
      );

  Widget _kpi(AppColors c, String value, String label, {Color? color}) => Expanded(
        child: Column(children: [
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color ?? c.textPrimary)),
          const SizedBox(height: 2),
          Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: c.textSecondary, fontWeight: FontWeight.w700)),
        ]),
      );

  Widget _bar(AppColors c, String label, int value, int max, {Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          SizedBox(width: 74, child: Text(label, style: TextStyle(fontSize: 12, color: c.textSecondary, fontWeight: FontWeight.w700))),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: LinearProgressIndicator(
                value: max == 0 ? 0 : value / max,
                minHeight: 10,
                backgroundColor: c.surfaceVariant,
                valueColor: AlwaysStoppedAnimation(color ?? c.primary),
              ),
            ),
          ),
          SizedBox(width: 38, child: Text('$value', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w800, color: c.textPrimary, fontSize: 12))),
        ]),
      );

  Widget _today(AppColors c) {
    final s = _stats!;
    final ov = Map<String, dynamic>.from(s['overview'] as Map);
    final days = (s['days'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final today = days.isNotEmpty ? days.last : <String, dynamic>{};
    final ret = Map<String, dynamic>.from(s['retention'] as Map);
    final top = (s['top'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final total = _n(ov['total']);
    final played = _n(ov['playedToday']);
    final buckets = (ov['levelBuckets'] as List).map(_n).toList();
    const bLabels = ['Niv. 1–5', 'Niv. 6–20', 'Niv. 21–50', 'Niv. 51–100', 'Niv. 101–200', 'Terminé'];
    final bMax = buckets.fold<int>(1, (a, b) => b > a ? b : a);
    final chal = (ov['chalBest'] as List).map(_n).toList();
    final cMax = chal.skip(1).fold<int>(1, (a, b) => b > a ? b : a);
    final yest = _n(ret['yesterday']);
    final back = _n(ret['back']);
    final cfg = Map<String, dynamic>.from(s['config'] as Map);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        _card(c,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text("Aujourd'hui", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: c.textPrimary)),
              const SizedBox(height: 10),
              Row(children: [
                _kpi(c, '$played', 'ont joué', color: c.primary),
                _kpi(c, total == 0 ? '–' : '${(played * 100 / total).round()} %', 'des $total inscrits au quiz'),
                _kpi(c, _dur(_n(today['avgSec'])), 'temps moyen'),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                _kpi(c, '${_n(ov['dailyDone'])}', 'quiz du jour finis'),
                _kpi(c, '${_n(today['levels'])}', 'niveaux terminés'),
                _kpi(c, '${_n(ov['chalToday'])}', 'parties du Défi (${_n(ov['chalPlayers'])} joueurs)'),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                _kpi(c, _dur(_n(today['sec'])), 'temps total passé'),
                _kpi(c, '${_n(ov['ptsToday'])}', 'points donnés'),
                _kpi(c, yest == 0 ? '–' : '${(back * 100 / yest).round()} %', 'd\'hier revenus ($back/$yest)'),
              ]),
            ])),
        _card(c,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Qui passe le plus de temps aujourd\'hui', style: TextStyle(fontWeight: FontWeight.w900, color: c.textPrimary)),
              const SizedBox(height: 8),
              if (top.isEmpty)
                Text('Aucune mesure de temps pour le moment (elle démarre avec la prochaine mise à jour de l\'application).', style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
              for (final u in top)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    Text(quizFlag('${u['country'] ?? ''}'), style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('${u['name']}'.isEmpty ? '${u['uid']}'.substring(0, 8) : '${u['name']}',
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, color: c.textPrimary)),
                    ),
                    Text(_dur(_n(u['sec'])), style: TextStyle(fontWeight: FontWeight.w900, color: c.primary)),
                  ]),
                ),
            ])),
        _card(c,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Où en sont les joueurs (parcours)', style: TextStyle(fontWeight: FontWeight.w900, color: c.textPrimary)),
              const SizedBox(height: 8),
              for (var i = 0; i < buckets.length; i++) _bar(c, bLabels[i], buckets[i], bMax),
              const SizedBox(height: 6),
              Text('${_n(ov['streak3'])} joueurs ont une série de 3 jours ou plus.', style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
            ])),
        _card(c,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Grand Défi : meilleur score des joueurs', style: TextStyle(fontWeight: FontWeight.w900, color: c.textPrimary)),
              const SizedBox(height: 8),
              for (var i = 1; i < chal.length; i++) if (chal[i] > 0) _bar(c, '$i/15', chal[i], cMax, color: c.accent),
              if (chal.skip(1).every((v) => v == 0)) Text('Personne n\'a encore joué le Défi.', style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
              const SizedBox(height: 6),
              Text('${_n(ov['chalWins'])} victoire(s) à 15/15 au total.', style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
            ])),
        _card(c,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Réglages actuels', style: TextStyle(fontWeight: FontWeight.w900, color: c.textPrimary)),
              const SizedBox(height: 6),
              Text(
                cfg.isEmpty ? 'Valeurs par défaut (rien d\'enregistré dans AppConfig/quiz).' : cfg.entries.where((e) => e.key != 'shop').map((e) => '${e.key} : ${e.value}').join('\n'),
                style: TextStyle(color: c.textSecondary, fontSize: 12.5, height: 1.4),
              ),
              const SizedBox(height: 6),
              Text('Pour les changer : node tools/quiz/set_config.js \'{"interstitialEveryLevels":2}\'', style: TextStyle(color: c.textSecondary, fontSize: 11.5)),
            ])),
        if (s['truncated'] == true)
          Text('Plus de 10 000 joueurs : les totaux sont partiels.', style: TextStyle(color: c.warning, fontSize: 12)),
      ]),
    );
  }

  Widget _daysTab(AppColors c) {
    final days = (_stats!['days'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final maxPlayers = days.fold<int>(1, (a, d) => _n(d['players']) > a ? _n(d['players']) : a);
    final rows = days.reversed.toList();
    return ListView(padding: const EdgeInsets.all(16), children: [
      Row(children: [
        for (final d in const [7, 14, 30])
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text('$d jours'),
              selected: _days == d,
              onSelected: (_) {
                _days = d;
                _load();
              },
            ),
          ),
      ]),
      const SizedBox(height: 12),
      _card(c,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Joueurs par jour (avec temps mesuré)', style: TextStyle(fontWeight: FontWeight.w900, color: c.textPrimary)),
            const SizedBox(height: 8),
            for (final d in days) _bar(c, _dayLabel('${d['day']}'), _n(d['players']), maxPlayers),
          ])),
      for (final d in rows)
        _card(c,
            child: Row(children: [
              SizedBox(width: 52, child: Text(_dayLabel('${d['day']}'), style: TextStyle(fontWeight: FontWeight.w900, color: c.textPrimary))),
              _kpi(c, '${_n(d['players'])}', 'joueurs'),
              _kpi(c, _dur(_n(d['avgSec'])), 'moyen'),
              _kpi(c, _dur(_n(d['sec'])), 'total'),
              _kpi(c, '${_n(d['levels'])}', 'niveaux'),
            ])),
      Text('Les niveaux terminés comptent le dernier essai de chaque niveau. Le temps vient de l\'application (une mesure par minute).',
          style: TextStyle(color: c.textSecondary, fontSize: 11.5)),
    ]);
  }
}

/// Parcourir les 200 niveaux : question, bonne réponse (en vert), explication et taux de réussite des joueurs.
class _QuestionsTab extends StatefulWidget {
  const _QuestionsTab();

  @override
  State<_QuestionsTab> createState() => _QuestionsTabState();
}

class _QuestionsTabState extends State<_QuestionsTab> {
  int _tier = 1;
  int _theme = 0;
  Map<String, dynamic>? _data;
  bool _loading = false;
  String? _error;

  int get _unit => (_tier - 1) * 8 + _theme + 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _data = null;
    });
    try {
      final m = await QuizService.instance.admin({'action': 'unit', 'u': _unit});
      if (mounted) setState(() => _data = m);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final levels = _data == null ? <Map<String, dynamic>>[] : (_data!['levels'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('Difficulté', style: TextStyle(fontWeight: FontWeight.w800, color: c.textSecondary, fontSize: 12)),
      const SizedBox(height: 4),
      Wrap(spacing: 8, children: [
        for (var t = 1; t <= 5; t++)
          ChoiceChip(
            label: Text('$t'),
            selected: _tier == t,
            onSelected: (_) {
              _tier = t;
              _load();
            },
          ),
      ]),
      const SizedBox(height: 8),
      Text('Thème', style: TextStyle(fontWeight: FontWeight.w800, color: c.textSecondary, fontSize: 12)),
      const SizedBox(height: 4),
      Wrap(spacing: 8, runSpacing: 4, children: [
        for (var i = 0; i < kQuizThemes.length; i++)
          ChoiceChip(
            label: Text(kQuizThemes[i].label),
            selected: _theme == i,
            onSelected: (_) {
              _theme = i;
              _load();
            },
          ),
      ]),
      const SizedBox(height: 12),
      if (_loading) const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
      if (_error != null) Text(_error!, style: TextStyle(color: c.danger)),
      for (final lv in levels) ...[
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 6),
          child: Text('Niveau ${lv['n']} · ${lv['theme']} · difficulté ${lv['tier']}', style: TextStyle(fontWeight: FontWeight.w900, color: c.textPrimary)),
        ),
        for (final q in (lv['questions'] as List).map((e) => Map<String, dynamic>.from(e as Map)))
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.border, width: 1.2)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${q['q']}', style: TextStyle(fontWeight: FontWeight.w800, color: c.textPrimary, height: 1.3)),
              const SizedBox(height: 6),
              for (var k = 0; k < (q['o'] as List).length; k++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1.5),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(k == _n(q['a']) ? Icons.check_circle_rounded : Icons.circle_outlined, size: 16, color: k == _n(q['a']) ? c.primary : c.textSecondary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text('${(q['o'] as List)[k]}',
                          style: TextStyle(color: k == _n(q['a']) ? c.primary : c.textPrimary, fontWeight: k == _n(q['a']) ? FontWeight.w800 : FontWeight.w500, fontSize: 13)),
                    ),
                  ]),
                ),
              const SizedBox(height: 4),
              Text('${q['e']}', style: TextStyle(color: c.textSecondary, fontSize: 12, height: 1.3)),
              const SizedBox(height: 4),
              Text(
                _n(q['total']) == 0 ? 'Pas encore répondue' : 'Réussite : ${(_n(q['ok']) * 100 / _n(q['total'])).round()} % (${_n(q['total'])} réponses)',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: _n(q['total']) == 0 ? c.textSecondary : (_n(q['ok']) * 100 / _n(q['total']) < 30 ? c.danger : c.info)),
              ),
            ]),
          ),
      ],
    ]);
  }
}

/// Signalements des joueurs : questions dont la réponse validée est contestée (les plus signalées d'abord).
class _ReportsTab extends StatefulWidget {
  const _ReportsTab();

  @override
  State<_ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<_ReportsTab> {
  List<Map<String, dynamic>>? _reports;
  String? _error;

  static const _reasons = {'wrong': 'Réponse fausse', 'ambiguous': 'Plusieurs réponses possibles', 'typo': 'Faute / texte', 'other': 'Autre'};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final m = await QuizService.instance.admin({'action': 'reports'});
      if (mounted) setState(() => _reports = (m['reports'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList());
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _resolve(String qHash, String status) async {
    try {
      await QuizService.instance.admin({'action': 'resolve', 'qHash': qHash, 'status': status});
      if (mounted) setState(() => _reports?.removeWhere((r) => r['qHash'] == qHash));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    if (_error != null) return Center(child: Text(_error!, style: TextStyle(color: c.danger)));
    final list = _reports;
    if (list == null) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        if (list.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Text('Aucun signalement en attente.', textAlign: TextAlign.center, style: TextStyle(color: c.textSecondary, fontWeight: FontWeight.w700)),
          ),
        for (final r in list)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: c.border, width: 1.2)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: _n(r['count']) >= 3 ? c.danger : c.warning, borderRadius: BorderRadius.circular(999)),
                  child: Text('${_n(r['count'])} signalement${_n(r['count']) > 1 ? 's' : ''}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text((r['reasons'] as Map).entries.map((e) => '${_reasons[e.key] ?? e.key} (${e.value})').join(' · '),
                      style: TextStyle(color: c.textSecondary, fontSize: 12)),
                ),
              ]),
              const SizedBox(height: 8),
              Text('${r['q']}', style: TextStyle(fontWeight: FontWeight.w800, color: c.textPrimary, height: 1.3)),
              const SizedBox(height: 6),
              for (final o in (r['options'] as List))
                Text('${o == r['shown'] ? '✔ ' : '• '}$o',
                    style: TextStyle(color: o == r['shown'] ? c.primary : c.textPrimary, fontWeight: o == r['shown'] ? FontWeight.w900 : FontWeight.w500, fontSize: 13)),
              if ((r['comments'] as List).isNotEmpty) ...[
                const SizedBox(height: 8),
                for (final cm in (r['comments'] as List))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text('« $cm »', style: TextStyle(color: c.textSecondary, fontStyle: FontStyle.italic, fontSize: 12.5)),
                  ),
              ],
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: OutlinedButton(onPressed: () => _resolve('${r['qHash']}', 'ignored'), child: const Text('Ignorer'))),
                const SizedBox(width: 10),
                Expanded(child: FilledButton(onPressed: () => _resolve('${r['qHash']}', 'done'), child: const Text('Traité'))),
              ]),
            ]),
          ),
        Text('Pour corriger une question : modifier tools/quiz/questions/*.json puis relancer build_levels.js et upload_levels.js.',
            style: TextStyle(color: c.textSecondary, fontSize: 11.5)),
      ]),
    );
  }
}
