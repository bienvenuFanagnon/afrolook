import 'package:flutter/material.dart';

import '../../ads/ad_gate.dart';
import '../../l10n/tr.dart';
import '../../services/etude/etude_service.dart';
import '../../theme/app_colors.dart';
import '../quiz/quiz_defi_lines.dart';
import '../quiz/widgets/hawk_mascot.dart';
import '../quiz/widgets/quiz_ads.dart';
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

class _EtudeHomePageState extends State<EtudeHomePage> with EtudeAdBypass {
  List<EtudeTrack>? _tracks;
  String? _error;
  bool _busy = false; // rechargement : la mascotte s'anime
  final TextEditingController _search = TextEditingController();
  String _query = '';
  String _rub = 'all'; // rubrique : all, school, univ, concours, skills
  String _fac = 'all'; // faculté (rubrique Université) : all, sci, eco, law, health, sport

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Faculté (domaine) d'un parcours, déduite de son identifiant.
  String _facultyOf(EtudeTrack t) {
    final id = t.id;
    if (id == 'college' || id.startsWith('lycee')) return 'school';
    if (id == 'univ_info' || id == 'univ_mpc' || id == 'univ_btp') return 'sci';
    if (id == 'univ_comm') return 'arts';
    if (id == 'univ_agro') return 'agro';
    if (id == 'univ_efc' || id == 'univ_gestion' || id == 'univ_marketing') return 'eco';
    if (id == 'univ_droit') return 'law';
    if (id == 'univ_sante') return 'health';
    if (id == 'univ_sport') return 'sport';
    return 'other';
  }

  String _facultyLabel(String f) {
    switch (f) {
      case 'school':
        return context.tr('École');
      case 'sci':
        return context.tr('Sciences et technologies');
      case 'eco':
        return context.tr('Économie et gestion');
      case 'law':
        return context.tr('Droit');
      case 'health':
        return context.tr('Santé');
      case 'arts':
        return context.tr('Lettres et communication');
      case 'agro':
        return context.tr('Agronomie');
      case 'sport':
        return context.tr('Sport');
      default:
        return context.tr('Autres');
    }
  }

  IconData _facultyIcon(String f) {
    switch (f) {
      case 'school':
        return Icons.school_rounded;
      case 'sci':
        return Icons.science_rounded;
      case 'eco':
        return Icons.trending_up_rounded;
      case 'law':
        return Icons.gavel_rounded;
      case 'health':
        return Icons.health_and_safety_rounded;
      case 'arts':
        return Icons.campaign_rounded;
      case 'agro':
        return Icons.grass_rounded;
      case 'sport':
        return Icons.sports_soccer_rounded;
      default:
        return Icons.account_balance_rounded;
    }
  }

  /// Rubrique d'un parcours : école, université, concours (BTS…) ou compétences (attestations).
  String _rubricOf(EtudeTrack t) {
    final id = t.id;
    if (id == 'college' || id.startsWith('lycee')) return 'school';
    if (id.startsWith('univ_')) return 'univ';
    if (id.startsWith('bts_') || id.startsWith('concours_')) return 'concours';
    return 'skills';
  }

  String _rubricLabel(String r) {
    switch (r) {
      case 'school':
        return context.tr('École');
      case 'univ':
        return context.tr('Université');
      case 'concours':
        return context.tr('Concours et BTS');
      case 'skills':
        return context.tr('Compétences');
      default:
        return context.tr('Tout');
    }
  }

  String _rubricHint(String r) {
    switch (r) {
      case 'school':
        return context.tr('Collège et lycée : BEPC et BAC');
      case 'univ':
        return context.tr('Licences par faculté');
      case 'concours':
        return context.tr("Préparer un concours d'entrée");
      default:
        return context.tr('Entretien, Python, IA…');
    }
  }

  IconData _rubricIcon(String r) {
    switch (r) {
      case 'school':
        return Icons.school_rounded;
      case 'univ':
        return Icons.account_balance_rounded;
      case 'concours':
        return Icons.emoji_events_rounded;
      case 'skills':
        return Icons.workspace_premium_rounded;
      default:
        return Icons.apps_rounded;
    }
  }

  bool _matches(EtudeTrack t) {
    if (_rub != 'all' && _rubricOf(t) != _rub) return false;
    if (_rub == 'univ' && _fac != 'all' && _facultyOf(t) != _fac) return false;
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    if (t.title.toLowerCase().contains(q) || _rubricLabel(_rubricOf(t)).toLowerCase().contains(q) || _facultyLabel(_facultyOf(t)).toLowerCase().contains(q)) return true;
    for (final cls in t.classes) {
      for (final sub in cls.subjects) {
        if (sub.title.toLowerCase().contains(q)) return true;
        for (final ch in sub.chapters) {
          if (ch.title.toLowerCase().contains(q)) return true;
        }
      }
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
      if (_tracks != null) _busy = true;
    });
    try {
      final job = Future.wait([EtudeService.instance.catalog(force: true), EtudeService.instance.refresh()]);
      final r = await (_tracks == null ? job : quizMinTime(job, ms: 650));
      if (mounted) {
        setState(() {
          _tracks = r[0] as List<EtudeTrack>;
          _busy = false;
        });
      }
    } on EtudeException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.code;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'NETWORK';
        });
      }
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
              ? const QuizLoading(kind: QuizLoadingKind.etude)
              : QuizBusyOverlay(
                  busy: _busy,
                  kind: QuizLoadingKind.etude,
                  child: ValueListenableBuilder<EtudeState?>(
                    valueListenable: EtudeService.instance.state,
                    builder: (context, s, _) => _content(c, s ?? const EtudeState()),
                  ),
                ),
    );
  }

  /// « À la une » : les parcours mis en avant par l'équipe (champ `featured` du catalogue), en défilement horizontal.
  List<Widget> _featuredSection(AppColors c, EtudeState st, List<EtudeTrack> all) {
    final list = all.where((t) => t.featured > 0).toList()..sort((a, b) => a.featured.compareTo(b.featured));
    if (list.isEmpty) return const [];
    return [
      _sectionTitle(c, context.tr('À la une'), context.tr('Nos parcours à ne pas manquer')),
      SizedBox(
        height: 168,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (_, i) => _featuredCard(c, st, list[i], i),
        ),
      ),
      const SizedBox(height: 18),
    ];
  }

  Widget _featuredCard(AppColors c, EtudeState st, EtudeTrack t, int i) {
    final tint = [c.primary, c.info, c.accent, c.warning][i % 4];
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => _openFeatured(t),
      child: Container(
        width: 250,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [tint.withOpacity(0.32), c.surface], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: tint.withOpacity(0.7), width: 1.5),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: tint.withOpacity(0.25), shape: BoxShape.circle),
              child: Icon(_rubricIcon(_rubricOf(t)), color: tint, size: 20),
            ),
            const Spacer(),
            if (t.badge.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(20)),
                child: Text(context.tr(t.badge), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11)),
              ),
          ]),
          const SizedBox(height: 10),
          Text(t.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w900, fontSize: 16, height: 1.2)),
          const SizedBox(height: 4),
          Expanded(
            child: Text(context.tr(t.pitch), maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textSecondary, fontSize: 12.5, height: 1.3)),
          ),
          Row(children: [
            Text(context.tr('Découvrir'), style: TextStyle(color: tint, fontWeight: FontWeight.w900, fontSize: 13)),
            Icon(Icons.arrow_forward_rounded, color: tint, size: 16),
          ]),
        ]),
      ),
    );
  }

  /// Ouvre la carte complète du parcours dans une feuille, sans quitter l'accueil.
  void _openFeatured(EtudeTrack t) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.of(context).background,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        builder: (_, scroll) => ValueListenableBuilder<EtudeState?>(
          valueListenable: EtudeService.instance.state,
          builder: (_, s, __) => ListView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [_card(AppColors.of(ctx), s ?? const EtudeState(), t)],
          ),
        ),
      ),
    );
  }

  /// Sous-groupe d'un parcours dans une rubrique (pour ne pas tout empiler dans une seule liste).
  String _groupOf(EtudeTrack t) {
    final id = t.id;
    switch (_rubricOf(t)) {
      case 'concours':
        return id.startsWith('bts_') ? context.tr('Concours BTS') : context.tr('Concours administratifs');
      case 'skills':
        if (id == 'cert_entretien') return context.tr('Emploi');
        if (id == 'permis_conduire') return context.tr('Vie pratique');
        return context.tr('Numérique');
      case 'univ':
        return _facultyLabel(_facultyOf(t));
      default:
        return '';
    }
  }

  /// Cartes d'une liste, séparées par petits titres de sous-groupe quand il y en a plusieurs.
  List<Widget> _grouped(AppColors c, EtudeState st, List<EtudeTrack> list) {
    if (_rub == 'all' || _rub == 'school') return [for (final t in list) _card(c, st, t)];
    final groups = <String, List<EtudeTrack>>{};
    for (final t in list) {
      groups.putIfAbsent(_groupOf(t), () => []).add(t);
    }
    if (groups.length < 2) return [for (final t in list) _card(c, st, t)];
    return [
      for (final e in groups.entries) ...[
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 8),
          child: Row(children: [
            Container(width: 4, height: 16, decoration: BoxDecoration(color: c.primary, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 8),
            Text(e.key, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w900, fontSize: 14.5)),
            const SizedBox(width: 6),
            Text('${e.value.length}', style: TextStyle(color: c.textSecondary, fontWeight: FontWeight.w800, fontSize: 12.5)),
          ]),
        ),
        for (final t in e.value) _card(c, st, t),
      ],
    ];
  }

  bool _inProgress(EtudeState st, EtudeTrack t) {
    if (t.isCycle) return st.tracks.containsKey(t.id);
    final info = st.certs[t.cert?['id']] as Map? ?? const {};
    return ((info['done'] as num?)?.toInt() ?? 0) > 0;
  }

  Widget _card(AppColors c, EtudeState st, EtudeTrack t) => t.isCycle ? _trackCard(c, st, t) : _certCard(c, st, t);

  Widget _content(AppColors c, EtudeState st) {
    final all = _tracks!.where((t) => t.isCycle || t.cert != null).toList();
    final browsing = _rub != 'all' || _query.trim().isNotEmpty;
    final shown = all.where(_matches).toList();
    final mine = shown.where((t) => _inProgress(st, t)).toList();
    final others = shown.where((t) => !_inProgress(st, t)).toList();
    return RefreshIndicator(
      onRefresh: () async {
        _load();
      },
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
        _header(c, st),
        const SizedBox(height: 16),
        _searchBar(c),
        const SizedBox(height: 10),
        _rubricChips(c, all),
        if (_rub == 'univ') ...[
          const SizedBox(height: 8),
          _facultyChips(c, all.where((t) => _rubricOf(t) == 'univ').toList()),
        ],
        const SizedBox(height: 14),
        if (!browsing) ...[
          ..._featuredSection(c, st, all),
          if (mine.isNotEmpty) ...[
            _sectionTitle(c, context.tr('En cours'), context.tr('Reprends là où tu t\'es arrêté')),
            for (final t in mine) _card(c, st, t),
          ],
          _sectionTitle(c, context.tr('Que veux-tu apprendre ?'), context.tr('Choisis une rubrique')),
          _rubricTiles(c, all),
          const QuizAdInline(),
          if (st.diplomas.isNotEmpty) ...[
            const SizedBox(height: 10),
            _sectionTitle(c, context.tr('Mes diplômes'), null),
            for (final d in st.diplomas) Padding(padding: const EdgeInsets.only(bottom: 8), child: EtudeDiplomaTile(diploma: d)),
          ],
        ] else if (shown.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text(context.tr('Aucun parcours ne correspond à ta recherche.'), textAlign: TextAlign.center, style: TextStyle(color: c.textSecondary))),
          )
        else ...[
          if (mine.isNotEmpty) ...[
            _sectionTitle(c, context.tr('En cours'), null),
            for (final t in mine) _card(c, st, t),
          ],
          if (others.isNotEmpty) ...[
            _sectionTitle(c, mine.isEmpty ? (_rub == 'all' ? context.tr('Résultats') : _rubricLabel(_rub)) : context.tr('À découvrir'), _rub == 'all' ? null : _rubricHint(_rub)),
            ..._grouped(c, st, others),
          ],
          const QuizAdInline(),
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

  /// Rubriques : une ligne de pastilles défilantes avec le nombre de parcours.
  Widget _rubricChips(AppColors c, List<EtudeTrack> all) {
    const keys = ['all', 'school', 'univ', 'concours', 'skills'];
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: keys.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final k = keys[i];
          final selected = _rub == k;
          return ChoiceChip(
            avatar: Icon(_rubricIcon(k), size: 16, color: selected ? c.primary : c.textSecondary),
            label: Text(_rubricLabel(k)),
            selected: selected,
            onSelected: (_) => setState(() {
              _rub = k;
              _fac = 'all';
            }),
            selectedColor: c.primary.withOpacity(0.2),
            backgroundColor: c.surface,
            labelStyle: TextStyle(color: selected ? c.primary : c.textPrimary, fontWeight: FontWeight.w800, fontSize: 13),
            side: BorderSide(color: selected ? c.primary : c.border),
          );
        },
      ),
    );
  }

  /// Écran d'accueil : quatre grandes tuiles plutôt qu'une longue liste.
  Widget _rubricTiles(AppColors c, List<EtudeTrack> all) {
    const keys = ['school', 'univ', 'concours', 'skills'];
    return Column(children: [
      for (final k in keys)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => setState(() {
              _rub = k;
              _fac = 'all';
            }),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: c.border, width: 1.4)),
              child: Row(children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(color: c.primary.withOpacity(0.15), shape: BoxShape.circle),
                  child: Icon(_rubricIcon(k), color: c.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_rubricLabel(k), style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w900, fontSize: 16)),
                    Text(_rubricHint(k), style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
                  ]),
                ),
                QuizPill(icon: Icons.menu_book_rounded, label: context.tr('{n} parcours', {'n': '${all.where((t) => _rubricOf(t) == k).length}'}), color: c.info),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded, color: c.textSecondary),
              ]),
            ),
          ),
        ),
    ]);
  }

  Widget _searchBar(AppColors c) {
    return TextField(
      controller: _search,
      onChanged: (v) => setState(() => _query = v),
      style: TextStyle(color: c.textPrimary),
      decoration: InputDecoration(
        hintText: context.tr('Rechercher un parcours, une matière ou un chapitre'),
        hintStyle: TextStyle(color: c.textSecondary, fontSize: 14),
        prefixIcon: Icon(Icons.search_rounded, color: c.textSecondary),
        suffixIcon: _query.isEmpty
            ? null
            : IconButton(
                tooltip: context.tr('Effacer'),
                icon: Icon(Icons.close_rounded, color: c.textSecondary),
                onPressed: () {
                  _search.clear();
                  setState(() => _query = '');
                },
              ),
        filled: true,
        fillColor: c.surface,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: c.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: c.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: c.primary, width: 1.6)),
      ),
    );
  }

  Widget _facultyChips(AppColors c, List<EtudeTrack> cycles) {
    final present = <String>{for (final t in cycles) _facultyOf(t)};
    const order = ['sci', 'eco', 'law', 'health', 'arts', 'agro', 'sport'];
    final keys = ['all', ...order.where(present.contains)];
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: keys.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final k = keys[i];
          final selected = _fac == k;
          return ChoiceChip(
            label: Text(k == 'all' ? context.tr('Toutes') : _facultyLabel(k)),
            selected: selected,
            onSelected: (_) => setState(() => _fac = k),
            selectedColor: c.primary.withOpacity(0.2),
            backgroundColor: c.surface,
            labelStyle: TextStyle(color: selected ? c.primary : c.textPrimary, fontWeight: FontWeight.w800, fontSize: 13),
            side: BorderSide(color: selected ? c.primary : c.border),
          );
        },
      ),
    );
  }

  Widget _sectionTitle(AppColors c, String title, String? sub) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w900, fontSize: 19)),
          if (sub != null) Text(sub, style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
        ]),
      );

  /// Phrase d'accroche de l'en-tête (change chaque jour).
  String _hook(EtudeState st) {
    final lines = [
      'Chapitre après chapitre, ton diplôme se construit ici.',
      'Réponds, valide ta classe, décroche ton diplôme !',
      'Chaque bonne réponse te rapproche de ton examen.',
      'Révise malin : un chapitre par jour fait la différence.',
      ...kEtudeDefiLines,
      ...kQuizDefiLines,
    ];
    final d = DateTime.now();
    return context.tr(lines[(d.year * 372 + d.month * 31 + d.day + st.xp ~/ 50) % lines.length]);
  }

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
            Text(_hook(st), style: TextStyle(color: c.textSecondary, fontWeight: FontWeight.w700, fontSize: 12.5, height: 1.3)),
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
            child: Icon(_facultyIcon(_facultyOf(t)), color: c.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.title, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w900, fontSize: 17)),
              Text(_facultyLabel(_facultyOf(t)), style: TextStyle(color: c.textSecondary, fontSize: 12, fontWeight: FontWeight.w700)),
            ]),
          ),
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
          Icon(t.id.contains('python') || t.id == 'bts_info' ? Icons.code_rounded : (_rubricOf(t) == 'concours' ? Icons.emoji_events_rounded : Icons.work_rounded), color: c.info),
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
