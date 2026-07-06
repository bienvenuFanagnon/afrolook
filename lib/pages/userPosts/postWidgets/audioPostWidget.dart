import 'dart:async';
import 'package:afrotok/pages/component/consoleWidget.dart';

import 'dart:io';

import 'package:audioplayers/audioplayers.dart';

import 'package:cached_network_image/cached_network_image.dart';

import 'package:firebase_storage/firebase_storage.dart';

import 'package:flutter/material.dart';

import 'package:path_provider/path_provider.dart';

import 'package:provider/provider.dart';

import 'package:visibility_detector/visibility_detector.dart';

import '../../../models/model_data.dart';

import '../../../providers/authProvider.dart';

import '../../../providers/sound_provider.dart';

import '../../../theme/app_colors.dart';

import '../../postDetails.dart';

import '../youTube_video_card.dart';

/// Carte de post audio, extraite de HomePostUsersWidget.
/// Affiche la pochette, le bouton play/pause, la progression et la durée,
/// ainsi qu'un bouton son on/off relié au SoundProvider/MediaPlaybackManager
/// (même logique que les cartes vidéo).
class AudioPostCard extends StatefulWidget {
  final Post post;
  final bool isLocked;

  const AudioPostCard({
    Key? key,
    required this.post,
    this.isLocked = false,
  }) : super(key: key);

  @override
  State<AudioPostCard> createState() => _AudioPostCardState();
}

class _AudioPostCardState extends State<AudioPostCard> {
  AudioPlayer? _player;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  File? _cachedAudioFile;
  Timer? _visibilityTimer;

  late UserAuthProvider _authProvider;
  late SoundProvider _soundProvider;

  @override
  void initState() {
    super.initState();
    _authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    _soundProvider = Provider.of<SoundProvider>(context, listen: false);

    // 🔥 S'abonner aux changements globaux du son pour resynchroniser le volume
    _soundProvider.addListener(_onGlobalSoundChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _precacheAudio();
    });
  }

  String get _audioUrl => widget.post.url_media ?? '';
  String get _postId => widget.post.id ?? '';

  void _initPlayer() {
    if (_player != null) return;
    final player = AudioPlayer();

    player.onDurationChanged.listen((duration) {
      if (mounted) setState(() => _duration = duration);
    });

    player.onPositionChanged.listen((position) {
      if (mounted) setState(() => _position = position);
    });

    player.onPlayerComplete.listen((event) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
      }
    });

    _player = player;
  }

  Future<File?> _precacheAudio() async {
    if (_cachedAudioFile != null) return _cachedAudioFile;
    if (_audioUrl.isEmpty) return null;

    try {
      final tempDir = await getTemporaryDirectory();
      final fileName = 'audio_$_postId.${_getAudioExtension(_audioUrl)}';
      final file = File('${tempDir.path}/$fileName');

      if (await file.exists()) {
        _cachedAudioFile = file;
        return file;
      }

      final optimizedUrl = _optimizeUrl(_audioUrl);
      final storageRef = FirebaseStorage.instance.refFromURL(optimizedUrl);
      const maxSize = 10 * 1024 * 1024; // 10 MB
      final data = await storageRef.getData(maxSize);

      if (data != null) {
        await file.writeAsBytes(data);
        _cachedAudioFile = file;
        return file;
      }
    } catch (e) {
      printVm('Erreur préchargement audio $_postId: $e');
    }
    return null;
  }

  String _getAudioExtension(String url) {
    if (url.contains('.mp3')) return 'mp3';
    if (url.contains('.m4a')) return 'm4a';
    if (url.contains('.aac')) return 'aac';
    if (url.contains('.opus')) return 'opus';
    if (url.contains('.webm')) return 'webm';
    return 'm4a';
  }

  String _optimizeUrl(String url) {
    if (url.isEmpty) return url;
    return _authProvider.convertToCdnUrl(url, _authProvider.appDefaultData);
  }

  Future<void> _playPause() async {
    if (widget.isLocked) return;
    _initPlayer();
    final player = _player!;

    if (_isPlaying) {
      await player.pause();
      if (mounted) setState(() => _isPlaying = false);
      return;
    }

    // 🔥 Enregistrer dans le manager global (arrête vidéo/autre audio en cours)
    MediaPlaybackManager.registerAudio(
      _postId,
      player,
      () => _stop(),
    );

    // 🔥 Appliquer systématiquement l'état courant du SoundProvider
    final isMuted = _soundProvider.isMuted;
    await player.setVolume(isMuted ? 0.0 : 1.0);

    if (_position == Duration.zero) {
      if (_cachedAudioFile != null) {
        await player.play(DeviceFileSource(_cachedAudioFile!.path));
      } else {
        await player.play(UrlSource(_audioUrl));
      }
    } else {
      await player.resume();
    }

    if (mounted) setState(() => _isPlaying = true);
  }

  void _stop() {
    _player?.stop();
    if (mounted) {
      setState(() {
        _isPlaying = false;
        _position = Duration.zero;
      });
    }
  }

  void _pause() {
    if (_isPlaying) {
      _player?.pause();
      if (mounted) setState(() => _isPlaying = false);
    }
  }

  void _seek(double value) {
    _player?.seek(Duration(seconds: value.toInt()));
  }

  void _toggleSound() {
    _soundProvider.setMuted(!_soundProvider.isMuted);
  }

  /// Resynchronise le volume avec l'état global du son, quel que soit
  /// le widget "actif" suivi par MediaPlaybackManager.
  void _onGlobalSoundChanged() {
    if (_player == null) return;
    final isMuted = _soundProvider.isMuted;
    final volume = isMuted ? 0.0 : 1.0;
    _player!.setVolume(volume);

    if (isMuted && _isPlaying) {
      _pause();
    }
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    _visibilityTimer?.cancel();

    if (widget.isLocked) return;

    if (info.visibleFraction > 0.5) {
      _visibilityTimer = Timer(const Duration(milliseconds: 500), () {
        if (!mounted || info.visibleFraction <= 0.5) return;

        _initPlayer();

        // 🔥 Enregistrer comme média courant
        MediaPlaybackManager.registerAudio(
          _postId,
          _player!,
          () => _stop(),
        );

        // Synchroniser le volume (0 si muet, 1 si son actif) puis toujours lancer
        final isMuted = _soundProvider.isMuted;
        _player!.setVolume(isMuted ? 0.0 : 1.0);

        if (!_isPlaying) {
          _playPause();
        }
      });
    } else {
      _pause();
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  @override
  void dispose() {
    _visibilityTimer?.cancel();
    _soundProvider.removeListener(_onGlobalSoundChanged);
    MediaPlaybackManager.unregisterMedia(_postId);
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isLocked = widget.isLocked;
    final isCurrentlyPlaying = _isPlaying;
    final duration = _duration;
    final position = _position;

    final coverImage = widget.post.images != null && widget.post.images!.isNotEmpty
        ? widget.post.images!.first
        : null;

    return VisibilityDetector(
      key: Key('audio_${widget.post.id}'),
      onVisibilityChanged: _onVisibilityChanged,
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DetailsPost(post: widget.post),
            ),
          );
        },
        child: Stack(
          children: [
            // Fond avec dégradé
            Container(
              width: double.infinity,
              height: 140,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF2196F3).withOpacity(0.3),
                    const Color(0xFF9C27B0).withOpacity(0.3),
                  ],
                ),
              ),
            ),

            // Overlay verrouillage
            if (isLocked)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.lock, color: colors.warning, size: 40),
                        const SizedBox(height: 8),
                        Text(
                          'Audio verrouillé',
                          style: TextStyle(
                            color: colors.warning,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Abonnez-vous pour écouter',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Contenu audio
            if (!isLocked)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (coverImage != null)
                      Container(
                        width: 80,
                        height: 80,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          image: DecorationImage(
                            image: CachedNetworkImageProvider(coverImage),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),

                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2196F3).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(
                                  Icons.audiotrack,
                                  color: Color(0xFF2196F3),
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Audio',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const Spacer(),
                              // 🔥 Bouton son on/off (même pattern que les cartes vidéo)
                              Consumer<SoundProvider>(
                                builder: (context, soundProvider, _) {
                                  return GestureDetector(
                                    onTap: _toggleSound,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.5),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        soundProvider.isMuted ? Icons.volume_off : Icons.volume_up,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _formatDuration(duration),
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 10),

                          Row(
                            children: [
                              GestureDetector(
                                onTap: _playPause,
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF2196F3),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    isCurrentlyPlaying ? Icons.pause : Icons.play_arrow,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              ),

                              const SizedBox(width: 12),

                              Expanded(
                                child: Column(
                                  children: [
                                    Slider(
                                      value: position.inSeconds.toDouble(),
                                      min: 0,
                                      max: duration.inSeconds > 0 ? duration.inSeconds.toDouble() : 1.0,
                                      onChanged: _seek,
                                      activeColor: const Color(0xFF2196F3),
                                      inactiveColor: Colors.grey[700],
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 4),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            _formatDuration(position),
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 9,
                                            ),
                                          ),
                                          Text(
                                            _formatDuration(duration),
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 9,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(15, (index) {
                              final barHeight = 3.0 + (index % 4) * 1.5;
                              return Container(
                                width: 2,
                                height: barHeight,
                                margin: const EdgeInsets.symmetric(horizontal: 1),
                                decoration: BoxDecoration(
                                  color: isCurrentlyPlaying && index % 2 == 0
                                      ? const Color(0xFF2196F3)
                                      : Colors.grey[600],
                                  borderRadius: BorderRadius.circular(1),
                                ),
                              );
                            }),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
