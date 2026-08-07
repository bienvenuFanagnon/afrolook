import 'package:afrotok/layout/centered_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/model_data.dart';
import '../../providers/authProvider.dart';
import '../../providers/coin_gift_provider.dart';
import '../../services/coin_gift_service.dart';
import '../../theme/app_colors.dart';

class CoinConversionPage extends StatefulWidget {
  const CoinConversionPage({Key? key}) : super(key: key);

  @override
  State<CoinConversionPage> createState() => _CoinConversionPageState();
}

class _CoinConversionPageState extends State<CoinConversionPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _coinsController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  bool _isLoading = false;
  int _coinsBalance = 0;
  int _coinsToConvert = 0;
  double _fcfaToGet = 0;
  String _errorMessage = '';

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  static const int _minCoins = 100;
  static const double _rate = 0.4; // 25 pièces = 10 FCFA

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );
    _loadBalance();
  }

  @override
  void dispose() {
    _coinsController.dispose();
    _focusNode.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadBalance() async {
    final authPro = Provider.of<UserAuthProvider>(context, listen: false);
    final coinProvider = Provider.of<CoinGiftUserProvider>(context, listen: false);
    await coinProvider.refreshBalance(authPro.loginUserData!.id!);
    final user = coinProvider.currentUser;
    if (user != null) {
      setState(() => _coinsBalance = user.giftCoinsBalance ?? 0);
    }
  }

  void _updateConversion(String value) {
    setState(() {
      _errorMessage = '';
      if (value.isEmpty) {
        _coinsToConvert = 0;
        _fcfaToGet = 0;
        return;
      }
      final parsed = int.tryParse(value);
      if (parsed == null) {
        _errorMessage = 'Veuillez entrer un nombre valide';
        _coinsToConvert = 0;
        _fcfaToGet = 0;
        return;
      }
      if (parsed > _coinsBalance) {
        _errorMessage = 'Maximum disponible : ${_fmt(_coinsBalance)} pièces';
        _coinsToConvert = 0;
        _fcfaToGet = 0;
      } else if (parsed < _minCoins) {
        _errorMessage = 'Minimum $_minCoins pièces par conversion';
        _coinsToConvert = 0;
        _fcfaToGet = 0;
      } else {
        _coinsToConvert = parsed;
        _fcfaToGet = parsed * _rate;
        _pulseController.forward().then((_) => _pulseController.reverse());
      }
    });
  }

  void _setQuickAmount(int amount) {
    _coinsController.text = amount.toString();
    _updateConversion(amount.toString());
    _focusNode.unfocus();
  }

  Future<void> _convertCoins() async {
    if (_coinsToConvert < _minCoins) return;
    setState(() => _isLoading = true);
    try {
      final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
      await CoinGiftService.convertCoinsToFcfa(
        userId: authProvider.loginUserData!.id!,
        coinsAmount: _coinsToConvert,
        firestore: FirebaseFirestore.instance,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Conversion réussie !'),
          backgroundColor: Color(0xFF2ECC71),
          duration: Duration(seconds: 3),
        ),
      );
      await _loadBalance();
      _coinsController.clear();
      setState(() {
        _coinsToConvert = 0;
        _fcfaToGet = 0;
      });
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Erreur : $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _fmt(int num) => num.toString();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final canConvert = _coinsToConvert >= _minCoins && !_isLoading;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          'Convertir en FCFA',
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
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBalanceHero(colors),
              const SizedBox(height: 20),
              _buildRateBar(colors),
              const SizedBox(height: 28),
              _buildInputSection(colors),
              const SizedBox(height: 14),
              _buildQuickAmounts(colors),
              const SizedBox(height: 24),
              _buildPreviewCard(colors, canConvert),
              const SizedBox(height: 32),
              _buildConvertButton(colors, canConvert),
              const SizedBox(height: 16),
              _buildInfoFooter(colors),
            ],
          ),
        ),
      ),
    );
  }

  // ── Balance hero ──────────────────────────────────────────────────────────

  Widget _buildBalanceHero(AppColors colors) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.accent.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
            color: colors.accent.withOpacity(0.07),
            blurRadius: 24,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [colors.accent.withOpacity(0.25), colors.accent.withOpacity(0.05)],
              ),
              shape: BoxShape.circle,
            ),
            child: const Center(child: Text('🪙', style: TextStyle(fontSize: 38))),
          ),
          const SizedBox(height: 18),
          Text(
            'Solde de pièces',
            style: TextStyle(color: colors.textSecondary, fontSize: 13, letterSpacing: 0.3),
          ),
          const SizedBox(height: 6),
          Text(
            _fmt(_coinsBalance),
            style: TextStyle(
              color: colors.accent,
              fontSize: 46,
              fontWeight: FontWeight.bold,
              letterSpacing: -2,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: colors.accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'pièces disponibles',
              style: TextStyle(color: colors.accent, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // ── Taux ─────────────────────────────────────────────────────────────────

  Widget _buildRateBar(AppColors colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: colors.primary.withOpacity(0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.primary.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🪙', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 6),
          Text(
            '25 pièces',
            style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(width: 12),
          Icon(Icons.east_rounded, color: colors.primary, size: 18),
          const SizedBox(width: 12),
          Text(
            '10 FCFA',
            style: TextStyle(color: colors.primary, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: colors.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'Taux fixe',
              style: TextStyle(color: colors.primary, fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  // ── Champ de saisie ───────────────────────────────────────────────────────

  Widget _buildInputSection(AppColors colors) {
    final hasError = _errorMessage.isNotEmpty;
    final isValid = _coinsToConvert >= _minCoins;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pièces à convertir',
          style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600, fontSize: 15),
        ),
        const SizedBox(height: 10),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: hasError
                  ? colors.danger
                  : isValid
                      ? colors.primary
                      : colors.border,
              width: (hasError || isValid) ? 1.5 : 1,
            ),
            boxShadow: isValid
                ? [BoxShadow(color: colors.primary.withOpacity(0.1), blurRadius: 12, offset: const Offset(0, 4))]
                : null,
          ),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 8, 0),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: hasError
                        ? colors.danger.withOpacity(0.1)
                        : isValid
                            ? colors.primary.withOpacity(0.1)
                            : colors.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('🪙', style: TextStyle(fontSize: 22)),
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _coinsController,
                  focusNode: _focusNode,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                  decoration: InputDecoration(
                    hintText: '0',
                    hintStyle: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 26,
                      fontWeight: FontWeight.w300,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 18),
                  ),
                  onChanged: _updateConversion,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 18),
                child: Text(
                  'pièces',
                  style: TextStyle(color: colors.textSecondary, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          child: hasError
              ? Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline_rounded, color: colors.danger, size: 14),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          _errorMessage,
                          style: TextStyle(color: colors.danger, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  // ── Montants rapides ──────────────────────────────────────────────────────

  Widget _buildQuickAmounts(AppColors colors) {
    final quickAmounts = <int>[100, 500, 1000, 5000];
    return Wrap(
      spacing: 8,
      children: [
        Text('Rapide :', style: TextStyle(color: colors.textSecondary, fontSize: 12)),
        ...quickAmounts.where((a) => a <= _coinsBalance).map((amount) {
          final isSelected = _coinsToConvert == amount;
          return GestureDetector(
            onTap: () => _setQuickAmount(amount),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? colors.primary : colors.surfaceVariant,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isSelected ? colors.primary : colors.border),
              ),
              child: Text(
                _fmt(amount),
                style: TextStyle(
                  color: isSelected ? colors.onPrimary : colors.textPrimary,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          );
        }),
        if (_coinsBalance > 5000)
          GestureDetector(
            onTap: () => _setQuickAmount(_coinsBalance),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _coinsToConvert == _coinsBalance ? colors.primary : colors.surfaceVariant,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _coinsToConvert == _coinsBalance ? colors.primary : colors.border,
                ),
              ),
              child: Text(
                'Tout',
                style: TextStyle(
                  color: _coinsToConvert == _coinsBalance ? colors.onPrimary : colors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ── Aperçu résultat ───────────────────────────────────────────────────────

  Widget _buildPreviewCard(AppColors colors, bool canConvert) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
      decoration: BoxDecoration(
        color: canConvert ? colors.primary.withOpacity(0.07) : colors.surfaceVariant,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: canConvert ? colors.primary.withOpacity(0.35) : colors.border,
          width: canConvert ? 1.5 : 1,
        ),
        boxShadow: canConvert
            ? [BoxShadow(color: colors.primary.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 6))]
            : null,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.south_rounded,
                color: canConvert ? colors.primary : colors.textSecondary,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                'Vous recevrez',
                style: TextStyle(
                  color: canConvert ? colors.textPrimary : colors.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ScaleTransition(
            scale: canConvert ? _pulseAnimation : const AlwaysStoppedAnimation(1.0),
            child: Text(
              canConvert ? '${_fcfaToGet.toStringAsFixed(0)} FCFA' : '— FCFA',
              style: TextStyle(
                color: canConvert ? colors.primary : colors.textSecondary,
                fontSize: 40,
                fontWeight: FontWeight.bold,
                letterSpacing: -1.5,
                height: 1,
              ),
            ),
          ),
          if (canConvert) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${_fmt(_coinsToConvert)} pièces',
                  style: TextStyle(color: colors.textSecondary, fontSize: 12),
                ),
                const SizedBox(width: 6),
                Icon(Icons.arrow_forward_rounded, color: colors.textSecondary, size: 12),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: colors.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Solde Gains',
                    style: TextStyle(color: colors.primary, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── Bouton convertir ──────────────────────────────────────────────────────

  Widget _buildConvertButton(AppColors colors, bool canConvert) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: canConvert ? _convertCoins : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: canConvert ? colors.accent : colors.surfaceVariant,
          foregroundColor: colors.onAccent,
          disabledBackgroundColor: colors.surfaceVariant,
          disabledForegroundColor: colors.textSecondary,
          elevation: canConvert ? 2 : 0,
          shadowColor: colors.accent.withOpacity(0.3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        child: _isLoading
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation(colors.onAccent),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('🪙', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 10),
                  Text(
                    'Convertir maintenant',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: canConvert ? colors.onAccent : colors.textSecondary,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // ── Info footer ───────────────────────────────────────────────────────────

  Widget _buildInfoFooter(AppColors colors) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: colors.textSecondary, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Minimum $_minCoins pièces par conversion. '
              'Le montant FCFA est ajouté à votre Solde Gains.',
              style: TextStyle(color: colors.textSecondary, fontSize: 12, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
