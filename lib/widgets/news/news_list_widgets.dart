import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../l10n/tr.dart';
import '../../models/news_article.dart';
import '../../models/news_digest.dart';
import '../../theme/app_colors.dart';
import 'news_widgets.dart';

/// Vignette d'un article : image carrée ou, à défaut, l'icône de son domaine.
class _Thumb extends StatelessWidget {
  final String image;
  final NewsAgentInfo agent;
  final double size = 56;
  const _Thumb({required this.image, required this.agent});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: agent.color(c).withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
      child: Icon(agent.icon, color: agent.color(c), size: size * 0.45),
    );
    if (image.isEmpty) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: CachedNetworkImage(imageUrl: image, width: size, height: size, fit: BoxFit.cover, placeholder: (_, __) => Container(width: size, height: size, color: c.shimmerBase), errorWidget: (_, __, ___) => fallback),
    );
  }
}

/// Ligne compacte d'un article (liste du journal) : vignette, titre, domaine, agent et ancienneté. [rank] numérote les résumés.
class NewsListTile extends StatelessWidget {
  final NewsAgentInfo agent;
  final String title;
  final String image;
  final String meta;
  final int? rank;
  final VoidCallback onTap;
  const NewsListTile({super.key, required this.agent, required this.title, required this.image, required this.meta, required this.onTap, this.rank});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: c.border)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (rank != null)
            Container(
              width: 24,
              height: 24,
              margin: const EdgeInsets.only(right: 8, top: 2),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: rank == 1 ? c.primary : c.surfaceVariant, shape: BoxShape.circle),
              child: Text('$rank', style: TextStyle(color: rank == 1 ? c.onPrimary : c.textSecondary, fontWeight: FontWeight.w800, fontSize: 12)),
            ),
          _Thumb(image: image, agent: agent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 13.5, height: 1.25)),
              const SizedBox(height: 4),
              Row(children: [
                Icon(agent.icon, size: 13, color: agent.color(c)),
                const SizedBox(width: 4),
                Expanded(child: Text(meta, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textSecondary, fontSize: 11.5))),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// « À la une » : la grande carte (même style que la carte du fil : 20 px de rayon, bordure verte).
class NewsTopCard extends StatelessWidget {
  final String badge;
  final NewsAgentInfo agent;
  final String title;
  final String chapo;
  final String image;
  final String meta;
  final VoidCallback onTap;
  const NewsTopCard({super.key, required this.badge, required this.agent, required this.title, required this.chapo, required this.image, required this.meta, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 4, 12, 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [c.primary.withOpacity(0.18), c.surface], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.primary.withOpacity(0.55), width: 1.5),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          NewsChip(text: badge, color: c.primary, filled: true, icon: Icons.local_fire_department_rounded),
          const SizedBox(height: 8),
          if (image.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: image,
                height: 150,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(height: 150, color: c.shimmerBase),
                errorWidget: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          if (image.isNotEmpty) const SizedBox(height: 8),
          Text(title, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 15.5, height: 1.25)),
          if (chapo.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(chapo, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textSecondary, fontSize: 12.5, height: 1.35)),
          ],
          const SizedBox(height: 8),
          Row(children: [
            AgentAvatar(agent: agent, size: 22),
            const SizedBox(width: 8),
            Expanded(child: Text(meta, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textSecondary, fontSize: 11.5))),
          ]),
        ]),
      ),
    );
  }
}

/// En-tête d'un résumé : la période, le nombre d'infos et l'introduction.
class NewsDigestHeader extends StatelessWidget {
  final String title;
  final String range;
  final String intro;
  const NewsDigestHeader({super.key, required this.title, required this.range, required this.intro});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [c.primary.withOpacity(0.18), c.surface], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.primary.withOpacity(0.55), width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.newspaper_rounded, color: c.primary, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(title, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 15))),
        ]),
        if (range.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2, left: 28), child: Text(range, style: TextStyle(color: c.textSecondary, fontSize: 11.5))),
        if (intro.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(intro, style: TextStyle(color: c.textPrimary, fontSize: 13, height: 1.4)),
        ],
      ]),
    );
  }
}

/// Message quand il n'y a rien à montrer, avec une action facultative (par exemple « Voir l'Afrique »).
class NewsEmpty extends StatelessWidget {
  final String message;
  final String? hint;
  final String? action;
  final VoidCallback? onAction;
  const NewsEmpty({super.key, required this.message, this.hint, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
      child: Column(children: [
        Icon(Icons.newspaper_rounded, size: 56, color: c.border),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 14.5)),
        if (hint != null) ...[
          const SizedBox(height: 6),
          Text(hint!, textAlign: TextAlign.center, style: TextStyle(color: c.textSecondary, fontSize: 12.5, height: 1.35)),
        ],
        if (action != null) ...[
          const SizedBox(height: 14),
          OutlinedButton(
            onPressed: onAction,
            style: OutlinedButton.styleFrom(foregroundColor: c.primary, side: BorderSide(color: c.primary), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
            child: Text(action!),
          ),
        ],
      ]),
    );
  }
}

/// Article d'un résumé dont la page n'existe plus : on montre la copie gardée dans le résumé (titre, chapô) et ses sources.
Future<void> showDigestItemSheet(BuildContext context, NewsDigestItem item) {
  final c = AppColors.of(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: c.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (sheetContext) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.92,
      minChildSize: 0.35,
      builder: (_, scroll) => ListView(controller: scroll, padding: const EdgeInsets.fromLTRB(16, 14, 16, 28), children: [
        Row(children: [
          AgentAvatar(agent: item.agent, size: 32),
          const SizedBox(width: 10),
          Expanded(child: Text(item.agent.pseudo, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 14))),
          Text(newsAgo(item.at), style: TextStyle(color: c.textSecondary, fontSize: 12)),
        ]),
        const SizedBox(height: 12),
        if (item.image.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: CachedNetworkImage(imageUrl: item.image, height: 170, width: double.infinity, fit: BoxFit.cover, errorWidget: (_, __, ___) => const SizedBox.shrink()),
          ),
        if (item.image.isNotEmpty) const SizedBox(height: 12),
        Text(item.title, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 18, height: 1.25)),
        const SizedBox(height: 8),
        Text(item.chapo, style: TextStyle(color: c.textPrimary, fontSize: 14.5, height: 1.45)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: c.surfaceVariant, borderRadius: BorderRadius.circular(12), border: Border.all(color: c.border)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.info_outline_rounded, size: 18, color: c.info),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                context.tr('Cet article n\'est plus dans l\'application, mais voici son résumé. Pour le détail complet, consulte ses sources.'),
                style: TextStyle(color: c.textSecondary, fontSize: 12.5, height: 1.35),
              ),
            ),
          ]),
        ),
        if (item.sources.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(context.tr('Sources'), style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 4),
          for (final s in item.sources)
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
        ],
      ]),
    ),
  );
}
