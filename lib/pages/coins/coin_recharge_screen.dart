import 'package:afrotok/layout/centered_content.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/coin_pack.dart';
import '../../models/model_data.dart';
import '../../providers/authProvider.dart';
import '../../providers/coin_gift_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../paiement/newDepot.dart';
import '../../theme/app_colors.dart';

class CoinRechargeScreen extends StatefulWidget {
  const CoinRechargeScreen({Key? key}) : super(key: key);

  @override
  State<CoinRechargeScreen> createState() => _CoinRechargeScreenState();
}

class _CoinRechargeScreenState extends State<CoinRechargeScreen> {
  bool _isLoading = false;
  bool _isForOther = false;
  String _selectedBalance = 'votre_solde_depot';
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

  // ── Recherche utilisateur par email ───────────────────────────────────────

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
        setState(() { _isSearching = false; _userFound = false; });
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
      setState(() { _isSearching = false; _userFound = false; });
      _showErrorDialog('Erreur lors de la recherche : $e');
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final coinProvider = Provider.of<CoinGiftUserProvider>(context);
    final user = coinProvider.currentUser;
    final soldeDepot = user?.votre_solde_depot ?? 0.0;
    final soldePrincipal = user?.votre_solde_principal ?? 0.0;
    final currentUserBalance =
        _selectedBalance == 'votre_solde_depot' ? soldeDepot : soldePrincipal;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          'Acheter des pièces',
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: colors.surface,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: colors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: colors.divider),
        ),
      ),
      body: CenteredContent(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBalanceHeader(colors, user, soldeDepot, soldePrincipal),
              const SizedBox(height: 20),
              _buildBalanceSelector(colors, soldeDepot, soldePrincipal),
              const SizedBox(height: 16),
              _buildBeneficiaryToggle(colors),
              if (_isForOther) ...[
                const SizedBox(height: 14),
                _buildEmailForm(colors),
              ],
              const SizedBox(height: 28),
              _buildPacksHeader(colors),
              const SizedBox(height: 14),
              _buildCoinPacksGrid(coinProvider, user, currentUserBalance, colors),
              const SizedBox(height: 20),
              _buildRateInfo(colors),
            ],
          ),
        ),
      ),
    );
  }

  // ── En-tête soldes ────────────────────────────────────────────────────────

  Widget _buildBalanceHeader(AppColors colors, UserData? user, double depot, double principal) {
    final coins = user?.giftCoinsBalance ?? 0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.accent.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
            color: colors.accent.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Pièces actuelles
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text('🪙', style: TextStyle(fontSize: 28)),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Votre solde de pièces',
                    style: TextStyle(color: colors.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatNumber(coins),
                    style: TextStyle(
                      color: colors.accent,
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -1,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: colors.divider, height: 1),
          const SizedBox(height: 14),
          // Deux soldes FCFA
          Row(
            children: [
              Expanded(
                child: _buildMiniBalance(
                  colors,
                  label: 'Dépôt',
                  amount: depot,
                  color: const Color(0xFF34C759),
                  icon: Icons.savings_rounded,
                ),
              ),
              Container(width: 1, height: 36, color: colors.divider),
              Expanded(
                child: _buildMiniBalance(
                  colors,
                  label: 'Gains',
                  amount: principal,
                  color: colors.warning,
                  icon: Icons.account_balance_wallet_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniBalance(AppColors colors, {
    required String label,
    required double amount,
    required Color color,
    required IconData icon,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: colors.textSecondary, fontSize: 11)),
        const SizedBox(height: 2),
        Text(
          '${amount.toStringAsFixed(0)} FCFA',
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ],
    );
  }

  // ── Sélecteur de solde ────────────────────────────────────────────────────

  Widget _buildBalanceSelector(AppColors colors, double depot, double principal) {
    const green = Color(0xFF34C759);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Payer avec',
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildBalanceOption(
                colors: colors,
                label: 'Solde Dépôt',
                amount: depot,
                color: green,
                icon: Icons.savings_rounded,
                isSelected: _selectedBalance == 'votre_solde_depot',
                onTap: () => setState(() => _selectedBalance = 'votre_solde_depot'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildBalanceOption(
                colors: colors,
                label: 'Solde Gains',
                amount: principal,
                color: colors.warning,
                icon: Icons.account_balance_wallet_rounded,
                isSelected: _selectedBalance == 'votre_solde_principal',
                onTap: () => setState(() => _selectedBalance = 'votre_solde_principal'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBalanceOption({
    required AppColors colors,
    required String label,
    required double amount,
    required Color color,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : colors.surfaceVariant,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : colors.border,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: color.withOpacity(0.12), blurRadius: 10, offset: const Offset(0, 3))]
              : null,
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? color : colors.textSecondary, size: 22),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : colors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '${amount.toStringAsFixed(0)} FCFA',
              style: TextStyle(
                color: isSelected ? color : colors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(height: 4),
              Container(
                width: 20,
                height: 3,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Toggle bénéficiaire ───────────────────────────────────────────────────

  Widget _buildBeneficiaryToggle(AppColors colors) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Expanded(child: _buildToggleTab(colors, 'Pour moi', !_isForOther, () {
            setState(() {
              _isForOther = false;
              _targetUserId = null;
              _targetUserName = null;
              _targetUserAvatar = null;
              _userFound = false;
              _emailController.clear();
            });
          })),
          Expanded(child: _buildToggleTab(colors, 'Pour un autre', _isForOther, () {
            setState(() {
              _isForOther = true;
              _userFound = false;
              _targetUserId = null;
              _targetUserName = null;
              _targetUserAvatar = null;
            });
          })),
        ],
      ),
    );
  }

  Widget _buildToggleTab(AppColors colors, String label, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? colors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          boxShadow: isActive
              ? [BoxShadow(color: colors.accent.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 2))]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isActive ? colors.onAccent : colors.textSecondary,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  // ── Formulaire email ──────────────────────────────────────────────────────

  Widget _buildEmailForm(AppColors colors) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Email du destinataire',
            style: TextStyle(color: colors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: TextStyle(color: colors.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'exemple@email.com',
                    hintStyle: TextStyle(color: colors.textSecondary),
                    prefixIcon: Icon(Icons.alternate_email_rounded, color: colors.accent, size: 18),
                    filled: true,
                    fillColor: colors.surfaceVariant,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: colors.accent, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _isSearching ? null : _searchUser,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.accent,
                    foregroundColor: colors.onAccent,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSearching
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(colors.onAccent),
                          ),
                        )
                      : const Text('Vérifier', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
          if (_userFound && _targetUserName != null) ...[
            const SizedBox(height: 12),
            _buildFoundUserCard(colors),
          ],
        ],
      ),
    );
  }

  Widget _buildFoundUserCard(AppColors colors) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.primary.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: colors.surfaceVariant,
            backgroundImage: _targetUserAvatar != null && _targetUserAvatar!.isNotEmpty
                ? NetworkImage(_targetUserAvatar!)
                : null,
            child: _targetUserAvatar == null || _targetUserAvatar!.isEmpty
                ? Icon(Icons.person_rounded, size: 22, color: colors.textSecondary)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _targetUserName!,
                  style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Text(
                  _emailController.text,
                  style: TextStyle(color: colors.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: colors.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_rounded, color: colors.primary, size: 13),
                const SizedBox(width: 4),
                Text('Trouvé', style: TextStyle(color: colors.primary, fontSize: 10, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── En-tête section packs ─────────────────────────────────────────────────

  Widget _buildPacksHeader(AppColors colors) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colors.accent.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Text('🪙', style: TextStyle(fontSize: 16)),
        ),
        const SizedBox(width: 10),
        Text(
          'Choisissez votre pack',
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // ── Grille packs ──────────────────────────────────────────────────────────

  Widget _buildCoinPacksGrid(
    CoinGiftUserProvider coinProvider,
    UserData? user,
    double currentUserBalance,
    AppColors colors,
  ) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.72,
      ),
      itemCount: _rechargePacks.length,
      itemBuilder: (context, index) {
        final pack = _rechargePacks[index];
        final isAffordable = currentUserBalance >= pack.priceFcfa;
        final canPurchase = _isForOther ? _userFound : true;
        return _buildPackCard(pack, coinProvider, user, isAffordable, canPurchase, colors);
      },
    );
  }

  Widget _buildPackCard(
    CoinPack pack,
    CoinGiftUserProvider coinProvider,
    UserData? user,
    bool isAffordable,
    bool canPurchase,
    AppColors colors,
  ) {
    final isDisabled = !isAffordable || !canPurchase || _isLoading;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: pack.isPopular
              ? colors.accent
              : isAffordable
                  ? colors.border
                  : colors.border.withOpacity(0.4),
          width: pack.isPopular ? 1.5 : 1,
        ),
        boxShadow: pack.isPopular
            ? [BoxShadow(color: colors.accent.withOpacity(0.12), blurRadius: 12, offset: const Offset(0, 4))]
            : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Stack(
        children: [
          // Fond subtil pour les packs populaires
          if (pack.isPopular)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colors.accent.withOpacity(0.06),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

          Padding(
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  children: [
                    // Icône pack
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: pack.isPopular
                            ? colors.accent.withOpacity(0.12)
                            : colors.surfaceVariant,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(pack.icon, style: const TextStyle(fontSize: 30)),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Nom du pack
                    Text(
                      pack.label,
                      style: TextStyle(
                        color: pack.isPopular ? colors.accent : colors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),

                    // Nombre de pièces
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        const Text('🪙', style: TextStyle(fontSize: 13)),
                        const SizedBox(width: 3),
                        Text(
                          _formatNumber(pack.coins),
                          style: TextStyle(
                            color: pack.isPopular ? colors.accent : colors.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Prix FCFA
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isAffordable
                            ? colors.surfaceVariant
                            : colors.danger.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${pack.priceFcfa.toInt()} FCFA',
                        style: TextStyle(
                          color: isAffordable ? colors.textSecondary : colors.danger,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),

                // Bouton Acheter
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isDisabled ? null : () => _processPurchase(pack, coinProvider, user),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDisabled
                          ? colors.surfaceVariant
                          : pack.isPopular
                              ? colors.accent
                              : colors.primary,
                      foregroundColor: isDisabled
                          ? colors.textSecondary
                          : pack.isPopular
                              ? colors.onAccent
                              : colors.onPrimary,
                      disabledBackgroundColor: colors.surfaceVariant,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      isAffordable ? 'Acheter' : 'Insuffisant',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Badge populaire
          if (pack.isPopular && pack.popularLabel != null)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: colors.accent,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(20),
                    bottomLeft: Radius.circular(12),
                  ),
                ),
                child: Text(
                  pack.popularLabel!,
                  style: TextStyle(
                    color: colors.onAccent,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Info taux ─────────────────────────────────────────────────────────────

  Widget _buildRateInfo(AppColors colors) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: colors.textSecondary, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '10 FCFA = 25 pièces · Minimum 500 pièces · Recharge instantanée',
              style: TextStyle(color: colors.textSecondary, fontSize: 12, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  // ── Logique d'achat ───────────────────────────────────────────────────────

  Future<void> _processPurchase(CoinPack pack, CoinGiftUserProvider coinProvider, UserData? user) async {
    final soldeDepot = user?.votre_solde_depot ?? 0.0;
    final soldePrincipal = user?.votre_solde_principal ?? 0.0;
    final currentUserBalance = _selectedBalance == 'votre_solde_depot' ? soldeDepot : soldePrincipal;

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
      final payerUserId = authProvider.loginUserData!.id!;
      final receiverUserId = _isForOther ? _targetUserId! : payerUserId;

      final success = await coinProvider.purchaseCoins(
        userPaid: payerUserId,
        userReceived: receiverUserId,
        coinsAmount: pack.coins,
        fcfaCost: pack.priceFcfa,
        context: context,
        balanceKey: _selectedBalance,
      );

      await authProvider.refreshUserData();

      if (mounted && success) {
        _showSuccessDialog(pack, _isForOther ? _emailController.text : '');
        if (!_isForOther) {
          setState(() => _isLoading = false);
        } else {
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

  // ── Dialogs ───────────────────────────────────────────────────────────────

  void _showInsufficientFcfaDialog() {
    final colors = AppColors.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.account_balance_wallet_rounded, color: colors.accent, size: 22),
            const SizedBox(width: 8),
            Text('Solde insuffisant', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text(
          'Votre solde sélectionné est insuffisant pour cet achat. Rechargez votre solde de dépôt.',
          style: TextStyle(color: colors.textSecondary, fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Annuler', style: TextStyle(color: colors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const DepositScreen()));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.accent,
              foregroundColor: colors.onAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: const Text('Recharger', style: TextStyle(fontWeight: FontWeight.bold)),
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
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2ECC71), Color(0xFF1FAA59)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 64),
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
                style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                pack.icon,
                style: const TextStyle(fontSize: 32),
              ),
            ],
          ),
        ),
      ),
    );
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      Navigator.pop(context);
      if (!_isForOther) {
        Navigator.pop(context);
      } else {
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
    final colors = AppColors.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Icon(Icons.error_outline_rounded, color: colors.danger, size: 20),
            const SizedBox(width: 8),
            Text('Erreur', style: TextStyle(color: colors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(message, style: TextStyle(color: colors.textSecondary, fontSize: 14)),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.surfaceVariant,
              foregroundColor: colors.textPrimary,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  String _formatNumber(int num) => num.toString();
}
