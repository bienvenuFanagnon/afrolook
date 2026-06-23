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

  /// ID de l'utilisateur connecté (pour vérifier l'état d'abonnement).
  final String currentUserId;

  /// IDs des utilisateurs à qui l'utilisateur courant a déjà envoyé une invitation.
  final Set<String> pendingInvitationUserIds;

  const FeedProfilesSection({
    Key? key,
    required this.users,
    this.isLoading = false,
    required this.title,
    required this.seeAllLabel,
    required this.onShowProfile,
    required this.currentUserId,
    this.pendingInvitationUserIds = const {},
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
            itemBuilder: (_, i) {
              final user = users[i];
              final isSubscribed =
                  user.userAbonnesIds?.contains(currentUserId) ?? false;
              final hasPendingInvitation =
                  pendingInvitationUserIds.contains(user.id);

              return Container(
                margin:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                width: size.width * 0.35,
                child: _ProfileCard(
                  user: user,
                  size: size,
                  isSubscribed: isSubscribed,
                  hasPendingInvitation: hasPendingInvitation,
                  onTap: () => onShowProfile(user),
                  onSubscribe: () => onShowProfile(user),
                ),
              );
            },
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
  final VoidCallback onSubscribe;
  final bool isSubscribed;
  final bool hasPendingInvitation;

  const _ProfileCard({
    required this.user,
    required this.size,
    required this.onTap,
    required this.onSubscribe,
    required this.isSubscribed,
    required this.hasPendingInvitation,
  });

  String _formatNumber(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }

  bool get _hasBadge =>
      (user.isVerify ?? false) ||
      (user.officialBadge ?? false) ||
      (user.abonnement?.estPremium ?? false);

  String _flagEmoji(String code) {
    return code.toUpperCase().codeUnits
        .map((c) => String.fromCharCode(c + 127397))
        .join();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final rawCode = user.countryData?['countryCode']?.toUpperCase();
    final countryFlag = rawCode != null && rawCode.length == 2
        ? _flagEmoji(rawCode)
        : null;
    final cardW = size.width * 0.4;
    final imgH = size.height * 0.18;

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          // ── Zone image ──────────────────────────────────────────────────
          GestureDetector(
            onTap: onTap,
            child: SizedBox(
              width: cardW,
              height: imgH,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Photo de profil
                  ClipRRect(
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
                              color: colors.primary, strokeWidth: 2),
                        ),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: colors.surfaceVariant,
                        child: Icon(Icons.person,
                            color: colors.textSecondary, size: 36),
                      ),
                    ),
                  ),

                  // Gradient bas → pseudo + abonnés
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(8, 18, 8, 6),
                      decoration: const BoxDecoration(
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(0),
                          topRight: Radius.circular(0),
                        ),
                        gradient: LinearGradient(
                          colors: [Colors.black87, Colors.transparent],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '@${user.pseudo?.replaceAll("@", "") ?? "user"}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(Icons.group,
                                  size: 9, color: colors.accent),
                              const SizedBox(width: 2),
                              Text(
                                _formatNumber(
                                    user.userAbonnesIds?.length ?? 0),
                                style: TextStyle(
                                    color: colors.accent, fontSize: 9),
                              ),
                              if (countryFlag != null) ...[
                                const SizedBox(width: 4),
                                Text(
                                  countryFlag,
                                  style: const TextStyle(fontSize: 10),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Badge en capsule haut-droite
                  if (_hasBadge)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: UserBadgeWidget(
                            user: user, size: 11, withBackground: false),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ── Bouton d'action ─────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 30,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: _buildActionButton(context, colors),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, AppColors colors) {
    if (isSubscribed) {
      return ElevatedButton.icon(
        onPressed: null,
        icon: const Icon(Icons.check, size: 10),
        label: const Text(
          'Abonné',
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          disabledBackgroundColor: colors.surfaceVariant,
          disabledForegroundColor: colors.textSecondary,
          padding: const EdgeInsets.symmetric(vertical: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: colors.border),
          ),
        ),
      );
    }

    if (hasPendingInvitation) {
      return ElevatedButton.icon(
        onPressed: null,
        icon: const Icon(Icons.hourglass_empty, size: 10),
        label: const Text(
          'Invité',
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          disabledBackgroundColor: Colors.orange.withValues(alpha: 0.15),
          disabledForegroundColor: Colors.orange,
          padding: const EdgeInsets.symmetric(vertical: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: Colors.orange.withValues(alpha: 0.4)),
          ),
        ),
      );
    }

    return ElevatedButton(
      onPressed: onSubscribe,
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
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
