import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../pages/LiveAgora/livePage.dart';
import '../../../pages/LiveAgora/livesAgora.dart';
import '../../../providers/authProvider.dart';
import '../../../theme/app_colors.dart';

/// Carousel horizontal des lives actifs — affiché dans les feeds quand au moins un live est en cours.
class FeedLiveSection extends StatefulWidget {
  const FeedLiveSection({super.key});

  @override
  State<FeedLiveSection> createState() => _FeedLiveSectionState();
}

class _FeedLiveSectionState extends State<FeedLiveSection> {
  bool _fetched = false;
  Timer? _pulseTimer;
  bool _pulseOn = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    _pulseTimer = Timer.periodic(const Duration(milliseconds: 800), (_) {
      if (mounted) setState(() => _pulseOn = !_pulseOn);
    });
  }

  @override
  void dispose() {
    _pulseTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted || _fetched) return;
    _fetched = true;
    await context.read<LiveProvider>().fetchActiveLives();
  }

  void _joinLive(BuildContext context, PostLive live) {
    if (live.liveId == null) return;
    final auth = context.read<UserAuthProvider>();
    final myId = auth.loginUserData.id ?? '';
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LivePage(
          liveId: live.liveId!,
          postLive: live,
          isHost: live.hostId == myId,
          hostName: live.hostName ?? '',
          hostImage: live.hostImage ?? '',
          isInvited: live.invitedUsers.contains(myId),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LiveProvider>(
      builder: (context, liveProvider, _) {
        final lives = liveProvider.activeLives.where((l) => l.isLive).toList()
          ..sort((a, b) => b.viewerCount.compareTo(a.viewerCount));

        if (lives.isEmpty) return const SizedBox.shrink();

        final colors = AppColors.of(context);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              child: Row(
                children: [
                  AnimatedOpacity(
                    opacity: _pulseOn ? 1.0 : 0.2,
                    duration: const Duration(milliseconds: 400),
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: colors.danger,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'En direct',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: colors.danger,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${lives.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 140,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: lives.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, i) => _LiveCard(
                  live: lives[i],
                  colors: colors,
                  onTap: () => _joinLive(context, lives[i]),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }
}

class _LiveCard extends StatelessWidget {
  const _LiveCard({
    required this.live,
    required this.colors,
    required this.onTap,
  });

  final PostLive live;
  final AppColors colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isPaid = live.isPaidLive;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 110,
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.danger.withAlpha(80), width: 1.5),
        ),
        child: Column(
          children: [
            // Avatar + badge LIVE
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                  child: _Avatar(url: live.hostImage, size: 70),
                ),
                // Badge LIVE rouge
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: colors.danger,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                  ),
                ),
                // Badge payant
                if (isPaid)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.amber[700],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('💰', style: TextStyle(fontSize: 9)),
                    ),
                  ),
                // Viewers
                Positioned(
                  bottom: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.remove_red_eye, color: Colors.white, size: 9),
                        const SizedBox(width: 2),
                        Text(
                          '${live.viewerCount}',
                          style: const TextStyle(color: Colors.white, fontSize: 9),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // Infos texte
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      live.hostName ?? '',
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                    if (live.title.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        live.title,
                        style: TextStyle(color: colors.textSecondary, fontSize: 10),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, required this.size});
  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final hasUrl = url != null && url!.isNotEmpty;
    return SizedBox(
      width: double.infinity,
      height: size,
      child: hasUrl
          ? Image.network(
              url!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _placeholder(),
            )
          : _placeholder(),
    );
  }

  Widget _placeholder() => Container(
        color: Colors.grey[800],
        child: const Icon(Icons.person_rounded, color: Colors.white54, size: 28),
      );
}
