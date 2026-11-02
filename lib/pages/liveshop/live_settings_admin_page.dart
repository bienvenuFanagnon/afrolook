import 'package:afrotok/services/admin_reauth.dart';
import 'package:flutter/material.dart';

import '../../l10n/tr.dart';
import '../../services/api/live_shop_api.dart';
import '../../theme/app_colors.dart';

/// Réglages de l'équipe pour la vente en direct et les lives : commission sur les ventes, nombre de lives par mois selon l'abonnement,
/// prix et durée de la prolongation payante (le prix suit le coût vidéo Agora, qui dépend du nombre de spectateurs).
class LiveSettingsAdminPage extends StatefulWidget {
  const LiveSettingsAdminPage({super.key});

  @override
  State<LiveSettingsAdminPage> createState() => _LiveSettingsAdminPageState();
}

class _LiveSettingsAdminPageState extends State<LiveSettingsAdminPage> {
  // clé API → (libellé, aide)
  static const _fields = <String, List<String>>{
    'commission_percent': ['Commission sur les ventes (%)', "Part gardée par l'application quand la vente est terminée (0 à 30)."],
    'trusted_commission_percent': ['Commission « vendeur fiable » (%)', 'Taux réduit pour les vendeurs fiables. Vide = même taux pour tous.'],
    'free_monthly_lives': ['Lives par mois sans abonnement', 'Quota gratuit.'],
    'premium_monthly_lives': ['Lives par mois avec Premium', 'Gold et l\'équipe sont illimités.'],
    'extension_minutes': ['Durée d\'une prolongation (minutes)', '5 à 180.'],
    'extension_min_xof': ['Prix minimum d\'une prolongation (F)', 'Prix sans spectateur.'],
    'extension_per_viewer_xof': ['Ajout par spectateur (F)', 'Coût vidéo : environ 134 F par spectateur et par heure.'],
    'extension_cap_xof': ['Prix maximum (F)', '0 = pas de plafond.'],
    'extension_max': ['Prolongations par live', '0 à 10.'],
  };

  final Map<String, TextEditingController> _c = {for (final k in _fields.keys) k: TextEditingController()};
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _show(dynamic v) => v == null ? '' : (v is num && v == v.roundToDouble() ? '${v.toInt()}' : '$v');

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final s = await AdminReauth.run(context, () => LiveShopApi.adminSettings());
      for (final k in _fields.keys) {
        _c[k]!.text = _show(s[k]);
      }
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = LiveShopApi.message(e); });
    }
  }

  Future<void> _save() async {
    final body = <String, dynamic>{};
    for (final k in _fields.keys) {
      final t = _c[k]!.text.trim().replaceAll(',', '.');
      if (t.isEmpty) {
        if (k == 'trusted_commission_percent') body[k] = null;
        continue;
      }
      final n = num.tryParse(t);
      if (n == null) {
        setState(() => _error = tr('Valeur invalide : {k}', {'k': tr(_fields[k]![0])}));
        return;
      }
      body[k] = k.endsWith('_percent') ? n.toDouble() : n.toInt();
    }
    setState(() { _saving = true; _error = null; });
    try {
      await AdminReauth.run(context, () => LiveShopApi.setAdminSettings(body));
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Réglages enregistrés.'))));
    } catch (e) {
      if (mounted) setState(() { _saving = false; _error = LiveShopApi.message(e); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(backgroundColor: c.surface, foregroundColor: c.textPrimary, title: Text(tr('Réglages lives et ventes'))),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: c.primary))
          : ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 32), children: [
              for (final e in _fields.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextField(
                    controller: _c[e.key],
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: tr(e.value[0]), helperText: tr(e.value[1]), border: const OutlineInputBorder()),
                  ),
                ),
              if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w700))),
              FilledButton(onPressed: _saving ? null : _save, child: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Text(tr('Enregistrer'))),
            ]),
    );
  }
}
