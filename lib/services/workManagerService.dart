import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../pages/component/consoleWidget.dart';

/// =======================================================
/// GLOBAL
/// =======================================================

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

const String afrolookTask = "afrolookTask";
const String afrolookTestTask = "afrolookTestTask";

/// Clé SharedPreferences où SessionUserFirebaseService stocke l'userId
const String _sessionTokenKey = 'token';

/// Clé locale pour éviter de re-montrer des notifs déjà affichées
const String _shownNotifIdsKey = 'wm_shown_notif_ids';

/// Nombre max de notifications affichées par run WorkManager
const int _maxNotifsPerRun = 3;

/// =======================================================
/// WORKMANAGER CALLBACK
/// =======================================================

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      debugPrint('WORKMANAGER EXECUTÉ: $task à ${DateTime.now()}');

      WidgetsFlutterBinding.ensureInitialized();
      await Firebase.initializeApp();
      // Obligatoire dans l'isolate WorkManager — le plugin n'est pas initialisé depuis main.dart
      await initLocalNotifications();

      if (task == afrolookTestTask) {
        printVm('registerOneOffTask est lancé ...');
        await sendTestAfrolookNotification();
        return true;
      }

      // Récupère l'userId de la session active
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString(_sessionTokenKey);

      if (userId == null || userId.isEmpty) {
        debugPrint('⏭ WorkManager: aucun utilisateur connecté, skip');
        return true;
      }

      await _fetchAndShowUserNotifications(userId, prefs);
      return true;
    } catch (e, stack) {
      debugPrint("❌ WorkManager error: $e");
      debugPrint(stack.toString());
      return false;
    }
  });
}

/// =======================================================
/// REGISTER WORKMANAGER
/// =======================================================

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
    existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
  );
}

/// =======================================================
/// CORE LOGIC — Notifications Firestore de l'utilisateur
/// =======================================================

/// Récupère les notifications non vues de [userId] depuis Firestore,
/// affiche jusqu'à [_maxNotifsPerRun] notifications locales,
/// puis marque chacune comme vue (users_id_view + cache local).
Future<void> _fetchAndShowUserNotifications(
  String userId,
  SharedPreferences prefs,
) async {
  final firestore = FirebaseFirestore.instance;

  // Cache local des IDs déjà affichés (backup si l'update Firestore échoue)
  final shownIds = (prefs.getStringList(_shownNotifIdsKey) ?? []).toSet();

  // Notifications destinées à cet utilisateur (requête simple, 1 seul where = pas d'index composite)
  final sinceMs = DateTime.now().subtract(const Duration(days: 7)).millisecondsSinceEpoch;
  QuerySnapshot snapshot;
  try {
    snapshot = await firestore
        .collection('Notifications')
        .where('receiver_id', isEqualTo: userId)
        .limit(50)
        .get();
  } catch (e) {
    debugPrint('❌ WorkManager Firestore query error: $e');
    return;
  }

  // Filtre côté client : non vues + moins de 7 jours + pas encore affichées localement
  final unread = snapshot.docs.where((doc) {
    final data = doc.data() as Map<String, dynamic>;
    final notifId = (data['id'] as String?) ?? doc.id;
    if (shownIds.contains(notifId)) return false;
    final viewers = List<String>.from(data['users_id_view'] ?? []);
    if (viewers.contains(userId)) return false;
    final createdAt = (data['created_at'] as int?) ?? 0;
    return createdAt > sinceMs;
  }).toList()

  // Tri côté client : plus récentes en premier
  ..sort((a, b) {
    final aTs = ((a.data() as Map)['created_at'] as int?) ?? 0;
    final bTs = ((b.data() as Map)['created_at'] as int?) ?? 0;
    return bTs.compareTo(aTs);
  });

  if (unread.isEmpty) {
    debugPrint('⏭ WorkManager: aucune nouvelle notification pour $userId');
    return;
  }

  final toShow = unread.take(_maxNotifsPerRun).toList();
  final newShownIds = <String>[];

  for (final doc in toShow) {
    final data = doc.data() as Map<String, dynamic>;
    final notifId = (data['id'] as String?) ?? doc.id;
    final titre = (data['titre'] as String?)?.isNotEmpty == true
        ? data['titre'] as String
        : 'Afrolook';
    final description = (data['description'] as String?) ?? '';

    await _showNotification(title: titre, body: description);

    // Marquer comme vu dans Firestore
    try {
      await doc.reference.update({
        'users_id_view': FieldValue.arrayUnion([userId]),
      });
    } catch (e) {
      debugPrint('⚠️ WorkManager: impossible de marquer la notif $notifId: $e');
    }

    newShownIds.add(notifId);
  }

  // Mettre à jour le cache local (conserver max 500 entrées)
  final updated = {...shownIds, ...newShownIds}.toList();
  if (updated.length > 500) updated.removeRange(0, updated.length - 500);
  await prefs.setStringList(_shownNotifIdsKey, updated);

  debugPrint('✅ WorkManager: ${toShow.length} notifications affichées pour $userId');
}

/// =======================================================
/// NOTIFICATION UI
/// =======================================================
Future<void> initLocalNotifications() async {
  const AndroidInitializationSettings initializationSettingsAndroid =
  AndroidInitializationSettings('@drawable/ic_stat_onesignal_default');
  // AndroidInitializationSettings('@mipmap/ic_launcher');

  final InitializationSettings initializationSettings =
  InitializationSettings(android: initializationSettingsAndroid);

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
  );
}
Future<void> _showNotification({
  required String title,
  required String body,
})
async {
  const androidDetails = AndroidNotificationDetails(
    'afrolook_channel',
    'Afrolook Notifications',
    importance: Importance.max,
    priority: Priority.high,
    showWhen: true,
  );

  const details = NotificationDetails(android: androidDetails);

  await flutterLocalNotificationsPlugin.show(
    DateTime.now().millisecondsSinceEpoch % 100000,
    title,
    body,
    details,
  );
}

/// =======================================================
/// MANUAL TEST
/// =======================================================


Future<void> sendTestAfrolookNotification() async {
  final prefs = await SharedPreferences.getInstance();

  final today = DateTime.now();
  final todayKey = '${today.year}-${today.month}-${today.day}';

  final lastSentDate = prefs.getString('daily_notification_date');

  // ❌ Déjà envoyée aujourd’hui → on sort
  // if (lastSentDate == todayKey) return;

  // ✅ Liste de messages très addictifs et variés
  final List<String> messages = [
    "Le réseau social africain où ton contenu peut devenir une source de revenus",
    "Découvre de nouvelles opportunités chaque jour sur notre plateforme",
    "Publie, partage et fais grandir ta communauté africaine",
    "Ton talent mérite d’être vu : rejoins-nous aujourd’hui",
    "Chaque jour est une chance de booster ton contenu",
    "Des créateurs africains explosent en ce moment : connecte-toi !",
    "Les tendances du jour sont là, ne les rate pas !",
    "Ton contenu peut rapporter gros si tu es actif aujourd’hui",
    "Le buzz africain t’attend sur notre plateforme",
    "Chaque partage peut transformer ton talent en argent",
  ];

  // ✅ Éviter répétition des messages
  final shown = prefs.getStringList("testShown") ?? [];
  List<String> remaining = messages.where((m) => !shown.contains(m)).toList();

  if (remaining.isEmpty) {
    shown.clear();
    remaining = messages;
  }

  final random = Random();
  final message = remaining[random.nextInt(remaining.length)];

  // ⚡ Envoyer la notification
  await _showNotification(
    title: "🔥 Afrolook",
    body: message,
  );

  // 💾 Mémoriser le message pour éviter répétition
  shown.add(message);
  await prefs.setStringList("testShown", shown);

  // 💾 Mémoriser la date pour ne pas renvoyer aujourd'hui
  await prefs.setString('daily_notification_date', todayKey);
}


Future<void> initializeCanalFields() async {
  final firestore = FirebaseFirestore.instance;

  try {
    printVm('🚀 Démarrage initialisation des champs des canaux...');

    final canals = await firestore.collection('Canaux').get();
    int updatedCount = 0;

    for (final doc in canals.docs) {
      final canalData = doc.data();

      // Vérifier et initialiser les champs
      final updates = <String, dynamic>{};

      if (canalData['adminIds'] == null) {
        updates['adminIds'] = [canalData['userId']]; // Le créateur est admin par défaut
      }

      if (canalData['allowedPostersIds'] == null) {
        updates['allowedPostersIds'] = [canalData['userId']]; // Le créateur peut poster
      }

      if (canalData['allowAllMembersToPost'] == null) {
        updates['allowAllMembersToPost'] = false; // Par défaut, seuls les autorisés peuvent poster
      }

      // Ajouter timestamp de mise à jour
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
