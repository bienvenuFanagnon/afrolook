import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/tr.dart';
import '../../providers/authProvider.dart';
import '../../theme/app_colors.dart';
import '../LiveAgora/create_live_page.dart';
import '../LiveAgora/livePage.dart';
import '../LiveAgora/livesAgora.dart';
import 'video_chrome.dart';

/// Onglet « Lives » de la page des vidéos verticales : les lives en cours défilent en plein écran, comme les vidéos.
/// Toucher un live le rejoint. Quand il n'y a aucun live, la page invite la personne à lancer le sien.
class VerticalLivesView extends StatefulWidget {
  const VerticalLivesView({super.key, required this.onBackToVideos});

  final VoidCallback onBackToVideos;

  @override
  State<VerticalLivesView> createState() => _VerticalLivesViewState();
}

class _VerticalLivesViewState extends State<VerticalLivesView> {
  final PageController _controller = PageController();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load(reset: true));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    final lp = context.read<LiveProvider>();
    try {
      await lp.fetchActiveLivesBatch(reset: reset);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  List<PostLive> _live(LiveProvider lp) => lp.activeLives.where((l) => l.isLive && l.liveId != null).toList();

  void _join(PostLive live) {
    final auth = context.read<UserAuthProvider>();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LivePage(
          liveId: live.liveId!,
          isHost: live.hostId == auth.userId,
          hostName: live.hostName ?? '',
          hostImage: live.hostImage ?? '',
          isInvited: live.invitedUsers.contains(auth.userId),
          postLive: live,
        ),
      ),
    );
  }

  void _start() => Navigator.push(context, MaterialPageRoute(builder: (_) => CreateLivePage()));

  @override
  Widget build(BuildContext context) {
    final lp = context.watch<LiveProvider>();
    final lives = _live(lp);
    if (_loading && lives.isEmpty) {
      return const ColoredBox(color: Colors.black, child: Center(child: CircularProgressIndicator(color: Colors.white)));
    }
    if (lives.isEmpty) return _EmptyLives(onStart: _start, onVideos: widget.onBackToVideos);
    return Stack(children: [
      PageView.builder(
        controller: _controller,
        scrollDirection: Axis.vertical,
        physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
        itemCount: lives.length,
        onPageChanged: (i) {
          if (i >= lives.length - 2) _load();
        },
        itemBuilder: (_, i) => _LivePage(live: lives[i], onJoin: () => _join(lives[i])),
      ),
      Positioned(
        right: 10,
        bottom: 62 + MediaQuery.of(context).padding.bottom,
        child: VideoRailButton(icon: Icons.videocam_outlined, label: tr('Lancer'), onTap: _start),
      ),
    ]);
  }
}

class _LivePage extends StatelessWidget {
  const _LivePage({required this.live, required this.onJoin});
  final PostLive live;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final cover = (live.coverImage?.isNotEmpty == true) ? live.coverImage! : (live.hostImage ?? '');
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onJoin,
      child: Stack(fit: StackFit.expand, children: [
        const ColoredBox(color: Colors.black),
        if (cover.isNotEmpty) CachedNetworkImage(imageUrl: cover, fit: BoxFit.cover, errorWidget: (_, __, ___) => const SizedBox.shrink()),
        const VideoShade(),
        Positioned(
          top: MediaQuery.of(context).padding.top + 60,
          left: 12,
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(color: c.danger, borderRadius: BorderRadius.circular(99)),
              child: Text(tr('EN DIRECT'), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(99)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.remove_red_eye_outlined, size: 14, color: Colors.white),
                const SizedBox(width: 4),
                Text('${live.viewerCount}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
              ]),
            ),
          ]),
        ),
        Positioned(
          left: 12,
          right: 74,
          bottom: 20 + MediaQuery.of(context).padding.bottom,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              CircleAvatar(radius: 22, backgroundColor: Colors.white24, backgroundImage: (live.hostImage ?? '').isNotEmpty ? CachedNetworkImageProvider(live.hostImage!) : null),
              const SizedBox(width: 10),
              Expanded(
                child: Text('@${live.hostName ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800, shadows: [Shadow(color: Color(0xCC000000), blurRadius: 4)])),
              ),
            ]),
            if (live.title.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(live.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.3, shadows: [Shadow(color: Color(0xCC000000), blurRadius: 4)])),
            ],
            const SizedBox(height: 14),
            SizedBox(
              height: 46,
              child: FilledButton.icon(
                onPressed: onJoin,
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(tr('Rejoindre le live'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                style: FilledButton.styleFrom(backgroundColor: c.accent, foregroundColor: c.onAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(23))),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _EmptyLives extends StatelessWidget {
  const _EmptyLives({required this.onStart, required this.onVideos});
  final VoidCallback onStart;
  final VoidCallback onVideos;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const VideoPill(size: 76, child: Icon(Icons.videocam_outlined, size: 38, color: Colors.white)),
          const SizedBox(height: 22),
          Text(tr('Aucun live en ce moment'), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(tr('Sois le premier : lance ton live et ta communauté te rejoint, avec cadeaux et vente en direct.'), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4)),
          const SizedBox(height: 26),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              onPressed: onStart,
              style: FilledButton.styleFrom(backgroundColor: c.accent, foregroundColor: c.onAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25))),
              child: Text(tr('Lancer un live'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ),
          ),
          TextButton(onPressed: onVideos, child: Text(tr('Voir les vidéos'), style: const TextStyle(color: Colors.white70))),
        ]),
      ),
    );
  }
}
