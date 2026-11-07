import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../l10n/tr.dart';
import '../../services/api/chroniques_api.dart';
import '../../theme/app_colors.dart';
import '../videos/video_chrome.dart';
import 'chroniqueform.dart' show ChroniqueType;
import 'chronique_commerce.dart';

/// Aperçu avant publication d'une chronique : l'écran de lecture tel que le verront les abonnés (contenu, texte, carte de vente), avec la durée de 24 h et le coût.
/// Rend vrai si la personne choisit « Publier », faux (ou null) pour « Modifier ».
class ChroniquePreviewPage extends StatefulWidget {
  const ChroniquePreviewPage({
    super.key,
    required this.type,
    required this.pseudo,
    this.avatarUrl,
    this.text,
    this.backgroundColor,
    this.mediaFile,
    this.coverFile,
    this.videoController,
    this.commerce,
    this.musicTitle,
    this.textX,
    this.textY,
  });

  final ChroniqueType type;
  final String pseudo;
  final String? avatarUrl;
  final String? text;
  final Color? backgroundColor;
  final File? mediaFile;
  final File? coverFile;
  final VideoPlayerController? videoController;
  final Map<String, dynamic>? commerce;
  final String? musicTitle;
  final double? textX;
  final double? textY;

  @override
  State<ChroniquePreviewPage> createState() => _ChroniquePreviewPageState();
}

class _ChroniquePreviewPageState extends State<ChroniquePreviewPage> {
  Map<String, dynamic>? _fee;

  @override
  void initState() {
    super.initState();
    widget.videoController?.play();
    ChroniquesApi.fee().then((f) {
      if (mounted) setState(() => _fee = f);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    widget.videoController?.pause();
    super.dispose();
  }

  Widget _content(BuildContext context) {
    final t = widget.text?.trim() ?? '';
    switch (widget.type) {
      case ChroniqueType.TEXT:
        return Container(
          color: widget.backgroundColor ?? const Color(0xFF1A1A2E),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Text(t, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800, height: 1.25)),
        );
      case ChroniqueType.IMAGE:
        return Stack(fit: StackFit.expand, children: [
          const ColoredBox(color: Colors.black),
          if (widget.mediaFile != null) Image.file(widget.mediaFile!, fit: BoxFit.contain),
          if (t.isNotEmpty) _overlayText(t),
        ]);
      case ChroniqueType.VIDEO:
        final vc = widget.videoController;
        return Stack(fit: StackFit.expand, children: [
          const ColoredBox(color: Colors.black),
          if (vc != null && vc.value.isInitialized) Center(child: AspectRatio(aspectRatio: vc.value.aspectRatio, child: VideoPlayer(vc))),
          if (t.isNotEmpty) _overlayText(t),
        ]);
      case ChroniqueType.AUDIO:
        return Container(
          color: const Color(0xFF0F1A14),
          alignment: Alignment.center,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: SizedBox(
                width: 220,
                height: 220,
                child: widget.coverFile != null ? Image.file(widget.coverFile!, fit: BoxFit.cover) : const ColoredBox(color: Color(0xFF1B8A3C), child: Icon(Icons.graphic_eq_rounded, size: 80, color: Colors.white)),
              ),
            ),
            if (t.isNotEmpty) Padding(padding: const EdgeInsets.fromLTRB(24, 20, 24, 0), child: Text(t, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700))),
          ]),
        );
    }
  }

  /// Texte posé sur l'image ou la vidéo, à l'endroit choisi.
  Widget _overlayText(String t) => Align(
        alignment: Alignment(((widget.textX ?? 0.5) * 2) - 1, ((widget.textY ?? 0.75) * 2) - 1),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 18),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
          child: Text(t, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
        ),
      );

  String _costLine(BuildContext context) {
    final f = _fee;
    if (f == null) return context.tr('Chronique publiée pendant 24 h');
    final due = f['fee_due'] == true;
    final coins = (f['fee_coins'] as num?)?.toInt() ?? 0;
    final left = f['free_left'];
    if (due && coins > 0) return context.tr('Chronique supplémentaire : {a} pièces · publiée pendant 24 h', {'a': '$coins'});
    if (left == null) return context.tr('Chronique publiée pendant 24 h');
    return context.tr('Chronique gratuite ({a} restante(s)) · publiée pendant 24 h', {'a': '$left'});
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final inset = MediaQuery.of(context).padding;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(fit: StackFit.expand, children: [
        _content(context),
        const Positioned.fill(child: IgnorePointer(child: VideoShade())),
        // barre de progression et en-tête de la lecture réelle
        Positioned(top: inset.top + 8, left: 10, right: 10, child: Row(children: [Expanded(child: Container(height: 2.5, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(3))))])),
        Positioned(
          top: inset.top + 20,
          left: 10,
          right: 10,
          child: Row(children: [
            CircleAvatar(radius: 15, backgroundColor: Colors.white24, backgroundImage: (widget.avatarUrl ?? '').isNotEmpty ? NetworkImage(widget.avatarUrl!) : null),
            const SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.pseudo, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
              Text(context.tr('maintenant'), style: const TextStyle(color: Colors.white70, fontSize: 10)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), borderRadius: BorderRadius.circular(99), border: Border.all(color: Colors.white24)),
              child: Text(context.tr('Disparaît dans 24 h'), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
            ),
          ]),
        ),
        // bandeau « Aperçu »
        Positioned(
          top: inset.top + 60,
          left: 12,
          right: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.95), borderRadius: BorderRadius.circular(14)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(context.tr('Aperçu avant publication'), style: const TextStyle(color: Color(0xFF14201A), fontSize: 13, fontWeight: FontWeight.w800)),
              Text(context.tr('Voici exactement ce que tes abonnés verront.'), style: const TextStyle(color: Color(0xFF444444), fontSize: 11.5)),
              if ((widget.musicTitle ?? '').isNotEmpty) Padding(padding: const EdgeInsets.only(top: 3), child: Text('♪ ${widget.musicTitle}', style: const TextStyle(color: Color(0xFF444444), fontSize: 11))),
            ]),
          ),
        ),
        // carte de vente (chronique business) et panneau de publication
        Positioned(
          left: 12,
          right: 12,
          bottom: 12 + inset.bottom,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (widget.commerce != null) ...[ChroniqueCommerceCard(commerce: widget.commerce!, preview: true), const SizedBox(height: 10)],
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.97), borderRadius: BorderRadius.circular(22)),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(_costLine(context), textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF555555), fontSize: 11.5)),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF14201A), side: const BorderSide(color: Color(0xFFBBBBBB)), padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                      child: Text(context.tr('Modifier'), style: const TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: FilledButton.styleFrom(backgroundColor: c.accent, foregroundColor: c.onAccent, padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                      child: Text(context.tr('Publier'), style: const TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ),
                ]),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }
}
