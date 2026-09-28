import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/model_data.dart';
import '../theme/app_colors.dart';
import 'package:afrotok/utils/responsive_sheet.dart';
import '../l10n/tr.dart';

/// Pièces reçues par un post (likes + commentaires + cadeaux), visibles par tous :
/// c'est la preuve que sur Afrolook, chaque interaction paie le créateur.
class PostCoins {
  static final NumberFormat _n = NumberFormat.decimalPattern('fr');

  static int total(Post p) => p.totalGiftCoinsSentOnThisPost ?? 0;
  static int likes(Post p) => p.totalCoinsFromLikes ?? 0;
  static int comments(Post p) => p.totalCoinsFromComments ?? 0;
  static int gifts(Post p) => (total(p) - likes(p) - comments(p)).clamp(0, 1 << 40);

  static String fmt(int v) => _n.format(v);

  static String compact(int v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1).replaceAll('.', ',')}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1).replaceAll('.', ',')}k';
    return '$v';
  }

  static String creatorName(Post p) {
    final canal = p.canal?.titre;
    if (canal != null && canal.isNotEmpty) return '#$canal';
    final pseudo = p.user?.pseudo;
    return pseudo != null && pseudo.isNotEmpty ? '@$pseudo' : tr('au créateur');
  }

  // Or : fond clair ou sombre selon le thème
  static Color bg(AppColors c) => c.isDark ? const Color(0x33EF9F27) : const Color(0xFFFAEEDA);
  static Color fg(AppColors c) => c.isDark ? const Color(0xFFFAC775) : const Color(0xFF633806);
  static const Color border = Color(0xFFEF9F27);
}

/// Détail de ce que le post a rapporté (au tap sur le bandeau ou la pastille).
Future<void> showPostCoinsBreakdown(BuildContext context, Post post) {
  final c = AppColors.of(context);
  Widget line(IconData icon, String label, int coins) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Icon(icon, size: 18, color: c.textSecondary),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: TextStyle(color: c.textPrimary, fontSize: 14))),
          Text(context.tr('{a} pièces', {'a': PostCoins.fmt(coins)}),
              style: TextStyle(color: c.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
        ]),
      );
  return showResponsiveBottomSheet(
    context: context,
    backgroundColor: c.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: PostCoins.bg(c),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: PostCoins.border.withValues(alpha: 0.6), width: 0.8),
            ),
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: context.tr('🪙 Ce post a rapporté ')),
                TextSpan(
                  text: context.tr('{a} pièces', {'a': PostCoins.fmt(PostCoins.total(post))}),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                TextSpan(
                  text: PostCoins.creatorName(post).startsWith(context.tr('au '))
                      ? ' ${PostCoins.creatorName(post)}'
                      : ' à ${PostCoins.creatorName(post)}',
                ),
              ]),
              style: TextStyle(color: PostCoins.fg(c), fontSize: 14),
            ),
          ),
          const SizedBox(height: 12),
          Text(context.tr('Détail'), style: TextStyle(color: c.textSecondary, fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          line(Icons.favorite_rounded, context.tr('Likes'), PostCoins.likes(post)),
          line(Icons.chat_bubble_rounded, context.tr('Commentaires'), PostCoins.comments(post)),
          line(Icons.card_giftcard_rounded, context.tr('Cadeaux'), PostCoins.gifts(post)),
          Divider(height: 20, color: c.border),
          Row(children: [
            Expanded(child: Text(context.tr('Total'), style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700))),
            Text(context.tr('{a} pièces', {'a': PostCoins.fmt(PostCoins.total(post))}),
                style: TextStyle(color: PostCoins.fg(c), fontSize: 15, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: PostCoins.bg(c), borderRadius: BorderRadius.circular(10)),
            child: Text(
              context.tr('Sur Afrolook, chaque like et chaque commentaire paient le créateur : 1 pièce à chaque fois.'),
              style: TextStyle(color: PostCoins.fg(c), fontSize: 12.5, height: 1.35),
            ),
          ),
        ]),
      ),
    ),
  );
}

/// Bandeau des pages de détails, placé entre le média et la rangée de statistiques.
class PostCoinsBanner extends StatelessWidget {
  final Post post;
  final EdgeInsetsGeometry margin;

  const PostCoinsBanner({super.key, required this.post, this.margin = const EdgeInsets.symmetric(vertical: 8)});

  @override
  Widget build(BuildContext context) {
    if (post.isAdvertisement == true) return const SizedBox.shrink();
    final c = AppColors.of(context);
    final total = PostCoins.total(post);
    final name = PostCoins.creatorName(post);
    return Padding(
      padding: margin,
      child: Material(
        color: PostCoins.bg(c),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: PostCoins.border.withValues(alpha: 0.6), width: 0.8),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => showPostCoinsBreakdown(context, post),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(children: [
              const Text('🪙', style: TextStyle(fontSize: 15)),
              const SizedBox(width: 8),
              Expanded(
                child: Text.rich(
                  total > 0
                      ? TextSpan(children: [
                          TextSpan(text: context.tr('Ce post a rapporté ')),
                          TextSpan(text: context.tr('{a} pièces', {'a': PostCoins.fmt(total)}), style: const TextStyle(fontWeight: FontWeight.w800)),
                          TextSpan(text: name.startsWith(context.tr('au ')) ? ' $name' : ' à $name'),
                        ])
                      : TextSpan(text: context.tr('Chaque like rapporte 1 pièce {a}', {'a': name.startsWith('au ') ? name : 'à $name'})),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: PostCoins.fg(c), fontSize: 13),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: PostCoins.fg(c), size: 20),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Pastille de la vidéo portrait (fond vidéo sombre), au-dessus du pseudo.
class PostCoinsChip extends StatelessWidget {
  final Post post;

  const PostCoinsChip({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    if (post.isAdvertisement == true) return const SizedBox.shrink();
    final total = PostCoins.total(post);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => showPostCoinsBreakdown(context, post),
      child: Padding(
        // Zone de tap plus large que la pastille elle-même
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFFAEEDA),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: PostCoins.border, width: 0.8),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(
            total > 0 ? context.tr('🪙 {a} pièces reçues', {'a': PostCoins.fmt(total)}) : context.tr('🪙 1 like = 1 pièce au créateur'),
            style: const TextStyle(color: Color(0xFF633806), fontSize: 11.5, fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 2),
          const Icon(Icons.chevron_right_rounded, size: 16, color: Color(0xFF633806)),
        ]),
      ),
      ),
    );
  }
}

/// Cœur du like avec la mini-pastille « +1 » dorée, dessinée dans sa propre zone (rien ne déborde).
class LikeCoinHeart extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  const LikeCoinHeart({super.key, required this.icon, required this.color, this.size = 21});

  @override
  Widget build(BuildContext context) {
    // Même hauteur que le cœur : la pastille se place à droite, dans la largeur réservée
    return SizedBox(
      width: size + 13,
      height: size,
      child: Stack(children: [
        Positioned(left: 0, top: 0, child: Icon(icon, size: size, color: color)),
        Positioned(
          right: 0,
          top: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 3.5, vertical: 0.5),
            decoration: BoxDecoration(color: PostCoins.border, borderRadius: BorderRadius.circular(7)),
            child: const Text('+1',
                style: TextStyle(color: Color(0xFF412402), fontSize: 8.5, fontWeight: FontWeight.w800, height: 1.2)),
          ),
        ),
      ]),
    );
  }
}
