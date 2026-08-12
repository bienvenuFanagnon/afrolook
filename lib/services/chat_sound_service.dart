import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatSoundService {
  static const _prefKey = 'chat_sounds_muted';
  static final AudioPlayer _player = AudioPlayer();

  static Future<bool> isMuted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefKey) ?? false;
  }

  static Future<void> setMuted(bool muted) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, muted);
  }

  /// Son discret type Messenger — reçu en étant dans le chat
  static Future<void> playInChat() async {
    if (kIsWeb) return;
    if (await isMuted()) return;
    try {
      await _player.play(AssetSource('sounds/msg_receive.mp3'));
    } catch (_) {}
  }

  /// Son de notification — reçu dans l'app mais hors du chat
  static Future<void> playNotification() async {
    if (kIsWeb) return;
    if (await isMuted()) return;
    try {
      await _player.play(AssetSource('sounds/msg_notify.mp3'));
    } catch (_) {}
  }
}
