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

/// Heures EXACTES de notifications (4 fois / jour)
const List<int> notificationHours = [9, 12, 18, 21];

/// =======================================================
/// WORKMANAGER CALLBACK
/// =======================================================

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      print('WORKMANAGER EXECUTÉ: $task à ${DateTime.now()}');

      WidgetsFlutterBinding.ensureInitialized();
      await Firebase.initializeApp();
      if (task == afrolookTestTask) {
        printVm('registerOneOffTask est lancé ...');
        await sendTestAfrolookNotification();
      }
      await _handleAfrolookNotification();
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
    frequency: const Duration(hours: 3),
    initialDelay: const Duration(seconds: 10),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
  );
}

/// =======================================================
/// CORE LOGIC (4x / DAY GUARANTEED)
/// =======================================================

Future<void> _handleAfrolookNotification() async {
  final prefs = await SharedPreferences.getInstance();
  final now = DateTime.now();

  // final int? hourToNotify = _getValidHour(now, prefs);
  //
  // if (hourToNotify == null) {
  //   debugPrint("⏭ No notification for this slot");
  //   return;
  // }

  await _sendAfrolookNotification();
  //
  // final key = _buildDailyKey(now, hourToNotify);
  // await prefs.setBool(key, true);
}

/// =======================================================
/// TIME CONTROL
/// =======================================================

int? _getValidHour(DateTime now, SharedPreferences prefs) {
  for (final hour in notificationHours) {
    if (now.hour == hour) {
      final key = _buildDailyKey(now, hour);
      if (!prefs.containsKey(key)) {
        return hour;
      }
    }
  }
  return null;
}

String _buildDailyKey(DateTime now, int hour) {
  return "afrolook_${now.year}_${now.month}_${now.day}_$hour";
}

/// =======================================================
/// NOTIFICATION CONTENT
/// =======================================================


Future<void> _sendAfrolookNotification() async {
  final random = Random();
  final prefs = await SharedPreferences.getInstance();

  final countries = [
    "Togo", "Bénin", "Sénégal", "Côte d'Ivoire", "Cameroun", "Burkina Faso",
    "Mali", "Gabon", "Ghana", "Nigeria", "Rwanda", "Kenya", "Afrique du Sud",
    "Égypte", "Maroc", "Tunisie", "Algérie", "Maurice", "Sierra Leone",
    "Guinée", "Libéria", "Congo", "RD Congo", "Mozambique", "Zambie",
    "Zimbabwe", "Ouganda", "Tanzanie", "Éthiopie", "Namibie"
  ];

  final amounts = [
    "10 000", "20 000", "30 000", "50 000", "75 000", "100 000", "150 000", "200 000"
  ];

  final List<Map<String, String>> notifications = [
    {
      "title": "🔥 Afrolook s’anime",
      "body": "Des contenus africains explosent en ce moment. Connecte-toi !"
    },
    {
      "title": "💰 Ton contenu a de la valeur",
      "body": "Sur Afrolook, certains gagnent plus de {amount} FCFA par semaine"
    },
    {
      "title": "📺 Live gratuit",
      "body": "Lance ou regarde des lives sans abonnement, partout en Afrique"
    },
    {
      "title": "🌍 Actu africaine",
      "body": "Les infos de {country} font le buzz aujourd’hui"
    },
    {
      "title": "🚀 Crée ton média",
      "body": "Canaux, pages et contenus premium sont monétisables maintenant"
    },
    {
      "title": "✨ Tu es différent",
      "body": "Ton style mérite visibilité et reconnaissance sur toute l’Afrique"
    },
    {
      "title": "📈 Popularité en hausse",
      "body": "Les profils actifs gagnent visibilité et revenus rapidement"
    },
    {
      "title": "🛍 Vends ton contenu",
      "body": "Photos, vidéos, infos : transforme ton talent en argent"
    },
    {
      "title": "🎉 Buzz du jour",
      "body": "Le contenu de {country} fait le buzz sur Afrolook !"
    },
    {
      "title": "🏆 Deviens célèbre",
      "body": "Les créateurs africains montent en flèche grâce à leur contenu"
    },
    {
      "title": "💎 Contenu premium",
      "body": "Les utilisateurs paient pour accéder à tes contenus exclusifs"
    },
    {
      "title": "📢 Notifications instant",
      "body": "Reste au courant des tendances de {country} dès maintenant"
    },
  ];

  // ✅ Éviter répétition jusqu'à ce que tous les messages aient été montrés
  final shown = prefs.getStringList("afrolookShown") ?? [];
  List<Map<String, String>> remaining =
  notifications.where((n) => !shown.contains(n['title'])).toList();

  if (remaining.isEmpty) {
    shown.clear();
    remaining = notifications;
  }

  final notif = remaining[random.nextInt(remaining.length)];

  String title = notif['title']!;
  String body = notif['body']!;

  body = body
      .replaceAll("{amount}", amounts[random.nextInt(amounts.length)])
      .replaceAll("{country}", countries[random.nextInt(countries.length)]);

  await _showNotification(title: title, body: body);

  shown.add(title);
  await prefs.setStringList("afrolookShown", shown);
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
    print('🚀 Démarrage initialisation des champs des canaux...');

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
        print('✅ Canal ${doc.id} mis à jour');
      }
    }

    print('🎉 Initialisation terminée : $updatedCount canaux mis à jour');

  } catch (e) {
    print('❌ Erreur lors de l\'initialisation: $e');
  }
}
