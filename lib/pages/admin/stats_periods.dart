// stats_periods.dart — périodes communes des mesures de l'administration (cinéma, page Travail ; 21/11/2026).
// L'API accepte `period` = today | yesterday | 3 | 7 | 30 | 90 (derniers jours, aujourd'hui compris, heure UTC).
import 'package:afrotok/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

const List<(String, String)> kStatsPeriods = [
  ('today', 'Aujourd\'hui'),
  ('yesterday', 'Hier'),
  ('3', '3 jours'),
  ('7', '7 jours'),
  ('30', '30 jours'),
  ('90', '90 jours'),
];

/// Liste « personnes venues par jour », du plus récent au plus ancien. [daily] : éléments {day, visitors, visits ou sessions}.
class StatsDailyList extends StatelessWidget {
  const StatsDailyList({super.key, required this.daily});

  final List<Map<String, dynamic>> daily;

  static final NumberFormat _nf = NumberFormat.decimalPattern('fr');
  static int _i(Object? v) => v is num ? v.toInt() : 0;

  static String _label(String day) {
    final d = DateTime.tryParse(day);
    if (d == null) return day;
    final today = DateTime.now().toUtc();
    final t0 = DateTime.utc(today.year, today.month, today.day);
    final diff = t0.difference(DateTime.utc(d.year, d.month, d.day)).inDays;
    if (diff == 0) return 'Aujourd\'hui';
    if (diff == 1) return 'Hier';
    const wd = ['lun.', 'mar.', 'mer.', 'jeu.', 'ven.', 'sam.', 'dim.'];
    return '${wd[d.weekday - 1]} ${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final rows = daily.reversed.toList();
    final peak = rows.fold<int>(1, (m, e) => _i(e['visitors']) > m ? _i(e['visitors']) : m);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (final e in rows)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            SizedBox(width: 92, child: Text(_label('${e['day']}'), style: TextStyle(color: c.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w600))),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(value: _i(e['visitors']) / peak, minHeight: 7, backgroundColor: c.border, valueColor: AlwaysStoppedAnimation(c.primary)),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 120,
              child: Text('${_nf.format(_i(e['visitors']))} pers. · ${_nf.format(_i(e['visits'] ?? e['sessions']))} visites',
                  textAlign: TextAlign.right, style: TextStyle(color: c.textSecondary, fontSize: 11.5)),
            ),
          ]),
        ),
    ]);
  }
}
