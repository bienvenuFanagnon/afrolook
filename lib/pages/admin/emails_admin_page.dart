// emails_admin_page.dart — suivi des e-mails de l'application pour l'administration (API : GET /admin/emails).
// Derniers e-mails (envoyés, en attente, en échec avec la raison), chiffres des dernières 24 h, état de la configuration d'envoi, « envoyer maintenant » et « réessayer ».
// Le texte des e-mails n'est jamais montré : seulement l'objet, le destinataire et l'état.
import 'package:afrotok/layout/centered_content.dart';
import 'package:afrotok/services/api/api_gateway.dart';
import 'package:afrotok/services/api/regie_api.dart';
import 'package:afrotok/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class EmailsAdminPage extends StatefulWidget {
  const EmailsAdminPage({Key? key}) : super(key: key);

  @override
  State<EmailsAdminPage> createState() => _EmailsAdminPageState();
}

class _EmailsAdminPageState extends State<EmailsAdminPage> {
  static const _statuses = [('all', 'Tous'), ('pending', 'En attente'), ('sent', 'Envoyés'), ('failed', 'En échec')];
  static final DateFormat _df = DateFormat('dd/MM HH:mm');

  String _status = 'all';
  String? _kind;
  final TextEditingController _q = TextEditingController();
  bool _loading = true;
  bool _busy = false;
  String? _error;
  Map<String, dynamic> _d = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  static Map<String, dynamic> _m(Object? v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
  static int _i(Object? v) => v is num ? v.toInt() : 0;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await RegieApi.getMap('/admin/emails', query: {'status': _status, if (_kind != null) 'kind': _kind, if (_q.text.trim().isNotEmpty) 'q': _q.text.trim(), 'limit': 80});
      if (!mounted) return;
      setState(() {
        _d = r;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = RegieApi.err(e);
          _loading = false;
        });
      }
    }
  }

  Future<void> _act(Future<dynamic> Function() run, String Function(Map<String, dynamic>) msg) async {
    setState(() => _busy = true);
    try {
      final res = await run();
      final data = res is Map ? _m(res['data'] ?? res) : <String, dynamic>{};
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg(data))));
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(RegieApi.err(e)), backgroundColor: AppColors.of(context).danger));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _configCard(AppColors c) {
    final cfg = _m(_d['config']);
    final real = cfg['real'] == true;
    final host = cfg['smtpHost'] == true;
    final user = cfg['smtpUser'] == true;
    final ok = real && (cfg['mailer'] != 'smtp' || (host && user));
    final color = ok ? c.success : c.danger;
    final text = !real
        ? 'Les e-mails ne sont PAS vraiment envoyés : le mode d\'envoi est « ${cfg['mailer']} » (ils sont seulement écrits dans un journal). Il faut régler le fournisseur d\'e-mails sur le serveur.'
        : (cfg['mailer'] == 'smtp' && !(host && user))
            ? 'Mode SMTP, mais l\'hôte ou l\'identifiant ne semble pas réglé : les envois risquent d\'échouer.'
            : 'Envoi réel actif (${cfg['mailer']}). Expéditeur : ${cfg['from']}.';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withValues(alpha: .10), borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withValues(alpha: .45))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(ok ? Icons.check_circle_rounded : Icons.warning_amber_rounded, color: color),
        const SizedBox(width: 10),
        Expanded(child: Text(text, key: const ValueKey('mail_config'), style: TextStyle(color: c.textPrimary, fontSize: 13.5, height: 1.35))),
      ]),
    );
  }

  Widget _tile(AppColors c, String label, int n, Color color) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.border)),
          child: Column(children: [
            Text('$n', style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w900)),
            Text(label, style: TextStyle(color: c.textSecondary, fontSize: 12)),
          ]),
        ),
      );

  Widget _item(AppColors c, Map<String, dynamic> m) {
    final status = '${m['status']}';
    final color = status == 'sent' ? c.success : (status == 'failed' ? c.danger : c.textSecondary);
    final icon = status == 'sent' ? Icons.mark_email_read_rounded : (status == 'failed' ? Icons.error_outline_rounded : Icons.schedule_rounded);
    final when = DateTime.tryParse('${m['sentAt'] ?? m['createdAt']}')?.toLocal();
    return Container(
      key: ValueKey('mail_${m['id']}'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.border)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${m['subject']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 13.5)),
            const SizedBox(height: 2),
            Text('${m['to']}  ·  ${m['kind']}${when == null ? '' : '  ·  ${_df.format(when)}'}', style: TextStyle(color: c.textSecondary, fontSize: 12)),
            if (m['error'] != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text('${m['error']}', style: TextStyle(color: c.danger, fontSize: 12))),
          ]),
        ),
        if (status == 'failed')
          TextButton(
            key: ValueKey('mail_retry_${m['id']}'),
            onPressed: _busy ? null : () => _act(() => ApiGateway.instance.client.post('/admin/emails/${m['id']}/retry', body: const {}), (_) => 'Remis en file : il repartira à la prochaine passe ou avec « Envoyer maintenant ».'),
            child: const Text('Réessayer'),
          ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final counts = _m(_d['counts24h']);
    final kinds = (_d['kinds'] is List ? (_d['kinds'] as List).map((e) => '$e').toList() : <String>[]);
    final items = (_d['items'] is List ? (_d['items'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : <Map<String, dynamic>>[]);
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.surface,
        foregroundColor: c.textPrimary,
        elevation: 0,
        title: const Text('Suivi des e-mails'),
        actions: [IconButton(tooltip: 'Actualiser', icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      body: SafeArea(
        child: CenteredContent(
          maxWidth: 900,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: c.danger)),
                          const SizedBox(height: 12),
                          OutlinedButton(onPressed: _load, child: const Text('Réessayer')),
                        ]),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(padding: const EdgeInsets.all(16), children: [
                        _configCard(c),
                        const SizedBox(height: 12),
                        Row(children: [
                          _tile(c, 'Envoyés (24 h)', _i(counts['sent']), c.success),
                          const SizedBox(width: 8),
                          _tile(c, 'En attente', _i(counts['pending']), c.textSecondary),
                          const SizedBox(width: 8),
                          _tile(c, 'En échec', _i(counts['failed']), c.danger),
                        ]),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            key: const ValueKey('mail_dispatch'),
                            onPressed: _busy ? null : () => _act(() => ApiGateway.instance.client.post('/admin/emails/dispatch', body: _kind == null ? const {} : {'kind': _kind}), (d) => '${_i(d['sent'])} envoyé(s), ${_i(d['failed'])} en échec.'),
                            icon: const Icon(Icons.send_rounded),
                            label: Text(_kind == null ? 'Envoyer maintenant ce qui attend' : 'Envoyer maintenant ($_kind)'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(spacing: 8, runSpacing: 4, children: [
                          for (final s in _statuses)
                            ChoiceChip(
                              key: ValueKey('mail_status_${s.$1}'),
                              label: Text(s.$2),
                              selected: _status == s.$1,
                              onSelected: (_) {
                                setState(() => _status = s.$1);
                                _load();
                              },
                            ),
                        ]),
                        if (kinds.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Wrap(spacing: 8, runSpacing: 4, children: [
                              ChoiceChip(label: const Text('Tous les types'), selected: _kind == null, onSelected: (_) {
                                setState(() => _kind = null);
                                _load();
                              }),
                              for (final k in kinds)
                                ChoiceChip(
                                  label: Text(k),
                                  selected: _kind == k,
                                  onSelected: (_) {
                                    setState(() => _kind = _kind == k ? null : k);
                                    _load();
                                  },
                                ),
                            ]),
                          ),
                        const SizedBox(height: 10),
                        TextField(
                          key: const ValueKey('mail_search'),
                          controller: _q,
                          textInputAction: TextInputAction.search,
                          onSubmitted: (_) => _load(),
                          decoration: InputDecoration(hintText: 'Chercher une adresse ou un objet', prefixIcon: const Icon(Icons.search_rounded), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                        ),
                        const SizedBox(height: 12),
                        if (items.isEmpty) Padding(padding: const EdgeInsets.all(24), child: Center(child: Text('Aucun e-mail ne correspond.', style: TextStyle(color: c.textSecondary)))),
                        for (final m in items) _item(c, m),
                      ]),
                    ),
        ),
      ),
    );
  }
}
