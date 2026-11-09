import 'dart:io';

import '../../../widgets/reply_banner.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../l10n/tr.dart';
import '../../../theme/app_colors.dart';

/// Aperçu du montage terminé, avant d'aller plus loin : on voit et on entend exactement ce qui sera publié (vidéo avec son, ou image),
/// puis on choisit de revenir modifier ou de poursuivre. Rend vrai pour « Poursuivre », faux (ou null) pour « Modifier ».
class MontagePreviewPage extends StatefulWidget {
  const MontagePreviewPage({super.key, required this.file, required this.video, this.exact = false});

  final File file;
  final bool video;

  /// Aperçu « rendu exact » du serveur (basse définition) : un seul bouton « Fermer », rien à poursuivre.
  final bool exact;

  @override
  State<MontagePreviewPage> createState() => _MontagePreviewPageState();
}

class _MontagePreviewPageState extends State<MontagePreviewPage> {
  VideoPlayerController? _vc;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    if (widget.video) _init();
  }

  Future<void> _init() async {
    final v = VideoPlayerController.file(widget.file);
    _vc = v;
    try {
      await v.initialize();
      await v.setLooping(true);
      await v.setVolume(1);
      await v.play();
    } catch (_) {
      _failed = true;
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _vc?.dispose();
    super.dispose();
  }

  Widget _media() {
    if (!widget.video) {
      return Center(child: Image.file(widget.file, fit: BoxFit.contain, errorBuilder: (_, __, ___) => _error()));
    }
    final v = _vc;
    if (_failed) return _error();
    if (v == null || !v.value.isInitialized) return const Center(child: CircularProgressIndicator(color: Colors.white70));
    return GestureDetector(
      key: const ValueKey('preview_video'),
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => v.value.isPlaying ? v.pause() : v.play()),
      child: Stack(alignment: Alignment.center, children: [
        Center(child: AspectRatio(aspectRatio: v.value.aspectRatio, child: VideoPlayer(v))),
        if (!v.value.isPlaying) const Icon(Icons.play_circle_fill_rounded, size: 72, color: Colors.white70),
      ]),
    );
  }

  Widget _error() => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Text(context.tr('L\'aperçu ne peut pas s\'afficher, mais ton montage est prêt. Tu peux poursuivre.'), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, height: 1.4)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final inset = MediaQuery.of(context).padding;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(fit: StackFit.expand, children: [
        _media(),
        Positioned(
          top: inset.top + 10,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(color: Colors.black.withOpacity(0.55), borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              const Icon(Icons.visibility_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(widget.exact ? context.tr('Rendu exact en basse définition (6 s au plus). La vidéo finale sera plus nette.') : context.tr('Voici ton montage. Vérifie-le avant de continuer.'), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700))),
            ]),
          ),
        ),
        Positioned(top: inset.top + 66, left: 16, right: 16, child: const Align(alignment: Alignment.centerLeft, child: ReplyBanner())),
        Positioned(
          left: 16,
          right: 16,
          bottom: 14 + inset.bottom,
          child: widget.exact
              ? SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    key: const ValueKey('preview_close'),
                    onPressed: () => Navigator.of(context).pop(false),
                    style: FilledButton.styleFrom(backgroundColor: c.accent, foregroundColor: c.onAccent, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    child: Text(context.tr('Fermer'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                  ),
                )
              : Row(children: [
            Expanded(
              child: OutlinedButton(
                key: const ValueKey('preview_edit'),
                onPressed: () => Navigator.of(context).pop(false),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white54), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                child: Text(context.tr('Modifier'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: FilledButton(
                key: const ValueKey('preview_continue'),
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(backgroundColor: c.accent, foregroundColor: c.onAccent, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                child: Text(context.tr('Poursuivre'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}
