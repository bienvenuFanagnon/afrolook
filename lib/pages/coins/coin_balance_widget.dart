// widgets/coin_balance_widget.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/coin_gift_provider.dart';

class CoinBalanceWidget extends StatelessWidget {
  final bool showIcon;
  final bool showLabel;
  final VoidCallback? onTap;

  const CoinBalanceWidget({
    Key? key,
    this.showIcon = true,
    this.showLabel = true,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final coinProvider = Provider.of<CoinGiftUserProvider>(context);
    final balance = coinProvider.giftCoinsBalance;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1A1A1A), Color(0xFF2D2D2D)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFFFD700), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showIcon) ...[
              const Text('🪙', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 6),
            ],
            Text(
              _formatNumber(balance),
              style: const TextStyle(
                color: Color(0xFFFFD700),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            if (showLabel) ...[
              const SizedBox(width: 4),
              const Text(
                'pièces',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatNumber(int num) {
    if (num >= 1000000) return '${(num / 1000000).toStringAsFixed(1)}M';
    if (num >= 1000) return '${(num / 1000).toStringAsFixed(1)}K';
    return num.toString();
  }
}