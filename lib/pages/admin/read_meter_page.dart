import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/read_meter.dart';
import '../../theme/app_colors.dart';

/// Mesure des lectures Firestore (diagnostic temporaire) : sources les plus actives de cette session et total du jour, tous téléphones confondus.
class ReadMeterPage extends StatefulWidget {
  const ReadMeterPage({super.key});

  @override
  State<ReadMeterPage> createState() => _ReadMeterPageState();
}

class _ReadMeterPageState extends State<ReadMeterPage> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  Map<String, int>? _today;
  int _reports = 0;
  int _total = 0;
  String? _error;
  bool _loading = false;
  String _day = '';

  @override
  void initState() {
    super.initState();
    _loadToday();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  /// `ReadStats/{jour}` : un document par jour (une lecture), additionné par le serveur.
  Future<void> _loadToday({bool yesterday = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = DateTime.now().toUtc().subtract(Duration(days: yesterday ? 1 : 0));
      _day = '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
      final snap = await FirebaseFirestore.instance.collection('ReadStats').doc(_day).get();
      final data = snap.data();
      final tags = <String, int>{};
      ((data?['tags'] as Map?) ?? const {}).forEach((k, v) => tags[k.toString()] = (v as num).toInt());
      if (!mounted) return;
      setState(() {
        _today = tags;
        _reports = (data?['reports'] as num?)?.toInt() ?? 0;
        _total = (data?['totalReads'] as num?)?.toInt() ?? 0;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _loading = false;
        });
      }
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
        title: const Text('Mesure des lectures'),
        bottom: TabBar(controller: _tabs, tabs: const [Tab(text: 'Cette session'), Tab(text: 'Jour (tous)')]),
      ),
      body: TabBarView(controller: _tabs, children: [_session(c), _day_(c)]),
    );
  }

  Widget _session(AppColors c) {
    final all = ReadMeter.instance.session;
    final total = all.values.fold<int>(0, (a, b) => a + b);
    return _list(c, ReadMeter.top(all, max: 80), total, header: 'Depuis l\'ouverture de l\'application : $total lectures', onRefresh: () async => setState(() {}));
  }

  Widget _day_(AppColors c) {
    if (_error != null) return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, style: TextStyle(color: c.textSecondary))));
    if (_today == null) return const Center(child: CircularProgressIndicator());
    return _list(
      c,
      ReadMeter.top(_today!, max: 80),
      _total,
      header: 'Jour $_day (UTC) : $_total lectures envoyées par $_reports envois',
      onRefresh: _loadToday,
      footer: TextButton(onPressed: _loading ? null : () => _loadToday(yesterday: true), child: const Text('Voir hier')),
    );
  }

  Widget _list(AppColors c, Map<String, int> rows, int total, {required String header, required Future<void> Function() onRefresh, Widget? footer}) {
    final entries = rows.entries.toList();
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        itemCount: entries.length + 2,
        itemBuilder: (_, i) {
          if (i == 0) return Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(header, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700)));
          if (i == entries.length + 1) return footer ?? const SizedBox.shrink();
          final e = entries[i - 1];
          final share = total == 0 ? 0.0 : e.value / total;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(e.key, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textPrimary, fontSize: 12.5))),
                Text('${e.value}  (${(share * 100).toStringAsFixed(1)} %)', style: TextStyle(color: c.textSecondary, fontSize: 12, fontFeatures: const [FontFeature.tabularFigures()])),
              ]),
              const SizedBox(height: 3),
              ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(value: share.clamp(0.0, 1.0), minHeight: 4, backgroundColor: c.border, color: c.primary)),
            ]),
          );
        },
      ),
    );
  }
}
