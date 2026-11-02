import 'package:afrolook_api_client/afrolook_api_client.dart';
import 'package:afrotok/services/api/regie_api.dart';

/// Administration de la régie Afrolook Ads depuis l'application : les MÊMES opérations que le site d'administration (`/admin/regie/*`, mêmes formats) :
/// listes filtrables par statut (en attente, validés, refusés, suspendus, tous), noms et e-mails, alertes de surveillance, fraude confirmée / blocage levé.
/// Les opérations d'argent (partageurs, campagnes) demandent une connexion de moins de 10 minutes : l'API répond alors 403 `reauth_required`
/// (voir `AdminReauth`).
class RegieAdminApi {
  RegieAdminApi._();

  static List<Map<String, dynamic>> _rows(Object? v) =>
      (v is List ? v : const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();

  static Future<Map<String, dynamic>> _call(String fn, Map<String, dynamic> body) async {
    final r = await RegieApi.post('/admin/regie/$fn', body: body);
    return r is Map ? Map<String, dynamic>.from(r) : <String, dynamic>{};
  }

  /// File de la régie pour un filtre de statut : `pending`, `active`, `refused`, `suspended` ou `all`.
  static Future<Map<String, List<Map<String, dynamic>>>> queue({required String filter}) async {
    // annonceurs : le site parle de « approved / rejected » ; ils n'ont pas de statut « suspendu »
    final advFilter = switch (filter) { 'active' => 'approved', 'refused' => 'rejected', _ => filter };
    final adv = filter == 'suspended' ? <String, dynamic>{} : await _call('adsAdvAdminList', {'status': advFilter});
    final pub = await _call('adsPubAdminList', {'status': filter});
    final alerts = (filter == 'pending' || filter == 'all') ? await _call('adsPubAdminList', {'alerts': true, 'status': 'open'}) : <String, dynamic>{};
    // argent : peut lever `reauth_required` (laissée à l'écran, qui propose de se reconnecter)
    final sharers = await _call('adsPubAdminList', {'sharers': true, 'status': filter});
    final campaigns = await _call('adsPubAdminList', {'campaigns': true, 'status': filter == 'suspended' ? 'paused' : filter});
    return {
      'advertisers': _rows(adv['items']),
      'profiles': _rows(pub['profiles']),
      'properties': _rows(pub['properties']),
      'sharers': _rows(sharers['sharers']),
      'campaigns': _rows(campaigns['campaigns']),
      'alerts': _rows(alerts['alerts']),
    };
  }

  /// Décision de l'équipe. [target] : advertiser, profile, property, sharer, campaign, alert.
  /// [decision] : approve, refuse (reject pour un annonceur), suspend, reactivate, pause, resume, end, clear (blocage de fraude levé), fraud (fraude confirmée), ack, hold, release.
  /// [retained] : audience retenue (partageur, site ou application). [paymentReference] : référence du paiement de l'annonceur, EXIGÉE pour activer une campagne.
  static Future<void> decide(String target, String id, String decision, {String? reason, int? retained, String? paymentReference}) async {
    if (target == 'advertiser') {
      await _call('adsAdvAdminReview', {'uid': id, 'decision': decision == 'approve' ? 'approve' : 'reject', if (reason != null) 'reason': reason});
      return;
    }
    await _call('adsPubAdminReview', {
      'target': target,
      'id': id,
      'decision': decision,
      if (reason != null) 'reason': reason,
      if (retained != null) 'audienceRetained': retained,
      if (retained != null && target == 'property') 'audienceCounted': retained,
      if (paymentReference != null && paymentReference.trim().isNotEmpty) 'paymentReference': paymentReference.trim(),
    });
  }
}
