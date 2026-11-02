import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../l10n/tr.dart';
import '../../providers/authProvider.dart';
import '../../services/api/live_shop_api.dart';
import 'package:afrolook_api_client/afrolook_api_client.dart' show ApiException;
import '../paiement/newDepot.dart';
import 'delivery_rates_page.dart';
import 'live_shop_orders_page.dart';

/// Vitrine d'un live de vente : les produits épinglés par le vendeur défilent en cartes (prix, ancien prix, stock, ventes, minuteur de vente flash).
/// Toucher une carte ouvre la fiche complète (photos, description, livraison). Le vendeur change ses produits et ses stocks PENDANT le live
/// (« Gérer ») ; le stock est visible par tout le monde et se met à jour toutes les 10 secondes. À placer dans le `Stack` de la page du live.
class LivePinnedProduct extends StatefulWidget {
  const LivePinnedProduct({super.key, required this.liveId, required this.isHost});

  final String liveId;
  final bool isHost;

  @override
  State<LivePinnedProduct> createState() => _LivePinnedProductState();
}

class _LivePinnedProductState extends State<LivePinnedProduct> {
  static final NumberFormat _n = NumberFormat.decimalPattern('fr');
  static const _gold = Color(0xFFF9A825);

  List<Map<String, dynamic>> _pins = const [];
  Timer? _poll;
  Timer? _tick;
  Timer? _auto;
  final ScrollController _scroll = ScrollController();
  DateTime _userTouch = DateTime.fromMillisecondsSinceEpoch(0);
  static const double _step = 232.0 + 8.0;   // largeur d'une carte + espace
  int _current = 0;

  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(const Duration(seconds: 10), (_) => _load());
    // défilement automatique : un produit après l'autre toutes les 4 secondes (il s'arrête 8 s dès que la personne touche la vitrine)
    _auto = Timer.periodic(const Duration(seconds: 4), (_) => _advance());
    _scroll.addListener(() {
      final i = _scroll.hasClients ? (_scroll.offset / _step).round() : 0;
      if (i != _current && mounted) setState(() => _current = i);
    });
    // minuteur des ventes flash : une seconde, seulement quand un produit en a un
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _pins.any((p) => _flashLeft(p) != null)) setState(() {});
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _tick?.cancel();
    _auto?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  /// Passe au produit suivant (et revient au premier après le dernier), sauf si la personne vient de faire défiler elle-même.
  void _advance() {
    if (!mounted || _pins.length < 2 || !_scroll.hasClients) return;
    if (DateTime.now().difference(_userTouch) < const Duration(seconds: 8)) return;
    final max = _scroll.position.maxScrollExtent;
    var next = _scroll.offset + _step;
    if (next > max + 1) next = 0;
    _scroll.animateTo(next, duration: const Duration(milliseconds: 650), curve: Curves.easeInOutCubic);
  }

  Future<void> _load() async {
    try {
      final r = await LiveShopApi.pins(widget.liveId);
      if (mounted) setState(() => _pins = r);
    } catch (_) {}   // jamais bloquant : le live continue sans la vitrine
  }

  String _f(num v) => '${_n.format(v)} F';

  void _say(String m) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  int? _stock(Map<String, dynamic> p) => (p['stock'] as num?)?.toInt();

  bool _soldOut(Map<String, dynamic> p) => (_stock(p) ?? 1) <= 0;

  /// Temps restant de la vente flash (null si aucune ou terminée).
  Duration? _flashLeft(Map<String, dynamic> p) {
    final until = DateTime.tryParse('${p['promo_until'] ?? ''}');
    if (until == null) return null;
    final left = until.difference(DateTime.now());
    return left.isNegative ? null : left;
  }

  String _clock(Duration d) {
    String two(int v) => v.toString().padLeft(2, '0');
    return d.inHours > 0 ? '${two(d.inHours)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}' : '${two(d.inMinutes)}:${two(d.inSeconds % 60)}';
  }

  /// Pastille de stock : visible du vendeur comme des spectateurs.
  Widget _stockBadge(Map<String, dynamic> p, {double size = 10.5}) {
    final s = _stock(p);
    final low = (p['stock_low'] as num?)?.toInt() ?? 3;
    if (s == null) return const SizedBox.shrink();
    final (String text, Color color) = s <= 0
        ? (tr('Épuisé'), Colors.redAccent)
        : s <= low
            ? (tr('Plus que {n}', {'n': s}), Colors.orangeAccent)
            : (tr('Stock : {n}', {'n': s}), Colors.greenAccent);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.18), borderRadius: BorderRadius.circular(99), border: Border.all(color: color.withOpacity(0.7))),
      child: Text(text, style: TextStyle(color: color, fontSize: size, fontWeight: FontWeight.w800)),
    );
  }

  // ── Vendeur : gérer la vitrine ──────────────────────────────────────────────────────

  Future<void> _addProduct() async {
    List<Map<String, dynamic>> mine;
    try {
      mine = await LiveShopApi.myArticles();
    } catch (e) {
      _say(LiveShopApi.message(e));
      return;
    }
    if (!mounted) return;
    final pinned = _pins.map((p) => '${p['id']}').toSet();
    final choices = mine.where((a) => !pinned.contains('${a['id']}')).toList();
    final chosen = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
          child: choices.isEmpty
              ? Padding(padding: const EdgeInsets.all(32), child: Text(tr("Tous tes produits sont déjà dans la vitrine, ou ta boutique est vide."), textAlign: TextAlign.center))
              : ListView(shrinkWrap: true, children: [
                  Padding(padding: const EdgeInsets.all(16), child: Text(tr('Ajouter un produit à la vitrine'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
                  for (final a in choices)
                    ListTile(
                      title: Text('${a['title']}', maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(_f((a['effective_price'] as num?) ?? (a['price'] as num?) ?? 0)),
                      trailing: a['live_sellable'] == true ? const Icon(Icons.shopping_bag_rounded) : Text(tr('Activer la vente directe'), style: const TextStyle(fontSize: 11)),
                      onTap: () => Navigator.pop(ctx, a),
                    ),
                ]),
        ),
      ),
    );
    if (chosen == null) return;
    try {
      if (chosen['live_sellable'] != true) await LiveShopApi.enableSelling('${chosen['id']}');
      final r = await LiveShopApi.pin(widget.liveId, '${chosen['id']}');
      if (mounted) setState(() => _pins = r);
    } catch (e) {
      _say(LiveShopApi.message(e));
    }
  }

  Future<void> _setStock(Map<String, dynamic> p, int? stock, void Function(void Function()) set) async {
    try {
      final r = await LiveShopApi.setStock('${p['id']}', stock);
      set(() => p['stock'] = r['stock']);
      if (mounted) setState(() {});
    } catch (e) {
      _say(LiveShopApi.message(e));
    }
  }

  Future<void> _manage() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.85),
            child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(16, 16, 16, 24), children: [
              Text(tr('Ma vitrine'), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
              const SizedBox(height: 2),
              Text(tr('Change tes produits et tes stocks pendant le live : les spectateurs voient tout de suite.'), style: const TextStyle(fontSize: 12.5)),
              const SizedBox(height: 12),
              if (_pins.isEmpty) Padding(padding: const EdgeInsets.all(24), child: Center(child: Text(tr('Aucun produit pour le moment.')))),
              for (final p in List<Map<String, dynamic>>.of(_pins))
                Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        ClipRRect(borderRadius: BorderRadius.circular(8), child: _image(p['image'] as String?, 48)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('${p['title']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                            Text('${_f((p['price_xof'] as num?) ?? 0)} · ${tr('{n} vendu(s)', {'n': (p['sold'] as num?)?.toInt() ?? 0})}', style: const TextStyle(fontSize: 12)),
                          ]),
                        ),
                        IconButton(
                          tooltip: tr('Retirer de la vitrine'),
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () async {
                            try {
                              final r = await LiveShopApi.unpin(widget.liveId, '${p['id']}');
                              set(() => _pins = r);
                              if (mounted) setState(() {});
                            } catch (e) {
                              _say(LiveShopApi.message(e));
                            }
                          },
                        ),
                      ]),
                      const SizedBox(height: 8),
                      Row(children: [
                        Text(tr('Stock'), style: const TextStyle(fontWeight: FontWeight.w700)),
                        const Spacer(),
                        IconButton(visualDensity: VisualDensity.compact, icon: const Icon(Icons.remove_circle_outline), onPressed: (_stock(p) ?? 0) <= 0 ? null : () => _setStock(p, (_stock(p) ?? 1) - 1, set)),
                        GestureDetector(
                          onTap: () async {
                            final ctl = TextEditingController(text: '${_stock(p) ?? ''}');
                            final v = await showDialog<String>(
                              context: ctx,
                              builder: (d) => AlertDialog(
                                title: Text(tr('Quantité en stock')),
                                content: TextField(controller: ctl, keyboardType: TextInputType.number, autofocus: true, decoration: InputDecoration(helperText: tr('Laisse vide pour un stock illimité.'))),
                                actions: [TextButton(onPressed: () => Navigator.pop(d), child: Text(tr('Annuler'))), FilledButton(onPressed: () => Navigator.pop(d, ctl.text.trim()), child: Text(tr('Enregistrer')))],
                              ),
                            );
                            if (v == null) return;
                            await _setStock(p, v.isEmpty ? null : int.tryParse(v), set);
                          },
                          child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: Text(_stock(p)?.toString() ?? '∞', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900))),
                        ),
                        IconButton(visualDensity: VisualDensity.compact, icon: const Icon(Icons.add_circle_outline), onPressed: () => _setStock(p, (_stock(p) ?? 0) + 1, set)),
                        const SizedBox(width: 6),
                        _stockBadge(p),
                      ]),
                    ]),
                  ),
                ),
              OutlinedButton.icon(onPressed: () async { await _addProduct(); set(() {}); }, icon: const Icon(Icons.add_shopping_cart_rounded), label: Text(tr('Ajouter un produit'))),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: OutlinedButton.icon(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DeliveryRatesPage())), icon: const Icon(Icons.local_shipping_outlined), label: Text(tr('Mes tarifs de livraison')))),
                const SizedBox(width: 8),
                Expanded(child: OutlinedButton.icon(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LiveShopOrdersPage())), icon: const Icon(Icons.receipt_long_rounded), label: Text(tr('Mes commandes')))),
              ]),
            ]),
          ),
        ),
      ),
    );
    _load();
  }

  // ── Fiche complète d'un produit ─────────────────────────────────────────────────────

  Widget _image(String? url, double size, {BoxFit fit = BoxFit.cover}) => (url == null || url.isEmpty)
      ? Container(width: size, height: size, color: Colors.white12, child: const Icon(Icons.shopping_bag_rounded, color: Colors.white54))
      : CachedNetworkImage(imageUrl: url, width: size, height: size, fit: fit, errorWidget: (_, __, ___) => Container(width: size, height: size, color: Colors.white12));

  Future<void> _showDetail(Map<String, dynamic> p) async {
    final user = Provider.of<UserAuthProvider>(context, listen: false).loginUserData;
    final myCountry = '${user.countryData?['countryCode'] ?? ''}'.toUpperCase();
    final images = ((p['images'] as List?) ?? const []).map((e) => '$e').toList();
    if (images.isEmpty && (p['image'] as String?) != null) images.add(p['image'] as String);
    final delivery = (p['delivery'] is Map) ? Map<String, dynamic>.from(p['delivery'] as Map) : const <String, dynamic>{};
    final rates = ((delivery['rates'] as List?) ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    final page = PageController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.92),
            child: ListView(shrinkWrap: true, padding: const EdgeInsets.only(bottom: 20), children: [
              if (images.isNotEmpty)
                SizedBox(
                  height: 280,
                  child: Stack(children: [
                    PageView(controller: page, children: [for (final u in images) CachedNetworkImage(imageUrl: u, fit: BoxFit.cover, width: double.infinity)]),
                    if (images.length > 1)
                      Positioned(
                        bottom: 10,
                        left: 0,
                        right: 0,
                        child: Center(child: SmoothDots(controller: page, count: images.length)),
                      ),
                  ]),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${p['title']}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(_f((p['price_xof'] as num?) ?? 0), style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: scheme.primary)),
                    if ((p['original_price_xof'] as num?) != null && (p['original_price_xof'] as num) > ((p['price_xof'] as num?) ?? 0)) ...[
                      const SizedBox(width: 8),
                      Text(_f(p['original_price_xof'] as num), style: const TextStyle(decoration: TextDecoration.lineThrough, fontSize: 14)),
                    ],
                  ]),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 6, children: [
                    _stockBadge(p, size: 12),
                    if (((p['sold'] as num?)?.toInt() ?? 0) > 0) Chip(visualDensity: VisualDensity.compact, label: Text(tr('{n} vendu(s)', {'n': (p['sold'] as num).toInt()}))),
                    if (_flashLeft(p) != null) Chip(visualDensity: VisualDensity.compact, avatar: const Icon(Icons.bolt_rounded, size: 16, color: _gold), label: Text(tr('Vente flash : {t}', {'t': _clock(_flashLeft(p)!)}))),
                    if (p['negotiable'] == true) Chip(visualDensity: VisualDensity.compact, label: Text(tr('Prix négociable'))),
                    if (p['seller'] is Map && ((p['seller'] as Map)['rating'] != null))
                      Chip(visualDensity: VisualDensity.compact, avatar: const Icon(Icons.star_rounded, size: 16, color: _gold), label: Text('${(p['seller'] as Map)['rating']} (${(p['seller'] as Map)['reviews']} ${tr('avis')})')),
                    if (p['seller'] is Map && (p['seller'] as Map)['trusted'] == true)
                      Chip(visualDensity: VisualDensity.compact, avatar: const Icon(Icons.verified_rounded, size: 16, color: Colors.green), label: Text(tr('Vendeur fiable')))
                    else if (p['seller'] is Map && (p['seller'] as Map)['verified'] == true)
                      Chip(visualDensity: VisualDensity.compact, avatar: const Icon(Icons.verified_user_rounded, size: 16, color: Colors.green), label: Text(tr('Identité vérifiée'))),
                  ]),
                  if ('${p['description'] ?? ''}'.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(tr('Description'), style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text('${p['description']}', style: const TextStyle(height: 1.4)),
                  ],
                  const SizedBox(height: 16),
                  // Livraison : payée à la livraison, tarif fixé par le vendeur (il peut l'ajuster pour ta commande)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: scheme.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: scheme.primary.withOpacity(0.35))),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Icon(Icons.local_shipping_outlined, color: scheme.primary),
                        const SizedBox(width: 8),
                        Text(tr('Livraison'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                      ]),
                      const SizedBox(height: 6),
                      Text(tr("Elle se paie à la livraison, en plus du prix de l'article. Le vendeur fixe le tarif et peut l'ajuster pour ta commande : tu l'acceptes ou tu refuses, sans frais."), style: const TextStyle(fontSize: 12.5, height: 1.4)),
                      const SizedBox(height: 8),
                      if (rates.isEmpty)
                        Text(tr('Tarif à convenir avec le vendeur.'), style: const TextStyle(fontWeight: FontWeight.w700))
                      else
                        for (final r in rates)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(children: [
                              Expanded(child: Text(r['city'] == null ? '${r['country']}' : '${r['city']} (${r['country']})', style: TextStyle(fontWeight: '${r['country']}' == myCountry ? FontWeight.w800 : FontWeight.w500))),
                              Text(_f((r['fee_xof'] as num?) ?? 0), style: const TextStyle(fontWeight: FontWeight.w800)),
                            ]),
                          ),
                      const SizedBox(height: 6),
                      Text(tr("Ton argent est protégé : le vendeur n'est payé que lorsque tu confirmes la réception. Un problème ? Tu es remboursé."), style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  if (!widget.isHost)
                    Row(children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _soldOut(p) ? null : () { Navigator.pop(ctx); _buy(p); },
                          icon: const Icon(Icons.shopping_bag_rounded),
                          label: Text(_soldOut(p) ? tr('Épuisé') : tr('Acheter')),
                        ),
                      ),
                      if (p['negotiable'] == true && !_soldOut(p)) ...[
                        const SizedBox(width: 10),
                        OutlinedButton(onPressed: () { Navigator.pop(ctx); _negotiate(p); }, child: Text(tr('Négocier'))),
                      ],
                    ]),
                ]),
              ),
            ]),
          ),
        );
      },
    );
    page.dispose();
  }

  // ── Négocier, acheter ───────────────────────────────────────────────────────────────

  Future<void> _negotiate(Map<String, dynamic> p) async {
    final ctl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Propose ton prix')),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tr('Prix affiché : {f}', {'f': _f((p['price_xof'] as num?) ?? 0)})),
          TextField(controller: ctl, keyboardType: TextInputType.number, autofocus: true, decoration: InputDecoration(labelText: tr('Ton prix en F CFA'))),
          const SizedBox(height: 6),
          Text(tr('Le vendeur peut accepter, refuser ou te répondre avec un autre prix (3 propositions au plus).'), style: const TextStyle(fontSize: 12)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('Annuler'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('Envoyer'))),
        ],
      ),
    );
    final amount = int.tryParse(ctl.text.trim());
    if (ok != true || amount == null) return;
    try {
      final o = await LiveShopApi.offer('${p['id']}', amount, liveId: widget.liveId);
      _say(o['status'] == 'refused' ? tr('Le vendeur a refusé ce prix.') : tr('Offre envoyée. Suis la réponse dans « Mes commandes ».'));
    } catch (e) {
      _say(LiveShopApi.message(e));
    }
  }

  Future<void> _buy(Map<String, dynamic> p) async {
    final user = Provider.of<UserAuthProvider>(context, listen: false).loginUserData;
    final country = TextEditingController(text: '${user.countryData?['countryCode'] ?? ''}'.toUpperCase());
    final city = TextEditingController();
    final address = TextEditingController();
    final phone = TextEditingController(text: user.numeroDeTelephone ?? '');
    int? estimate;
    bool estimated = false;
    String? error;
    int? missing;   // montant manquant (FCFA) quand le solde ne suffit pas : bouton « Recharger »
    bool busy = false;
    int qty = 1;
    final promo = TextEditingController();
    int discount = 0;
    String? promoInfo;
    final articleId = '${p['id']}';
    final price = (p['price_xof'] as num?)?.toInt() ?? 0;
    final stock = _stock(p);
    final maxQty = stock == null ? 10 : stock.clamp(1, 10);

    Future<void> refreshEstimate(StateSetter set) async {
      try {
        final e = await LiveShopApi.estimate(articleId, country: country.text.trim(), city: city.text.trim());
        set(() { estimate = e; estimated = true; });
      } catch (_) {}
    }

    Future<void> submit(BuildContext ctx, StateSetter set) async {
      // vérifications avant l'envoi : le message dit précisément quoi corriger
      final problem = country.text.trim().length != 2
          ? tr('Indique le pays en 2 lettres (par exemple TG pour le Togo).')
          : city.text.trim().isEmpty
              ? tr('Indique ta ville.')
              : address.text.trim().length < 5
                  ? tr('Écris une adresse plus précise (5 caractères au moins).')
                  : phone.text.replaceAll(RegExp(r'[^0-9]'), '').length < 6
                      ? tr('Indique un numéro de téléphone valide, avec au moins 6 chiffres.')
                      : null;
      if (problem != null) {
        set(() => error = problem);
        return;
      }
      set(() { busy = true; error = null; missing = null; });
      try {
        await LiveShopApi.placeOrder(articleId: articleId, quantity: qty, country: country.text.trim().toUpperCase(), city: city.text.trim(), address: address.text.trim(), phone: phone.text.trim(), liveId: widget.liveId, promoCode: discount > 0 ? promo.text.trim() : null);
        if (ctx.mounted) Navigator.pop(ctx, true);
      } catch (e) {
        if (e is ApiException && e.code == 'insufficient_funds') {
          final m = (e.details['missing_xof'] as num?)?.toInt();
          set(() { busy = false; missing = m; error = tr('Il te manque {f} pour cette commande.', {'f': _f(m ?? 0)}); });
        } else {
          set(() { busy = false; error = LiveShopApi.message(e); });
        }
      }

    }

    final done = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(ctx).viewInsets.bottom),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${p['title']}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Row(children: [
                Text(_f(price * qty - discount), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                const Spacer(),
                IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: qty <= 1 ? null : () => set(() { qty--; discount = 0; promoInfo = null; })),
                Text('$qty', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: qty >= maxQty ? null : () => set(() { qty++; discount = 0; promoInfo = null; })),
              ]),
              if (stock != null) Padding(padding: const EdgeInsets.only(bottom: 6), child: Align(alignment: Alignment.centerLeft, child: _stockBadge(p, size: 12))),
              Row(children: [
                SizedBox(width: 90, child: TextField(controller: country, maxLength: 2, textCapitalization: TextCapitalization.characters, onChanged: (_) => refreshEstimate(set), decoration: InputDecoration(labelText: tr('Pays'), counterText: ''))),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: city, onChanged: (_) => refreshEstimate(set), decoration: InputDecoration(labelText: tr('Ville')))),
              ]),
              TextField(controller: address, decoration: InputDecoration(labelText: tr('Adresse de livraison'))),
              TextField(controller: phone, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: tr('Téléphone'))),
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Expanded(child: TextField(controller: promo, textCapitalization: TextCapitalization.characters, onChanged: (_) => set(() { discount = 0; promoInfo = null; }), decoration: InputDecoration(labelText: tr('Code promo (facultatif)')))),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: promo.text.trim().isEmpty
                      ? null
                      : () async {
                          try {
                            final r = await LiveShopApi.promoCheck(articleId, promo.text.trim(), quantity: qty);
                            set(() { discount = (r['discount_xof'] as num?)?.toInt() ?? 0; promoInfo = tr('Code {c} : -{f}', {'c': '${r['code']}', 'f': _f(discount)}); error = null; });
                          } catch (e) {
                            set(() { discount = 0; promoInfo = null; error = LiveShopApi.message(e); });
                          }
                        },
                  child: Text(tr('Appliquer')),
                ),
              ]),
              if (promoInfo != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(promoInfo!, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w700, fontSize: 12.5))),
              const SizedBox(height: 10),
              Text(
                estimated && estimate != null ? tr('Livraison estimée : {f}, payée à la livraison (le vendeur peut la modifier).', {'f': _f(estimate!)}) : tr('Livraison : à convenir, payée à la livraison.'),
                style: const TextStyle(fontSize: 12.5),
              ),
              const SizedBox(height: 4),
              Text(tr("Ton argent est protégé : le vendeur n'est payé que lorsque tu confirmes la réception. Un problème ? Tu es remboursé."), style: const TextStyle(fontSize: 12.5)),
              if (error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(error!, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w700))),
              if (missing != null && missing! > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.account_balance_wallet_rounded),
                      label: Text(tr('Recharger {f} et commander', {'f': _f(missing!)})),
                      onPressed: busy
                          ? null
                          : () async {
                              // recharge directe du montant manquant, puis la commande repart toute seule (rien à ressaisir)
                              await Navigator.push(ctx, MaterialPageRoute(builder: (_) => DepositScreen(defaultAmount: missing!.toDouble())));
                              if (ctx.mounted) await submit(ctx, set);
                            },
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: busy ? null : () => submit(ctx, set),
                  child: Text(tr('Commander · {f}', {'f': _f(price * qty - discount)})),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
    if (done == true && mounted) {
      _say(tr('Commande envoyée. Suis-la dans « Mes commandes ».'));
      _load();
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LiveShopOrdersPage()));
    }
  }

  // ── Affichage dans le live ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_pins.isEmpty && !widget.isHost) return const SizedBox.shrink();
    return Positioned(
      left: 12,
      right: 76,
      top: MediaQuery.of(context).padding.top + 190,
      child: _pins.isEmpty
          ? Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton.icon(
                onPressed: _manage,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.black.withOpacity(0.6), foregroundColor: Colors.white),
                icon: const Icon(Icons.push_pin_rounded, size: 16),
                label: Text(tr('Ouvrir ma vitrine'), style: const TextStyle(fontSize: 12)),
              ),
            )
          : Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              SizedBox(
                height: 126,
                child: NotificationListener<ScrollStartNotification>(
                  onNotification: (n) {
                    if (n.dragDetails != null) _userTouch = DateTime.now();   // la personne fait défiler : on ne la dérange pas
                    return false;
                  },
                  child: ListView.separated(
                    controller: _scroll,
                    scrollDirection: Axis.horizontal,
                    itemCount: _pins.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) => _card(_pins[i]),
                  ),
                ),
              ),
              if (_pins.length > 1)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: Colors.black.withOpacity(0.62), borderRadius: BorderRadius.circular(99)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.shopping_bag_rounded, color: _gold, size: 12),
                        const SizedBox(width: 4),
                        Text(tr('{n} produits · fais défiler', {'n': _pins.length}), style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                    const SizedBox(width: 8),
                    for (var i = 0; i < _pins.length && i < 8; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        width: i == _current.clamp(0, _pins.length - 1) ? 16 : 6,
                        height: 6,
                        decoration: BoxDecoration(color: i == _current.clamp(0, _pins.length - 1) ? _gold : Colors.white54, borderRadius: BorderRadius.circular(99)),
                      ),
                  ]),
                ),
              if (widget.isHost)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(children: [
                    _chipButton(Icons.tune_rounded, tr('Gérer ma vitrine'), _manage),
                    const SizedBox(width: 6),
                    _chipButton(Icons.receipt_long_rounded, tr('Commandes'), () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LiveShopOrdersPage()))),
                  ]),
                ),
            ]),
    );
  }

  Widget _chipButton(IconData icon, String label, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: Colors.black.withOpacity(0.62), borderRadius: BorderRadius.circular(99)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: Colors.white, size: 14), const SizedBox(width: 5), Text(label, style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700))]),
        ),
      );

  Widget _card(Map<String, dynamic> p) {
    final old = (p['original_price_xof'] as num?)?.toInt();
    final price = (p['price_xof'] as num?)?.toInt() ?? 0;
    final flash = _flashLeft(p);
    final out = _soldOut(p);
    return GestureDetector(
      onTap: () => _showDetail(p),
      child: Container(
        width: 232,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.66),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: flash != null ? _gold : Colors.white24, width: flash != null ? 1.4 : 1),
        ),
        child: Row(children: [
          Stack(children: [
            ClipRRect(borderRadius: BorderRadius.circular(12), child: _image(p['image'] as String?, 72)),
            if (out) Positioned.fill(child: Container(decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)), child: Center(child: Text(tr('Épuisé'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12))))),
          ]),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('${p['title']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12.5)),
              Row(children: [
                Text(_f(price), style: const TextStyle(color: _gold, fontWeight: FontWeight.w900, fontSize: 14)),
                if (old != null && old > price) ...[
                  const SizedBox(width: 5),
                  Flexible(child: Text(_f(old), overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white54, fontSize: 10.5, decoration: TextDecoration.lineThrough))),
                ],
              ]),
              const SizedBox(height: 3),
              Row(children: [
                _stockBadge(p),
                if (flash != null) ...[
                  const SizedBox(width: 5),
                  const Icon(Icons.bolt_rounded, color: _gold, size: 14),
                  Text(_clock(flash), style: const TextStyle(color: _gold, fontSize: 10.5, fontWeight: FontWeight.w800)),
                ],
              ]),
              if (!widget.isHost) ...[
                const SizedBox(height: 5),
                Row(children: [
                  SizedBox(height: 26, child: FilledButton(onPressed: out ? null : () => _buy(p), style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12)), child: Text(tr('Acheter'), style: const TextStyle(fontSize: 11.5)))),
                  if (p['negotiable'] == true && !out) ...[
                    const SizedBox(width: 5),
                    SizedBox(height: 26, child: OutlinedButton(onPressed: () => _negotiate(p), style: OutlinedButton.styleFrom(foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 8)), child: Text(tr('Négocier'), style: const TextStyle(fontSize: 11.5)))),
                  ],
                ]),
              ] else if (((p['sold'] as num?)?.toInt() ?? 0) > 0)
                Padding(padding: const EdgeInsets.only(top: 4), child: Text(tr('{n} vendu(s)', {'n': (p['sold'] as num).toInt()}), style: const TextStyle(color: Colors.white70, fontSize: 11))),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Points de la galerie d'images d'un produit.
class SmoothDots extends StatefulWidget {
  const SmoothDots({super.key, required this.controller, required this.count});

  final PageController controller;
  final int count;

  @override
  State<SmoothDots> createState() => _SmoothDotsState();
}

class _SmoothDotsState extends State<SmoothDots> {
  double _page = 0;

  void _listen() => setState(() => _page = widget.controller.hasClients ? (widget.controller.page ?? 0) : 0);

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_listen);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_listen);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < widget.count; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: (_page.round() == i) ? 18 : 7,
              height: 7,
              decoration: BoxDecoration(color: (_page.round() == i) ? Colors.white : Colors.white54, borderRadius: BorderRadius.circular(99)),
            ),
        ],
      );
}
