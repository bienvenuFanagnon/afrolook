// lib/pages/studio/studio_video_editor.dart

import '../../widgets/music/music_overlay.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import '../../theme/app_colors.dart';
import 'studio_models.dart';

const _c = AppColors.dark;

class StudioVideoEditor extends StatefulWidget {
  final bool forChronique;
  const StudioVideoEditor({Key? key, this.forChronique = false}) : super(key: key);

  @override
  State<StudioVideoEditor> createState() => _StudioVideoEditorState();
}

class _StudioVideoEditorState extends State<StudioVideoEditor> with MusicSuspendMixin {
  File? _videoFile;
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  StudioTemplate? _selectedTemplate;
  final _titleController = TextEditingController();
  bool _isLoading = false;

  final _picker = ImagePicker();

  List<StudioTemplate> get _videoTemplates =>
      kStudioTemplates.where((t) => t.type == StudioContentType.video).toList();

  @override
  void initState() {
    super.initState();
    _selectedTemplate = _videoTemplates.first;
  }

  @override
  void dispose() {
    _controller?.dispose();
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickVideo(ImageSource source) async {
    try {
      setState(() => _isLoading = true);
      final xfile = await _picker.pickVideo(
        source: source,
        maxDuration: Duration(seconds: widget.forChronique ? 60 : 120),
      );
      if (xfile == null) {
        setState(() => _isLoading = false);
        return;
      }

      await _controller?.dispose();
      _controller = VideoPlayerController.file(File(xfile.path));
      await _controller!.initialize();
      _controller!.setLooping(true);
      _controller!.play();

      setState(() {
        _videoFile = File(xfile.path);
        _isInitialized = true;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _c.background,
      appBar: AppBar(
        backgroundColor: _c.background,
        elevation: 0,
        title: const Text('Vidéo + Texte', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          if (_videoFile != null)
            TextButton(
              onPressed: _publish,
              child: Text(
                'Suivant →',
                style: TextStyle(color: _c.primary, fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Aperçu vidéo
          Expanded(
            flex: 5,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: _c.surface,
                border: Border.all(color: _c.border),
              ),
              clipBehavior: Clip.hardEdge,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_isInitialized && _controller != null)
                    GestureDetector(
                      onTap: () {
                        if (_controller!.value.isPlaying) {
                          _controller!.pause();
                        } else {
                          _controller!.play();
                        }
                        setState(() {});
                      },
                      child: VideoPlayer(_controller!),
                    )
                  else
                    _VideoPlaceholder(onTap: () => _showSourceSheet(context)),

                  // Template overlay (titre + barre progression)
                  if (_selectedTemplate != null && _videoFile != null)
                    _buildTemplateOverlay(),

                  // Play/pause icon
                  if (_isInitialized && _controller != null && !_controller!.value.isPlaying)
                    const Center(
                      child: Icon(Icons.play_circle_fill, size: 56, color: Colors.white70),
                    ),

                  // Loader
                  if (_isLoading)
                    Container(
                      color: Colors.black54,
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Champ titre
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: _c.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _c.border),
            ),
            child: TextField(
              controller: _titleController,
              maxLines: 1,
              maxLength: 50,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(fontSize: 13, color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Titre de la vidéo (optionnel)…',
                hintStyle: TextStyle(color: _c.textSecondary),
                border: InputBorder.none,
                counterText: '',
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Templates
          SizedBox(
            height: 80,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: _videoTemplates.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final t = _videoTemplates[i];
                final sel = _selectedTemplate?.id == t.id;
                return GestureDetector(
                  onTap: () => setState(() => _selectedTemplate = t),
                  child: Container(
                    width: 80,
                    decoration: BoxDecoration(
                      color: sel
                          ? const Color(0xFFE84B3C).withOpacity(0.2)
                          : _c.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: sel ? const Color(0xFFE84B3C) : _c.border,
                        width: sel ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(t.emoji, style: const TextStyle(fontSize: 22)),
                        const SizedBox(height: 4),
                        Text(
                          t.name,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: sel ? const Color(0xFFE84B3C) : _c.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildTemplateOverlay() {
    final t = _selectedTemplate!;
    return Stack(
      fit: StackFit.expand,
      children: [
        // Badge défi/label en haut
        if (t.id == 'vid_defi')
          Positioned(
            top: 12,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE84B3C),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: const Text('🔴 DÉFI', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
              ),
            ),
          ),

        // Barre basse avec titre + progression
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 20, 12, 12),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Color(0xEE000000), Colors.transparent],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_titleController.text.isNotEmpty)
                  Text(
                    _titleController.text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                const SizedBox(height: 6),
                // Barre de progression
                Container(
                  height: 2,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: FractionallySizedBox(
                    widthFactor: _isInitialized && _controller != null
                        ? (_controller!.value.position.inMilliseconds /
                                (_controller!.value.duration.inMilliseconds + 1))
                            .clamp(0.0, 1.0)
                        : 0.0,
                    alignment: Alignment.centerLeft,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFE84B3C),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showSourceSheet(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: _c.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.videocam, color: Colors.white),
              title: const Text('Filmer une vidéo', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                _pickVideo(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.video_library, color: Colors.white),
              title: const Text('Choisir depuis la galerie', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                _pickVideo(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _publish() {
    if (_videoFile == null) return;
    _controller?.pause();
    Navigator.pop(
      context,
      StudioResult(
        type: StudioContentType.video,
        mediaFile: _videoFile,
        textContent: _titleController.text.trim().isEmpty ? null : _titleController.text.trim(),
        templateId: _selectedTemplate?.id,
        forChronique: widget.forChronique,
      ),
    );
  }
}

class _VideoPlaceholder extends StatelessWidget {
  final VoidCallback onTap;
  const _VideoPlaceholder({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: const Color(0xFF0A0A12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white24, width: 2),
                borderRadius: BorderRadius.circular(36),
              ),
              child: const Icon(Icons.videocam, color: Colors.white38, size: 32),
            ),
            const SizedBox(height: 12),
            const Text(
              'Toucher pour ajouter\nvotre vidéo',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
