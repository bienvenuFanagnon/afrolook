import 'package:afrotok/services/read_meter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/model_data.dart';

/// Suppression d'une publicité : on supprime la publicité elle-même, JAMAIS le post auquel elle est reliée
/// (post boosté, défi, post publié avec une pub). Les publicités de profil, canal ou groupe n'ont pas de post.
///
/// Si le post avait été marqué comme publicité par ce boost, il redevient un post normal (visible dans le fil), et sa description
/// d'origine est remise quand elle avait été sauvegardée au moment du boost.
class AdDeletion {
  AdDeletion._();

  static Future<void> delete(Advertisement ad) async {
    final adId = ad.id;
    if (adId == null || adId.isEmpty) return;
    final db = FirebaseFirestore.instance;
    await db.collection('Advertisements').doc(adId).delete();

    final postId = ad.postId;
    if (postId == null || postId.isEmpty) return;
    try {
      final ref = db.collection('Posts').doc(postId);
      final snap = await ref.getM('ad_delete.dart:24');
      final data = snap.data();
      if (data == null) return;
      // Post relié à une autre publicité, ou jamais marqué par celle-ci (défi boosté) : on n'y touche pas
      if (data['advertisementId'] != adId) return;
      final upd = <String, dynamic>{'advertisementId': FieldValue.delete(), 'isAdvertisement': false};
      final backup = data['boostBackup'];
      if (backup is Map) {
        if (backup.containsKey('description')) upd['description'] = backup['description'] ?? '';
        upd['boostBackup'] = FieldValue.delete();
      }
      await ref.update(upd);
    } catch (e) {
      // La publicité est bien supprimée ; le post reste tel quel
      debugPrint('AdDeletion : post $postId non remis à l\'état normal : $e');
    }
  }
}
