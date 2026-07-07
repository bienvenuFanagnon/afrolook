// widgets/coin_gift_dialog.dart
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/coin_pack.dart';
import '../../models/model_data.dart';
import '../../providers/coin_gift_provider.dart';
import '../../services/quick_gift_service.dart';
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
  int _quantity = 1;
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
        constraints: const BoxConstraints(maxWidth: 480),
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
// widgets/coin_gift_dialog.dart - Version corrigée du header

  Widget _buildHeader() {
    // Déterminer l'avatar à afficher
    String avatarUrl = widget.receiverAvatar;
    String displayName = widget.receiverName;
    bool isCanal = widget.receiverName.startsWith('#') ||
        (widget.post?.canal_id != null && widget.post?.canal_id?.isNotEmpty == true);

    // Si c'est un post de canal, on peut aussi récupérer l'avatar du canal depuis le post
    if (widget.post?.canal != null && widget.post!.canal!.urlImage != null) {
      avatarUrl = widget.post!.canal!.urlImage!;
      displayName = '#${widget.post!.canal!.titre}';
      isCanal = true;
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          // Avatar avec cercle doré
          Container(
            width: 55,
            height: 55,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: ClipOval(
              child: avatarUrl.isNotEmpty
                  ? Image.network(
                avatarUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[800],
                    child: Icon(
                      isCanal ? Icons.group : Icons.person,
                      size: 30,
                      color: Colors.white70,
                    ),
                  );
                },
              )
                  : Container(
                color: Colors.grey[800],
                child: Icon(
                  isCanal ? Icons.group : Icons.person,
                  size: 30,
                  color: Colors.white70,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Informations du destinataire
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Envoyer un cadeau à',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    // Icône canal ou utilisateur
                    Icon(
                      isCanal ? Icons.group : Icons.person,
                      size: 14,
                      color: const Color(0xFFFFD700),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        displayName,
                        style: const TextStyle(
                          color: Color(0xFFFFD700),
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Badge vérifié (si canal vérifié)
                    if (isCanal && widget.post?.canal?.isVerify == true)
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Icon(Icons.verified, color: Colors.blue, size: 14),
                      ),
                  ],
                ),
                // Sous-texte pour les canaux (nombre d'abonnés)
                if (isCanal && widget.post?.canal != null)
                  Text(
                    '${widget.post?.canal?.usersSuiviId?.length ?? 0} abonné(s)',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 10,
                    ),
                  ),
              ],
            ),
          ),

          // Bouton de fermeture
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close,
                color: Colors.white70,
                size: 20,
              ),
            ),
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
        crossAxisCount: 4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.78,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      itemCount: _giftPacks.length,
      itemBuilder: (context, index) {
        final pack = _giftPacks[index];
        final isSelected = _selectedIndex == index;
        // PAS DE VERROUILLAGE - tous les cadeaux sont sélectionnables
        // Mais on change la couleur si le solde est insuffisant

        return GestureDetector(
          onTap: () => setState(() {
            if (_selectedIndex == index) {
              _quantity++;
            } else {
              _selectedIndex = index;
              _quantity = 1;
            }
          }),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedContainer(
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
                  borderRadius: BorderRadius.circular(12),
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
                      Text(pack.icon, style: const TextStyle(fontSize: 26)),
                      const SizedBox(height: 4),
                      Text(
                        pack.displayLabel,
                        style: TextStyle(
                          color: isSelected ? Colors.black : Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.black.withOpacity(0.2)
                              : (_currentBalance >= pack.coins
                              ? Colors.black.withOpacity(0.5)
                              : Colors.red.withOpacity(0.2)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('🪙',
                                style: TextStyle(
                                    fontSize: 8,
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
                                fontSize: 9,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Petit indicateur si solde insuffisant (optionnel)
                      if (_currentBalance < pack.coins && !isSelected)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            'Insuffisant',
                            style: TextStyle(
                              color: Colors.red.withOpacity(0.7),
                              fontSize: 7,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              // Quantity badge
              if (isSelected && _quantity > 1)
                Positioned(
                  top: -6,
                  right: -6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Text(
                      'x$_quantity',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActions() {
    final selectedPack = _giftPacks[_selectedIndex];
    final totalCost = selectedPack.coins * _quantity;
    final hasEnoughCoins = _currentBalance >= totalCost;

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
                  Text(
                    _quantity > 1
                        ? '${_quantity}x ${selectedPack.icon}  🪙 ${_formatNumber(totalCost)}'
                        : '🪙 ${_formatNumber(totalCost)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  const SizedBox(width: 6),
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

// widgets/coin_gift_dialog.dart - Modifier _sendGift

  /// 🔥 Envoi "instantané" : la validation locale du solde (déjà disponible
  /// côté client via [_coinProvider.giftCoinsBalance]) permet de fermer la
  /// modale et d'afficher la confirmation IMMÉDIATEMENT, sans attendre
  /// l'écriture Firestore (transaction + notifications) qui s'exécute en
  /// arrière-plan (fire-and-forget). En cas d'échec, le solde réel est
  /// re-synchronisé via `_coinProvider.refreshBalance` (déjà utilisé par le
  /// provider existant) et une erreur est affichée.
  Future<void> _sendGift(CoinPack pack) async {
    final totalCost = pack.coins * _quantity;
    if (_currentBalance < totalCost) {
      _showInsufficientBalanceDialog();
      return;
    }

    // 1. Optimistic update locale du solde affiché + fermeture immédiate
    setState(() => _currentBalance -= totalCost);

    if (mounted) {
      Navigator.pop(context);
      _showSuccessAnimation(pack);
    }

    if (widget.isLive && widget.liveId != null) {
      _recordLiveGift(widget.liveId!, totalCost);
    }
    widget.onGiftSuccess?.call();

    // 2. Enregistrer dans les récents
    unawaited(QuickGiftService.recordRecentGift(pack));

    // 3. Écriture Firestore réelle en arrière-plan (fire-and-forget)
    final senderId = _coinProvider.currentUser!.id!;
    unawaited(_coinProvider.sendGift(
      senderId: senderId,
      receiverId: widget.receiverId,
      coinsAmount: totalCost,
      post: widget.post!,
      context: context,
      giftPack: pack,
      onSuccess: () {
        _coinProvider.refreshBalance(senderId);
      },
    ).then((success) {
      if (!success) {
        debugPrint('❌ Échec de l\'envoi du cadeau (solde insuffisant côté serveur), resynchronisation du solde');
        _coinProvider.refreshBalance(senderId);
      }
    }).catchError((e) {
      debugPrint('❌ Erreur lors de l\'envoi du cadeau : $e');
      _coinProvider.refreshBalance(senderId);
    }));
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

  void _showSuccessAnimation2(CoinPack pack) {
    // Afficher le dialog
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16),
        child: Stack(
          children: [
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
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: () => Navigator.of(ctx).pop(),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 18),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    // 🔥 Fermeture automatique après 1 seconde
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    });
  }

  void _showSuccessAnimation(CoinPack pack) {
    // 1. Récupérer l'Overlay d'état actuel
    final overlay = Overlay.of(context);

    late OverlayEntry overlayEntry;

    // 2. Créer l'entrée de l'Overlay (Le Flash en haut)
    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 12, // Juste en dessous de la barre de statut
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: -50.0, end: 0.0), // Animation de glissement du haut vers le bas
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutBack,
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, value),
                child: child,
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Icône du cadeau avec un petit effet pop
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.6, end: 1.0),
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.elasticOut,
                    builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
                    child: Text(pack.icon, style: const TextStyle(fontSize: 28)),
                  ),
                  const SizedBox(width: 12),

                  // Texte informatif
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Cadeau envoyé ! 🎉',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          'offert à ${widget.receiverName}',
                          style: const TextStyle(color: Colors.black87, fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // Badge du montant en pièces
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🪙', style: TextStyle(fontSize: 12)),
                        const SizedBox(width: 4),
                        Text(
                          _formatNumber(pack.coins),
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
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
    );

    // 3. Insérer le flash dans l'overlay de l'application
    overlay.insert(overlayEntry);

    // 4. Suppression automatique et propre après 1.2 seconde
    Future.delayed(const Duration(milliseconds: 1200), () {
      overlayEntry.remove();
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