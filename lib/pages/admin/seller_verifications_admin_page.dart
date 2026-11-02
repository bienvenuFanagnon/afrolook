import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/tr.dart';
import '../../services/admin_reauth.dart';
import '../../services/api/live_shop_api.dart';
import '../../theme/app_colors.dart';

/// Vérification d'identité des vendeurs (équipe, droit « sellers.verify », connexion récente) : file des demandes, photos privées (liens de 5 minutes),
/// accepter ou refuser avec motif. Les photos sont effacées dès la décision.
class SellerVerificationsAdminPage extends StatefulWidget {
  const SellerVerificationsAdminPage({super.key});

  @override
  State<SellerVerificationsAdminPage> createState() => _SellerVerificationsAdminPageState();
}

class _SellerVerificationsAdminPageState extends State<SellerVerificationsAdminPage> {
  static final _date = DateFormat('dd/MM/yyyy HH:mm');
  String _status = 'pending';
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _counts = const {};
  List<Map<String, dynamic>> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final r = await AdminReauth.run(context, () => LiveShopApi.adminVerifications(status: _status));
      if (!mounted) return;
      setState(() {
        _counts = Map<String, dynamic>.from(r['counts'] as Map? ?? {});
        _items = (r['items'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = LiveShopApi.message(e); });
    }
  }

  String _typeLabel(String t) => switch (t) { 'passport' => tr('Passeport'), 'driver_license' => tr('Permis de conduire'), _ => tr('Carte d\'identité') };

  Future<void> _open(Map<String, dynamic> row) async {
    final changed = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => _VerificationDetailPage(id: '${row['id']}')));
    if (changed == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(backgroundColor: c.surface, foregroundColor: c.textPrimary, title: Text(tr('Identités des vendeurs'))),
      body: Column(children: [
        SizedBox(
          height: 52,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), children: [
            for (final s in const ['pending', 'approved', 'rejected', 'expired'])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text('${switch (s) { 'pending' => tr('À examiner'), 'approved' => tr('Acceptées'), 'rejected' => tr('Refusées'), _ => tr('Expirées') }} (${_counts[s] ?? 0})'),
                  selected: _status == s,
                  onSelected: (_) { setState(() => _status = s); _load(); },
                ),
              ),
          ]),
        ),
        Expanded(
          child: _loading
              ? Center(child: CircularProgressIndicator(color: c.primary))
              : _error != null
                  ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: c.danger))))
                  : _items.isEmpty
                      ? Center(child: Text(tr('Aucune demande.'), style: TextStyle(color: c.textSecondary)))
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.separated(
                            padding: const EdgeInsets.all(12),
                            itemCount: _items.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (_, i) {
                              final r = _items[i];
                              final u = Map<String, dynamic>.from(r['user'] as Map? ?? {});
                              final created = DateTime.tryParse('${r['created_at']}')?.toLocal();
                              return Material(
                                color: c.surface,
                                borderRadius: BorderRadius.circular(14),
                                child: ListTile(
                                  onTap: () => _open(r),
                                  leading: CircleAvatar(backgroundImage: '${u['avatar_url'] ?? ''}'.isNotEmpty ? NetworkImage('${u['avatar_url']}') : null, child: '${u['avatar_url'] ?? ''}'.isEmpty ? const Icon(Icons.person_rounded) : null),
                                  title: Text('${r['full_name']}', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800)),
                                  subtitle: Text('@${u['username'] ?? ''} · ${_typeLabel('${r['id_type']}')} · ${r['country']}${created == null ? '' : '\n${_date.format(created)}'}', style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
                                  isThreeLine: created != null,
                                  trailing: const Icon(Icons.chevron_right_rounded),
                                ),
                              );
                            },
                          ),
                        ),
        ),
      ]),
    );
  }
}

class _VerificationDetailPage extends StatefulWidget {
  const _VerificationDetailPage({required this.id});
  final String id;

  @override
  State<_VerificationDetailPage> createState() => _VerificationDetailPageState();
}

class _VerificationDetailPageState extends State<_VerificationDetailPage> {
  Map<String, dynamic>? _d;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await AdminReauth.run(context, () => LiveShopApi.adminVerification(widget.id));
      if (mounted) setState(() => _d = r);
    } catch (e) {
      if (mounted) setState(() => _error = LiveShopApi.message(e));
    }
  }

  Future<void> _decide(bool approve) async {
    String? reason;
    if (!approve) {
      final ctl = TextEditingController();
      reason = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(tr('Motif du refus')),
          content: TextField(controller: ctl, maxLength: 200, autofocus: true, decoration: InputDecoration(hintText: tr('Ex. : photo floue, nom différent de la pièce…'))),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Annuler'))),
            FilledButton(onPressed: () => Navigator.pop(ctx, ctl.text.trim()), child: Text(tr('Refuser'))),
          ],
        ),
      );
      if (reason == null || reason.length < 3) return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      await AdminReauth.run(context, () => LiveShopApi.adminDecideVerification(widget.id, approve: approve, reason: reason));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() { _busy = false; _error = LiveShopApi.message(e); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final d = _d;
    final docs = Map<String, dynamic>.from(d?['docs'] as Map? ?? {});
    final rep = Map<String, dynamic>.from(d?['reputation'] as Map? ?? {});
    final pending = d?['status'] == 'pending';
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(backgroundColor: c.surface, foregroundColor: c.textPrimary, title: Text(tr('Demande de vérification'))),
      body: d == null
          ? Center(child: _error != null ? Padding(padding: const EdgeInsets.all(24), child: Text(_error!, style: TextStyle(color: c.danger))) : CircularProgressIndicator(color: c.primary))
          : ListView(padding: const EdgeInsets.all(16), children: [
              Text('${d['full_name']}', style: TextStyle(color: c.textPrimary, fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text('@${(d['user'] as Map?)?['username'] ?? ''} · ${d['country']}', style: TextStyle(color: c.textSecondary)),
              if ((d['businesses'] as List? ?? []).isNotEmpty) Text(tr('Boutiques : {b}', {'b': (d['businesses'] as List).join(', ')}), style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
              Text(tr('Ventes terminées : {n} · note : {r}', {'n': '${rep['completed'] ?? 0}', 'r': rep['rating'] == null ? '—' : '${rep['rating']}'}), style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
              const SizedBox(height: 12),
              if (docs.isEmpty)
                Text(tr('Les photos ont été effacées après la décision.'), style: TextStyle(color: c.textSecondary))
              else
                for (final k in const ['front', 'back', 'selfie'])
                  if (docs[k] != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(switch (k) { 'front' => tr('Recto'), 'back' => tr('Verso'), _ => tr('Selfie') }, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        GestureDetector(
                          onTap: () => showDialog<void>(context: context, builder: (_) => Dialog(child: InteractiveViewer(child: Image.network('${docs[k]}')))),
                          child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network('${docs[k]}', height: 220, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(height: 80, color: c.surface, alignment: Alignment.center, child: Text(tr('Photo indisponible'))))),
                        ),
                      ]),
                    ),
              if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(_error!, style: TextStyle(color: c.danger, fontWeight: FontWeight.w700))),
              if (pending)
                Row(children: [
                  Expanded(child: OutlinedButton(onPressed: _busy ? null : () => _decide(false), child: Text(tr('Refuser')))),
                  const SizedBox(width: 12),
                  Expanded(child: FilledButton(onPressed: _busy ? null : () => _decide(true), child: _busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : Text(tr('Accepter')))),
                ])
              else
                Text(tr('Demande déjà traitée ({s}).', {'s': '${d['status']}'}), style: TextStyle(color: c.textSecondary)),
            ]),
    );
  }
}
