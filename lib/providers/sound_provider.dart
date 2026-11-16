// lib/providers/sound_provider.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/music_queue.dart';

class SoundProvider extends ChangeNotifier {
  bool _isMuted = false; // Par défaut : son activé (décision du 16/11/2026) ; le choix de la personne est retenu dès qu'elle touche le bouton
  late SharedPreferences _prefs;

  SoundProvider() {
    _loadSoundPreference();
  }

  bool get isMuted => _isMuted;

  Future<void> _loadSoundPreference() async {
    _prefs = await SharedPreferences.getInstance();
    _isMuted = _prefs.getBool('global_sound_muted') ?? false;
    notifyListeners();
  }

  Future<void> toggleSound() async {
    _isMuted = !_isMuted;
    await _prefs.setBool('global_sound_muted', _isMuted);
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
      await _prefs.setBool('global_sound_muted', _isMuted);
      _musicFollowsVideoSound();
      notifyListeners();
    }
  }
}