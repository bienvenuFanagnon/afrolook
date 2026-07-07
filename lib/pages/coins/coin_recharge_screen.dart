// widgets/coin_recharge_screen.dart
import 'package:afrotok/layout/centered_content.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/coin_pack.dart';
import '../../models/model_data.dart';
import '../../providers/authProvider.dart';
import '../../providers/coin_gift_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/coin_gift_service.dart';
import '../paiement/newDepot.dart';

class CoinRechargeScreen extends StatefulWidget {
  const CoinRechargeScreen({Key? key}) : super(key: key);

  @override
  State<CoinRechargeScreen> createState() => _CoinRechargeScreenState();
}

class _CoinRechargeScreenState extends State<CoinRechargeScreen> {
  bool _isLoading = false;
  bool _isForOther = false;
  final TextEditingController _emailController = TextEditingController();
  String? _targetUserId;
  String? _targetUserName;
  String? _targetUserAvatar;
  bool _isSearching = false;
  bool _userFound = false;

  final List<CoinPack> _rechargePacks = CoinPack.rechargePacks;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  // Rechercher l'utilisateur par email
  Future<void> _searchUser() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showErrorDialog('Veuillez entrer un email');
      return;
    }

    setState(() {
      _isSearching = true;
      _userFound = false;
      _targetUserId = null;
      _targetUserName = null;
      _targetUserAvatar = null;
    });

    try {
      final query = await FirebaseFirestore.instance
          .collection('Users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        setState(() {
          _isSearching = false;
          _userFound = false;
        });
        _showErrorDialog('Aucun utilisateur trouvé avec cet email');
        return;
      }

      final userDoc = query.docs.first;
      setState(() {
        _targetUserId = userDoc.id;
        _targetUserName = userDoc.data()['pseudo'] ?? 'Utilisateur';
        _targetUserAvatar = userDoc.data()['imageUrl'];
        _userFound = true;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _isSearching = false;
        _userFound = false;
      });
      _showErrorDialog('Erreur lors de la recherche : $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final coinProvider = Provider.of<CoinGiftUserProvider>(context);
    final authProvider = Provider.of<UserAuthProvider>(context);
    final user = coinProvider.currentUser;
    final currentUserBalance = user?.votre_solde_principal ?? 0.0;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'Acheter des pièces',
          style: TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFFFFD700)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: CenteredContent(child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Solde actuel (utilisateur courant)
            _buildCurrentBalance(user),
            const SizedBox(height: 20),

            // Switch pour recharge pour soi ou pour autre
            _buildRechargeTypeSwitch(),

            if (_isForOther) ...[
              const SizedBox(height: 16),
              _buildOtherUserForm(),
              const SizedBox(height: 16),
              // Affichage du profil du destinataire si trouvé
              if (_userFound && _targetUserName != null)
                _buildTargetUserProfile(),
            ],

            const SizedBox(height: 24),

            // Titre avec icône
            Row(
              children: [
                const Icon(Icons.local_offer, color: Color(0xFFFFD700), size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Choisissez votre pack',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Grille des packs
            _buildCoinPacksGrid(coinProvider, user, currentUserBalance),

            const SizedBox(height: 20),

            // Info sur la conversion
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.amber.shade900.withOpacity(0.2), Colors.amber.shade800.withOpacity(0.1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD700).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.info_outline, color: Color(0xFFFFD700), size: 16),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      '10 FCFA = 25 pièces • Minimum 500 pièces par recharge • Recharge instantanée',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      )),
    );
  }

  Widget _buildCurrentBalance(UserData? user) {
    final balance = user?.giftCoinsBalance ?? 0;
    final principalBalance = user?.votre_solde_principal ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1A1A), Color(0xFF2D2D2D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFD700), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD700).withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD700).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text('🪙', style: TextStyle(fontSize: 28)),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Votre solde', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      Text('de pièces', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  _formatNumber(balance),
                  style: const TextStyle(
                    color: Color(0xFFFFD700),
                    fontWeight: FontWeight.bold,
                    fontSize: 28,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: DateTime.now().day == 1 ? MainAxisAlignment.spaceBetween : MainAxisAlignment.end,
            children: [
              if (DateTime.now().day == 1)
                const Text(
                  'Solde FCFA',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              Text(
                '${principalBalance.toStringAsFixed(0)} FCFA',
                style: const TextStyle(
                  color: Color(0xFF00CC66),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTargetUserProfile() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A2E1A), Color(0xFF0D1A0D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF00CC66).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFFFD700), width: 2),
            ),
            child: ClipOval(
              child: _targetUserAvatar != null && _targetUserAvatar!.isNotEmpty
                  ? Image.network(_targetUserAvatar!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 30))
                  : const Icon(Icons.person, size: 30, color: Colors.white70),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Destinataire',
                  style: TextStyle(color: Colors.white54, fontSize: 10),
                ),
                const SizedBox(height: 4),
                Text(
                  _targetUserName!,
                  style: const TextStyle(
                    color: Color(0xFFFFD700),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  _emailController.text,
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 14),
                SizedBox(width: 4),
                Text(
                  'Confirmé',
                  style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRechargeTypeSwitch() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _isForOther = false;
                  _targetUserId = null;
                  _targetUserName = null;
                  _targetUserAvatar = null;
                  _userFound = false;
                  _emailController.clear();
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: !_isForOther ? const Color(0xFFFFD700) : Colors.transparent,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Center(
                  child: Text(
                    'Pour moi',
                    style: TextStyle(
                      color: !_isForOther ? Colors.black : Colors.white70,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _isForOther = true;
                  _userFound = false;
                  _targetUserId = null;
                  _targetUserName = null;
                  _targetUserAvatar = null;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _isForOther ? const Color(0xFFFFD700) : Colors.transparent,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Center(
                  child: Text(
                    'Pour un autre',
                    style: TextStyle(
                      color: _isForOther ? Colors.black : Colors.white70,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtherUserForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Email du destinataire', style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _emailController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'exemple@email.com',
                    hintStyle: const TextStyle(color: Colors.white38),
                    prefixIcon: const Icon(Icons.email, color: Color(0xFFFFD700), size: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.white24),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.white24),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFFFD700)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSearching ? null : _searchUser,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD700),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSearching
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Text('Vérifier'),
                ),
              ),
            ],
          ),
          if (_userFound && _targetUserName != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Utilisateur trouvé : $_targetUserName',
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCoinPacksGrid(CoinGiftUserProvider coinProvider, UserData? user, double currentUserBalance) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 0.7,
      ),
      itemCount: _rechargePacks.length,
      itemBuilder: (context, index) {
        final pack = _rechargePacks[index];
        final isAffordable = currentUserBalance >= pack.priceFcfa;
        final canPurchase = _isForOther ? _userFound : true;

        return _buildCoinPackCard(pack, coinProvider, user, isAffordable, canPurchase);
      },
    );
  }

  Widget _buildCoinPackCard(CoinPack pack, CoinGiftUserProvider coinProvider, UserData? user, bool isAffordable, bool canPurchase) {
    return Container(
      decoration: BoxDecoration(
        gradient: pack.isPopular
            ? LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFFFD700).withOpacity(0.15),
            const Color(0xFFFFA500).withOpacity(0.1),
          ],
        )
            : const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2D2D2D), Color(0xFF1A1A1A)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: pack.isPopular
              ? const Color(0xFFFFD700)
              : const Color(0xFFFFD700).withOpacity(0.3),
          width: pack.isPopular ? 2 : 1,
        ),
        boxShadow: pack.isPopular
            ? [
          BoxShadow(
            color: const Color(0xFFFFD700).withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ]
            : null,
      ),
      child: Stack(
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: pack.isPopular
                      ? const Color(0xFFFFD700).withOpacity(0.2)
                      : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Text(pack.icon, style: const TextStyle(fontSize: 36)),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('🪙', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 4),
                  Text(
                    _formatNumber(pack.coins),
                    style: TextStyle(
                      color: pack.isPopular ? const Color(0xFFFFD700) : Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: pack.isPopular ? 22 : 18,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                pack.label,
                style: TextStyle(
                  color: pack.isPopular ? const Color(0xFFFFD700) : Colors.white70,
                  fontSize: pack.isPopular ? 12 : 11,
                  fontWeight: pack.isPopular ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${pack.priceFcfa.toInt()} FCFA',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: 100,
                child: ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : () => _processPurchase(pack, coinProvider, user),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: pack.isPopular
                        ? const Color(0xFFFFD700)
                        : Colors.green,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: Text(
                     'Acheter',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),              const SizedBox(height: 12),
            ],
          ),
          if (pack.isPopular && pack.popularLabel != null)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star, size: 10, color: Colors.black),
                    const SizedBox(width: 4),
                    Text(
                      pack.popularLabel!,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _processPurchase(CoinPack pack, CoinGiftUserProvider coinProvider, UserData? user) async {
    final currentUserBalance = user?.votre_solde_principal ?? 0.0;

    if (currentUserBalance < pack.priceFcfa) {
      _showInsufficientFcfaDialog();
      return;
    }

    if (_isForOther && !_userFound) {
      _showErrorDialog('Veuillez d\'abord vérifier l\'email du destinataire');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
      final payerUserId = authProvider.loginUserData!.id!;  // 🔥 Celui qui paie (utilisateur connecté)

      // 🔥 Destinataire des pièces
      final receiverUserId = _isForOther ? _targetUserId! : payerUserId;

      // Appel unique qui gère les deux cas
      final success = await coinProvider.purchaseCoins(
        userPaid: payerUserId,
        userReceived: receiverUserId,
        coinsAmount: pack.coins,
        fcfaCost: pack.priceFcfa,
        context: context,
      );

      // Rafraîchir l'authProvider
      await authProvider.refreshUserData();

      if (mounted && success) {
        _showSuccessDialog(pack, _isForOther ? _emailController.text : '');
        if (!_isForOther) {
          setState(() => _isLoading = false);
        } else {
          // Réinitialiser le formulaire
          setState(() {
            _isLoading = false;
            _userFound = false;
            _targetUserId = null;
            _targetUserName = null;
            _targetUserAvatar = null;
            _emailController.clear();
          });
        }
      } else if (mounted && !success) {
        _showErrorDialog('Erreur lors de l\'achat');
        setState(() => _isLoading = false);
      }
    } catch (e) {
      _showErrorDialog('Erreur : $e');
      setState(() => _isLoading = false);
    }
  }
  void _showInsufficientFcfaDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Solde FCFA insuffisant', style: TextStyle(color: Colors.yellow)),
        content: const Text('Votre solde principal est insuffisant pour cet achat.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const DepositScreen()),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFD700)),
            child: const Text('Déposer de l\'argent', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(CoinPack pack, String email) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)]),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 60),
              const SizedBox(height: 16),
              const Text(
                'Recharge réussie !',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
              ),
              const SizedBox(height: 8),
              Text(
                _isForOther
                    ? '${_formatNumber(pack.coins)} pièces envoyées à $email'
                    : '${_formatNumber(pack.coins)} pièces ajoutées à votre compte',
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
    Future.delayed(const Duration(seconds: 2), () {
      Navigator.pop(context);
      if (!_isForOther) {
        Navigator.pop(context);
      } else {
        // Réinitialiser après recharge pour autre
        setState(() {
          _isLoading = false;
          _userFound = false;
          _targetUserId = null;
          _targetUserName = null;
          _targetUserAvatar = null;
          _emailController.clear();
        });
      }
    });
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Erreur', style: TextStyle(color: Colors.red)),
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  String _formatNumber(int num) {
    // if (num >= 1000000) return '${(num / 1000000).toStringAsFixed(1)}M';
    // if (num >= 1000) return '${(num / 1000).toStringAsFixed(1)}K';
    return num.toString();
  }
}