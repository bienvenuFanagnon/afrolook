import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/tr.dart';
import '../../services/api/live_shop_api.dart';
import '../../theme/app_colors.dart';
import 'delivery_rates_page.dart';
import 'promo_codes_page.dart';
import 'live_sales_card.dart';
import 'orders_dashboards.dart';
import 'order_notifications_page.dart';
import 'seller_badge.dart';
import '../../services/api/chat_api.dart';

/// « Mes commandes » du Live Shopping : achats, ventes et négociations, avec les actions de chaque étape
/// (valider, expédier, confirmer la réception, annuler, signaler un problème). L'argent de l'acheteur est protégé (séquestre) jusqu'à la réception.
class LiveShopOrdersPage extends StatefulWidget {
  const LiveShopOrdersPage({super.key});

  @override
  State<LiveShopOrdersPage> createState() => _LiveShopOrdersPageState();
}

/// Une liste de commandes lue page par page (un vendeur peut en avoir des centaines), avec son filtre et sa recherche.
class _Feed {
  String? group;
  String? status;   // étape exacte (tuile du tableau de bord) : en préparation, en livraison…
  String q = '';
  List<Map<String, dynamic>> items = [];
  bool more = true;
  bool loading = false;
}

class _LiveShopOrdersPageState extends State<LiveShopOrdersPage> with TickerProviderStateMixin {
  static final NumberFormat _n = NumberFormat.decimalPattern('fr');
  static const _pageSize = 30;

  late final TabController _tabs = TabController(length: 3, vsync: this);
  final _buyFeed = _Feed();
  final _sellFeed = _Feed();
  final _sellSearch = TextEditingController();
  Timer? _debounce;
  bool _loading = true;
  bool _firstLoad = true;
  String? _error;
  Map<String, dynamic> _counts = const {};
  Map<String, dynamic>? _buyerStats;
  Map<String, dynamic>? _sellerStats;
  int _notifUnread = 0;   // notifications de commandes non lues (pastille de la cloche)
  List<Map<String, dynamic>> _offersBuy = const [];
  List<Map<String, dynamic>> _offersSell = const [];

  int _count(String role, String k) => ((_counts[role] as Map?)?[k] as num?)?.toInt() ?? 0;

  /// Négociations qui attendent MA réponse (vendeur : offre ouverte ; acheteur : contre-proposition reçue).
  int get _offersTodo => _offersSell.where((o) => '${o['status']}' == 'open').length + _offersBuy.where((o) => '${o['status']}' == 'countered').length;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _sellSearch.dispose();
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _fetch(String role, _Feed f, {bool reset = true}) async {
    final off = reset ? 0 : f.items.length;
    final r = await LiveShopApi.orders(role: role, group: f.group, status: f.status, q: f.q, offset: off, limit: _pageSize);
    f.items = reset ? r : [...f.items, ...r];
    f.more = r.length >= _pageSize;
  }

  Future<void> _load() async {
    if (_firstLoad) setState(() { _loading = true; _error = null; });
    try {
      final head = await Future.wait([LiveShopApi.orderCounts(), LiveShopApi.offers(role: 'buyer'), LiveShopApi.offers(role: 'seller')]);
      _counts = head[0] as Map<String, dynamic>;
      _offersBuy = head[1] as List<Map<String, dynamic>>;
      _offersSell = head[2] as List<Map<String, dynamic>>;
      try {
        _buyerStats = await LiveShopApi.buyerStats();
      } catch (_) {}   // le tableau de bord de l'acheteur ne bloque jamais la liste
      try {
        _sellerStats = await LiveShopApi.sellerStats();
      } catch (_) {}
      _loadNotifCount();
      if (_firstLoad) {
        // ce qui est prioritaire s'affiche en premier : les ventes à traiter, puis mes achats à faire, puis les offres, sinon ce qui est en cours
        final sTodo = _count('seller', 'todo'), bTodo = _count('buyer', 'todo'), sProg = _count('seller', 'progress'), bProg = _count('buyer', 'progress');
        _sellFeed.group = sTodo > 0 ? 'todo' : (sProg > 0 ? 'progress' : null);
        _buyFeed.group = bTodo > 0 ? 'todo' : (bProg > 0 ? 'progress' : null);
        _tabs.index = sTodo > 0 ? 1 : (bTodo > 0 ? 0 : (_offersTodo > 0 ? 2 : (sProg > 0 ? 1 : 0)));
      }
      await Future.wait([_fetch('buyer', _buyFeed), _fetch('seller', _sellFeed)]);
      if (!mounted) return;
      setState(() { _loading = false; _firstLoad = false; });
    } catch (e) {
      if (mounted) setState(() { _error = LiveShopApi.message(e); _loading = false; });
    }
  }

  Future<void> _loadNotifCount() async {
    try {
      final m = await ChatApi.unreadCountsByType();
      final n = kOrderNotifTypes.fold<int>(0, (a, t) => a + (m[t] ?? 0));
      if (mounted && n != _notifUnread) setState(() => _notifUnread = n);
    } catch (_) {}
  }

  /// Page des notifications de commandes ; en revenant on ouvre la bonne liste (ventes à traiter, achats ou offres).
  Future<void> _openNotifs() async {
    final r = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const OrderNotificationsPage()));
    _loadNotifCount();
    if (r == 'sell') {
      _openSell(group: 'todo');
    } else if (r == 'buy') {
      _openBuy(group: 'todo');
    } else if (r == 'offers') {
      _tabs.animateTo(2);
    }
  }

  Future<void> _reloadFeed(String role) async {
    final f = role == 'seller' ? _sellFeed : _buyFeed;
    setState(() => f.loading = true);
    try {
      await _fetch(role, f);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(LiveShopApi.message(e))));
    }
    if (mounted) setState(() => f.loading = false);
  }

  Future<void> _more(String role) async {
    final f = role == 'seller' ? _sellFeed : _buyFeed;
    if (f.loading) return;
    setState(() => f.loading = true);
    try {
      await _fetch(role, f, reset: false);
    } catch (_) {}
    if (mounted) setState(() => f.loading = false);
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

  /// « il y a 12 min », « il y a 3 h », « il y a 2 j ».
  String _age(Object? iso) {
    final d = DateTime.tryParse('$iso')?.toLocal();
    if (d == null) return '';
    final m = DateTime.now().difference(d).inMinutes;
    if (m < 1) return tr("à l'instant");
    if (m < 60) return tr('il y a {n} min', {'n': m});
    if (m < 1440) return tr('il y a {n} h', {'n': m ~/ 60});
    return tr('il y a {n} j', {'n': m ~/ 1440});
  }

  /// Qui a commandé (vendeur : le pseudo de l'acheteur) ou chez qui j'ai commandé (acheteur), et depuis quand.
  Widget _personRow(AppColors c, Map<String, dynamic> o, bool seller, bool mine) {
    final p = (seller ? o['buyer'] : o['seller']) as Map?;
    final name = '${p?['username'] ?? p?['display_name'] ?? ''}';
    final url = '${p?['avatar_url'] ?? ''}';
    final minutes = DateTime.now().difference(DateTime.tryParse('${o['created_at']}') ?? DateTime.now()).inMinutes;
    final late = seller && '${o['status']}' == 'pending_seller' && minutes >= 60;   // une commande qui attend depuis plus d'une heure
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: c.border,
          backgroundImage: url.isNotEmpty ? NetworkImage(url) : null,
          onBackgroundImageError: url.isNotEmpty ? (_, __) {} : null,
          child: url.isEmpty ? Text(name.isEmpty ? '?' : name.substring(0, 1).toUpperCase(), style: TextStyle(color: c.textPrimary, fontSize: 12, fontWeight: FontWeight.w800)) : null,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Row(children: [
            Flexible(
              child: Text(
                name.isEmpty ? (seller ? tr('Un acheteur') : tr('Le vendeur')) : (seller ? tr('@{p} a commandé', {'p': name}) : tr('Chez @{p}', {'p': name})),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
            if (p?['verified'] == true) const Padding(padding: EdgeInsets.only(left: 5), child: SellerVerifiedBadge(compact: true)),
          ]),
        ),
        Text(_age(o['created_at']), style: TextStyle(color: late ? c.danger : c.textSecondary, fontSize: 11.5, fontWeight: late ? FontWeight.w800 : FontWeight.w500)),
      ]),
    );
  }

  /// Les étapes d'une commande côté acheteur : Envoyée → Validée → Expédiée → Reçue, et ce qu'il doit faire maintenant.
  Widget _stepper(AppColors c, String s) {
    final idx = switch (s) { 'pending_seller' => 0, 'pending_buyer' => 1, 'accepted' => 1, 'shipped' => 2, 'completed' => 3, _ => -1 };
    if (idx < 0) return const SizedBox.shrink();
    final labels = [tr('Envoyée'), tr('Validée'), tr('Expédiée'), tr('Reçue')];
    final mine = s == 'pending_buyer' || s == 'shipped';
    final hint = switch (s) {
      'pending_seller' => tr('Le vendeur doit valider ta commande.'),
      'pending_buyer' => tr('À toi : accepte ou refuse les frais de livraison.'),
      'accepted' => tr('Le vendeur prépare ta commande.'),
      'shipped' => tr("Ta commande est en route : confirme la réception quand tu l'as."),
      _ => tr('Commande terminée.'),
    };
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          for (var i = 0; i < 4; i++)
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i < 3 ? 4 : 0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(height: 6, decoration: BoxDecoration(color: i < idx ? c.primary : (i == idx ? (mine ? c.warning : c.primary) : c.border), borderRadius: BorderRadius.circular(99))),
                  const SizedBox(height: 3),
                  Text(labels[i], style: TextStyle(color: i <= idx ? c.textPrimary : c.textSecondary, fontSize: 10.5, fontWeight: i == idx ? FontWeight.w800 : FontWeight.w500)),
                ]),
              ),
            ),
        ]),
        const SizedBox(height: 4),
        Text(hint, style: TextStyle(color: mine ? c.warning : c.textSecondary, fontSize: 12, fontWeight: mine ? FontWeight.w800 : FontWeight.w500)),
      ]),
    );
  }

  /// Pastille rouge d'un compteur (onglets).
  Widget _dot(AppColors c, int n) => n <= 0
      ? const SizedBox.shrink()
      : Container(
          margin: const EdgeInsets.only(left: 6),
          constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
          padding: const EdgeInsets.symmetric(horizontal: 5),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: const Color(0xFFE53935), borderRadius: BorderRadius.circular(99)),
          child: Text(n > 99 ? '99+' : '$n', style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800)),
        );

  /// Filtres d'étape d'une liste (le compteur ne s'affiche que pour ce qui attend ma réponse ou ce qui est en cours).
  Widget _filters(AppColors c, String role, _Feed f) {
    final seller = role == 'seller';
    Widget chip(String label, String? group, int n) {
      final on = f.group == group && f.status == null;
      return ChoiceChip(
        selected: on,
        label: Text(n > 0 ? '$label ($n)' : label),
        labelStyle: TextStyle(color: on ? c.onPrimary : c.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w700),
        selectedColor: group == 'todo' && n > 0 ? (seller ? c.danger : c.warning) : c.primary,
        backgroundColor: c.surface,
        side: BorderSide(color: c.border),
        showCheckmark: false,
        onSelected: (_) {
          if (f.group == group && f.status == null) return;
          f.group = group;
          f.status = null;
          _reloadFeed(role);
        },
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Wrap(spacing: 8, runSpacing: 4, children: [
        chip(seller ? tr('À traiter') : tr('À faire'), 'todo', _count(role, 'todo')),
        chip(tr('En cours'), 'progress', _count(role, 'progress')),
        chip(tr('Terminées'), 'done', 0),
        chip(tr('Toutes'), null, 0),
        if (f.status != null)
          InputChip(
            label: Text(_statusLabel(f.status!), style: TextStyle(color: c.onPrimary, fontSize: 12.5, fontWeight: FontWeight.w700)),
            backgroundColor: c.primary,
            deleteIconColor: c.onPrimary,
            onDeleted: () {
              f.status = null;
              _reloadFeed(role);
            },
          ),
      ]),
    );
  }

  // ── Tableau de bord : tout d'un coup d'œil, chaque tuile ouvre la bonne liste ──

  int _status(String role, String st) => ((_counts['${role}_status'] as Map?)?[st] as num?)?.toInt() ?? 0;

  void _openSell({String? group, String? status}) {
    _sellFeed.group = status != null ? null : group;
    _sellFeed.status = status;
    _sellSearch.clear();
    _sellFeed.q = '';
    _tabs.animateTo(1);
    _reloadFeed('seller');
  }

  void _openBuy({String? group, String? status}) {
    _buyFeed.group = status != null ? null : group;
    _buyFeed.status = status;
    _tabs.animateTo(0);
    _reloadFeed('buyer');
  }

  /// Bandeau du haut : ce qui attend ma réponse (rouge pour un vendeur, ambre pour un acheteur).
  Widget _banner(AppColors c, bool seller) {
    final todo = _count(seller ? 'seller' : 'buyer', 'todo');
    final rate = seller ? 0 : _count('buyer', 'to_rate');
    if (todo == 0 && rate == 0) return const SizedBox.shrink();
    final color = seller ? c.danger : c.warning;
    final text = seller
        ? tr('{n} commande(s) attendent ta réponse : valide ou annule chacune.', {'n': todo})
        : [
            if (todo > 0) tr('{n} commande(s) attendent ta réponse : accepte les frais ou confirme la réception.', {'n': todo}),
            if (rate > 0) tr('{n} achat(s) à noter.', {'n': rate}),
          ].join(' ');
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withOpacity(0.6))),
      child: Row(children: [
        Icon(Icons.notifications_active_rounded, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: TextStyle(color: c.textPrimary, fontSize: 13, fontWeight: FontWeight.w700, height: 1.3))),
      ]),
    );
  }

  /// Liste des achats ou des ventes : en-tête (bandeau, recherche, filtres), cartes lues page par page, « Voir plus ».
  Widget _feedList(AppColors c, bool seller) {
    final role = seller ? 'seller' : 'buyer';
    final f = seller ? _sellFeed : _buyFeed;
    final header = <Widget>[
      if (seller)
        SellerDashboard(counts: _counts, onStatus: (st) => _openSell(status: st), onOffers: () => _tabs.animateTo(2), onPromos: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PromoCodesPage())).then((_) => _load()))
      else
        BuyerDashboard(counts: _counts, stats: _buyerStats, onStatus: (st) => _openBuy(status: st), onTodo: () => _openBuy(group: 'todo'), onOffers: () => _tabs.animateTo(2)),
      if (seller)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: TextField(
            key: const ValueKey('orders_search'),
            controller: _sellSearch,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: tr('Chercher un acheteur (@pseudo)'),
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: f.q.isEmpty ? null : IconButton(icon: const Icon(Icons.close_rounded), onPressed: () { _sellSearch.clear(); f.q = ''; _reloadFeed(role); }),
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onChanged: (v) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 450), () {
                if (v.trim() == f.q) return;
                f.q = v.trim();
                _reloadFeed(role);
              });
            },
          ),
        ),
      _filters(c, role, f),
    ];
    final empty = f.items.isEmpty;
    final count = header.length + f.items.length + 1;
    return RefreshIndicator(
      color: c.primary,
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        itemCount: count,
        itemBuilder: (ctx, i) {
          if (i < header.length) return header[i];
          final k = i - header.length;
          if (k < f.items.length) return _card(c, f.items[k], seller: seller);
          if (f.loading) return Padding(padding: const EdgeInsets.all(20), child: Center(child: CircularProgressIndicator(color: c.primary)));
          if (empty) {
            final msg = f.q.isNotEmpty
                ? tr('Aucune commande pour ce pseudo.')
                : f.group == 'todo'
                    ? (seller ? tr('Rien à traiter : bravo !') : tr('Rien à faire pour le moment.'))
                    : (seller ? tr('Aucune vente pour le moment.') : tr('Aucun achat pour le moment.'));
            return Padding(padding: const EdgeInsets.all(32), child: Center(child: Text(msg, textAlign: TextAlign.center, style: TextStyle(color: c.textSecondary))));
          }
          if (f.more) return Center(child: TextButton(onPressed: () => _more(role), child: Text(tr('Voir plus de commandes'))));
          return const SizedBox.shrink();
        },
      ),
    );
  }

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

    // ce qui attend MA réponse est mis en évidence (rouge côté vendeur, ambre côté acheteur)
    final mine = seller ? s == 'pending_seller' : (s == 'pending_buyer' || s == 'shipped');
    final alert = seller ? c.danger : c.warning;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: mine ? alert : c.border, width: mine ? 1.6 : 1)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _personRow(c, o, seller, mine),
        Row(children: [
          Expanded(child: Text('${o['title']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 15))),
          const SizedBox(width: 8),
          _chip(c, s),
        ]),
        if (!seller) _stepper(c, s),
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
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.surface,
        foregroundColor: c.textPrimary,
        title: Text(tr('Mes commandes')),
        actions: [
          IconButton(
            key: const ValueKey('orders_notifs_bell'),
            tooltip: tr('Notifications de commandes'),
            icon: Stack(clipBehavior: Clip.none, children: [
              const Icon(Icons.notifications_none_rounded),
              if (_notifUnread > 0)
                Positioned(
                  top: -4,
                  right: -5,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: const Color(0xFFE53935), borderRadius: BorderRadius.circular(99)),
                    child: Text(_notifUnread > 99 ? '99+' : '$_notifUnread', style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w800)),
                  ),
                ),
            ]),
            onPressed: _openNotifs,
          ),
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
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: c.primary))
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: c.textSecondary)), TextButton(onPressed: _load, child: Text(tr('Réessayer')))])))
              : Column(children: [
                  OrdersOverview(counts: _counts, buyerStats: _buyerStats, sellerStats: _sellerStats, onTab: (t) => _tabs.animateTo(t)),
                  Material(
                    color: c.surface,
                    child: TabBar(
                      controller: _tabs,
                      labelColor: c.primary,
                      unselectedLabelColor: c.textSecondary,
                      indicatorColor: c.primary,
                      tabs: [
                        Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [Text(tr('Achats')), _dot(c, _count('buyer', 'todo'))])),
                        Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [Text(tr('Ventes')), _dot(c, _count('seller', 'todo'))])),
                        Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [Text(tr('Offres')), _dot(c, _offersTodo)])),
                      ],
                    ),
                  ),
                  Expanded(
                    child: TabBarView(controller: _tabs, children: [
                      _feedList(c, false),
                      _feedList(c, true),
                      _list(c, [for (final o in _offersSell) _offerCard(c, o, seller: true), for (final o in _offersBuy) _offerCard(c, o, seller: false)], tr('Aucune négociation pour le moment.')),
                    ]),
                  ),
                ]),
    );
  }
}
