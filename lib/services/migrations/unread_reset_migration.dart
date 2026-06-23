import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:afrotok/pages/component/consoleWidget.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _migrationKey = 'migration_unread_reset_v1';

/// Réinitialise une seule fois les compteurs de messages non lus pour [userId].
///
/// Ce que fait la migration :
///  - Met à 0 le champ `unread_counts.$userId` dans chaque GroupChat dont
///    l'utilisateur est membre.
///  - Marque comme lu (message_state = "LU") tous les messages directs où
///    receiverBy == userId et message_state == "NONLU".
///
/// Stocke un flag dans SharedPreferences pour ne s'exécuter qu'une seule fois.
Future<void> runUnreadResetMigrationIfNeeded(String userId) async {
  final prefs = await SharedPreferences.getInstance();
  final alreadyDone = prefs.getBool('${_migrationKey}_$userId') ?? false;
  if (alreadyDone) return;

  try {
    final firestore = FirebaseFirestore.instance;

    // ── 1. Réinitialiser unread_counts dans tous les GroupChats ──────────────
    final groupSnap = await firestore
        .collection('GroupChats')
        .where('member_ids', arrayContains: userId)
        .get();

    final groupBatch = firestore.batch();
    for (final doc in groupSnap.docs) {
      final data = doc.data();
      final unreadCounts = data['unread_counts'] as Map<String, dynamic>? ?? {};
      final myCount = (unreadCounts[userId] as int?) ?? 0;
      if (myCount > 0) {
        groupBatch.update(doc.reference, {'unread_counts.$userId': 0});
      }
    }
    await groupBatch.commit();

    // ── 2. Marquer LU tous les messages directs NONLU reçus ──────────────────
    final msgSnap = await firestore
        .collection('Messages')
        .where('receiverBy', isEqualTo: userId)
        .where('message_state', isEqualTo: 'NONLU')
        .get();

    // Firestore batch max 500 opérations — on découpe si besoin
    const chunkSize = 450;
    for (var i = 0; i < msgSnap.docs.length; i += chunkSize) {
      final chunk = msgSnap.docs.sublist(
        i,
        (i + chunkSize).clamp(0, msgSnap.docs.length),
      );
      final msgBatch = firestore.batch();
      for (final doc in chunk) {
        msgBatch.update(doc.reference, {'message_state': 'LU'});
      }
      await msgBatch.commit();
    }

    // ── 3. Marquer la migration comme terminée ───────────────────────────────
    await prefs.setBool('${_migrationKey}_$userId', true);
  } catch (e) {
    // Ne pas bloquer l'app si la migration échoue — elle retentira au prochain démarrage
    printVm('⚠️ UnreadResetMigration: $e');
  }
}
