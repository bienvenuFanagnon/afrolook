import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ambiance de veillée : bourdon chaud, notes de kora, crépitement de feu et grillons, en boucle, volume bas.
/// Le son est fabriqué par le code (aucun fichier à télécharger). Le lecteur peut le couper à tout moment ; son choix est mémorisé.
class ConteAmbience {
  ConteAmbience._();
  static const _kMuted = 'contes_sound_muted';
  static const _rate = 22050;

  /// true quand le lecteur a coupé l'ambiance.
  static final ValueNotifier<bool> muted = ValueNotifier<bool>(false);
  static bool _loaded = false;
  static bool _playing = false;
  static AudioPlayer? _player;
  static Future<Uint8List>? _bytes;

  static Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final sp = await SharedPreferences.getInstance();
      muted.value = sp.getBool(_kMuted) ?? false;
    } catch (_) {}
  }

  static Future<void> setMuted(bool v) async {
    muted.value = v;
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setBool(_kMuted, v);
    } catch (_) {}
    if (v) {
      await stop();
    } else {
      await start();
    }
  }

  /// Lance la boucle (sans effet si le lecteur a coupé le son ou sur le web).
  static Future<void> start() async {
    await load();
    if (muted.value || kIsWeb || _playing) return;
    try {
      _bytes ??= compute(_build, _rate);
      final bytes = await _bytes!;
      if (muted.value) return;
      final p = _player ??= AudioPlayer()
        ..setReleaseMode(ReleaseMode.loop)
        ..setAudioContext(AudioContext(
          // se mélange à la musique d'une autre application au lieu de la couper
          android: const AudioContextAndroid(contentType: AndroidContentType.music, usageType: AndroidUsageType.media, audioFocus: AndroidAudioFocus.none),
          iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
        ));
      _playing = true;
      await p.play(BytesSource(bytes), volume: 0.32);
    } catch (e) {
      _playing = false;
      debugPrint('[ConteAmbience] $e');
    }
  }

  static Future<void> pause() async {
    try {
      if (_playing) await _player?.pause();
    } catch (_) {}
  }

  static Future<void> resume() async {
    try {
      if (_playing && !muted.value) await _player?.resume();
    } catch (_) {}
  }

  static Future<void> stop() async {
    _playing = false;
    try {
      await _player?.stop();
    } catch (_) {}
  }

  static Future<void> dispose() async {
    await stop();
    try {
      await _player?.dispose();
    } catch (_) {}
    _player = null;
  }
}

/// Fabrique la boucle (24 s, mono, 16 bits). Les composantes régulières ont un nombre entier de cycles
/// et la fin est fondue dans le début : la boucle ne « claque » pas.
Uint8List _build(int rate) {
  const secs = 24;
  const fadeSecs = 0.6;
  final total = rate * secs;
  final cross = (rate * fadeSecs).round();
  final n = total + cross;
  final buf = Float64List(n);
  final rnd = math.Random(2026);
  const twoPi = math.pi * 2;

  // bourdon : fréquences à nombre entier de cycles sur 24 s
  for (var i = 0; i < n; i++) {
    final t = i / rate;
    final swell = 0.75 + 0.25 * math.sin(twoPi * t / secs * 2);
    buf[i] += swell * (0.085 * math.sin(twoPi * 110 * t) + 0.05 * math.sin(twoPi * 165 * t + 0.6 * math.sin(twoPi * t / 12)) + 0.04 * math.sin(twoPi * 220 * t));
  }

  // souffle de nuit : bruit filtré, très doux
  var y = 0.0;
  for (var i = 0; i < n; i++) {
    y += 0.012 * ((rnd.nextDouble() * 2 - 1) - y);
    buf[i] += y * 0.55;
  }

  // notes de kora (gamme pentatonique), jamais deux trop proches
  const scale = [261.63, 293.66, 329.63, 392.0, 440.0];
  var t = 0.8;
  while (t < secs - 1.2) {
    final f = scale[rnd.nextInt(scale.length)] * (rnd.nextDouble() < .35 ? .5 : 1.0);
    final start = (t * rate).round();
    final len = (rate * 3.2).round();
    final amp = 0.15 + rnd.nextDouble() * 0.06;
    for (var j = 0; j < len; j++) {
      final tt = j / rate;
      final env = (1 - math.exp(-tt * 260)) * math.exp(-tt * 1.15);
      final v = (math.sin(twoPi * f * tt) + 0.34 * math.sin(twoPi * 2 * f * tt) + 0.13 * math.sin(twoPi * 3 * f * tt)) * env * amp;
      buf[(start + j) % total] += v;
    }
    t += 1.0 + rnd.nextDouble() * 2.4;
  }

  // crépitement du feu : petites impulsions
  for (var k = 0; k < secs * 22; k++) {
    if (rnd.nextDouble() > .5) continue;
    final at = rnd.nextInt(total);
    final len = (rate * (0.002 + rnd.nextDouble() * 0.006)).round();
    final amp = 0.07 + rnd.nextDouble() * 0.22;
    for (var j = 0; j < len; j++) {
      buf[(at + j) % total] += (rnd.nextDouble() * 2 - 1) * amp * (1 - j / len);
    }
  }

  // grillons : trois courts chants très discrets
  for (var g = 0; g < 3; g++) {
    final at = (rnd.nextDouble() * (secs - 3)) * rate;
    final len = (rate * 1.4).round();
    for (var j = 0; j < len; j++) {
      final tt = j / rate;
      final gate = math.sin(twoPi * 26 * tt) > 0.2 ? 1.0 : 0.0;
      final env = math.sin(math.pi * j / len);
      buf[(at.round() + j) % total] += math.sin(twoPi * 4300 * tt) * gate * env * 0.014;
    }
  }

  // la fin est fondue dans le début (boucle sans coupure)
  final out = Float64List(total);
  for (var i = 0; i < total; i++) {
    out[i] = buf[i];
  }
  for (var i = 0; i < cross; i++) {
    final w = i / cross;
    out[i] = buf[i] * w + buf[total + i] * (1 - w);
  }
  var peak = 0.0;
  for (final v in out) {
    if (v.abs() > peak) peak = v.abs();
  }
  final gain = peak > 0 ? 0.82 / peak : 1.0;

  final data = ByteData(44 + total * 2);
  void str(int off, String s) {
    for (var i = 0; i < s.length; i++) {
      data.setUint8(off + i, s.codeUnitAt(i));
    }
  }

  str(0, 'RIFF');
  data.setUint32(4, 36 + total * 2, Endian.little);
  str(8, 'WAVE');
  str(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, rate, Endian.little);
  data.setUint32(28, rate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  str(36, 'data');
  data.setUint32(40, total * 2, Endian.little);
  for (var i = 0; i < total; i++) {
    data.setInt16(44 + i * 2, (out[i] * gain * 32767).round().clamp(-32767, 32767), Endian.little);
  }
  return data.buffer.asUint8List();
}
