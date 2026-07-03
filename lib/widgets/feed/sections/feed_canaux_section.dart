import 'package:flutter/material.dart';
import '../../../models/model_data.dart';
import '../../../pages/canaux/listCanal.dart';
import '../../../pages/canaux/detailsCanal.dart';
import '../../../theme/app_colors.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Section horizontale de canaux Afrolook.
class FeedCanauxSection extends StatelessWidget {
  final List<Canal> canaux;
  final bool isLoading;
  final String title;
  final String seeMoreLabel;

  const FeedCanauxSection({
    Key? key,
    required this.canaux,
    this.isLoading = false,
    required this.title,
    required this.seeMoreLabel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (isLoading || canaux.isEmpty) return const SizedBox.shrink();

    final colors = AppColors.of(context);
    const cardWidth = 90.0;
    const avatarSize = 56.0;
    final afroGreen = const Color(0xFF25D366);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => CanalListPage(isUserCanals: false)),
                  ),
                  child: Row(
                    children: [
                      Text(
                        seeMoreLabel,
                        style: TextStyle(
                          color: afroGreen,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Icon(Icons.arrow_forward_ios, color: afroGreen, size: 12),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              itemCount: canaux.length,
              itemBuilder: (_, i) {
                final canal = canaux[i];
                return GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => CanalDetails(canal: canal)),
                  ),
                  child: SizedBox(
                    width: cardWidth,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Avatar cerclé
                        Container(
                          width: avatarSize,
                          height: avatarSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: afroGreen, width: 2),
                          ),
                          child: ClipOval(
                            child: CachedNetworkImage(
                              imageUrl: canal.urlImage ?? '',
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(
                                color: colors.surfaceVariant,
                                child: Icon(Icons.group, color: afroGreen, size: 22),
                              ),
                              errorWidget: (_, __, ___) => Container(
                                color: colors.surfaceVariant,
                                child: Icon(Icons.group, color: afroGreen, size: 22),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 5),
                        // Nom du canal
                        Text(
                          '#${canal.titre ?? ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        // Abonnés
                        Text(
                          '${canal.usersSuiviId?.length ?? 0} abonnés',
                          style: TextStyle(
                            fontSize: 9,
                            color: colors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingSection extends StatelessWidget {
  final String title;
  const _LoadingSection({required this.title});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: TextStyle(color: colors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF25D366)),
          ),
        ],
      ),
    );
  }
}
