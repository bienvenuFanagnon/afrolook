import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../pages/LiveAgora/live_list_page.dart';
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
    if (!mounted) return;
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
        final lives = (liveProvider.activeLives.where((l) => l.isLive).toList()
              ..sort((a, b) => b.viewerCount.compareTo(a.viewerCount)))
            .take(3)
            .toList();

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
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => LiveListPage()),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: colors.danger.withAlpha(25),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colors.danger.withAlpha(100)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Voir plus',
                            style: TextStyle(
                              color: colors.danger,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 3),
                          Icon(Icons.arrow_forward_ios_rounded, color: colors.danger, size: 10),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 170,
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
    final likes = live.likeCount ?? 0;

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 115,
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.danger.withAlpha(80), width: 1.5),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Image de couverture plein widget
              _Avatar(url: live.hostImage),
              // Dégradé bas pour lisibilité du texte
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withAlpha(200)],
                      stops: const [0.4, 1.0],
                    ),
                  ),
                ),
              ),
              // Badge LIVE
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
              // Likes (bas droite)
              Positioned(
                bottom: 32,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.favorite_rounded, color: Colors.pinkAccent, size: 9),
                      const SizedBox(width: 2),
                      Text('$likes', style: const TextStyle(color: Colors.white, fontSize: 9)),
                    ],
                  ),
                ),
              ),
              // Pseudo + titre (bas)
              Positioned(
                left: 6,
                right: 6,
                bottom: 6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '@${live.hostName ?? ''}',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (live.title.isNotEmpty)
                      Text(
                        live.title,
                        style: TextStyle(color: Colors.white.withAlpha(200), fontSize: 9),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url});
  final String? url;

  @override
  Widget build(BuildContext context) {
    final hasUrl = url != null && url!.isNotEmpty;
    return hasUrl
        ? Image.network(url!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _placeholder())
        : _placeholder();
  }

  Widget _placeholder() => Container(
        color: Colors.grey[800],
        child: const Icon(Icons.person_rounded, color: Colors.white54, size: 36),
      );
}
