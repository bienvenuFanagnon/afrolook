import 'package:afrotok/services/api/regie_api.dart';

import '../models/model_data.dart';

/// Suppression d'une publicité : on supprime la publicité elle-même, JAMAIS le post auquel elle est reliée.
/// Le serveur remet le post à l'état normal (voir lacunes_api_regie_admin.md : route `DELETE /ads/account/ads/{id}` à fournir).
class AdDeletion {
  AdDeletion._();

  static Future<void> delete(Advertisement ad) async {
    final adId = ad.id;
    if (adId == null || adId.isEmpty) return;
    await RegieApi.delete('/ads/account/ads/$adId');
  }
}
