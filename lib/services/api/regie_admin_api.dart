import 'package:afrolook_api_client/afrolook_api_client.dart';
import 'package:afrotok/services/api/regie_api.dart';

/// Administration de la régie Afrolook Ads via l'API (`/admin/ads/*`, `/admin/share/*`).
/// Les réponses sont converties vers les noms de champs déjà utilisés par la page d'administration.
/// Limite connue (voir lacunes_api_regie_admin.md) : l'API ne liste que les éléments « en attente ».
class RegieAdminApi {
  RegieAdminApi._();

  static String _st(Object? s) => switch ('$s') {
        'approved' || 'active' => 'active',
        'rejected' => 'refused',
        'suspended' => 'suspended',
        _ => 'pending',
      };

  static List<Map<String, dynamic>> _rows(Object? v) =>
      (v is List ? v : const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();

  static int _i(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

  static List _arr(Object? v) => v is List ? v : const [];

  /// File d'attente de la régie convertie : annonceurs, diffuseurs, sites/applications, partageurs, campagnes de partage.
  static Future<Map<String, List<Map<String, dynamic>>>> queue({required bool pendingOnly}) async {
    final ads = await RegieApi.getMap('/admin/ads/queue');
    Map<String, dynamic> share = {};
    try {
      share = await RegieApi.getMap('/admin/share/queue');
    } catch (_) {/* la file de partage est facultative à l'affichage */}
    return {
      'advertisers': [
        for (final a in _rows(ads['advertisers']))
          {
            'uid': a['user_id'],
            'brandName': a['brand'],
            'logoUrl': a['logo_url'] ?? '',
            'sector': a['sector'] ?? '',
            'city': a['city'] ?? '',
            'country': a['country'] ?? '',
            'email': '',
            'about': a['description'] ?? '',
            'whatsapp': a['whatsapp'] ?? '',
            'website': a['website'] ?? '',
            'stats': const <String, dynamic>{},
            'logoStatus': a['status'],
            'logoReason': a['reject_reason'] ?? '',
            'partnerConsent': a['display_consent'] == true,
          },
      ],
      'profiles': [
        for (final p in _rows(ads['publishers']))
          {
            'uid': p['user_id'],
            'name': p['name'],
            'type': p['kind'],
            'country': p['country'] ?? '',
            'city': p['city'] ?? '',
            'phone': p['whatsapp'] ?? '',
            'email': '',
            'website': p['website'] ?? '',
            'about': p['presentation'] ?? '',
            'status': _st(p['status']),
            'reason': '',
          },
      ],
      'properties': [
        for (final p in _rows(ads['properties']))
          {
            'id': p['id'],
            'name': p['name'],
            'kind': p['kind'],
            'ownerName': '${p['owner_id']}',
            'ownerEmail': '',
            'url': p['url'] ?? '',
            'category': p['category'] ?? '',
            'countries': p['country'] == null ? const [] : [p['country']],
            'audienceMonthly': _i(p['declared_audience']),
            'audienceCounted': 0,
            'verified': p['verified_at'] != null,
            'payable': p['verified_at'] != null,
            'acceptedCategories': _arr(p['accept']),
            'description': '',
            'status': _st(p['status']),
            'reason': p['reject_reason'] ?? '',
          },
      ],
      'sharers': [
        for (final p in _rows(share['profiles']))
          {
            'uid': p['user_id'],
            'name': '',
            'email': '',
            'status': _st(p['status']),
            'country': p['country'] ?? '',
            'city': p['city'] ?? '',
            'whatsapp': p['whatsapp'] ?? '',
            'declared': _i(p['status_audience']) + _i(p['telegram_audience']) + _i(p['other_audience']),
            'statusAudience': _i(p['status_audience']),
            'telegramAudience': _i(p['telegram_audience']),
            'otherAudience': _i(p['other_audience']),
            'groups': _arr(p['groups']),
            'about': p['about'] ?? '',
            'retained': _i(p['retained_audience']),
            'reason': p['reject_reason'] ?? '',
          },
      ],
      'campaigns': [
        for (final c in _rows(share['campaigns']))
          {
            'id': c['id'],
            'brand': '',
            'title': c['title'],
            'status': c['status'] == 'rejected' ? 'refused' : c['status'],
            'text': c['text'] ?? '',
            'targetAudience': _i(c['target_audience']),
            'free': false,
            'listPriceFcfa': _i(c['budget_fcfa']),
            'countries': _arr(c['countries']),
            'actionUrl': c['url'] ?? '',
            'allocatedReach': _i(c['allocated_reach']),
            // Audit H2 : référence du paiement de l'annonceur (exigée à l'approbation) et créateur de la campagne (un autre approbateur dès 200 000 F)
            'paymentReference': c['payment_reference'] ?? '',
            'createdBy': c['created_by'] ?? '',
          },
      ],
      'alerts': const [],
    };
  }

  /// Décision de l'équipe. [target] : advertiser, profile, property, sharer, campaign.
  /// [paymentReference] : référence du paiement de l'annonceur, EXIGÉE par l'API pour activer une campagne (422 `payment_reference_required`).
  /// Au-delà du seuil fixé par l'API (200 000 F), le créateur de la campagne ne peut pas l'approuver lui-même (403 `second_approver_required`).
  static Future<void> decide(String target, String id, String decision, {String? reason, int? retained, String? paymentReference}) async {
    final action = switch (decision) {
      'approve' || 'reactivate' || 'resume' => 'approve',
      'refuse' || 'reject' => 'reject',
      'suspend' || 'end' => 'suspend',
      'pause' => 'pause',
      _ => throw ApiException(status: 501, code: 'not_available', message: 'Cette action n\'est pas encore disponible.'),
    };
    if (target == 'sharer' || target == 'campaign') {
      // Une campagne « terminée » n'a pas de verbe propre côté API : « suspend » la termine, « pause » la met en pause.
      await RegieApi.post('/admin/share/decisions', body: {
        'type': target == 'sharer' ? 'profile' : 'campaign',
        'id': id,
        'action': action,
        if (reason != null) 'reason': reason,
        if (retained != null && target == 'sharer') 'retained_audience': retained,
        if (paymentReference != null && paymentReference.trim().isNotEmpty && target == 'campaign') 'payment_reference': paymentReference.trim(),
      });
      return;
    }
    await RegieApi.post('/admin/ads/decisions', body: {
      'type': switch (target) { 'advertiser' => 'advertiser', 'profile' => 'publisher', _ => 'property' },
      'id': id,
      'action': action == 'pause' ? 'suspend' : action,
      if (reason != null) 'reason': reason,
    });
  }
}
