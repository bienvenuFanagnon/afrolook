import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
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

      await _runNotificationCheck(userId, prefs, debugMode: !kReleaseMode);
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

// ═══════════════════════════════════════════════════════════════
// LOGIQUE PRINCIPALE
// ═══════════════════════════════════════════════════════════════

Future<void> _runNotificationCheck(
  String userId,
  SharedPreferences prefs, {
  bool debugMode = false,
}) async {
  final firestore = FirebaseFirestore.instance;
  final now = DateTime.now().millisecondsSinceEpoch;
  final lastCheck = prefs.getInt(_lastCheckKey) ?? (now - const Duration(hours: 24).inMilliseconds);

  if (debugMode) {
    // ── MODE DEBUG : affiche les dernières notifications sans filtre non-lu ──
    debugPrint('🔧 WorkManager DEBUG — récupération des dernières notifications...');
    await _runDebugNotificationPreview(firestore, userId);
    await prefs.setInt(_lastCheckKey, now);
    return;
  }

  // ── MODE PRODUCTION : uniquement si le count a augmenté ──
  final lastCounts = _loadLastCounts(prefs);
  final lastShown  = _loadLastShown(prefs);

  final intResults = await Future.wait<int>([
    _countUnreadDirectMessages(firestore, userId),
    _countUnreadGroupMessages(firestore, userId, lastCheck),
    _countPendingInvitations(firestore, userId),
  ]);
  final countNotifs = await _countUnreadNotifications(firestore, userId);

  final countMessages    = intResults[0];
  final countGroups      = intResults[1];
  final countInvitations = intResults[2];
  final countDating      = countNotifs['dating'] ?? 0;
  final countApp         = countNotifs['app'] ?? 0;

  debugPrint('WorkManager counts → msgs:$countMessages grps:$countGroups inv:$countInvitations dating:$countDating app:$countApp');

  bool anyShown = false;

  Future<void> maybeShow({
    required String category,
    required int current,
    required int previous,
    required Future<void> Function() showFn,
  }) async {
    if (current <= 0) return;
    if (current <= previous) return;
    final lastShownTs = lastShown[category] ?? 0;
    if ((now - lastShownTs) < _categoryCoooldown.inMilliseconds) return;
    await showFn();
    lastShown[category] = now;
    anyShown = true;
  }

  await maybeShow(
    category: 'messages',
    current: countMessages,
    previous: lastCounts['messages'] ?? 0,
    showFn: () async {
      String? imageUrl;
      try {
        final snap = await firestore.collection('Messages')
            .where('receiverBy', isEqualTo: userId)
            .where('message_state', isEqualTo: 'NONLU')
            .where('is_valide', isEqualTo: true)
            .limit(1).get();
        final senderId = snap.docs.firstOrNull?.data()['send_by'] as String?;
        if (senderId != null) {
          final doc = await firestore.collection('Users').doc(senderId).get();
          imageUrl = doc.data()?['imageUrl'] as String?;
        }
      } catch (_) {}
      await _showCategoryNotification(
        id: _notifIdMessages,
        title: '$countMessages nouveau${countMessages > 1 ? 'x' : ''} message${countMessages > 1 ? 's' : ''}',
        body: 'Tu as des messages non lus dans tes conversations.',
        icon: '💬',
        imageUrl: imageUrl,
      );
    },
  );

  await maybeShow(
    category: 'groups',
    current: countGroups,
    previous: lastCounts['groups'] ?? 0,
    showFn: () async {
      String? imageUrl;
      try {
        final snap = await firestore.collection('GroupChats')
            .where('member_ids', arrayContains: userId)
            .limit(1).get();
        imageUrl = snap.docs.firstOrNull?.data()['image_url'] as String?;
      } catch (_) {}
      await _showCategoryNotification(
        id: _notifIdGroups,
        title: '$countGroups groupe${countGroups > 1 ? 's' : ''} actif${countGroups > 1 ? 's' : ''}',
        body: 'Des messages t\'attendent dans tes groupes.',
        icon: '👥',
        imageUrl: imageUrl,
      );
    },
  );

  await maybeShow(
    category: 'invitations',
    current: countInvitations,
    previous: lastCounts['invitations'] ?? 0,
    showFn: () async {
      String? imageUrl;
      try {
        final snap = await firestore.collection('Invitations')
            .where('receiver_id', isEqualTo: userId)
            .where('status', isEqualTo: 'ENCOURS')
            .limit(1).get();
        final senderId = snap.docs.firstOrNull?.data()['sender_id'] as String?;
        if (senderId != null) {
          final doc = await firestore.collection('Users').doc(senderId).get();
          imageUrl = doc.data()?['imageUrl'] as String?;
        }
      } catch (_) {}
      await _showCategoryNotification(
        id: _notifIdInvitations,
        title: '$countInvitations demande${countInvitations > 1 ? 's' : ''} d\'amitié',
        body: '${countInvitations > 1 ? 'Des personnes veulent' : 'Une personne veut'} te rejoindre sur Afrolook.',
        icon: '🤝',
        imageUrl: imageUrl,
      );
    },
  );

  await maybeShow(
    category: 'dating',
    current: countDating,
    previous: lastCounts['dating'] ?? 0,
    showFn: () async {
      String? imageUrl;
      try {
        final snap = await firestore.collection('Notifications')
            .where('receiver_id', isEqualTo: userId)
            .where('is_open', isEqualTo: false)
            .limit(10).get();
        for (final doc in snap.docs) {
          final type = (doc.data()['type'] as String?) ?? '';
          if (_datingTypes.contains(type)) {
            imageUrl = doc.data()['media_url'] as String?;
            if (imageUrl != null) break;
          }
        }
      } catch (_) {}
      await _showCategoryNotification(
        id: _notifIdDating,
        title: '$countDating notification${countDating > 1 ? 's' : ''} AfroLove',
        body: countDating > 1
            ? 'Tu as des likes, matchs ou messages non lus sur AfroLove.'
            : 'Quelqu\'un t\'a aimé ou t\'a envoyé un message sur AfroLove.',
        icon: '❤️',
        imageUrl: imageUrl,
      );
    },
  );

  await maybeShow(
    category: 'app',
    current: countApp,
    previous: lastCounts['app'] ?? 0,
    showFn: () async {
      String? imageUrl;
      try {
        final snap = await firestore.collection('Notifications')
            .where('receiver_id', isEqualTo: userId)
            .where('is_open', isEqualTo: false)
            .limit(10).get();
        for (final doc in snap.docs) {
          final type = (doc.data()['type'] as String?) ?? '';
          if (!_datingTypes.contains(type)) {
            imageUrl = doc.data()['media_url'] as String?;
            if (imageUrl != null) break;
          }
        }
      } catch (_) {}
      await _showCategoryNotification(
        id: _notifIdApp,
        title: '$countApp notification${countApp > 1 ? 's' : ''}',
        body: 'Tu as des interactions non lues sur tes publications.',
        icon: '🔔',
        imageUrl: imageUrl,
      );
    },
  );

  _saveLastCounts(prefs, {
    'messages':    countMessages,
    'groups':      countGroups,
    'invitations': countInvitations,
    'dating':      countDating,
    'app':         countApp,
  });
  _saveLastShown(prefs, lastShown);
  await prefs.setInt(_lastCheckKey, now);

  if (anyShown) {
    debugPrint('✅ WorkManager: notifications affichées pour $userId');
  } else {
    debugPrint('⏭ WorkManager: aucune nouvelle activité pour $userId');
  }
}

/// Mode debug : affiche un aperçu des dernières notifications de chaque catégorie
/// sans tenir compte du statut lu/non-lu — pour valider que le système fonctionne.
Future<void> _runDebugNotificationPreview(
  FirebaseFirestore firestore,
  String userId,
) async {
  // Derniers messages directs — image de l'expéditeur
  try {
    final msgs = await firestore
        .collection('Messages')
        .where('receiverBy', isEqualTo: userId)
        .where('is_valide', isEqualTo: true)
        .limit(5)
        .get();
    if (msgs.docs.isNotEmpty) {
      String? imageUrl;
      try {
        final senderId = msgs.docs.first.data()['send_by'] as String?;
        if (senderId != null) {
          final senderDoc = await firestore.collection('Users').doc(senderId).get();
          imageUrl = senderDoc.data()?['imageUrl'] as String?;
        }
      } catch (_) {}
      await _showCategoryNotification(
        id: _notifIdMessages,
        title: '💬 ${msgs.docs.length} conversation(s) [DEBUG]',
        body: 'Aperçu — ${msgs.docs.length} message(s) récents dans tes conversations.',
        icon: '💬',
        imageUrl: imageUrl,
      );
    }
  } catch (e) {
    debugPrint('❌ WM debug msgs: $e');
  }

  // Groupes actifs — image du groupe
  try {
    final groups = await firestore
        .collection('GroupChats')
        .where('member_ids', arrayContains: userId)
        .limit(5)
        .get();
    if (groups.docs.isNotEmpty) {
      final firstGroupData = groups.docs.first.data();
      final imageUrl = firstGroupData['image_url'] as String?;
      await _showCategoryNotification(
        id: _notifIdGroups,
        title: '👥 ${groups.docs.length} groupe(s) [DEBUG]',
        body: 'Aperçu — ${groups.docs.length} groupe(s) avec activité récente.',
        icon: '👥',
        imageUrl: imageUrl,
      );
    }
  } catch (e) {
    debugPrint('❌ WM debug groups: $e');
  }

  // Dernières notifications Firestore (toutes, lues ou non) — image media_url
  try {
    final notifs = await firestore
        .collection('Notifications')
        .where('receiver_id', isEqualTo: userId)
        .limit(5)
        .get();

    int dating = 0, app = 0;
    String? datingImageUrl, appImageUrl;
    for (final doc in notifs.docs) {
      final data = doc.data();
      final type = (data['type'] as String?) ?? '';
      final mediaUrl = data['media_url'] as String?;
      if (_datingTypes.contains(type)) {
        dating++;
        datingImageUrl ??= mediaUrl;
      } else {
        app++;
        appImageUrl ??= mediaUrl;
      }
    }

    if (dating > 0) {
      await _showCategoryNotification(
        id: _notifIdDating,
        title: '❤️ $dating notification(s) AfroLove [DEBUG]',
        body: 'Aperçu — $dating notification(s) AfroLove récentes.',
        icon: '❤️',
        imageUrl: datingImageUrl,
      );
    }
    if (app > 0) {
      await _showCategoryNotification(
        id: _notifIdApp,
        title: '🔔 $app notification(s) app [DEBUG]',
        body: 'Aperçu — $app notification(s) récentes (likes, comments...).',
        icon: '🔔',
        imageUrl: appImageUrl,
      );
    }
  } catch (e) {
    debugPrint('❌ WM debug notifs: $e');
  }

  // Invitations — image de l'expéditeur de l'invitation
  try {
    final invits = await firestore
        .collection('Invitations')
        .where('receiver_id', isEqualTo: userId)
        .limit(5)
        .get();
    if (invits.docs.isNotEmpty) {
      String? imageUrl;
      try {
        final senderId = invits.docs.first.data()['sender_id'] as String?;
        if (senderId != null) {
          final senderDoc = await firestore.collection('Users').doc(senderId).get();
          imageUrl = senderDoc.data()?['imageUrl'] as String?;
        }
      } catch (_) {}
      await _showCategoryNotification(
        id: _notifIdInvitations,
        title: '🤝 ${invits.docs.length} invitation(s) [DEBUG]',
        body: 'Aperçu — ${invits.docs.length} invitation(s) d\'amitié.',
        icon: '🤝',
        imageUrl: imageUrl,
      );
    }
  } catch (e) {
    debugPrint('❌ WM debug invits: $e');
  }

  debugPrint('✅ WorkManager DEBUG : aperçu affiché pour $userId');
}

// ═══════════════════════════════════════════════════════════════
// REQUÊTES FIRESTORE — 1 par catégorie, lecture minimale
// ═══════════════════════════════════════════════════════════════

/// Messages directs non lus destinés à cet utilisateur
Future<int> _countUnreadDirectMessages(
  FirebaseFirestore db,
  String userId,
) async {
  try {
    final snap = await db
        .collection('Messages')
        .where('receiverBy', isEqualTo: userId)
        .where('message_state', isEqualTo: 'NONLU')
        .where('is_valide', isEqualTo: true)
        .limit(50)
        .get();
    return snap.docs.length;
  } catch (e) {
    debugPrint('❌ WM countDirectMessages: $e');
    return 0;
  }
}

/// Nombre de groupes ayant eu une activité depuis le dernier check
/// (proxy : last_message_at > lastCheck)
Future<int> _countUnreadGroupMessages(
  FirebaseFirestore db,
  String userId,
  int lastCheckMs,
) async {
  try {
    final snap = await db
        .collection('GroupChats')
        .where('member_ids', arrayContains: userId)
        .limit(30)
        .get();

    int active = 0;
    for (final doc in snap.docs) {
      final data = doc.data();
      final lastMsgAt = (data['last_message_at'] as int?) ?? 0;
      if (lastMsgAt > lastCheckMs) active++;
    }
    return active;
  } catch (e) {
    debugPrint('❌ WM countGroupMessages: $e');
    return 0;
  }
}

/// Invitations en attente
Future<int> _countPendingInvitations(
  FirebaseFirestore db,
  String userId,
) async {
  try {
    final snap = await db
        .collection('Invitations')
        .where('receiver_id', isEqualTo: userId)
        .where('status', isEqualTo: 'ENCOURS')
        .limit(50)
        .get();
    return snap.docs.length;
  } catch (e) {
    debugPrint('❌ WM countInvitations: $e');
    return 0;
  }
}

/// Notifications non lues — séparées en dating vs app
Future<Map<String, int>> _countUnreadNotifications(
  FirebaseFirestore db,
  String userId,
) async {
  try {
    final snap = await db
        .collection('Notifications')
        .where('receiver_id', isEqualTo: userId)
        .where('is_open', isEqualTo: false)
        .limit(100)
        .get();

    int dating = 0;
    int app    = 0;

    for (final doc in snap.docs) {
      final type = (doc.data()['type'] as String?) ?? '';
      if (_datingTypes.contains(type)) {
        dating++;
      } else {
        app++;
      }
    }
    return {'dating': dating, 'app': app};
  } catch (e) {
    debugPrint('❌ WM countNotifications: $e');
    return {'dating': 0, 'app': 0};
  }
}

// ═══════════════════════════════════════════════════════════════
// AFFICHAGE NOTIFICATION — style BigText (Facebook/Snapchat)
// ═══════════════════════════════════════════════════════════════

Future<void> initLocalNotifications() async {
  const AndroidInitializationSettings android =
      AndroidInitializationSettings('@drawable/notification_icon');
  await flutterLocalNotificationsPlugin.initialize(
    InitializationSettings(android: android),
  );
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
}) async {
  final fullTitle = '$icon $title';
  final largeBitmap = await _downloadImageBitmap(imageUrl);

  final androidDetails = AndroidNotificationDetails(
    'afrolook_channel',
    'Afrolook Notifications',
    channelDescription: 'Notifications de l\'application Afrolook',
    importance: Importance.max,
    priority: Priority.high,
    showWhen: true,
    color: const Color(0xFF1FAA59),
    largeIcon: largeBitmap ?? const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
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
  );
}

// ═══════════════════════════════════════════════════════════════
// PERSISTANCE ANTI-ABUS
// ═══════════════════════════════════════════════════════════════

Map<String, int> _loadLastCounts(SharedPreferences prefs) {
  try {
    final raw = prefs.getString(_countsKey);
    if (raw == null) return {};
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map((k, v) => MapEntry(k, (v as num).toInt()));
  } catch (_) {
    return {};
  }
}

void _saveLastCounts(SharedPreferences prefs, Map<String, int> counts) {
  prefs.setString(_countsKey, jsonEncode(counts));
}

Map<String, int> _loadLastShown(SharedPreferences prefs) {
  try {
    final raw = prefs.getString(_lastShownKey);
    if (raw == null) return {};
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map((k, v) => MapEntry(k, (v as num).toInt()));
  } catch (_) {
    return {};
  }
}

void _saveLastShown(SharedPreferences prefs, Map<String, int> shown) {
  prefs.setString(_lastShownKey, jsonEncode(shown));
}

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

Future<void> initializeCanalFields() async {
  final firestore = FirebaseFirestore.instance;
  try {
    printVm('🚀 Démarrage initialisation des champs des canaux...');
    final canals = await firestore.collection('Canaux').get();
    int updatedCount = 0;
    for (final doc in canals.docs) {
      final canalData = doc.data();
      final updates = <String, dynamic>{};
      if (canalData['adminIds'] == null) {
        updates['adminIds'] = [canalData['userId']];
      }
      if (canalData['allowedPostersIds'] == null) {
        updates['allowedPostersIds'] = [canalData['userId']];
      }
      if (canalData['allowAllMembersToPost'] == null) {
        updates['allowAllMembersToPost'] = false;
      }
      updates['updatedAt'] = DateTime.now().microsecondsSinceEpoch;
      if (updates.isNotEmpty) {
        await doc.reference.update(updates);
        updatedCount++;
        printVm('✅ Canal ${doc.id} mis à jour');
      }
    }
    printVm('🎉 Initialisation terminée : $updatedCount canaux mis à jour');
  } catch (e) {
    printVm('❌ Erreur lors de l\'initialisation: $e');
  }
}
