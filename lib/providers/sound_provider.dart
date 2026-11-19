// lib/providers/sound_provider.dart
import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:volume_controller/volume_controller.dart';

import '../services/music_queue.dart';

/// Pubs vidéo Afrolook Ads qui jouent AVEC le son (décision du propriétaire, 19/11/2026) : la pub démarre toujours avec le son,
/// et tant qu'elle le joue, les autres vidéos (via [SoundProvider.isMuted]) et la musique se taisent ; elles reprennent quand la pub
/// est coupée, mise en pause, quittée ou fermée. Chaque pub s'enregistre avec un propriétaire (son contrôleur ou son écran).
class AdSoundFocus {
  AdSoundFocus._();
  static final Set<Object> _owners = <Object>{};
  static final ValueNotifier<int> holders = ValueNotifier<int>(0);

  static bool get active => _owners.isNotEmpty;

  static void hold(Object owner) {
    if (_owners.add(owner)) holders.value = _owners.length;
  }

  static void release(Object owner) {
    if (_owners.remove(owner)) holders.value = _owners.length;
  }

  /// [hold] si [on], sinon [release].
  static void set(Object owner, bool on) => on ? hold(owner) : release(owner);

  /// Pour les tests.
  @visibleForTesting
  static void reset() {
    _owners.clear();
    holders.value = 0;
  }
}

class SoundProvider extends ChangeNotifier {
  bool _isMuted = false; // Par défaut : son activé (décision du 16/11/2026) ; le choix de la personne est retenu dès qu'elle touche le bouton
  late SharedPreferences _prefs;

  SoundProvider() {
    _loadSoundPreference();
    AdSoundFocus.holders.addListener(_onAdSound);
  }

  /// Coupé par la personne, ou pendant qu'une pub vidéo joue avec le son ([AdSoundFocus]).
  bool get isMuted => _isMuted || AdSoundFocus.active;

  final Object _adMusicToken = Object();
  bool _adHeld = false;

  void _onAdSound() {
    final active = AdSoundFocus.active;
    if (active == _adHeld) return;
    _adHeld = active;
    active ? MusicQueue.suspend(_adMusicToken) : MusicQueue.release(_adMusicToken);   // la musique se tait pendant la pub
    notifyListeners();   // les vidéos du fil appliquent le nouveau volume
  }
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
    AdSoundFocus.holders.removeListener(_onAdSound);
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