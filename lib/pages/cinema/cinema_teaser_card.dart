import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../l10n/tr.dart';
import '../../services/api/cinema_api.dart';
import '../../theme/app_colors.dart';
import 'cinema_home_page.dart';
import 'cinema_widgets.dart';

/// Appel à Cartoon Cinéma dans les fils (accueil et vidéos, 21/11/2026) : quelques secondes d'un épisode gratuit, en boucle tant que la carte est
/// visible, puis « Regarder sur Cinéma ». La carte se masque d'elle-même s'il n'y a encore aucun épisode gratuit.
class CinemaTeaserCard extends StatefulWidget {
  const CinemaTeaserCard({super.key, this.vertical = false});

  /// Version plein écran pour le fil des vidéos.
  final bool vertical;

  /// Chaque carte demande son propre extrait : un épisode au hasard (gratuit ou à débloquer), pour varier d'une carte à l'autre.
  static Future<Map<String, dynamic>?> load() => CinemaApi.teaser().catchError((_) => null);

  @override
  State<CinemaTeaserCard> createState() => _CinemaTeaserCardState();
}

class _CinemaTeaserCardState extends State<CinemaTeaserCard> {
  /// 30 secondes d'extrait (décision du 21/11/2026), durée donnée par l'API.
  int get _clipSeconds => (_t?['teaser_seconds'] as num?)?.toInt() ?? 30;
  Map<String, dynamic>? _t;
  VideoPlayerController? _video;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    CinemaTeaserCard.load().then((t) {
      if (mounted && t != null) setState(() => _t = t);
    });
  }

  Future<void> _ensureVideo() async {
    if (_video != null || _t?['master_url'] == null) return;
    final c = VideoPlayerController.networkUrl(Uri.parse('${_t!['master_url']}'), formatHint: VideoFormat.hls);
    _video = c;
    try {
      await c.initialize();
      c.addListener(() {
        if (c.value.position.inSeconds >= _clipSeconds || c.value.isCompleted) c.seekTo(Duration.zero);
      });
      if (_visible) c.play();
      if (mounted) setState(() {});
    } catch (_) {}
  }

  void _onVisibility(VisibilityInfo info) {
    final v = info.visibleFraction > 0.5;
    if (v == _visible) return;
    _visible = v;
    if (v) {
      _ensureVideo();
      _video?.play();
    } else {
      _video?.pause();
    }
  }

  @override
  void dispose() {
    _video?.dispose();
    super.dispose();
  }

  void _open() => Navigator.push(context, MaterialPageRoute(builder: (_) => const CinemaHomePage(source: 'feed')));

  @override
  Widget build(BuildContext context) {
    final t = _t;
    if (t == null) return const SizedBox.shrink();
    final c = AppColors.of(context);
    final title = (t['title'] as Map?) ?? const {};
    final v = _video;
    final media = Stack(fit: StackFit.expand, children: [
      if (v != null && v.value.isInitialized)
        FittedBox(fit: BoxFit.cover, clipBehavior: Clip.hardEdge, child: SizedBox(width: v.value.size.width, height: v.value.size.height, child: VideoPlayer(v)))
      else
        CinemaImage(t['thumb_url'] as String? ?? title['banner_url'] as String?, radius: 0),
      const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x00000000), Color(0xB3000000)], stops: [.4, 1]))),
      Positioned(top: 10, left: 10, child: Row(children: [
        CinemaTag(context.tr('Ép. {a} gratuit', {'a': t['number']}), kind: 'free'),
        const SizedBox(width: 6),
        CinemaTag(context.tr('Extrait')),
      ])),
      Positioned(left: 12, right: 12, bottom: 12, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${title['title'] ?? ''}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
        Text('${t['name'] ?? ''} · ${cinemaDuration((t['duration_sec'] as num?)?.toInt() ?? 0)}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ])),
    ]);
    final button = SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFFD400), foregroundColor: const Color(0xFF121212), padding: const EdgeInsets.symmetric(vertical: 12)),
        onPressed: _open,
        icon: const Icon(Icons.play_arrow_rounded),
        label: Text(context.tr('Regarder sur Cinéma'), style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
    );
    return VisibilityDetector(
      key: ValueKey('cinema_teaser_${identityHashCode(this)}'),
      onVisibilityChanged: _onVisibility,
      child: widget.vertical
          ? GestureDetector(
              onTap: _open,
              child: Container(color: Colors.black, child: Stack(fit: StackFit.expand, children: [
                media,
                Positioned(left: 16, right: 16, bottom: 90, child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Row(children: [const CinemaLogo(size: 30), const SizedBox(width: 8), Text(context.tr('Cartoon Cinéma'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15))]),
                  const SizedBox(height: 10),
                  button,
                ])),
              ])),
            )
          : Container(
              color: c.surface,
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const CinemaLogo(size: 30),
                  const SizedBox(width: 8),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(context.tr('Cartoon Cinéma'), style: TextStyle(color: c.textPrimary, fontSize: 13, fontWeight: FontWeight.w800)),
                    Text(context.tr('Regardez gratuitement'), style: TextStyle(color: c.textSecondary, fontSize: 11)),
                  ])),
                  CinemaTag(context.tr('Nouveau'), kind: 'new'),
                ]),
                const SizedBox(height: 8),
                GestureDetector(onTap: _open, child: ClipRRect(borderRadius: BorderRadius.circular(14), child: AspectRatio(aspectRatio: 16 / 10, child: media))),
                const SizedBox(height: 8),
                button,
              ]),
            ),
    );
  }
}
