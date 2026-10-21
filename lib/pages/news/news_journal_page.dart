import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../ads/admob_widgets.dart';
import '../../l10n/tr.dart';
import '../../layout/centered_content.dart';
import '../../models/news_article.dart';
import '../../models/news_digest.dart';
import '../../providers/authProvider.dart';
import '../../services/news/news_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/country_continent.dart';
import '../../utils/country_names.dart';
import '../../widgets/news/news_list_widgets.dart';
import 'news_detail_page.dart';

/// « Mon journal » : tout ce qui se passe dans le pays de la personne, son continent et le monde, en trois niveaux.
/// Trois vues : Jour (les articles du moment, puis les résumés des jours précédents), Semaine et Mois (les infos les plus importantes de la période).
/// Filtres par domaine. Un résumé garde sa propre copie des articles : il reste lisible quand l'article d'origine a disparu.
class NewsJournalPage extends StatefulWidget {
  const NewsJournalPage({super.key});

  @override
  State<NewsJournalPage> createState() => _NewsJournalPageState();
}

enum _Scope { country, continent, world, other }

class _NewsJournalPageState extends State<NewsJournalPage> {
  final _svc = NewsService.instance;

  _Scope _scope = _Scope.continent;
  String _userCountry = '';
  String _otherCountry = '';
  List<String> _countries = [];
  String _period = 'day'; // day | week | month
  String _periodKey = '';
  String? _cat;

  bool _loading = true;
  List<NewsFeedItem> _live = [];
  NewsDigest? _digest;

  @override
  void initState() {
    super.initState();
    _periodKey = NewsPeriods.days().first.key;
    _init();
  }

  Future<void> _init() async {
    final cfg = await _svc.loadConfig();
    if (!mounted) return;
    final code = (context.read<UserAuthProvider>().loginUserData.countryData?['countryCode'] ?? '').toString().toUpperCase();
    setState(() {
      _userCountry = code;
      _countries = cfg.countries;
      _scope = _countries.contains(code) ? _Scope.country : _Scope.continent;
    });
    await _load();
  }

  String get _continent => continentOfCountry(_userCountry) ?? 'AF';

  String get _scopeKey {
    switch (_scope) {
      case _Scope.country:
        return 'country_$_userCountry';
      case _Scope.other:
        return 'country_$_otherCountry';
      case _Scope.continent:
        return 'continent_$_continent';
      case _Scope.world:
        return 'world';
    }
  }

  String get _scopeLabel {
    switch (_scope) {
      case _Scope.country:
        return countryName(_userCountry);
      case _Scope.other:
        return countryName(_otherCountry);
      case _Scope.continent:
        return newsContinentName(_continent);
      case _Scope.world:
        return 'le monde';
    }
  }

  List<PeriodChoice> get _choices => _period == 'day' ? NewsPeriods.days() : _period == 'week' ? NewsPeriods.weeks() : NewsPeriods.months();
  bool get _isLive => _period == 'day' && _periodKey == NewsPeriods.days().first.key;

  Future<void> _load({bool fresh = false}) async {
    setState(() => _loading = true);
    if (fresh) _svc.clearCache();
    if (_isLive) {
      final items = await _svc.liveScope(_scopeKey, fresh: fresh);
      if (!mounted) return;
      setState(() {
        _live = items;
        _digest = null;
        _loading = false;
      });
    } else {
      final d = await _svc.digest(_scopeKey, _period, _periodKey, fresh: fresh);
      if (!mounted) return;
      setState(() {
        _digest = d;
        _live = [];
        _loading = false;
      });
    }
  }

  void _setPeriod(String p) {
    if (_period == p) return;
    setState(() {
      _period = p;
      _periodKey = _choices.first.key;
    });
    _load();
  }

  void _setScope(_Scope s, {String? other}) {
    setState(() {
      _scope = s;
      if (other != null) _otherCountry = other;
    });
    _load();
  }

  /// Niveau plus large que l'actuel (pays → continent → monde), pour ne jamais rester sur une page vide.
  _Scope? get _broader => (_scope == _Scope.country || _scope == _Scope.other) ? _Scope.continent : _scope == _Scope.continent ? _Scope.world : null;

  Future<void> _openDigestItem(NewsDigestItem item) async {
    final alive = await _svc.article(item.id);
    if (!mounted) return;
    if (alive != null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => NewsDetailPage(postId: item.id)));
    } else {
      showDigestItemSheet(context, item);
    }
  }

  // ── éléments d'interface ──
  Widget _pill(AppColors c, String label, bool selected, VoidCallback onTap, {Color? color, IconData? trailing}) {
    final base = color ?? c.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? base : c.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
          border: selected ? null : Border.all(color: c.border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: TextStyle(color: selected ? c.onPrimary : c.textSecondary, fontWeight: FontWeight.w600, fontSize: 12.5)),
          if (trailing != null) ...[const SizedBox(width: 2), Icon(trailing, size: 16, color: selected ? c.onPrimary : c.textSecondary)],
        ]),
      ),
    );
  }

  Widget _scopeRow(AppColors c) {
    final others = _countries.where((x) => x != _userCountry).toList();
    return SizedBox(
      height: 38,
      child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), children: [
        if (_countries.contains(_userCountry))
          _pill(c, '${countryFlag(_userCountry)} ${countryName(_userCountry)}', _scope == _Scope.country, () => _setScope(_Scope.country)),
        _pill(c, newsContinentName(_continent), _scope == _Scope.continent, () => _setScope(_Scope.continent)),
        _pill(c, context.tr('Monde'), _scope == _Scope.world, () => _setScope(_Scope.world)),
        if (others.isNotEmpty)
          PopupMenuButton<String>(
            onSelected: (code) => _setScope(_Scope.other, other: code),
            itemBuilder: (_) => [for (final code in others) PopupMenuItem(value: code, child: Text('${countryFlag(code)} ${countryName(code)}'))],
            child: IgnorePointer(
              child: _pill(
                c,
                _scope == _Scope.other ? '${countryFlag(_otherCountry)} ${countryName(_otherCountry)}' : context.tr('Un autre pays'),
                _scope == _Scope.other,
                () {},
                trailing: Icons.arrow_drop_down_rounded,
              ),
            ),
          ),
      ]),
    );
  }

  Widget _periodTabs(AppColors c) {
    Widget tab(String p, String label) => Expanded(
          child: GestureDetector(
            onTap: () => _setPeriod(p),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 9),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _period == p ? c.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(label, style: TextStyle(color: _period == p ? c.onPrimary : c.textSecondary, fontWeight: FontWeight.w700, fontSize: 13)),
            ),
          ),
        );
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: c.surfaceVariant, borderRadius: BorderRadius.circular(24), border: Border.all(color: c.border)),
      child: Row(children: [tab('day', context.tr('Jour')), tab('week', context.tr('Semaine')), tab('month', context.tr('Mois'))]),
    );
  }

  Widget _choiceRow(AppColors c) => SizedBox(
        height: 36,
        child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), children: [
          for (final ch in _choices)
            _pill(c, context.tr(ch.label), _periodKey == ch.key, () {
              setState(() => _periodKey = ch.key);
              _load();
            }),
        ]),
      );

  Widget _categoryRow(AppColors c) => SizedBox(
        height: 36,
        child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), children: [
          _pill(c, context.tr('Tout'), _cat == null, () => setState(() => _cat = null), color: c.textPrimary),
          for (final a in kNewsAgents) _pill(c, context.tr(a.label), _cat == a.category, () => setState(() => _cat = a.category), color: a.color(c)),
        ]),
      );

  // ── contenu ──
  List<Widget> _liveContent(AppColors c) {
    final now = DateTime.now().millisecondsSinceEpoch;
    var items = _live.where((i) => _cat == null || i.category == _cat).toList();
    if (items.isEmpty) {
      final b = _broader;
      return [
        NewsEmpty(
          message: _live.isEmpty ? context.tr('Aucune actualité pour {lieu} pour le moment.', {'lieu': _scopeLabel}) : context.tr('Aucune actualité dans ce domaine.'),
          hint: context.tr('De nouveaux articles arrivent tout au long de la journée.'),
          action: _live.isEmpty && b != null ? context.tr(b == _Scope.continent ? 'Voir {lieu}' : 'Voir le monde', {'lieu': newsContinentName(_continent)}) : null,
          onAction: b == null ? null : () => _setScope(b),
        ),
      ];
    }
    final today = items.where((i) => now - i.at < 24 * 3600 * 1000).toList();
    final recentOnly = today.isNotEmpty;
    if (recentOnly) items = today;
    NewsFeedItem top = items.reduce((a, b) => (b.score > a.score || (b.score == a.score && b.at > a.at)) ? b : a);
    final rest = items.where((i) => i.id != top.id).toList()..sort((a, b) => b.at.compareTo(a.at));
    final out = <Widget>[
      if (!recentOnly)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(context.tr('Pas de nouveauté depuis 24 h : voici les dernières actualités.'), style: TextStyle(color: c.textSecondary, fontSize: 12)),
        ),
      NewsTopCard(
        badge: context.tr('À la une'),
        agent: newsAgentOf(top.agentKey),
        title: top.title,
        chapo: top.chapo,
        image: top.image,
        meta: '${newsAgentOf(top.agentKey).pseudo} · ${newsAgo(top.at)} · ${newsLevelLabel(top.level, top.country, top.continent)}',
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NewsDetailPage(postId: top.id))),
      ),
    ];
    for (var i = 0; i < rest.length; i++) {
      final it = rest[i];
      final agent = newsAgentOf(it.agentKey);
      out.add(NewsListTile(
        agent: agent,
        title: it.title,
        image: it.image,
        meta: '${context.tr(agent.label)} · ${agent.pseudo} · ${newsAgo(it.at)}',
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NewsDetailPage(postId: it.id))),
      ));
      if (i == 2 || i == 8) out.add(AdmobNativeWidget(key: ValueKey('journal_native_$i'))); // pub native (rien pour Gold ou sans pub prête)
    }
    return out;
  }

  List<Widget> _digestContent(AppColors c) {
    final d = _digest;
    final choice = _choices.firstWhere((x) => x.key == _periodKey, orElse: () => _choices.first);
    final isCurrent = _choices.first.key == _periodKey;
    if (d == null) {
      final b = _broader;
      return [
        NewsEmpty(
          message: context.tr('Pas encore de résumé pour cette période.'),
          hint: isCurrent
              ? context.tr(_period == 'week' ? 'Le résumé de la semaine paraît le dimanche soir.' : _period == 'month' ? 'Le résumé du mois paraît le dernier jour du mois.' : 'Le résumé du jour paraît en fin de journée.')
              : context.tr('Aucun article n\'a été retenu pour {lieu} à cette période.', {'lieu': _scopeLabel}),
          action: b != null ? context.tr(b == _Scope.continent ? 'Voir {lieu}' : 'Voir le monde', {'lieu': newsContinentName(_continent)}) : null,
          onAction: b == null ? null : () => _setScope(b),
        ),
      ];
    }
    final items = d.items.where((i) => _cat == null || i.category == _cat).toList();
    final title = _period == 'day' ? 'Les infos du jour' : _period == 'week' ? 'Les infos de la semaine' : 'Les infos du mois';
    final out = <Widget>[NewsDigestHeader(title: context.tr(title), range: context.tr(choice.label), intro: d.intro)];
    if (items.isEmpty) out.add(NewsEmpty(message: context.tr('Aucune info dans ce domaine pour cette période.')));
    for (var i = 0; i < items.length; i++) {
      final it = items[i];
      out.add(NewsListTile(
        agent: it.agent,
        title: it.title,
        image: it.image,
        rank: i + 1,
        meta: '${it.agent.pseudo} · ${newsAgo(it.at)} · ${context.tr('Résumé de {n} sources', {'n': it.sourceCount})}',
        onTap: () => _openDigestItem(it),
      ));
      if (i == 2) out.add(const AdmobNativeWidget(key: ValueKey('journal_native_digest')));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.surface,
        foregroundColor: c.textPrimary,
        title: Text(context.tr('Mon journal')),
      ),
      body: CenteredContent(
        child: RefreshIndicator(
          color: c.primary,
          onRefresh: () => _load(fresh: true),
          child: ListView(padding: const EdgeInsets.only(top: 10, bottom: 30), children: [
            _scopeRow(c),
            const SizedBox(height: 8),
            _periodTabs(c),
            _choiceRow(c),
            const SizedBox(height: 8),
            _categoryRow(c),
            const SizedBox(height: 12),
            if (_loading)
              Padding(padding: const EdgeInsets.symmetric(vertical: 60), child: Center(child: CircularProgressIndicator(color: c.primary)))
            else
              ..._isLive ? _liveContent(c) : _digestContent(c),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Text(
                context.tr('Chaque article est un résumé de plusieurs sources, citées en bas de l\'article.'),
                textAlign: TextAlign.center,
                style: TextStyle(color: c.textSecondary, fontSize: 11.5, height: 1.35),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
