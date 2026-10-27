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

/// Article d'actualité en page entière, pour les fils verticaux plein écran (Vibe, Chroniques) : photo plein cadre, titre en grand, résumé,
/// signature de l'agent, boutons « Lire l'article » et « Voir plus d'actualités », et la colonne d'actions (j'aime, commentaires, cadeau) à droite,
/// à l'image d'une vidéo. Même règle de vues que la carte du fil : visible une seconde = une vue, un j'aime = une vue.
/// [onEmpty] : appelée quand aucun article n'est disponible, pour que le fil passe à la page suivante au lieu de rester vide.
class NewsFullPage extends StatefulWidget {
  const NewsFullPage({super.key, required this.slotKey, this.onEmpty, this.onOpenStart, this.onOpenEnd, this.bottomInset = 0});
  final String slotKey;
  final VoidCallback? onEmpty;

  /// Appelées avant et après l'ouverture d'un écran par-dessus la page (article, commentaires, cadeau) : un fil qui défile tout seul se met en pause.
  final VoidCallback? onOpenStart;
  final VoidCallback? onOpenEnd;

  /// Espace à laisser en bas (bannière de pub, barre de navigation).
  final double bottomInset;

  @override
  State<NewsFullPage> createState() => _NewsFullPageState();
}

class _NewsFullPageState extends State<NewsFullPage> {
  NewsFeedItem? _item;
  NewsArticle? _article;
  bool _ready = false;
  bool _liked = false;
  int _loves = 0;
  bool _extraView = false;
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

  Future<void> _load() async {
    final svc = NewsService.instance;
    final cfg = await svc.loadConfig();
    if (!cfg.enabled || !cfg.feedEnabled || !mounted) return _empty();
    final user = context.read<UserAuthProvider>().loginUserData;
    final item = await svc.pickForSlot(slotKey: widget.slotKey, country: user.countryData?['countryCode']);
    if (!mounted) return;
    if (item == null) return _empty();
    setState(() {
      _item = item;
      _ready = true;
    });
    final a = await svc.article(item.id);
    if (!mounted || a == null) return;
    setState(() {
      _article = a;
      _liked = a.lovedByUser(user.id);
      _loves = a.loves;
    });
    if (_visible) _viewTimer = Timer(const Duration(seconds: 1), _countView);
  }

  void _empty() {
    if (mounted) setState(() => _ready = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onEmpty?.call();
    });
  }

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

  Future<void> _like() async {
    final a = _article;
    if (a == null || _liked) return;
    setState(() {
      _liked = true;
      _loves += 1;
    });
    _viewTimer?.cancel();
    _visible = true;
    _countView();
    if (!await NewsService.instance.like(a.id) && mounted) {
      setState(() {
        _liked = false;
        _loves -= 1;
      });
    }
  }

  Future<void> _around(Future<void> Function() action) async {
    widget.onOpenStart?.call();
    try {
      await action();
    } finally {
      widget.onOpenEnd?.call();
    }
  }

  Future<void> _open() async {
    final item = _item;
    if (item == null) return;
    await _around(() => Navigator.push(context, MaterialPageRoute(builder: (_) => NewsDetailPage(postId: item.id))));
  }

  @override
  Widget build(BuildContext context) {
    final item = _item;
    final c = AppColors.of(context);
    if (!_ready || item == null) {
      return Container(color: const Color(0xFF111111), child: const Center(child: CircularProgressIndicator(color: Colors.white54)));
    }
    final agent = newsAgentOf(item.agentKey);
    final a = _article;
    return VisibilityDetector(
      key: Key('news-full-${widget.slotKey}-${item.id}'),
      onVisibilityChanged: _onVisibility,
      child: GestureDetector(
        onTap: _open,
        child: Container(
          color: const Color(0xFF111111),
          child: Stack(fit: StackFit.expand, children: [
            if (item.image.isNotEmpty)
              CachedNetworkImage(
                imageUrl: item.image,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: const Color(0xFF1C1C1C)),
                errorWidget: (_, __, ___) => Container(color: const Color(0xFF1C1C1C), child: Icon(agent.icon, size: 96, color: Colors.white12)),
              )
            else
              Container(color: const Color(0xFF1C1C1C), child: Icon(agent.icon, size: 96, color: Colors.white12)),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x99000000), Color(0x00000000), Color(0xE6000000)], stops: [0, 0.35, 0.95]),
              ),
            ),
            // bandeau du haut
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: Colors.black.withOpacity(0.55), borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.white24)),
                      child: Text(context.tr('ACTUALITÉ'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1.6)),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(newsLevelLabel(item.level, item.country, item.continent).toUpperCase(),
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700, fontSize: 11.5, letterSpacing: 0.8)),
                    ),
                  ]),
                ),
              ),
            ),
            // texte en bas à gauche
            Positioned(
              left: 16,
              right: 78,
              bottom: 18 + widget.bottomInset,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(item.title, maxLines: 4, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontFamily: 'serif', fontWeight: FontWeight.w800, fontSize: 24, height: 1.2)),
                const SizedBox(height: 8),
                Text(item.chapo, maxLines: 4, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4)),
                const SizedBox(height: 12),
                Row(children: [
                  AgentAvatar(agent: agent, size: 28),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('${agent.pseudo}  ·  ${newsAgo(item.at)}${newsLeftTag(item.exp)}  ·  ${context.tr('Résumé de {n} sources', {'n': item.sourceCount})}',
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ),
                ]),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _open,
                      icon: const Icon(Icons.article_outlined, size: 18),
                      label: Text(context.tr('Lire l\'article')),
                      style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () => NewsMoreButton.openJournal(context),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white54), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    child: Text(context.tr('Voir plus d\'actualités'), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                  ),
                ]),
              ]),
            ),
            // colonne d'actions à droite
            Positioned(
              right: 10,
              bottom: 22 + widget.bottomInset,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                _rail(_liked ? Icons.favorite_rounded : Icons.favorite_border_rounded, newsCount(_loves), _like, color: _liked ? c.danger : Colors.white),
                _rail(Icons.chat_bubble_outline_rounded, newsCount(a?.comments ?? 0), a == null ? null : () => _around(() => NewsActions.comments(context, a))),
                _rail(Icons.card_giftcard_rounded, context.tr('Cadeau'), a == null ? null : () => _around(() => NewsActions.gift(context, a)), color: c.warning),
                _rail(Icons.visibility_outlined, newsCount(_views), null),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _rail(IconData icon, String label, VoidCallback? onTap, {Color color = Colors.white}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 30, color: color, shadows: const [Shadow(color: Colors.black54, blurRadius: 6)]),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700, shadows: [Shadow(color: Colors.black54, blurRadius: 6)])),
        ]),
      ),
    );
  }
}
