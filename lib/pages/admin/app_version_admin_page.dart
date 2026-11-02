import 'package:afrolook_api_client/afrolook_api_client.dart';
import 'package:flutter/material.dart';

import '../../l10n/tr.dart';
import '../../services/admin_reauth.dart';
import '../../services/api/api_gateway.dart';
import '../../services/api/wallet_api.dart';
import '../../theme/app_colors.dart';

/// Version de l'application et liens des magasins (droit « config.edit », connexion récente, journalisé).
/// Règle appliquée par l'application au démarrage : la mise à jour est OBLIGATOIRE seulement si la « version en ligne » est SUPÉRIEURE au numéro de build
/// installé. Ne la monter qu'une fois la nouvelle version publiée dans les deux magasins ; la remettre au niveau d'une version publiée = laisser passer.
class AppVersionAdminPage extends StatefulWidget {
  const AppVersionAdminPage({super.key});

  @override
  State<AppVersionAdminPage> createState() => _AppVersionAdminPageState();
}

class _AppVersionAdminPageState extends State<AppVersionAdminPage> {
  final _code = TextEditingController();
  final _official = TextEditingController();
  final _androidCode = TextEditingController();
  final _iosCode = TextEditingController();
  final _android = TextEditingController();
  final _ios = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _saved;

  ApiClient get _c => ApiGateway.instance.client;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [_code, _official, _androidCode, _iosCode, _android, _ios]) {
      c.dispose();
    }
    super.dispose();
  }

  void _fill(Map<String, dynamic> d) {
    _code.text = '${d['version_code'] ?? ''}';
    _official.text = '${d['version_code_official'] ?? ''}';
    _androidCode.text = '${d['version_code_android'] ?? ''}';
    _iosCode.text = '${d['version_code_ios'] ?? ''}';
    _android.text = '${d['android_link'] ?? ''}';
    _ios.text = '${d['ios_link'] ?? ''}';
  }

  Future<void> _load() async {
    try {
      final d = WalletApi.map(await AdminReauth.run(context, () => _c.get('/admin/settings/app')));
      if (!mounted) return;
      setState(() { _fill(d); _loading = false; _error = null; });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = WalletApi.message(e); });
    }
  }

  Future<void> _save() async {
    final code = int.tryParse(_code.text.trim());
    final official = int.tryParse(_official.text.trim());
    if (code == null && _code.text.trim().isNotEmpty || official == null && _official.text.trim().isNotEmpty) {
      setState(() => _error = tr('Les numéros de version doivent être des nombres entiers.'));
      return;
    }
    setState(() { _saving = true; _error = null; _saved = null; });
    try {
      final body = <String, dynamic>{
        if (code != null) 'version_code': code,
        if (official != null) 'version_code_official': official,
        // numéro par système : vide = retour au numéro commun
        'version_code_android': int.tryParse(_androidCode.text.trim()),
        'version_code_ios': int.tryParse(_iosCode.text.trim()),
        if (_android.text.trim().isNotEmpty) 'android_link': _android.text.trim(),
        if (_ios.text.trim().isNotEmpty) 'ios_link': _ios.text.trim(),
      };
      final d = WalletApi.map(await AdminReauth.run(context, () => _c.put('/admin/settings/app', body: body)));
      if (mounted) setState(() { _fill(d); _saved = tr('Enregistré. Les applications le lisent à leur prochain démarrage (jusqu\'à une minute de délai).'); });
    } catch (e) {
      if (mounted) setState(() => _error = WalletApi.message(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field(TextEditingController c, String label, {TextInputType? type, String? help}) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextField(controller: c, keyboardType: type, decoration: InputDecoration(labelText: label, helperText: help, helperMaxLines: 3, border: const OutlineInputBorder())),
      );

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(backgroundColor: c.surface, foregroundColor: c.textPrimary, title: Text(tr('Version de l\'application'))),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: c.primary))
          : ListView(padding: const EdgeInsets.all(16), children: [
              Container(
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(14)),
                child: Text(
                  tr('Une personne est obligée de mettre à jour seulement si la version en ligne est PLUS GRANDE que le numéro de build installé sur son téléphone. Monte-la uniquement quand la nouvelle version est publiée dans les deux magasins. Pour laisser passer tout le monde, mets le numéro d\'une version déjà publiée.'),
                  style: TextStyle(color: c.textSecondary, height: 1.4, fontSize: 13),
                ),
              ),
              _field(_code, tr('Version en ligne (numéro de build)'), type: TextInputType.number, help: tr('Exemple : 268 pour la version 2.0.17+268.')),
              _field(_androidCode, tr('Version Android (facultatif)'), type: TextInputType.number, help: tr('Si vide, le numéro commun ci-dessus est utilisé. À monter seulement quand la version est disponible à 100 % sur Google Play.')),
              _field(_iosCode, tr('Version iPhone (facultatif)'), type: TextInputType.number, help: tr('Si vide, le numéro commun ci-dessus est utilisé. À monter seulement quand la version est en ligne sur l\'App Store.')),
              _field(_official, tr('Version officielle (numéro de build)'), type: TextInputType.number),
              _field(_android, tr('Lien Play Store'), type: TextInputType.url),
              _field(_ios, tr('Lien App Store'), type: TextInputType.url),
              if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(_error!, style: TextStyle(color: c.danger, fontWeight: FontWeight.w700))),
              if (_saved != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(_saved!, style: TextStyle(color: c.success, fontWeight: FontWeight.w700))),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Text(tr('Enregistrer')),
                ),
              ),
            ]),
    );
  }
}
