import 'dart:async';
import 'dart:convert';
import 'package:afrotok/pages/component/consoleWidget.dart';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NavigationCacheService {
  static const String _keyPendingNavigation = 'pending_navigation';

  // Ajout du navigatorKey
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static final NavigationCacheService _instance = NavigationCacheService._internal();
  factory NavigationCacheService() => _instance;
  NavigationCacheService._internal();

  // Stream utilisé pour notifier HomeScreen quand l'app est déjà ouverte
  final StreamController<Map<String, dynamic>> _liveNavController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get liveNavigationStream => _liveNavController.stream;

  // Stocker une navigation en cache ET émettre sur le stream si l'app est ouverte
  Future<void> storePendingNavigation(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPendingNavigation, jsonEncode(data));
    printVm("💾 [CACHE] Navigation stockée: $data");
    _liveNavController.add(data);
  }

  // Récupérer et VIDER le cache
  Future<Map<String, dynamic>?> getAndClearPendingNavigation() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonString = prefs.getString(_keyPendingNavigation);

    if (jsonString == null) return null;

    // Supprimer immédiatement du cache
    await prefs.remove(_keyPendingNavigation);

    printVm("🗑️ [CACHE] Cache vidé après lecture");
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

  Future<void> storeGroupNavigation(String joinCode) async {
    await storePendingNavigation({
      'type': 'group',
      'joinCode': joinCode,
    });
  }

  Future<void> storeContenuNavigation(String contentId, {String? affiliateId}) async {
    await storePendingNavigation({
      'type': 'contenu',
      'contentId': contentId,
      if (affiliateId != null) 'affiliateId': affiliateId,
    });
  }

  Future<void> storeCreatorNavigation(String userId) async {
    await storePendingNavigation({
      'type': 'creator',
      'userId': userId,
    });
  }

  Future<void> storeCanalNavigation(String canalId) async {
    await storePendingNavigation({
      'type': 'canal',
      'canalId': canalId,
    });
  }
}