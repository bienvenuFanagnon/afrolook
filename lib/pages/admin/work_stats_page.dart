// work_stats_page.dart — suivi de la page Travail et des missions de Partage pour l'administration (API : GET /admin/work/stats).
// Fréquentation, temps passé, missions ou tâches (boutons réellement touchés), pubs plein écran montrées depuis ces pages et revenu estimé.
import 'package:afrotok/layout/centered_content.dart';
import 'package:afrotok/services/api/regie_api.dart';
import 'package:afrotok/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class WorkStatsPage extends StatefulWidget {
  const WorkStatsPage({Key? key}) : super(key: key);

  @override
  State<WorkStatsPage> createState() => _WorkStatsPageState();
}

class _WorkStatsPageState extends State<WorkStatsPage> {
  static final NumberFormat _nf = NumberFormat.decimalPattern('fr');

  int _days = 7;
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _d = {};

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
      final r = await RegieApi.getMap('/admin/work/stats', query: {'days': _days});
      if (!mounted) return;
      setState(() {
        _d = r;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = RegieApi.err(e);
          _loading = false;
        });
      }
    }
  }

  static int _i(Object? v) => v is num ? v.toInt() : 0;
  static Map<String, dynamic> _m(Object? v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
  static String _n(Object? v) => _nf.format(_i(v));

  /// 125 → « 2 min 05 s » ; 4 000 → « 1 h 06 min ».
  static String _dur(Object? v) {
    final s = _i(v);
    if (s < 60) return '$s s';
    if (s < 3600) return '${s ~/ 60} min ${(s % 60).toString().padLeft(2, '0')} s';
    return '${s ~/ 3600} h ${((s % 3600) ~/ 60).toString().padLeft(2, '0')} min';
  }

  Future<void> _editEcpm() async {
    final c = AppColors.of(context);
    final ads = _m(_d['ads']);
    final ctl = TextEditingController(text: ads['ecpmUsd'] == null ? '' : '${ads['ecpmUsd']}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        title: Text('Prix de 1 000 pubs montrées', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.bold)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Entre l\'eCPM en dollars (revenu pour 1 000 pubs plein écran), relevé dans le tableau de bord de ton fournisseur de pubs. Il sert uniquement à estimer le revenu ci-dessous. Vide = pas d\'estimation.',
              style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
          const SizedBox(height: 12),
          TextField(
            controller: ctl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
            decoration: const InputDecoration(suffixText: '\$ / 1 000 pubs', border: OutlineInputBorder()),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Enregistrer')),
        ],
      ),
    );
    if (ok != true) return;
    final v = double.tryParse(ctl.text.trim().replaceAll(',', '.'));
    try {
      await RegieApi.put('/admin/work/ecpm', body: {'ecpm_usd': v});
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(RegieApi.err(e)), backgroundColor: c.danger));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.surface,
        foregroundColor: c.textPrimary,
        elevation: 0,
        title: const Text('Suivi de la page Travail'),
        actions: [IconButton(tooltip: 'Actualiser', icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      body: SafeArea(
        child: CenteredContent(
          maxWidth: 900,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: c.danger)),
                          const SizedBox(height: 12),
                          OutlinedButton(onPressed: _load, child: const Text('Réessayer')),
                        ]),
                      ),
                    )
                  : RefreshIndicator(onRefresh: _load, child: _content(c)),
        ),
      ),
    );
  }

  Widget _card(AppColors c, {required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: c.border)),
        child: child,
      );

  Widget _title(AppColors c, String t, {String? sub}) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 15)),
          if (sub != null) Text(sub, style: TextStyle(color: c.textSecondary, fontSize: 12)),
        ]),
      );

  Widget _kpi(AppColors c, IconData icon, String label, String value, {String? sub}) => Container(
        width: 150,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 18, color: c.primary),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: c.textPrimary)),
          Text(label, style: TextStyle(fontSize: 11.5, color: c.textSecondary)),
          if (sub != null) Text(sub, style: TextStyle(fontSize: 10.5, color: c.textSecondary)),
        ]),
      );

  /// Ligne avec barre : part de [value] dans [total].
  Widget _bar(AppColors c, String label, String right, int value, int total, Color color, {String? sub}) {
    final share = total > 0 ? (value / total).clamp(0.0, 1.0) : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(label, style: TextStyle(color: c.textPrimary, fontSize: 13, fontWeight: FontWeight.w600))),
          Text(right, style: TextStyle(color: c.textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 5),
        ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: share, minHeight: 7, backgroundColor: c.border, valueColor: AlwaysStoppedAnimation(color))),
        if (sub != null) Padding(padding: const EdgeInsets.only(top: 3), child: Text(sub, style: TextStyle(color: c.textSecondary, fontSize: 11))),
      ]),
    );
  }

  Widget _content(AppColors c) {
    final t = _m(_d['totals']), pages = _m(_d['pages']), actions = _m(_d['actions']), ads = _m(_d['ads']);
    final daily = ((_d['daily'] as List?) ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    final top = ((_d['topUsers'] as List?) ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    final peak = daily.fold<int>(1, (m, e) => _i(e['visitors']) > m ? _i(e['visitors']) : m);
    final am = _m(actions['missions']), at = _m(actions['tasks']), ap = _m(actions['partner']);
    final tapsTotal = _i(am['taps']) + _i(at['taps']) + _i(ap['taps']);
    final adsTotal = _i(ads['total']);
    final work = _m(pages['work']), miss = _m(pages['missions']);
    final empty = _i(t['sessions']) == 0;

    return ListView(padding: const EdgeInsets.all(14), children: [
      Wrap(spacing: 8, children: [
        for (final d in const [7, 30, 90])
          ChoiceChip(
            label: Text('$d jours'),
            selected: _days == d,
            onSelected: (_) {
              setState(() => _days = d);
              _load();
            },
            selectedColor: c.primary.withOpacity(0.18),
            labelStyle: TextStyle(color: _days == d ? c.primary : c.textPrimary, fontWeight: _days == d ? FontWeight.bold : FontWeight.normal),
            side: BorderSide(color: _days == d ? c.primary : c.border),
          ),
      ]),
      const SizedBox(height: 12),
      if (empty)
        _card(c, child: Text('Aucune visite enregistrée sur cette période. Le suivi démarre avec la version de l\'application qui contient cette page : les chiffres arrivent au fur et à mesure que les personnes l\'ouvrent.', style: TextStyle(color: c.textSecondary, fontSize: 13)))
      else ...[
        Wrap(spacing: 10, runSpacing: 10, children: [
          _kpi(c, Icons.people_alt_outlined, 'Personnes venues', _n(t['visitors']), sub: '${_n(t['returningVisitors'])} reviennent'),
          _kpi(c, Icons.touch_app_outlined, 'Visites', _n(t['sessions'])),
          _kpi(c, Icons.timer_outlined, 'Temps par visite', _dur(t['avgSecondsPerSession'])),
          _kpi(c, Icons.hourglass_bottom, 'Temps par personne', _dur(t['avgSecondsPerVisitor']), sub: 'total ${_dur(t['seconds'])}'),
        ]),
        const SizedBox(height: 16),
        _card(c,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _title(c, 'Missions ou tâches ?', sub: 'Boutons réellement touchés depuis la page Travail'),
              _bar(c, 'Missions de partage', '${_n(am['taps'])} touches · ${_n(am['people'])} pers.', _i(am['taps']), tapsTotal, c.primary),
              _bar(c, 'Tâches (jeux, sondages, applications)', '${_n(at['taps'])} touches · ${_n(at['people'])} pers.', _i(at['taps']), tapsTotal, c.info),
              _bar(c, 'Plateformes de tâches (Tapjoy, AyeT)', '${_n(ap['taps'])} touches · ${_n(ap['people'])} pers.', _i(ap['taps']), tapsTotal, c.warning),
            ])),
        const SizedBox(height: 12),
        _card(c,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _title(c, 'Temps passé par page'),
              _bar(c, 'Page Travail (tâches)', '${_dur(work['avgSeconds'])} / visite', _i(work['seconds']), _i(t['seconds']), c.primary, sub: '${_n(work['visitors'])} personnes · ${_n(work['sessions'])} visites · ${_dur(work['seconds'])} au total'),
              _bar(c, 'Missions de Partage', '${_dur(miss['avgSeconds'])} / visite', _i(miss['seconds']), _i(t['seconds']), c.info, sub: '${_n(miss['visitors'])} personnes · ${_n(miss['sessions'])} visites · ${_dur(miss['seconds'])} au total'),
            ])),
        const SizedBox(height: 12),
        _card(c,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: _title(c, 'Pubs plein écran montrées', sub: 'Depuis la page Travail et les missions')),
                TextButton.icon(onPressed: _editEcpm, icon: const Icon(Icons.edit_outlined, size: 16), label: const Text('Prix')),
              ]),
              Row(children: [
                Text(_n(adsTotal), style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: c.textPrimary)),
                const SizedBox(width: 8),
                Text('pubs · ${ads['perVisitor'] ?? 0} par personne', style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
              ]),
              const SizedBox(height: 6),
              _bar(c, 'Avant d\'ouvrir les missions ou les tâches', _n(ads['tasks']), _i(ads['tasks']), adsTotal, c.primary),
              _bar(c, 'Avant une mission', _n(ads['missions']), _i(ads['missions']), adsTotal, c.info),
              _bar(c, 'Autres', _n(ads['other']), _i(ads['other']), adsTotal, c.warning),
              const SizedBox(height: 6),
              Text(
                ads['estimatedUsd'] == null
                    ? 'Revenu estimé : renseigne le prix de 1 000 pubs (bouton « Prix ») pour l\'estimer. Le revenu réel est dans le tableau de bord de ton fournisseur de pubs.'
                    : 'Revenu estimé : ≈ ${ads['estimatedUsd']} \$ (${_n(adsTotal)} pubs × ${ads['ecpmUsd']} \$ pour 1 000). Estimation : le revenu réel est dans le tableau de bord de ton fournisseur de pubs.',
                style: TextStyle(color: c.accentText, fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
            ])),
        const SizedBox(height: 12),
        _card(c,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _title(c, 'Personnes par jour'),
              SizedBox(
                height: 100,
                child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  for (final e in daily)
                    Expanded(
                      child: Tooltip(
                        message: '${e['day']} : ${_n(e['visitors'])} pers. · ${_n(e['sessions'])} visites · ${_dur(e['seconds'])} · ${_n(e['ads'])} pubs',
                        child: Container(margin: const EdgeInsets.symmetric(horizontal: 1.5), height: 4 + 92 * (_i(e['visitors']) / peak), decoration: BoxDecoration(color: c.primary, borderRadius: BorderRadius.circular(3))),
                      ),
                    ),
                ]),
              ),
              const SizedBox(height: 4),
              if (daily.isNotEmpty) Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('${daily.first['day']}'.substring(5), style: TextStyle(fontSize: 10.5, color: c.textSecondary)), Text('${daily.last['day']}'.substring(5), style: TextStyle(fontSize: 10.5, color: c.textSecondary))]),
            ])),
        const SizedBox(height: 12),
        _card(c,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _title(c, 'Les plus présents', sub: 'Classés par temps passé'),
              if (top.isEmpty) Text('Personne pour l\'instant', style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
              for (var i = 0; i < top.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(children: [
                    SizedBox(width: 24, child: Text('${i + 1}.', style: TextStyle(color: c.textSecondary, fontWeight: FontWeight.bold))),
                    Expanded(child: Text('@${top[i]['username'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textPrimary, fontSize: 13))),
                    Text('${_dur(top[i]['seconds'])} · ${_n(top[i]['sessions'])} visites · ${_n(top[i]['taps'])} touches · ${_n(top[i]['ads'])} pubs', style: TextStyle(color: c.textSecondary, fontSize: 11)),
                  ]),
                ),
            ])),
      ],
      const SizedBox(height: 24),
    ]);
  }
}
