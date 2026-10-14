import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../layout/centered_content.dart';
import '../../providers/authProvider.dart';
import '../../theme/app_colors.dart';

// ─── Modèles ────────────────────────────────────────────────────────────────

class _StatsPoint {
  final String label;
  final int count;
  const _StatsPoint(this.label, this.count);
}

class _InscriptionData {
  final String period;
  final List<_StatsPoint> points;
  final int total;
  const _InscriptionData({required this.period, required this.points, required this.total});
}

// ─── Page principale ─────────────────────────────────────────────────────────

class TeamHubPage extends StatefulWidget {
  const TeamHubPage({super.key});

  @override
  State<TeamHubPage> createState() => _TeamHubPageState();
}

class _TeamHubPageState extends State<TeamHubPage> {
  static const _periods = [
    ('today', "Aujourd'hui"),
    ('yesterday', 'Hier'),
    ('week', 'Cette semaine'),
    ('month', 'Ce mois'),
    ('3months', '3 mois'),
    ('6months', '6 mois'),
    ('12months', '12 mois'),
  ];

  bool _loading = true;
  String? _error;
  String _period = 'week';
  String _profileName = '';
  List<String> _widgets = [];
  _InscriptionData? _inscriptions;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final fn = FirebaseFunctions.instance.httpsCallable('getTeamHubData');
      final res = await fn.call({'period': _period});
      final data = Map<String, dynamic>.from(res.data);
      final profile = Map<String, dynamic>.from(data['profile'] ?? {});
      final wData = Map<String, dynamic>.from(data['widgets'] ?? {});

      _InscriptionData? insc;
      if (wData.containsKey('stats_inscriptions')) {
        final d = Map<String, dynamic>.from(wData['stats_inscriptions']);
        final pts = (d['points'] as List)
            .map((p) => _StatsPoint(p['label'] as String, (p['count'] as num).toInt()))
            .toList();
        insc = _InscriptionData(
          period: d['period'] as String,
          points: pts,
          total: (d['total'] as num).toInt(),
        );
      }

      if (!mounted) return;
      setState(() {
        _loading = false;
        _profileName = profile['name'] as String? ?? '';
        _widgets = List<String>.from(profile['widgets'] ?? []);
        _inscriptions = insc;
      });
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.code; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isWide = MediaQuery.of(context).size.width >= 700;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Hub Équipe', style: TextStyle(fontWeight: FontWeight.w700)),
          if (_profileName.isNotEmpty)
            Text(_profileName,
                style: TextStyle(fontSize: 12, color: colors.primary, fontWeight: FontWeight.w500)),
        ]),
        actions: [
          if (!_loading)
            IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
        ],
      ),
      body: SafeArea(
        child: CenteredContent(
          maxWidth: 900,
          child: _loading
              ? Center(child: CircularProgressIndicator(color: colors.primary))
              : _error != null
                  ? _buildError()
                  : _buildContent(isWide),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.lock_outline_rounded, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(_error == 'permission-denied' ? 'Accès non autorisé' : 'Erreur : $_error',
              textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[500])),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _load, child: const Text('Réessayer')),
        ]),
      ),
    );
  }

  Widget _buildContent(bool isWide) {
    return ListView(
      padding: EdgeInsets.symmetric(horizontal: isWide ? 24 : 16, vertical: 16),
      children: [
        // Sélecteur de période
        _buildPeriodSelector(),
        const SizedBox(height: 20),

        // Widgets autorisés
        if (_widgets.contains('stats_inscriptions') && _inscriptions != null)
          _InscriptionsCard(data: _inscriptions!, colors: AppColors.of(context)),

        if (_widgets.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text('Aucun widget disponible pour ce profil.',
                  style: TextStyle(color: Colors.grey[500])),
            ),
          ),
      ],
    );
  }

  Widget _buildPeriodSelector() {
    final colors = AppColors.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _periods.map((p) {
          final selected = _period == p.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                if (_period == p.$1) return;
                setState(() => _period = p.$1);
                _load();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: selected ? colors.primary : colors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(p.$2,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : colors.primary,
                    )),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Widget inscriptions ─────────────────────────────────────────────────────

class _InscriptionsCard extends StatelessWidget {
  final _InscriptionData data;
  final AppColors colors;

  const _InscriptionsCard({required this.data, required this.colors});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final max = data.points.fold(1, (m, p) => p.count > m ? p.count : m);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.person_add_alt_1_rounded, color: colors.primary, size: 20),
          const SizedBox(width: 8),
          Text('Nouvelles inscriptions', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(color: colors.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
            child: Text('${data.total}', style: TextStyle(color: colors.primary, fontWeight: FontWeight.w800, fontSize: 16)),
          ),
        ]),
        const SizedBox(height: 20),

        // Graphe en barres
        SizedBox(
          height: 140,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: data.points.map((pt) {
              final ratio = max == 0 ? 0.0 : pt.count / max;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (pt.count > 0)
                        Text('${pt.count}',
                            style: TextStyle(fontSize: 9, color: colors.primary, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        height: 100 * ratio.clamp(0.02, 1.0),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [colors.primary.withOpacity(0.7), colors.primary],
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(pt.label, style: TextStyle(fontSize: 9, color: Colors.grey[500]), overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ]),
    );
  }
}
