import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/model_data.dart';
import '../../models/news_article.dart';
import '../../pages/coins/coin_gift_dialog.dart';
import '../../pages/postComments.dart';
import '../../theme/app_colors.dart';

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

  static Future<void> openSource(NewsSource s) async {
    try {
      await launchUrl(Uri.parse(s.url), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }
}
