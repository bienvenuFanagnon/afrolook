import 'dart:io';

import 'package:flutter/material.dart';

import '../../l10n/tr.dart';
import '../../services/face_filters.dart';
import '../../theme/app_colors.dart';

/// Aperçu de la photo prise AVANT de la garder : on essaie les filtres de visage d'un toucher et on voit tout de suite le résultat.
/// Rend le fichier à utiliser (avec ou sans filtre), ou null si la personne choisit de reprendre la photo.
class FaceFilterPage extends StatefulWidget {
  const FaceFilterPage({super.key, required this.path, required this.size, required this.faces, this.initial = FaceFilter.none});

  final String path; // photo redressée
  final Size size;
  final List<FaceBox> faces;

  /// Filtre déjà choisi dans la caméra (affiché tout de suite).
  final FaceFilter initial;

  @override
  State<FaceFilterPage> createState() => _FaceFilterPageState();
}

class _FaceFilterPageState extends State<FaceFilterPage> {
  late FaceFilter _filter = widget.initial;
  bool _busy = false;

  Future<void> _use() async {
    setState(() => _busy = true);
    final r = await FaceFilters.apply(widget.path, widget.faces, _filter);
    if (mounted) Navigator.pop(context, r.path);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final noFace = widget.faces.isEmpty;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: Center(
              child: FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(
                  width: widget.size.width,
                  height: widget.size.height,
                  child: Stack(fit: StackFit.expand, children: [
                    Image.file(File(widget.path), fit: BoxFit.fill),
                    CustomPaint(key: const ValueKey('face_overlay'), painter: _OverlayPainter(widget.faces, _filter)),
                  ]),
                ),
              ),
            ),
          ),
          if (noFace)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: Text(context.tr('Aucun visage trouvé : tu peux garder la photo telle quelle.'), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 13)),
            )
          else
            SizedBox(
              height: 64,
              child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), children: [
                for (final f in FaceFilter.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      key: ValueKey('filter_${f.name}'),
                      label: Text(f == FaceFilter.none ? context.tr('Sans filtre') : FaceFilters.emoji(f), style: TextStyle(fontSize: f == FaceFilter.none ? 13 : 20, fontWeight: FontWeight.w700, color: _filter == f ? c.onAccent : c.textPrimary)),
                      selected: _filter == f,
                      selectedColor: c.accent,
                      backgroundColor: c.surface,
                      onSelected: (_) => setState(() => _filter = f),
                    ),
                  ),
              ]),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
            child: Row(children: [
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: FilledButton(
                    key: const ValueKey('filter_retake'),
                    onPressed: _busy ? null : () => Navigator.pop(context),
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF272B30), foregroundColor: const Color(0xFFF3F1EA), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    child: Text(context.tr('Reprendre'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 50,
                  child: FilledButton(
                    key: const ValueKey('filter_use'),
                    onPressed: _busy ? null : _use,
                    style: FilledButton.styleFrom(backgroundColor: c.accent, foregroundColor: c.onAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    child: _busy ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)) : Text(context.tr('Utiliser cette photo'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  ),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _OverlayPainter extends CustomPainter {
  _OverlayPainter(this.faces, this.filter);
  final List<FaceBox> faces;
  final FaceFilter filter;

  @override
  void paint(Canvas canvas, Size size) {
    for (final f in faces) {
      FaceFilters.drawOn(canvas, f, filter);
    }
  }

  @override
  bool shouldRepaint(_OverlayPainter old) => old.filter != filter || old.faces != faces;
}
