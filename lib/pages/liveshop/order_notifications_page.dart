import 'package:flutter/material.dart';

import '../../l10n/tr.dart';
import '../../services/api/chat_api.dart';
import '../../theme/app_colors.dart';

/// Types de notification qui concernent les commandes, les ventes et les offres.
const List<String> kOrderNotifTypes = [
  'ORDER_NEW', 'ORDER_VALIDATED', 'ORDER_FEE', 'ORDER_SHIPPED', 'ORDER_RECEIVED', 'ORDER_CANCELLED', 'ORDER_DISPUTE', 'ORDER_RESOLVED',
  'ORDER_DELIVERED', 'ORDER_REVIEW', 'ORDER_REMIND', 'ORDER_REMIND_BUYER', 'OFFER_NEW', 'OFFER_REPLY', 'STOCK_LOW', 'STOCK_OUT',
];

/// Où ouvrir « Mes commandes » pour une notification : `sell` (ventes à traiter), `buy` (achats), `offers` (négociations).
String orderNotifTarget(String type) => switch (type) {
      'ORDER_NEW' || 'ORDER_REMIND' || 'ORDER_DISPUTE' || 'ORDER_DELIVERED' || 'ORDER_REVIEW' || 'STOCK_LOW' || 'STOCK_OUT' => 'sell',
      'OFFER_NEW' || 'OFFER_REPLY' => 'offers',
      _ => 'buy',
    };

/// Phrase française d'une notification de commande (le pseudo de l'autre personne et l'article sont ajoutés par la page).
String orderNotifText(String type) => switch (type) {
      'ORDER_NEW' => tr('{a} t\'a passé une commande : valide-la'),
      'ORDER_VALIDATED' => tr('{a} a validé ta commande'),
      'ORDER_FEE' => tr('{a} a fixé les frais de livraison : accepte-les ou refuse'),
      'ORDER_SHIPPED' => tr('{a} a expédié ta commande'),
      'ORDER_RECEIVED' => tr('{a} a confirmé la réception : l\'argent t\'est versé'),
      'ORDER_CANCELLED' => tr('{a} a annulé la commande'),
      'ORDER_DISPUTE' => tr('{a} a signalé un problème sur une commande'),
      'ORDER_RESOLVED' => tr('L\'équipe a tranché le litige d\'une commande'),
      'ORDER_DELIVERED' => tr('{a} a confirmé la livraison de ta commande'),
      'ORDER_REVIEW' => tr('{a} t\'a donné une note'),
      'ORDER_REMIND' => tr('Une commande attend ton action : réponds ou expédie-la'),
      'ORDER_REMIND_BUYER' => tr('As-tu reçu ta commande ? Confirme-la ou signale un problème'),
      'OFFER_NEW' => tr('{a} propose un prix sur ton article'),
      'OFFER_REPLY' => tr('{a} a répondu à ton offre'),
      'STOCK_LOW' => tr('Le stock d\'un de tes articles est bas'),
      'STOCK_OUT' => tr('Un de tes articles est épuisé'),
      _ => '{a}',
    };

IconData orderNotifIcon(String type) => switch (type) {
      'ORDER_NEW' => Icons.shopping_bag_outlined,
      'ORDER_VALIDATED' => Icons.check_circle_outline_rounded,
      'ORDER_FEE' => Icons.payments_outlined,
      'ORDER_SHIPPED' || 'ORDER_DELIVERED' => Icons.local_shipping_outlined,
      'ORDER_RECEIVED' => Icons.savings_outlined,
      'ORDER_CANCELLED' => Icons.cancel_outlined,
      'ORDER_DISPUTE' || 'ORDER_RESOLVED' => Icons.report_gmailerrorred_rounded,
      'ORDER_REVIEW' => Icons.star_outline_rounded,
      'ORDER_REMIND' || 'ORDER_REMIND_BUYER' => Icons.notifications_active_outlined,
      'OFFER_NEW' || 'OFFER_REPLY' => Icons.handshake_outlined,
      _ => Icons.inventory_2_outlined,
    };

/// Une notification qui attend une action de ma part (et non une simple information) : pastille rouge.
bool orderNotifNeedsAction(String type) => const {'ORDER_NEW', 'ORDER_FEE', 'ORDER_SHIPPED', 'ORDER_DISPUTE', 'ORDER_REMIND', 'ORDER_REMIND_BUYER', 'OFFER_NEW', 'OFFER_REPLY'}.contains(type);

/// Page « Notifications de commandes » : toutes les alertes de ventes, d'achats et d'offres au même endroit, les non lues d'abord marquées.
/// Toucher une ligne la marque comme lue et revient à « Mes commandes » sur la bonne liste (le résultat renvoyé est `sell`, `buy` ou `offers`).
class OrderNotificationsPage extends StatefulWidget {
  const OrderNotificationsPage({super.key});

  @override
  State<OrderNotificationsPage> createState() => _OrderNotificationsPageState();
}

class _OrderNotificationsPageState extends State<OrderNotificationsPage> {
  List<Map<String, dynamic>> _items = [];
  String? _next;
  bool _loading = true;
  bool _more = false;
  String? _error;
  bool _unreadOnly = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final r = await ChatApi.notifications(types: kOrderNotifTypes, unreadOnly: _unreadOnly);
      if (mounted) setState(() { _items = r.items; _next = r.next; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _error = tr('Impossible de charger tes notifications pour le moment.'); _loading = false; });
    }
  }

  Future<void> _loadMore() async {
    if (_next == null || _more) return;
    setState(() => _more = true);
    try {
      final r = await ChatApi.notifications(types: kOrderNotifTypes, unreadOnly: _unreadOnly, cursor: _next);
      if (mounted) setState(() { _items = [..._items, ...r.items]; _next = r.next; });
    } catch (_) {}
    if (mounted) setState(() => _more = false);
  }

  Future<void> _readAll() async {
    try {
      // seulement celles de commandes : on les marque une à une (le serveur n'a pas de « tout lire par type »)
      for (final n in _items.where((n) => n['is_read'] != true)) {
        await ChatApi.markNotificationRead('${n['id']}');
      }
    } catch (_) {}
    await _load();
  }

  String _age(Object? iso) {
    final d = DateTime.tryParse('$iso')?.toLocal();
    if (d == null) return '';
    final m = DateTime.now().difference(d).inMinutes;
    if (m < 1) return tr("à l'instant");
    if (m < 60) return tr('il y a {n} min', {'n': m});
    if (m < 1440) return tr('il y a {n} h', {'n': m ~/ 60});
    return tr('il y a {n} j', {'n': m ~/ 1440});
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final unread = _items.where((n) => n['is_read'] != true).length;
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.surface,
        foregroundColor: c.textPrimary,
        title: Text(tr('Notifications de commandes')),
        actions: [
          if (unread > 0) TextButton(onPressed: _readAll, child: Text(tr('Tout lire'))),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: Row(children: [
            ChoiceChip(label: Text(tr('Toutes')), selected: !_unreadOnly, onSelected: (_) { _unreadOnly = false; _load(); }),
            const SizedBox(width: 8),
            ChoiceChip(label: Text(tr('Non lues')), selected: _unreadOnly, onSelected: (_) { _unreadOnly = true; _load(); }),
          ]),
        ),
        Expanded(
          child: _loading
              ? Center(child: CircularProgressIndicator(color: c.primary))
              : _error != null
                  ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: c.textSecondary))))
                  : _items.isEmpty
                      ? Center(child: Padding(padding: const EdgeInsets.all(32), child: Text(_unreadOnly ? tr('Rien de non lu : tout est à jour.') : tr('Aucune notification de commande pour le moment.'), textAlign: TextAlign.center, style: TextStyle(color: c.textSecondary))))
                      : RefreshIndicator(
                          color: c.primary,
                          onRefresh: _load,
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                            itemCount: _items.length + (_next != null ? 1 : 0),
                            itemBuilder: (ctx, i) {
                              if (i >= _items.length) {
                                return Center(child: TextButton(onPressed: _loadMore, child: _more ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: c.primary)) : Text(tr('Voir plus'))));
                              }
                              return _row(c, _items[i]);
                            },
                          ),
                        ),
        ),
      ]),
    );
  }

  Widget _row(AppColors c, Map<String, dynamic> n) {
    final type = '${n['type']}'.toUpperCase();
    final read = n['is_read'] == true;
    final actor = n['actor'] as Map?;
    final name = actor == null ? '' : '@${actor['username'] ?? actor['display_name'] ?? ''}';
    final text = orderNotifText(type).replaceAll('{a}', name.isEmpty ? tr('Quelqu\'un') : name);
    final body = '${n['body'] ?? ''}'.trim();
    final action = !read && orderNotifNeedsAction(type);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () async {
        if (!read) ChatApi.markNotificationRead('${n['id']}').catchError((_) {});
        if (mounted) Navigator.of(context).pop(orderNotifTarget(type));
      },
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: read ? c.surface : c.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: action ? c.danger.withOpacity(0.6) : c.border, width: action ? 1.4 : 1),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: (action ? c.danger : c.primary).withOpacity(0.12), shape: BoxShape.circle),
            child: Icon(orderNotifIcon(type), size: 19, color: action ? c.danger : c.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(text, style: TextStyle(color: c.textPrimary, fontSize: 13.5, fontWeight: read ? FontWeight.w500 : FontWeight.w800, height: 1.3)),
              if (body.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2), child: Text(body, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textSecondary, fontSize: 12))),
              Padding(padding: const EdgeInsets.only(top: 3), child: Text(_age(n['created_at']), style: TextStyle(color: c.textSecondary, fontSize: 11))),
            ]),
          ),
          if (!read) Container(margin: const EdgeInsets.only(top: 4, left: 6), width: 9, height: 9, decoration: BoxDecoration(color: action ? c.danger : c.primary, shape: BoxShape.circle)),
        ]),
      ),
    );
  }
}
