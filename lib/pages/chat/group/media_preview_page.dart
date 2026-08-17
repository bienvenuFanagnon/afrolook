import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

/// Aperçu avant envoi d'un média dans le groupe.
/// Retourne le texte de légende (peut être vide) si l'utilisateur confirme,
/// ou null s'il annule.
class MediaPreviewPage extends StatefulWidget {
  final XFile file;
  final String type; // 'image' | 'video'

  const MediaPreviewPage({Key? key, required this.file, required this.type})
      : super(key: key);

  @override
  State<MediaPreviewPage> createState() => _MediaPreviewPageState();
}

class _MediaPreviewPageState extends State<MediaPreviewPage> {
  final _captionCtrl = TextEditingController();
  final _focusNode = FocusNode();

  Uint8List? _imageBytes;
  VideoPlayerController? _videoCtrl;
  bool _videoReady = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.type == 'image') {
      final bytes = await widget.file.readAsBytes();
      if (mounted) setState(() { _imageBytes = bytes; _loading = false; });
    } else {
      VideoPlayerController ctrl;
      if (kIsWeb) {
        ctrl = VideoPlayerController.networkUrl(Uri.parse(widget.file.path));
      } else {
        ctrl = VideoPlayerController.file(File(widget.file.path));
      }
      try {
        await ctrl.initialize();
        await ctrl.setVolume(1.0);
        if (mounted) setState(() { _videoCtrl = ctrl; _videoReady = true; _loading = false; });
      } catch (_) {
        if (mounted) setState(() => _loading = false);
      }
    }
  }

  @override
  void dispose() {
    _captionCtrl.dispose();
    _focusNode.dispose();
    _videoCtrl?.dispose();
    super.dispose();
  }

  void _confirm() {
    Navigator.pop(context, _captionCtrl.text.trim());
  }

  void _cancel() => Navigator.pop(context, null);

  void _togglePlay() {
    if (_videoCtrl == null) return;
    setState(() {
      _videoCtrl!.value.isPlaying ? _videoCtrl!.pause() : _videoCtrl!.play();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // ── Barre du haut ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 22),
                    onPressed: _cancel,
                  ),
                  Text(
                    widget.type == 'image' ? 'Aperçu photo' : 'Aperçu vidéo',
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),

            // ── Zone de prévisualisation ──────────────────────────────────
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: Colors.white))
                  : widget.type == 'image'
                      ? _buildImagePreview()
                      : _buildVideoPreview(),
            ),

            // ── Barre légende + envoi ────────────────────────────────────
            AnimatedPadding(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.only(bottom: bottom),
              child: Container(
                color: const Color(0xCC000000),
                padding: const EdgeInsets.fromLTRB(12, 10, 10, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0x33FFFFFF),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        child: TextField(
                          controller: _captionCtrl,
                          focusNode: _focusNode,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          decoration: const InputDecoration(
                            hintText: 'Ajouter une légende...',
                            hintStyle: TextStyle(color: Colors.white54, fontSize: 14),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                          maxLines: 4,
                          minLines: 1,
                          textCapitalization: TextCapitalization.sentences,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _confirm,
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFD700),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.send_rounded, color: Colors.black, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    if (_imageBytes == null) {
      return const Center(child: Icon(Icons.broken_image_outlined, color: Colors.white54, size: 64));
    }
    return InteractiveViewer(
      child: Center(
        child: Image.memory(_imageBytes!, fit: BoxFit.contain),
      ),
    );
  }

  Widget _buildVideoPreview() {
    if (!_videoReady || _videoCtrl == null) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.videocam_outlined, color: Colors.white54, size: 64),
            SizedBox(height: 12),
            Text('Impossible de prévisualiser la vidéo',
                style: TextStyle(color: Colors.white54, fontSize: 13)),
          ],
        ),
      );
    }
    return GestureDetector(
      onTap: _togglePlay,
      child: Center(
        child: AspectRatio(
          aspectRatio: _videoCtrl!.value.aspectRatio,
          child: Stack(
            alignment: Alignment.center,
            children: [
              VideoPlayer(_videoCtrl!),
              ValueListenableBuilder<VideoPlayerValue>(
                valueListenable: _videoCtrl!,
                builder: (_, val, __) => val.isPlaying
                    ? const SizedBox.shrink()
                    : Container(
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(14),
                        child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 36),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
