import 'package:flutter/material.dart';

import '../../services/contes/contes_service.dart';
import '../../theme/app_colors.dart';

int _n(dynamic v) => v is num ? v.toInt() : 0;

/// Admin de La Case aux Contes : lecteurs, lectures, taux de fin, déblocages (pubs, pièces, lectures offertes), carte du fil,
/// contes les plus lus, points d'abandon, et gestion des contes (masquer, mettre à la une, prix).
/// Les données viennent de la fonction `conteAdmin` (réservée aux admins).
class ContesAdminPage extends StatefulWidget {
  const ContesAdminPage({super.key});

  @override
  State<ContesAdminPage> createState() => _ContesAdminPageState();
}

class _ContesAdminPageState extends State<ContesAdminPage> {
  Map<String, dynamic>? _d;
  ContesCatalog? _catalog;
  String? _error;
  final Map<String, bool> _hidden = {};
  final Map<String, bool> _featured = {};
  final Map<String, int?> _price = {};
  String _q = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final r = await Future.wait([ContesService.instance.admin(), ContesService.instance.catalog(force: true)]);
      if (mounted) {
        setState(() {
          _d = r[0] as Map<String, dynamic>;
          _catalog = r[1] as ContesCatalog;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Widget _card(AppColors c, String title, Widget child) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: c.border, width: 1.2)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 8),
          child,
        ]),
      );

  Widget _kpi(AppColors c, String v, String label) => Expanded(
        child: Column(children: [
          Text(v, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: c.textPrimary)),
          const SizedBox(height: 2),
          Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: c.textSecondary, fontWeight: FontWeight.w700)),
        ]),
      );

  Widget _row(AppColors c, String k, Object v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Expanded(child: Text(k, style: TextStyle(color: c.textSecondary, fontSize: 13))),
          Text('$v', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 13)),
        ]),
      );

  Widget _bars(AppColors c, List<dynamic> days) {
    final vals = [for (final x in days) _n((x as Map)['opens'])];
    final mx = vals.fold<int>(1, (a, b) => b > a ? b : a);
    return SizedBox(
      height: 90,
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        for (var i = 0; i < days.length; i++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                Text('${vals[i]}', style: TextStyle(fontSize: 10, color: c.textSecondary, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Container(height: 8 + 56.0 * vals[i] / mx, decoration: BoxDecoration(color: c.accent, borderRadius: BorderRadius.circular(4))),
                const SizedBox(height: 3),
                Text(((days[i] as Map)['day'] as String).substring(6), style: TextStyle(fontSize: 10, color: c.textSecondary)),
              ]),
            ),
          ),
      ]),
    );
  }

  Future<void> _patch(ConteCard card, Map<String, dynamic> patch) async {
    try {
      await ContesService.instance.adminStory(card.id, patch);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Échec : $e')));
      _load();
    }
  }

  Future<void> _editPrice(ConteCard card, int current) async {
    final ctrl = TextEditingController(text: '$current');
    final res = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Prix de « ${card.title} »', style: const TextStyle(fontSize: 16)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: ctrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Pièces (0 = gratuit)')),
          const SizedBox(height: 8),
          const Text('Laisser vide pour revenir au prix du type de conte.', style: TextStyle(fontSize: 12)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Enregistrer')),
        ],
      ),
    );
    if (res == null) return;
    if (res.isEmpty) {
      setState(() => _price[card.id] = null);
      await _patch(card, {'price': null});
    } else {
      final v = int.tryParse(res);
      if (v == null || v < 0 || v > 500) return;
      setState(() => _price[card.id] = v);
      await _patch(card, {'price': v});
    }
  }

  Widget _manage(AppColors c, ContesCatalog cat, ContesCfg cfg) {
    final q = _q.toLowerCase();
    final cards = cat.cards.where((x) => q.isEmpty || x.title.toLowerCase().contains(q) || x.collectionId.contains(q)).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextField(
        onChanged: (v) => setState(() => _q = v),
        decoration: InputDecoration(prefixIcon: const Icon(Icons.search_rounded), hintText: 'Chercher un conte', isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
      ),
      const SizedBox(height: 8),
      for (final x in cards)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(x.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 13)),
                Text('${x.collectionId} · ${x.minutes} min · ${_price.containsKey(x.id) ? _price[x.id] : cfg.priceOf(x)} pièces', style: TextStyle(color: c.textSecondary, fontSize: 11.5)),
              ]),
            ),
            IconButton(visualDensity: VisualDensity.compact, tooltip: 'Prix', icon: Icon(Icons.edit_rounded, size: 18, color: c.textSecondary), onPressed: () => _editPrice(x, _price[x.id] ?? cfg.priceOf(x))),
            Column(mainAxisSize: MainAxisSize.min, children: [
              Text('À la une', style: TextStyle(fontSize: 9.5, color: c.textSecondary)),
              Switch(
                value: _featured[x.id] ?? x.featured,
                onChanged: (v) {
                  setState(() => _featured[x.id] = v);
                  _patch(x, {'featured': v});
                },
              ),
            ]),
            Column(mainAxisSize: MainAxisSize.min, children: [
              Text('Masqué', style: TextStyle(fontSize: 9.5, color: c.textSecondary)),
              Switch(
                value: _hidden[x.id] ?? false,
                onChanged: (v) {
                  setState(() => _hidden[x.id] = v);
                  _patch(x, {'active': !v});
                },
              ),
            ]),
          ]),
        ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final d = _d;
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        elevation: 0,
        iconTheme: IconThemeData(color: c.textPrimary),
        title: Text('Contes · admin', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w900)),
        actions: [IconButton(onPressed: _load, icon: Icon(Icons.refresh_rounded, color: c.textPrimary))],
      ),
      body: _error != null
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(_error!, style: TextStyle(color: c.danger)), TextButton(onPressed: _load, child: const Text('Réessayer'))]))
          : d == null
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(onRefresh: _load, child: ListView(padding: const EdgeInsets.all(16), children: _sections(c, d))),
    );
  }

  List<Widget> _sections(AppColors c, Map<String, dynamic> d) {
    final w = Map<String, dynamic>.from(d['week'] as Map);
    final cfg = ContesCfg.fromMap(d['config'] as Map);
    final feedView = _n(w['feedView']);
    final feedClick = _n(w['feedClick']);
    final ctr = feedView == 0 ? 0 : (feedClick * 100 / feedView).round();
    final unlocks = _n(w['unlockAds']) + _n(w['unlockCoins']) + _n(w['unlockFree']);
    String share(int x) => unlocks == 0 ? '0 %' : '${(x * 100 / unlocks).round()} %';
    return [
      _card(c, 'Participation', Row(children: [
        _kpi(c, '${_n(d['readers'])}', 'Lecteurs'),
        _kpi(c, '${_n(d['activeToday'])}', "Actifs aujourd'hui"),
        _kpi(c, '${_n(d['active7'])}', 'Actifs sur 7 jours'),
        _kpi(c, '${_n(d['completionRate'])} %', 'Taux de fin'),
      ])),
      _card(c, 'Ouvertures par jour (7 jours)', _bars(c, d['perDay'] as List)),
      _card(c, 'Cette semaine', Column(children: [
        _row(c, 'Contes ouverts', _n(w['opens'])),
        _row(c, '… dont depuis le téléphone (sans relire le texte)', _n(w['cachedOpens'])),
        _row(c, 'Contes terminés (premières fois)', _n(w['finishes'])),
        _row(c, 'Pass Veillée actifs', _n(d['passActive'])),
      ])),
      _card(c, 'Déblocages (7 jours)', Column(children: [
        _row(c, 'Par pubs', '${_n(w['unlockAds'])} (${share(_n(w['unlockAds']))})'),
        _row(c, 'Par pièces', '${_n(w['unlockCoins'])} (${share(_n(w['unlockCoins']))})'),
        _row(c, 'Lectures offertes (aucune pub disponible)', '${_n(w['unlockFree'])} (${share(_n(w['unlockFree']))})'),
        _row(c, 'Pubs avec récompense regardées', _n(w['adsRewarded'])),
        _row(c, 'Pubs plein écran (déblocage)', _n(w['adsInterstitial'])),
        _row(c, 'Pièces dépensées', _n(d['coins7'])),
      ])),
      _card(c, 'Carte « Conte du jour » dans le fil (7 jours)', Column(children: [
        _row(c, 'Affichages', feedView),
        _row(c, 'Clics', '$feedClick ($ctr %)'),
        _row(c, 'Masquée par la croix', _n(w['feedDismiss'])),
        _row(c, 'Ambiance coupée / remise', '${_n(w['soundOff'])} / ${_n(w['soundOn'])}'),
      ])),
      _card(c, 'Contes les plus ouverts', _topList(c, d['topOpened'] as List, 'opens')),
      _card(c, 'Contes les plus terminés', _topList(c, d['topFinished'] as List, 'finishes')),
      _card(c, 'Où les lecteurs abandonnent', Column(children: [
        for (final t in (d['worstDrop'] as List))
          _row(c, '${(t as Map)['title']}', '${_n(t['finishes'])}/${_n(t['opens'])} fins · page ${_n(t['dropPage'])}'),
        if ((d['worstDrop'] as List).isEmpty) Text('Pas assez de lectures pour le moment', style: TextStyle(color: c.textSecondary, fontSize: 13)),
      ])),
      _card(c, 'Gérer les contes', _catalog == null ? const SizedBox.shrink() : _manage(c, _catalog!, cfg)),
      _card(c, 'Réglages (AppConfig/contes)', Column(children: [
        for (final e in (d['config'] as Map).entries) _row(c, '${e.key}', '${e.value}'),
      ])),
    ];
  }

  Widget _topList(AppColors c, List rows, String key) {
    if (rows.isEmpty) return Text('Aucun pour le moment', style: TextStyle(color: c.textSecondary, fontSize: 13));
    return Column(children: [for (final t in rows) _row(c, '${(t as Map)['title']}', _n(t[key]))]);
  }
}
