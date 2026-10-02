import 'package:cloud_firestore/cloud_firestore.dart';

/// Vues à exclure du calcul des gains : celles des posts NON monétisés du créateur
/// (champ `monetized == false` ; absent = ancien post = monétisé).
/// Même règle que la Cloud Function cashViewEarnings, pour que l'affichage corresponde au montant payé.
class ViewEarningsFilter {
  static Future<int> nonMonetizedViews(String userId) async {
    try {
      final db = FirebaseFirestore.instance;
      final results = await Future.wait([
        db.collection('Users').doc(userId).get(),
        db.collection('Posts').where('user_id', isEqualTo: userId).where('monetized', isEqualTo: false).get(),
      ]);
      final perPost = ((results[0] as DocumentSnapshot<Map<String, dynamic>>).data()?['postViewsPerPost'] as Map?) ?? {};
      var total = 0;
      for (final d in (results[1] as QuerySnapshot<Map<String, dynamic>>).docs) {
        total += ((perPost[d.id] as num?) ?? 0).toInt();
      }
      return total;
    } catch (_) {
      return 0;
    }
  }
}
