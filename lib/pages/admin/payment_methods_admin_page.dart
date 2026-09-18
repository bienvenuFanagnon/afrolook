import 'package:flutter/material.dart';
import '../../services/payment_methods_config_service.dart';

// Tous les opérateurs connus avec leur pays et code FeexPay
const _operators = [
  {'country': 'Bénin',            'name': 'MTN Bénin',      'code': 'mtn'},
  {'country': 'Bénin',            'name': 'MOOV Bénin',     'code': 'moov'},
  {'country': 'Bénin',            'name': 'CELTIIS Bénin',  'code': 'celtiis_bj'},
  {'country': 'Bénin',            'name': 'CORIS Bénin',    'code': 'coris'},
  {'country': 'Togo',             'name': 'TOGOCOM',        'code': 'togocom_tg'},
  {'country': 'Togo',             'name': 'MOOV Togo',      'code': 'moov_tg'},
  {'country': 'Côte d\'Ivoire',   'name': 'MTN CI',         'code': 'mtn_ci'},
  {'country': 'Côte d\'Ivoire',   'name': 'MOOV CI',        'code': 'moov_ci'},
  {'country': 'Côte d\'Ivoire',   'name': 'WAVE CI',        'code': 'wave_ci'},
  {'country': 'Côte d\'Ivoire',   'name': 'ORANGE CI',      'code': 'orange_ci'},
  {'country': 'Congo Brazzaville','name': 'MTN Congo',      'code': 'mtn_cg'},
  {'country': 'Sénégal',          'name': 'ORANGE SN',      'code': 'orange_sn'},
  {'country': 'Sénégal',          'name': 'WAVE SN',        'code': 'wave_sn'},
  {'country': 'Sénégal',          'name': 'FREE SN',        'code': 'free_sn'},
  {'country': 'Burkina Faso',     'name': 'Moov BF',        'code': 'moov_bf'},
  {'country': 'Burkina Faso',     'name': 'Orange BF',      'code': 'orange_bf'},
  {'country': 'Burkina Faso',     'name': 'Wave BF',        'code': 'wave_bf'},
  {'country': 'Mali',             'name': 'Orange Mali',    'code': 'orange_ml'},
  {'country': 'Mali',             'name': 'Mobicash Mali',  'code': 'mobicash_ml'},
];

// Pays qui apparaissent dans le formulaire de retrait
const _retraitCountries = {'Togo', 'Burkina Faso', 'Mali'};

class PaymentMethodsAdminPage extends StatefulWidget {
  const PaymentMethodsAdminPage({super.key});

  @override
  State<PaymentMethodsAdminPage> createState() => _PaymentMethodsAdminPageState();
}

class _PaymentMethodsAdminPageState extends State<PaymentMethodsAdminPage> {
  final _svc = PaymentMethodsConfigService.instance;
  bool _loading = true;
  // operatorCode -> { 'payin': bool, 'payout': bool }
  final Map<String, Map<String, bool>> _local = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _svc.invalidate();
    await _svc.load();
    final updated = <String, Map<String, bool>>{};
    for (final op in _operators) {
      final code = op['code']!;
      updated[code] = {
        'payin': _svc.isPayinEnabled(code),
        'payout': _svc.isPayoutEnabled(code),
      };
    }
    if (mounted) setState(() { _local.addAll(updated); _loading = false; });
  }

  Future<void> _togglePayin(String code, bool value) async {
    setState(() => _local[code]!['payin'] = value);
    await _svc.setPayinEnabled(code, value);
  }

  Future<void> _togglePayout(String code, bool value) async {
    setState(() => _local[code]!['payout'] = value);
    await _svc.setPayoutEnabled(code, value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Moyens de paiement'),
        backgroundColor: const Color(0xFFD8A868),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () { setState(() => _loading = true); _load(); },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFD8A868)))
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    // Grouper par pays
    final countries = <String, List<Map<String, String>>>{};
    for (final op in _operators) {
      countries.putIfAbsent(op['country']!, () => []).add(op);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildLegend(),
        const SizedBox(height: 12),
        ...countries.entries.map((entry) => _buildCountrySection(entry.key, entry.value)),
      ],
    );
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.blue.shade700, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Dépôt = visible dans l\'écran de recharge.\nRetrait = visible dans le formulaire de retrait.',
              style: TextStyle(color: Colors.blue.shade800, fontSize: 12, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountrySection(String country, List<Map<String, String>> ops) {
    final hasRetrait = _retraitCountries.contains(country);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête pays
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.flag_rounded, size: 18, color: Color(0xFFD8A868)),
                const SizedBox(width: 8),
                Text(country, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                if (!hasRetrait) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('retrait non disponible', style: TextStyle(color: Colors.grey.shade600, fontSize: 10)),
                  ),
                ],
              ],
            ),
          ),
          // En-tête colonnes
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Row(
              children: [
                const Expanded(child: SizedBox()),
                SizedBox(
                  width: 70,
                  child: Text('Dépôt', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                ),
                SizedBox(
                  width: 70,
                  child: Text('Retrait', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...ops.asMap().entries.map((e) {
            final isLast = e.key == ops.length - 1;
            return _buildOperatorRow(e.value, hasRetrait, isLast);
          }),
        ],
      ),
    );
  }

  Widget _buildOperatorRow(Map<String, String> op, bool hasRetrait, bool isLast) {
    final code = op['code']!;
    final payin = _local[code]?['payin'] ?? true;
    final payout = _local[code]?['payout'] ?? true;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: payin ? Colors.green : Colors.red.shade300,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(op['name']!, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              // Toggle Dépôt
              SizedBox(
                width: 70,
                child: Center(
                  child: Switch(
                    value: payin,
                    onChanged: (v) => _togglePayin(code, v),
                    activeColor: const Color(0xFFD8A868),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
              // Toggle Retrait
              SizedBox(
                width: 70,
                child: Center(
                  child: hasRetrait
                      ? Switch(
                          value: payout,
                          onChanged: (v) => _togglePayout(code, v),
                          activeColor: Colors.green,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        )
                      : Icon(Icons.remove, color: Colors.grey.shade300, size: 20),
                ),
              ),
            ],
          ),
        ),
        if (!isLast) const Divider(height: 1, indent: 34),
      ],
    );
  }
}
