import 'dart:async';

import 'package:afrotok/layout/centered_content.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:provider/provider.dart';

import '../../models/coin_pack.dart';
import '../../providers/authProvider.dart';
import '../../providers/coin_gift_provider.dart';
import '../../services/apple_iap_service.dart';
import '../../theme/app_colors.dart';

/// Boutique iOS : pièces vendues via In-App Purchase (règle App Store 3.1.1).
class AppleCoinStoreView extends StatefulWidget {
  const AppleCoinStoreView({super.key});

  @override
  State<AppleCoinStoreView> createState() => _AppleCoinStoreViewState();
}

class _AppleCoinStoreViewState extends State<AppleCoinStoreView> {
  final AppleIapService _iap = AppleIapService.instance;
  StreamSubscription<AppleIapEvent>? _eventsSub;

  @override
  void initState() {
    super.initState();
    _iap.start();
    _iap.onCoinsCredited = _refreshBalance;
    _iap.addListener(_onServiceChanged);
    _eventsSub = _iap.events.listen(_onEvent);
    _iap.loadProducts();
  }

  @override
  void dispose() {
    _iap.removeListener(_onServiceChanged);
    _eventsSub?.cancel();
    super.dispose();
  }

  void _onServiceChanged() {
    if (mounted) setState(() {});
  }

  void _refreshBalance() {
    if (!mounted) return;
    final uid = Provider.of<UserAuthProvider>(context, listen: false).loginUserData.id;
    if (uid != null) {
      Provider.of<CoinGiftUserProvider>(context, listen: false).refreshBalance(uid);
    }
  }

  void _onEvent(AppleIapEvent event) {
    if (!mounted) return;
    switch (event.type) {
      case AppleIapEventType.success:
        _showMessage('🎉 Achat réussi', '+${event.coins} pièces ont été ajoutées à ton solde.');
        break;
      case AppleIapEventType.error:
        _showMessage('Achat non finalisé', event.message);
        break;
      case AppleIapEventType.pending:
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(event.message)));
        break;
      case AppleIapEventType.canceled:
        break;
    }
  }

  void _showMessage(String title, String message) {
    final colors = AppColors.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(title, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold)),
        content: Text(message, style: TextStyle(color: colors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final coins = Provider.of<CoinGiftUserProvider>(context).giftCoinsBalance;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text('Acheter des pièces',
            style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: colors.surface,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: colors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: CenteredContent(
        child: RefreshIndicator(
          onRefresh: _iap.loadProducts,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
            children: [
              _balanceCard(colors, coins),
              const SizedBox(height: 18),
              Text('Choisis un pack',
                  style: TextStyle(color: colors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ..._content(colors),
              const SizedBox(height: 18),
              Text(
                "Paiement sécurisé par l'App Store. Les pièces achetées servent aux cadeaux, votes, "
                "participations et DÉFI. Elles ne sont pas convertibles en argent : seules les pièces "
                "gagnées (cadeaux reçus, récompenses, gains de DÉFI) peuvent être converties.",
                style: TextStyle(color: colors.textSecondary, fontSize: 12, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _balanceCard(AppColors colors, int coins) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          const Text('🪙', style: TextStyle(fontSize: 30)),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Mon solde', style: TextStyle(color: colors.textSecondary, fontSize: 12)),
              Text('$coins pièces',
                  style: TextStyle(color: colors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _content(AppColors colors) {
    if (_iap.loadingProducts && _iap.products.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (!_iap.storeAvailable || _iap.products.isEmpty) {
      return [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(16)),
          child: Column(
            children: [
              const Text('🍎', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 10),
              Text(
                "Les achats App Store ne sont pas disponibles pour le moment.",
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: _iap.loadProducts, child: const Text('Réessayer')),
            ],
          ),
        ),
      ];
    }
    return _iap.products.map((p) => _productTile(colors, p)).toList();
  }

  Widget _productTile(AppColors colors, ProductDetails product) {
    final pack = CoinPack.appleProducts.firstWhere(
      (c) => c.appleProductId == product.id,
      orElse: () => CoinPack(coins: _iap.coinsFor(product.id), priceFcfa: 0),
    );
    final busy = _iap.purchasingProductId != null;
    final isThis = _iap.purchasingProductId == product.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: pack.isPopular ? colors.primary : colors.border.withOpacity(0.5),
          width: pack.isPopular ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Text(pack.icon, style: const TextStyle(fontSize: 26)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${pack.coins} pièces',
                    style: TextStyle(color: colors.textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
                Text(pack.popularLabel ?? pack.label,
                    style: TextStyle(color: colors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: busy ? null : () => _iap.buy(product),
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: colors.onPrimary,
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: isThis
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: colors.onPrimary),
                  )
                : Text(product.price, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
