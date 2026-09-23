import 'package:flutter/material.dart';
import '../../models/coin_pack.dart';

/// Affiche une animation centrée (style "double-tap like") lors de l'envoi d'un cadeau.
/// Fonctionne depuis n'importe quelle page via l'Overlay.
void showGiftSentOverlay(
  BuildContext context,
  CoinPack pack,
  String receiverName, {
  int quantity = 1,
  int? receiverCoins,
}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _GiftSentOverlay(
      pack: pack,
      receiverName: receiverName,
      quantity: quantity,
      receiverCoins: receiverCoins ?? (pack.coins * quantity * 0.7).floor(),
      onDone: () {
        try {
          entry.remove();
        } catch (_) {}
      },
    ),
  );
  overlay.insert(entry);
}

class _GiftSentOverlay extends StatefulWidget {
  final CoinPack pack;
  final String receiverName;
  final int quantity;
  final int receiverCoins;
  final VoidCallback onDone;

  const _GiftSentOverlay({
    required this.pack,
    required this.receiverName,
    required this.quantity,
    required this.receiverCoins,
    required this.onDone,
  });

  @override
  State<_GiftSentOverlay> createState() => _GiftSentOverlayState();
}

class _GiftSentOverlayState extends State<_GiftSentOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _opacity;
  late Animation<double> _translateY;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    // Entrée : spring-bounce 0→1 sur 0-35% de la durée
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.25, end: 1.1)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.1, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 10,
      ),
      TweenSequenceItem(
        tween: ConstantTween(1.0),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.85)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 25,
      ),
    ]).animate(_ctrl);

    _opacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 15),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 25),
    ]).animate(_ctrl);

    // Monte légèrement pendant la sortie
    _translateY = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 75),
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: -40.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 25,
      ),
    ]).animate(_ctrl);

    _ctrl.forward().then((_) => widget.onDone());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    final hasQty = widget.quantity > 1;
    final name = widget.receiverName.length > 16
        ? '${widget.receiverName.substring(0, 14)}…'
        : widget.receiverName;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Positioned.fill(
        child: IgnorePointer(
          child: Material(
            color: Colors.transparent,
            child: Opacity(
            opacity: _opacity.value,
            child: Transform.translate(
              offset: Offset(0, _translateY.value),
              child: Center(
                child: Transform.scale(
                  scale: _scale.value,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ── Icône cadeau ──
                      Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const RadialGradient(
                            colors: [Color(0xFFFFF3CD), Color(0xFFFFD700)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFFD700).withOpacity(0.5),
                              blurRadius: 20,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            widget.pack.icon,
                            style: const TextStyle(fontSize: 38),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // ── Pilule message ──
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.72),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: const Color(0xFFFFD700).withOpacity(0.4),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  hasQty
                                      ? '${widget.pack.label} × ${widget.quantity}'
                                      : widget.pack.label,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFD700)
                                        .withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text('🪙',
                                          style: TextStyle(fontSize: 11)),
                                      const SizedBox(width: 3),
                                      Text(
                                        '+${_fmt(widget.receiverCoins)} créateur',
                                        style: const TextStyle(
                                          color: Color(0xFFFFD700),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Vous soutenez @$name ✨',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.75),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          ), // Material
        ),
      ),
    );
  }
}
