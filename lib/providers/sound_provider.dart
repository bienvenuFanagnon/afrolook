// lib/providers/sound_provider.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SoundProvider extends ChangeNotifier {
  bool _isMuted = true; // Par défaut : son coupé (comme Instagram)
  late SharedPreferences _prefs;

  SoundProvider() {
    _loadSoundPreference();
  }

  bool get isMuted => _isMuted;

  Future<void> _loadSoundPreference() async {
    _prefs = await SharedPreferences.getInstance();
    _isMuted = _prefs.getBool('global_sound_muted') ?? true;
    notifyListeners();
  }

  Future<void> toggleSound() async {
    _isMuted = !_isMuted;
    await _prefs.setBool('global_sound_muted', _isMuted);
    notifyListeners();
  }

  void setMuted(bool muted) async {
    if (_isMuted != muted) {
      _isMuted = muted;
      await _prefs.setBool('global_sound_muted', _isMuted);
      notifyListeners();
    }
  }
}