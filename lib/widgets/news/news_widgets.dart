import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/tr.dart';
import '../../models/model_data.dart';
import '../../models/news_article.dart';
import '../../pages/coins/coin_gift_dialog.dart';
import '../../pages/news/news_journal_page.dart';
import '../../pages/postComments.dart';
import '../../theme/app_colors.dart';
import 'news_ads.dart';

/// Bandeau « ACTUALITÉ » : la marque visuelle qui distingue un article d'actualité d'un post ordinaire (carte du fil, page de détail).
/// [place] : niveau de l'article (pays, continent, monde) ; [onClose] : croix de la carte du fil.
class NewsMasthead extends StatelessWidget {
  final String place;
  final VoidCallback? onClose;
  const NewsMasthead({super.key, required this.place, this.onClose});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      color: c.primary,
      padding: EdgeInsets.fromLTRB(12, onClose == null ? 7 : 4, onClose == null ? 12 : 4, onClose == null ? 7 : 4),
      child: Row(children: [
        Icon(Icons.newspaper_rounded, size: 16, color: c.onPrimary),
        const SizedBox(width: 6),
        Text(context.tr('ACTUALITÉ'), style: TextStyle(color: c.onPrimary, fontWeight: FontWeight.w900, fontSize: 11.5, letterSpacing: 1.6)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            place.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: TextStyle(color: c.onPrimary.withOpacity(0.85), fontWeight: FontWeight.w700, fontSize: 10.5, letterSpacing: 0.8),
          ),
        ),
        if (onClose != null)
          InkWell(
            onTap: onClose,
            customBorder: const CircleBorder(),
            child: Padding(padding: const EdgeInsets.all(5), child: Icon(Icons.close_rounded, size: 17, color: c.onPrimary)),
          ),
      ]),
    );
  }
}

/// Bouton « Voir plus d'actualités » : ouvre la page du journal (pays, continent, monde, résumés du jour, de la semaine, du mois).
class NewsMoreButton extends StatelessWidget {
  const NewsMoreButton({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Material(
      color: c.primary.withOpacity(0.12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: c.primary.withOpacity(0.6))),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NewsJournalPage())),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.newspaper_rounded, size: 18, color: c.primary),
            const SizedBox(width: 8),
            Flexible(
              child: Text(context.tr('Voir plus d\'actualités'), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.primary, fontWeight: FontWeight.w800, fontSize: 13.5)),
            ),
            const SizedBox(width: 6),
            Icon(Icons.arrow_forward_rounded, size: 18, color: c.primary),
          ]),
        ),
      ),
    );
  }
}

/// Avatar d'un agent d'actualités : pastille aux couleurs de son domaine, avec le badge « journal » vert, réservé aux agents
/// (carte du fil, page de détail, commentaires).
class AgentAvatar extends StatelessWidget {
  final NewsAgentInfo agent;
  final double size;
  const AgentAvatar({super.key, required this.agent, this.size = 28});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final color = agent.color(c);
    final badge = size * 0.44;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(clipBehavior: Clip.none, children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(0.18), border: Border.all(color: color, width: 1.5)),
          child: Icon(agent.icon, size: size * 0.52, color: color),
        ),
        Positioned(
          right: -badge * 0.25,
          bottom: -badge * 0.25,
          child: Container(
            width: badge,
            height: badge,
            decoration: BoxDecoration(shape: BoxShape.circle, color: c.primary, border: Border.all(color: c.surface, width: 1.5)),
            child: Icon(Icons.newspaper_rounded, size: badge * 0.62, color: c.onPrimary),
          ),
        ),
      ]),
    );
  }
}

/// Petite pastille d'information (domaine, niveau, sources).
class NewsChip extends StatelessWidget {
  final String text;
  final Color? color;
  final IconData? icon;
  final bool filled;
  const NewsChip({super.key, required this.text, this.color, this.icon, this.filled = false});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final base = color ?? c.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: filled ? base : c.surfaceVariant,
        borderRadius: BorderRadius.circular(20),
        border: filled ? null : Border.all(color: c.border),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 12, color: filled ? c.onPrimary : base), const SizedBox(width: 3)],
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: filled ? c.onPrimary : base),
          ),
        ),
      ]),
    );
  }
}

/// Actions communes à la carte du fil et à la page de détail : commentaires, cadeau, ouverture d'une source.
class NewsActions {
  NewsActions._();

  /// Post de l'article, avec le compte de l'agent comme créateur (les écrans de commentaires et de cadeaux s'en servent).
  static Post postOf(NewsArticle a) {
    final post = Post.fromJson(Map<String, dynamic>.from(a.raw));
    post.id ??= a.id;
    post.user = UserData()
      ..id = a.agent.userId
      ..pseudo = a.agent.pseudo;
    return post;
  }

  static Future<void> comments(BuildContext context, NewsArticle a) async {
    try {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => PostComments(post: postOf(a))));
    } catch (_) {}
  }

  static Future<void> gift(BuildContext context, NewsArticle a, {VoidCallback? onSent}) async {
    try {
      await showDialog(
        context: context,
        builder: (_) => CoinGiftDialog(
          receiverId: a.agent.userId,
          receiverName: a.agent.pseudo,
          post: postOf(a),
          onGiftSuccess: onSent,
        ),
      );
    } catch (_) {}
  }

  /// Ouvre une source dans le navigateur, après une pub plein écran (voir [NewsAds.beforeSource]) : jamais bloquant.
  static Future<void> openSource(BuildContext context, NewsSource s) async {
    await NewsAds.beforeSource(context);
    try {
      await launchUrl(Uri.parse(s.url), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }
}
