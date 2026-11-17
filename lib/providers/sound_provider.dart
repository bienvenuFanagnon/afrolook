// lib/providers/sound_provider.dart
import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:volume_controller/volume_controller.dart';

import '../services/music_queue.dart';

class SoundProvider extends ChangeNotifier {
  bool _isMuted = false; // Par défaut : son activé (décision du 16/11/2026) ; le choix de la personne est retenu dès qu'elle touche le bouton
  late SharedPreferences _prefs;

  SoundProvider() {
    _loadSoundPreference();
  }

  bool get isMuted => _isMuted;
  static const _key = 'global_sound_muted_v2';

  Future<void> _loadSoundPreference() async {
    _prefs = await SharedPreferences.getInstance();
    // Nouvelle clé (16/11/2026) : l'ancienne avait été mise à « coupé » par la carte vidéo du fil, sans choix de la personne ;
    // tout le monde repart avec le son activé, puis son propre choix est retenu.
    _isMuted = _prefs.getBool(_key) ?? false;
    notifyListeners();
    _listenVolumeButtons();
  }

  StreamSubscription<double>? _volumeSub;
  double? _lastVolume;

  /// Boutons de volume du téléphone (2.1.9, 16/11/2026) : monter le volume quand le son des vidéos est coupé le réactive aussitôt.
  void _listenVolumeButtons() {
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS) || Platform.environment.containsKey('FLUTTER_TEST')) return;
    try {
      _volumeSub = VolumeController.instance.addListener(onVolume, fetchInitialVolume: true);
      _volumeSub!.onError((_) {});   // module absent ou indisponible : le bouton du son reste le seul réglage
    } catch (_) {}
  }

  /// Nouveau volume du téléphone (0 à 1). Le premier sert de référence ; une hausse réactive le son s'il était coupé.
  @visibleForTesting
  void onVolume(double v) {
    final before = _lastVolume;
    _lastVolume = v;
    if (before != null && v > before + 0.001 && _isMuted) setMuted(false);
  }

  @override
  void dispose() {
    _volumeSub?.cancel();
    super.dispose();
  }

  Future<void> toggleSound() async {
    _isMuted = !_isMuted;
    await _prefs.setBool(_key, _isMuted);
    _musicFollowsVideoSound();
    notifyListeners();
  }

  /// Le son des vidéos du fil est ouvert : la musique se met en pause (elle reprend quand le son des vidéos est recoupé).
  void _musicFollowsVideoSound() {
    if (_isMuted) {
      MusicQueue.release(this);
    } else {
      MusicQueue.suspend(this);
    }
  }

  void setMuted(bool muted) async {
    if (_isMuted != muted) {
      _isMuted = muted;
      await _prefs.setBool(_key, _isMuted);
      _musicFollowsVideoSound();
      notifyListeners();
    }
  }
}