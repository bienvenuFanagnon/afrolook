import 'package:afrotok/layout/centered_content.dart';
import 'package:afrotok/pages/user/UserRetrait/userRetraitForm.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/model_data.dart';
import '../coins/coin_recharge_screen.dart';
import '../paiement/newDepot.dart';
import '../paiement/feexpay/pendingTransactionsScreen.dart';
import 'UserRetrait/userRetraitListe.dart';
import 'coin_conversion_page.dart';
import '../../../providers/authProvider.dart';
import '../../../providers/postProvider.dart';
import '../../../theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';

class MonetisationPage extends StatefulWidget {
  @override
  _MonetisationPageState createState() => _MonetisationPageState();
}

class _MonetisationPageState extends State<MonetisationPage> {
  late UserAuthProvider authProvider;
  late PostProvider postProvider;
  Stream<UserData>? userStream;

  @override
  void initState() {
    super.initState();
    authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    postProvider = Provider.of<PostProvider>(context, listen: false);
    userStream = authProvider.getUserStream();
  }

  void refreshUser() {
    setState(() {
      userStream = authProvider.getUserStream();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final t = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          t.profileMenuMonetization,
          style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: colors.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: colors.textPrimary),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: colors.primary),
            onPressed: refreshUser,
            tooltip: t.commonRefresh,
          ),
        ],
      ),
      body: StreamBuilder<UserData>(
        stream: userStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
              ),
            );
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
              child: Text(
                t.commonLoadingError,
                style: TextStyle(color: colors.danger),
              ),
            );
          }

          final user = snapshot.data!;
          final double soldePrincipal = user.votre_solde_principal ?? 0;
          final double soldeDepot = user.votre_solde_depot ?? 0;
          final int giftCoinsBalance = user.giftCoinsBalance ?? 0;
          final double creatorScore = user.creatorScore ?? 0.0;
          final int totalViews = user.totalPostUniqueViews ?? 0;
          final int creditedViews = user.totalViewsEarningsCredited ?? 0;

          return CenteredContent(child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSoldePrincipalCard(soldePrincipal, colors, t),
                const SizedBox(height: 16),
                _buildSoldeDepotCard(soldeDepot, colors),
                const SizedBox(height: 16),
                _buildViewEarningsCard(creatorScore, totalViews, creditedViews, colors),
                const SizedBox(height: 16),
                _buildCoinsCard(giftCoinsBalance, colors, t),
                const SizedBox(height: 16),
                _buildConversionSection(giftCoinsBalance, colors, t),
                const SizedBox(height: 24),
                _buildTransactionHeader(colors, t),
                const SizedBox(height: 16),
                _buildTransactionList(user.id!, colors, t),
              ],
            ),
          ));
        },
      ),
    );
  }

  // ── Carte Revenus des vues ────────────────────────────────────────────────

  static const _scoreTiers = [
    {'minScore': 80.0, 'multiplier': 1.00, 'label': 'Élite',    'color': 0xFF22C55E},
    {'minScore': 50.0, 'multiplier': 0.80, 'label': 'Expert',   'color': 0xFF3B82F6},
    {'minScore': 25.0, 'multiplier': 0.60, 'label': 'Avancé',   'color': 0xFFF97316},
    {'minScore': 10.0, 'multiplier': 0.40, 'label': 'Standard', 'color': 0xFFF59E0B},
    {'minScore':  0.0, 'multiplier': 0.20, 'label': 'Débutant', 'color': 0xFF94A3B8},
  ];

  Map<String, dynamic> _getTier(double score) {
    for (final t in _scoreTiers) {
      if (score >= (t['minScore'] as double)) return t;
    }
    return _scoreTiers.last;
  }

  Widget _buildViewEarningsCard(
    double creatorScore,
    int totalViews,
    int creditedViews,
    AppColors colors,
  ) {
    const double baseRate = 1.0; // FCFA max (taux de base actuel)
    final tier = _getTier(creatorScore);
    final double multiplier = tier['multiplier'] as double;
    final String tierLabel = tier['label'] as String;
    final Color tierColor = Color(tier['color'] as int);
    final double myRate = baseRate * multiplier;
    final int pendingViews = (totalViews - creditedViews).clamp(0, totalViews);
    final double pendingEarnings = pendingViews * myRate;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tierColor.withOpacity(0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: tierColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.play_circle_outline, color: tierColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'REVENUS DES VUES',
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.textSecondary,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: tierColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  tierLabel,
                  style: TextStyle(
                    color: tierColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Taux actuel
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${myRate.toStringAsFixed(2)} FCFA',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: tierColor,
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '/ vue',
                  style: TextStyle(fontSize: 13, color: colors.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Score créateur : ${creatorScore.toStringAsFixed(1)} pts  ·  ${(multiplier * 100).toStringAsFixed(0)}% du taux de base (${baseRate.toStringAsFixed(0)} FCFA max)',
            style: TextStyle(fontSize: 11, color: colors.textSecondary),
          ),

          const SizedBox(height: 14),
          Divider(color: colors.divider, height: 1),
          const SizedBox(height: 14),

          // Statistiques vues
          Row(
            children: [
              Expanded(
                child: _viewStat(
                  icon: Icons.remove_red_eye_outlined,
                  label: 'Vues totales',
                  value: totalViews.toString(),
                  color: colors.textSecondary,
                  colors: colors,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _viewStat(
                  icon: Icons.schedule_outlined,
                  label: 'En attente',
                  value: pendingViews.toString(),
                  color: tierColor,
                  colors: colors,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _viewStat(
                  icon: Icons.trending_up,
                  label: 'Prochain crédit',
                  value: '${pendingEarnings.toStringAsFixed(2)} F',
                  color: tierColor,
                  colors: colors,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Paliers
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Paliers de rémunération',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: colors.textSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                ..._scoreTiers.map((t) {
                  final tColor = Color(t['color'] as int);
                  final tMulti = t['multiplier'] as double;
                  final tLabel = t['label'] as String;
                  final tMin = t['minScore'] as double;
                  final isActive = tierLabel == tLabel;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 8, height: 8,
                          decoration: BoxDecoration(
                            color: isActive ? tColor : tColor.withOpacity(0.4),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '$tLabel  (score ≥ ${tMin.toStringAsFixed(0)})',
                            style: TextStyle(
                              fontSize: 11,
                              color: isActive ? colors.textPrimary : colors.textSecondary,
                              fontWeight: isActive ? FontWeight.w700 : FontWeight.normal,
                            ),
                          ),
                        ),
                        Text(
                          '${(tMulti * baseRate).toStringAsFixed(2)} FCFA/vue',
                          style: TextStyle(
                            fontSize: 11,
                            color: isActive ? tColor : colors.textSecondary,
                            fontWeight: isActive ? FontWeight.w700 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),

          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 13, color: colors.textSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Les gains sont crédités automatiquement chaque jour sur ton solde principal. '
                  'Le taux de base (actuellement ${baseRate.toStringAsFixed(0)} FCFA/vue) peut être ajusté à tout moment par Afrolook. '
                  'Améliore ton score en publiant du contenu apprécié et engage ta communauté.',
                  style: TextStyle(fontSize: 10, color: colors.textSecondary, height: 1.4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _viewStat({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required AppColors colors,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: colors.textSecondary),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildSoldeDepotCard(double soldeDepot, AppColors colors) {
    const green = Color(0xFF34C759);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: green.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: green.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.savings_rounded, color: green, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'SOLDE DE DÉPÔT',
                style: TextStyle(
                  fontSize: 12,
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '${soldeDepot.toStringAsFixed(2)} FCFA',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: green,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Abonnements · Pièces · Canaux · Groupes',
            style: TextStyle(fontSize: 12, color: colors.textSecondary),
          ),
          const SizedBox(height: 8),
          Divider(color: colors.divider, height: 1),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DepositScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_circle_outline, size: 18, color: Colors.white),
                  SizedBox(width: 6),
                  Text('Recharger', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSoldePrincipalCard(double soldePrincipal, AppColors colors, AppLocalizations t) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.primary.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colors.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.account_balance_wallet, color: colors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                t.monetMainBalance,
                style: TextStyle(
                  fontSize: 12,
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            "${soldePrincipal.toStringAsFixed(2)} FCFA",
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: colors.primary,
            ),
          ),
          const SizedBox(height: 8),
          Divider(color: colors.divider, height: 1),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => UserRetraitListPage()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.danger,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.arrow_upward, size: 18, color: Colors.white),
                  const SizedBox(width: 6),
                  Text(t.monetWithdraw, style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => PendingTransactionsScreen()),
                );
              },
              icon: const Icon(Icons.pending_actions, size: 18),
              label: Text(t.monetPendingTx, style: const TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.warning,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoinsCard(int giftCoinsBalance, AppColors colors, AppLocalizations t) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.accent.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colors.accent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('🪙', style: TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 12),
              Text(
                t.monetCoinsBalance,
                style: TextStyle(
                  fontSize: 12,
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => CoinRechargeScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.accent,
                  foregroundColor: colors.onAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  elevation: 0,
                ),
                icon: Icon(Icons.add, size: 18, color: colors.onAccent),
                label: Text(
                  t.monetRecharge,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: colors.onAccent),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                giftCoinsBalance.toString(),
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: colors.accent),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  t.monetCoins,
                  style: TextStyle(color: colors.textSecondary, fontSize: 14),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConversionSection(int giftCoinsBalance, AppColors colors, AppLocalizations t) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.accent.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.swap_horiz, color: colors.accent, size: 20),
              const SizedBox(width: 8),
              Text(
                t.monetConvertTitle,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            t.monetConvertRate,
            style: TextStyle(color: colors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.accent.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(t.monetAvailableBalance, style: TextStyle(color: colors.textSecondary)),
                Row(
                  children: [
                    const Text('🪙', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Text(
                      giftCoinsBalance.toString(),
                      style: TextStyle(
                        color: colors.accent,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CoinConversionPage()),
                );
                if (result == true) refreshUser();
              },
              icon: Icon(Icons.swap_horiz, color: colors.onAccent),
              label: Text(
                t.monetConvertBtn,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: colors.onAccent),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.accent,
                foregroundColor: colors.onAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            t.monetConvertMin,
            style: TextStyle(color: colors.textSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionHeader(AppColors colors, AppLocalizations t) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: colors.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.history, color: colors.primary, size: 16),
          ),
          const SizedBox(width: 8),
          Text(
            t.monetTxHistory,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionList(String userId, AppColors colors, AppLocalizations t) {
    return StreamBuilder<List<TransactionSolde>>(
      stream: postProvider.getTransactionsSoldes(userId),
      builder: (context, snapshotTx) {
        if (snapshotTx.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(colors.primary)));
        }
        if (snapshotTx.hasError) {
          return Center(child: Text(t.commonLoadingError, style: TextStyle(color: colors.danger)));
        }
        final transactions = snapshotTx.data ?? [];
        if (transactions.isEmpty) {
          return Center(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.receipt_long, size: 48, color: colors.textSecondary),
              const SizedBox(height: 16),
              Text(t.monetNoTx, style: TextStyle(color: colors.textSecondary)),
            ]),
          );
        }
        return _TxGroupedList(transactions: transactions, colors: colors);
      },
    );
  }
}

// ── Groupes de transactions ────────────────────────────────────────────────────

class _TxGroupedList extends StatefulWidget {
  final List<TransactionSolde> transactions;
  final AppColors colors;
  const _TxGroupedList({required this.transactions, required this.colors});
  @override
  State<_TxGroupedList> createState() => _TxGroupedListState();
}

class _TxGroupedListState extends State<_TxGroupedList> {
  static const _groups = {
    'Gains':       ['DEPOT', 'DEPOTADMIN', 'GAIN', 'GAIN_PIECES', 'CADEAU_PIECES_RECU'],
    'Dépenses':    ['DEPENSE', 'ACHAT_PIECES', 'CADEAU_PIECES', 'LIKE_PIECES'],
    'Retraits':    ['RETRAIT', 'RETRAITADMIN'],
    'Conversions': ['CONVERSION_PIECES'],
  };
  static const _groupIcons = {
    'Gains':       Icons.trending_up,
    'Dépenses':    Icons.shopping_cart_outlined,
    'Retraits':    Icons.arrow_upward,
    'Conversions': Icons.swap_horiz,
  };
  static const _groupColors = {
    'Gains':       Color(0xFF0F6E56),
    'Dépenses':    Color(0xFFE53935),
    'Retraits':    Color(0xFFFF9800),
    'Conversions': Color(0xFF5B9CFA),
  };

  final Map<String, bool> _expanded = {
    'Gains': false, 'Dépenses': false, 'Retraits': false, 'Conversions': false,
  };
  final Map<String, int> _visible = {};

  String _groupFor(String? type) {
    for (final e in _groups.entries) {
      if (e.value.contains(type?.toUpperCase())) return e.key;
    }
    return 'Gains';
  }

  @override
  void initState() {
    super.initState();
    // Ouvrir automatiquement le groupe avec la transaction la plus récente
    final sorted = _sortedGroups();
    if (sorted.isNotEmpty) _expanded[sorted.first] = true;
  }

  List<String> _sortedGroups() {
    int latestOf(String g) => widget.transactions
        .where((tx) => _groupFor(tx.type) == g)
        .fold<int>(0, (m, tx) => (tx.createdAt ?? 0) > m ? (tx.createdAt ?? 0) : m);
    return _groups.keys.toList()..sort((a, b) => latestOf(b).compareTo(latestOf(a)));
  }

  @override
  Widget build(BuildContext context) {
    final sortedGroups = _sortedGroups();
    return ListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: sortedGroups.map((group) {
        final items = widget.transactions
            .where((tx) => _groupFor(tx.type) == group)
            .toList()
          ..sort((a, b) => (b.createdAt ?? 0).compareTo(a.createdAt ?? 0));
        if (items.isEmpty) return const SizedBox.shrink();
        final isOpen = _expanded[group] ?? false;
        final groupColor = _groupColors[group] ?? widget.colors.primary;
        final visible = _visible[group] ?? 2;
        return Column(
          children: [
            InkWell(
              onTap: () => setState(() => _expanded[group] = !isOpen),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: widget.colors.surface,
                child: Row(
                  children: [
                    Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: groupColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(_groupIcons[group], color: groupColor, size: 16),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(group,
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: widget.colors.textPrimary)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: groupColor.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('${items.length}',
                          style: TextStyle(color: groupColor, fontWeight: FontWeight.w700, fontSize: 12)),
                    ),
                    const SizedBox(width: 6),
                    Icon(isOpen ? Icons.expand_less : Icons.expand_more,
                        color: widget.colors.textSecondary, size: 20),
                  ],
                ),
              ),
            ),
            if (isOpen) ...[
              ...items.take(visible).map((tx) => TransactionWidget(transaction: tx)),
              if (visible < items.length)
                TextButton.icon(
                  onPressed: () => setState(() => _visible[group] = visible + 5),
                  icon: Icon(Icons.expand_more, size: 16, color: groupColor),
                  label: Text('Voir plus (${items.length - visible})',
                      style: TextStyle(color: groupColor, fontSize: 12)),
                ),
            ],
            Divider(height: 1, color: widget.colors.border.withOpacity(0.3)),
          ],
        );
      }).toList(),
    );
  }
}

class TransactionWidget extends StatelessWidget {
  final TransactionSolde transaction;
  const TransactionWidget({required this.transaction});

  String formatDate(DateTime date) {
    return DateFormat('dd MMM yyyy, HH:mm').format(date);
  }

  String getTransactionLabel(String type) {
    switch (type) {
      case "DEPOT":            return "Dépôt";
      case "DEPOTADMIN":       return "Dépôt Admin";
      case "RETRAIT":          return "Retrait";
      case "RETRAITADMIN":     return "Retrait Admin";
      case "GAIN":             return "Gain";
      case "GAIN_PIECES":      return "Gain en pièces";
      case "DEPENSE":          return "Dépense";
      case "ACHAT_PIECES":     return "Achat de pièces";
      case "CONVERSION_PIECES":return "Conversion pièces → FCFA";
      case "CADEAU_PIECES":    return "Cadeau envoyé";
      case "CADEAU_PIECES_RECU":return "Cadeau reçu";
      case "LIKE_PIECES":      return "Like envoyé";
      default:                 return type;
    }
  }

  IconData getIcon(String type) {
    switch (type) {
      case "DEPOT":
      case "DEPOTADMIN":        return Icons.account_balance_wallet;
      case "RETRAIT":
      case "RETRAITADMIN":      return Icons.arrow_upward;
      case "GAIN":
      case "GAIN_PIECES":       return Icons.trending_up;
      case "DEPENSE":           return Icons.shopping_cart;
      case "ACHAT_PIECES":      return Icons.shopping_bag;
      case "CONVERSION_PIECES": return Icons.swap_horiz;
      case "CADEAU_PIECES":
      case "CADEAU_PIECES_RECU":return Icons.card_giftcard;
      case "LIKE_PIECES":       return Icons.favorite;
      default:                  return Icons.help_outline;
    }
  }

  Color _resolveColor(String type, AppColors colors) {
    switch (type) {
      case "DEPOT":
      case "DEPOTADMIN":
      case "GAIN":
      case "GAIN_PIECES":
      case "CADEAU_PIECES_RECU": return colors.primary;
      case "RETRAIT":
      case "RETRAITADMIN":
      case "DEPENSE":
      case "ACHAT_PIECES":
      case "CADEAU_PIECES":
      case "LIKE_PIECES":        return colors.danger;
      case "CONVERSION_PIECES":  return colors.accent;
      default:                   return colors.textSecondary;
    }
  }

  String getPrefix(String type) {
    switch (type) {
      case "DEPOT":
      case "DEPOTADMIN":
      case "GAIN":
      case "GAIN_PIECES":
      case "CADEAU_PIECES_RECU": return "+ ";
      case "RETRAIT":
      case "RETRAITADMIN":
      case "DEPENSE":
      case "ACHAT_PIECES":
      case "CADEAU_PIECES":
      case "LIKE_PIECES":        return "- ";
      case "CONVERSION_PIECES":  return "→ ";
      default:                   return "";
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    final isValide = transaction.statut == StatutTransaction.VALIDER.name;
    final color = _resolveColor(transaction.type!, colors);
    final icon = getIcon(transaction.type!);
    final prefix = getPrefix(transaction.type!);
    final label = getTransactionLabel(transaction.type!);

    final bool isCoinAchatTransaction =
        transaction.type == TypeTransaction.ACHAT_PIECES.name ||
        transaction.type == TypeTransaction.CONVERSION_PIECES.name;

    final bool isCoinTransaction =
        transaction.type == TypeTransaction.ACHAT_PIECES.name ||
        transaction.type == TypeTransaction.CADEAU_PIECES.name ||
        transaction.type == TypeTransaction.CADEAU_PIECES_RECU.name ||
        transaction.type == TypeTransaction.LIKE_PIECES.name ||
        transaction.type == TypeTransaction.GAIN_PIECES.name;

    final String amountDisplay;
    if (isCoinAchatTransaction) {
      amountDisplay = "$prefix${transaction.montant!.toStringAsFixed(2)} FCFA";
    } else if (isCoinTransaction) {
      amountDisplay = "$prefix${transaction.montant!.toStringAsFixed(2)} 🪙";
    } else {
      amountDisplay = "$prefix${transaction.montant!.toStringAsFixed(2)} FCFA";
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: colors.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  amountDisplay,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
                ),
                if (transaction.description != null && transaction.description!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      transaction.description!,
                      style: TextStyle(color: colors.textSecondary, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatDate(DateTime.fromMillisecondsSinceEpoch(transaction.createdAt!)),
                style: TextStyle(fontSize: 11, color: colors.textSecondary),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isValide
                      ? colors.primary.withOpacity(0.15)
                      : colors.warning.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  transaction.statut!.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isValide ? colors.primary : colors.warning,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
