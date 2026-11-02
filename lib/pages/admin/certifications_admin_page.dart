import 'package:afrotok/services/admin_reauth.dart';
import 'package:afrolook_api_client/afrolook_api_client.dart';
import 'package:flutter/material.dart';

import '../../l10n/tr.dart';
import '../../services/api/api_gateway.dart';
import '../../services/api/wallet_api.dart';
import '../../theme/app_colors.dart';

/// Hub des certifications (badge) : voir les comptes certifiés, en ajouter ou en retirer (motif obligatoire au retrait, action journalisée).
/// Droit d'équipe : `users.certify`. Les comptes certifiés de l'ancien système sont repris à l'import et ne perdent jamais leur badge.
class CertificationsAdminPage extends StatefulWidget {
  const CertificationsAdminPage({super.key});

  @override
  State<CertificationsAdminPage> createState() => _CertificationsAdminPageState();
}

class _CertificationsAdminPageState extends State<CertificationsAdminPage> {
  final _search = TextEditingController();
  List<Map<String, dynamic>> _users = const [];
  int _total = 0;
  bool _loading = true;
  String? _error;

  ApiClient get _c => ApiGateway.instance.client;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final q = _search.text.trim();
      final r = await _c.get('/admin/certifications', query: {'limit': 50, if (q.isNotEmpty) 'search': q}) as Map;
      if (!mounted) return;
      setState(() {
        _users = ((r['data'] as List?) ?? const []).whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
        _total = (r['total_verified'] as num?)?.toInt() ?? 0;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = WalletApi.message(e, fallback: "Impossible de charger les comptes."); _loading = false; });
    }
  }

  Future<void> _set(Map<String, dynamic> u, bool verified) async {
    String? reason;
    if (!verified) {
      final ctl = TextEditingController();
      reason = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(tr('Retirer la certification')),
          content: TextField(controller: ctl, autofocus: true, maxLength: 200, decoration: InputDecoration(labelText: tr('Motif (obligatoire)'))),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Annuler'))),
            FilledButton(onPressed: () => Navigator.pop(ctx, ctl.text.trim()), child: Text(tr('Retirer'))),
          ],
        ),
      );
      if (reason == null || reason.length < 5) {
        if (reason != null && mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Indique un motif (5 caractères au moins).'))));
        return;
      }
    }
    try {
      await AdminReauth.run(context, () => _c.post('/admin/users/${u['id']}/certification', body: {'verified': verified, if (reason != null) 'reason': reason}));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(verified ? tr('Compte certifié.') : tr('Certification retirée.'))));
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(WalletApi.message(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(backgroundColor: c.surface, foregroundColor: c.textPrimary, title: Text(tr('Certifications'))),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            controller: _search,
            onSubmitted: (_) => _load(),
            decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: tr('Chercher un compte à certifier (pseudo, nom, e-mail)'), border: const OutlineInputBorder()),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Align(alignment: Alignment.centerLeft, child: Text(tr('{n} compte(s) certifié(s)', {'n': _total}), style: TextStyle(color: c.textSecondary, fontSize: 12.5))),
        ),
        Expanded(
          child: _loading
              ? Center(child: CircularProgressIndicator(color: c.primary))
              : _error != null
                  ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: c.textSecondary)), TextButton(onPressed: _load, child: Text(tr('Réessayer')))])))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
                        if (_users.isEmpty) Padding(padding: const EdgeInsets.all(32), child: Center(child: Text(tr('Aucun compte.'), style: TextStyle(color: c.textSecondary)))),
                        for (final u in _users)
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.border)),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: c.surfaceVariant,
                                backgroundImage: ('${u['avatar_url'] ?? ''}'.startsWith('http')) ? NetworkImage('${u['avatar_url']}') : null,
                                child: ('${u['avatar_url'] ?? ''}'.startsWith('http')) ? null : Icon(Icons.person_rounded, color: c.textSecondary),
                              ),
                              title: Row(children: [
                                Flexible(child: Text('${u['display_name'] ?? u['username'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700))),
                                if (u['is_verified'] == true) ...[const SizedBox(width: 5), Icon(Icons.verified_rounded, color: c.info, size: 17)],
                              ]),
                              subtitle: Text(
                                '@${u['username'] ?? ''} · ${tr('{n} abonnés', {'n': (u['followers_count'] as num?)?.toInt() ?? 0})}${u['official'] is Map ? ' · ${(u['official'] as Map)['category']}' : ''}',
                                style: TextStyle(color: c.textSecondary, fontSize: 12),
                              ),
                              trailing: u['is_verified'] == true
                                  ? OutlinedButton(onPressed: () => _set(u, false), child: Text(tr('Retirer')))
                                  : FilledButton(onPressed: () => _set(u, true), child: Text(tr('Certifier'))),
                            ),
                          ),
                      ]),
                    ),
        ),
      ]),
    );
  }
}
