import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../../l10n/tr.dart';
import '../../theme/app_colors.dart';

/// Extrait l'image d'une vidéo à l'instant [ms] (fichier JPEG temporaire) ; null si impossible.
typedef CoverFrameLoader = Future<File?> Function(int ms);

/// Choisit une image dans la galerie (null si la personne annule).
typedef CoverGalleryPicker = Future<File?> Function();

/// Choix de la COUVERTURE d'une vidéo avant la publication (décision du 08/11/2026 : l'option avait disparu du parcours unique de création).
/// Trois façons de choisir : une image de la bande (la vidéo découpée en 8 instants), un instant précis avec le curseur, ou une image de la galerie.
/// Renvoie le fichier choisi, ou null si la personne ferme sans choisir.
Future<File?> showCoverPicker(
  BuildContext context, {
  required File video,
  required Duration duration,
  File? current,
  CoverFrameLoader? frameLoader,
  CoverGalleryPicker? galleryPicker,
}) {
  return showModalBottomSheet<File>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.of(context).surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (_) => CoverPickerSheet(video: video, duration: duration, current: current, frameLoader: frameLoader, galleryPicker: galleryPicker),
  );
}

class CoverPickerSheet extends StatefulWidget {
  const CoverPickerSheet({super.key, required this.video, required this.duration, this.current, this.frameLoader, this.galleryPicker});
  final File video;
  final Duration duration;
  final File? current;
  final CoverFrameLoader? frameLoader;
  final CoverGalleryPicker? galleryPicker;

  @override
  State<CoverPickerSheet> createState() => _CoverPickerSheetState();
}

class _CoverPickerSheetState extends State<CoverPickerSheet> {
  static const int _count = 8;

  late final List<int> _times;
  final Map<int, File?> _frames = {};
  File? _selected;
  double _sliderMs = 0;
  bool _sliderBusy = false;
  bool _closed = false;

  int get _totalMs => widget.duration.inMilliseconds < 1000 ? 1000 : widget.duration.inMilliseconds;

  @override
  void initState() {
    super.initState();
    _selected = widget.current;
    // 8 instants répartis dans la vidéo (jamais la toute dernière image, souvent noire)
    _times = [for (var i = 0; i < _count; i++) ((_totalMs * (i + .5) / _count).round()).clamp(0, _totalMs - 100)];
    _loadFrames();
  }

  @override
  void dispose() {
    _closed = true;
    super.dispose();
  }

  Future<File?> _frameAt(int ms) async {
    final custom = widget.frameLoader;
    if (custom != null) return custom(ms);
    if (kIsWeb) return null;
    try {
      final dir = await getTemporaryDirectory();
      final path = await VideoThumbnail.thumbnailFile(video: widget.video.path, thumbnailPath: dir.path, imageFormat: ImageFormat.JPEG, maxWidth: 720, quality: 80, timeMs: ms);
      return path == null ? null : File(path);
    } catch (_) {
      return null;
    }
  }

  /// Les images de la bande arrivent l'une après l'autre (une seule extraction à la fois : la vidéo reste légère à lire).
  Future<void> _loadFrames() async {
    for (final t in _times) {
      if (_closed) return;
      final f = await _frameAt(t);
      if (_closed) return;
      setState(() => _frames[t] = f);
    }
  }

  Future<void> _fromSlider() async {
    if (_sliderBusy) return;
    setState(() => _sliderBusy = true);
    final f = await _frameAt(_sliderMs.round());
    if (_closed) return;
    setState(() {
      _sliderBusy = false;
      if (f != null) _selected = f;
    });
  }

  Future<void> _fromGallery() async {
    File? f;
    final custom = widget.galleryPicker;
    if (custom != null) {
      f = await custom();
    } else {
      final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1080, imageQuality: 85);
      f = x == null ? null : File(x.path);
    }
    if (f != null && !_closed) setState(() => _selected = f);
  }

  String _clock(int ms) => '${ms ~/ 60000}:${((ms ~/ 1000) % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(99)))),
            const SizedBox(height: 14),
            Text(context.tr('Couverture de ta vidéo'), style: TextStyle(color: c.textPrimary, fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(context.tr('C\'est l\'image qu\'on voit avant de lancer la vidéo.'), style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
            const SizedBox(height: 12),
            // l'image retenue
            Center(
              child: Container(
                key: const ValueKey('cover_selected'),
                width: 150,
                height: 200,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(color: c.surfaceVariant, borderRadius: BorderRadius.circular(14)),
                child: _selected == null
                    ? Center(child: Icon(Icons.image_outlined, color: c.textSecondary, size: 34))
                    : Image.file(_selected!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Icon(Icons.broken_image_outlined, color: c.textSecondary)),
              ),
            ),
            const SizedBox(height: 14),
            Text(context.tr('Une image de la vidéo'), style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 13.5)),
            const SizedBox(height: 8),
            SizedBox(
              height: 86,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _times.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final t = _times[i];
                  final f = _frames[t];
                  final chosen = f != null && _selected?.path == f.path;
                  return GestureDetector(
                    key: ValueKey('cover_frame_$i'),
                    onTap: f == null ? null : () => setState(() => _selected = f),
                    child: Container(
                      width: 62,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: c.surfaceVariant,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: chosen ? c.primary : c.border, width: chosen ? 2.5 : 1),
                      ),
                      child: f == null
                          ? Center(child: _frames.containsKey(t) ? Icon(Icons.image_not_supported_outlined, size: 18, color: c.textSecondary) : const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)))
                          : Image.file(f, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: Text(context.tr('Choisir l\'instant exact'), style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 13.5))),
              Text(_clock(_sliderMs.round()), style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
            ]),
            Slider(
              key: const ValueKey('cover_slider'),
              value: _sliderMs.clamp(0, _totalMs.toDouble()),
              min: 0,
              max: _totalMs.toDouble(),
              onChanged: (v) => setState(() => _sliderMs = v),
              onChangeEnd: (_) => _fromSlider(),
            ),
            if (_sliderBusy) const Padding(padding: EdgeInsets.only(bottom: 6), child: LinearProgressIndicator(minHeight: 2)),
            OutlinedButton.icon(
              key: const ValueKey('cover_gallery'),
              onPressed: _fromGallery,
              icon: const Icon(Icons.photo_library_outlined, size: 18),
              label: Text(context.tr('Une image de ma galerie')),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: TextButton(key: const ValueKey('cover_cancel'), onPressed: () => Navigator.pop(context), child: Text(context.tr('Annuler')))),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: FilledButton(
                  key: const ValueKey('cover_ok'),
                  onPressed: _selected == null ? null : () => Navigator.pop(context, _selected),
                  child: Text(context.tr('Utiliser cette image')),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}
