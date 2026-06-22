import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../models/model_data.dart';
import '../../../pages/listeUserLikepage.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/user_badge_widget.dart';

/// Section horizontale de profils suggérés.
class FeedProfilesSection extends StatelessWidget {
  final List<UserData> users;
  final bool isLoading;
  final String title;
  final String seeAllLabel;
  final void Function(UserData) onShowProfile;

  const FeedProfilesSection({
    Key? key,
    required this.users,
    this.isLoading = false,
    required this.title,
    required this.seeAllLabel,
    required this.onShowProfile,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (isLoading || users.isEmpty) return const SizedBox.shrink();

    final size = MediaQuery.of(context).size;
    final colors = AppColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                ),
              ),
              Container(
                height: 32,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFD700), Color(0xFF8B0000)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => UsersListPage()),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(seeAllLabel,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 11)),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward,
                          color: Colors.white, size: 12),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: size.height * 0.25,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: users.length,
            itemBuilder: (_, i) => Container(
              margin:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              width: size.width * 0.35,
              child: _ProfileCard(
                user: users[i],
                size: size,
                onTap: () => onShowProfile(users[i]),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Carte profil individuelle ─────────────────────────────────────────────────

class _ProfileCard extends StatelessWidget {
  final UserData user;
  final Size size;
  final VoidCallback onTap;

  const _ProfileCard({
    required this.user,
    required this.size,
    required this.onTap,
  });

  String _formatNumber(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: onTap,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                SizedBox(
                  width: size.width * 0.4,
                  height: size.height * 0.18,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                    child: CachedNetworkImage(
                      fit: BoxFit.cover,
                      imageUrl: user.imageUrl ?? '',
                      placeholder: (_, __) => Container(
                        color: colors.surfaceVariant,
                        child: Center(
                            child: CircularProgressIndicator(
                                color: colors.primary)),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: colors.surfaceVariant,
                        child: Icon(Icons.person, color: colors.textSecondary),
                      ),
                    ),
                  ),
                ),
                Container(
                  width: size.width * 0.4,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.black87, Colors.transparent],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '@${user.pseudo?.replaceAll("@", "") ?? "user"}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          UserBadgeWidget(user: user, size: 12),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.group, size: 9, color: colors.accent),
                          const SizedBox(width: 2),
                          Text(
                            _formatNumber(user.userAbonnesIds?.length ?? 0),
                            style:
                                TextStyle(color: colors.accent, fontSize: 9),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: double.infinity,
            height: 30,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: ElevatedButton(
                onPressed: onTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  "S'abonner",
                  style:
                      TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
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
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: Color(0xFF25D366)),
          ),
        ],
      ),
    );
  }
}
