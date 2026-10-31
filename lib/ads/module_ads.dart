import 'package:afrolook_api_client/afrolook_api_client.dart';
import 'package:afrotok/services/api/api_gateway.dart';
import 'package:afrotok/services/api/regie_api.dart';
import 'package:flutter/foundation.dart';

import '../models/model_data.dart';
import 'ad_gate.dart';

/// Offre « sans pub » des modules Quiz, Étude et Contes (réglages publics de l'API : section `modules` de GET /config).
class ModuleAdFreeOffer {
  const ModuleAdFreeOffer({this.price = 500, this.days = 30, this.enabled = true});
  final int price, days;
  final bool enabled;
}

class ModuleAdFreeException implements Exception {
  ModuleAdFreeException(this.code);
  final String code;
  bool get insufficient => code.toLowerCase().contains('insuffisant');
}

/// Le pass « sans pub 30 jours » retire les pubs passives (bannières, pubs dans les listes, pubs plein écran de fin) de Quiz,
/// Étude et Contes. Les pubs avec récompense que le lecteur choisit pour débloquer un contenu restent possibles.
class ModuleAds {
  ModuleAds._();

  /// Incrémenté après un achat : les écrans qui affichent l'offre se mettent à jour.
  static final ValueNotifier<int> changes = ValueNotifier<int>(0);

  static bool adFree(UserData? u) => (u?.modulesAdFreeUntil ?? 0) > DateTime.now().millisecondsSinceEpoch;

  /// Pub passive autorisée dans un module : règle générale d'Afrolook et pas de pass « sans pub ».
  static bool shows(UserData? u) => AdGate.userSeesAds(u) && !adFree(u);

  static DateTime? endsAt(UserData? u) {
    final ms = u?.modulesAdFreeUntil ?? 0;
    return ms > DateTime.now().millisecondsSinceEpoch ? DateTime.fromMillisecondsSinceEpoch(ms) : null;
  }

  static ModuleAdFreeOffer? _offer;
  static DateTime? _offerAt;

  static Future<ModuleAdFreeOffer> offer() async {
    final at = _offerAt;
    if (_offer != null && at != null && DateTime.now().difference(at).inMinutes < 15) return _offer!;
    try {
      final d = await RegieApi.configSection('modules');
      _offer = ModuleAdFreeOffer(
        price: (d['adFreePrice'] as num?)?.toInt() ?? 500,
        days: (d['adFreeDays'] as num?)?.toInt() ?? 30,
        enabled: d['adFreeEnabled'] != false,
      );
      _offerAt = DateTime.now();
    } catch (_) {
      _offer ??= const ModuleAdFreeOffer();
    }
    return _offer!;
  }

  /// Achète le pass en pièces. Met à jour le profil local et retourne la date de fin.
  static Future<DateTime> buy(UserData user) async {
    try {
      // Achat en pièces : la clé d'idempotence évite tout double débit si la requête est rejouée.
      final res = ApiClient.data(await ApiGateway.instance.client.pay('/purchases', body: {'kind': 'module_ad_free'}));
      final raw = res is Map ? res['until'] : null;
      final until = raw is num ? raw.toInt() : (DateTime.tryParse('$raw')?.millisecondsSinceEpoch ?? 0);
      if (until <= 0) throw ModuleAdFreeException('Achat enregistré, mais la date de fin est inconnue. Rouvre l’application.');
      user.modulesAdFreeUntil = until;
      changes.value++;
      return DateTime.fromMillisecondsSinceEpoch(until);
    } on ApiException catch (e) {
      throw ModuleAdFreeException(e.isInsufficientCoins ? 'Solde insuffisant' : e.message);
    }
  }
}
