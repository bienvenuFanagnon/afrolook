import 'dart:async';
import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lecture des questions à voix haute. Les voix (féminine par défaut, masculine au choix) sont fabriquées à l'avance
/// par `tools/quiz/gen_tts.js` : un petit mp3 par question et par réponse, dans Storage (quiz_tts/{f|m}/{empreinte}.mp3).
/// L'app retrouve chaque fichier grâce à l'empreinte du texte, sans rien demander au serveur, et le garde en cache.
/// Si un fichier manque (réseau, nouvelle question pas encore enregistrée), la lecture continue sans lui.
class QuizVoice {
  QuizVoice._();
  static final QuizVoice instance = QuizVoice._();

  static const _kOn = 'quiz_voice_on';
  static const _kGender = 'quiz_voice_gender';
  static const _base = 'https://firebasestorage.googleapis.com/v0/b/afrolooki.appspot.com/o/';
  static const sample = 'Bonjour ! Je suis ton guide Afrolook. Écoute bien la question.';

  bool _loaded = false;
  bool _on = true;
  String _gender = 'f';
  int _token = 0;
  AudioPlayer? _player;

  /// Vrai pendant que la voix parle (l'épervier ouvre le bec).
  final ValueNotifier<bool> speaking = ValueNotifier<bool>(false);

  /// Réglages modifiables depuis l'écran « Voix » (écoutés par les pages du quiz).
  final ValueNotifier<int> settingsVersion = ValueNotifier<int>(0);

  bool get enabled => _on && !kIsWeb;
  String get gender => _gender;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final sp = await SharedPreferences.getInstance();
      _on = sp.getBool(_kOn) ?? true;
      _gender = sp.getString(_kGender) == 'm' ? 'm' : 'f';
    } catch (_) {}
  }

  Future<void> setEnabled(bool v) async {
    await load();
    _on = v;
    if (!v) stop();
    settingsVersion.value++;
    try {
      (await SharedPreferences.getInstance()).setBool(_kOn, v);
    } catch (_) {}
  }

  Future<void> setGender(String g) async {
    await load();
    _gender = g == 'm' ? 'm' : 'f';
    settingsVersion.value++;
    try {
      (await SharedPreferences.getInstance()).setString(_kGender, _gender);
    } catch (_) {}
  }

  /// Empreinte FNV-1a 64 bits du texte (UTF-8) en 16 caractères hexadécimaux, identique à celle du script de fabrication.
  @visibleForTesting
  static String hash(String text) {
    var h = 0xcbf29ce484222325;
    for (final b in utf8.encode(text.trim())) {
      h ^= b;
      h *= 0x100000001b3;
    }
    String half(int v) => (v & 0xffffffff).toRadixString(16).padLeft(8, '0');
    return half(h >>> 32) + half(h);
  }

  String _url(String text) => '${_base}quiz_tts%2F$_gender%2F${hash(text)}.mp3?alt=media';

  Future<String?> _file(String text) async {
    try {
      return (await DefaultCacheManager().getSingleFile(_url(text))).path;
    } catch (_) {
      return null;
    }
  }

  /// Télécharge à l'avance (sans rien jouer) les voix d'une série de questions.
  Future<void> prefetch(Iterable<({String q, List<String> o})> questions) async {
    await load();
    if (!enabled) return;
    for (final x in questions) {
      unawaited(_file(x.q));
      for (final o in x.o) {
        unawaited(_file(o));
      }
    }
  }

  AudioPlayer _ensurePlayer() {
    return _player ??= AudioPlayer()
      ..setReleaseMode(ReleaseMode.stop)
      ..setAudioContext(AudioContext(
        android: const AudioContextAndroid(
          contentType: AndroidContentType.speech,
          usageType: AndroidUsageType.media,
          audioFocus: AndroidAudioFocus.gainTransientMayDuck,
        ),
        iOS: AudioContextIOS(category: AVAudioSessionCategory.playback, options: const [AVAudioSessionOptions.duckOthers]),
      ));
  }

  Future<void> _playFile(String path, int token) async {
    if (token != _token) return;
    final p = _ensurePlayer();
    final done = Completer<void>();
    final sub = p.onPlayerComplete.listen((_) {
      if (!done.isCompleted) done.complete();
    });
    try {
      await p.play(DeviceFileSource(path));
      await done.future.timeout(const Duration(seconds: 25), onTimeout: () {});
    } finally {
      await sub.cancel();
    }
  }

  /// Lit la question puis chaque réponse (« A. … B. … »). [options] peut contenir `null` pour une réponse retirée (joker 50/50).
  /// Un nouvel appel, ou [stop], interrompt la lecture en cours.
  Future<void> speakQuestion(String question, List<String?> options) async {
    await load();
    if (!enabled) return;
    final token = ++_token;
    try {
      await _player?.stop();
    } catch (_) {}
    // Tout part en parallèle : la lecture commence dès que la question est arrivée, les réponses suivent.
    final qf = _file(question);
    final letters = ['A.', 'B.', 'C.', 'D.'];
    final lf = [for (var i = 0; i < options.length && i < 4; i++) options[i] == null ? null : _file(letters[i])];
    final of = [for (final o in options) o == null ? null : _file(o)];
    speaking.value = true;
    try {
      final qp = await qf;
      if (qp != null) await _playFile(qp, token);
      for (var i = 0; i < of.length; i++) {
        if (token != _token) return;
        if (of[i] == null) continue;
        await Future<void>.delayed(const Duration(milliseconds: 220));
        final l = lf[i] == null ? null : await lf[i];
        if (l != null) await _playFile(l, token);
        final o = await of[i];
        if (o != null) await _playFile(o, token);
      }
    } catch (e) {
      debugPrint('[QuizVoice] $e');
    } finally {
      if (token == _token) speaking.value = false;
    }
  }

  /// Joue la phrase d'essai de l'écran « Voix ».
  Future<void> speakSample() async {
    await load();
    final token = ++_token;
    try {
      await _player?.stop();
    } catch (_) {}
    final f = await _file(sample);
    if (f == null) return;
    speaking.value = true;
    try {
      await _playFile(f, token);
    } finally {
      if (token == _token) speaking.value = false;
    }
  }

  void stop() {
    _token++;
    speaking.value = false;
    try {
      _player?.stop();
    } catch (_) {}
  }
}
