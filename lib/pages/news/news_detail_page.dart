import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  int _followers = 0;
  bool _pulse = false; // petit rebond du bouton Suivre au toucher

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
    // déjà comptée si la carte du fil a été vue : le compteur n'augmente alors pas une seconde fois
    NewsService.instance.recordView(a).then((counted) {
      if (counted && mounted) setState(() => _views += 1);
    });
    AdmobService.warmUpInterstitial(context.read<UserAuthProvider>().loginUserData); // prête pour l'ouverture d'une source
    try {
      final db = FirebaseFirestore.instance;
      final res = await Future.wait([
        db.collection('Follows').doc('${a.agent.userId}_$uid').get(),
        db.collection('Users').doc(a.agent.userId).get(),
      ]);
      if (mounted) {
        setState(() {
          _following = res[0].exists;
          _followers = ((res[1].data() ?? const {})['abonnes'] as num?)?.toInt() ?? 0;
        });
      }
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
    // réponse immédiate (le compteur et le bouton changent tout de suite), annulée si le serveur refuse
    final was = _following;
    HapticFeedback.selectionClick();
    setState(() {
      _followBusy = true;
      _following = !was;
      _followers = (_followers + (was ? -1 : 1)).clamp(0, 1 << 31).toInt();
      _pulse = true;
    });
    Future.delayed(const Duration(milliseconds: 160), () {
      if (mounted) setState(() => _pulse = false);
    });
    try {
      if (was) {
        await FollowService.unfollow(a.agent.userId);
      } else {
        await FollowService.follow(a.agent.userId);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _following = was;
          _followers = (_followers + (was ? 1 : -1)).clamp(0, 1 << 31).toInt();
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('Action impossible pour le moment.'))));
      }
    }
    if (mounted) setState(() => _followBusy = false);
  }

  /// Suppression par un administrateur, avec confirmation ; l'article disparaît du fil, du journal et de la liste admin.
  Future<void> _adminDelete() async {
    final a = _a;
    if (a == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.tr('Supprimer cet article ?')),
        content: Text(ctx.tr('Il disparaîtra du fil et du journal, avec ses commentaires. Cette action est définitive.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.tr('Annuler'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(ctx.tr('Supprimer'), style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w800))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final done = await NewsService.instance.adminDelete(a.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr(done ? 'Article supprimé.' : 'Suppression impossible pour le moment.'))));
    if (done) Navigator.pop(context);
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
          // administrateur : suppression directe, sans passer par l'écran d'administration
          if (a != null && context.read<UserAuthProvider>().loginUserData.role == 'ADM')
            IconButton(tooltip: context.tr('Supprimer (admin)'), icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent), onPressed: _adminDelete),
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
      // en-tête « journal » : bandeau ACTUALITÉ puis photo, comme sur la carte du fil
      ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Column(children: [
          NewsMasthead(place: newsLevelLabel(a.level, a.country, a.continent)),
          if (a.image.isNotEmpty)
            GestureDetector(
              onTap: () => NewsImageViewer.open(context, a.image, 'news_img_${a.id}'), // photo en grand : zoom, glisser vers le bas pour fermer
              child: Stack(children: [
                Hero(
                  tag: 'news_img_${a.id}',
                  child: CachedNetworkImage(
                    imageUrl: a.image,
                    width: double.infinity,
                    height: 210,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(height: 210, color: c.shimmerBase),
                    errorWidget: (_, __, ___) => Container(height: 90, color: c.surfaceVariant, child: Icon(Icons.image_not_supported_outlined, color: c.textSecondary)),
                  ),
                ),
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                    child: const Icon(Icons.zoom_out_map_rounded, size: 18, color: Colors.white),
                  ),
                ),
              ]),
            ),
        ]),
      ),
      const SizedBox(height: 12),
      NewsChip(text: context.tr(agent.label), color: agent.color(c), filled: true),
      const SizedBox(height: 10),
      Text(a.title, style: TextStyle(color: c.textPrimary, fontFamily: 'serif', fontWeight: FontWeight.w800, fontSize: 23, height: 1.25)),
      const SizedBox(height: 12),
      Row(children: [
        AgentAvatar(agent: agent, size: 36),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(agent.pseudo, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 14)),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (w, anim) => FadeTransition(opacity: anim, child: SlideTransition(position: Tween(begin: const Offset(0, 0.4), end: Offset.zero).animate(anim), child: w)),
              child: Text(
                '${newsCount(_followers)} ${context.tr(_followers > 1 ? 'abonnés' : 'abonné')} · ${newsAgo(a.createdAtMs)}',
                key: ValueKey(_followers),
                style: TextStyle(color: c.textSecondary, fontSize: 12),
              ),
            ),
          ]),
        ),
        _followButton(c),
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
      const SizedBox(height: 12),
      const NewsMoreButton(),
    ]);
  }

  /// Bouton Suivre / Abonné : change de couleur et d'icône en fondu, rebondit au toucher.
  Widget _followButton(AppColors c) {
    return AnimatedScale(
      scale: _pulse ? 1.12 : 1,
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      child: GestureDetector(
        onTap: _followBusy ? null : _toggleFollow,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: _following ? Colors.transparent : c.primary,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _following ? c.border : c.primary, width: 1.4),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            transitionBuilder: (w, anim) => FadeTransition(opacity: anim, child: ScaleTransition(scale: anim, child: w)),
            child: Row(
              key: ValueKey(_following),
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_following ? Icons.check_rounded : Icons.add_rounded, size: 17, color: _following ? c.textSecondary : c.onPrimary),
                const SizedBox(width: 4),
                Text(
                  _following ? context.tr('Abonné') : context.tr('Suivre'),
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: _following ? c.textSecondary : c.onPrimary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
