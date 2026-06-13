import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/chatmodels/message.dart';

/// Cache local (SharedPreferences) des derniers messages d'une conversation.
///
/// Objectif : afficher instantanément les messages déjà vus à l'ouverture
/// d'un chat (style WhatsApp) pendant que le flux Firestore se (re)connecte,
/// et éviter de redessiner tout l'écran à vide à chaque ouverture.
class ChatCacheService {
  static const String _prefix = 'chat_messages_';

  /// Nombre maximum de messages conservés en cache par conversation.
  static const int maxCachedMessages = 60;

  static String _key(String chatId) => '$_prefix$chatId';

  /// Sauvegarde les [maxCachedMessages] derniers messages de la conversation.
  static Future<void> saveMessages(String chatId, List<Message> messages) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final toCache = messages.length > maxCachedMessages
          ? messages.sublist(messages.length - maxCachedMessages)
          : messages;
      final jsonList = toCache.map(_toCacheMap).toList();
      await prefs.setString(_key(chatId), jsonEncode(jsonList));
    } catch (e) {
      // Le cache est un confort, jamais bloquant.
      print('⚠️ ChatCacheService.saveMessages error ($chatId): $e');
    }
  }

  /// Charge les messages mis en cache pour la conversation (ordre chronologique).
  static Future<List<Message>> loadMessages(String chatId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key(chatId));
      if (raw == null) return [];

      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];

      return decoded
          .whereType<Map<String, dynamic>>()
          .map(_fromCacheMap)
          .whereType<Message>()
          .toList();
    } catch (e) {
      print('⚠️ ChatCacheService.loadMessages error ($chatId): $e');
      return [];
    }
  }

  /// Représentation JSON-safe d'un [Message] (sans `DateTime`/`Duration`
  /// non sérialisables directement).
  static Map<String, dynamic> _toCacheMap(Message m) {
    final json = m.toJson();
    json.remove('createdAt'); // recréé depuis create_at_time_spam au chargement
    // Duration n'est pas sérialisable en JSON : on ne le met pas en cache,
    // il sera de toute façon rafraîchi par le flux Firestore.
    json['voice_message_duration'] = null;

    final reply = json['reply_message'] as Map<String, dynamic>?;
    if (reply != null) {
      reply['voiceMessageDuration'] = null;
    }
    return json;
  }

  static Message? _fromCacheMap(Map<String, dynamic> json) {
    try {
      return Message.fromJson(json);
    } catch (e) {
      return null;
    }
  }
}
