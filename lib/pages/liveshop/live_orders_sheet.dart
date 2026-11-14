import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/tr.dart';
import '../../services/api/live_shop_api.dart';
import 'live_shop_orders_page.dart';
import 'seller_badge.dart';

/// « Mes commandes » DANS le live (spectateur) : la personne suit et gère ses commandes sans quitter le live —
/// frais de livraison à accepter ou refuser, annulation tant que le vendeur n'a pas validé, code de livraison, « J'ai reçu », problème à signaler.
/// La fenêtre se met à jour toute seule (toutes les 8 secondes) : un changement fait par le vendeur apparaît aussitôt.
/// Les commandes de CE live passent en premier ; « Tout voir » ouvre la page complète.
Future<void> showLiveOrdersSheet(BuildContext context, {required String liveId}) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LiveOrdersSheet(liveId: liveId),
    );

class LiveOrdersSheet extends StatefulWidget {
  const LiveOrdersSheet({super.key, required this.liveId, this.loader});

  final String liveId;

  /// Pour les essais : remplace la lecture des commandes.
  final Future<List<Map<String, dynamic>>> Function()? loader;

  @override
  State<LiveOrdersSheet> createState() => _LiveOrdersSheetState();
}

class _LiveOrdersSheetState extends State<LiveOrdersSheet> {
  static final NumberFormat _n = NumberFormat.decimalPattern('fr');
  static const _gold = Color(0xFFF9A825);

  List<Map<String, dynamic>> _orders = const [];
  bool _loading = true;
  String? _busyId;
  Timer? _poll;
  final Map<String, String> _lastStatus = {};
  final Set<String> _changed = {};   // commandes dont l'étape vient de changer (encadré lumineux quelques secondes)

  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(const Duration(seconds: 8), (_) => _load());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final all = await (widget.loader?.call() ?? LiveShopApi.orders(role: 'buyer', limit: 40));
      // celles qui sont en cours d'abord (celles de ce live en tête), puis les dernières terminées de ce live
      final open = {'pending_seller', 'pending_buyer', 'accepted', 'shipped', 'disputed'};
      final mine = all.where((o) => open.contains('${o['status']}') || '${o['live_id']}' == widget.liveId).toList()
        ..sort((a, b) {
          int rank(Map o) => ('${o['live_id']}' == widget.liveId ? 0 : 2) + (open.contains('${o['status']}') ? 0 : 1);
          return rank(a).compareTo(rank(b));
        });
      if (!mounted) return;
      final changed = <String>{};
      for (final o in mine) {
        final id = '${o['id']}', st = '${o['status']}';
        if (_lastStatus.containsKey(id) && _lastStatus[id] != st) changed.add(id);
        _lastStatus[id] = st;
      }
      setState(() {
        _orders = mine.take(15).toList();
        _loading = false;
        _changed.addAll(changed);
      });
      if (changed.isNotEmpty) Future.delayed(const Duration(seconds: 6), () { if (mounted) setState(() => _changed.removeAll(changed)); });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _f(num v) => '${_n.format(v)} F';

  void _say(String m) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _act(String id, Future<dynamic> Function() action, {String? done}) async {
    setState(() => _busyId = id);
    try {
      await action();
      if (done != null) _say(done);
    } catch (e) {
      _say(LiveShopApi.message(e));
    }
    if (mounted) setState(() => _busyId = null);
    await _load();
  }

  Future<bool> _confirm(String text) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          content: Text(text),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('Non'))),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('Oui'))),
          ],
        ),
      ) ??
      false;

  Future<String?> _ask(String title, String hint) async {
    final c = TextEditingController();
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(controller: c, autofocus: true, maxLines: 2, decoration: InputDecoration(hintText: hint, border: const OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Annuler'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: Text(tr('Envoyer'))),
        ],
      ),
    );
    return (v == null || v.length < 5) ? null : v;
  }

  /// Étapes : Envoyée → Validée → Expédiée → Reçue, et ce qu'il faut faire maintenant.
  Widget _steps(String s) {
    final idx = switch (s) { 'pending_seller' => 0, 'pending_buyer' => 1, 'accepted' => 1, 'shipped' => 2, 'completed' => 3, _ => -1 };
    if (idx < 0) return const SizedBox.shrink();
    final labels = [tr('Envoyée'), tr('Validée'), tr('Expédiée'), tr('Reçue')];
    final mine = s == 'pending_buyer' || s == 'shipped';
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(children: [
        for (var i = 0; i < 4; i++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i < 3 ? 4 : 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(height: 5, decoration: BoxDecoration(color: i < idx ? const Color(0xFF69F0AE) : (i == idx ? (mine ? _gold : const Color(0xFF69F0AE)) : Colors.white24), borderRadius: BorderRadius.circular(99))),
                const SizedBox(height: 3),
                Text(labels[i], style: TextStyle(color: i <= idx ? Colors.white : Colors.white38, fontSize: 10.5, fontWeight: i == idx ? FontWeight.w800 : FontWeight.w500)),
              ]),
            ),
          ),
      ]),
    );
  }

  Widget _card(Map<String, dynamic> o) {
    final id = '${o['id']}';
    final s = '${o['status']}';
    final busy = _busyId == id;
    final fee = (o['delivery_fee_xof'] as num?)?.toInt();
    final price = (o['price_xof'] as num?)?.toInt() ?? 0;
    final seller = o['seller'] as Map?;
    final mine = s == 'pending_buyer' || s == 'shipped';
    final (String what, Color color) = switch (s) {
      'pending_seller' => (tr('En attente du vendeur : il doit valider ta commande.'), Colors.white70),
      'pending_buyer' => (tr('Le vendeur a fixé les frais de livraison : {f}, payés à la livraison. Accepte ou refuse.', {'f': _f(fee ?? 0)}), _gold),
      'accepted' => (tr('Validée : le vendeur prépare ta commande.'), const Color(0xFF69F0AE)),
      'shipped' => (tr('Ta commande est en route : confirme quand tu l\'as reçue.'), _gold),
      'completed' => (tr('Commande terminée.'), const Color(0xFF69F0AE)),
      'cancelled' || 'refunded' => (tr('Commande annulée : tu es remboursé.'), Colors.white54),
      'disputed' => (tr('Problème signalé : l\'équipe examine ton cas, ton argent reste protégé.'), Colors.redAccent),
      _ => (s, Colors.white70),
    };
    final actions = <Widget>[];
    if (s == 'pending_buyer') {
      actions.add(FilledButton(
        key: ValueKey('accept_fee_$id'),
        style: FilledButton.styleFrom(backgroundColor: _gold, foregroundColor: Colors.black),
        onPressed: busy ? null : () => _act(id, () => LiveShopApi.buyerFee(id, true), done: tr('Frais acceptés : le vendeur prépare ta commande.')),
        child: Text(tr('Accepter les frais')),
      ));
      actions.add(OutlinedButton(
        style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white38)),
        onPressed: busy ? null : () async { if (await _confirm(tr('Refuser ces frais annule la commande, sans pénalité, et tu es remboursé. Continuer ?'))) await _act(id, () => LiveShopApi.buyerFee(id, false), done: tr('Commande annulée, tu es remboursé.')); },
        child: Text(tr('Refuser')),
      ));
    } else if (s == 'pending_seller') {
      actions.add(OutlinedButton(
        style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white38)),
        onPressed: busy ? null : () async { if (await _confirm(tr('Annuler la commande ? Tu es remboursé en entier.'))) await _act(id, () => LiveShopApi.cancel(id), done: tr('Commande annulée, tu es remboursé.')); },
        child: Text(tr('Annuler')),
      ));
    } else if (s == 'shipped') {
      actions.add(FilledButton(
        style: FilledButton.styleFrom(backgroundColor: _gold, foregroundColor: Colors.black),
        onPressed: busy ? null : () async { if (await _confirm(tr('Confirmer la réception ? L\'argent est alors versé au vendeur.'))) await _act(id, () => LiveShopApi.confirm(id), done: tr('Merci ! Réception confirmée.')); },
        child: Text(tr('J\'ai reçu')),
      ));
      actions.add(TextButton(
        onPressed: busy ? null : () async { final v = await _ask(tr('Que se passe-t-il ?'), tr('Colis non reçu, article différent…')); if (v != null) await _act(id, () => LiveShopApi.dispute(id, v), done: tr('Notre équipe examine ton cas. Ton argent reste protégé.')); },
        child: Text(tr('Signaler un problème'), style: const TextStyle(color: Colors.white70)),
      ));
    }
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _changed.contains(id) ? _gold.withOpacity(0.18) : Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: mine ? _gold : Colors.white12, width: mine ? 1.5 : 1),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('${o['title']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14.5))),
          Text(_f(price), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        ]),
        if (seller != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Row(children: [
              Flexible(child: Text(tr('Chez @{p}', {'p': '${seller['username'] ?? ''}'}), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white60, fontSize: 12))),
              if (seller['verified'] == true) const Padding(padding: EdgeInsets.only(left: 5), child: SellerVerifiedBadge(compact: true, onDark: true)),
              if ('${o['live_id']}' == widget.liveId) Padding(padding: const EdgeInsets.only(left: 6), child: Text(tr('· dans ce live'), style: const TextStyle(color: _gold, fontSize: 11.5, fontWeight: FontWeight.w700))),
            ]),
          ),
        _steps(s),
        const SizedBox(height: 6),
        Text(what, style: TextStyle(color: color, fontSize: 12.5, fontWeight: mine ? FontWeight.w800 : FontWeight.w500, height: 1.3)),
        if ('${o['delivery_code'] ?? ''}'.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: _gold.withOpacity(0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: _gold.withOpacity(0.5))),
            child: Row(children: [
              Expanded(child: Text(tr('Ton code de livraison : donne-le seulement quand tu as ta commande en main.'), style: const TextStyle(color: Colors.white70, fontSize: 11.5, height: 1.3))),
              const SizedBox(width: 8),
              SelectableText('${o['delivery_code']}', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 4)),
            ]),
          ),
        if (actions.isNotEmpty) ...[
          const SizedBox(height: 10),
          busy ? const SizedBox(height: 36, child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: _gold))) : Wrap(spacing: 8, runSpacing: 6, children: actions),
        ],
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('live_orders_sheet'),
      height: MediaQuery.of(context).size.height * .72,
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF26223A), Color(0xFF15121F)]),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(children: [
        const SizedBox(height: 8),
        Container(width: 38, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(99))),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 8, 2),
          child: Row(children: [
            const Icon(Icons.receipt_long_rounded, color: _gold, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(tr('Mes commandes'), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LiveShopOrdersPage()));
              },
              child: Text(tr('Tout voir'), style: const TextStyle(color: _gold)),
            ),
            IconButton(icon: const Icon(Icons.close_rounded, color: Colors.white54), onPressed: () => Navigator.pop(context)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Text(tr('Tu restes dans le live : la page se met à jour toute seule quand le vendeur répond.'), style: const TextStyle(color: Colors.white38, fontSize: 11.5)),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: _gold))
              : _orders.isEmpty
                  ? Center(child: Padding(padding: const EdgeInsets.all(32), child: Text(tr('Aucune commande en cours. Touche un produit de la vitrine pour commander.'), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60, height: 1.4))))
                  : RefreshIndicator(
                      color: _gold,
                      onRefresh: _load,
                      child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [for (final o in _orders) _card(o)]),
                    ),
        ),
      ]),
    );
  }
}
