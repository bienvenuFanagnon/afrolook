import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../models/model_data.dart';
import '../../../pages/canaux/detailsCanal.dart';
import '../../../pages/listeUserLikepage.dart';
import '../../../services/active_creators_service.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/user_badge_widget.dart';

/// Section horizontale de profils suggérés.
///
/// [roundCards] = true  → cartes rondes style "stories" (Créateurs actifs)
/// [roundCards] = false → cartes rectangulaires classiques (Profils à découvrir)
class FeedProfilesSection extends StatelessWidget {
  final List<UserData> users;
  final bool isLoading;
  final String title;

  // ── Params design classique ──
  final String seeAllLabel;
  final void Function(UserData) onShowProfile;
  final String currentUserId;
  final Set<String> pendingInvitationUserIds;

  // ── Params communs ──
  final Map<String, int> unseenCounts;
  final VoidCallback? onSeeAllOverride;
  final void Function(UserData)? onTapCard;

  // ── Mode rond ──
  final bool roundCards;

  /// Canaux récemment actifs à afficher après les créateurs (mode rond uniquement).
  final List<ActiveCanal> recentCanaux;

  /// Timestamp d'activité par créateur pour le tri mixte (microsecondes).
  final Map<String, int> creatorLastActivityUs;

  const FeedProfilesSection({
    Key? key,
    required this.users,
    this.isLoading = false,
    required this.title,
    this.seeAllLabel = 'Voir tout',
    required this.onShowProfile,
    this.currentUserId = '',
    this.pendingInvitationUserIds = const {},
    this.unseenCounts = const {},
    this.onSeeAllOverride,
    this.onTapCard,
    this.roundCards = false,
    this.recentCanaux = const <ActiveCanal>[],
    this.creatorLastActivityUs = const {},
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (isLoading || (users.isEmpty && recentCanaux.isEmpty)) {
      return const SizedBox.shrink();
    }

    final size = MediaQuery.of(context).size;

    final colors = AppColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── En-tête titre + bouton ─────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
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
                  onPressed: onSeeAllOverride ??
                      () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => UsersListPage()),
                          ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        roundCards ? 'Voir plus' : seeAllLabel,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 11),
                      ),
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

        // ── Liste horizontale ──────────────────────────────────────────────
        if (roundCards)
          _RoundList(
            users: users,
            unseenCounts: unseenCounts,
            canaux: recentCanaux,
            creatorLastActivityUs: creatorLastActivityUs,
            onTap: onTapCard ?? onShowProfile,
          )
        else
          _RectList(
            users: users,
            size: size,
            colors: colors,
            currentUserId: currentUserId,
            pendingInvitationUserIds: pendingInvitationUserIds,
            unseenCounts: unseenCounts,
            onTap: onTapCard ?? onShowProfile,
            onSubscribe: onShowProfile,
          ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// MODE ROND — cartes stories (Créateurs actifs / récents)
// ═══════════════════════════════════════════════════════════════════════════

// ── Item unifié pour le tri mixte round cards ─────────────────────────────────

class _RoundItem {
  final UserData? user;
  final ActiveCanal? canal;
  final int unseen;
  final int sortUs;

  _RoundItem.user(UserData u, int unseenCount, int actUs)
      : user = u,
        canal = null,
        unseen = unseenCount,
        sortUs = actUs;

  _RoundItem.canal(ActiveCanal c)
      : canal = c,
        user = null,
        unseen = 0,
        sortUs = c.lastActivityUs;

  bool get isUser => user != null;
}

class _RoundList extends StatelessWidget {
  final List<UserData> users;
  final Map<String, int> unseenCounts;
  final List<ActiveCanal> canaux;
  final Map<String, int> creatorLastActivityUs;
  final void Function(UserData) onTap;

  const _RoundList({
    required this.users,
    required this.unseenCounts,
    required this.onTap,
    this.canaux = const <ActiveCanal>[],
    this.creatorLastActivityUs = const {},
  });

  @override
  Widget build(BuildContext context) {
    // Fusionner créateurs et canaux, triés par date décroissante.
    // Les créateurs avec posts non vus passent en tête.
    final items = <_RoundItem>[
      for (final u in users)
        _RoundItem.user(
          u,
          unseenCounts[u.id] ?? 0,
          creatorLastActivityUs[u.id] ?? 0,
        ),
      for (final c in canaux) _RoundItem.canal(c),
    ]..sort((a, b) {
        // Non vus en premier
        final aUnseen = a.unseen > 0 ? 1 : 0;
        final bUnseen = b.unseen > 0 ? 1 : 0;
        if (bUnseen != aUnseen) return bUnseen - aUnseen;
        // Puis par date d'activité
        return b.sortUs.compareTo(a.sortUs);
      });

    return SizedBox(
      height: 108,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: items.length,
        itemBuilder: (ctx, i) {
          final item = items[i];
          if (item.isUser) {
            return _RoundCard(
              user: item.user!,
              unseenCount: item.unseen,
              onTap: () => onTap(item.user!),
            );
          }
          final activeCanal = item.canal!;
          return _CanalRoundCard(
            activeCanal: activeCanal,
            onTap: () => Navigator.push(
              ctx,
              MaterialPageRoute(
                builder: (_) => CanalDetails(canal: activeCanal.canal),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RoundCard extends StatelessWidget {
  final UserData user;
  final int unseenCount;
  final VoidCallback onTap;

  const _RoundCard({
    required this.user,
    required this.unseenCount,
    required this.onTap,
  });

  String _formatCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final pseudo =
        '@${user.pseudo?.replaceAll('@', '') ?? 'user'}';
    final followers =
        _formatCount(user.userAbonnesIds?.length ?? user.abonnes ?? 0);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 74,
        margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Avatar + ring + badge
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // Anneau de couleur si posts non vus
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: unseenCount > 0
                        ? const LinearGradient(
                            colors: [Color(0xFFFFD700), Color(0xFF8B0000)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    border: unseenCount == 0
                        ? Border.all(
                            color: colors.border,
                            width: 1.5,
                          )
                        : null,
                  ),
                  padding: const EdgeInsets.all(2.5),
                  child: CircleAvatar(
                    radius: 28,
                    backgroundColor: colors.surfaceVariant,
                    backgroundImage: user.imageUrl != null &&
                            user.imageUrl!.isNotEmpty
                        ? CachedNetworkImageProvider(user.imageUrl!)
                        : null,
                    child: user.imageUrl == null || user.imageUrl!.isEmpty
                        ? Icon(Icons.person,
                            color: colors.textSecondary, size: 28)
                        : null,
                  ),
                ),

                // Badge nombre de posts non vus
                if (unseenCount > 0)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: colors.primary,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: colors.surface, width: 1.5),
                      ),
                      child: Text(
                        '$unseenCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                // Badge vérification / premium (bas-droite de l'avatar)
                Positioned(
                  bottom: 0,
                  right: 2,
                  child: UserBadgeWidget(
                      user: user, size: 12, withBackground: true),
                ),
              ],
            ),

            const SizedBox(height: 3),

            // Pseudo
            Text(
              pseudo,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 10,
                fontWeight:
                    unseenCount > 0 ? FontWeight.bold : FontWeight.normal,
              ),
            ),

            // Abonnés
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.group, size: 9, color: colors.textSecondary),
                const SizedBox(width: 2),
                Text(
                  followers,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CARTE CANAL RONDE
// ═══════════════════════════════════════════════════════════════════════════

class _CanalRoundCard extends StatelessWidget {
  final ActiveCanal activeCanal;
  final VoidCallback onTap;

  const _CanalRoundCard({required this.activeCanal, required this.onTap});

  Canal get canal => activeCanal.canal;

  String _formatCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final name = canal.titre ?? 'Canal';
    final followers = _formatCount(canal.usersSuiviId?.length ?? canal.suivi ?? 0);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 74,
        margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Avatar canal avec badge "Canal" distinctif
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF8B0000),
                      width: 2,
                    ),
                  ),
                  padding: const EdgeInsets.all(2.5),
                  child: CircleAvatar(
                    radius: 28,
                    backgroundColor: colors.surfaceVariant,
                    backgroundImage: canal.urlImage != null &&
                            canal.urlImage!.isNotEmpty
                        ? CachedNetworkImageProvider(canal.urlImage!)
                        : null,
                    child: canal.urlImage == null || canal.urlImage!.isEmpty
                        ? Icon(Icons.campaign_rounded,
                            color: colors.textSecondary, size: 28)
                        : null,
                  ),
                ),
                // Étiquette "Canal" en bas
                Positioned(
                  bottom: -2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B0000),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Canal',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            // Nom du canal
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
            // Abonnés
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.group, size: 9, color: colors.textSecondary),
                const SizedBox(width: 2),
                Text(
                  followers,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// MODE RECTANGULAIRE — cartes classiques (Profils à découvrir, HomeSport…)
// ═══════════════════════════════════════════════════════════════════════════

class _RectList extends StatelessWidget {
  final List<UserData> users;
  final Size size;
  final AppColors colors;
  final String currentUserId;
  final Set<String> pendingInvitationUserIds;
  final Map<String, int> unseenCounts;
  final void Function(UserData) onTap;
  final void Function(UserData) onSubscribe;

  const _RectList({
    required this.users,
    required this.size,
    required this.colors,
    required this.currentUserId,
    required this.pendingInvitationUserIds,
    required this.unseenCounts,
    required this.onTap,
    required this.onSubscribe,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: size.height * 0.25,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: users.length,
        itemBuilder: (_, i) {
          final user = users[i];
          final isSubscribed =
              user.userAbonnesIds?.contains(currentUserId) ?? false;
          final hasPending = pendingInvitationUserIds.contains(user.id);
          final unseen = unseenCounts[user.id] ?? 0;
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            width: size.width * 0.35,
            child: _RectCard(
              user: user,
              size: size,
              isSubscribed: isSubscribed,
              hasPendingInvitation: hasPending,
              unseenCount: unseen,
              onTap: () => onTap(user),
              onSubscribe: () => onSubscribe(user),
            ),
          );
        },
      ),
    );
  }
}

class _RectCard extends StatelessWidget {
  final UserData user;
  final Size size;
  final VoidCallback onTap;
  final VoidCallback onSubscribe;
  final bool isSubscribed;
  final bool hasPendingInvitation;
  final int unseenCount;

  const _RectCard({
    required this.user,
    required this.size,
    required this.onTap,
    required this.onSubscribe,
    required this.isSubscribed,
    required this.hasPendingInvitation,
    this.unseenCount = 0,
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

  String _flagEmoji(String code) => code.toUpperCase().codeUnits
      .map((c) => String.fromCharCode(c + 127397))
      .join();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final rawCode = user.countryData?['countryCode']?.toUpperCase();
    final countryFlag =
        rawCode != null && rawCode.length == 2 ? _flagEmoji(rawCode) : null;
    final cardW = size.width * 0.4;
    final imgH = size.height * 0.18;

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: unseenCount > 0
              ? colors.primary.withValues(alpha: 0.6)
              : colors.primary.withValues(alpha: 0.25),
          width: unseenCount > 0 ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: onTap,
            child: SizedBox(
              width: cardW,
              height: imgH,
              child: Stack(
                fit: StackFit.expand,
                children: [
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
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(8, 18, 8, 6),
                      decoration: const BoxDecoration(
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
                                Text(countryFlag,
                                    style:
                                        const TextStyle(fontSize: 10)),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
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
                  if (unseenCount > 0)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: colors.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$unseenCount nouveau${unseenCount > 1 ? 'x' : ''}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
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
        label: const Text('Abonné',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
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
        label: const Text('Invité',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: const Text("S'abonner",
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}
