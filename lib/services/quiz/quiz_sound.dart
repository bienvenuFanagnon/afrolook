import 'dart:math' as math;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum QuizSfx { tap, ok, bad, win, hi, up }

class _Note {
  const _Note(this.freq, this.start, this.len, {this.wave = 'tri', this.gain = 0.5});
  final double freq, start, len, gain;
  final String wave;
}

/// Sons et vibrations du quiz. Les sons sont fabriqués par le code (petites mélodies) :
/// aucun fichier à ajouter, donc rien à télécharger et une mise à jour légère.
class QuizSound {
  QuizSound._();
  static const _kMuted = 'quiz_sound_muted';
  static const _rate = 22050;

  static bool _muted = false;
  static bool _loaded = false;
  static final Map<QuizSfx, Uint8List> _cache = {};
  static final Map<QuizSfx, AudioPlayer> _players = {};

  static const Map<QuizSfx, List<_Note>> _tunes = {
    QuizSfx.tap: [_Note(440, 0, 0.04, wave: 'sq', gain: 0.25)],
    QuizSfx.ok: [_Note(523.25, 0, 0.13), _Note(659.25, 0.09, 0.13), _Note(783.99, 0.18, 0.26)],
    QuizSfx.bad: [_Note(220, 0, 0.18, wave: 'saw', gain: 0.35), _Note(164.81, 0.14, 0.3, wave: 'saw', gain: 0.35)],
    QuizSfx.win: [
      _Note(523.25, 0, 0.18), _Note(659.25, 0.12, 0.18), _Note(783.99, 0.24, 0.18),
      _Note(1046.5, 0.36, 0.22), _Note(1318.5, 0.5, 0.4),
    ],
    QuizSfx.hi: [_Note(698.46, 0, 0.09, wave: 'sin'), _Note(932.33, 0.07, 0.14, wave: 'sin')],
    QuizSfx.up: [_Note(440, 0, 0.1), _Note(554.37, 0.08, 0.1), _Note(659.25, 0.16, 0.18)],
  };

  static const Map<QuizSfx, String> _fallback = {
    QuizSfx.tap: 'sounds/tuto_tick.wav',
    QuizSfx.ok: 'sounds/tuto_success.wav',
    QuizSfx.bad: 'sounds/tuto_tick.wav',
    QuizSfx.win: 'sounds/tuto_success.wav',
    QuizSfx.hi: 'sounds/tuto_pop.wav',
    QuizSfx.up: 'sounds/tuto_rise.wav',
  };

  static Future<void> _load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final sp = await SharedPreferences.getInstance();
      _muted = sp.getBool(_kMuted) ?? false;
    } catch (_) {}
  }

  static Future<bool> isMuted() async {
    await _load();
    return _muted;
  }

  static Future<void> setMuted(bool v) async {
    _muted = v;
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setBool(_kMuted, v);
    } catch (_) {}
  }

  static Future<void> play(QuizSfx sfx) async {
    await _load();
    if (_muted || kIsWeb) return;
    try {
      final p = _players.putIfAbsent(sfx, () {
        final player = AudioPlayer()..setReleaseMode(ReleaseMode.stop);
        // Sons très courts : ils se mélangent à la musique d'une autre application au lieu de la couper
        player.setAudioContext(AudioContext(
          android: const AudioContextAndroid(
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.game,
            audioFocus: AndroidAudioFocus.none,
          ),
          iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
        ));
        return player;
      });
      await p.stop();
      try {
        final bytes = _cache.putIfAbsent(sfx, () => _wav(_tunes[sfx]!));
        await p.play(BytesSource(bytes), volume: 0.8);
      } catch (e) {
        // Repli : sons déjà présents dans l'application
        debugPrint('[QuizSound] $e');
        await p.play(AssetSource(_fallback[sfx]!), volume: 0.8);
      }
    } catch (e) {
      debugPrint('[QuizSound] $e');
    }
  }

  static void haptic(QuizSfx sfx) {
    if (_muted) return;
    try {
      if (sfx == QuizSfx.bad) {
        HapticFeedback.mediumImpact();
      } else if (sfx == QuizSfx.win) {
        HapticFeedback.heavyImpact();
      } else {
        HapticFeedback.lightImpact();
      }
    } catch (_) {}
  }

  /// Joue le son et fait vibrer l'appareil en même temps.
  static void fx(QuizSfx sfx) {
    haptic(sfx);
    play(sfx);
  }

  /// Pour les tests : le fichier WAV fabriqué pour un son.
  @visibleForTesting
  static Uint8List debugWav(QuizSfx sfx) => _wav(_tunes[sfx]!);

  /// Fabrique un fichier WAV (16 bits, mono) à partir d'une suite de notes.
  static Uint8List _wav(List<_Note> notes) {
    final total = notes.map((n) => n.start + n.len).reduce(math.max) + 0.05;
    final count = (total * _rate).ceil();
    final samples = Float64List(count);
    for (final n in notes) {
      final from = (n.start * _rate).floor();
      final to = math.min(count, ((n.start + n.len) * _rate).ceil());
      for (var i = from; i < to; i++) {
        final t = (i - from) / _rate;
        final attack = math.min(1.0, t / 0.008);
        final decay = math.exp(-3.2 * t / n.len);
        final phase = (t * n.freq) % 1.0;
        double w;
        switch (n.wave) {
          case 'sq':
            w = phase < 0.5 ? 1.0 : -1.0;
            break;
          case 'saw':
            w = 2 * phase - 1;
            break;
          case 'sin':
            w = math.sin(2 * math.pi * phase);
            break;
          default:
            w = 4 * (phase - 0.5).abs() - 1; // triangle
        }
        samples[i] += w * attack * decay * n.gain;
      }
    }
    final data = ByteData(44 + count * 2);
    void str(int off, String s) {
      for (var i = 0; i < s.length; i++) {
        data.setUint8(off + i, s.codeUnitAt(i));
      }
    }

    str(0, 'RIFF');
    data.setUint32(4, 36 + count * 2, Endian.little);
    str(8, 'WAVE');
    str(12, 'fmt ');
    data.setUint32(16, 16, Endian.little);
    data.setUint16(20, 1, Endian.little);
    data.setUint16(22, 1, Endian.little);
    data.setUint32(24, _rate, Endian.little);
    data.setUint32(28, _rate * 2, Endian.little);
    data.setUint16(32, 2, Endian.little);
    data.setUint16(34, 16, Endian.little);
    str(36, 'data');
    data.setUint32(40, count * 2, Endian.little);
    for (var i = 0; i < count; i++) {
      final v = (samples[i].clamp(-1.0, 1.0) * 32767).round();
      data.setInt16(44 + i * 2, v, Endian.little);
    }
    return data.buffer.asUint8List();
  }
}
