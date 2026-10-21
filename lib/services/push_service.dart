import 'dart:async';
import 'dart:convert';

import 'package:afrotok/models/model_data.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'nav_cache_service.dart';
import 'workManagerService.dart';

/// Notifications push via Firebase Cloud Messaging (FCM) : canal principal, gratuit et sans quota (OneSignal ne sert plus que de secours
/// pour les personnes qui n'ont pas encore de jeton FCM — voir functions/src/shared/push.ts).
///
/// - Chaque appareil enregistre son jeton dans `Users/{id}.fcmTokens` (le serveur retire lui-même les jetons devenus invalides).
/// - Application fermée ou en arrière-plan : Android / iOS affichent la notification eux-mêmes ; le toucher ouvre l'écran voulu.
/// - Application ouverte : FCM n'affiche rien, on affiche donc la notification localement (Android ; iOS la montre nativement).
class PushService {
  PushService._();

  /// Canal Android à importance haute (même identifiant que celui envoyé par le serveur dans le message).
  static const String channelId = 'afrolook_push';
  static const String _savedKey = 'fcm_token_saved';

  /// Appelé quand une notification touchée demande d'ouvrir l'application sur un écran précis (relance sur l'écran d'accueil).
  static void Function()? onNavigate;

  static bool _initialized = false;
  static String? _userId;

  /// À appeler une fois au démarrage, après l'initialisation de Firebase. Sans effet sur le web.
  static Future<void> init() async {
    if (kIsWeb || _initialized) return;
    _initialized = true;
    try {
      await initLocalNotifications();
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(const AndroidNotificationChannel(
            channelId,
            'Notifications Afrolook',
            description: 'Messages, mentions, cadeaux et activité de votre compte',
            importance: Importance.high,
          ));

      // iOS : afficher aussi la notification quand l'application est ouverte
      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(alert: true, badge: true, sound: true);

      FirebaseMessaging.onMessage.listen(_showForeground);
      FirebaseMessaging.onMessageOpenedApp.listen((m) async {
        await storeNavigationFromPush(m.data);
        onNavigate?.call();
      });
      FirebaseMessaging.instance.onTokenRefresh.listen((t) {
        final uid = _userId;
        if (uid != null) _save(uid, t);
      });

      // Application ouverte en touchant une notification alors qu'elle était fermée : le démarrage passe déjà par l'accueil
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) await storeNavigationFromPush(initial.data);
    } catch (e) {
      debugPrint('⚠️ PushService.init : $e');
    }
  }

  /// Enregistre le jeton FCM de cet appareil pour la personne connectée. Sans erreur remontée : la connexion ne doit jamais en dépendre.
  static Future<void> registerForUser(String userId) async {
    if (kIsWeb || userId.isEmpty) return;
    _userId = userId;
    try {
      final settings = await FirebaseMessaging.instance.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _save(userId, token);
    } catch (e) {
      // iOS : le jeton APNs peut ne pas être encore prêt ; onTokenRefresh prendra le relais
      debugPrint('⚠️ PushService.registerForUser : $e');
    }
  }

  /// À la déconnexion (avant la fermeture de session Firebase) : cet appareil ne doit plus recevoir les notifications de ce compte.
  static Future<void> unregisterForUser(String userId) async {
    if (kIsWeb || userId.isEmpty) return;
    _userId = null;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await FirebaseFirestore.instance.collection('Users').doc(userId).update({
          'fcmTokens': FieldValue.arrayRemove([token]),
        });
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_savedKey);
    } catch (e) {
      debugPrint('⚠️ PushService.unregisterForUser : $e');
    }
  }

  static Future<void> _save(String userId, String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final marker = '$userId|$token';
      if (prefs.getString(_savedKey) == marker) return; // déjà enregistré : aucune écriture
      await FirebaseFirestore.instance.collection('Users').doc(userId).update({
        'fcmTokens': FieldValue.arrayUnion([token]),
        'fcmTokenUpdatedAt': DateTime.now().millisecondsSinceEpoch,
      });
      await prefs.setString(_savedKey, marker);
    } catch (e) {
      debugPrint('⚠️ PushService._save : $e');
    }
  }

  static Future<void> _showForeground(RemoteMessage m) async {
    final n = m.notification;
    if (n == null || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await flutterLocalNotificationsPlugin.show(
        m.hashCode & 0x7fffffff,
        n.title,
        n.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            'Notifications Afrolook',
            importance: Importance.high,
            priority: Priority.high,
            icon: 'notification_icon',
          ),
        ),
        payload: jsonEncode({'push': m.data}),
      );
    } catch (e) {
      debugPrint('⚠️ PushService._showForeground : $e');
    }
  }

  /// Notification affichée localement (application ouverte) puis touchée : même destination que pour une notification système.
  static Future<void> handleLocalTap(Map<String, dynamic> push) async {
    await storeNavigationFromPush(push);
    onNavigate?.call();
  }
}

/// Mémorise l'écran à ouvrir selon les données de la notification (type_notif, post_id, post_type, chat_id, send_user_id).
/// Partagé par OneSignal (touché) et FCM : même comportement quel que soit le canal.
Future<void> storeNavigationFromPush(Map<String, dynamic> data) async {
  final typeNotif = data['type_notif']?.toString();
  final postType = data['post_type']?.toString() ?? '';
  final postId = data['post_id']?.toString();
  final chatId = data['chat_id']?.toString();
  final sendUserId = data['send_user_id']?.toString();
  final nav = NavigationCacheService();
  final hasPost = postId != null && postId.isNotEmpty;

  if (postType == 'CHRONIQUE' || typeNotif == 'CHRONIQUE' || typeNotif == 'COMMENT_LIKE') {
    if (hasPost) {
      await nav.storeChroniqueNavigation(postId);
    } else {
      await nav.storePendingNavigation({'type': 'chronique_home'});
    }
  } else if (typeNotif == NotificationType.MESSAGE.name) {
    if (chatId != null && chatId.isNotEmpty && sendUserId != null && sendUserId.isNotEmpty) {
      await nav.storeMessageNavigation(chatId, sendUserId);
    }
  } else if (typeNotif == NotificationType.INVITATION.name) {
    await nav.storeInvitationNavigation();
  } else if (typeNotif == NotificationType.ACCEPTINVITATION.name) {
    await nav.storeAcceptInvitationNavigation();
  } else if (typeNotif == NotificationType.PARRAINAGE.name) {
    await nav.storeParrainageNavigation();
  } else if (typeNotif == NotificationType.ARTICLE.name) {
    await nav.storeArticleNavigation();
  } else if (typeNotif == NotificationType.POST.name || typeNotif == NotificationType.FAVORITE.name) {
    if (hasPost) await nav.storePostNavigation(postId, postType);
  }
}
