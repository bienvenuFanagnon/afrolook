import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/tr.dart';
import '../../services/api/live_shop_api.dart';
import '../../theme/app_colors.dart';
import 'seller_verification_page.dart';

final NumberFormat _n = NumberFormat.decimalPattern('fr');
String _f(num v) => '${_n.format(v)} F';

/// Couleurs d'une carte de ventes : thème de l'application, ou palette sombre quand la carte est posée sur une page sombre (fin de live).
class _Pal {
  _Pal(BuildContext context, bool onDark) {
    final c = AppColors.of(context);
    text = onDark ? Colors.white : c.textPrimary;
    sub = onDark ? Colors.white70 : c.textSecondary;
    card = onDark ? Colors.white.withOpacity(0.07) : c.surface;
    line = onDark ? Colors.white24 : c.border;
    accent = onDark ? const Color(0xFFF9A825) : c.primary;
  }

  late final Color text, sub, card, line, accent;
}

Widget _metric(_Pal p, String label, String value, {bool big = false}) => Expanded(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: TextStyle(color: p.text, fontWeight: FontWeight.w900, fontSize: big ? 18 : 15)),
        const SizedBox(height: 1),
        Text(label, style: TextStyle(color: p.sub, fontSize: 11.5)),
      ]),
    );

/// Bilan des ventes en ligne d'un live (historique) : le total vendu en gros, puis commandes, articles, acheteurs ; l'hôte voit aussi l'argent reçu,
/// l'argent en attente, le panier moyen, le taux de conversion et ses produits les plus vendus. Rien n'est affiché si le live n'a rien vendu (sauf à l'hôte d'une vente).
class LiveSalesCard extends StatefulWidget {
  const LiveSalesCard({super.key, required this.liveId, this.onDark = false});

  final String liveId;
  final bool onDark;

  @override
  State<LiveSalesCard> createState() => _LiveSalesCardState();
}

class _LiveSalesCardState extends State<LiveSalesCard> {
  Map<String, dynamic>? _d;

  @override
  void initState() {
    super.initState();
    LiveShopApi.liveSummary(widget.liveId).then((r) { if (mounted) setState(() => _d = r); }).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    if (d == null) return const SizedBox.shrink();
    final host = d.containsKey('received_xof');
    final orders = (d['orders'] as num?)?.toInt() ?? 0;
    if (d['is_shopping'] != true || (orders == 0 && !host)) return const SizedBox.shrink();
    final p = _Pal(context, widget.onDark);
    final top = ((d['top_products'] as List?) ?? const []).whereType<Map>().toList();
    final conv = d['conversion_pct'];
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: p.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.shopping_bag_rounded, color: p.accent, size: 20),
          const SizedBox(width: 8),
          Text(tr('Ventes en ligne'), style: TextStyle(color: p.text, fontWeight: FontWeight.w800, fontSize: 15)),
        ]),
        const SizedBox(height: 10),
        Text(_f((d['gross_xof'] as num?) ?? 0), style: TextStyle(color: p.accent, fontWeight: FontWeight.w900, fontSize: 28)),
        Text(tr('vendus pendant ce live'), style: TextStyle(color: p.sub, fontSize: 12)),
        const SizedBox(height: 12),
        Row(children: [
          _metric(p, tr('commandes'), '$orders'),
          _metric(p, tr('articles vendus'), '${(d['items_sold'] as num?)?.toInt() ?? 0}'),
          if (host) _metric(p, tr('acheteurs'), '${(d['buyers'] as num?)?.toInt() ?? 0}'),
        ]),
        if (host) ...[
          const SizedBox(height: 12),
          Row(children: [
            _metric(p, tr('argent reçu'), _f((d['received_xof'] as num?) ?? 0)),
            _metric(p, tr('en attente de réception'), _f((d['in_escrow_xof'] as num?) ?? 0)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            _metric(p, tr('panier moyen'), _f((d['avg_basket_xof'] as num?) ?? 0)),
            _metric(p, tr('acheteurs / spectateurs'), conv == null ? '—' : '$conv %'),
          ]),
          if (top.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(tr('Produits les plus vendus'), style: TextStyle(color: p.text, fontWeight: FontWeight.w800, fontSize: 13)),
            const SizedBox(height: 6),
            for (final t in top)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(children: [
                  Expanded(child: Text('${t['title']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.text, fontSize: 12.5))),
                  Text('× ${t['quantity']}', style: TextStyle(color: p.sub, fontSize: 12)),
                  const SizedBox(width: 10),
                  Text(_f((t['revenue_xof'] as num?) ?? 0), style: TextStyle(color: p.accent, fontWeight: FontWeight.w800, fontSize: 12.5)),
                ]),
              ),
          ],
        ] else
          Padding(padding: const EdgeInsets.only(top: 10), child: Text(tr('Vends toi aussi en direct avec ta boutique.'), style: TextStyle(color: p.sub, fontSize: 12, fontStyle: FontStyle.italic))),
      ]),
    );
  }
}

/// Tableau de bord du vendeur : tout ce qu'il a vendu en ligne, l'argent reçu, les 14 derniers jours, ses meilleurs lives et ses meilleurs produits.
class SellerStatsCard extends StatefulWidget {
  const SellerStatsCard({super.key});

  @override
  State<SellerStatsCard> createState() => _SellerStatsCardState();
}

class _SellerStatsCardState extends State<SellerStatsCard> {
  Map<String, dynamic>? _d;

  @override
  void initState() {
    super.initState();
    LiveShopApi.sellerStats().then((r) { if (mounted) setState(() => _d = r); }).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    if (d == null || ((d['orders'] as num?)?.toInt() ?? 0) == 0) return const SizedBox.shrink();
    final p = _Pal(context, false);
    final days = ((d['by_day'] as List?) ?? const []).whereType<Map>().toList();
    final maxDay = days.fold<num>(1, (m, e) => ((e['gross_xof'] as num?) ?? 0) > m ? (e['gross_xof'] as num) : m);
    final lives = ((d['lives'] as List?) ?? const []).whereType<Map>().take(3).toList();
    final top = ((d['top_products'] as List?) ?? const []).whereType<Map>().take(3).toList();
    final rep = d['reputation'] is Map ? Map<String, dynamic>.from(d['reputation'] as Map) : const <String, dynamic>{};
    final repRating = (rep['rating'] as num?)?.toDouble();
    final commission = (d['commission_percent'] as num?)?.toDouble();
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(18), border: Border.all(color: p.accent.withOpacity(0.5))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.insights_rounded, color: p.accent),
          const SizedBox(width: 8),
          Text(tr('Mes ventes en ligne'), style: TextStyle(color: p.text, fontWeight: FontWeight.w800, fontSize: 16)),
        ]),
        const SizedBox(height: 10),
        Text(_f((d['gross_xof'] as num?) ?? 0), style: TextStyle(color: p.accent, fontWeight: FontWeight.w900, fontSize: 30)),
        Text(tr('vendus au total'), style: TextStyle(color: p.sub, fontSize: 12)),
        const SizedBox(height: 12),
        Row(children: [
          _metric(p, tr('commandes'), '${(d['orders'] as num?)?.toInt() ?? 0}'),
          _metric(p, tr('articles vendus'), '${(d['items_sold'] as num?)?.toInt() ?? 0}'),
          _metric(p, tr('acheteurs'), '${(d['buyers'] as num?)?.toInt() ?? 0}'),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
          if (repRating != null) Text('★ ${repRating.toStringAsFixed(1)} (${rep['reviews']} ${tr('avis')})', style: TextStyle(color: p.accent, fontWeight: FontWeight.w800, fontSize: 12.5)),
          if (rep['trusted'] == true) Text(tr('Vendeur fiable'), style: TextStyle(color: p.accent, fontWeight: FontWeight.w800, fontSize: 12.5))
          else if (rep['verified'] == true) Text(tr('Identité vérifiée'), style: TextStyle(color: p.accent, fontWeight: FontWeight.w800, fontSize: 12.5)),
          if (commission != null) Text(tr('Commission : {c} %', {'c': commission == commission.roundToDouble() ? '${commission.toInt()}' : '$commission'}), style: TextStyle(color: p.sub, fontSize: 12)),
        ]),
        if (rep['verified'] != true)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SellerVerificationPage())),
              icon: Icon(Icons.verified_user_rounded, size: 18, color: p.accent),
              label: Text(tr('Vérifier mon identité'), style: TextStyle(color: p.accent, fontWeight: FontWeight.w800)),
            ),
          ),
        const SizedBox(height: 12),
        Row(children: [
          _metric(p, tr('argent reçu'), _f((d['received_xof'] as num?) ?? 0)),
          _metric(p, tr('en attente de réception'), _f((d['in_escrow_xof'] as num?) ?? 0)),
          _metric(p, tr('annulations'), '${d['cancel_rate_pct'] ?? 0} %'),
        ]),
        const SizedBox(height: 14),
        Text(tr('14 derniers jours'), style: TextStyle(color: p.text, fontWeight: FontWeight.w800, fontSize: 13)),
        const SizedBox(height: 6),
        SizedBox(
          height: 64,
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            for (final e in days)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1.5),
                  child: Tooltip(
                    message: '${e['day']} : ${_f((e['gross_xof'] as num?) ?? 0)}',
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      height: 4 + 56 * (((e['gross_xof'] as num?) ?? 0) / maxDay),
                      decoration: BoxDecoration(color: ((e['gross_xof'] as num?) ?? 0) > 0 ? p.accent : p.line, borderRadius: BorderRadius.circular(4)),
                    ),
                  ),
                ),
              ),
          ]),
        ),
        if (lives.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(tr('Mes meilleurs lives'), style: TextStyle(color: p.text, fontWeight: FontWeight.w800, fontSize: 13)),
          for (final l in lives)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(children: [
                Expanded(child: Text('${l['title']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.text, fontSize: 12.5))),
                Text(tr('{n} cmd', {'n': (l['orders'] as num?)?.toInt() ?? 0}), style: TextStyle(color: p.sub, fontSize: 12)),
                const SizedBox(width: 10),
                Text(_f((l['gross_xof'] as num?) ?? 0), style: TextStyle(color: p.accent, fontWeight: FontWeight.w800, fontSize: 12.5)),
              ]),
            ),
        ],
        if (top.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(tr('Mes meilleurs produits'), style: TextStyle(color: p.text, fontWeight: FontWeight.w800, fontSize: 13)),
          for (final t in top)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(children: [
                Expanded(child: Text('${t['title']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.text, fontSize: 12.5))),
                Text('× ${t['quantity']}', style: TextStyle(color: p.sub, fontSize: 12)),
                const SizedBox(width: 10),
                Text(_f((t['revenue_xof'] as num?) ?? 0), style: TextStyle(color: p.accent, fontWeight: FontWeight.w800, fontSize: 12.5)),
              ]),
            ),
        ],
      ]),
    );
  }
}
