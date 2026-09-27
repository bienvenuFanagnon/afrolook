import 'package:afrotok/layout/centered_content.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../theme/app_colors.dart';

/// Admin — Commissions : ce que l'app gagne réellement, par source et par période.
///
/// Source : CommissionsDaily/{AAAA-MM-JJ}, alimenté par le serveur à chaque paiement en pièces
/// (payWithCoins, sendLike, sendPostGift, sendLiveGift, DÉFI). Montants en pièces, avec
/// l'équivalent FCFA au taux de conversion (25 pièces = 10 FCFA).
class CommissionsAdminPage extends StatefulWidget {
  const CommissionsAdminPage({super.key});

  @override
  State<CommissionsAdminPage> createState() => _CommissionsAdminPageState();
}

enum _Period { today, week, month30, thisMonth }

class _CommissionsAdminPageState extends State<CommissionsAdminPage> {
  static final NumberFormat _n = NumberFormat.decimalPattern('fr');
  static const double _fcfaPerCoin = 0.4;

  /// Libellés et icônes des sources (clés écrites par le serveur, voir coinShares.ts).
  static const Map<String, (String, IconData)> _sources = {
    'likes': ('Likes', Icons.favorite_rounded),
    'cadeaux': ('Cadeaux sur les posts', Icons.card_giftcard_rounded),
    'cadeaux_live': ('Cadeaux en live', Icons.live_tv_rounded),
    'defi': ('DÉFI (votes, participations)', Icons.emoji_events_rounded),
    'groupes': ('Abonnements groupes', Icons.groups_rounded),
    'canaux': ('Abonnements canaux', Icons.campaign_rounded),
    'lives_prives': ('Lives privés', Icons.lock_rounded),
    'participation_live': ('Participation aux lives', Icons.mic_rounded),
    'premium': ('Premium', Icons.workspace_premium_rounded),
    'gold': ('Gold', Icons.star_rounded),
    'compte_officiel': ('Comptes officiels', Icons.verified_rounded),
    'pubs_boosts': ('Publicités et boosts', Icons.rocket_launch_rounded),
    'abonnement_entreprise': ('Abonnements entreprise (Afroshop)', Icons.store_rounded),
    'contenus': ('Contenus payants (en pièces)', Icons.storefront_rounded),
  };

  _Period _period = _Period.month30;
  bool _loading = true;
  Map<String, int> _totals = {};
  int _days = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _key(DateTime d) => DateFormat('yyyy-MM-dd').format(d.toUtc());

  Future<void> _load() async {
    setState(() => _loading = true);
    final now = DateTime.now();
    final start = switch (_period) {
      _Period.today => DateTime(now.year, now.month, now.day),
      _Period.week => now.subtract(const Duration(days: 6)),
      _Period.month30 => now.subtract(const Duration(days: 29)),
      _Period.thisMonth => DateTime(now.year, now.month, 1),
    };
    try {
      final snap = await FirebaseFirestore.instance
          .collection('CommissionsDaily')
          .where('date', isGreaterThanOrEqualTo: _key(start))
          .where('date', isLessThanOrEqualTo: _key(now))
          .get();
      final totals = <String, int>{};
      for (final d in snap.docs) {
        d.data().forEach((k, v) {
          if (_sources.containsKey(k) && v is num) totals[k] = (totals[k] ?? 0) + v.round();
        });
      }
      if (!mounted) return;
      setState(() {
        _totals = totals;
        _days = snap.docs.length;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur de chargement : $e')));
    }
  }

  String _coins(int v) => '${_n.format(v)} pièces';
  String _fcfa(int v) => '≈ ${_n.format((v * _fcfaPerCoin).round())} FCFA';

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final total = _totals.values.fold(0, (s, v) => s + v);
    final rows = _totals.entries.where((e) => e.value > 0).toList()..sort((a, b) => b.value.compareTo(a.value));

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: c.textPrimary),
        title: Text('Commissions', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 17)),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: c.textPrimary),
            tooltip: 'Actualiser',
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: CenteredContent(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              _periodChips(c),
              const SizedBox(height: 14),
              if (_loading)
                const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
              else ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: _box(c),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Gains de l\'app sur la période', style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
                    const SizedBox(height: 4),
                    Text(_coins(total),
                        style: TextStyle(color: c.textPrimary, fontSize: 24, fontWeight: FontWeight.w800)),
                    Text(_fcfa(total), style: TextStyle(color: c.textSecondary, fontSize: 13)),
                    const SizedBox(height: 6),
                    Text('$_days jour(s) avec activité', style: TextStyle(color: c.textSecondary, fontSize: 11.5)),
                  ]),
                ),
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
                  child: Text('PAR SOURCE',
                      style: TextStyle(color: c.textSecondary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: _box(c),
                  child: rows.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                              child: Text('Aucune commission sur la période',
                                  style: TextStyle(color: c.textSecondary))),
                        )
                      : Column(children: [
                          for (var i = 0; i < rows.length; i++) ...[
                            if (i > 0) Divider(height: 1, thickness: 0.5, color: c.border),
                            _sourceRow(c, rows[i].key, rows[i].value, total),
                          ],
                        ]),
                ),
                const SizedBox(height: 12),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.info_outline_rounded, size: 14, color: c.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Part de l\'app après le créateur (70 %) et les parrainages (2,5 % + 2,5 %). '
                      'Suivi démarré le 27/09/2026 : les gains antérieurs figurent dans l\'« Ancien compteur » du tableau de bord.',
                      style: TextStyle(color: c.textSecondary, fontSize: 11.5, height: 1.35),
                    ),
                  ),
                ]),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _sourceRow(AppColors c, String key, int value, int total) {
    final (label, icon) = _sources[key]!;
    final ratio = total > 0 ? value / total : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(children: [
        Row(children: [
          Icon(icon, size: 18, color: c.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: TextStyle(color: c.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w600))),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(_coins(value), style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
            Text(_fcfa(value), style: TextStyle(color: c.textSecondary, fontSize: 11)),
          ]),
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 5,
            backgroundColor: c.surfaceVariant,
            valueColor: AlwaysStoppedAnimation(c.primary),
          ),
        ),
      ]),
    );
  }

  Widget _periodChips(AppColors c) {
    const labels = {
      _Period.today: "Aujourd'hui",
      _Period.week: '7 jours',
      _Period.month30: '30 jours',
      _Period.thisMonth: 'Ce mois',
    };
    return Wrap(spacing: 6, runSpacing: 6, children: [
      for (final e in labels.entries)
        GestureDetector(
          onTap: () {
            if (_period == e.key) return;
            setState(() => _period = e.key);
            _load();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: _period == e.key ? c.textPrimary : c.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _period == e.key ? c.textPrimary : c.border),
            ),
            child: Text(e.value,
                style: TextStyle(
                  color: _period == e.key ? c.background : c.textSecondary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                )),
          ),
        ),
    ]);
  }

  BoxDecoration _box(AppColors c) => BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      );
}
