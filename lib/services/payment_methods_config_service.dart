import 'api/api_gateway.dart';

/// Lit et écrit la config d'activation des opérateurs de paiement
/// Source : réglages publics de l'API (`GET /config`, clé `payments.operators`).
/// Structure : { operators: { "moov_bf": { payinEnabled: true, payoutEnabled: false }, ... } }
class PaymentMethodsConfigService {
  static final instance = PaymentMethodsConfigService._();
  PaymentMethodsConfigService._();

  // operatorCode -> { 'payin': bool, 'payout': bool }
  Map<String, Map<String, bool>> _cache = {};
  bool _loaded = false;

  Future<void> load() async {
    try {
      final r = await ApiGateway.instance.client.get('/config');
      final root = r is Map ? r['data'] : null;
      final payments = root is Map ? root['payments'] : null;
      final ops = payments is Map && payments['operators'] is Map ? Map<String, dynamic>.from(payments['operators'] as Map) : <String, dynamic>{};
      _cache = ops.map((code, v) {
        final m = v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
        return MapEntry(code, {
          'payin': (m['payin_enabled'] as bool?) ?? (m['payinEnabled'] as bool?) ?? true,
          'payout': (m['payout_enabled'] as bool?) ?? (m['payoutEnabled'] as bool?) ?? true,
        });
      });
    } catch (_) {}
    _loaded = true;
  }

  bool isPayinEnabled(String code) => _loaded ? (_cache[code]?['payin'] ?? true) : true;
  bool isPayoutEnabled(String code) => _loaded ? (_cache[code]?['payout'] ?? true) : true;

  /// Point d'accès prévu : PUT /admin/payments/operators/{code} (absent pour l'instant, voir lacunes_api_argent_creations.md).
  Future<void> setPayinEnabled(String code, bool enabled) async {
    await ApiGateway.instance.client.put('/admin/payments/operators/$code', body: {'payin_enabled': enabled});
    _cache[code] = {
      'payin': enabled,
      'payout': _cache[code]?['payout'] ?? true,
    };
  }

  Future<void> setPayoutEnabled(String code, bool enabled) async {
    await ApiGateway.instance.client.put('/admin/payments/operators/$code', body: {'payout_enabled': enabled});
    _cache[code] = {
      'payin': _cache[code]?['payin'] ?? true,
      'payout': enabled,
    };
  }

  void invalidate() {
    _loaded = false;
    _cache = {};
  }
}
