// lib/services/artist_sound_usage_service.dart
//
// Les artistes sont payés par le serveur, jamais par le téléphone : quand un son d'artiste est utilisé dans un
// montage du Studio, la fonction renderStudioMontage débite la personne et crédite l'artiste (Users.giftCoinsBalance)
// dans une seule transaction, une fois le montage réussi.
//
// L'ancien crédit direct depuis l'app écrivait dans une collection inexistante (`users`) et aurait permis à
// n'importe quel téléphone de créditer un compte : il est retiré. Dans l'onglet Audio des posts, le son choisi
// n'est pas mis dans le post ; aucune somme n'est donc prélevée ni versée.

class ArtistSoundUsageService {
  static Future<void> recordUsage({
    required String soundId,
    required String artistId,
  }) async {}
}
