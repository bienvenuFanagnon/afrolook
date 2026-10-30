import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../layout/centered_content.dart';
import '../../theme/app_colors.dart';
import 'offerwall_fraud_guide_page.dart';

/// Admin — « Tâches » (mur de tâches Tapjoy / ayeT-Studios) : ce que gagnent les utilisateurs, qui gagne, signes de fraude,
/// recherche d'un utilisateur et décision sur les tâches mises en revue. Les données viennent des fonctions offerwallAdmin*
/// (réservées aux administrateurs, voir functions/src/offerwall/offerwallAdmin.ts et docs/OFFERWALL_TACHES.md §12).
class OfferwallAdminPage extends StatefulWidget {
  const OfferwallAdminPage({super.key});

  @override
  State<OfferwallAdminPage> createState() => _OfferwallAdminPageState();
}

final NumberFormat _nf = NumberFormat.decimalPattern('fr');
String _coins(num v) => _nf.format(v.round());
String _fcfa(num coins) => '≈ ${_nf.format((coins * 0.4).round())} FCFA';
String _date(num ms) => ms <= 0 ? '—' : DateFormat('dd/MM/yyyy HH:mm').format(DateTime.fromMillisecondsSinceEpoch(ms.toInt()));

Future<Map<String, dynamic>> _call(String name, [Map<String, dynamic>? data]) async {
  final res = await FirebaseFunctions.instance.httpsCallable(name).call(data ?? <String, dynamic>{});
  return Map<String, dynamic>.from(res.data as Map);
}

String _err(Object e) => e is FirebaseFunctionsException ? (e.message ?? e.code) : e.toString();

Color _riskColor(String level, AppColors c) => level == 'élevé' ? c.danger : level == 'moyen' ? c.warning : c.primary;

/// Nom lisible du partenaire de tâches d'un événement.
String _providerName(Object? p) => switch ('$p') {
      'ayet' => 'ayeT',
      'tapjoy' => 'Tapjoy',
      'pubscale' => 'Pubscale',
      'afrolook_pub' => 'Pub Afrolook',
      final x => x.isEmpty ? '?' : x,
    };

String _statusLabel(String s) => switch (s) {
      'pending' => 'En attente',
      'validee' => 'Validée',
      'en_revue' => 'En revue',
      'refusee' => 'Refusée',
      'refusee_admin' => 'Refusée (admin)',
      'expiree' => 'Expirée',
      'annulee' => 'Annulée (régie)',
      _ => s,
    };

class _OfferwallAdminPageState extends State<OfferwallAdminPage> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.surface,
        foregroundColor: c.textPrimary,
        title: const Text('Tâches et offres'),
        actions: [
          IconButton(
            tooltip: 'Fraude : aide-mémoire',
            icon: const Icon(Icons.fact_check_rounded),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OfferwallFraudGuidePage())),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: c.primary,
          unselectedLabelColor: c.textSecondary,
          tabs: const [Tab(text: 'Vue d\'ensemble'), Tab(text: 'À revoir'), Tab(text: 'Utilisateur')],
        ),
      ),
      body: TabBarView(controller: _tabs, children: const [_OverviewTab(), _ReviewTab(), _UserTab()]),
    );
  }
}

// ── Vue d'ensemble ───────────────────────────────────────────────────────────

class _OverviewTab extends StatefulWidget {
  const _OverviewTab();
  @override
  State<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<_OverviewTab> {
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
    setState(() { _loading = true; _error = null; });
    try {
      final r = await _call('offerwallAdminOverview', {'days': _days});
      if (mounted) setState(() { _d = r; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = _err(e); _loading = false; });
    }
  }

  Widget _tile(AppColors c, String title, String value, {String? sub, Color? color}) => Expanded(
        child: Container(
          margin: const EdgeInsets.all(4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(color: c.textSecondary, fontSize: 11.5)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(color: color ?? c.textPrimary, fontSize: 19, fontWeight: FontWeight.w800)),
            if (sub != null) Text(sub, style: TextStyle(color: c.textSecondary, fontSize: 10.5)),
          ]),
        ),
      );

  Widget _userRow(AppColors c, Map u, {bool showRisk = false}) {
    final risk = Map<String, dynamic>.from(u['risk'] as Map);
    final level = '${risk['level']}';
    final pseudo = '${u['pseudo']}'.isEmpty ? '${u['userId']}'.substring(0, 6) : '@${u['pseudo']}';
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: c.surface,
        backgroundImage: '${u['imageUrl']}'.isNotEmpty ? NetworkImage('${u['imageUrl']}') : null,
        child: '${u['imageUrl']}'.isEmpty ? Icon(Icons.person_rounded, size: 18, color: c.textSecondary) : null,
      ),
      title: Text(pseudo, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700)),
      subtitle: Text(
        showRisk ? (risk['flags'] as List).join(' · ') : '${u['events']} tâche(s) · validées ${_coins(u['validated'])} · en attente ${_coins(u['pending'])}',
        maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textSecondary, fontSize: 11.5),
      ),
      trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text('${_coins(u['coins'])} pièces', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 12.5)),
        Text('risque $level', style: TextStyle(color: _riskColor(level, c), fontSize: 11, fontWeight: FontWeight.w700)),
      ]),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _UserDetailPage(userId: '${u['userId']}'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, style: TextStyle(color: c.danger))));
    final byStatus = Map<String, dynamic>.from(_d['byStatus'] as Map? ?? {});
    final byProvider = Map<String, dynamic>.from(_d['byProvider'] as Map? ?? {});
    int coinsOf(String k) => (byStatus[k]?['coins'] as num?)?.toInt() ?? 0;
    int eventsOf(String k) => (byStatus[k]?['events'] as num?)?.toInt() ?? 0;
    final series = (_d['series'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final maxCoins = series.fold<num>(1, (m, e) => (e['coins'] as num) > m ? e['coins'] as num : m);
    final top = (_d['top'] as List? ?? []);
    final suspects = (_d['suspects'] as List? ?? []);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.all(12), children: [
        CenteredContent(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 8, children: [
              for (final d in [1, 7, 30]) ChoiceChip(label: Text(d == 1 ? 'Aujourd\'hui' : '$d jours'), selected: _days == d, onSelected: (_) { _days = d; _load(); }),
            ]),
            const SizedBox(height: 6),
            Row(children: [
              _tile(c, 'Tâches', '${_d['events']}', sub: '${_d['users']} utilisateur(s)'),
              _tile(c, 'Pièces validées', _coins(coinsOf('validee')), sub: _fcfa(coinsOf('validee')), color: c.primary),
            ]),
            Row(children: [
              _tile(c, 'En attente', _coins(coinsOf('pending')), sub: '${eventsOf('pending')} tâche(s)'),
              _tile(c, 'En revue', _coins(coinsOf('en_revue')), sub: '${eventsOf('en_revue')} tâche(s)', color: eventsOf('en_revue') > 0 ? c.warning : null),
            ]),
            Row(children: [
              _tile(c, 'Versé aux parrains', _coins(_d['sponsorCoins'] as num? ?? 0), sub: _fcfa(_d['sponsorCoins'] as num? ?? 0)),
              _tile(c, 'Part de l\'application', _coins(_d['studioCoins'] as num? ?? 0), sub: '${_fcfa(_d['studioCoins'] as num? ?? 0)} · tâches validées', color: c.primary),
            ]),
            const SizedBox(height: 8),
            Text('Par partenaire de tâches', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            if (byProvider.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text('Aucune tâche sur la période.', style: TextStyle(color: c.textSecondary))),
            for (final p in byProvider.entries)
              Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: c.border)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_providerName(p.key), style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text('${(p.value['events'] as num?) ?? 0} tâche(s) · ${_coins((p.value['coins'] as num?) ?? 0)} pièces', style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
                  Text('Validées : ${_coins((p.value['validatedCoins'] as num?) ?? 0)} · part de l\'application ${_coins((p.value['studioCoins'] as num?) ?? 0)} (${_fcfa((p.value['studioCoins'] as num?) ?? 0)}) · parrains ${_coins((p.value['sponsorCoins'] as num?) ?? 0)}', style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
                ]),
              ),
            if (_d['truncated'] == true)
              Padding(padding: const EdgeInsets.all(6), child: Text('Période très chargée : seuls les 3 000 derniers événements sont analysés.', style: TextStyle(color: c.warning, fontSize: 11.5))),
            const SizedBox(height: 10),
            Text('Pièces par jour', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            for (final e in series.reversed.take(14))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(children: [
                  SizedBox(width: 78, child: Text('${e['day']}'.substring(5), style: TextStyle(color: c.textSecondary, fontSize: 11.5))),
                  Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: (e['coins'] as num) / maxCoins, minHeight: 9, backgroundColor: c.border, color: c.primary))),
                  SizedBox(width: 92, child: Text('  ${_coins(e['coins'])} (${e['events']})', style: TextStyle(color: c.textPrimary, fontSize: 11.5))),
                ]),
              ),
            const SizedBox(height: 14),
            Text('Comptes à surveiller', style: TextStyle(color: c.danger, fontWeight: FontWeight.w800)),
            if (suspects.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('Aucun signe de fraude sur la période.', style: TextStyle(color: c.textSecondary))),
            for (final u in suspects) _userRow(c, u as Map, showRisk: true),
            const SizedBox(height: 14),
            Text('Ceux qui gagnent le plus', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800)),
            if (top.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('Aucune tâche sur la période.', style: TextStyle(color: c.textSecondary))),
            for (final u in top) _userRow(c, u as Map),
            const SizedBox(height: 24),
          ]),
        ),
      ]),
    );
  }
}

// ── Tâches à revoir ──────────────────────────────────────────────────────────

class _ReviewTab extends StatefulWidget {
  const _ReviewTab();
  @override
  State<_ReviewTab> createState() => _ReviewTabState();
}

class _ReviewTabState extends State<_ReviewTab> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _list = [];
  String? _busy;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final r = await _call('offerwallAdminEvents', {'status': 'en_revue'});
      if (mounted) setState(() { _list = (r['events'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList(); _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = _err(e); _loading = false; });
    }
  }

  Future<void> _decide(Map<String, dynamic> e, String action) async {
    setState(() => _busy = '${e['id']}');
    try {
      await _call('offerwallAdminReview', {'eventId': e['id'], 'action': action});
      await _load();
    } catch (err) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_err(err))));
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, style: TextStyle(color: c.danger))));
    if (_list.isEmpty) return Center(child: Text('Aucune tâche en revue.', style: TextStyle(color: c.textSecondary)));
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _list.length,
        itemBuilder: (_, i) {
          final e = _list[i];
          final busy = _busy == '${e['id']}';
          return CenteredContent(
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.border)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text('${e['pseudo']}'.isEmpty ? '${e['userId']}' : '@${e['pseudo']}', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800))),
                  Text('${_coins(e['coins'])} pièces', style: TextStyle(color: c.primary, fontWeight: FontWeight.w800)),
                ]),
                const SizedBox(height: 4),
                Text('${_date(e['createdAt'])} · ${_providerName(e['provider'])} ${e['platform']} · ${e['reason']}', style: TextStyle(color: c.textSecondary, fontSize: 11.5)),
                const SizedBox(height: 8),
                Row(children: [
                  TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _UserDetailPage(userId: '${e['userId']}'))), child: const Text('Voir l\'utilisateur')),
                  const Spacer(),
                  if (busy) const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  else ...[
                    OutlinedButton(onPressed: () => _decide(e, 'reject'), style: OutlinedButton.styleFrom(foregroundColor: c.danger), child: const Text('Refuser')),
                    const SizedBox(width: 8),
                    FilledButton(onPressed: () => _decide(e, 'approve'), child: const Text('Approuver')),
                  ],
                ]),
              ]),
            ),
          );
        },
      ),
    );
  }
}

// ── Recherche d'un utilisateur ───────────────────────────────────────────────

class _UserTab extends StatefulWidget {
  const _UserTab();
  @override
  State<_UserTab> createState() => _UserTabState();
}

class _UserTabState extends State<_UserTab> {
  final _ctrl = TextEditingController();
  bool _loading = false;
  String? _msg;
  List<Map<String, dynamic>> _matches = [];

  Future<void> _search() async {
    final q = _ctrl.text.trim();
    if (q.length < 2) { setState(() => _msg = 'Saisissez au moins 2 caractères.'); return; }
    setState(() { _loading = true; _msg = null; _matches = []; });
    try {
      final r = await _call('offerwallAdminUser', {'query': q});
      if (!mounted) return;
      if (r['matches'] != null) {
        final m = (r['matches'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        setState(() { _matches = m; _msg = m.isEmpty ? 'Aucun utilisateur trouvé (identifiant, pseudo ou e-mail exact).' : null; });
      } else {
        final id = '${(r['user'] as Map)['id']}';
        Navigator.push(context, MaterialPageRoute(builder: (_) => _UserDetailPage(userId: id)));
      }
    } catch (e) {
      if (mounted) setState(() => _msg = _err(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return ListView(padding: const EdgeInsets.all(12), children: [
      CenteredContent(
        child: Column(children: [
          TextField(
            controller: _ctrl,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(),
            decoration: InputDecoration(
              hintText: 'Identifiant, pseudo ou e-mail',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: IconButton(icon: const Icon(Icons.arrow_forward_rounded), onPressed: _search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          if (_loading) const Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()),
          if (_msg != null) Padding(padding: const EdgeInsets.all(12), child: Text(_msg!, style: TextStyle(color: c.textSecondary))),
          for (final m in _matches)
            ListTile(
              leading: CircleAvatar(backgroundImage: '${m['imageUrl']}'.isNotEmpty ? NetworkImage('${m['imageUrl']}') : null, child: '${m['imageUrl']}'.isEmpty ? const Icon(Icons.person_rounded) : null),
              title: Text('@${m['pseudo']}', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700)),
              subtitle: Text('${m['email']} · gagné ${_coins(m['earned'])} · en attente ${_coins(m['pending'])}', style: TextStyle(color: c.textSecondary, fontSize: 11.5)),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _UserDetailPage(userId: '${m['id']}'))),
            ),
        ]),
      ),
    ]);
  }
}

// ── Détail d'un utilisateur ──────────────────────────────────────────────────

class _UserDetailPage extends StatefulWidget {
  const _UserDetailPage({required this.userId});
  final String userId;
  @override
  State<_UserDetailPage> createState() => _UserDetailPageState();
}

class _UserDetailPageState extends State<_UserDetailPage> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _d = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final r = await _call('offerwallAdminUser', {'userId': widget.userId});
      if (mounted) setState(() { _d = r; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = _err(e); _loading = false; });
    }
  }

  Future<void> _toggleBlock(bool blocked) async {
    String reason = '';
    if (blocked) {
      final ctrl = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Suspendre des tâches'),
          content: TextField(controller: ctrl, decoration: const InputDecoration(hintText: 'Raison (visible seulement des administrateurs)')),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Suspendre'))],
        ),
      );
      if (ok != true) return;
      reason = ctrl.text.trim();
    }
    try {
      await _call('offerwallAdminBlock', {'userId': widget.userId, 'blocked': blocked, 'reason': reason});
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_err(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(backgroundColor: c.surface, foregroundColor: c.textPrimary, title: const Text('Gains de l\'utilisateur')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, style: TextStyle(color: c.danger))))
              : _body(c),
    );
  }

  Widget _body(AppColors c) {
    final u = Map<String, dynamic>.from(_d['user'] as Map);
    final risk = Map<String, dynamic>.from(_d['risk'] as Map);
    final act = Map<String, dynamic>.from(_d['activity'] as Map);
    final events = (_d['events'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final level = '${risk['level']}';
    final total = (u['earned'] as num) + (u['pending'] as num);
    final sponsor = u['sponsor'] as Map?;
    return ListView(padding: const EdgeInsets.all(12), children: [
      CenteredContent(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(radius: 26, backgroundImage: '${u['imageUrl']}'.isNotEmpty ? NetworkImage('${u['imageUrl']}') : null, child: '${u['imageUrl']}'.isEmpty ? const Icon(Icons.person_rounded) : null),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('@${u['pseudo']}', style: TextStyle(color: c.textPrimary, fontSize: 17, fontWeight: FontWeight.w800)),
              Text('${u['email']}', style: TextStyle(color: c.textSecondary, fontSize: 12)),
              Text('Inscrit le ${_date(u['createdAt'])}${'${u['country']}'.isEmpty ? '' : ' · ${u['country']}'}', style: TextStyle(color: c.textSecondary, fontSize: 12)),
            ])),
          ]),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: _riskColor(level, c))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Risque : $level (score ${risk['score']})', style: TextStyle(color: _riskColor(level, c), fontWeight: FontWeight.w800)),
              if ((risk['flags'] as List).isEmpty) Text('Aucun signe de fraude.', style: TextStyle(color: c.textSecondary, fontSize: 12)),
              for (final f in risk['flags'] as List) Text('• $f', style: TextStyle(color: c.textPrimary, fontSize: 12.5)),
            ]),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _mini(c, 'Total gagné grâce aux tâches', _coins(total), _fcfa(total))),
            const SizedBox(width: 8),
            Expanded(child: _mini(c, 'En attente', _coins(u['pending'] as num), 'déjà inclus dans le total')),
          ]),
          const SizedBox(height: 8),
          Text('Sur les 24 dernières heures : ${act['eventsLast24h']} tâche(s), ${_coins(act['coinsLast24h'] as num)} pièces. Tâches mises en revue : ${act['reviewCount']}.', style: TextStyle(color: c.textSecondary, fontSize: 12)),
          if (sponsor != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text('Parrain : @${sponsor['pseudo']}', style: TextStyle(color: c.textSecondary, fontSize: 12))),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: u['blocked'] == true,
            title: Text('Suspendu des tâches', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700)),
            subtitle: Text(u['blocked'] == true ? '${u['blockedReason']}' : 'Les pièces restent en attente tant que le compte est suspendu.', style: TextStyle(color: c.textSecondary, fontSize: 11.5)),
            onChanged: _toggleBlock,
          ),
          const Divider(),
          Text('Historique (${events.length})', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800)),
          for (final e in events)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text('${_coins(e['coins'])} pièces · ${_statusLabel('${e['status']}')}', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w600)),
              subtitle: Text('${_date(e['createdAt'])} · ${_providerName(e['provider'])} ${e['platform']}${'${e['reason']}'.isEmpty ? '' : ' · ${e['reason']}'}${(e['sponsorCoins'] as num) > 0 ? ' · parrain ${e['sponsorCoins']}' : ''}', style: TextStyle(color: c.textSecondary, fontSize: 11.5)),
            ),
          const SizedBox(height: 24),
        ]),
      ),
    ]);
  }

  Widget _mini(AppColors c, String title, String value, String sub) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(color: c.textSecondary, fontSize: 11.5)),
          Text(value, style: TextStyle(color: c.primary, fontSize: 20, fontWeight: FontWeight.w800)),
          Text(sub, style: TextStyle(color: c.textSecondary, fontSize: 10.5)),
        ]),
      );
}
