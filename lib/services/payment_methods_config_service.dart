import 'package:cloud_firestore/cloud_firestore.dart';

/// Lit et écrit la config d'activation des opérateurs de paiement
/// Document Firestore : AppData/paymentMethodsConfig
/// Structure : { operators: { "moov_bf": { payinEnabled: true, payoutEnabled: false }, ... } }
class PaymentMethodsConfigService {
  static final instance = PaymentMethodsConfigService._();
  PaymentMethodsConfigService._();

  // operatorCode -> { 'payin': bool, 'payout': bool }
  Map<String, Map<String, bool>> _cache = {};
  bool _loaded = false;

  static const _docPath = 'AppData/paymentMethodsConfig';

  Future<void> load() async {
    try {
      final doc = await FirebaseFirestore.instance.doc(_docPath).get();
      if (doc.exists) {
        final ops = (doc.data()?['operators'] as Map<String, dynamic>?) ?? {};
        _cache = ops.map((code, v) {
          final m = v as Map<String, dynamic>;
          return MapEntry(code, {
            'payin': (m['payinEnabled'] as bool?) ?? true,
            'payout': (m['payoutEnabled'] as bool?) ?? true,
          });
        });
      }
    } catch (_) {}
    _loaded = true;
  }

  bool isPayinEnabled(String code) => _loaded ? (_cache[code]?['payin'] ?? true) : true;
  bool isPayoutEnabled(String code) => _loaded ? (_cache[code]?['payout'] ?? true) : true;

  Future<void> setPayinEnabled(String code, bool enabled) async {
    await FirebaseFirestore.instance.doc(_docPath).set(
      {'operators': {code: {'payinEnabled': enabled}}},
      SetOptions(merge: true),
    );
    _cache[code] = {
      'payin': enabled,
      'payout': _cache[code]?['payout'] ?? true,
    };
  }

  Future<void> setPayoutEnabled(String code, bool enabled) async {
    await FirebaseFirestore.instance.doc(_docPath).set(
      {'operators': {code: {'payoutEnabled': enabled}}},
      SetOptions(merge: true),
    );
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
