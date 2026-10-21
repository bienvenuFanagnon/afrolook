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
  const NewsFeedCard({super.key, required this.slotKey, this.category, this.postId});
  final String slotKey;
  final String? category;

  /// Article précis à montrer (un post d'actualité rencontré dans une liste de posts) : pas de choix automatique, pas de réglage du fil.
  final String? postId;

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
    // Présentation « journal » : bandeau ACTUALITÉ, photo pleine largeur, titre en empattement, signature de l'agent, sources, puis le bouton vers le journal.
    // Volontairement différente d'un post ordinaire (pas de carte arrondie verte, pas de ligne auteur en tête).
    return GestureDetector(
      onTap: _open,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: c.border),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          NewsMasthead(
            place: newsLevelLabel(item.level, item.country, item.continent),
            onClose: () async {
              if (widget.postId == null) await NewsService.instance.hideUntilTomorrow(); // la croix du fil masque toutes les cartes jusqu'à demain
              if (mounted) setState(() => _hidden = true);
            },
          ),
          if (item.image.isNotEmpty)
            CachedNetworkImage(
              imageUrl: item.image,
              height: 175,
              width: double.infinity,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(height: 175, color: c.shimmerBase),
              errorWidget: (_, __, ___) => Container(height: 70, color: c.surfaceVariant, child: Icon(Icons.image_not_supported_outlined, color: c.textSecondary)),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.title, style: TextStyle(color: c.textPrimary, fontFamily: 'serif', fontWeight: FontWeight.w800, fontSize: 17.5, height: 1.25)),
              const SizedBox(height: 6),
              Text(item.chapo, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textSecondary, fontSize: 13, height: 1.4)),
              const SizedBox(height: 10),
              Row(children: [
                AgentAvatar(agent: agent, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(text: agent.pseudo, style: TextStyle(color: agent.color(c), fontWeight: FontWeight.w800)),
                      TextSpan(text: '  ·  ${newsAgo(item.at)}'),
                    ]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: c.textSecondary, fontSize: 12),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Icon(Icons.link_rounded, size: 14, color: c.info),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    item.sourceNames.isEmpty
                        ? context.tr('Résumé de {n} sources', {'n': item.sourceCount})
                        : '${context.tr('Résumé de {n} sources', {'n': item.sourceCount})} : ${item.sourceNames.join(', ')}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: c.info, fontSize: 11.5, fontWeight: FontWeight.w600),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              Divider(color: c.border, height: 1),
              const SizedBox(height: 4),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                _stat(c, Icons.visibility_outlined, newsCount(a?.views ?? 0), null, c.textSecondary),
                _stat(c, _liked ? Icons.favorite_rounded : Icons.favorite_border_rounded, newsCount(_loves), _like, _liked ? c.danger : c.textSecondary),
                _stat(c, Icons.chat_bubble_outline_rounded, newsCount(a?.comments ?? 0), a == null ? null : () => NewsActions.comments(context, a), c.textSecondary),
                _stat(c, Icons.card_giftcard_rounded, context.tr('Cadeau'), a == null ? null : () => NewsActions.gift(context, a), c.warning),
              ]),
              const SizedBox(height: 8),
              // accès à tout le journal : pays, continent, monde, résumés du jour, de la semaine et du mois
              const NewsMoreButton(),
            ]),
          ),
        ]),
      ),
    );
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
