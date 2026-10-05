import 'package:flutter/material.dart';

import '../../l10n/tr.dart';
import '../../services/etude/etude_service.dart';
import '../../theme/app_colors.dart';
import '../quiz/widgets/hawk_mascot.dart';
import '../quiz/widgets/quiz_loading.dart';
import '../quiz/widgets/quiz_widgets.dart';
import 'etude_class_page.dart';
import 'etude_diploma_page.dart';
import 'etude_flow.dart';

/// Afrolook Étude : le parcours de l'école au diplôme, comme un jeu.
/// Collège (BEPC) → lycée (BAC) → université (licence), plus des attestations par domaine.
class EtudeHomePage extends StatefulWidget {
  const EtudeHomePage({super.key});

  @override
  State<EtudeHomePage> createState() => _EtudeHomePageState();
}

class _EtudeHomePageState extends State<EtudeHomePage> {
  List<EtudeTrack>? _tracks;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final r = await Future.wait([EtudeService.instance.catalog(force: true), EtudeService.instance.refresh()]);
      if (mounted) setState(() => _tracks = r[0] as List<EtudeTrack>);
    } on EtudeException catch (e) {
      if (mounted) setState(() => _error = e.code);
    } catch (_) {
      if (mounted) setState(() => _error = 'NETWORK');
    }
  }

  Future<void> _start(EtudeTrack t, EtudeState st) async {
    final prev = t.after;
    final needDeclare = prev.isNotEmpty && !_hasDiploma(st, _tracks!, prev);
    final res = await showModalBottomSheet<Map<String, Object?>>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _StartSheet(track: t, needDeclare: needDeclare, tracks: _tracks!),
    );
    if (res == null || !mounted) return;
    try {
      await EtudeService.instance.startTrack(t.id, entry: res['entry'] as String?, declared: res['declared'] == true);
    } on EtudeException catch (e) {
      if (mounted) quizToast(context, e.code.contains('NEED_PREVIOUS') ? context.tr('Termine d\'abord le parcours précédent.') : context.tr('Une erreur est survenue, réessaie.'), error: true);
    }
  }

  bool _hasDiploma(EtudeState st, List<EtudeTrack> all, List<String> trackIds) {
    for (final id in trackIds) {
      final t = all.where((x) => x.id == id).firstOrNull;
      final eid = t?.exam?['id'];
      if (eid != null && st.diplomas.any((d) => d['track'] == id && d['kind'] == 'exam')) return true;
    }
    return false;
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
        title: Text(context.tr('Étude'), style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w900)),
        actions: [IconButton(onPressed: _load, icon: Icon(Icons.refresh_rounded, color: c.textPrimary))],
      ),
      body: _error != null
          ? Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const HawkMascot(mood: HawkMood.sad, size: 120),
                const SizedBox(height: 10),
                Text(_error!.contains('ETUDE_OFF') ? context.tr('Le module Étude est en pause pour le moment.') : context.tr('Connexion impossible. Vérifie ta connexion.'), style: TextStyle(color: c.textSecondary)),
                TextButton(onPressed: _load, child: Text(context.tr('Réessayer'))),
              ]),
            )
          : _tracks == null
              ? const QuizLoading(kind: QuizLoadingKind.home)
              : ValueListenableBuilder<EtudeState?>(
                  valueListenable: EtudeService.instance.state,
                  builder: (context, s, _) => _content(c, s ?? const EtudeState()),
                ),
    );
  }

  Widget _content(AppColors c, EtudeState st) {
    final tracks = _tracks!;
    final cycles = tracks.where((t) => t.isCycle).toList();
    final certs = etudeCerts(tracks);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
        _header(c, st),
        const SizedBox(height: 18),
        _sectionTitle(c, context.tr('Mon parcours'), context.tr('De l\'école au diplôme')),
        for (final t in cycles) _trackCard(c, st, t),
        const SizedBox(height: 10),
        _sectionTitle(c, context.tr('Attestations'), context.tr('Un domaine, une attestation')),
        for (final t in certs) _certCard(c, st, t),
        if (st.diplomas.isNotEmpty) ...[
          const SizedBox(height: 10),
          _sectionTitle(c, context.tr('Mes diplômes'), null),
          for (final d in st.diplomas) Padding(padding: const EdgeInsets.only(bottom: 8), child: EtudeDiplomaTile(diploma: d)),
        ],
        const SizedBox(height: 14),
        Text(
          context.tr('Les diplômes et attestations Afrolook Étude sont des documents de progression, sans valeur de diplôme officiel.'),
          textAlign: TextAlign.center,
          style: TextStyle(color: c.textSecondary, fontSize: 11.5, height: 1.4),
        ),
      ]),
    );
  }

  Widget _sectionTitle(AppColors c, String title, String? sub) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w900, fontSize: 19)),
          if (sub != null) Text(sub, style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
        ]),
      );

  Widget _header(AppColors c, EtudeState st) {
    final into = st.xpInLevel.clamp(0, st.xpForLevel);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [c.primary.withOpacity(0.18), c.accent.withOpacity(0.16)]),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.primary.withOpacity(0.4)),
      ),
      child: Row(children: [
        const HawkMascot(mood: HawkMood.wave, size: 86, accessory: 'acc_glasses'),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(context.tr('Niveau {n}', {'n': '${st.level}'}), style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w900, fontSize: 18)),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(value: st.xpForLevel == 0 ? 0 : into / st.xpForLevel, minHeight: 9, backgroundColor: c.surfaceVariant, valueColor: AlwaysStoppedAnimation(c.accent)),
            ),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 6, children: [
              QuizPill(icon: Icons.bolt_rounded, label: '${st.xp} XP', color: c.accent),
              QuizPill(icon: Icons.local_fire_department_rounded, label: context.tr('{n} jours', {'n': '${st.streak}'}), color: c.warning),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _trackCard(AppColors c, EtudeState st, EtudeTrack t) {
    final status = st.tracks[t.id];
    final started = status != null;
    final diploma = status?.diploma;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: diploma != null ? const Color(0xFFD4A017) : c.border, width: diploma != null ? 2 : 1.4)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: c.primary.withOpacity(0.14), borderRadius: BorderRadius.circular(13)),
            child: Icon(t.id.startsWith('univ') ? Icons.account_balance_rounded : (t.id.startsWith('lycee') ? Icons.school_rounded : Icons.backpack_rounded), color: c.primary),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(t.title, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w900, fontSize: 17))),
          if (diploma != null) const Icon(Icons.workspace_premium_rounded, color: Color(0xFFD4A017)),
        ]),
        const SizedBox(height: 12),
        if (!started)
          QuizChunkyButton(label: context.tr('Commencer ce parcours'), icon: Icons.flag_rounded, color: c.primary, textColor: c.onPrimary, onPressed: () => _start(t, st))
        else ...[
          for (final cls in t.classes) _classRow(c, st, t, cls, status.classes[cls.id]),
          if (t.exam != null) _examRow(c, st, t, status),
        ],
      ]),
    );
  }

  Widget _classRow(AppColors c, EtudeState st, EtudeTrack t, EtudeClass cls, EtudeClassStatus? cs) {
    final s = cs?.status ?? 'soon';
    final (IconData icon, Color col, String label) = switch (s) {
      'validated' => (Icons.verified_rounded, c.primary, context.tr('Validée')),
      'open' => (Icons.play_circle_fill_rounded, c.info, context.tr('{a}/{b} chapitres', {'a': '${cs!.done}', 'b': '${cs.total}'})),
      'locked' => (Icons.lock_rounded, c.textSecondary, context.tr('Valide la classe précédente')),
      'skipped' => (Icons.fast_forward_rounded, c.textSecondary, context.tr('Passée')),
      _ => (Icons.hourglass_empty_rounded, c.textSecondary, context.tr('Bientôt')),
    };
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        if (s == 'open' || s == 'validated') {
          Navigator.push(context, MaterialPageRoute(builder: (_) => EtudeClassPage(track: t, cls: cls)));
        } else if (s == 'locked') {
          quizToast(context, context.tr('Valide d\'abord la classe précédente.'));
        } else if (s == 'soon') {
          quizToast(context, context.tr('Cette classe arrive bientôt.'));
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(children: [
          Icon(icon, color: col, size: 26),
          const SizedBox(width: 10),
          Expanded(child: Text(cls.title, style: TextStyle(color: s == 'skipped' || s == 'soon' ? c.textSecondary : c.textPrimary, fontWeight: FontWeight.w800, fontSize: 15))),
          Text(label, style: TextStyle(color: col, fontWeight: FontWeight.w700, fontSize: 12)),
          if (s == 'open' || s == 'validated') Icon(Icons.chevron_right_rounded, color: c.textSecondary),
        ]),
      ),
    );
  }

  Widget _examRow(AppColors c, EtudeState st, EtudeTrack t, EtudeTrackStatus status) {
    final ex = t.exam!;
    final got = status.diploma;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: c.accent.withOpacity(0.12), borderRadius: BorderRadius.circular(14), border: Border.all(color: c.accent.withOpacity(0.5))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.emoji_events_rounded, color: c.supportAccent),
          const SizedBox(width: 8),
          Expanded(child: Text('${ex['title']}', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w900))),
        ]),
        const SizedBox(height: 4),
        Text(
          got != null
              ? context.tr('Obtenu avec {p} %', {'p': '${got['pct']}'})
              : status.examReady
                  ? context.tr('{n} questions, il faut 50 % pour décrocher le diplôme', {'n': '${ex['count'] ?? 40}'})
                  : context.tr('Valide toutes les classes du parcours pour passer l\'examen'),
          style: TextStyle(color: c.textSecondary, fontSize: 12.5),
        ),
        if (got != null) ...[
          const SizedBox(height: 8),
          QuizChunkyButton(label: context.tr('Voir mon diplôme'), icon: Icons.workspace_premium_rounded, color: c.accent, textColor: c.onAccent, onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EtudeDiplomaPage(diploma: got)))),
        ] else if (status.examReady) ...[
          const SizedBox(height: 8),
          QuizChunkyButton(
            label: context.tr('Passer l\'examen'),
            icon: Icons.edit_note_rounded,
            color: c.warning,
            textColor: Colors.white,
            onPressed: () async {
              final ok = await etudeLaunch(context, kind: 'exam', id: t.id, item: 'exam:${t.id}', title: '${ex['title']}');
              if (ok) await EtudeService.instance.refresh().catchError((Object _) => const EtudeState());
            },
          ),
        ],
      ]),
    );
  }

  Widget _certCard(AppColors c, EtudeState st, EtudeTrack t) {
    final cert = t.cert!;
    final info = st.certs[cert['id']] as Map? ?? const {};
    final done = (info['done'] as num?)?.toInt() ?? 0;
    final total = (info['total'] as num?)?.toInt() ?? 0;
    final got = info['diploma'] is Map ? Map<String, dynamic>.from(info['diploma'] as Map) : null;
    final cls = t.classes.isNotEmpty ? t.classes.first : null;
    final ready = total > 0 && done >= total;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: got != null ? const Color(0xFFD4A017) : c.border, width: got != null ? 2 : 1.4)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(t.id.contains('python') ? Icons.code_rounded : Icons.work_rounded, color: c.info),
          const SizedBox(width: 10),
          Expanded(child: Text(t.title, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w900, fontSize: 16))),
          if (got != null) const Icon(Icons.workspace_premium_rounded, color: Color(0xFFD4A017)),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(value: total == 0 ? 0 : done / total, minHeight: 8, backgroundColor: c.surfaceVariant, valueColor: AlwaysStoppedAnimation(c.info)),
        ),
        const SizedBox(height: 4),
        Text(context.tr('{a}/{b} chapitres terminés', {'a': '$done', 'b': '$total'}), style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
        const SizedBox(height: 10),
        Row(children: [
          if (cls != null)
            Expanded(
              child: QuizChunkyButton(
                label: context.tr('Apprendre'),
                icon: Icons.menu_book_rounded,
                color: c.info,
                textColor: Colors.white,
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EtudeClassPage(track: t, cls: cls))),
              ),
            ),
          if (cls == null)
            Expanded(
              child: QuizChunkyButton(
                label: context.tr('Voir le cours'),
                icon: Icons.menu_book_rounded,
                color: c.info,
                textColor: Colors.white,
                onPressed: () => quizToast(context, context.tr('Les chapitres se trouvent dans la Licence d\'Informatique, Licence 1.')),
              ),
            ),
          const SizedBox(width: 10),
          Expanded(
            child: got != null
                ? QuizChunkyButton(label: context.tr('Mon attestation'), icon: Icons.workspace_premium_rounded, color: c.accent, textColor: c.onAccent, onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EtudeDiplomaPage(diploma: got))))
                : QuizChunkyButton(
                    label: context.tr('Passer l\'examen'),
                    icon: ready ? Icons.edit_note_rounded : Icons.lock_rounded,
                    color: ready ? c.warning : c.surfaceVariant,
                    textColor: ready ? Colors.white : c.textSecondary,
                    onPressed: ready
                        ? () async {
                            final ok = await etudeLaunch(context, kind: 'cert', id: '${cert['id']}', item: 'cert:${cert['id']}', title: '${cert['title']}');
                            if (ok) await EtudeService.instance.refresh().catchError((Object _) => const EtudeState());
                          }
                        : null,
                  ),
          ),
        ]),
      ]),
    );
  }
}

/// Choix de la classe de départ d'un parcours.
class _StartSheet extends StatefulWidget {
  const _StartSheet({required this.track, required this.needDeclare, required this.tracks});
  final EtudeTrack track;
  final bool needDeclare;
  final List<EtudeTrack> tracks;

  @override
  State<_StartSheet> createState() => _StartSheetState();
}

class _StartSheetState extends State<_StartSheet> {
  late String _entry = widget.track.classes.first.id;
  bool _declared = false;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final prevNames = widget.track.after.map((id) => widget.tracks.where((t) => t.id == id).firstOrNull?.exam?['diploma'] ?? id).join(' / ');
    final canGo = !widget.needDeclare || _declared;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: BoxDecoration(color: c.background, borderRadius: const BorderRadius.vertical(top: Radius.circular(24)), border: Border.all(color: c.border)),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(child: Container(width: 44, height: 4, decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 14),
          Text(widget.track.title, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w900, fontSize: 20)),
          const SizedBox(height: 4),
          Text(context.tr('Par quelle classe veux-tu commencer ?'), style: TextStyle(color: c.textSecondary)),
          const SizedBox(height: 10),
          for (final cls in widget.track.classes)
            RadioListTile<String>(
              dense: true,
              contentPadding: EdgeInsets.zero,
              activeColor: c.primary,
              value: cls.id,
              groupValue: _entry,
              onChanged: (v) => setState(() => _entry = v ?? _entry),
              title: Text(cls.title, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700)),
              subtitle: cls.subjects.isEmpty ? Text(context.tr('Bientôt'), style: TextStyle(color: c.textSecondary, fontSize: 12)) : null,
            ),
          if (widget.needDeclare)
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              activeColor: c.primary,
              value: _declared,
              onChanged: (v) => setState(() => _declared = v ?? false),
              title: Text(context.tr('J\'ai déjà ce diplôme : {d}', {'d': '$prevNames'}), style: TextStyle(color: c.textPrimary, fontSize: 13.5)),
            ),
          const SizedBox(height: 8),
          QuizChunkyButton(
            label: context.tr('Commencer'),
            icon: Icons.flag_rounded,
            color: canGo ? c.primary : c.surfaceVariant,
            textColor: canGo ? c.onPrimary : c.textSecondary,
            onPressed: canGo ? () => Navigator.pop(context, {'entry': _entry, 'declared': _declared}) : null,
          ),
        ]),
      ),
    );
  }
}
