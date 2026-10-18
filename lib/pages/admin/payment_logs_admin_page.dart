// Suivi des paiements (administration) : journal de chaque étape d'un paiement (FeexPay, CinetPay, PayGate, Google Play, App Store),
// compteurs du jour par fournisseur, filtre « erreurs seulement ». Le journal est écrit par le serveur (PaymentLogs) ;
// chaque erreur envoie aussi un e-mail d'alerte à l'administration.

import 'package:afrotok/services/read_meter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'admin_palette.dart';
import 'card_payments_admin.dart';

const kPaymentProviders = <String, String>{
  'feexpay': 'FeexPay',
  'cinetpay': 'CinetPay',
  'paygate': 'PayGate',
  'google_play': 'Google Play',
  'apple': 'App Store',
  'balance': 'Solde',
  'app': 'Application',
};

/// Entrée du journal, lue dans PaymentLogs.
class PaymentLogEntry {
  PaymentLogEntry(this.id, Map<String, dynamic> m)
      : at = (m['at'] as num?)?.toInt() ?? 0,
        provider = '${m['provider'] ?? 'app'}',
        step = '${m['step'] ?? ''}',
        ok = m['ok'] == true,
        expected = m['expected'] == true,
        uid = m['uid'] as String?,
        amount = (m['amount'] as num?)?.toDouble(),
        currency = m['currency'] as String?,
        reference = m['reference'] as String?,
        code = m['code'] as String?,
        message = '${m['message'] ?? ''}';

  final String id;
  final int at;
  final String provider;
  final String step;
  final bool ok;
  final bool expected;
  final String? uid;
  final double? amount;
  final String? currency;
  final String? reference;
  final String? code;
  final String message;

  String get providerName => kPaymentProviders[provider] ?? provider;

  /// « credit » → « Pièces créditées », etc.
  String get stepLabel {
    final s = step.startsWith('app:') ? step.substring(4) : step;
    final base = switch (s) {
      'initiate' => 'Démarrage du paiement',
      'execute' => 'Envoi à l\'opérateur',
      'webhook' => 'Confirmation de l\'opérateur',
      'check' => 'Vérification du statut',
      'verify' => 'Vérification de l\'achat',
      'credit' => 'Pièces ou solde crédités',
      'pending_timeout' => 'Paiement jamais confirmé (30 min)',
      _ => s.isEmpty ? 'Paiement' : s,
    };
    return step.startsWith('app:') ? '$base (vu par l\'application)' : base;
  }
}

class PaymentLogsAdminPage extends StatefulWidget {
  const PaymentLogsAdminPage({super.key, this.preview});

  /// Journal et compteurs fournis d'avance (captures et tests) : aucune connexion à Firebase.
  @visibleForTesting
  final ({List<PaymentLogEntry> logs, Map<String, int> stats})? preview;

  @override
  State<PaymentLogsAdminPage> createState() => _PaymentLogsAdminPageState();
}

class _PaymentLogsAdminPageState extends State<PaymentLogsAdminPage> {
  bool _errorsOnly = true;
  String? _provider;

  static String _today() => DateTime.now().toUtc().toIso8601String().substring(0, 10);

  @override
  Widget build(BuildContext context) {
    AdminPalette.of(context);
    return Scaffold(
      backgroundColor: AdminPalette.bg,
      appBar: AppBar(
        backgroundColor: AdminPalette.bg,
        elevation: 0,
        iconTheme: IconThemeData(color: AdminPalette.textP),
        title: Text('Suivi des paiements', style: TextStyle(color: AdminPalette.textP, fontWeight: FontWeight.w900)),
        actions: [
          if (widget.preview == null)
            IconButton(
              tooltip: 'Réglages du paiement par carte (web)',
              icon: Icon(Icons.credit_card_rounded, color: AdminPalette.textP),
              onPressed: () => CardPaymentsAdminDialog.open(context),
            ),
        ],
      ),
      body: widget.preview != null ? _body(widget.preview!.logs, widget.preview!.stats) : _live(),
    );
  }

  Widget _live() {
    final db = FirebaseFirestore.instance;
    Query<Map<String, dynamic>> q = db.collection('PaymentLogs');
    if (_errorsOnly) q = q.where('ok', isEqualTo: false);
    q = q.orderBy('at', descending: true).limit(200);
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: db.collection('PaymentStats').doc(_today()).snapshotsM('payment_logs_admin_page.dart:115'),
      builder: (_, st) {
        final stats = <String, int>{for (final e in (st.data?.data() ?? const {}).entries) if (e.value is num) e.key: (e.value as num).toInt()};
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: q.snapshotsM('payment_logs_admin_page.dart:119'),
          builder: (_, snap) {
            if (snap.hasError) return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('Impossible de lire le journal : ${snap.error}', style: TextStyle(color: AdminPalette.red))));
            if (!snap.hasData) return Center(child: CircularProgressIndicator(color: AdminPalette.green));
            return _body([for (final d in snap.data!.docs) PaymentLogEntry(d.id, d.data())], stats);
          },
        );
      },
    );
  }

  Widget _body(List<PaymentLogEntry> all, Map<String, int> stats) {
    final shown = all.where((e) => (!_errorsOnly || (!e.ok && !e.expected)) && (_provider == null || e.provider == _provider)).toList();
    final errToday = [for (final p in kPaymentProviders.keys) stats['${p}_error'] ?? 0].fold<int>(0, (a, b) => a + b);
    final okToday = [for (final p in kPaymentProviders.keys) stats['${p}_ok'] ?? 0].fold<int>(0, (a, b) => a + b);
    return ListView(padding: const EdgeInsets.fromLTRB(14, 6, 14, 28), children: [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AdminPalette.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: errToday > 0 ? AdminPalette.red.withValues(alpha: .6) : AdminPalette.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('AUJOURD’HUI', style: TextStyle(color: AdminPalette.textS, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.1)),
          const SizedBox(height: 8),
          Row(children: [
            _big('$okToday', 'réussis', AdminPalette.green),
            const SizedBox(width: 22),
            _big('$errToday', errToday > 1 ? 'en erreur' : 'en erreur', errToday > 0 ? AdminPalette.red : AdminPalette.textS),
          ]),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 6, children: [
            for (final p in kPaymentProviders.entries)
              if ((stats['${p.key}_ok'] ?? 0) + (stats['${p.key}_error'] ?? 0) > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(color: AdminPalette.field, borderRadius: BorderRadius.circular(99)),
                  child: Text.rich(TextSpan(style: TextStyle(color: AdminPalette.textP, fontSize: 12, fontWeight: FontWeight.w700), children: [
                    TextSpan(text: '${p.value}  '),
                    TextSpan(text: '${stats['${p.key}_ok'] ?? 0}', style: TextStyle(color: AdminPalette.green)),
                    const TextSpan(text: ' · '),
                    TextSpan(text: '${stats['${p.key}_error'] ?? 0}', style: TextStyle(color: (stats['${p.key}_error'] ?? 0) > 0 ? AdminPalette.red : AdminPalette.textS)),
                  ])),
                ),
          ]),
          if (okToday + errToday == 0) Text('Aucun paiement aujourd’hui pour l’instant.', style: TextStyle(color: AdminPalette.textS, fontSize: 12.5)),
        ]),
      ),
      const SizedBox(height: 12),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          _chip('Erreurs', _errorsOnly, () => setState(() => _errorsOnly = true)),
          _chip('Tout', !_errorsOnly, () => setState(() => _errorsOnly = false)),
          const SizedBox(width: 10),
          _chip('Tous', _provider == null, () => setState(() => _provider = null)),
          for (final p in kPaymentProviders.entries) _chip(p.value, _provider == p.key, () => setState(() => _provider = p.key)),
        ]),
      ),
      const SizedBox(height: 10),
      if (shown.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Center(child: Text(_errorsOnly ? 'Aucune erreur de paiement. 👍' : 'Rien dans le journal.', style: TextStyle(color: AdminPalette.textS, fontSize: 15))),
        ),
      for (final e in shown) _row(e),
    ]);
  }

  Widget _big(String n, String label, Color c) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(n, style: TextStyle(color: c, fontSize: 30, fontWeight: FontWeight.w900, height: 1)),
        Text(label, style: TextStyle(color: AdminPalette.textS, fontSize: 12)),
      ]);

  Widget _chip(String label, bool on, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(right: 6),
        child: ChoiceChip(
          label: Text(label, style: TextStyle(color: on ? AdminPalette.bg : AdminPalette.textP, fontWeight: FontWeight.w700, fontSize: 12.5)),
          selected: on,
          onSelected: (_) => onTap(),
          selectedColor: AdminPalette.green,
          backgroundColor: AdminPalette.card,
          side: BorderSide(color: AdminPalette.border),
          visualDensity: VisualDensity.compact,
          showCheckmark: false,
        ),
      );

  static String _time(int at) {
    final d = DateTime.fromMillisecondsSinceEpoch(at);
    final now = DateTime.now();
    final hm = '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    if (d.year == now.year && d.month == now.month && d.day == now.day) return 'Aujourd’hui à $hm';
    final y = now.subtract(const Duration(days: 1));
    if (d.year == y.year && d.month == y.month && d.day == y.day) return 'Hier à $hm';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} à $hm';
  }

  Widget _row(PaymentLogEntry e) {
    final color = e.ok ? AdminPalette.green : (e.expected ? AdminPalette.amber : AdminPalette.red);
    final amount = e.amount == null ? '' : ' · ${e.amount!.toStringAsFixed(e.amount! % 1 == 0 ? 0 : 2)} ${e.currency ?? ''}'.trimRight();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: AdminPalette.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: AdminPalette.border)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _details(e),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: color.withValues(alpha: .15), shape: BoxShape.circle),
              child: Icon(e.ok ? Icons.check_rounded : (e.expected ? Icons.info_outline_rounded : Icons.error_outline_rounded), color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${e.providerName} · ${e.stepLabel}$amount', style: TextStyle(color: AdminPalette.textP, fontWeight: FontWeight.w800, fontSize: 13.5)),
                if (e.message.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2), child: Text(e.message, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(color: e.ok ? AdminPalette.textS : color, fontSize: 12.5, height: 1.3))),
                Padding(padding: const EdgeInsets.only(top: 3), child: Text(_time(e.at), style: TextStyle(color: AdminPalette.textS, fontSize: 11.5))),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  void _details(PaymentLogEntry e) {
    final lines = <String, String>{
      'Fournisseur': e.providerName,
      'Étape': e.stepLabel,
      'Résultat': e.ok ? 'Réussi' : (e.expected ? 'Erreur attendue (ex. annulation)' : 'Échec'),
      if (e.message.isNotEmpty) 'Message': e.message,
      if ((e.code ?? '').isNotEmpty) 'Code': e.code!,
      if (e.amount != null) 'Montant': '${e.amount} ${e.currency ?? ''}'.trim(),
      if ((e.reference ?? '').isNotEmpty) 'Référence': e.reference!,
      if ((e.uid ?? '').isNotEmpty) 'Utilisateur': e.uid!,
      'Date': DateTime.fromMillisecondsSinceEpoch(e.at).toString().substring(0, 19),
    };
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AdminPalette.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Détail', style: TextStyle(color: AdminPalette.textP, fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            for (final l in lines.entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(width: 100, child: Text(l.key, style: TextStyle(color: AdminPalette.textS, fontSize: 13))),
                  Expanded(child: SelectableText(l.value, style: TextStyle(color: AdminPalette.textP, fontSize: 13.5, fontWeight: FontWeight.w600))),
                ]),
              ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: lines.entries.map((x) => '${x.key} : ${x.value}').join('\n')));
                  Navigator.pop(ctx);
                },
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: const Text('Copier'),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
