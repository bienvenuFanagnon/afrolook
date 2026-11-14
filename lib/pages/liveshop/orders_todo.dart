import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/api/live_shop_api.dart';

/// Ce qui attend MA réponse dans la boutique et les lives (ventes à valider, frais à accepter, réceptions à confirmer, offres) :
/// un seul compteur lu sur le serveur, partagé par toutes les pastilles rouges de l'application (menu, liste des lives).
class OrdersTodo {
  static final ValueNotifier<int> total = ValueNotifier<int>(0);
  static DateTime _last = DateTime.fromMillisecondsSinceEpoch(0);
  static bool _busy = false;
  static Timer? _timer;
  static int _watchers = 0;

  /// Relit le compteur (au plus une fois toutes les 20 s, sauf `force`). Hors connexion ou en erreur : on garde l'ancien chiffre.
  static Future<void> refresh({bool force = false}) async {
    if (_busy || (!force && DateTime.now().difference(_last) < const Duration(seconds: 20))) return;
    _busy = true;
    try {
      final c = await LiveShopApi.orderCounts();
      total.value = (c['total'] as num?)?.toInt() ?? 0;
      _last = DateTime.now();
    } catch (_) {} finally {
      _busy = false;
    }
  }

  /// Une pastille à l'écran : lit le compteur et le relit toutes les 90 secondes tant qu'au moins une pastille est affichée.
  static void watch() {
    _watchers++;
    refresh();
    _timer ??= Timer.periodic(const Duration(seconds: 90), (_) => refresh());
  }

  static void unwatch() {
    _watchers = (_watchers - 1).clamp(0, 1 << 30);
    if (_watchers == 0) {
      _timer?.cancel();
      _timer = null;
    }
  }
}

/// Petit rond rouge avec le nombre (rien quand il n'y a rien à traiter).
Widget ordersTodoDot(int n, {double top = -5, double right = -5}) => Positioned(
      top: top,
      right: right,
      child: Container(
        key: const ValueKey('orders_todo_badge'),
        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: const Color(0xFFE53935), borderRadius: BorderRadius.circular(99), border: Border.all(color: Colors.white, width: 1.2)),
        child: Text(n > 99 ? '99+' : '$n', style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w800)),
      ),
    );

/// Entoure une icône d'une pastille rouge « à traiter ».
class OrdersTodoBadge extends StatefulWidget {
  const OrdersTodoBadge({super.key, required this.child});
  final Widget child;

  @override
  State<OrdersTodoBadge> createState() => _OrdersTodoBadgeState();
}

class _OrdersTodoBadgeState extends State<OrdersTodoBadge> {
  @override
  void initState() {
    super.initState();
    OrdersTodo.watch();
  }

  @override
  void dispose() {
    OrdersTodo.unwatch();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
        valueListenable: OrdersTodo.total,
        builder: (_, n, child) => Stack(clipBehavior: Clip.none, children: [child!, if (n > 0) ordersTodoDot(n)]),
        child: widget.child,
      );
}

/// Pastille placée à droite d'une ligne de menu (« Mes commandes »).
class OrdersTodoPill extends StatefulWidget {
  const OrdersTodoPill({super.key});

  @override
  State<OrdersTodoPill> createState() => _OrdersTodoPillState();
}

class _OrdersTodoPillState extends State<OrdersTodoPill> {
  @override
  void initState() {
    super.initState();
    OrdersTodo.watch();
  }

  @override
  void dispose() {
    OrdersTodo.unwatch();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
        valueListenable: OrdersTodo.total,
        builder: (_, n, __) => n <= 0
            ? const SizedBox.shrink()
            : Container(
                key: const ValueKey('orders_todo_pill'),
                constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                padding: const EdgeInsets.symmetric(horizontal: 6),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: const Color(0xFFE53935), borderRadius: BorderRadius.circular(99)),
                child: Text(n > 99 ? '99+' : '$n', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
              ),
      );
}

/// Donne le compteur « à traiter » à un constructeur (pour les composants qui prennent un nombre, comme le menu latéral).
class OrdersTodoScope extends StatefulWidget {
  const OrdersTodoScope({super.key, required this.builder});
  final Widget Function(BuildContext context, int todo) builder;

  @override
  State<OrdersTodoScope> createState() => _OrdersTodoScopeState();
}

class _OrdersTodoScopeState extends State<OrdersTodoScope> {
  @override
  void initState() {
    super.initState();
    OrdersTodo.watch();
  }

  @override
  void dispose() {
    OrdersTodo.unwatch();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(valueListenable: OrdersTodo.total, builder: (c, n, _) => widget.builder(c, n));
}
