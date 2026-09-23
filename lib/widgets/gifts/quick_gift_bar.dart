import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/coin_pack.dart';
import '../../models/model_data.dart';
import '../../pages/coins/coin_gift_dialog.dart';
import '../../pages/coins/coin_recharge_screen.dart';
import '../../providers/authProvider.dart';
import '../../providers/coin_gift_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/coin_gift_service.dart';
import '../../services/quick_gift_service.dart';
import '../../theme/app_colors.dart';
import 'gift_sent_overlay.dart';

// ── Badge "Cadeau" + envoi rapide ────────────────────────────────────────────

/// Pilule "🏆 Cadeau" + bulle de cadeau rapide à gauche.
/// - Tap bulle  : envoie le dernier cadeau utilisé (ou 1er par défaut) directement.
/// - Tap pilule : ouvre le CoinGiftDialog complet.
class CadeauBadge extends StatefulWidget {
  final String receiverId;
  final String receiverName;
  final String receiverAvatar;
  final Post post;
  final int giftCount;
  final VoidCallback? onGiftSuccess;

  const CadeauBadge({
    Key? key,
    required this.receiverId,
    required this.receiverName,
    required this.receiverAvatar,
    required this.post,
    this.giftCount = 0,
    this.onGiftSuccess,
  }) : super(key: key);

  @override
  State<CadeauBadge> createState() => _CadeauBadgeState();
}

class _CadeauBadgeState extends State<CadeauBadge> {
  CoinPack? _quickGift;
  DateTime? _lastSentAt;

  @override
  void initState() {
    super.initState();
    _loadQuickGift();
  }

  Future<void> _loadQuickGift() async {
    final shortcuts = await QuickGiftService.getShortcuts();
    if (!mounted) return;
    setState(() {
      _quickGift = shortcuts.isNotEmpty
          ? shortcuts.first.pack
          : CoinPack.defaultPacks.isNotEmpty ? CoinPack.defaultPacks.first : null;
    });
  }

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }

  void _openFullDialog() {
    showDialog(
      context: context,
      builder: (_) => CoinGiftDialog(
        receiverId: widget.receiverId,
        receiverName: widget.receiverName,
        receiverAvatar: widget.receiverAvatar,
        post: widget.post,
        onGiftSuccess: () {
          widget.onGiftSuccess?.call();
          _loadQuickGift(); // recharger l'emoji après envoi depuis le modal
        },
      ),
    );
  }

  void _sendQuickGift() {
    if (_quickGift == null) return;
    final now = DateTime.now();
    if (_lastSentAt != null && now.difference(_lastSentAt!).inMilliseconds < 1500) return;
    _lastSentAt = now;

    final coinProvider = Provider.of<CoinGiftUserProvider>(context, listen: false);
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final senderId = authProvider.loginUserData?.id;
    if (senderId == null) return;

    if (coinProvider.giftCoinsBalance < _quickGift!.coins) {
      _showInsufficientModal(coinProvider.giftCoinsBalance);
      return;
    }

    if (mounted) {
      showGiftSentOverlay(context, _quickGift!, widget.receiverName);
    }
    widget.onGiftSuccess?.call();
    unawaited(QuickGiftService.recordRecentGift(_quickGift!));

    // Commentaire auto optimiste
    CoinGiftService.postGiftAutoComment(
      senderId: senderId,
      senderData: authProvider.loginUserData,
      postId: widget.post.id!,
      giftPack: _quickGift!,
      coinsAmount: _quickGift!.coins,
      quantity: 1,
      firestore: FirebaseFirestore.instance,
    );

    unawaited(coinProvider.sendGift(
      senderId: senderId,
      receiverId: widget.receiverId,
      coinsAmount: _quickGift!.coins,
      post: widget.post,
      context: context,
      giftPack: _quickGift!,
      onSuccess: () => coinProvider.refreshBalance(senderId),
    ).then((ok) {
      if (!ok) coinProvider.refreshBalance(senderId);
    }).catchError((_) {}));
  }

  void _showInsufficientModal(int balance) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) {
        final colors = AppColors.of(ctx);
        return AlertDialog(
          backgroundColor: colors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(children: [
            const Text('🪙', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Text('Solde insuffisant',
                style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold)),
          ]),
          content: Text(
            'Il vous faut ${_quickGift!.coins} pièces pour envoyer ce cadeau.\nVotre solde : $balance pièces.',
            style: TextStyle(color: colors.textSecondary, fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Annuler', style: TextStyle(color: colors.textSecondary)),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.add_circle_outline, color: Colors.white, size: 16),
              label: const Text('Acheter des pièces',
                  style: TextStyle(color: Colors.white, fontSize: 13)),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const CoinRechargeScreen()));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isDark = colors.isDark;
    final pillBg = isDark ? const Color(0xFF1E1E1E) : const Color(0xFFFFFFFF);
    final pillBorder = isDark
        ? const Color(0xFFFF6A00).withOpacity(0.35)
        : const Color(0xFFFF6A00).withOpacity(0.25);
    final labelColor = isDark ? const Color(0xFFFFFFFF) : const Color(0xFF1A1A1A);

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // ── Pilule "🏆 Cadeau" ──
        GestureDetector(
          onTap: _openFullDialog,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
            decoration: BoxDecoration(
              color: pillBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: pillBorder, width: 0.8),
              boxShadow: isDark
                  ? [BoxShadow(color: const Color(0xFFFF6A00).withOpacity(0.12), blurRadius: 6, offset: const Offset(0, 1))]
                  : [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4, offset: const Offset(0, 1))],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFFFF4500), Color(0xFFFFAA00)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: const Center(child: Text('🏆', style: TextStyle(fontSize: 9))),
                ),
                const SizedBox(width: 4),
                Text('Cadeau',
                    style: TextStyle(
                        color: labelColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.1)),
                Container(
                  width: 1,
                  height: 10,
                  margin: const EdgeInsets.symmetric(horizontal: 5),
                  color: pillBorder,
                ),
                Text(_fmt(widget.giftCount),
                    style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ),
        // ── Bulle envoi rapide (à droite) ──
        if (_quickGift != null) ...[
          const SizedBox(width: 5),
          GestureDetector(
            onTap: _sendQuickGift,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: pillBg,
                border: Border.all(color: pillBorder, width: 0.8),
                boxShadow: isDark
                    ? [BoxShadow(color: const Color(0xFFFF6A00).withOpacity(0.12), blurRadius: 6, offset: const Offset(0, 1))]
                    : [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4, offset: const Offset(0, 1))],
              ),
              child: Center(
                child: Text(_quickGift!.icon, style: const TextStyle(fontSize: 14)),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

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
      _showInsufficientBalanceModal(pack.coins);
      return;
    }

    // 1. Feedback immédiat — animation avant tout appel réseau
    if (mounted) showGiftSentOverlay(context, pack, widget.receiverName);
    widget.onGiftSuccess?.call();

    // 2. Historique récent en arrière-plan
    unawaited(QuickGiftService.recordRecentGift(pack));

    // Commentaire auto optimiste
    CoinGiftService.postGiftAutoComment(
      senderId: senderId,
      senderData: authProvider.loginUserData,
      postId: widget.post.id!,
      giftPack: pack,
      coinsAmount: pack.coins,
      quantity: 1,
      firestore: FirebaseFirestore.instance,
    );

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

  void _showInsufficientBalanceModal(int required) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.monetization_on, color: Colors.amber),
            SizedBox(width: 8),
            Text('Solde insuffisant'),
          ],
        ),
        content: Text(
          'Il te manque des pièces pour envoyer ce cadeau ($required 🪙 requis).\nRecharge ton solde pour continuer.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const CoinRechargeScreen()));
            },
            icon: const Icon(Icons.add_circle_outline, color: Colors.white),
            label: const Text('Recharger', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade700),
          ),
        ],
      ),
    );
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

