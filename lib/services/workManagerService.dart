import 'package:afrotok/services/read_meter.dart';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../firebase_options.dart';
import '../pages/component/consoleWidget.dart';
import 'nav_cache_service.dart';
import 'push_service.dart';

// ═══════════════════════════════════════════════════════════════
// GLOBAL
// ═══════════════════════════════════════════════════════════════

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

const String afrolookTask     = 'afrolookTask';
const String afrolookTestTask = 'afrolookTestTask';

/// Clé SharedPreferences où SessionUserFirebaseService stocke l'userId
const String _sessionTokenKey = 'token';

/// Clé SharedPreferences où on stocke les derniers counts par catégorie
const String _countsKey = 'wm_last_counts';

/// Clé pour le timestamp du dernier check (pour les groupes)
const String _lastCheckKey = 'wm_last_check_ts';

/// Clé pour le cooldown par catégorie (dernier affichage) — prod uniquement
const String _lastShownKey = 'wm_last_shown_ts';

/// Cooldown minimum entre deux notifications de la même catégorie (prod)
const Duration _categoryCoooldown = Duration(minutes: 30);

/// IDs fixes par catégorie — la notif remplace la précédente au lieu d'empiler
const int _notifIdMessages     = 1001;
const int _notifIdGroups       = 1002;
const int _notifIdInvitations  = 1003;
const int _notifIdDating       = 1004;
const int _notifIdApp          = 1005;
const int _notifIdCreatorsPromo = 1006;
const int _notifIdCanalsPromo   = 1007;

/// Clé pour le timestamp de la dernière promo envoyée
const String _lastPromoKey = 'wm_last_promo_ts';

/// Cooldown minimum entre deux notifications promo (6h)
const Duration _promoCooldown = Duration(hours: 6);

/// Types de notifications dating (collection Notifications)
const List<String> _datingTypes = [
  'DATING_LIKE',
  'DATING_MATCH',
  'DATING_SUPER_LIKE',
  'DATING_MESSAGE',
];

// ═══════════════════════════════════════════════════════════════
// WORKMANAGER CALLBACK
// ═══════════════════════════════════════════════════════════════

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      debugPrint('WORKMANAGER EXECUTÉ: $task à ${DateTime.now()}');

      WidgetsFlutterBinding.ensureInitialized();

      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }

      debugPrint('WM STEP 1 : Firebase OK');
      await initLocalNotifications();
      debugPrint('WM STEP 2 : LocalNotifications initialisé');

      if (task == afrolookTestTask) {
        printVm('registerOneOffTask est lancé ...');
        await _sendDebugTestNotification();
        return true;
      }

      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString(_sessionTokenKey);
      debugPrint('WM STEP 3 : userId = $userId');

      if (userId == null || userId.isEmpty) {
        debugPrint('⏭ WorkManager: aucun utilisateur connecté, skip');
        return true;
      }

      // Les notifications (messages, groupes, invitations, rappels) sont envoyées par le serveur en FCM : plus de lecture de Firestore ici.
      return true;
    } catch (e, stack) {
      debugPrint('❌ WorkManager error: $e\n$stack');
      return false;
    }
  });
}

// ═══════════════════════════════════════════════════════════════
// REGISTER
// ═══════════════════════════════════════════════════════════════

Future<void> registerAfrolookWorkManager() async {
  await Workmanager().initialize(
    callbackDispatcher,
    isInDebugMode: false,
  );

  await Workmanager().registerPeriodicTask(
    afrolookTask,
    afrolookTask,
    frequency: const Duration(minutes: 15),
    initialDelay: const Duration(seconds: 10),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
  );
}

@pragma('vm:entry-point')
void onNotificationTapBackground(NotificationResponse details) {
  _handleLocalNotifPayload(details.payload);
}

Future<void> initLocalNotifications() async {
  const AndroidInitializationSettings android =
      AndroidInitializationSettings('@drawable/ic_stat_afrolook');
  await flutterLocalNotificationsPlugin.initialize(
    const InitializationSettings(
      android: android,
      // iPhone : les réglages sont obligatoires ; les permissions sont demandées ailleurs (PushService / OneSignal)
      iOS: DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false),
    ),
    onDidReceiveNotificationResponse: (details) => _handleLocalNotifPayload(details.payload),
    onDidReceiveBackgroundNotificationResponse: onNotificationTapBackground,
  );
}

/// Stocke la destination dans NavigationCacheService selon le payload JSON.
void _handleLocalNotifPayload(String? payload) {
  if (payload == null || payload.isEmpty) return;
  try {
    final data = jsonDecode(payload) as Map<String, dynamic>;
    // Notification push (FCM) affichée pendant que l'application était ouverte
    final push = data['push'];
    if (push is Map) {
      PushService.handleLocalTap(Map<String, dynamic>.from(push));
      return;
    }
    final type = data['type'] as String?;
    if (type == 'creator') {
      final uid = data['userId'] as String?;
      if (uid != null && uid.isNotEmpty) {
        NavigationCacheService().storeCreatorNavigation(uid);
      }
    } else if (type == 'canal') {
      final cid = data['canalId'] as String?;
      if (cid != null && cid.isNotEmpty) {
        NavigationCacheService().storeCanalNavigation(cid);
      }
    }
  } catch (e) {
    debugPrint('⚠️ WM notif payload parse error: $e');
  }
}

/// Télécharge une image depuis une URL et la retourne comme bitmap Android.
/// Retourne null en cas d'échec (timeout, erreur réseau, URL vide).
Future<FilePathAndroidBitmap?> _downloadImageBitmap(String? url) async {
  if (url == null || url.isEmpty) return null;
  try {
    final response = await http
        .get(Uri.parse(url))
        .timeout(const Duration(seconds: 5));
    if (response.statusCode != 200) return null;
    final dir = await getTemporaryDirectory();
    final hash = url.hashCode.abs();
    final file = File('${dir.path}/wm_icon_$hash.jpg');
    await file.writeAsBytes(response.bodyBytes);
    return FilePathAndroidBitmap(file.path);
  } catch (e) {
    debugPrint('⚠️ WM image download failed: $e');
    return null;
  }
}

Future<void> _showCategoryNotification({
  required int id,
  required String title,
  required String body,
  required String icon,
  String? imageUrl,
  String? payload,
}) async {
  final fullTitle = icon.isEmpty ? title : '$icon $title';
  final largeBitmap = await _downloadImageBitmap(imageUrl);

  final androidDetails = AndroidNotificationDetails(
    'afrolook_channel',
    'Afrolook Notifications',
    channelDescription: 'Notifications de l\'application Afrolook',
    importance: Importance.max,
    priority: Priority.high,
    showWhen: true,
    color: const Color(0xFF1FAA59),
    largeIcon: largeBitmap ?? const DrawableResourceAndroidBitmap('@mipmap/launcher_icon'),
    // Texte expandable au clic vers le bas
    styleInformation: BigTextStyleInformation(
      body,
      htmlFormatBigText: false,
      contentTitle: fullTitle,
      htmlFormatContentTitle: false,
      summaryText: 'Afrolook',
    ),
    // Groupe visuel — toutes les notifs Afrolook s'empilent ensemble
    groupKey: 'afrolook_group',
    channelShowBadge: true,
    playSound: true,
    enableVibration: true,
    visibility: NotificationVisibility.public,
    // Force le popup heads-up même quand l'app est au premier plan
    fullScreenIntent: false,
    category: AndroidNotificationCategory.message,
  );

  await flutterLocalNotificationsPlugin.show(
    id,
    fullTitle,
    body,
    NotificationDetails(android: androidDetails),
    payload: payload,
  );
}

// ═══════════════════════════════════════════════════════════════
// PERSISTANCE ANTI-ABUS
// ═══════════════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════════════
// TEST DEBUG
// ═══════════════════════════════════════════════════════════════

Future<void> _sendDebugTestNotification() async {
  await _showCategoryNotification(
    id: 9999,
    title: 'WorkManager opérationnel',
    body: 'Le système de notifications en arrière-plan fonctionne correctement.',
    icon: '✅',
  );
}

// Alias public conservé pour compatibilité
Future<void> sendTestAfrolookNotification() => _sendDebugTestNotification();
