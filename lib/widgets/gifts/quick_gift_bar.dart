import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/coin_pack.dart';
import '../../models/model_data.dart';
import '../../pages/coins/coin_gift_dialog.dart';
import '../../providers/authProvider.dart';
import '../../providers/coin_gift_provider.dart';
import '../../services/quick_gift_service.dart';
import '../../theme/app_colors.dart';

class QuickGiftBar extends StatefulWidget {
  final String receiverId;
  final String receiverName;
  final String receiverAvatar;
  final Post post;
  final VoidCallback? onGiftSuccess;
  final int giftCount;

  const QuickGiftBar({
    Key? key,
    required this.receiverId,
    required this.receiverName,
    required this.receiverAvatar,
    required this.post,
    this.onGiftSuccess,
    this.giftCount = 0,
  }) : super(key: key);

  @override
  State<QuickGiftBar> createState() => _QuickGiftBarState();
}

class _QuickGiftBarState extends State<QuickGiftBar> {
  List<({CoinPack pack, bool pinned})> _slots = [];

  @override
  void initState() {
    super.initState();
    _loadSlots();
  }

  Future<void> _loadSlots() async {
    final shortcuts = await QuickGiftService.getShortcuts();
    if (mounted) setState(() => _slots = shortcuts);
  }

  // Debounce : évite les doubles envois rapides
  DateTime? _lastSentAt;

  void _sendQuickGift(int slotIndex, CoinPack pack) {
    final now = DateTime.now();
    if (_lastSentAt != null && now.difference(_lastSentAt!).inMilliseconds < 1500) return;
    _lastSentAt = now;

    final coinProvider = Provider.of<CoinGiftUserProvider>(context, listen: false);
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final senderId = authProvider.loginUserData.id!;
    final balance = coinProvider.giftCoinsBalance;

    if (balance < pack.coins) {
      _showError('Solde insuffisant pour envoyer ${pack.icon} (${pack.coins} 🪙)');
      return;
    }

    // 1. Feedback immédiat — toast avant tout appel réseau
    _showSuccessToast(pack);
    widget.onGiftSuccess?.call();

    // 2. Historique récent en arrière-plan
    unawaited(QuickGiftService.recordRecentGift(pack));

    // 3. Transaction Firestore en arrière-plan total (fire-and-forget)
    unawaited(coinProvider.sendGift(
      senderId: senderId,
      receiverId: widget.receiverId,
      coinsAmount: pack.coins,
      post: widget.post,
      context: context,
      giftPack: pack,
      onSuccess: () => coinProvider.refreshBalance(senderId),
    ).then((success) {
      if (!success) {
        coinProvider.refreshBalance(senderId);
        if (mounted) _showError('Envoi échoué — solde resynchronisé');
      }
    }).catchError((e) {
      coinProvider.refreshBalance(senderId);
      debugPrint('QuickGiftBar sendGift error: $e');
    }));
  }

  void _showSuccessToast(CoinPack pack) {
    if (!mounted) return;
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _GiftToast(
        pack: pack,
        receiverName: widget.receiverName,
        onDone: () => entry.remove(),
      ),
    );
    overlay.insert(entry);
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  void _openFullModal() {
    showDialog(
      context: context,
      builder: (_) => CoinGiftDialog(
        receiverId: widget.receiverId,
        receiverName: widget.receiverName,
        receiverAvatar: widget.receiverAvatar,
        post: widget.post,
        onGiftSuccess: () async {
          widget.onGiftSuccess?.call();
          await _loadSlots();
        },
      ),
    );
  }

  void _showSlotOptions(CoinPack pack, bool isPinned) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SlotOptionsSheet(
        pack: pack,
        isPinned: isPinned,
        onPin: () async {
          await QuickGiftService.pinGift(pack);
          await _loadSlots();
        },
        onUnpin: () async {
          await QuickGiftService.unpinGift(pack);
          await _loadSlots();
        },
        onOpenModal: _openFullModal,
      ),
    );
  }

  String _formatCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ..._slots.asMap().entries.map((entry) {
              final i = entry.key;
              final slot = entry.value;
              return Padding(
                padding: const EdgeInsets.only(right: 4),
                child: GestureDetector(
                  onTap: () => _sendQuickGift(i, slot.pack),
                  onLongPress: () => _showSlotOptions(slot.pack, slot.pinned),
                  child: _GiftBubble(
                    pack: slot.pack,
                    pinned: slot.pinned,
                    colors: colors,
                  ),
                ),
              );
            }),
            GestureDetector(
              onTap: _openFullModal,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.supportAccent, width: 1),
                ),
                child: Icon(Icons.add, size: 14, color: colors.supportAccent),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          _formatCount(widget.giftCount),
          style: TextStyle(color: colors.textSecondary, fontSize: 13),
        ),
      ],
    );
  }
}

class _GiftBubble extends StatelessWidget {
  final CoinPack pack;
  final bool pinned;
  final AppColors colors;

  const _GiftBubble({
    required this.pack,
    required this.pinned,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: pinned
                ? colors.supportAccent.withOpacity(0.15)
                : Colors.transparent,
            border: Border.all(
              color: pinned
                  ? colors.supportAccent
                  : colors.textSecondary.withOpacity(0.4),
              width: 1,
            ),
          ),
          child: Center(
            child: Text(pack.icon, style: const TextStyle(fontSize: 15)),
          ),
        ),
        if (pinned)
          Positioned(
            top: -2,
            right: -2,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.supportAccent,
                border: Border.all(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  width: 1,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SlotOptionsSheet extends StatelessWidget {
  final CoinPack pack;
  final bool isPinned;
  final VoidCallback onPin;
  final VoidCallback onUnpin;
  final VoidCallback onOpenModal;

  const _SlotOptionsSheet({
    required this.pack,
    required this.isPinned,
    required this.onPin,
    required this.onUnpin,
    required this.onOpenModal,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 32,
            height: 3,
            decoration: BoxDecoration(
              color: colors.textSecondary.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(pack.icon, style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(pack.label,
                        style: TextStyle(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.bold)),
                    Text('${pack.coins} 🪙',
                        style: TextStyle(
                            color: colors.textSecondary, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (!isPinned)
            ListTile(
              leading: Icon(Icons.push_pin_outlined, color: colors.supportAccent),
              title: Text('Épingler ce cadeau',
                  style: TextStyle(color: colors.textPrimary)),
              subtitle: Text('Toujours visible dans les raccourcis',
                  style: TextStyle(color: colors.textSecondary, fontSize: 12)),
              onTap: () {
                Navigator.pop(context);
                onPin();
              },
            )
          else
            ListTile(
              leading: Icon(Icons.push_pin, color: colors.supportAccent),
              title: Text('Retirer l\'épingle',
                  style: TextStyle(color: colors.textPrimary)),
              onTap: () {
                Navigator.pop(context);
                onUnpin();
              },
            ),
          ListTile(
            leading: Icon(Icons.card_giftcard, color: colors.textSecondary),
            title: Text('Ouvrir tous les cadeaux',
                style: TextStyle(color: colors.textPrimary)),
            onTap: () {
              Navigator.pop(context);
              onOpenModal();
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _GiftToast extends StatefulWidget {
  final CoinPack pack;
  final String receiverName;
  final VoidCallback onDone;

  const _GiftToast({
    required this.pack,
    required this.receiverName,
    required this.onDone,
  });

  @override
  State<_GiftToast> createState() => _GiftToastState();
}

class _GiftToastState extends State<_GiftToast>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 250));
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, -0.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    _ctrl.forward();

    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) {
        _ctrl.reverse().then((_) => widget.onDone());
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 12,
      left: 16,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: FadeTransition(
          opacity: _opacity,
          child: SlideTransition(
            position: _slide,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3))
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(widget.pack.icon,
                      style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      '${widget.pack.label} envoyé à ${widget.receiverName} !',
                      style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
