import 'dart:async';
import 'dart:convert';

import 'package:afrotok/models/model_data.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:ui' show PlatformDispatcher;

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

  /// Canal Android à importance haute avec le son Afrolook (même identifiant que celui envoyé par le serveur et le manifest). Un canal garde son
  /// son pour toujours : la version 2 apporte le son `afrolook_chime` (android/app/src/main/res/raw).
  static const String channelId = 'afrolook_push_v2';
  static const _sound = RawResourceAndroidNotificationSound('afrolook_chime');
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
      // une erreur d'initialisation des notifications locales ne doit jamais empêcher d'écouter FCM
      try {
        await initLocalNotifications();
      } catch (e) {
        debugPrint('⚠️ PushService : notifications locales : $e');
      }
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(const AndroidNotificationChannel(
            channelId,
            'Notifications Afrolook',
            description: 'Messages, mentions, cadeaux, rappels et activité de votre compte',
            importance: Importance.high,
            sound: _sound,
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

  /// Langue choisie dans l'application (sinon celle du téléphone), parmi les langues supportées.
  static String _currentLang(SharedPreferences prefs) {
    final code = (prefs.getString('app_locale') ?? PlatformDispatcher.instance.locale.languageCode).toLowerCase();
    const supported = {'fr', 'en', 'es', 'de', 'ar', 'pt', 'zh', 'sw'};
    return supported.contains(code) ? code : 'en'; // même repli que l'application (deviceLanguageCode)
  }

  /// À appeler quand la langue change : met à jour le profil pour que les prochains rappels arrivent dans la nouvelle langue.
  static Future<void> syncProfile() async {
    final uid = _userId;
    if (kIsWeb || uid == null) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _save(uid, token);
    } catch (_) {}
  }

  static Future<void> _save(String userId, String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // fuseau horaire (minutes par rapport à UTC) et langue choisie dans l'application : le serveur envoie les rappels à l'heure locale, dans la bonne langue
      final tz = DateTime.now().timeZoneOffset.inMinutes;
      final lang = _currentLang(prefs);
      final marker = '$userId|$token|$tz|$lang';
      if (prefs.getString(_savedKey) == marker) return; // déjà enregistré : aucune écriture
      await FirebaseFirestore.instance.collection('Users').doc(userId).update({
        'fcmTokens': FieldValue.arrayUnion([token]),
        'fcmTokenUpdatedAt': DateTime.now().millisecondsSinceEpoch,
        'tzOffsetMin': tz,
        'appLang': lang,
        'pushReady': true,
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
            icon: 'ic_stat_afrolook',
            sound: _sound,
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
/// Partagé par OneSignal (touché) et FCM : même comportement quel que soit le canal. Chaque type de notification a son action ;
/// un type inconnu ouvre simplement l'application sur l'accueil.
Future<void> storeNavigationFromPush(Map<String, dynamic> data) async {
  final type = (data['type_notif']?.toString() ?? '').toUpperCase();
  final postType = data['post_type']?.toString() ?? '';
  final postId = data['post_id']?.toString();
  final chatId = data['chat_id']?.toString();
  final sendUserId = data['send_user_id']?.toString();
  final nav = NavigationCacheService();
  final hasPost = postId != null && postId.isNotEmpty;
  final hasSender = sendUserId != null && sendUserId.isNotEmpty;

  // Rappels programmés et notifications pédagogiques : une page d'action précise
  const screens = {
    'RAPPEL_QUIZ': 'quiz',
    'RAPPEL_ETUDE': 'etude',
    'RAPPEL_CONTE': 'contes',
    'RAPPEL_MONETISATION': 'monetisation',
    'RAPPEL_LIVE': 'live_create',
    'RAPPEL_CANAL': 'canal_create',
    'RAPPEL_GROUPE': 'group_create',
    'RAPPEL_CLASSEMENT': 'weekly_commentators',
    'RAPPEL_COMMENTER': 'weekly_commentators',
    'RAPPEL_MUSIQUE': 'artist_space',
    'RAPPEL_ARTISTE': 'artist_space',
    'RAPPEL_WHATSAPP': 'whatsapp',
    'RAPPEL_FACEBOOK': 'facebook',
    'RAPPEL_TIKTOK': 'tiktok',
    'RAPPEL_NOUVEAUTE_MUSIQUE': 'music',
    'RAPPEL_NOUVEAUTE_DEFI': 'defi',
    'RAPPEL_NOUVEAUTE_ETUDE': 'etude',
    'RAPPEL_NOUVEAUTE_CONTES': 'contes',
    'RAPPEL_JOURNAL': 'news_journal', // résumé du jour, de la semaine : Mon journal
    'MUSIC': 'music',
    'WEEKLY_REWARD': 'monetisation',
    'GAIN': 'monetisation',
    'COMPTE_OFFICIEL': 'notifications',
    'SUPPORT': 'notifications',
    'SERVICE': 'notifications',
    'CERTIFICATION': 'notifications',
  };
  if (type == 'NEWS' && hasPost) {
    // article d'actualité : sa page de détail
    await nav.storeScreenNavigation('news:$postId');
  } else if (screens.containsKey(type)) {
    await nav.storeScreenNavigation(screens[type]!);
  } else if (type == 'RAPPEL_PARRAINAGE' || type == NotificationType.PARRAINAGE.name) {
    await nav.storeParrainageNavigation();
  } else if (type == 'RAPPEL_FEED' || type == 'RAPPEL_RETOUR' || type == 'RAPPEL_ABOUT' || type == 'RAPPEL_BOUTIQUE') {
    // l'accueil est la bonne page : rien à mémoriser
  } else if (postType == 'CHRONIQUE' || type == 'CHRONIQUE' || type == 'COMMENT_LIKE') {
    if (hasPost) {
      await nav.storeChroniqueNavigation(postId);
    } else {
      await nav.storePendingNavigation({'type': 'chronique_home'});
    }
  } else if (type == NotificationType.MESSAGE.name) {
    if (chatId != null && chatId.isNotEmpty && hasSender) await nav.storeMessageNavigation(chatId, sendUserId);
  } else if (type == NotificationType.INVITATION.name) {
    await nav.storeInvitationNavigation();
  } else if (type == NotificationType.ACCEPTINVITATION.name) {
    await nav.storeAcceptInvitationNavigation();
  } else if (type == NotificationType.ARTICLE.name) {
    await nav.storeArticleNavigation();
  } else if (type == NotificationType.ABONNER.name || type == NotificationType.USER.name || type == 'PROFILE_LIKE') {
    if (hasSender) await nav.storeCreatorNavigation(sendUserId);
  } else if (type == NotificationType.LIVE.name) {
    if (hasPost) {
      await nav.storeLiveNavigation(postId);
    } else {
      await nav.storeScreenNavigation('live_list');
    }
  } else if (type.startsWith('DATING_')) {
    await nav.storeScreenNavigation('dating_notifications');
  } else if (hasPost) {
    // j'aime, commentaire, republication, nouveau post, favori, défi… : le post concerné
    await nav.storePostNavigation(postId, postType);
  }
}
