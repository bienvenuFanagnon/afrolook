import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/tr.dart';
import '../../services/api/live_shop_api.dart';
import '../../theme/app_colors.dart';
import 'delivery_rates_page.dart';
import 'promo_codes_page.dart';
import 'live_sales_card.dart';

/// « Mes commandes » du Live Shopping : achats, ventes et négociations, avec les actions de chaque étape
/// (valider, expédier, confirmer la réception, annuler, signaler un problème). L'argent de l'acheteur est protégé (séquestre) jusqu'à la réception.
class LiveShopOrdersPage extends StatefulWidget {
  const LiveShopOrdersPage({super.key});

  @override
  State<LiveShopOrdersPage> createState() => _LiveShopOrdersPageState();
}

class _LiveShopOrdersPageState extends State<LiveShopOrdersPage> {
  static final NumberFormat _n = NumberFormat.decimalPattern('fr');

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _buy = const [];
  List<Map<String, dynamic>> _sell = const [];
  List<Map<String, dynamic>> _offersBuy = const [];
  List<Map<String, dynamic>> _offersSell = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final r = await Future.wait([
        LiveShopApi.orders(role: 'buyer'),
        LiveShopApi.orders(role: 'seller'),
        LiveShopApi.offers(role: 'buyer'),
        LiveShopApi.offers(role: 'seller'),
      ]);
      if (!mounted) return;
      setState(() { _buy = r[0]; _sell = r[1]; _offersBuy = r[2]; _offersSell = r[3]; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = LiveShopApi.message(e); _loading = false; });
    }
  }

  Future<void> _do(Future<dynamic> Function() action, {String? done}) async {
    try {
      await action();
      if (mounted && done != null) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(done)));
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(LiveShopApi.message(e))));
    }
  }

  String _f(num v) => '${_n.format(v)} F';

  String _statusLabel(String s) => switch (s) {
        'pending_seller' => tr('En attente du vendeur'),
        'pending_buyer' => tr('Frais de livraison à accepter'),
        'accepted' => tr('Validée, en préparation'),
        'shipped' => tr('Expédiée'),
        'completed' => tr('Terminée'),
        'cancelled' => tr('Annulée'),
        'disputed' => tr('Problème signalé'),
        'refunded' => tr('Remboursée'),
        _ => s,
      };

  Color _statusColor(AppColors c, String s) => switch (s) {
        'completed' => c.primary,
        'shipped' || 'accepted' => c.info,
        'pending_seller' || 'pending_buyer' => c.warning,
        'disputed' => c.danger,
        _ => c.textSecondary,
      };

  Future<String?> _ask(String title, {String? hint, TextInputType type = TextInputType.text, String? initial}) async {
    final ctl = TextEditingController(text: initial);
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(controller: ctl, keyboardType: type, autofocus: true, decoration: InputDecoration(hintText: hint, border: const OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Annuler'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctl.text.trim()), child: Text(tr('Valider'))),
        ],
      ),
    );
    return (v == null || v.isEmpty) ? null : v;
  }

  /// Note le vendeur (1 à 5 étoiles, commentaire facultatif) : une seule fois par commande terminée.
  Future<void> _rate(Map<String, dynamic> o) async {
    int stars = 5;
    final ctl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: Text(tr('Comment s\'est passé cet achat ?')),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(i <= stars ? Icons.star_rounded : Icons.star_border_rounded, color: const Color(0xFFF9A825), size: 34),
                  onPressed: () => set(() => stars = i),
                ),
            ]),
            TextField(controller: ctl, maxLength: 300, maxLines: 2, decoration: InputDecoration(hintText: tr('Un mot sur le vendeur (facultatif)'), border: const OutlineInputBorder())),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('Plus tard'))),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('Envoyer mon avis'))),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await _do(() => LiveShopApi.review('${o['id']}', stars, comment: ctl.text), done: tr('Merci pour ton avis !'));
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

  // ── Cartes ──

  Widget _chip(AppColors c, String s) {
    final color = _statusColor(c, s);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.14), borderRadius: BorderRadius.circular(99)),
      child: Text(_statusLabel(s), style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w800)),
    );
  }

  Widget _card(AppColors c, Map<String, dynamic> o, {required bool seller}) {
    final s = '${o['status']}';
    final price = (o['price_xof'] as num?)?.toInt() ?? 0;
    final estimate = (o['delivery_estimate_xof'] as num?)?.toInt();
    final fee = (o['delivery_fee_xof'] as num?)?.toInt();
    final actions = <Widget>[];
    void add(String label, VoidCallback onTap, {bool primary = false}) =>
        actions.add(primary ? FilledButton(onPressed: onTap, child: Text(label)) : OutlinedButton(onPressed: onTap, child: Text(label)));

    if (seller) {
      if (s == 'pending_seller') {
        add(tr('Valider'), () async {
          final v = await _ask(tr('Frais de livraison (payés à la livraison)'), hint: estimate != null ? '$estimate' : '0', type: TextInputType.number, initial: estimate?.toString());
          if (v == null) return;
          await _do(() => LiveShopApi.sellerValidate('${o['id']}', deliveryFee: int.tryParse(v)), done: tr('Commande validée.'));
        }, primary: true);
        add(tr('Annuler'), () async { if (await _confirm(tr("Annuler cette commande ? L'acheteur sera remboursé en entier."))) await _do(() => LiveShopApi.cancel('${o['id']}', reason: tr('Annulée par le vendeur'))); });
      } else if (s == 'shipped') {
        add(tr('Saisir le code de livraison'), () async {
          final v = await _ask(tr("Code à 4 chiffres donné par l'acheteur à la remise"), hint: '0000', type: TextInputType.number);
          if (v == null) return;
          await _do(() => LiveShopApi.deliver('${o['id']}', v), done: tr('Livraison confirmée : ton argent est versé.'));
        }, primary: true);
      } else if (s == 'accepted') {
        add(tr('Marquer expédiée'), () => _do(() => LiveShopApi.ship('${o['id']}'), done: tr('Commande expédiée.')), primary: true);
        actions.add(SizedBox(width: double.infinity, child: Text(tr("Commande validée : elle ne peut plus être annulée. Expédie-la sous 7 jours, sinon l'acheteur est remboursé automatiquement et ta note de vendeur baisse."), style: TextStyle(color: c.textSecondary, fontSize: 12, height: 1.35))));
      }
    } else {
      if (s == 'pending_buyer') {
        add(tr('Accepter les frais'), () => _do(() => LiveShopApi.buyerFee('${o['id']}', true)), primary: true);
        add(tr('Refuser'), () async { if (await _confirm(tr('Refuser ces frais annule la commande, sans pénalité. Continuer ?'))) await _do(() => LiveShopApi.buyerFee('${o['id']}', false)); });
      } else if (s == 'pending_seller') {
        add(tr('Annuler'), () async { if (await _confirm(tr("Annuler la commande ? Tu es remboursé en entier."))) await _do(() => LiveShopApi.cancel('${o['id']}')); });
      } else if (s == 'accepted') {
        actions.add(SizedBox(width: double.infinity, child: Text(tr("Commande validée par le vendeur : elle ne peut plus être annulée. Si elle n'est pas expédiée sous 7 jours, tu es remboursé automatiquement."), style: TextStyle(color: c.textSecondary, fontSize: 12, height: 1.35))));
      } else if (s == 'completed' && o['reviewed'] != true) {
        add(tr('Noter le vendeur'), () => _rate(o), primary: true);
      } else if (s == 'shipped') {
        add(tr("J'ai reçu"), () async {
          if (!await _confirm(tr("Confirmer la réception ? L'argent est alors versé au vendeur."))) return;
          await _do(() => LiveShopApi.confirm('${o['id']}'), done: tr('Merci ! Réception confirmée.'));
          if (mounted) await _rate(o);
        }, primary: true);
        add(tr('Signaler un problème'), () async {
          final v = await _ask(tr('Que se passe-t-il ?'), hint: tr('Colis non reçu, article différent…'));
          if (v != null && v.length >= 5) await _do(() => LiveShopApi.dispute('${o['id']}', v), done: tr("Notre équipe examine ton cas. Ton argent reste protégé."));
        });
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: c.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('${o['title']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 15))),
          const SizedBox(width: 8),
          _chip(c, s),
        ]),
        const SizedBox(height: 6),
        Text(tr('{p} · quantité {q}', {'p': _f(price), 'q': (o['quantity'] as num?)?.toInt() ?? 1}), style: TextStyle(color: c.textSecondary, fontSize: 13)),
        Text(
          fee != null
              ? tr('Livraison : {f}, payée à la livraison', {'f': _f(fee)})
              : (estimate != null ? tr('Livraison estimée : {f}, payée à la livraison', {'f': _f(estimate)}) : tr('Livraison : à convenir, payée à la livraison')),
          style: TextStyle(color: c.textSecondary, fontSize: 12.5),
        ),
        if (seller && '${o['address'] ?? ''}'.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('${o['city'] ?? ''} · ${o['address']} · ${o['phone'] ?? ''}', style: TextStyle(color: c.textPrimary, fontSize: 12.5)),
          ),
        if ((o['penalty_xof'] as num?) != null && (o['penalty_xof'] as num) > 0)
          Padding(padding: const EdgeInsets.only(top: 4), child: Text(tr("Pénalité d'annulation : {f}", {'f': _f(o['penalty_xof'] as num)}), style: TextStyle(color: c.danger, fontSize: 12.5))),
        if (seller && s == 'completed' && o['received_xof'] != null)
          Padding(padding: const EdgeInsets.only(top: 4), child: Text(tr('Tu as reçu : {f}', {'f': _f(o['received_xof'] as num)}), style: TextStyle(color: c.primary, fontWeight: FontWeight.w800, fontSize: 13))),
        if ('${o['promo_code'] ?? ''}'.isNotEmpty)
          Padding(padding: const EdgeInsets.only(top: 4), child: Text(tr('Code promo {c} : -{f}', {'c': '${o['promo_code']}', 'f': _f((o['discount_xof'] as num?) ?? 0)}), style: TextStyle(color: c.primary, fontSize: 12.5, fontWeight: FontWeight.w700))),
        if (!seller && '${o['delivery_code'] ?? ''}'.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: c.warning.withOpacity(0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: c.warning.withOpacity(0.5))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr('Ton code de livraison'), style: TextStyle(color: c.textSecondary, fontSize: 12)),
              SelectableText('${o['delivery_code']}', style: TextStyle(color: c.textPrimary, fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: 8)),
              Text(tr("Donne-le au vendeur ou au livreur SEULEMENT quand tu as ta commande en main : il déclenche le paiement du vendeur."), style: TextStyle(color: c.textSecondary, fontSize: 11.5, height: 1.3)),
            ]),
          ),
        if (s == 'shipped' && !seller)
          Padding(padding: const EdgeInsets.only(top: 6), child: Text(tr("Sans réponse de ta part, l'argent est versé au vendeur 7 jours après l'expédition."), style: TextStyle(color: c.textSecondary, fontSize: 11.5))),
        if (actions.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: actions),
        ],
      ]),
    );
  }

  Widget _offerCard(AppColors c, Map<String, dynamic> o, {required bool seller}) {
    final s = '${o['status']}';
    final asked = (o['buyer_amount_xof'] as num?)?.toInt() ?? 0;
    final counter = (o['counter_xof'] as num?)?.toInt();
    final agreed = (o['agreed_xof'] as num?)?.toInt();
    final label = switch (s) {
      'open' => seller ? tr('À ton tour de répondre') : tr('En attente du vendeur'),
      'countered' => seller ? tr("En attente de l'acheteur") : tr('Contre-proposition reçue'),
      'accepted' => tr('Accord trouvé'),
      'refused' => tr('Refusée'),
      'expired' => tr('Expirée'),
      'used' => tr('Utilisée pour une commande'),
      _ => s,
    };
    final actions = <Widget>[];
    if (seller && s == 'open') {
      actions.add(FilledButton(onPressed: () => _do(() => LiveShopApi.sellerReply('${o['id']}', 'accept')), child: Text(tr('Accepter'))));
      actions.add(OutlinedButton(
        onPressed: () async {
          final v = await _ask(tr('Ton prix'), type: TextInputType.number);
          if (v != null && int.tryParse(v) != null) await _do(() => LiveShopApi.sellerReply('${o['id']}', 'counter', amount: int.parse(v)));
        },
        child: Text(tr('Contre-proposer')),
      ));
      actions.add(TextButton(onPressed: () => _do(() => LiveShopApi.sellerReply('${o['id']}', 'refuse')), child: Text(tr('Refuser'))));
    } else if (!seller && s == 'countered') {
      actions.add(FilledButton(onPressed: () => _do(() => LiveShopApi.buyerReply('${o['id']}', 'accept')), child: Text(tr('Accepter {f}', {'f': _f(counter ?? 0)}))));
      if (((o['round'] as num?)?.toInt() ?? 1) < ((o['rounds_max'] as num?)?.toInt() ?? 3)) {
        actions.add(OutlinedButton(
          onPressed: () async {
            final v = await _ask(tr('Ton nouveau prix'), type: TextInputType.number);
            if (v != null && int.tryParse(v) != null) await _do(() => LiveShopApi.buyerReply('${o['id']}', 'propose', amount: int.parse(v)));
          },
          child: Text(tr('Proposer un autre prix')),
        ));
      }
      actions.add(TextButton(onPressed: () => _do(() => LiveShopApi.buyerReply('${o['id']}', 'refuse')), child: Text(tr('Refuser'))));
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: c.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 14)),
        const SizedBox(height: 4),
        Text(
          agreed != null ? tr('Prix convenu : {f}', {'f': _f(agreed)}) : tr('Proposition : {a} · tour {r}/{m}', {'a': _f(asked), 'r': (o['round'] as num?)?.toInt() ?? 1, 'm': (o['rounds_max'] as num?)?.toInt() ?? 3}),
          style: TextStyle(color: c.textSecondary, fontSize: 13),
        ),
        if (counter != null && s == 'countered') Text(tr('Contre-proposition : {f}', {'f': _f(counter)}), style: TextStyle(color: c.primary, fontWeight: FontWeight.w700, fontSize: 13)),
        if (actions.isNotEmpty) ...[const SizedBox(height: 10), Wrap(spacing: 8, runSpacing: 8, children: actions)],
      ]),
    );
  }

  Widget _list(AppColors c, List<Widget> items, String empty) => RefreshIndicator(
        color: c.primary,
        onRefresh: _load,
        child: items.isEmpty
            ? ListView(children: [Padding(padding: const EdgeInsets.all(40), child: Center(child: Text(empty, textAlign: TextAlign.center, style: TextStyle(color: c.textSecondary))))])
            : ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 32), children: items),
      );

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: c.background,
        appBar: AppBar(
          backgroundColor: c.surface,
          foregroundColor: c.textPrimary,
          title: Text(tr('Mes commandes')),
          actions: [
            IconButton(
              tooltip: tr('Mes codes promo'),
              icon: const Icon(Icons.local_offer_outlined),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PromoCodesPage())),
            ),
            IconButton(
              tooltip: tr('Mes tarifs de livraison'),
              icon: const Icon(Icons.local_shipping_outlined),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DeliveryRatesPage())),
            ),
          ],
          bottom: TabBar(
            labelColor: c.primary,
            unselectedLabelColor: c.textSecondary,
            indicatorColor: c.primary,
            tabs: [Tab(text: tr('Achats')), Tab(text: tr('Ventes')), Tab(text: tr('Offres'))],
          ),
        ),
        body: _loading
            ? Center(child: CircularProgressIndicator(color: c.primary))
            : _error != null
                ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: c.textSecondary)), TextButton(onPressed: _load, child: Text(tr('Réessayer')))])))
                : TabBarView(children: [
                    _list(c, [for (final o in _buy) _card(c, o, seller: false)], tr('Aucun achat pour le moment.')),
                    _list(c, [const SellerStatsCard(), for (final o in _sell) _card(c, o, seller: true)], tr('Aucune vente pour le moment.')),
                    _list(c, [for (final o in _offersSell) _offerCard(c, o, seller: true), for (final o in _offersBuy) _offerCard(c, o, seller: false)], tr('Aucune négociation pour le moment.')),
                  ]),
      ),
    );
  }
}
