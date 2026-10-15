// lib/pages/studio/studio_audio_trimmer.dart
//
// Écran de découpe audio style WhatsApp :
// waveform scrollable + deux poignées draggables + lecture en boucle du clip.
// Ne coupe PAS le fichier — retourne seulement startMs / endMs.

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:audio_waveforms/audio_waveforms.dart' hide PlayerState;
import '../../theme/app_colors.dart';

const _c = AppColors.dark;

/// Résultat renvoyé par le trimmer
class TrimResult {
  final int startMs;
  final int endMs;
  const TrimResult({required this.startMs, required this.endMs});
  int get durationMs => endMs - startMs;
}

class StudioAudioTrimmer extends StatefulWidget {
  final File audioFile;
  final int maxDurationMs; // limite de la sélection (ex. 30 000 = 30s chronique)

  const StudioAudioTrimmer({
    Key? key,
    required this.audioFile,
    required this.maxDurationMs,
  }) : super(key: key);

  @override
  State<StudioAudioTrimmer> createState() => _StudioAudioTrimmerState();
}

class _StudioAudioTrimmerState extends State<StudioAudioTrimmer> {
  // ── Durée totale du fichier ────────────────────────────────────────────────
  int _totalMs = 0;

  // ── Positions des poignées (0.0 → 1.0 de _totalMs) ───────────────────────
  double _startFrac = 0.0;
  double _endFrac = 1.0;

  int get _startMs => (_startFrac * _totalMs).round();
  int get _endMs => (_endFrac * _totalMs).round();
  int get _selDurationMs => _endMs - _startMs;

  // ── Lecture ───────────────────────────────────────────────────────────────
  final _player = AudioPlayer();
  PlayerController? _waveCtrl;
  bool _isPlaying = false;
  int _positionMs = 0;
  Timer? _loopTimer;

  // ── Layout ────────────────────────────────────────────────────────────────
  double _barWidth = 0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // Durée via AudioPlayer
    await _player.setSourceDeviceFile(widget.audioFile.path);
    final dur = await _player.getDuration();
    final total = dur?.inMilliseconds ?? 0;

    // Waveform
    final ctrl = PlayerController();
    await ctrl.preparePlayer(
      path: widget.audioFile.path,
      shouldExtractWaveform: true,
    );

    // Limite de sélection : si le fichier est plus court que maxDuration,
    // on sélectionne tout ; sinon on cadre les 30 (ou 60) premières secondes.
    final maxFrac = total > 0
        ? (widget.maxDurationMs / total).clamp(0.0, 1.0)
        : 1.0;

    setState(() {
      _totalMs = total;
      _startFrac = 0.0;
      _endFrac = maxFrac;
      _waveCtrl = ctrl;
    });

    _player.onPositionChanged.listen((pos) {
      if (!mounted) return;
      setState(() => _positionMs = pos.inMilliseconds);
      // Retour au début du clip quand on dépasse la fin
      if (_isPlaying && _positionMs >= _endMs) {
        _player.seek(Duration(milliseconds: _startMs));
      }
    });
    _player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _isPlaying = s == PlayerState.playing);
    });
  }

  @override
  void dispose() {
    _loopTimer?.cancel();
    _player.dispose();
    _waveCtrl?.dispose();
    super.dispose();
  }

  // ── Lecture / pause ───────────────────────────────────────────────────────
  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _player.pause();
    } else {
      await _player.seek(Duration(milliseconds: _startMs));
      await _player.resume();
    }
  }

  // ── Conversion fraction ↔ pixels ──────────────────────────────────────────
  double _fracToX(double frac) => frac * _barWidth;
  double _xToFrac(double x) => (x / _barWidth).clamp(0.0, 1.0);

  // ── Contraintes sur les poignées ──────────────────────────────────────────
  void _updateStart(double dx) {
    if (_totalMs == 0) return;
    final f = _xToFrac(dx);
    setState(() {
      _startFrac = f.clamp(0.0, _endFrac - 1000 / _totalMs);
      // Si la sélection dépasse maxDuration on compresse la fin
      final maxEnd = (_startFrac + widget.maxDurationMs / _totalMs).clamp(0.0, 1.0);
      if (_endFrac > maxEnd) _endFrac = maxEnd;
    });
  }

  void _updateEnd(double dx) {
    if (_totalMs == 0) return;
    final f = _xToFrac(dx);
    setState(() {
      // min 1s, max maxDuration depuis le début
      final maxEnd = (_startFrac + widget.maxDurationMs / _totalMs).clamp(0.0, 1.0);
      _endFrac = f.clamp(_startFrac + 1000 / _totalMs, maxEnd);
    });
  }

  // ── Formatage ─────────────────────────────────────────────────────────────
  String _fmt(int ms) {
    final s = (ms / 1000).round();
    final m = s ~/ 60;
    final sec = (s % 60).toString().padLeft(2, '0');
    return '$m:$sec';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _c.background,
      appBar: AppBar(
        backgroundColor: _c.background,
        elevation: 0,
        title: const Text('Choisir le clip', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          TextButton(
            onPressed: _totalMs > 0
                ? () => Navigator.pop(context, TrimResult(startMs: _startMs, endMs: _endMs))
                : null,
            child: Text(
              'Confirmer →',
              style: TextStyle(
                color: _totalMs > 0 ? _c.primary : _c.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: _totalMs == 0
          ? Center(child: CircularProgressIndicator(color: _c.primary))
          : Column(
              children: [
                const SizedBox(height: 24),

                // ── Durées sélectionnées ────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_fmt(_startMs), style: TextStyle(color: _c.textSecondary, fontSize: 13)),
                      Text(
                        '${(_selDurationMs / 1000).toStringAsFixed(1)}s sélectionnées',
                        style: TextStyle(color: _c.textPrimary, fontWeight: FontWeight.w700),
                      ),
                      Text(_fmt(_endMs), style: TextStyle(color: _c.textSecondary, fontSize: 13)),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── Zone waveform + poignées ────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: LayoutBuilder(
                    builder: (_, constraints) {
                      _barWidth = constraints.maxWidth;
                      return SizedBox(
                        height: 80,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Waveform en fond
                            ClipRect(
                              child: _waveCtrl != null
                                  ? AudioFileWaveforms(
                                      size: Size(_barWidth, 80),
                                      playerController: _waveCtrl!,
                                      waveformType: WaveformType.fitWidth,
                                      playerWaveStyle: PlayerWaveStyle(
                                        fixedWaveColor: Colors.white12,
                                        liveWaveColor: _c.primary,
                                        spacing: 3,
                                        waveThickness: 2.5,
                                      ),
                                    )
                                  : const SizedBox.expand(),
                            ),

                            // Zone sombre hors sélection (gauche)
                            Positioned(
                              left: 0,
                              top: 0,
                              bottom: 0,
                              width: _fracToX(_startFrac).clamp(0, _barWidth),
                              child: Container(color: Colors.black.withOpacity(0.55)),
                            ),

                            // Zone sombre hors sélection (droite)
                            Positioned(
                              right: 0,
                              top: 0,
                              bottom: 0,
                              width: (_barWidth - _fracToX(_endFrac)).clamp(0, _barWidth),
                              child: Container(color: Colors.black.withOpacity(0.55)),
                            ),

                            // Bordure de la sélection
                            Positioned(
                              left: _fracToX(_startFrac),
                              top: 0,
                              width: (_fracToX(_endFrac) - _fracToX(_startFrac)).clamp(0, _barWidth),
                              height: 80,
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: _c.primary, width: 2),
                                ),
                              ),
                            ),

                            // Curseur de lecture
                            if (_positionMs >= _startMs && _positionMs <= _endMs)
                              Positioned(
                                left: _fracToX(_positionMs / _totalMs) - 1,
                                top: 0,
                                bottom: 0,
                                width: 2,
                                child: Container(color: Colors.white70),
                              ),

                            // Poignée gauche (start)
                            Positioned(
                              left: (_fracToX(_startFrac) - 14).clamp(-4, _barWidth - 28),
                              top: 0,
                              bottom: 0,
                              width: 28,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onHorizontalDragUpdate: (d) => _updateStart(_fracToX(_startFrac) + d.delta.dx),
                                child: Center(
                                  child: Container(
                                    width: 20,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: _c.primary,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Icon(Icons.drag_handle, color: Colors.black, size: 16),
                                  ),
                                ),
                              ),
                            ),

                            // Poignée droite (end)
                            Positioned(
                              left: (_fracToX(_endFrac) - 14).clamp(-4, _barWidth - 28),
                              top: 0,
                              bottom: 0,
                              width: 28,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onHorizontalDragUpdate: (d) => _updateEnd(_fracToX(_endFrac) + d.delta.dx),
                                child: Center(
                                  child: Container(
                                    width: 20,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: _c.primary,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Icon(Icons.drag_handle, color: Colors.black, size: 16),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 8),

                // ── Durée totale du fichier ─────────────────────────────────
                Text(
                  'Durée totale : ${_fmt(_totalMs)}  ·  Max sélection : ${_fmt(widget.maxDurationMs)}',
                  style: TextStyle(fontSize: 11, color: _c.textSecondary),
                ),

                const SizedBox(height: 32),

                // ── Bouton lecture ──────────────────────────────────────────
                GestureDetector(
                  onTap: _togglePlay,
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: _c.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.black,
                      size: 32,
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                Text(
                  _isPlaying ? 'Lecture du clip en boucle…' : 'Écouter la sélection',
                  style: TextStyle(fontSize: 12, color: _c.textSecondary),
                ),
              ],
            ),
    );
  }
}
