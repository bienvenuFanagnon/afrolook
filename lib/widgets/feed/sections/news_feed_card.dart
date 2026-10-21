import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../l10n/tr.dart';
import '../../../models/news_article.dart';
import '../../../pages/news/news_detail_page.dart';
import '../../../providers/authProvider.dart';
import '../../../services/news/news_service.dart';
import '../../../theme/app_colors.dart';
import '../../news/news_widgets.dart';

/// Carte d'actualité dans le fil : un résumé de plusieurs sources, avec le pseudo de l'agent et son badge, le niveau (pays, continent, monde),
/// les sources et les actions (j'aime, commentaires, cadeau). Un toucher ouvre la page de détail.
/// Jamais montrée tant que `AppConfig/news.feedEnabled` n'est pas actif. La croix la masque jusqu'à demain.
/// [slotKey] : emplacement dans le fil (le même article revient au même emplacement) ; [category] : domaine imposé (page Sport : « sport »).
class NewsFeedCard extends StatefulWidget {
  const NewsFeedCard({super.key, required this.slotKey, this.category});
  final String slotKey;
  final String? category;

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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final svc = NewsService.instance;
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
  }

  Future<void> _open() async {
    final item = _item;
    if (item == null) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => NewsDetailPage(postId: item.id)));
  }

  Future<void> _like() async {
    final a = _article;
    if (a == null || _liked) return;
    setState(() {
      _liked = true;
      _loves += 1;
    });
    final ok = await NewsService.instance.like(a.id);
    if (!ok && mounted) {
      setState(() {
        _liked = false;
        _loves -= 1;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = _item;
    if (!_ready || _hidden || item == null) return const SizedBox.shrink();
    final c = AppColors.of(context);
    final agent = newsAgentOf(item.agentKey);
    final a = _article;
    return Stack(children: [
      GestureDetector(
        onTap: _open,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [c.primary.withOpacity(0.18), c.surface], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: c.primary.withOpacity(0.55), width: 1.5),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              AgentAvatar(agent: agent, size: 32),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(agent.pseudo, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 14)),
                  Text(
                    '${context.tr(agent.label)} · ${newsAgo(item.at)}',
                    style: TextStyle(color: c.textSecondary, fontSize: 11.5),
                  ),
                ]),
              ),
              const SizedBox(width: 30), // place de la croix
            ]),
            const SizedBox(height: 10),
            if (item.image.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: item.image,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(height: 160, color: c.shimmerBase),
                  errorWidget: (_, __, ___) => Container(height: 80, color: c.surfaceVariant, child: Icon(Icons.image_not_supported_outlined, color: c.textSecondary)),
                ),
              ),
            if (item.image.isNotEmpty) const SizedBox(height: 10),
            Text(item.title, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 15, height: 1.25)),
            const SizedBox(height: 4),
            Text(item.chapo, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textSecondary, fontSize: 12.5, height: 1.35)),
            const SizedBox(height: 10),
            Wrap(spacing: 6, runSpacing: 6, children: [
              NewsChip(text: newsLevelLabel(item.level, item.country, item.continent), color: c.supportAccent),
              NewsChip(
                text: context.tr('Résumé de {n} sources', {'n': item.sourceCount}),
                icon: Icons.link_rounded,
                color: c.info,
              ),
            ]),
            if (item.sourceNames.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                '${context.tr('Sources')} : ${item.sourceNames.join(', ')}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: c.textSecondary, fontSize: 11.5),
              ),
            ],
            const SizedBox(height: 8),
            Divider(color: c.border, height: 1),
            const SizedBox(height: 6),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              _stat(c, Icons.visibility_outlined, newsCount(a?.views ?? 0), null, c.textSecondary),
              _stat(c, _liked ? Icons.favorite_rounded : Icons.favorite_border_rounded, newsCount(_loves), _like, _liked ? c.danger : c.textSecondary),
              _stat(c, Icons.chat_bubble_outline_rounded, newsCount(a?.comments ?? 0), a == null ? null : () => NewsActions.comments(context, a), c.textSecondary),
              _stat(c, Icons.card_giftcard_rounded, context.tr('Cadeau'), a == null ? null : () => NewsActions.gift(context, a), c.warning),
            ]),
          ]),
        ),
      ),
      Positioned(
        top: 22,
        right: 24,
        child: GestureDetector(
          onTap: () async {
            await NewsService.instance.hideUntilTomorrow();
            if (mounted) setState(() => _hidden = true);
          },
          child: Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(color: c.surfaceVariant, shape: BoxShape.circle),
            child: Icon(Icons.close_rounded, size: 16, color: c.textSecondary),
          ),
        ),
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
