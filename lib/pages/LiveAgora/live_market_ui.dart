import 'dart:async';

import 'package:afrotok/l10n/tr.dart';
import 'package:afrotok/pages/LiveAgora/live_game_ui.dart' show clock;
import 'package:afrotok/services/api/live_stage.dart';
import 'package:afrotok/services/coin_checkout.dart';
import 'package:flutter/material.dart';

const _amber = Color(0xFFF9A825);
const _yellow = Color(0xFFFFE14D);

/// Un étal du marché : vendeur, état (en vente, appelé, suivant) et échéances.
class MarketStall {
  MarketStall(this.raw);

  final Map raw;

  String get id => '${raw['id']}';
  String get status => '${raw['status']}';
  int get rent => (raw['rent_coins'] as num?)?.toInt() ?? 0;
  StageUser? get vendor => StageUser.fromJson(raw['vendor']);
  DateTime? get endsAt => raw['ends_at'] is String ? DateTime.tryParse(raw['ends_at'] as String)?.toLocal() : null;
  DateTime? get callingUntil => raw['calling_until'] is String ? DateTime.tryParse(raw['calling_until'] as String)?.toLocal() : null;
  int get secondsToEnd => (endsAt?.difference(DateTime.now()).inSeconds ?? 0).clamp(0, 86400);
  int get secondsToAnswer => (callingUntil?.difference(DateTime.now()).inSeconds ?? 0).clamp(0, 86400);
}

/// Marché en direct (idée 1) : étals, tours des vendeurs, loyer payé seulement au tour. Mis à jour par l'écran du live toutes les 5 secondes.
class LiveMarketPanel extends StatefulWidget {
  const LiveMarketPanel({
    super.key,
    required this.state,
    required this.isHost,
    required this.onBook,
    required this.onCancel,
    required this.onReady,
    required this.onNext,
  });

  final Map<String, dynamic> state;
  final bool isHost;
  final VoidCallback onBook;
  final VoidCallback onCancel;
  final VoidCallback onReady;
  final VoidCallback onNext;

  @override
  State<LiveMarketPanel> createState() => _LiveMarketPanelState();
}

class _LiveMarketPanelState extends State<LiveMarketPanel> {
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) => mounted ? setState(() {}) : null);
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  Widget _av(StageUser? u) {
    final url = u?.avatarUrl;
    return CircleAvatar(
      radius: 15,
      backgroundColor: const Color(0xFF3B6A47),
      backgroundImage: url != null && url.isNotEmpty ? NetworkImage(url) : null,
      onBackgroundImageError: url != null && url.isNotEmpty ? (_, __) {} : null,
      child: url != null && url.isNotEmpty ? null : Text(u?.initials ?? '?', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cfg = (widget.state['config'] as Map?) ?? const {};
    final stalls = [for (final s in (widget.state['stalls'] as List? ?? const [])) MarketStall(s as Map)];
    final mine = widget.state['mine'] is Map ? MarketStall(widget.state['mine'] as Map) : null;
    final left = (widget.state['slots_left'] as num?)?.toInt() ?? 0;
    final rent = (cfg['rent_coins'] as num?)?.toInt() ?? 0;
    final minutes = (cfg['minutes'] as num?)?.toInt() ?? 15;
    final total = (cfg['stalls'] as num?)?.toInt() ?? stalls.length;
    Widget tag(String t, Color bg, [Color fg = Colors.white]) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(7)),
          child: Text(t, style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.w800)),
        );
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(color: Colors.black.withOpacity(.62), borderRadius: BorderRadius.circular(16), border: Border.all(color: _amber.withOpacity(.45))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Text(context.tr('Étals · {n}', {'n': '$total'}).toUpperCase(), style: const TextStyle(color: _yellow, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: .6)),
          const Spacer(),
          if (widget.isHost && stalls.any((s) => s.status == 'active' || s.status == 'calling'))
            GestureDetector(onTap: widget.onNext, child: Text(context.tr('Vendeur suivant'), style: const TextStyle(color: _amber, fontSize: 11.5, fontWeight: FontWeight.w800))),
        ]),
        const SizedBox(height: 6),
        for (final s in stalls)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white.withOpacity(.07), borderRadius: BorderRadius.circular(12), border: s.status == 'active' ? Border.all(color: _amber) : null),
            child: Row(children: [
              _av(s.vendor),
              const SizedBox(width: 8),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('@${s.vendor?.username ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700)),
                  Text(
                    s.status == 'active'
                        ? context.tr('{t} restantes', {'t': clock(s.secondsToEnd)})
                        : s.status == 'calling'
                            ? context.tr('Appelé : {t} pour répondre', {'t': clock(s.secondsToAnswer)})
                            : context.tr('En attente de son tour'),
                    style: const TextStyle(color: Colors.white60, fontSize: 10.5),
                  ),
                ]),
              ),
              if (s.status == 'active') tag(context.tr('EN VENTE'), const Color(0xFFD92D3A)),
              if (s.status == 'calling') tag(context.tr('À SON TOUR'), _amber, Colors.black),
              if (s.status == 'booked') tag(context.tr('SUIVANT'), Colors.white24),
            ]),
          ),
        if (stalls.isEmpty) Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(context.tr('Aucun vendeur pour le moment.'), style: const TextStyle(color: Colors.white60, fontSize: 12))),
        // le vendeur appelé répond « prêt » : le loyer est payé maintenant, jamais avant
        if (mine != null && mine.status == 'calling')
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton(
              onPressed: widget.onReady,
              style: ElevatedButton.styleFrom(backgroundColor: _amber, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(21))),
              child: Text(rent > 0 ? context.tr('Je suis prêt · loyer {n} pièces', {'n': CoinCheckout.fmt(rent)}) : context.tr('Je suis prêt'), style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w800)),
            ),
          )
        else if (mine != null && mine.status == 'booked')
          Row(children: [
            Expanded(child: Text(context.tr('Ta réservation est faite : rien n\'est payé avant ton tour.'), style: const TextStyle(color: Colors.white70, fontSize: 11.5))),
            TextButton(onPressed: widget.onCancel, child: Text(context.tr('Annuler'), style: const TextStyle(color: _amber))),
          ])
        else if (mine != null && mine.status == 'active')
          Text(context.tr('C\'est ton tour : épingle tes articles avec « Gérer » dans la vitrine.'), style: const TextStyle(color: Color(0xFF69F0AE), fontSize: 11.5, fontWeight: FontWeight.w700))
        else if (!widget.isHost && left > 0)
          Row(children: [
            Expanded(child: Text(context.tr('{n} étals libres · loyer {r} pièces pour {m} min', {'n': '$left', 'r': CoinCheckout.fmt(rent), 'm': '$minutes'}), style: const TextStyle(color: Colors.white70, fontSize: 11.5))),
            GestureDetector(
              onTap: widget.onBook,
              child: Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: _yellow, borderRadius: BorderRadius.circular(16)),
                child: Text(context.tr('Louer un étal'), style: const TextStyle(color: Color(0xFF121212), fontSize: 12, fontWeight: FontWeight.w800)),
              ),
            ),
          ])
        else if (left <= 0)
          Text(context.tr('Tous les étals sont pris.'), style: const TextStyle(color: Colors.white60, fontSize: 11.5)),
      ]),
    );
  }
}
