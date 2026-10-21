import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../ads/ad_banner.dart';
import '../../ads/admob_service.dart';
import '../../ads/admob_widgets.dart';
import '../../l10n/tr.dart';
import '../../models/news_article.dart';
import '../../providers/authProvider.dart';
import '../../services/follow_service.dart';
import '../../services/news/news_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/news/news_widgets.dart';

/// Page de détail d'un article d'actualité : le résumé complet, « À retenir », les sources (liens visibles, toujours en bas) et les actions
/// (j'aime, commentaires, cadeau, partage, signalement). Ouvrir la page compte une vue.
class NewsDetailPage extends StatefulWidget {
  const NewsDetailPage({super.key, required this.postId});
  final String postId;

  @override
  State<NewsDetailPage> createState() => _NewsDetailPageState();
}

class _NewsDetailPageState extends State<NewsDetailPage> {
  NewsArticle? _a;
  bool _loading = true;
  bool _liked = false;
  int _loves = 0;
  int _comments = 0;
  int _views = 0;
  bool _following = false;
  bool _followBusy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final a = await NewsService.instance.article(widget.postId, fresh: true);
    if (!mounted) return;
    final uid = context.read<UserAuthProvider>().loginUserData.id;
    setState(() {
      _a = a;
      _loading = false;
      _liked = a?.lovedByUser(uid) ?? false;
      _loves = a?.loves ?? 0;
      _comments = a?.comments ?? 0;
      _views = a?.views ?? 0;
    });
    if (a == null) return;
    NewsService.instance.recordView(a);
    AdmobService.warmUpInterstitial(context.read<UserAuthProvider>().loginUserData); // prête pour l'ouverture d'une source
    if (uid != null && !a.viewedBy.contains(uid) && mounted) setState(() => _views += 1);
    try {
      final f = await FirebaseFirestore.instance.collection('Follows').doc('${a.agent.userId}_$uid').get();
      if (mounted) setState(() => _following = f.exists);
    } catch (_) {}
  }

  Future<void> _like() async {
    final a = _a;
    if (a == null || _liked) return;
    setState(() {
      _liked = true;
      _loves += 1;
    });
    if (!await NewsService.instance.like(a.id) && mounted) {
      setState(() {
        _liked = false;
        _loves -= 1;
      });
    }
  }

  Future<void> _toggleFollow() async {
    final a = _a;
    if (a == null || _followBusy) return;
    setState(() => _followBusy = true);
    try {
      if (_following) {
        await FollowService.unfollow(a.agent.userId);
        if (mounted) setState(() => _following = false);
      } else {
        await FollowService.follow(a.agent.userId);
        if (mounted) setState(() => _following = true);
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('Action impossible pour le moment.'))));
    }
    if (mounted) setState(() => _followBusy = false);
  }

  Future<void> _report() async {
    final r = await NewsService.instance.report(widget.postId);
    if (!mounted) return;
    final msg = r == 'ok'
        ? 'Article signalé. Merci.'
        : r == 'already-exists'
            ? 'Tu as déjà signalé cet article.'
            : 'Signalement impossible pour le moment.';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr(msg))));
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final a = _a;
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.surface,
        foregroundColor: c.textPrimary,
        title: Text(context.tr('Actualités')),
        actions: [
          if (a != null)
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'share') Share.share('${a.title}\n\n${context.tr('Résumé de {n} sources', {'n': a.sources.length})} · Afrolook');
                if (v == 'report') _report();
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'share', child: Text(context.tr('Partager'))),
                PopupMenuItem(value: 'report', child: Text(context.tr('Signaler'))),
              ],
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : a == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(context.tr('Cet article n\'est plus disponible.'), textAlign: TextAlign.center, style: TextStyle(color: c.textSecondary)),
                  ),
                )
              : _body(c, a),
    );
  }

  Widget _body(AppColors c, NewsArticle a) {
    final agent = a.agent;
    return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 32), children: [
      if (a.image.isNotEmpty)
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: CachedNetworkImage(
            imageUrl: a.image,
            width: double.infinity,
            height: 210,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(height: 210, color: c.shimmerBase),
            errorWidget: (_, __, ___) => Container(height: 90, color: c.surfaceVariant, child: Icon(Icons.image_not_supported_outlined, color: c.textSecondary)),
          ),
        ),
      const SizedBox(height: 12),
      Wrap(spacing: 6, runSpacing: 6, children: [
        NewsChip(text: context.tr(agent.label), color: agent.color(c), filled: true),
        NewsChip(text: newsLevelLabel(a.level, a.country, a.continent), color: c.supportAccent),
      ]),
      const SizedBox(height: 10),
      Text(a.title, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 22, height: 1.25)),
      const SizedBox(height: 12),
      Row(children: [
        AgentAvatar(agent: agent, size: 36),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(agent.pseudo, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 14)),
            Text(newsAgo(a.createdAtMs), style: TextStyle(color: c.textSecondary, fontSize: 12)),
          ]),
        ),
        OutlinedButton(
          onPressed: _followBusy ? null : _toggleFollow,
          style: OutlinedButton.styleFrom(
            foregroundColor: _following ? c.textSecondary : c.primary,
            side: BorderSide(color: _following ? c.border : c.primary),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            visualDensity: VisualDensity.compact,
          ),
          child: Text(_following ? context.tr('Abonné') : context.tr('Suivre'), style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      ]),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: c.surfaceVariant, borderRadius: BorderRadius.circular(12), border: Border.all(color: c.border)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.link_rounded, size: 18, color: c.info),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.tr('Ce texte est un résumé de {n} sources, listées en bas de la page. Pour le détail complet, consulte-les.', {'n': a.sources.length}),
              style: TextStyle(color: c.textSecondary, fontSize: 12.5, height: 1.35),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 14),
      Text(a.chapo, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w600, fontSize: 15.5, height: 1.45)),
      for (var i = 0; i < a.sections.length; i++) ...[
        const SizedBox(height: 16),
        if (a.sections[i].title.isNotEmpty) Text(a.sections[i].title, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 16.5)),
        if (a.sections[i].title.isNotEmpty) const SizedBox(height: 4),
        Text(a.sections[i].text, style: TextStyle(color: c.textPrimary, fontSize: 14.5, height: 1.55)),
        // pub native après la première section (rien ne s'affiche pour Gold ou si aucune pub n'est prête)
        if (i == 0) const AdmobNativeWidget(key: ValueKey('news_native_1')),
      ],
      if (a.retenir.isNotEmpty) ...[
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.primary.withOpacity(0.55), width: 1.5),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(context.tr('À retenir'), style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 8),
            for (final r in a.retenir)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.check_circle_rounded, size: 16, color: c.primary),
                  const SizedBox(width: 8),
                  Expanded(child: Text(r, style: TextStyle(color: c.textPrimary, fontSize: 13.5, height: 1.35))),
                ]),
              ),
          ]),
        ),
      ],
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: c.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(context.tr('Sources'), style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 6),
          for (final s in a.sources)
            InkWell(
              onTap: () => NewsActions.openSource(context, s),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(children: [
                  Icon(Icons.open_in_new_rounded, size: 18, color: c.info),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(s.name, style: TextStyle(color: c.info, fontWeight: FontWeight.w700, fontSize: 13.5)),
                      Text(Uri.tryParse(s.url)?.host ?? s.url, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textSecondary, fontSize: 11.5)),
                    ]),
                  ),
                ]),
              ),
            ),
        ]),
      ),
      // grand format sous les sources : l'endroit où la personne s'arrête de lire
      const Center(child: AdBanner(key: ValueKey('news_mrec'), mrec: true)),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: c.border)),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _action(c, Icons.visibility_outlined, newsCount(_views), null, c.textSecondary),
          _action(c, _liked ? Icons.favorite_rounded : Icons.favorite_border_rounded, newsCount(_loves), _like, _liked ? c.danger : c.textSecondary),
          _action(c, Icons.chat_bubble_outline_rounded, newsCount(_comments), () async {
            await NewsActions.comments(context, a);
            final fresh = await NewsService.instance.article(a.id, fresh: true);
            if (mounted && fresh != null) setState(() => _comments = fresh.comments);
          }, c.textSecondary),
          _action(c, Icons.card_giftcard_rounded, context.tr('Cadeau'), () => NewsActions.gift(context, a), c.warning),
        ]),
      ),
    ]);
  }

  Widget _action(AppColors c, IconData icon, String label, VoidCallback? onTap, Color color) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 21, color: color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}
