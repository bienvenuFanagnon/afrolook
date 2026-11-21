import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../../l10n/tr.dart';

/// Promo de fin d'épisode (21/11/2026) : la vidéo de notre formation, jouée EN ENTIER à la fin de chaque épisode, pour tout le monde
/// (Gold compris). Le bouton ouvre le lien de la formation dans le navigateur ; « Fermer » n'apparaît qu'à la fin de la vidéo.
/// Si la vidéo ne se charge pas, la page se ferme toute seule : on ne bloque jamais la personne.
Future<void> showCinemaEndPromo(BuildContext context, Map<String, dynamic> promo) async {
  final url = promo['video_url'] as String?;
  if (url == null || url.isEmpty) return;
  await Navigator.of(context).push(PageRouteBuilder(
    opaque: true,
    pageBuilder: (_, __, ___) => _CinemaEndPromoPage(videoUrl: url, linkUrl: promo['link_url'] as String?, label: (promo['label'] as String?) ?? 'Découvrir la formation'),
  ));
}

class _CinemaEndPromoPage extends StatefulWidget {
  const _CinemaEndPromoPage({required this.videoUrl, required this.linkUrl, required this.label});

  final String videoUrl;
  final String? linkUrl;
  final String label;

  @override
  State<_CinemaEndPromoPage> createState() => _CinemaEndPromoPageState();
}

class _CinemaEndPromoPageState extends State<_CinemaEndPromoPage> {
  VideoPlayerController? _video;
  bool _ended = false;
  Timer? _guard;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final c = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    try {
      await c.initialize().timeout(const Duration(seconds: 12));
    } catch (_) {
      await c.dispose();
      if (mounted) Navigator.of(context).pop();   // vidéo introuvable : on n'attend pas
      return;
    }
    if (!mounted) {
      await c.dispose();
      return;
    }
    _video = c;
    c.addListener(_onTick);
    await c.play();
    // garde-fou : la vidéo qui ne signale jamais sa fin laisse quand même apparaître « Fermer »
    _guard = Timer(c.value.duration + const Duration(seconds: 3), _end);
    setState(() {});
  }

  void _onTick() {
    final c = _video;
    if (c == null || !mounted) return;
    final d = c.value.duration;
    if (c.value.isCompleted || (d > Duration.zero && c.value.position >= d)) _end();
    if (mounted) setState(() {});
  }

  void _end() {
    if (_ended || !mounted) return;
    setState(() => _ended = true);
  }

  Future<void> _open() async {
    final link = widget.linkUrl;
    if (link == null) return;
    try {
      await launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  void dispose() {
    _guard?.cancel();
    _video?.removeListener(_onTick);
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _video;
    final ready = c != null && c.value.isInitialized;
    final left = ready ? (c.value.duration - c.value.position).inSeconds.clamp(0, 99) : 0;
    return PopScope(
      canPop: _ended,   // la vidéo se regarde jusqu'au bout
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(children: [
            Center(
              child: ready
                  ? AspectRatio(aspectRatio: c.value.aspectRatio > 0 ? c.value.aspectRatio : 16 / 9, child: VideoPlayer(c))
                  : const CircularProgressIndicator(color: Color(0xFFFFD400)),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: _ended
                  ? FilledButton.tonalIcon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                      label: Text(context.tr('Fermer')),
                    )
                  : ready
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(color: Colors.black.withValues(alpha: .6), borderRadius: BorderRadius.circular(8)),
                          child: Text(context.tr('{a} s', {'a': left}), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                        )
                      : const SizedBox.shrink(),
            ),
            if (widget.linkUrl != null)
              Positioned(
                left: 20,
                right: 20,
                bottom: 24,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD400),
                    foregroundColor: const Color(0xFF121212),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _open,
                  icon: const Icon(Icons.school_rounded),
                  label: Text(context.tr(widget.label), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}
