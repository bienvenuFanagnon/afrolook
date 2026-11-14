import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/tr.dart';
import '../../theme/app_colors.dart';
import 'live_sales_card.dart';

final NumberFormat _n = NumberFormat.decimalPattern('fr');
String _f(num v) => '${_n.format(v)} F';

int _i(Object? v) => (v as num?)?.toInt() ?? 0;
int _st(Map<String, dynamic> counts, String role, String status) => _i((counts['${role}_status'] as Map?)?[status]);

/// Tuile chiffrée (une étape, un total) : touche = ouvre la liste correspondante.
Widget _tile(AppColors c, String label, int n, VoidCallback? onTap, {Color? color, bool alert = false, String? sub, IconData? icon}) {
  final col = alert && n > 0 ? color ?? c.danger : c.textPrimary;
  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: alert && n > 0 ? (color ?? c.danger) : c.border, width: alert && n > 0 ? 1.5 : 1)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          if (icon != null) ...[Icon(icon, size: 15, color: c.textSecondary), const SizedBox(width: 4)],
          Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textSecondary, fontSize: 11.5))),
        ]),
        const SizedBox(height: 2),
        Text('$n', style: TextStyle(color: col, fontSize: 20, fontWeight: FontWeight.w800)),
        if (sub != null) Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textSecondary, fontSize: 10.5)),
      ]),
    ),
  );
}

Widget _grid2(List<Widget> kids) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(children: [
        for (var i = 0; i < kids.length; i += 2)
          Padding(
            padding: EdgeInsets.only(bottom: i + 2 < kids.length ? 8 : 0),
            child: Row(children: [
              Expanded(child: kids[i]),
              const SizedBox(width: 8),
              Expanded(child: i + 1 < kids.length ? kids[i + 1] : const SizedBox.shrink()),
            ]),
          ),
      ]),
    );

/// Bandeau « À faire maintenant » : une ligne par chose qui attend ma réponse (rouge pour un vendeur, ambre pour un acheteur) ; vert quand tout est à jour.
Widget _todoBox(AppColors c, {required Color color, required List<Widget> rows, required String allDone}) {
  if (rows.isEmpty) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: c.primary.withOpacity(0.10), borderRadius: BorderRadius.circular(14), border: Border.all(color: c.primary.withOpacity(0.4))),
      child: Row(children: [Icon(Icons.check_circle_rounded, color: c.primary, size: 20), const SizedBox(width: 10), Expanded(child: Text(allDone, style: TextStyle(color: c.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)))]),
    );
  }
  return Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
    decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withOpacity(0.6))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Icon(Icons.notifications_active_rounded, color: color, size: 19), const SizedBox(width: 8), Text(tr('À faire maintenant'), style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w800))]),
      const SizedBox(height: 4),
      ...rows,
    ]),
  );
}

Widget _todoRow(AppColors c, Color color, String text, {String? sub, VoidCallback? onTap, String? action}) => InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(text, style: TextStyle(color: c.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
              if (sub != null) Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textSecondary, fontSize: 11.5)),
            ]),
          ),
          if (action != null) Text(action, style: TextStyle(color: color, fontSize: 12.5, fontWeight: FontWeight.w800)),
          Icon(Icons.chevron_right_rounded, color: color, size: 20),
        ]),
      ),
    );

/// 14 barres (une par jour) pour les ventes ou les dépenses.
Widget _bars(AppColors c, List<Map> days, String key) {
  final max = days.fold<num>(1, (m, e) => ((e[key] as num?) ?? 0) > m ? (e[key] as num) : m);
  return SizedBox(
    height: 46,
    child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      for (final e in days)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1.5),
            child: Tooltip(
              message: '${e['day']} : ${_f((e[key] as num?) ?? 0)}',
              child: Container(height: 4 + 42 * (((e[key] as num?) ?? 0) / max), decoration: BoxDecoration(color: ((e[key] as num?) ?? 0) > 0 ? c.primary : c.border, borderRadius: BorderRadius.circular(3))),
            ),
          ),
        ),
    ]),
  );
}

/// Tableau de bord du VENDEUR : ce qui attend ma réponse, les étapes de mes ventes, mes offres et mes codes promo, puis mes chiffres (argent, 14 jours, meilleurs produits).
class SellerDashboard extends StatelessWidget {
  const SellerDashboard({super.key, required this.counts, required this.onStatus, required this.onOffers, required this.onPromos});

  final Map<String, dynamic> counts;
  final void Function(String status) onStatus;
  final VoidCallback onOffers;
  final VoidCallback onPromos;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final pending = _st(counts, 'seller', 'pending_seller');
    final disputes = _st(counts, 'seller', 'disputed');
    final offers = _i((counts['offers'] as Map?)?['seller']);
    final promos = (counts['promos'] as Map?) ?? const {};
    return Column(key: const ValueKey('seller_dashboard'), crossAxisAlignment: CrossAxisAlignment.start, children: [
      _todoBox(c, color: c.danger, allDone: tr('Tout est à jour : rien n\'attend ta réponse.'), rows: [
        if (pending > 0) _todoRow(c, c.danger, tr('{n} commande(s) à valider', {'n': pending}), sub: tr('Valide ou annule chacune : l\'acheteur attend.'), onTap: () => onStatus('pending_seller')),
        if (offers > 0) _todoRow(c, c.danger, tr('{n} offre(s) à répondre', {'n': offers}), onTap: onOffers),
        if (disputes > 0) _todoRow(c, c.danger, tr('{n} litige(s) à suivre', {'n': disputes}), onTap: () => onStatus('disputed')),
      ]),
      _grid2([
        _tile(c, tr('À valider'), pending, () => onStatus('pending_seller'), alert: true, icon: Icons.hourglass_top_rounded),
        _tile(c, tr('En préparation'), _st(counts, 'seller', 'accepted'), () => onStatus('accepted'), icon: Icons.inventory_2_outlined),
        _tile(c, tr('En livraison'), _st(counts, 'seller', 'shipped'), () => onStatus('shipped'), icon: Icons.local_shipping_outlined),
        _tile(c, tr('Terminées'), _st(counts, 'seller', 'completed'), () => onStatus('completed'), icon: Icons.check_circle_outline_rounded),
        _tile(c, tr('Offres'), offers, onOffers, alert: true, sub: tr('à répondre'), icon: Icons.handshake_outlined),
        _tile(c, tr('Codes promo'), _i(promos['active']), onPromos, sub: '${_i(promos['uses'])} ${tr('utilisations')} · ${_i(promos['linked'])} ${tr('liés à un produit')}', icon: Icons.local_offer_outlined),
      ]),
      const SellerStatsCard(),
    ]);
  }
}

/// Tableau de bord de l'ACHETEUR : argent protégé, ce que je dois faire, les étapes de mes achats, mes offres, mes dépenses et mes vendeurs habituels.
class BuyerDashboard extends StatelessWidget {
  const BuyerDashboard({super.key, required this.counts, required this.stats, required this.onStatus, required this.onTodo, required this.onOffers});

  final Map<String, dynamic> counts;
  final Map<String, dynamic>? stats;
  final void Function(String status) onStatus;
  final VoidCallback onTodo;
  final VoidCallback onOffers;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final s = stats ?? const <String, dynamic>{};
    final actions = ((s['next_actions'] as List?) ?? const []).whereType<Map>().toList();
    final offers = _i((counts['offers'] as Map?)?['buyer']);
    final toRate = _i((counts['buyer'] as Map?)?['to_rate']);
    final days = ((s['by_day'] as List?) ?? const []).whereType<Map>().toList();
    final sellers = ((s['top_sellers'] as List?) ?? const []).whereType<Map>().toList();
    String what(String st) => switch (st) {
          'pending_buyer' => tr('Frais de livraison à accepter'),
          'shipped' => tr('Confirme la réception'),
          _ => tr('Note ton achat'),
        };
    String act(String st) => switch (st) { 'to_rate' => tr('Noter'), _ => tr('Ouvrir') };
    return Column(key: const ValueKey('buyer_dashboard'), crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(tr('Commandes en cours'), style: TextStyle(color: c.textSecondary, fontSize: 11.5)), Text('${_i(s['in_progress'])}', style: TextStyle(color: c.textPrimary, fontSize: 22, fontWeight: FontWeight.w800))])),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(tr('Argent protégé'), style: TextStyle(color: c.textSecondary, fontSize: 11.5)), Text(_f(_i(s['in_escrow_xof'])), style: TextStyle(color: c.primary, fontSize: 22, fontWeight: FontWeight.w800))])),
          ]),
          const SizedBox(height: 6),
          Text(tr('Ton argent est gardé en sécurité jusqu\'à la réception de tes commandes. Dépensé ces 30 jours : {f}.', {'f': _f(_i(s['spent_30d_xof']))}), style: TextStyle(color: c.textSecondary, fontSize: 11.5, height: 1.3)),
        ]),
      ),
      _todoBox(c, color: c.warning, allDone: tr('Rien à faire pour le moment : tes commandes avancent.'), rows: [
        for (final a in actions)
          _todoRow(c, c.warning, what('${a['status']}'), sub: '${a['title']} · @${(a['seller'] as Map?)?['username'] ?? ''}', onTap: onTodo, action: act('${a['status']}')),
      ]),
      _grid2([
        _tile(c, tr('Envoyées'), _st(counts, 'buyer', 'pending_seller'), () => onStatus('pending_seller'), icon: Icons.send_outlined),
        _tile(c, tr('Validées'), _st(counts, 'buyer', 'accepted'), () => onStatus('accepted'), icon: Icons.inventory_2_outlined),
        _tile(c, tr('Expédiées'), _st(counts, 'buyer', 'shipped'), () => onStatus('shipped'), alert: true, color: c.warning, icon: Icons.local_shipping_outlined),
        _tile(c, tr('Reçues'), _st(counts, 'buyer', 'completed'), () => onStatus('completed'), icon: Icons.check_circle_outline_rounded),
        _tile(c, tr('Offres'), offers, onOffers, alert: true, color: c.warning, sub: tr('contre-proposition(s)'), icon: Icons.handshake_outlined),
        _tile(c, tr('À noter'), toRate, null, alert: true, color: c.warning, sub: tr('achat(s) terminé(s)'), icon: Icons.star_outline_rounded),
      ]),
      if (_i(s['orders']) > 0)
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tr('Mes dépenses · 14 jours'), style: TextStyle(color: c.textSecondary, fontSize: 11.5)),
            const SizedBox(height: 6),
            _bars(c, days, 'spent_xof'),
            if (sellers.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(tr('Mes vendeurs habituels'), style: TextStyle(color: c.textSecondary, fontSize: 11.5)),
              for (final v in sellers)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(children: [
                    Expanded(child: Text('@${v['username']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textPrimary, fontSize: 13, fontWeight: FontWeight.w700))),
                    Text('${_i(v['orders'])} ${tr('commandes')} · ${_f(_i(v['spent_xof']))}', style: TextStyle(color: c.textSecondary, fontSize: 12)),
                  ]),
                ),
            ],
          ]),
        ),
    ]);
  }
}

/// Vue d'ensemble : un coup d'œil sur les trois catégories (achats, ventes, offres) avant les onglets ; chaque colonne ouvre son onglet.
class OrdersOverview extends StatelessWidget {
  const OrdersOverview({super.key, required this.counts, required this.buyerStats, required this.sellerStats, required this.onTab});

  final Map<String, dynamic> counts;
  final Map<String, dynamic>? buyerStats;
  final Map<String, dynamic>? sellerStats;
  final void Function(int tab) onTab;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final buyTodo = _i((counts['buyer'] as Map?)?['todo']);
    final buyProg = _i((counts['buyer'] as Map?)?['progress']);
    final sellTodo = _i((counts['seller'] as Map?)?['todo']);
    final sellProg = _i((counts['seller'] as Map?)?['progress']);
    final offers = _i((counts['offers'] as Map?)?['seller']) + _i((counts['offers'] as Map?)?['buyer']);
    final total = _i(counts['total']);
    Widget col(IconData icon, String title, int todo, String second, String money, int tab, {bool last = false}) => Expanded(
          child: InkWell(
            onTap: () => onTab(tab),
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
              decoration: BoxDecoration(border: last ? null : Border(right: BorderSide(color: c.border))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [Icon(icon, size: 14, color: c.textSecondary), const SizedBox(width: 4), Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textSecondary, fontSize: 11.5, fontWeight: FontWeight.w700)))]),
                Text('$todo', style: TextStyle(color: todo > 0 ? c.danger : c.textPrimary, fontSize: 22, fontWeight: FontWeight.w900, height: 1.15)),
                Text(tr('à traiter'), style: TextStyle(color: todo > 0 ? c.danger : c.textSecondary, fontSize: 10.5, fontWeight: FontWeight.w700)),
                Text(second, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textSecondary, fontSize: 10.5)),
                if (money.isNotEmpty) Text(money, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.primary, fontSize: 10.5, fontWeight: FontWeight.w800)),
              ]),
            ),
          ),
        );
    return Container(
      key: const ValueKey('orders_overview'),
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: total > 0 ? c.danger.withOpacity(0.55) : c.border, width: total > 0 ? 1.4 : 1)),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Row(children: [
            Expanded(child: Text(tr('Vue d\'ensemble'), style: TextStyle(color: c.textPrimary, fontSize: 13, fontWeight: FontWeight.w800))),
            if (total > 0)
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: c.danger, borderRadius: BorderRadius.circular(99)), child: Text(tr('{n} à traiter', {'n': total}), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)))
            else
              Text(tr('Tout est à jour'), style: TextStyle(color: c.primary, fontSize: 11.5, fontWeight: FontWeight.w700)),
          ]),
        ),
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            col(Icons.shopping_bag_outlined, tr('Achats'), buyTodo, tr('{n} en cours', {'n': buyProg}), _i(buyerStats?['in_escrow_xof']) > 0 ? tr('{f} protégés', {'f': _f(_i(buyerStats?['in_escrow_xof']))}) : '', 0),
            col(Icons.storefront_outlined, tr('Ventes'), sellTodo, tr('{n} en cours', {'n': sellProg}), _i(sellerStats?['received_xof']) > 0 ? tr('{f} reçus', {'f': _f(_i(sellerStats?['received_xof']))}) : '', 1),
            col(Icons.handshake_outlined, tr('Offres'), offers, tr('à répondre'), '', 2, last: true),
          ]),
        ),
      ]),
    );
  }
}
