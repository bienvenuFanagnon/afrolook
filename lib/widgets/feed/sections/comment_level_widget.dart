import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/authProvider.dart';
import '../../../providers/streakProvider.dart';
import '../../../theme/app_colors.dart';
import '../../flame_streak_banner.dart';

/// Bandeau "Mon niveau" — affiché en permanence dans le feed, indépendamment
/// du widget top commentateurs hebdomadaire.
class CommentLevelWidget extends StatelessWidget {
  const CommentLevelWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Consumer2<UserAuthProvider, StreakProvider>(
      builder: (ctx, auth, streakProv, _) {
        final me = auth.loginUserData;
        final streak = me.commentStreak;
        final lvl = commentLevelForStreak(streak);
        return GestureDetector(
          onTap: () {
            // Pré-remplir le StreakProvider depuis les données locales pour éviter
            // l'affichage à 0 avant que le stream Firestore n'ait répondu.
            streakProv.seedFromUserData(
              commentStreak: me.commentStreak,
              bestCommentStreak: me.bestCommentStreak,
              streakShields: me.streakShields,
              todayCommentCount: me.todayCommentCount,
              todayCommentDate: me.todayCommentDate,
            );
            showCommentStreakModal(ctx, streakProv);
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: lvl.color.withOpacity(0.35)),
              boxShadow: [
                BoxShadow(
                  color: lvl.color.withOpacity(0.06),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 18,
                  backgroundImage: (me.imageUrl?.isNotEmpty == true)
                      ? CachedNetworkImageProvider(me.imageUrl!)
                      : null,
                  backgroundColor: colors.shimmerBase,
                  child: (me.imageUrl?.isEmpty ?? true)
                      ? Icon(Icons.person, size: 16, color: colors.textSecondary)
                      : null,
                ),
                const SizedBox(width: 10),
                // Niveau + label
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text(lvl.emoji, style: const TextStyle(fontSize: 14)),
                        const SizedBox(width: 5),
                        Text(
                          lvl.label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: lvl.color,
                          ),
                        ),
                      ]),
                      Text(
                        'Mon niveau de commentaire · Appuie pour les détails',
                        style: TextStyle(fontSize: 9.5, color: colors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Badge streak
                if (streak > 0) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: lvl.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: lvl.color.withOpacity(0.4)),
                    ),
                    child: Text(
                      '🔥 $streak j',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: lvl.color,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                Icon(Icons.chevron_right, size: 16, color: colors.textSecondary),
              ],
            ),
          ),
        );
      },
    );
  }
}
