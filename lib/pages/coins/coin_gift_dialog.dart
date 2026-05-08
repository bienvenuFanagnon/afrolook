// widgets/coin_gift_dialog.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/coin_pack.dart';
import '../../models/model_data.dart';
import '../../providers/coin_gift_provider.dart';
import 'coin_recharge_screen.dart';

class CoinGiftDialog extends StatefulWidget {
  final String receiverId;
  final String receiverName;
  final String receiverAvatar;
  final Post? post;
  final VoidCallback? onGiftSuccess;
  final bool isLive;
  final String? liveId;

  const CoinGiftDialog({
    Key? key,
    required this.receiverId,
    required this.receiverName,
    this.receiverAvatar = '',
    this.post,
    this.onGiftSuccess,
    this.isLive = false,
    this.liveId,
  }) : super(key: key);

  @override
  State<CoinGiftDialog> createState() => _CoinGiftDialogState();
}

class _CoinGiftDialogState extends State<CoinGiftDialog> {
  int _selectedIndex = 0;
  bool _isLoading = false;
  late CoinGiftUserProvider _coinProvider;
  int _currentBalance = 0;

  final List<CoinPack> _giftPacks = CoinPack.giftPacks;

  @override
  void initState() {
    super.initState();
    _coinProvider = Provider.of<CoinGiftUserProvider>(context, listen: false);
    _currentBalance = _coinProvider.giftCoinsBalance;
  }

  void _updateBalance() {
    setState(() {
      _currentBalance = _coinProvider.giftCoinsBalance;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.8,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A1A1A), Color(0xFF0D0D0D)],
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFFFFD700), width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            const Divider(color: Colors.white24, height: 1),
            _buildBalanceSection(),
            const SizedBox(height: 16),
            Expanded(child: _buildGiftGrid()),
            const SizedBox(height: 16),
            _buildActions(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
              ),
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: ClipOval(
              child: widget.receiverAvatar.isNotEmpty
                  ? Image.network(widget.receiverAvatar, fit: BoxFit.cover)
                  : const Icon(Icons.person, size: 30, color: Colors.white),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Envoyer un cadeau à',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.receiverName,
                  style: const TextStyle(
                    color: Color(0xFFFFD700),
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Row(
            children: [
              Text('🪙', style: TextStyle(fontSize: 24)),
              SizedBox(width: 8),
              Text(
                'Vos pièces',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
          Text(
            '$_currentBalance',
            style: const TextStyle(
              color: Color(0xFFFFD700),
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGiftGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.72,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _giftPacks.length,
      itemBuilder: (context, index) {
        final pack = _giftPacks[index];
        final isSelected = _selectedIndex == index;
        // PAS DE VERROUILLAGE - tous les cadeaux sont sélectionnables
        // Mais on change la couleur si le solde est insuffisant

        return GestureDetector(
          onTap: () => setState(() => _selectedIndex = index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? const LinearGradient(
                colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
                  : const LinearGradient(
                colors: [Color(0xFF2D2D2D), Color(0xFF1A1A1A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? Colors.white
                    : (_currentBalance >= pack.coins
                    ? const Color(0xFFFFD700).withOpacity(0.3)
                    : Colors.red.withOpacity(0.3)),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(pack.icon, style: const TextStyle(fontSize: 40)),
                  const SizedBox(height: 8),
                  Text(
                    pack.displayLabel,
                    style: TextStyle(
                      color: isSelected ? Colors.black : Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.black.withOpacity(0.2)
                          : (_currentBalance >= pack.coins
                          ? Colors.black.withOpacity(0.5)
                          : Colors.red.withOpacity(0.2)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('🪙',
                            style: TextStyle(
                                fontSize: 10,
                                color: isSelected
                                    ? Colors.black
                                    : (_currentBalance >= pack.coins
                                    ? const Color(0xFFFFD700)
                                    : Colors.red)
                            )
                        ),
                        const SizedBox(width: 2),
                        Text(
                          _formatNumber(pack.coins),
                          style: TextStyle(
                            color: isSelected
                                ? Colors.black
                                : (_currentBalance >= pack.coins
                                ? const Color(0xFFFFD700)
                                : Colors.red),
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Petit indicateur si solde insuffisant (optionnel)
                  if (_currentBalance < pack.coins && !isSelected)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Insuffisant',
                        style: TextStyle(
                          color: Colors.red.withOpacity(0.7),
                          fontSize: 8,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActions() {
    final selectedPack = _giftPacks[_selectedIndex];
    final hasEnoughCoins = _currentBalance >= selectedPack.coins;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => _navigateToRecharge(),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFFFD700),
                side: const BorderSide(color: Color(0xFFFFD700)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Recharger', style: TextStyle(fontWeight: FontWeight.bold,fontSize: 13)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _isLoading ? null : () => _sendGift(selectedPack),
              style: ElevatedButton.styleFrom(
                backgroundColor: hasEnoughCoins ? const Color(0xFFFFD700) : Colors.red,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('🪙 ${_formatNumber(selectedPack.coins)}',
                      style: const TextStyle(fontWeight: FontWeight.bold)
                  ),
                  const SizedBox(width: 8),
                  Text(
                    hasEnoughCoins ? 'Envoyer' : 'Solde faible',
                    style: const TextStyle(fontWeight: FontWeight.bold,fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendGift(CoinPack pack) async {
    // Si le solde est insuffisant, rediriger vers la page d'achat
    if (_currentBalance < pack.coins) {
      _showInsufficientBalanceDialog();
      return;
    }

    setState(() => _isLoading = true);

    final success = await _coinProvider.sendGift(
      senderId: _coinProvider.currentUser!.id!,
      receiverId: widget.receiverId,
      coinsAmount: pack.coins,
      post: widget.post!,
      context: context,
      onSuccess: () {
        _updateBalance();
        if (widget.isLive && widget.liveId != null) {
          _recordLiveGift(widget.liveId!, pack.coins);
        }
        widget.onGiftSuccess?.call();
      },
    );

    setState(() => _isLoading = false);

    if (success) {
      if (mounted) {
        Navigator.pop(context);
        _showSuccessAnimation(pack);
      }
    } else {
      _showInsufficientBalanceDialog();
    }
  }

  void _showInsufficientBalanceDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Solde insuffisant', style: TextStyle(color: Colors.yellow)),
        content: const Text('Vous n\'avez pas assez de pièces. Voulez-vous en acheter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _navigateToRecharge();
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFD700)),
            child: const Text('Acheter des pièces', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  void _navigateToRecharge() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CoinRechargeScreen(),
      ),
    ).then((_) => _updateBalance());
  }

  void _showSuccessAnimation(CoinPack pack) {
    final navigator = Navigator.of(context);

    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16),
        child: Stack(
          children: [
            // Contenu principal
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Animation de l'icône (optionnelle)
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.5, end: 1.0),
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.elasticOut,
                    builder: (context, scale, child) {
                      return Transform.scale(
                        scale: scale,
                        child: child,
                      );
                    },
                    child: Text(pack.icon, style: const TextStyle(fontSize: 60)),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Cadeau envoyé ! 🎉',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('🪙', style: TextStyle(fontSize: 16)),
                            const SizedBox(width: 4),
                            Text(
                              _formatNumber(pack.coins),
                              style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'offertes à ${widget.receiverName}',
                          style: const TextStyle(color: Colors.black87, fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Bouton de fermeture (croix)
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: () {
                  if (mounted && navigator.canPop()) {
                    navigator.pop();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ).then((_) {
      // Callback après fermeture (si nécessaire)
    });

    // Fermeture automatique après 3 secondes
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && navigator.canPop()) {
        navigator.pop();
      }
    });
  }
  void _recordLiveGift(String liveId, int coins) async {
    final firestore = FirebaseFirestore.instance;
    await firestore.collection('LiveGifts').add({
      'liveId': liveId,
      'senderId': _coinProvider.currentUser!.id,
      'receiverId': widget.receiverId,
      'coins': coins,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  String _formatNumber(int num) {
    if (num >= 1000000) return '${(num / 1000000).toStringAsFixed(1)}M';
    if (num >= 1000) return '${(num / 1000).toStringAsFixed(1)}K';
    return num.toString();
  }
}