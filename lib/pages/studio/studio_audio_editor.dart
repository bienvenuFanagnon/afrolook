// lib/pages/studio/studio_audio_editor.dart
//
// Éditeur audio : fichier audio + pochette photo optionnelle + titre.
// Un post audio peut avoir une image de couverture.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:audio_waveforms/audio_waveforms.dart' hide PlayerState;
import '../../theme/app_colors.dart';
import 'studio_models.dart';
import 'studio_audio_trimmer.dart';

const _c = AppColors.dark;

class StudioAudioEditor extends StatefulWidget {
  final bool forChronique;
  const StudioAudioEditor({Key? key, this.forChronique = false}) : super(key: key);

  @override
  State<StudioAudioEditor> createState() => _StudioAudioEditorState();
}

class _StudioAudioEditorState extends State<StudioAudioEditor> {
  File? _audioFile;
  File? _coverImageFile;
  StudioTemplate? _selectedTemplate;
  final _titleController = TextEditingController();
  final _audioPlayer = AudioPlayer();
  PlayerController? _waveformController;
  bool _isPlaying = false;
  bool _isLoading = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  int? _audioStartMs; // trim sélectionné
  int? _audioEndMs;

  final _picker = ImagePicker();

  List<StudioTemplate> get _audioTemplates =>
      kStudioTemplates.where((t) => t.type == StudioContentType.audio).toList();

  @override
  void initState() {
    super.initState();
    _selectedTemplate = _audioTemplates.first;
    _audioPlayer.onDurationChanged.listen((d) => setState(() => _duration = d));
    _audioPlayer.onPositionChanged.listen((p) => setState(() => _position = p));
    _audioPlayer.onPlayerStateChanged.listen((s) {
      setState(() => _isPlaying = s == PlayerState.playing);
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _waveformController?.dispose();
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickAudio() async {
    try {
      setState(() => _isLoading = true);
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      final file = File(result.files.first.path!);

      // Vérifier la taille (max 50 Mo)
      final sizeInMb = await file.length() / (1024 * 1024);
      if (sizeInMb > 50) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Le fichier audio ne doit pas dépasser 50 Mo.')),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      await _audioPlayer.stop();

      // Waveform
      _waveformController?.dispose();
      _waveformController = PlayerController();
      await _waveformController!.preparePlayer(
        path: file.path,
        shouldExtractWaveform: true,
      );

      setState(() {
        _audioFile = file;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickCoverImage() async {
    final xfile = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (xfile != null) {
      setState(() => _coverImageFile = File(xfile.path));
    }
  }

  Future<void> _togglePlay() async {
    if (_audioFile == null) return;
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.play(DeviceFileSource(_audioFile!.path));
    }
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Color _hexToColor(String hex) {
    final h = hex.replaceAll('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _c.background,
      appBar: AppBar(
        backgroundColor: _c.background,
        elevation: 0,
        title: const Text('Audio + Texte', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          if (_audioFile != null)
            TextButton(
              onPressed: _publish,
              child: Text(
                'Suivant →',
                style: TextStyle(color: _c.primary, fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Aperçu carte audio
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _selectedTemplate != null
                    ? _hexToColor(_selectedTemplate!.backgroundColor ?? '#1a0a2a')
                    : _c.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _c.border),
              ),
              child: Column(
                children: [
                  // Pochette + titre
                  Row(
                    children: [
                      // Pochette (image de couverture)
                      GestureDetector(
                        onTap: _pickCoverImage,
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white24),
                            color: Colors.white.withOpacity(0.08),
                          ),
                          clipBehavior: Clip.hardEdge,
                          child: _coverImageFile != null
                              ? Image.file(_coverImageFile!, fit: BoxFit.cover)
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Icon(Icons.add_photo_alternate, color: Colors.white38, size: 24),
                                    SizedBox(height: 4),
                                    Text('Pochette', style: TextStyle(color: Colors.white38, fontSize: 9)),
                                  ],
                                ),
                        ),
                      ),

                      const SizedBox(width: 14),

                      // Titre + icône template
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_selectedTemplate != null)
                              Text(
                                _selectedTemplate!.emoji,
                                style: const TextStyle(fontSize: 24),
                              ),
                            const SizedBox(height: 4),
                            Text(
                              _titleController.text.isEmpty
                                  ? (_selectedTemplate?.name ?? 'Sans titre')
                                  : _titleController.text,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            if (_duration != Duration.zero)
                              Text(
                                _formatDuration(_duration),
                                style: TextStyle(fontSize: 11, color: Colors.white54),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Waveform ou placeholder
                  if (_waveformController != null)
                    AudioFileWaveforms(
                      size: Size(double.infinity, 48),
                      playerController: _waveformController!,
                      waveformType: WaveformType.fitWidth,
                      playerWaveStyle: PlayerWaveStyle(
                        fixedWaveColor: Colors.white24,
                        liveWaveColor: _c.primary,
                        spacing: 4,
                        waveThickness: 3,
                      ),
                    )
                  else
                    _WaveformPlaceholder(),

                  const SizedBox(height: 12),

                  // Contrôles lecture
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_audioFile != null) ...[
                        Text(
                          _formatDuration(_position),
                          style: TextStyle(fontSize: 11, color: Colors.white54),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: _togglePlay,
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: _c.primary,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _isPlaying ? Icons.pause : Icons.play_arrow,
                              color: Colors.black,
                              size: 24,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _formatDuration(_duration),
                          style: TextStyle(fontSize: 11, color: Colors.white54),
                        ),
                      ] else
                        Text(
                          'Aucun audio sélectionné',
                          style: TextStyle(color: Colors.white38, fontSize: 12),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Bouton sélectionner audio
            GestureDetector(
              onTap: _pickAudio,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: _c.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _audioFile != null ? _c.primary : _c.border,
                    style: BorderStyle.solid,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _audioFile != null ? Icons.check_circle : Icons.audio_file,
                      color: _audioFile != null ? _c.primary : Colors.white54,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _audioFile != null
                          ? _audioFile!.path.split('/').last
                          : 'Choisir un fichier audio (MP3 / WAV / AAC · max 50 Mo)',
                      style: TextStyle(
                        color: _audioFile != null ? _c.primary : Colors.white54,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),

            if (_isLoading) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],

            // Bouton trimmer (visible uniquement si un fichier est chargé)
            if (_audioFile != null) ...[
              const SizedBox(height: 10),
              GestureDetector(
                onTap: _openTrimmer,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: _c.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: (_audioStartMs != null) ? const Color(0xFF9B59B6) : _c.border,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.content_cut_rounded,
                        color: (_audioStartMs != null) ? const Color(0xFF9B59B6) : Colors.white54,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _audioStartMs != null
                            ? '✂️ Clip : ${(_audioStartMs! / 1000).toStringAsFixed(1)}s → ${(_audioEndMs! / 1000).toStringAsFixed(1)}s'
                            : 'Découper le clip (style WhatsApp)',
                        style: TextStyle(
                          color: (_audioStartMs != null) ? const Color(0xFF9B59B6) : Colors.white54,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Champ titre
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: _c.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _c.border),
              ),
              child: TextField(
                controller: _titleController,
                maxLines: 1,
                maxLength: 60,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(fontSize: 13, color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Titre du son / podcast…',
                  hintStyle: TextStyle(color: _c.textSecondary),
                  border: InputBorder.none,
                  counterText: '',
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Templates
            Text(
              'Style visuel',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _c.textPrimary),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 80,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _audioTemplates.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final t = _audioTemplates[i];
                  final sel = _selectedTemplate?.id == t.id;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedTemplate = t),
                    child: Container(
                      width: 80,
                      decoration: BoxDecoration(
                        color: t.backgroundColor != null
                            ? _hexToColor(t.backgroundColor!).withOpacity(sel ? 0.5 : 0.25)
                            : _c.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: sel ? const Color(0xFF9B59B6) : _c.border,
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
                              color: sel ? const Color(0xFF9B59B6) : _c.textSecondary,
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

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _openTrimmer() async {
    if (_audioFile == null) return;
    final maxMs = widget.forChronique ? 30000 : 60000;
    final result = await Navigator.push<TrimResult>(
      context,
      MaterialPageRoute(
        builder: (_) => StudioAudioTrimmer(audioFile: _audioFile!, maxDurationMs: maxMs),
      ),
    );
    if (result != null) {
      setState(() {
        _audioStartMs = result.startMs;
        _audioEndMs = result.endMs;
      });
    }
  }

  void _publish() {
    if (_audioFile == null) return;
    Navigator.pop(
      context,
      StudioResult(
        type: StudioContentType.audio,
        mediaFile: _audioFile,
        coverImageFile: _coverImageFile,
        textContent: _titleController.text.trim().isEmpty ? null : _titleController.text.trim(),
        templateId: _selectedTemplate?.id,
        forChronique: widget.forChronique,
        audioStartMs: _audioStartMs,
        audioEndMs: _audioEndMs,
      ),
    );
  }
}

class _WaveformPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(
          30,
          (i) => Container(
            width: 3,
            height: 8 + (i % 5) * 6.0,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: Colors.white12,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        ),
      ),
    );
  }
}
