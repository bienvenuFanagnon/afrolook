// Voix de la musique : à la fin de l'extrait gratuit d'un titre payant, une voix annonce que l'extrait est fini et le prix du titre,
// puis la lecture passe au titre suivant. Voix du téléphone (aucun envoi sur internet).

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class MusicVoice {
  MusicVoice._();

  /// Langue de l'application (« fr », « en »…), renseignée par le lecteur flottant.
  static String lang = 'fr';

  static FlutterTts? _tts;
  static bool _ready = false;
  static String? _setLang;

  /// Phrase dite à la fin de l'extrait : « Extrait gratuit terminé. Pour écouter la suite, achetez ce titre pour N pièces. »
  static String endOfPreview(int coins, {String? code}) {
    final l = code ?? lang;
    if (l == 'en') {
      return coins > 0 ? 'Free preview over. To hear the rest, buy this track for $coins coins.' : 'Free preview over.';
    }
    return coins > 0 ? 'Extrait gratuit terminé. Pour écouter la suite, achetez ce titre pour $coins pièces.' : 'Extrait gratuit terminé.';
  }

  static String _locale(String l) => switch (l) {
        'en' => 'en-US',
        'es' => 'es-ES',
        'de' => 'de-DE',
        'pt' => 'pt-PT',
        'ar' => 'ar',
        'zh' => 'zh-CN',
        'sw' => 'sw-KE',
        _ => 'fr-FR',
      };

  /// Dit [text] et rend la main quand c'est fini (au plus [maxWait]). Ne lève jamais d'erreur : sans voix disponible, on enchaîne.
  static Future<void> say(String text, {Duration maxWait = const Duration(seconds: 14)}) async {
    if (text.isEmpty) return;
    try {
      final tts = _tts ??= FlutterTts();
      if (!_ready) {
        await tts.awaitSpeakCompletion(true);
        await tts.setSpeechRate(0.48);
        await tts.setVolume(1.0);
        await tts.setPitch(1.0);
        _ready = true;
      }
      final loc = _locale(lang);
      if (_setLang != loc) {
        await tts.setLanguage(loc);
        _setLang = loc;
      }
      await tts.speak(text).timeout(maxWait, onTimeout: () async {
        await tts.stop();
        return 0;
      });
    } catch (e) {
      if (kDebugMode) debugPrint('MusicVoice: $e');
    }
  }

  static Future<void> stop() async {
    try {
      await _tts?.stop();
    } catch (_) {}
  }
}
