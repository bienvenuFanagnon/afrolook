import 'package:afrotok/layout/centered_content.dart';
import 'package:afrotok/pages/user/UserRetrait/userRetraitForm.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/model_data.dart';
import '../../utils/platform_guard.dart';
import '../../utils/tx_amount.dart';
import 'mes_gains_post_page.dart';
import 'mes_gains_publicite_page.dart';
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
  Stream<List<TransactionSolde>>? _txStream;
  String _txFilter = 'tous';
  bool _viewsExpanded = false;

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
      _txStream = null;
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
          final double creatorScore = user.creatorScore ?? 0.0;
          final int totalViews = user.totalPostUniqueViews ?? 0;
          final int creditedViews = user.totalViewsEarningsCredited ?? 0;

          return CenteredContent(child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildWallet(user, colors),
                const SizedBox(height: 20),
                _buildViewEarningsCard(creatorScore, totalViews, creditedViews, colors),
                const SizedBox(height: 24),
                _buildTransactionHeader(colors, t),
                const SizedBox(height: 10),
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
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête (repliable)
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(() => _viewsExpanded = !_viewsExpanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: tierColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.play_circle_outline_rounded, color: tierColor, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text('Revenus des vues',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: colors.textPrimary)),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                              decoration: BoxDecoration(
                                color: tierColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(tierLabel,
                                  style: TextStyle(color: tierColor, fontWeight: FontWeight.w700, fontSize: 10.5)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${(myRate * 1000).toInt()} FCFA RPM · à encaisser : ${pendingEarnings.toStringAsFixed(2)} F',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11.5, color: colors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Icon(_viewsExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                      color: colors.textSecondary, size: 22),
                ],
              ),
            ),
          ),

          if (_viewsExpanded) ...[
            Divider(height: 1, thickness: 0.5, color: colors.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Score créateur : ${creatorScore.toStringAsFixed(1)} pts  ·  ${(multiplier * 100).toStringAsFixed(0)}% du taux de base (RPM max : 1 000 FCFA)',
                    style: TextStyle(fontSize: 11, color: colors.textSecondary),
                  ),
                  const SizedBox(height: 12),
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
                      Expanded(
                        child: _viewStat(
                          icon: Icons.schedule_outlined,
                          label: 'Non encaissées',
                          value: pendingViews.toString(),
                          color: tierColor,
                          colors: colors,
                        ),
                      ),
                      Expanded(
                        child: _viewStat(
                          icon: Icons.account_balance_wallet_outlined,
                          label: 'À encaisser',
                          value: '${pendingEarnings.toStringAsFixed(2)} F',
                          color: tierColor,
                          colors: colors,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Paliers
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colors.surfaceVariant,
                      borderRadius: BorderRadius.circular(10),
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
                        const SizedBox(height: 6),
                        ..._scoreTiers.map((t) {
                          final tColor = Color(t['color'] as int);
                          final tMulti = t['multiplier'] as double;
                          final tLabel = t['label'] as String;
                          final tMin = t['minScore'] as double;
                          final isActive = tierLabel == tLabel;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 3),
                            child: Row(
                              children: [
                                Container(
                                  width: 7, height: 7,
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
                                  '${((tMulti * baseRate) * 1000).toInt()} FCFA RPM',
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
                  const SizedBox(height: 10),
                  Text(
                    'Tes gains s\'accumulent selon tes vues et ton palier. '
                    'Le RPM maximum est de 1 000 FCFA (pour 1 000 vues) et peut être ajusté par Afrolook. '
                    'Améliore ton score en publiant du contenu apprécié.',
                    style: TextStyle(fontSize: 10.5, color: colors.textSecondary, height: 1.4),
                  ),
                ],
              ),
            ),
          ],

          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: SizedBox(
              width: double.infinity,
              height: 38,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MesGainsPage(userId: Provider.of<UserAuthProvider>(context, listen: false).loginUserData.id!),
                  ),
                ),
                icon: Icon(Icons.account_balance_wallet_outlined, size: 16, color: tierColor),
                label: Text(
                  'Voir mes gains & encaisser',
                  style: TextStyle(color: tierColor, fontWeight: FontWeight.w700, fontSize: 13),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: tierColor.withOpacity(0.5)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
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

  // ── Portefeuille ──────────────────────────────────────────────────────────
  // Bloc 1 « Mes pièces » : pièces de dépôt (achetées, dépensables) et pièces gagnées
  // (convertibles en argent) — même calcul que le serveur (coin_locks.ts).
  // Bloc 2 « Mon argent » : gains à retirer + dépôt FCFA (Android uniquement).

  static final NumberFormat _moneyFmt = NumberFormat('#,##0.##', 'fr');
  String _money(double v) => '${_moneyFmt.format(v)} FCFA';

  Widget _buildWallet(UserData user, AppColors c) {
    final depotCoins = user.lockedGiftCoins;
    final gagnees = user.convertibleGiftCoins;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _walletTitle(c, 'Mes pièces'),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _coinTile(
                  c,
                  icon: Icons.toll_rounded,
                  color: c.supportAccent,
                  title: 'Pièces de dépôt',
                  coins: depotCoins,
                  caption: 'Pour acheter, offrir et voter',
                  action: 'Recharger',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CoinRechargeScreen())),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _coinTile(
                  c,
                  icon: Icons.emoji_events_rounded,
                  color: c.primary,
                  title: 'Pièces gagnées',
                  coins: gagnees,
                  caption: 'Convertibles en argent',
                  action: 'Convertir',
                  onTap: gagnees > 0
                      ? () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const CoinConversionPage()),
                          );
                          if (result == true) refreshUser();
                        }
                      : null,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _walletTitle(c, 'Mon argent'),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.border),
          ),
          child: Column(
            children: [
              _moneyRow(
                c,
                icon: Icons.account_balance_wallet_rounded,
                color: c.primary,
                title: 'Gains à retirer',
                value: _money(user.votre_solde_principal ?? 0),
                action: 'Retirer',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => UserDemandeRetraitPage())),
              ),
              // Dépôt FCFA : Android uniquement (argent déjà versé par Mobile Money,
              // utilisable pour recharger les pièces de dépôt).
              if (!kIsAppleStore) ...[
                Divider(height: 1, thickness: 0.5, indent: 60, color: c.border),
                _moneyRow(
                  c,
                  icon: Icons.savings_rounded,
                  color: c.info,
                  title: 'Dépôt FCFA',
                  value: _money(user.votre_solde_depot ?? 0),
                  action: 'Convertir en pièces',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CoinRechargeScreen())),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(60, 0, 8, 6),
                  child: Row(
                    children: [
                      _linkButton(c, Icons.add_rounded, 'Recharger',
                          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DepositScreen()))),
                      _linkButton(c, Icons.pending_actions_rounded, 'En attente',
                          () => Navigator.push(context, MaterialPageRoute(builder: (_) => PendingTransactionsScreen()))),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        _walletTitle(c, 'Mes revenus'),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.border),
          ),
          child: Column(
            children: [
              _linkRow(c, Icons.article_rounded, c.primary, 'Rémunération des posts',
                  () => Navigator.push(context, MaterialPageRoute(builder: (_) => MesGainsPage(userId: user.id!)))),
              Divider(height: 1, thickness: 0.5, indent: 52, color: c.border),
              _linkRow(c, Icons.campaign_rounded, c.info, 'Gains publicitaires',
                  () => Navigator.push(context, MaterialPageRoute(builder: (_) => MesGainsPublicitePage(userId: user.id!)))),
              Divider(height: 1, thickness: 0.5, indent: 52, color: c.border),
              _linkRow(c, Icons.receipt_long_rounded, c.warning, 'Historique des retraits',
                  () => Navigator.push(context, MaterialPageRoute(builder: (_) => UserRetraitListPage()))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _linkRow(AppColors c, IconData icon, Color color, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 18),
            Expanded(
              child: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.textPrimary)),
            ),
            Icon(Icons.chevron_right_rounded, color: c.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _walletTitle(AppColors c, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Text(title.toUpperCase(),
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: c.textSecondary)),
    );
  }

  Widget _coinTile(
    AppColors c, {
    required IconData icon,
    required Color color,
    required String title,
    required int coins,
    required String caption,
    required String action,
    required VoidCallback? onTap,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: c.textPrimary)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              TxAmount.fmt(coins),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: c.textPrimary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          Text('pièces · ≈ ${TxAmount.fmt(coins / 2.5)} FCFA',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: c.textSecondary)),
          const SizedBox(height: 6),
          Text(caption, style: TextStyle(fontSize: 11, color: c.textSecondary, height: 1.3)),
          const Spacer(),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 34,
            child: FilledButton(
              onPressed: onTap,
              style: FilledButton.styleFrom(
                backgroundColor: color,
                foregroundColor: color == c.primary ? c.onPrimary : c.onAccent,
                disabledBackgroundColor: c.surfaceVariant,
                disabledForegroundColor: c.textSecondary,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(action, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _moneyRow(
    AppColors c, {
    required IconData icon,
    required Color color,
    required String title,
    required String value,
    required String action,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withOpacity(c.isDark ? 0.18 : 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 12, color: c.textSecondary)),
                const SizedBox(height: 1),
                Text(value,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: c.textPrimary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    )),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
              foregroundColor: color,
              side: BorderSide(color: color.withOpacity(0.5)),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: const Size(0, 34),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(action, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _linkButton(AppColors c, IconData icon, String label, VoidCallback onTap) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16, color: c.textSecondary),
      label: Text(label, style: TextStyle(fontSize: 12, color: c.textSecondary, fontWeight: FontWeight.w600)),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: const Size(0, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  // ── Historique ────────────────────────────────────────────────────────────

  /// Transaction liée aux pièces (sinon : argent FCFA).
  static bool _isCoinTx(TransactionSolde t) {
    final type = t.type?.toUpperCase() ?? '';
    return TxAmount.storedInCoins(t) || type == 'ACHAT_PIECES' || type == 'CONVERSION_PIECES';
  }

  Widget _buildTransactionHeader(AppColors c, AppLocalizations t) {
    const filters = {'tous': 'Tout', 'pieces': 'Pièces', 'argent': 'Argent'};
    return Row(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(t.monetTxHistory.toUpperCase(),
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: c.textSecondary)),
          ),
        ),
        for (final e in filters.entries) ...[
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => setState(() => _txFilter = e.key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _txFilter == e.key ? c.textPrimary : c.surfaceVariant,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(e.value,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _txFilter == e.key ? c.background : c.textSecondary,
                  )),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTransactionList(String userId, AppColors colors, AppLocalizations t) {
    return StreamBuilder<List<TransactionSolde>>(
      stream: _txStream ??= postProvider.getTransactionsSoldes(userId),
      builder: (context, snapshotTx) {
        if (snapshotTx.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(colors.primary)));
        }
        if (snapshotTx.hasError) {
          return Center(child: Text(t.commonLoadingError, style: TextStyle(color: colors.danger)));
        }
        final transactions = (snapshotTx.data ?? []).where((tx) {
          if (_txFilter == 'pieces') return _isCoinTx(tx);
          if (_txFilter == 'argent') return !_isCoinTx(tx);
          return true;
        }).toList();
        if (transactions.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.receipt_long_rounded, size: 40, color: colors.textSecondary),
                const SizedBox(height: 10),
                Text(t.monetNoTx, style: TextStyle(color: colors.textSecondary)),
              ]),
            ),
          );
        }
        return _TxGroupedList(key: ValueKey(_txFilter), transactions: transactions, colors: colors);
      },
    );
  }
}

// ── Groupes de transactions ────────────────────────────────────────────────────

class _TxGroupedList extends StatefulWidget {
  final List<TransactionSolde> transactions;
  final AppColors colors;
  const _TxGroupedList({super.key, required this.transactions, required this.colors});
  @override
  State<_TxGroupedList> createState() => _TxGroupedListState();
}

class _TxGroupedListState extends State<_TxGroupedList> {
  static const _groups = {
    'Entrées':     ['DEPOT', 'DEPOTADMIN', 'GAIN', 'GAIN_PIECES', 'CADEAU_PIECES_RECU'],
    'Dépenses':    ['DEPENSE', 'ACHAT_PIECES', 'CADEAU_PIECES', 'LIKE_PIECES'],
    'Retraits':    ['RETRAIT', 'RETRAITADMIN'],
    'Conversions': ['CONVERSION_PIECES'],
  };
  static const _groupIcons = {
    'Entrées':     Icons.south_west_rounded,
    'Dépenses':    Icons.north_east_rounded,
    'Retraits':    Icons.account_balance_rounded,
    'Conversions': Icons.swap_horiz_rounded,
  };

  final Map<String, bool> _expanded = {};
  final Map<String, int> _visible = {};

  String _groupFor(String? type) {
    for (final e in _groups.entries) {
      if (e.value.contains(type?.toUpperCase())) return e.key;
    }
    return 'Entrées';
  }

  Color _groupColor(String group, AppColors c) {
    switch (group) {
      case 'Entrées':  return c.success;
      case 'Dépenses': return c.danger;
      case 'Retraits': return c.warning;
      default:         return c.info;
    }
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
    final c = AppColors.of(context);
    final groups = _sortedGroups()
        .map((group) {
          final items = widget.transactions.where((tx) => _groupFor(tx.type) == group).toList()
            ..sort((a, b) => (b.createdAt ?? 0).compareTo(a.createdAt ?? 0));
          return MapEntry(group, items);
        })
        .where((e) => e.value.isNotEmpty)
        .toList();

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Column(
        children: [
          for (var gi = 0; gi < groups.length; gi++) ...[
            if (gi > 0) Divider(height: 1, thickness: 1, color: c.border),
            _buildGroup(groups[gi].key, groups[gi].value, c),
          ],
        ],
      ),
    );
  }

  Widget _buildGroup(String group, List<TransactionSolde> items, AppColors c) {
    final isOpen = _expanded[group] ?? false;
    final color = _groupColor(group, c);
    final visible = _visible[group] ?? 5;
    return Column(
      children: [
        InkWell(
          onTap: () => setState(() => _expanded[group] = !isOpen),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                Icon(_groupIcons[group], color: color, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(group,
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: c.textPrimary)),
                ),
                Text('${items.length}',
                    style: TextStyle(color: c.textSecondary, fontWeight: FontWeight.w600, fontSize: 12)),
                const SizedBox(width: 4),
                Icon(isOpen ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    color: c.textSecondary, size: 20),
              ],
            ),
          ),
        ),
        if (isOpen) ...[
          for (final tx in items.take(visible)) ...[
            Divider(height: 1, thickness: 0.5, indent: 60, color: c.border),
            TransactionWidget(transaction: tx),
          ],
          if (visible < items.length)
            InkWell(
              onTap: () => setState(() => _visible[group] = visible + 10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Center(
                  child: Text('Voir plus (${items.length - visible})',
                      style: TextStyle(color: c.primary, fontSize: 12.5, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

/// Ligne compacte d'une transaction. Sur iPhone, tout est affiché en pièces
/// avec l'équivalent FCFA en dessous (sauf retraits et conversions, en argent réel).
class TransactionWidget extends StatelessWidget {
  final TransactionSolde transaction;
  const TransactionWidget({super.key, required this.transaction});

  static const _labels = {
    'DEPOT': 'Dépôt',
    'DEPOTADMIN': 'Dépôt (admin)',
    'RETRAIT': 'Retrait',
    'RETRAITADMIN': 'Retrait (admin)',
    'GAIN': 'Gain',
    'GAIN_PIECES': 'Gain en pièces',
    'DEPENSE': 'Achat',
    'ACHAT_PIECES': 'Achat de pièces',
    'CONVERSION_PIECES': 'Conversion en FCFA',
    'CADEAU_PIECES': 'Cadeau envoyé',
    'CADEAU_PIECES_RECU': 'Cadeau reçu',
    'LIKE_PIECES': 'Like envoyé',
  };

  static const _icons = {
    'DEPOT': Icons.add_card_rounded,
    'DEPOTADMIN': Icons.add_card_rounded,
    'RETRAIT': Icons.account_balance_rounded,
    'RETRAITADMIN': Icons.account_balance_rounded,
    'GAIN': Icons.trending_up_rounded,
    'GAIN_PIECES': Icons.emoji_events_rounded,
    'DEPENSE': Icons.shopping_bag_rounded,
    'ACHAT_PIECES': Icons.toll_rounded,
    'CONVERSION_PIECES': Icons.swap_horiz_rounded,
    'CADEAU_PIECES': Icons.card_giftcard_rounded,
    'CADEAU_PIECES_RECU': Icons.card_giftcard_rounded,
    'LIKE_PIECES': Icons.favorite_rounded,
  };

  /// true = crédit (argent ou pièces qui entrent), false = débit.
  static bool _isCredit(String type, TransactionSolde t) {
    switch (type) {
      case 'DEPOT':
      case 'DEPOTADMIN':
      case 'GAIN':
      case 'GAIN_PIECES':
      case 'CADEAU_PIECES_RECU':
      case 'CONVERSION_PIECES':
        return true;
      // Achat via l'App Store : des pièces entrent sur le compte
      case 'ACHAT_PIECES':
        return t.methode_paiement == 'apple_iap';
      default:
        return false;
    }
  }

  String _date(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final hm = DateFormat('HH:mm').format(d);
    if (!d.isBefore(today)) return "Aujourd'hui · $hm";
    if (!d.isBefore(today.subtract(const Duration(days: 1)))) return 'Hier · $hm';
    return DateFormat('d MMM yyyy · HH:mm', 'fr').format(d);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final type = transaction.type?.toUpperCase() ?? '';
    final credit = _isCredit(type, transaction);
    final isWithdrawal = type == 'RETRAIT' || type == 'RETRAITADMIN';
    final tint = credit ? c.success : (isWithdrawal ? c.warning : c.danger);
    final equivalent = TxAmount.equivalent(transaction);
    final desc = transaction.description?.trim() ?? '';
    final label = _labels[type] ?? type;

    final statut = transaction.statut?.toUpperCase() ?? '';
    final String? statutLabel = statut == 'ENCOURS'
        ? 'En cours'
        : statut == 'ANNULER'
            ? 'Annulée'
            : null;
    final statutColor = statut == 'ANNULER' ? c.danger : c.warning;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: tint.withOpacity(c.isDark ? 0.18 : 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_icons[type] ?? Icons.receipt_long_rounded, color: tint, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  desc.isNotEmpty ? desc : label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: c.textPrimary),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        '$label · ${_date(transaction.createdAt ?? 0)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: c.textSecondary),
                      ),
                    ),
                    if (statutLabel != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: statutColor.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(statutLabel,
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: statutColor)),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${credit ? '+' : '−'}${TxAmount.main(transaction)}',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: credit ? c.success : c.textPrimary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              if (equivalent != null)
                Text(equivalent, style: TextStyle(fontSize: 10.5, color: c.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}
