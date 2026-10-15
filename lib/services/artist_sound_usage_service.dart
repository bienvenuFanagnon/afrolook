// lib/services/artist_sound_usage_service.dart
//
// Débit de pièces artiste : 3 pièces créditées à l'artiste à chaque utilisation
// de son son dans un post. La transaction est atomique (Firestore batch).

import 'package:cloud_firestore/cloud_firestore.dart';

class ArtistSoundUsageService {
  static final _db = FirebaseFirestore.instance;

  // Appeler juste après la publication d'un post qui utilise un son artiste.
  // soundId    : id du document dans artist_sounds/
  // artistId   : userId de l'artiste (champ userId dans artist_sounds)
  static Future<void> recordUsage({
    required String soundId,
    required String artistId,
  }) async {
    final batch = _db.batch();

    final soundRef = _db.collection('artist_sounds').doc(soundId);
    batch.update(soundRef, {
      'usageCount': FieldValue.increment(1),
      'totalEarningsCoins': FieldValue.increment(3),
    });

    // Crédite 3 pièces retrait (giftCoinsBalance) à l'artiste
    final userRef = _db.collection('users').doc(artistId);
    batch.update(userRef, {
      'giftCoinsBalance': FieldValue.increment(3),
    });

    await batch.commit();
  }
}
