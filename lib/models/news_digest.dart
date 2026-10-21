import 'news_article.dart';

/// Résumé du jour, de la semaine ou du mois (NewsDigests/{périmètre}_{période}_{clé}) : les infos les plus importantes de la période.
/// Chaque élément est une COPIE de l'article (titre, chapô, image, sources) : il reste lisible quand l'article d'origine a disparu.
class NewsDigestItem {
  final String id;
  final String agentKey;
  final String category;
  final String title;
  final String chapo;
  final String image;
  final List<NewsSource> sources;
  final int sourceCount;
  final int at;
  final double rank;

  const NewsDigestItem({
    required this.id,
    required this.agentKey,
    required this.category,
    required this.title,
    required this.chapo,
    required this.image,
    required this.sources,
    required this.sourceCount,
    required this.at,
    required this.rank,
  });

  NewsAgentInfo get agent => newsAgentOf(agentKey);

  factory NewsDigestItem.fromMap(Map<String, dynamic> m) => NewsDigestItem(
        id: (m['id'] ?? '').toString(),
        agentKey: (m['agentKey'] ?? '').toString(),
        category: (m['category'] ?? '').toString(),
        title: (m['title'] ?? '').toString(),
        chapo: (m['chapo'] ?? '').toString(),
        image: (m['image'] ?? '').toString(),
        sources: ((m['sources'] as List?) ?? const []).map((e) => NewsSource(((e as Map)['name'] ?? '').toString(), (e['url'] ?? '').toString())).toList(),
        sourceCount: (m['sourceCount'] as num?)?.toInt() ?? 1,
        at: (m['at'] as num?)?.toInt() ?? 0,
        rank: (m['rank'] as num?)?.toDouble() ?? 0,
      );
}

class NewsDigest {
  final String scope;
  final String period;
  final String key;
  final int from;
  final int to;
  final String intro;
  final List<NewsDigestItem> items;

  const NewsDigest({required this.scope, required this.period, required this.key, required this.from, required this.to, required this.intro, required this.items});

  factory NewsDigest.fromMap(Map<String, dynamic> m) => NewsDigest(
        scope: (m['scope'] ?? '').toString(),
        period: (m['period'] ?? '').toString(),
        key: (m['key'] ?? '').toString(),
        from: (m['from'] as num?)?.toInt() ?? 0,
        to: (m['to'] as num?)?.toInt() ?? 0,
        intro: (m['intro'] ?? '').toString(),
        items: ((m['items'] as List?) ?? const []).map((e) => NewsDigestItem.fromMap(Map<String, dynamic>.from(e as Map))).toList(),
      );
}

/// Une période proposée à la personne : « Aujourd'hui », « Hier », « Cette semaine », « octobre 2026 »…
class PeriodChoice {
  final String key;
  final String label;

  /// Vrai pour « Aujourd'hui » : les articles du moment, lus dans le fil (le résumé du jour paraît le soir).
  final bool live;
  const PeriodChoice(this.key, this.label, {this.live = false});
}

/// Clés de période, en UTC : les mêmes que celles du serveur (functions/src/news/digest.ts).
class NewsPeriods {
  NewsPeriods._();

  static String _two(int n) => n.toString().padLeft(2, '0');
  static const _weekdays = ['lun.', 'mar.', 'mer.', 'jeu.', 'ven.', 'sam.', 'dim.'];
  static const _monthsShort = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];
  static const _months = ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'];

  static String dayKey(DateTime d) {
    final u = d.toUtc();
    return '${u.year}-${_two(u.month)}-${_two(u.day)}';
  }

  static String monthKey(DateTime d) {
    final u = d.toUtc();
    return '${u.year}-${_two(u.month)}';
  }

  /// Semaine ISO (lundi à dimanche) : « 2026-W43 ».
  static String weekKey(DateTime d) {
    final u = DateTime.utc(d.toUtc().year, d.toUtc().month, d.toUtc().day);
    final thursday = u.add(Duration(days: 4 - u.weekday));
    final week = thursday.difference(DateTime.utc(thursday.year, 1, 1)).inDays ~/ 7 + 1;
    return '${thursday.year}-W${_two(week)}';
  }

  /// Aujourd'hui (en direct) puis les 6 jours précédents.
  static List<PeriodChoice> days([DateTime? now]) {
    final n = (now ?? DateTime.now()).toUtc();
    return [
      for (var i = 0; i < 7; i++)
        () {
          final d = DateTime.utc(n.year, n.month, n.day).subtract(Duration(days: i));
          final label = i == 0 ? 'Aujourd\'hui' : i == 1 ? 'Hier' : '${_weekdays[d.weekday - 1]} ${d.day} ${_monthsShort[d.month - 1]}';
          return PeriodChoice(dayKey(d), label, live: i == 0);
        }(),
    ];
  }

  /// La semaine en cours (son résumé paraît le dimanche soir) puis les 3 précédentes.
  static List<PeriodChoice> weeks([DateTime? now]) {
    final n = (now ?? DateTime.now()).toUtc();
    final monday = DateTime.utc(n.year, n.month, n.day).subtract(Duration(days: n.weekday - 1));
    return [
      for (var i = 0; i < 4; i++)
        () {
          final start = monday.subtract(Duration(days: 7 * i));
          final end = start.add(const Duration(days: 6));
          final label = i == 0 ? 'Cette semaine' : 'Du ${start.day} ${_monthsShort[start.month - 1]} au ${end.day} ${_monthsShort[end.month - 1]}';
          return PeriodChoice(weekKey(start), label);
        }(),
    ];
  }

  /// Le mois en cours (son résumé paraît le dernier jour) puis les 5 précédents.
  static List<PeriodChoice> months([DateTime? now]) {
    final n = (now ?? DateTime.now()).toUtc();
    return [
      for (var i = 0; i < 6; i++)
        () {
          final d = DateTime.utc(n.year, n.month - i, 1);
          return PeriodChoice(monthKey(d), i == 0 ? 'Ce mois-ci' : '${_months[d.month - 1]} ${d.year}');
        }(),
    ];
  }
}
