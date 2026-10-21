import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Actualités d'Afrolook : des résumés de plusieurs sources publiés par des agents (comptes à part entière).
/// Un article est un post de type NEWS (Posts/{id}) : likes, commentaires, vues et cadeaux utilisent les mécanismes des posts.
/// L'index du fil (NewsFeed/{périmètre}) donne de quoi afficher une carte sans lire le post.

class NewsSource {
  final String name;
  final String url;
  const NewsSource(this.name, this.url);
}

class NewsSection {
  final String title;
  final String text;
  const NewsSection(this.title, this.text);
}

/// Un agent : pseudo, domaine, icône du badge. Les mêmes clés existent côté serveur (functions/src/news/agents.ts).
class NewsAgentInfo {
  final String key;
  final String pseudo;
  final String label;
  final IconData icon;
  const NewsAgentInfo(this.key, this.pseudo, this.label, this.icon);

  /// Identifiant du compte de l'agent (Users/{id}).
  String get userId => 'news_agent_$key';

  /// Couleur du domaine, prise dans la palette de l'application.
  Color color(AppColors c) {
    switch (key) {
      case 'sport':
        return c.primary;
      case 'politik':
        return c.info;
      case 'culture':
        return c.warning;
      case 'beat':
        return c.danger;
      case 'tech':
        return c.supportAccent;
      default:
        return c.info;
    }
  }
}

const List<NewsAgentInfo> kNewsAgents = [
  NewsAgentInfo('sport', 'AfroSport', 'Sport', Icons.sports_soccer_rounded),
  NewsAgentInfo('politik', 'AfroPolitik', 'Politique', Icons.account_balance_rounded),
  NewsAgentInfo('culture', 'AfroCulture', 'Culture', Icons.theater_comedy_rounded),
  NewsAgentInfo('beat', 'AfroBeat', 'Musique', Icons.music_note_rounded),
  NewsAgentInfo('tech', 'AfroTech', 'Technologie', Icons.memory_rounded),
  NewsAgentInfo('voyage', 'AfroVoyage', 'Voyage', Icons.flight_takeoff_rounded),
];

NewsAgentInfo newsAgentOf(String? key) => kNewsAgents.firstWhere((a) => a.key == key, orElse: () => kNewsAgents.first);

const Map<String, String> _kContinentNames = {
  'AF': 'Afrique',
  'EU': 'Europe',
  'AS': 'Asie',
  'NA': 'Amérique du Nord',
  'SA': 'Amérique du Sud',
  'OC': 'Océanie',
};

/// Pastille de niveau : « 🇹🇬 TG » pour un pays, « Afrique » pour un continent, « Monde ».
String newsLevelLabel(String level, String? country, String? continent) {
  if (level == 'country' && country != null && country.length == 2) {
    final flag = String.fromCharCodes(country.toUpperCase().codeUnits.map((c) => 0x1F1E6 + c - 65));
    return '$flag ${country.toUpperCase()}';
  }
  if (level == 'continent') return _kContinentNames[continent] ?? 'Continent';
  return 'Monde';
}

/// Élément de l'index du fil (NewsFeed/{périmètre}.items).
class NewsFeedItem {
  final String id;
  final String agentKey;
  final String category;
  final String level;
  final String? country;
  final String? continent;
  final String title;
  final String chapo;
  final String image;
  final int sourceCount;
  final List<String> sourceNames;
  final int at;

  const NewsFeedItem({
    required this.id,
    required this.agentKey,
    required this.category,
    required this.level,
    required this.country,
    required this.continent,
    required this.title,
    required this.chapo,
    required this.image,
    required this.sourceCount,
    required this.sourceNames,
    required this.at,
  });

  factory NewsFeedItem.fromMap(Map<String, dynamic> m) => NewsFeedItem(
        id: (m['id'] ?? '').toString(),
        agentKey: (m['agentKey'] ?? '').toString(),
        category: (m['category'] ?? '').toString(),
        level: (m['level'] ?? 'world').toString(),
        country: m['country']?.toString(),
        continent: m['continent']?.toString(),
        title: (m['title'] ?? '').toString(),
        chapo: (m['chapo'] ?? '').toString(),
        image: (m['image'] ?? '').toString(),
        sourceCount: (m['sourceCount'] as num?)?.toInt() ?? 1,
        sourceNames: ((m['sourceNames'] as List?) ?? const []).map((e) => e.toString()).toList(),
        at: (m['at'] as num?)?.toInt() ?? 0,
      );
}

/// Article complet (Posts/{id} de type NEWS).
class NewsArticle {
  final String id;
  final String agentKey;
  final String category;
  final String level;
  final String? country;
  final String? continent;
  final String title;
  final String chapo;
  final List<NewsSection> sections;
  final List<String> retenir;
  final List<NewsSource> sources;
  final String image;
  final int createdAtMs;
  final int loves;
  final int comments;
  final int views;
  final int gifts;
  final List<String> lovedBy;
  final List<String> viewedBy;
  final Map<String, dynamic> raw;

  const NewsArticle({
    required this.id,
    required this.agentKey,
    required this.category,
    required this.level,
    required this.country,
    required this.continent,
    required this.title,
    required this.chapo,
    required this.sections,
    required this.retenir,
    required this.sources,
    required this.image,
    required this.createdAtMs,
    required this.loves,
    required this.comments,
    required this.views,
    required this.gifts,
    required this.lovedBy,
    required this.viewedBy,
    required this.raw,
  });

  NewsAgentInfo get agent => newsAgentOf(agentKey);

  bool lovedByUser(String? uid) => uid != null && lovedBy.contains(uid);

  factory NewsArticle.fromDoc(String id, Map<String, dynamic> d) {
    final n = (d['news'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    int toInt(dynamic v) => (v as num?)?.toInt() ?? 0;
    List<String> strings(dynamic v) => ((v as List?) ?? const []).map((e) => e.toString()).toList();
    final created = toInt(d['created_at']);
    return NewsArticle(
      id: id,
      agentKey: (n['agentKey'] ?? '').toString(),
      category: (n['category'] ?? '').toString(),
      level: (n['level'] ?? 'world').toString(),
      country: n['country']?.toString(),
      continent: n['continent']?.toString(),
      title: (n['title'] ?? '').toString(),
      chapo: (n['chapo'] ?? d['description'] ?? '').toString(),
      sections: ((n['sections'] as List?) ?? const [])
          .map((e) => NewsSection(((e as Map)['titre'] ?? '').toString(), (e['texte'] ?? '').toString()))
          .toList(),
      retenir: strings(n['retenir']),
      sources: ((n['sources'] as List?) ?? const []).map((e) => NewsSource(((e as Map)['name'] ?? '').toString(), (e['url'] ?? '').toString())).toList(),
      image: (d['url_media'] ?? '').toString(),
      createdAtMs: created > 1e14 ? created ~/ 1000 : created, // created_at est en microsecondes
      loves: toInt(d['loves']),
      comments: toInt(d['comments']),
      views: toInt(d['vues']),
      gifts: toInt(d['giftCount']),
      lovedBy: strings(d['users_love_id']),
      viewedBy: strings(d['users_vue_id']),
      raw: d,
    );
  }
}

/// « il y a 3 h » : durée écoulée, en français court.
String newsAgo(int ms) {
  final diff = DateTime.now().millisecondsSinceEpoch - ms;
  if (diff < 60 * 1000) return 'à l\'instant';
  final min = diff ~/ 60000;
  if (min < 60) return 'il y a $min min';
  final h = min ~/ 60;
  if (h < 24) return 'il y a $h h';
  final d = h ~/ 24;
  return d == 1 ? 'hier' : 'il y a $d j';
}

/// Nombre court : 1 234 → « 1,2 k ».
String newsCount(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1).replaceAll('.', ',')} M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1).replaceAll('.', ',')} k';
  return '$n';
}
