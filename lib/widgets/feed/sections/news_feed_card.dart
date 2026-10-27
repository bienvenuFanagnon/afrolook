import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../../l10n/tr.dart';
import '../../../models/news_article.dart';
import '../../../pages/news/news_detail_page.dart';
import '../../../providers/authProvider.dart';
import '../../../services/news/news_service.dart';
import '../../../theme/app_colors.dart';
import '../../news/news_widgets.dart';

/// Carte d'actualité dans le fil : un résumé de plusieurs sources, avec le pseudo de l'agent et son badge, le niveau (pays, continent, monde),
/// les sources et les actions (j'aime, commentaires, cadeau). Un toucher ouvre la page de détail.
/// Quatre présentations qui alternent (A « La une », B « Photo plein cadre », C « Brève compacte », D « Flash info »), choisies d'après
/// l'emplacement dans le fil et le jour : un même article garde le même aspect pendant la journée, et le fil change d'un jour à l'autre.
/// Jamais montrée tant que `AppConfig/news.feedEnabled` n'est pas actif. La croix la masque jusqu'à demain.
/// [slotKey] : emplacement dans le fil (le même article revient au même emplacement) ; [category] : domaine imposé (page Sport : « sport »).
class NewsFeedCard extends StatefulWidget {
  const NewsFeedCard({super.key, required this.slotKey, this.category, this.postId, this.item, this.onOpen, this.showClose = true, this.showMore = true});
  final String slotKey;
  final String? category;

  /// Article précis à montrer (un post d'actualité rencontré dans une liste de posts) : pas de choix automatique, pas de réglage du fil.
  final String? postId;

  /// Article déjà connu (page « Mon journal ») : pas de choix automatique dans le fil, pas de réglage du fil.
  final NewsFeedItem? item;

  /// Remplace l'ouverture de la page de détail (résumés de semaine ou de mois : l'article d'origine peut avoir disparu).
  final VoidCallback? onOpen;

  /// Croix « masquer jusqu'à demain » (fil) et bouton « Voir plus d'actualités » : cachés dans le journal, qui est déjà la page des actualités.
  final bool showClose;
  final bool showMore;

  @override
  State<NewsFeedCard> createState() => _NewsFeedCardState();
}

class _NewsFeedCardState extends State<NewsFeedCard> {
  NewsFeedItem? _item;
  NewsArticle? _article;
  bool _ready = false;
  bool _hidden = false;
  bool _liked = false;
  int _loves = 0;
  bool _extraView = false; // la vue de cette personne vient d'être comptée : le compteur affiché monte de 1
  bool _visible = false;
  Timer? _viewTimer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _viewTimer?.cancel();
    super.dispose();
  }

  int get _views => (_article?.views ?? 0) + (_extraView ? 1 : 0);

  /// Une vue = la carte est visible à l'écran (au moins la moitié) pendant 1 seconde. Comptée une fois par personne et par article.
  void _onVisibility(VisibilityInfo info) {
    _visible = info.visibleFraction >= 0.5;
    _viewTimer?.cancel();
    if (_visible) _viewTimer = Timer(const Duration(seconds: 1), _countView);
  }

  Future<void> _countView() async {
    final a = _article;
    if (!mounted || !_visible || a == null || _extraView) return;
    if (await NewsService.instance.recordView(a) && mounted) setState(() => _extraView = true);
  }

  Future<void> _load() async {
    final svc = NewsService.instance;
    final preset = widget.item;
    if (preset != null) {
      setState(() {
        _item = preset;
        _ready = true;
      });
      final a = await svc.article(preset.id);
      if (!mounted || a == null) return;
      final uid = context.read<UserAuthProvider>().loginUserData.id;
      setState(() {
        _article = a;
        _liked = a.lovedByUser(uid);
        _loves = a.loves;
      });
      if (_visible) _viewTimer = Timer(const Duration(seconds: 1), _countView);
      return;
    }
    final fixed = widget.postId;
    if (fixed != null) {
      final a = await svc.article(fixed);
      if (!mounted) return;
      final uid = context.read<UserAuthProvider>().loginUserData.id;
      setState(() {
        _article = a;
        _item = a == null ? null : newsFeedItemOf(a);
        _liked = a?.lovedByUser(uid) ?? false;
        _loves = a?.loves ?? 0;
        _ready = true;
      });
      if (_visible) _viewTimer = Timer(const Duration(seconds: 1), _countView);
      return;
    }
    final cfg = await svc.loadConfig();
    if (!cfg.enabled || !cfg.feedEnabled || await svc.hiddenToday()) {
      if (mounted) setState(() => _ready = true);
      return;
    }
    if (!mounted) return;
    final user = context.read<UserAuthProvider>().loginUserData;
    final item = await svc.pickForSlot(slotKey: widget.slotKey, country: user.countryData?['countryCode'], category: widget.category);
    if (!mounted) return;
    setState(() {
      _item = item;
      _ready = true;
    });
    if (item == null) return;
    final a = await svc.article(item.id);
    if (!mounted || a == null) return;
    setState(() {
      _article = a;
      _liked = a.lovedByUser(user.id);
      _loves = a.loves;
    });
    if (_visible) _viewTimer = Timer(const Duration(seconds: 1), _countView); // carte déjà à l'écran avant l'arrivée de l'article
  }

  Future<void> _open() async {
    final item = _item;
    if (item == null) return;
    if (widget.onOpen != null) return widget.onOpen!();
    await Navigator.push(context, MaterialPageRoute(builder: (_) => NewsDetailPage(postId: item.id)));
  }

  Future<void> _like() async {
    final a = _article;
    if (a == null || _liked) return;
    setState(() {
      _liked = true;
      _loves += 1;
    });
    _viewTimer?.cancel();
    _visible = true; // un j'aime depuis le fil prouve que la carte est vue : la vue est comptée tout de suite
    _countView();
    final ok = await NewsService.instance.like(a.id);
    if (!ok && mounted) {
      setState(() {
        _liked = false;
        _loves -= 1;
      });
    }
  }

  Future<void> _close() async {
    if (widget.postId == null) await NewsService.instance.hideUntilTomorrow(); // la croix du fil masque toutes les cartes jusqu'à demain
    if (mounted) setState(() => _hidden = true);
  }

  /// 0 = A, 1 = B, 2 = C, 3 = D (seulement si l'article a un score élevé). Dépend de l'emplacement, de l'article et du jour : stable pendant la journée, différent le lendemain.
  int _variant(NewsFeedItem item) {
    final day = DateTime.now().difference(DateTime(2026)).inDays;
    var h = 0;
    for (final u in '${widget.slotKey}|${item.id}'.codeUnits) {
      h = (h * 31 + u) & 0x7fffffff;
    }
    // Flash info réservé aux grosses actualités (même seuil que l'alerte « À la une ») ; les autres alternent entre A, B et C
    if (item.score >= _flashMinScore) return (h + day) % 4;
    return (h + day) % 3;
  }

  static const _flashMinScore = 16;

  @override
  Widget build(BuildContext context) {
    final item = _item;
    if (!_ready || _hidden || item == null) return const SizedBox.shrink();
    final c = AppColors.of(context);
    final Widget body;
    switch (_variant(item)) {
      case 1:
        body = _photoFull(c, item);
        break;
      case 2:
        body = _compact(c, item);
        break;
      case 3:
        body = _flash(c, item);
        break;
      default:
        body = _lead(c, item);
    }
    return VisibilityDetector(
      key: Key('news-card-${widget.slotKey}-${item.id}'),
      onVisibilityChanged: _onVisibility,
      child: GestureDetector(
        onTap: _open,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: c.border),
          ),
          child: body,
        ),
      ),
    );
  }

  // ── Éléments communs ─────────────────────────────────────────────────────

  String _place(NewsFeedItem item) => newsLevelLabel(item.level, item.country, item.continent);

  Widget _more() => widget.showMore ? const NewsMoreButton() : const SizedBox.shrink();

  Widget _closeButton(AppColors c, {Color? color}) => !widget.showClose
      ? const SizedBox(height: 26)
      : InkWell(
        onTap: _close,
        customBorder: const CircleBorder(),
        child: Padding(padding: const EdgeInsets.all(4), child: Icon(Icons.close_rounded, size: 18, color: color ?? c.textSecondary)),
      );

  Widget _photo(AppColors c, NewsFeedItem item, double height, {double radius = 0}) {
    if (item.image.isEmpty) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: CachedNetworkImage(
        imageUrl: item.image,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(height: height, color: c.shimmerBase),
        errorWidget: (_, __, ___) => Container(height: height * 0.5, color: c.surfaceVariant, child: Icon(Icons.image_not_supported_outlined, color: c.textSecondary)),
      ),
    );
  }

  Widget _title(AppColors c, String text, double size, {Color? color}) =>
      Text(text, style: TextStyle(color: color ?? c.textPrimary, fontFamily: 'serif', fontWeight: FontWeight.w800, fontSize: size, height: 1.25));

  Widget _byline(AppColors c, NewsFeedItem item, {bool sources = true}) {
    final agent = newsAgentOf(item.agentKey);
    final srcLabel = context.tr('Résumé de {n} sources', {'n': item.sourceCount});
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        AgentAvatar(agent: agent, size: 24),
        const SizedBox(width: 8),
        Expanded(
          child: Text.rich(
            TextSpan(children: [
              TextSpan(text: agent.pseudo, style: TextStyle(color: agent.color(c), fontWeight: FontWeight.w800)),
              TextSpan(text: '  ·  ${newsAgo(item.at)}${newsLeftTag(item.exp)}'),
            ]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: c.textSecondary, fontSize: 12),
          ),
        ),
      ]),
      if (sources) ...[
        const SizedBox(height: 8),
        Row(children: [
          Icon(Icons.link_rounded, size: 14, color: c.info),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              item.sourceNames.isEmpty ? srcLabel : '$srcLabel : ${item.sourceNames.join(', ')}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: c.info, fontSize: 11.5, fontWeight: FontWeight.w600),
            ),
          ),
        ]),
      ],
    ]);
  }

  Widget _stats(AppColors c) {
    final a = _article;
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      _stat(c, Icons.visibility_outlined, newsCount(_views), null, c.textSecondary),
      _stat(c, _liked ? Icons.favorite_rounded : Icons.favorite_border_rounded, newsCount(_loves), _like, _liked ? c.danger : c.textSecondary),
      _stat(c, Icons.chat_bubble_outline_rounded, newsCount(a?.comments ?? 0), a == null ? null : () => NewsActions.comments(context, a), c.textSecondary),
      _stat(c, Icons.card_giftcard_rounded, context.tr('Cadeau'), a == null ? null : () => NewsActions.gift(context, a), c.warning),
    ]);
  }

  // ── A : La une (sobre, style presse) ─────────────────────────────────────

  Widget _lead(AppColors c, NewsFeedItem item) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(context.tr('ACTUALITÉ'), style: TextStyle(color: c.primary, fontWeight: FontWeight.w900, fontSize: 11.5, letterSpacing: 1.4)),
          const SizedBox(width: 6),
          Expanded(child: Text('· ${_place(item).toUpperCase()}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textSecondary, fontSize: 11, fontWeight: FontWeight.w600))),
          _closeButton(c),
        ]),
        const SizedBox(height: 6),
        _photo(c, item, 160, radius: 8),
        if (item.image.isNotEmpty) const SizedBox(height: 10),
        _title(c, item.title, 17.5),
        const SizedBox(height: 6),
        Text(item.chapo, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textSecondary, fontSize: 13, height: 1.4)),
        const SizedBox(height: 10),
        _byline(c, item),
        const SizedBox(height: 8),
        Divider(color: c.border, height: 1),
        const SizedBox(height: 4),
        _stats(c),
        const SizedBox(height: 8),
        _more(),
      ]),
    );
  }

  // ── B : Photo plein cadre (le titre sur la photo) ────────────────────────

  Widget _photoFull(AppColors c, NewsFeedItem item) {
    final agent = newsAgentOf(item.agentKey);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
        height: 220,
        child: Stack(fit: StackFit.expand, children: [
          if (item.image.isNotEmpty)
            CachedNetworkImage(
              imageUrl: item.image,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(color: c.shimmerBase),
              errorWidget: (_, __, ___) => Container(color: const Color(0xFF2C2C2A), child: Icon(agent.icon, size: 56, color: Colors.white24)),
            )
          else
            Container(color: const Color(0xFF2C2C2A), child: Icon(agent.icon, size: 56, color: Colors.white24)),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withOpacity(0.85)], stops: const [0.35, 1]),
              ),
            ),
          ),
          Positioned(
            top: 10,
            left: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(6)),
              child: Text('${context.tr('ACTUALITÉ')} · ${_place(item).toUpperCase()}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 10.5, letterSpacing: 0.8)),
            ),
          ),
          if (widget.showClose)
            Positioned(
              top: 6,
              right: 6,
              child: Container(decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), shape: BoxShape.circle), child: _closeButton(c, color: Colors.white)),
            ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 10,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              _title(c, item.title, 18, color: Colors.white),
              const SizedBox(height: 4),
              Text('${agent.pseudo}  ·  ${newsAgo(item.at)}${newsLeftTag(item.exp)}  ·  ${context.tr('Résumé de {n} sources', {'n': item.sourceCount})}',
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 11.5)),
            ]),
          ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Column(children: [
          _stats(c),
          const SizedBox(height: 8),
          _more(),
        ]),
      ),
    ]);
  }

  // ── C : Brève compacte (barre colorée, miniature) ────────────────────────

  Widget _compact(AppColors c, NewsFeedItem item) {
    final agent = newsAgentOf(item.agentKey);
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(width: 4, color: agent.color(c)),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 10, 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(context.tr('ACTUALITÉ'), style: TextStyle(color: agent.color(c), fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1.3)),
                const SizedBox(width: 6),
                Expanded(child: Text('· ${_place(item).toUpperCase()}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textSecondary, fontSize: 10.5, fontWeight: FontWeight.w600))),
                _closeButton(c),
              ]),
              const SizedBox(height: 4),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(item.title, maxLines: 4, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textPrimary, fontFamily: 'serif', fontWeight: FontWeight.w800, fontSize: 15, height: 1.25)),
                    const SizedBox(height: 6),
                    Text('${agent.pseudo}  ·  ${newsAgo(item.at)}${newsLeftTag(item.exp)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textSecondary, fontSize: 11.5)),
                  ]),
                ),
                if (item.image.isNotEmpty) ...[
                  const SizedBox(width: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: item.image,
                      width: 88,
                      height: 88,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(width: 88, height: 88, color: c.shimmerBase),
                      errorWidget: (_, __, ___) => Container(width: 88, height: 88, color: c.surfaceVariant, child: Icon(agent.icon, color: c.textSecondary)),
                    ),
                  ),
                ],
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: Row(children: [
                    Icon(Icons.visibility_outlined, size: 15, color: c.textSecondary),
                    const SizedBox(width: 3),
                    Text(newsCount(_views), style: TextStyle(color: c.textSecondary, fontSize: 11.5, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 12),
                    InkWell(
                      onTap: _like,
                      child: Row(children: [
                        Icon(_liked ? Icons.favorite_rounded : Icons.favorite_border_rounded, size: 15, color: _liked ? c.danger : c.textSecondary),
                        const SizedBox(width: 3),
                        Text(newsCount(_loves), style: TextStyle(color: _liked ? c.danger : c.textSecondary, fontSize: 11.5, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.chat_bubble_outline_rounded, size: 15, color: c.textSecondary),
                    const SizedBox(width: 3),
                    Text(newsCount(_article?.comments ?? 0), style: TextStyle(color: c.textSecondary, fontSize: 11.5, fontWeight: FontWeight.w600)),
                  ]),
                ),
                if (widget.showMore)
                  InkWell(
                  onTap: () => NewsMoreButton.openJournal(context),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(context.tr('Voir plus d\'actualités'), style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 12)),
                      const SizedBox(width: 2),
                      Icon(Icons.arrow_forward_rounded, size: 15, color: c.textPrimary),
                    ]),
                  ),
                ),
              ]),
            ]),
          ),
        ),
      ]),
    );
  }

  // ── D : Flash info (bandeau sombre) ──────────────────────────────────────

  Widget _flash(AppColors c, NewsFeedItem item) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        color: const Color(0xFF2C2C2A),
        padding: const EdgeInsets.fromLTRB(12, 4, 6, 4),
        child: Row(children: [
          Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFFE24B4A), shape: BoxShape.circle)),
          const SizedBox(width: 7),
          Text(context.tr('FLASH ACTUALITÉ'), style: const TextStyle(color: Color(0xFFF1EFE8), fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1.3)),
          const SizedBox(width: 8),
          Expanded(
            child: Text('${_place(item).toUpperCase()} · ${newsAgo(item.at)}${newsLeftTag(item.exp)}', maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.right, style: const TextStyle(color: Color(0xFFB4B2A9), fontSize: 10.5, fontWeight: FontWeight.w600)),
          ),
          _closeButton(c, color: const Color(0xFFB4B2A9)),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _title(c, item.title, 18.5),
          const SizedBox(height: 6),
          Text(item.chapo, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textSecondary, fontSize: 13, height: 1.4)),
          if (item.image.isNotEmpty) ...[
            const SizedBox(height: 10),
            _photo(c, item, 110, radius: 8),
          ],
          const SizedBox(height: 10),
          _byline(c, item, sources: false),
          const SizedBox(height: 8),
          Divider(color: c.border, height: 1),
          const SizedBox(height: 4),
          _stats(c),
          const SizedBox(height: 8),
          _more(),
        ]),
      ),
    ]);
  }

  Widget _stat(AppColors c, IconData icon, String label, VoidCallback? onTap, Color color) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}
