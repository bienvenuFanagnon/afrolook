import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NavigationCacheService {
  static const String _keyPendingNavigation = 'pending_navigation';

  // Ajout du navigatorKey
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static final NavigationCacheService _instance = NavigationCacheService._internal();
  factory NavigationCacheService() => _instance;
  NavigationCacheService._internal();

  // Stocker une navigation en cache
  Future<void> storePendingNavigation(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPendingNavigation, jsonEncode(data));
    print("💾 [CACHE] Navigation stockée: $data");
  }

  // Récupérer et VIDER le cache
  Future<Map<String, dynamic>?> getAndClearPendingNavigation() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonString = prefs.getString(_keyPendingNavigation);

    if (jsonString == null) return null;

    // Supprimer immédiatement du cache
    await prefs.remove(_keyPendingNavigation);

    print("🗑️ [CACHE] Cache vidé après lecture");
    return jsonDecode(jsonString) as Map<String, dynamic>;
  }

  // Vérifier si un cache existe
  Future<bool> hasPendingNavigation() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_keyPendingNavigation);
  }

  // Stockage simplifié pour les différents types
  Future<void> storePostNavigation(String postId, String postType) async {
    await storePendingNavigation({
      'type': 'post',
      'postId': postId,
      'postType': postType,
    });
  }

  Future<void> storeMessageNavigation(String chatId, String sendUserId) async {
    await storePendingNavigation({
      'type': 'message',
      'chatId': chatId,
      'sendUserId': sendUserId,
    });
  }

  Future<void> storeChroniqueNavigation(String chroniqueId) async {
    await storePendingNavigation({
      'type': 'chronique',
      'chroniqueId': chroniqueId,
    });
  }

  Future<void> storeChroniqueHomeNavigation() async {
    await storePendingNavigation({
      'type': 'chronique_home',
    });
  }

  Future<void> storeInvitationNavigation() async {
    await storePendingNavigation({
      'type': 'invitation',
    });
  }

  Future<void> storeAcceptInvitationNavigation() async {
    await storePendingNavigation({
      'type': 'acceptInvitation',
    });
  }

  Future<void> storeParrainageNavigation() async {
    await storePendingNavigation({
      'type': 'parrainage',
    });
  }

  Future<void> storeArticleNavigation() async {
    await storePendingNavigation({
      'type': 'article',
    });
  }
}