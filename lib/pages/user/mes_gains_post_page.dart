import 'package:afrotok/layout/centered_content.dart';
import 'package:afrotok/utils/responsive_sheet.dart';
import 'package:afrolook_api_client/afrolook_api_client.dart';
import 'package:flutter/material.dart';
import '../../services/api/api_gateway.dart';
import '../../services/api/wallet_api.dart';
import '../../services/api/audit_errors.dart';
import '../../widgets/email_verification_gate.dart';
import '../../services/monetization_config.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../models/model_data.dart';
import '../../providers/authProvider.dart';
import '../../theme/app_colors.dart';
import '../postDetails.dart';
import '../postDetailsVideo.dart';
import '../../l10n/tr.dart';
import '../../services/currency_service.dart';

/// Minimum d'encaissement : celui que l'API renvoie (`min_cash_xof`), 1 000 FCFA tant que les gains ne sont pas chargés.
double get _minEncaissement => (_apiEarn?['min_cash_xof'] is num) ? (_apiEarn!['min_cash_xof'] as num).toDouble() : 1000.0;

/// Plafond d'encaissement du jour et total déjà encaissé aujourd'hui, tels que l'API les renvoie (null si l'API ne les a pas donnés).
int? get _dailyCapXof => (_apiEarn?['daily_cap_xof'] is num) ? (_apiEarn!['daily_cap_xof'] as num).toInt() : null;
int? get _cashedTodayXof => (_apiEarn?['cashed_today_xof'] is num) ? (_apiEarn!['cashed_today_xof'] as num).toInt() : null;
double get _baseViewRate => MonetizationConfig.baseViewRate;

// Barème : config/monetization (MonetizationConfig), partagé avec les Cloud Functions.
const _tierColors = [0xFF22C55E, 0xFF3B82F6, 0xFFF97316, 0xFFF59E0B, 0xFF94A3B8];
List<Map<String, dynamic>> get _scoreTiersDyn {
  final tiers = MonetizationConfig.tiers;
  return [
    for (var i = 0; i < tiers.length; i++)
      {
        'minScore': tiers[i].minScore,
        'multiplier': tiers[i].multiplier,
        'label': tiers[i].label,
        'color': _tierColors[i < _tierColors.length ? i : _tierColors.length - 1],
      },
  ];
}
List<Map<String, dynamic>> get _scoreTiers => _scoreTiersDyn;

Map<String, dynamic> _getTier(double score) {
  for (final t in _scoreTiers) {
    if (score >= (t['minScore'] as double)) return t;
  }
  return _scoreTiers.last;
}

/// Gains des vues lus sur l'API (`GET /wallet/earnings/views`) : le serveur compte les vues et calcule le montant, l'application affiche seulement.
Map<String, dynamic>? _apiEarn;

double _fcfaPerView(double creatorScore) {
  final r = _apiEarn?['rate_xof_per_view'];
  if (r is num) return r.toDouble();
  final t = _getTier(creatorScore);
  return _baseViewRate * (t['multiplier'] as double);
}

/// Vues pas encore payées (totalViewsEarningsCredited = vues déjà payées, y compris par
/// l'ancien paiement automatique supprimé) : une vue n'est payée qu'une seule fois.
/// Vues des posts non monétisés, exclues du calcul (chargées par la page, comme le fait le serveur).
int _excludedViews = 0;

/// Vues payables (décidées par le serveur : seules ces vues rapportent). Aucun calcul local : 0 tant que l'API n'a pas répondu.
int _pendingViews(UserData user) => (_apiEarn?['pending_views'] is num) ? (_apiEarn!['pending_views'] as num).toInt() : 0;

/// Gains encaissables (FCFA), tels que l'API les renvoie. Aucun calcul local ni repli : 0 tant que l'API n'a pas répondu
/// (l'écran affiche alors l'erreur et « Réessayer »).
double _availableEarnings(UserData user) => (_apiEarn?['available_xof'] is num) ? (_apiEarn!['available_xof'] as num).toDouble() : 0;

class MesGainsPage extends StatefulWidget {
  final String userId;
  final bool isAdminView;
  const MesGainsPage({Key? key, required this.userId, this.isAdminView = false}) : super(key: key);

  @override
  State<MesGainsPage> createState() => _MesGainsPageState();
}

class _MesGainsPageState extends State<MesGainsPage> {
  final _amountController = TextEditingController();

  bool _isMigrating = false;
  bool _isEncashing = false;
  bool _isLoadingHistory = false;
  bool _showAllMonths = false;
  bool _isLoadingViewedUser = false;
  bool _tierInfoExpanded = false;

  UserData? _viewedUser;

  // postViewsMonthlyPostIds lu directement depuis Firestore
  Map<String, List<String>> _monthlyPostIds = {};

  List<Map<String, dynamic>> _history = [];

  @override
  void initState() {
    super.initState();
    MonetizationConfig.load().then((_) { if (mounted) setState(() {}); });
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  String? _loadError;

  Future<void> _init() async {
    if (widget.isAdminView) {
      // Vue équipe : les gains d'une autre personne ne sont pas encore exposés par l'API (voir lacunes_api_argent_creations.md).
      setState(() => _isLoadingViewedUser = true);
      try {
        final r = await ApiGateway.instance.client.get('/admin/users/${widget.userId}');
        final d = WalletApi.map(r);
        final u = d['user'] is Map ? Map<String, dynamic>.from(d['user'] as Map) : d;
        if (mounted) {
          setState(() {
            _viewedUser = UserData(pseudo: (u['username'] ?? u['display_name'] ?? '') as String?);
            _viewedUser!.id = widget.userId;
          });
        }
      } catch (e) {
        _loadError = WalletApi.message(e);
      }
      if (mounted) setState(() => _isLoadingViewedUser = false);
      return;
    }
    await _reloadEarnings();
    _loadHistory();
  }

  /// Relit les gains des vues sur l'API.
  Future<void> _reloadEarnings() async {
    try {
      final e = await WalletApi.instance.viewEarnings();
      _apiEarn = e;
      _loadError = null;
    } catch (e) {
      _loadError = WalletApi.message(e);
    }
    if (mounted) setState(() {});
  }

  Future<void> _loadHistory() async {
    if (widget.isAdminView) return;
    setState(() => _isLoadingHistory = true);
    try {
      final r = await WalletApi.instance.transactions(scope: 'money', limit: 50);
      _history = r.items.where((t) => t['kind'] == 'view_cashout').take(20).map((t) {
        final created = DateTime.tryParse('${t['created_at']}')?.millisecondsSinceEpoch;
        return <String, dynamic>{'id': t['id'], 'montant': t['amount_xof'], 'createdAt': created};
      }).toList();
    } catch (_) {}
    if (mounted) setState(() => _isLoadingHistory = false);
  }

  Future<void> _encaisser(UserData user, AppLocalizations t, AppColors colors) async {
    final input = double.tryParse(_amountController.text.trim()) ?? 0;
    final available = _availableEarnings(user);

    if (input < _minEncaissement) { _snack(t.gainsErrMin, colors.danger); return; }
    if (input > available)        { _snack(t.gainsErrMax, colors.danger); return; }

    setState(() => _isEncashing = true);
    try {
      // Calcul et crédit côté serveur (clé conservée tant que la demande n'est pas confirmée)
      // E-mail non confirmé (403 `email_unverified`) : fenêtre « Confirme ton e-mail », puis l'encaissement est rejoué.
      await EmailVerificationGate.run(context, () => WalletApi.instance.cashViews(input.round()));
      _amountController.clear();
      await _reloadEarnings();
      await Provider.of<UserAuthProvider>(context, listen: false).refreshUserData();
      await _loadHistory();
      _snack(t.gainsSuccess(input.toInt()), colors.primary);
    } on ApiException catch (e) {
      // Messages de l'API (plafond du jour, compte trop récent, e-mail non confirmé…) traduits ; aucun calcul local.
      final msg = switch (e.code) {
        'exceeds_available' => t.gainsErrInsuff,
        'too_soon' => t.gainsErrCooldown,
        'below_minimum' => t.gainsErrMin,
        'account_too_young' || 'daily_cap_reached' || 'email_unverified' => AuditErrors.message(e, scope: ErrorScope.views),
        _ => e.isNetwork ? AuditErrors.message(e) : t.gainsErrGeneral,
      };
      // Les montants ont pu changer côté serveur : on relit ce que l'API renvoie.
      if (e.code == 'exceeds_available' || e.code == 'daily_cap_reached') await _reloadEarnings();
      _snack(msg, colors.danger);
    } catch (_) {
      _snack(t.gainsErrGeneral, colors.danger);
    } finally {
      if (mounted) setState(() => _isEncashing = false);
    }
  }

  void _snack(String msg, Color bg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: bg, duration: const Duration(seconds: 3)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final t = AppLocalizations.of(context);
    final authUser = Provider.of<UserAuthProvider>(context).loginUserData;
    final user = widget.isAdminView ? (_viewedUser ?? authUser) : authUser;

    final isLoading = _isMigrating || (widget.isAdminView && _isLoadingViewedUser);

    String titleText = t.gainsTitle;
    if (widget.isAdminView && _viewedUser != null) {
      titleText = context.tr('Gains de @{a}', {'a': _viewedUser!.pseudo ?? ''});
    }

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(titleText,
            style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold)),
        backgroundColor: colors.background,
        iconTheme: IconThemeData(color: colors.textPrimary),
        elevation: 0,
      ),
      body: isLoading
          ? _migrationLoader(colors, t)
          : CenteredContent(child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_loadError != null) ...[
                    _infoBox(_loadError!, colors.danger, Icons.error_outline, colors),
                    TextButton(onPressed: _init, child: Text(context.tr('Réessayer'))),
                    const SizedBox(height: 8),
                  ],
                  _statsCard(user, colors, t),
                  const SizedBox(height: 16),
                  _tierInfoCard(user, colors),
                  const SizedBox(height: 16),
                  if (!widget.isAdminView) ...[
                    _encaissCard(user, colors, t),
                    const SizedBox(height: 16),
                  ],
                  _monthlyCard(user, colors, t),
                  const SizedBox(height: 16),
                  _historyCard(colors, t),
                  const SizedBox(height: 32),
                ],
              ),
            )),
    );
  }

  // ── Loader migration ──────────────────────────────────────
  Widget _migrationLoader(AppColors colors, AppLocalizations t) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: colors.accent),
            const SizedBox(height: 24),
            Text(t.gainsMigrating,
                style: TextStyle(color: colors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(t.gainsMigratingDesc,
                style: TextStyle(color: colors.textSecondary, fontSize: 13),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  // ── Carte niveau créateur & paliers ──────────────────────
  Widget _tierInfoCard(UserData user, AppColors colors) {
    final score     = user.creatorScore ?? 0.0;
    final tier      = _getTier(score);
    final tierLabel = tier['label'] as String;
    final tierColor = Color(tier['color'] as int);
    final myRate    = _fcfaPerView(score);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tierColor.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête — cliquable pour tout ouvrir
          GestureDetector(
            onTap: () => setState(() => _tierInfoExpanded = !_tierInfoExpanded),
            behavior: HitTestBehavior.opaque,
            child: Row(children: [
              Icon(Icons.emoji_events_outlined, color: tierColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(context.tr('Votre niveau créateur'),
                    style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
              ),
              Icon(
                _tierInfoExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                color: colors.textSecondary, size: 22,
              ),
            ]),
          ),
          const SizedBox(height: 14),

          // Badge niveau actuel (toujours visible)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: BoxDecoration(
              color: tierColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: tierColor.withOpacity(0.35)),
            ),
            child: Row(children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(context.tr('Niveau actuel'),
                    style: TextStyle(color: colors.textSecondary, fontSize: 11)),
                const SizedBox(height: 2),
                Text(tierLabel,
                    style: TextStyle(color: tierColor, fontWeight: FontWeight.w800, fontSize: 22)),
                const SizedBox(height: 2),
                Text(context.tr('Score : {a}', {'a': score.toStringAsFixed(1)}),
                    style: TextStyle(color: colors.textSecondary, fontSize: 11)),
              ]),
              const Spacer(),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(context.tr('Votre RPM'),
                    style: TextStyle(color: colors.textSecondary, fontSize: 11)),
                const SizedBox(height: 2),
                Text(Money.fmt(myRate * 1000),
                    style: TextStyle(color: tierColor, fontWeight: FontWeight.bold, fontSize: 20)),
                Text(context.tr('pour 1 000 vues'),
                    style: TextStyle(color: tierColor.withOpacity(0.7), fontSize: 10)),
              ]),
            ]),
          ),

          // Contenu dépliable
          if (_tierInfoExpanded) ...[
            const SizedBox(height: 14),
            Divider(color: colors.divider, height: 1),
            const SizedBox(height: 14),

            // Tableau des paliers
            Text(context.tr('Tous les paliers'),
                style: TextStyle(color: colors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
            const SizedBox(height: 10),
            ..._scoreTiers.map((t) {
              final tColor  = Color(t['color'] as int);
              final tLabel  = t['label'] as String;
              final tMulti  = t['multiplier'] as double;
              final tMin    = t['minScore'] as double;
              final isActive = tierLabel == tLabel;
              final tRate   = _baseViewRate * tMulti;

              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: isActive ? tColor.withOpacity(0.12) : colors.surfaceVariant,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isActive ? tColor.withOpacity(0.5) : Colors.transparent,
                    width: isActive ? 1.5 : 1,
                  ),
                ),
                child: Row(children: [
                  Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(
                      color: isActive ? tColor : tColor.withOpacity(0.4),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      context.tr('{a}  (score ≥ {b})', {'a': tLabel, 'b': tMin.toStringAsFixed(0)}),
                      style: TextStyle(
                        color: isActive ? colors.textPrimary : colors.textSecondary,
                        fontWeight: isActive ? FontWeight.w700 : FontWeight.normal,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Text(
                    context.tr('{a} RPM', {'a': Money.fmt(tRate * 1000)}),
                    style: TextStyle(
                      color: isActive ? tColor : colors.textSecondary,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.normal,
                      fontSize: 12,
                    ),
                  ),
                  if (isActive) ...[
                    const SizedBox(width: 6),
                    Icon(Icons.check_circle, color: tColor, size: 14),
                  ],
                ]),
              );
            }),

            const SizedBox(height: 14),
            Divider(color: colors.divider, height: 1),
            const SizedBox(height: 12),

            // Comment progresser
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.lightbulb_outline, color: colors.warning, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(context.tr('Comment progresser ?'),
                      style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(
                    context.tr('Publie régulièrement du contenu de qualité. Plus tes posts reçoivent de likes, loves et commentaires de ta communauté, plus ton score créateur monte — et plus ton RPM augmente.'),
                    style: TextStyle(color: colors.textSecondary, fontSize: 11.5, height: 1.5),
                  ),
                ]),
              ),
            ]),

            const SizedBox(height: 12),

            // Message motivant
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFF22C55E).withOpacity(0.1), const Color(0xFF3B82F6).withOpacity(0.1)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF22C55E).withOpacity(0.25)),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('🚀', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.tr('Certains créateurs Élite touchent déjà plus de {a} RPM. Comment ? Le RPM de base augmente avec la croissance de la plateforme — et les créateurs avec le meilleur score en bénéficient en premier. Plus tôt tu montes de palier, plus tu en profites.', {'a': Money.fmt(5000)}),
                    style: TextStyle(color: colors.textPrimary, fontSize: 11.5, height: 1.5),
                  ),
                ),
              ]),
            ),
          ], // fin section dépliable
        ],
      ),
    );
  }

  // ── Carte statistiques ────────────────────────────────────
  Widget _statsCard(UserData user, AppColors colors, AppLocalizations t) {
    final score      = user.creatorScore ?? 0.0;
    final tier       = _getTier(score);
    final rate       = _fcfaPerView(score);
    final tierLabel  = tier['label'] as String;
    final tierColor  = Color(tier['color'] as int);
    final totalViews = ((user.totalPostUniqueViews ?? 0) - _excludedViews).clamp(0, 1 << 40);
    final available  = _availableEarnings(user);
    final cashed     = user.postViewsTotalCashed ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.surface, colors.surfaceVariant],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tierColor.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête avec palier
          Row(children: [
            Icon(Icons.bar_chart_rounded, color: tierColor, size: 20),
            const SizedBox(width: 8),
            Text(t.gainsStats,
                style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: tierColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: tierColor.withOpacity(0.4)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.trending_up_rounded, size: 12, color: tierColor),
                const SizedBox(width: 4),
                Text(tierLabel,
                    style: TextStyle(color: tierColor, fontSize: 11, fontWeight: FontWeight.w700)),
              ]),
            ),
          ]),
          const SizedBox(height: 4),
          Text(
            context.tr('{a} RPM  ·  {b}% du taux de base ({c} RPM max)', {'a': Money.fmt(rate * 1000), 'b': ((tier['multiplier'] as double) * 100).toStringAsFixed(0), 'c': Money.fmt(1000)}),
            style: TextStyle(color: colors.textSecondary, fontSize: 11),
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _statChip(t.gainsTotalViews, '$totalViews', Icons.visibility_outlined, colors.info, colors)),
            const SizedBox(width: 12),
            Expanded(child: _statChip(t.gainsPerView, context.tr('{a} RPM', {'a': Money.fmt(rate * 1000)}), Icons.attach_money, tierColor, colors)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _statChip(t.gainsAvailable, Money.fmt(available), Icons.account_balance_wallet_outlined, tierColor, colors,
                subtitle: context.tr('{a} vues payables', {'a': _pendingViews(user)}))),
            const SizedBox(width: 12),
            Expanded(child: _statChip(t.gainsTotalCashed, Money.fmt(cashed), Icons.check_circle_outline, colors.primary, colors)),
          ]),
          if (_excludedViews > 0) ...[
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _statChip(context.tr('Vues non monétisées'), '$_excludedViews', Icons.visibility_off_outlined, colors.textSecondary, colors,
                  subtitle: context.tr('posts non monétisés : ces vues ne rapportent rien'))),
            ]),
          ],
        ],
      ),
    );
  }

  Widget _statChip(String label, String value, IconData icon, Color color, AppColors colors, {String? subtitle}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: color, size: 13),
            const SizedBox(width: 4),
            Flexible(child: Text(label, style: TextStyle(color: colors.textSecondary, fontSize: 10),
                overflow: TextOverflow.ellipsis)),
          ]),
          const SizedBox(height: 5),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle, style: TextStyle(color: color.withOpacity(0.7), fontSize: 11)),
          ],
        ],
      ),
    );
  }

  // ── Carte encaissement ────────────────────────────────────
  Widget _encaissCard(UserData user, AppColors colors, AppLocalizations t) {
    final available  = _availableEarnings(user);
    final canEncash = available >= _minEncaissement;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.payments_outlined, color: colors.primary, size: 20),
            const SizedBox(width: 8),
            Text(t.gainsEncaissTitle,
                style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
          ]),
          const SizedBox(height: 4),
          Text(t.gainsEncaissAvail(available.toInt()),
              style: TextStyle(color: colors.accent, fontWeight: FontWeight.bold, fontSize: 13)),
          // Plafond du jour : valeurs données par l'API (`daily_cap_xof`, `cashed_today_xof`), affichées telles quelles
          if (_dailyCapXof != null && _cashedTodayXof != null) ...[
            const SizedBox(height: 6),
            Text(
              context.tr("Plafond d'encaissement du jour : {a}. Déjà encaissé aujourd'hui : {b}.", {'a': Money.fmt(_dailyCapXof!), 'b': Money.fmt(_cashedTodayXof!)}),
              key: const Key('views_daily_cap'),
              style: TextStyle(color: colors.textSecondary, fontSize: 12, height: 1.4),
            ),
          ],
          const SizedBox(height: 16),

          if (!canEncash)
            _infoBox(t.gainsEncaissMinMsg, colors.warning, Icons.info_outline, colors)
          else ...[
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              style: TextStyle(color: colors.textPrimary),
              decoration: InputDecoration(
                labelText: t.gainsEncaissLabel,
                labelStyle: TextStyle(color: colors.textSecondary),
                hintText: t.gainsEncaissHint(_minEncaissement.toInt(), available.toInt()),
                hintStyle: TextStyle(color: colors.textSecondary, fontSize: 12),
                filled: true,
                fillColor: colors.surfaceVariant,
                border: _border(colors.border),
                enabledBorder: _border(colors.border),
                focusedBorder: _border(colors.accent),
                suffixText: 'FCFA',
                suffixStyle: TextStyle(color: colors.textSecondary),
              ),
            ),
            const SizedBox(height: 10),
            Row(children: [
              _quickBtn('25%', available * 0.25, colors),
              const SizedBox(width: 8),
              _quickBtn('50%', available * 0.50, colors),
              const SizedBox(width: 8),
              _quickBtn('100%', available, colors),
            ]),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _isEncashing ? null : () => _encaisser(user, t, colors),
                child: _isEncashing
                    ? const SizedBox(height: 18, width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(t.gainsEncaissBtn,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _quickBtn(String label, double amount, AppColors colors) {
    return GestureDetector(
      onTap: () => _amountController.text = amount.toInt().toString(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: colors.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colors.border),
        ),
        child: Text(label, style: TextStyle(color: colors.textSecondary, fontSize: 12)),
      ),
    );
  }

  // ── Historique mensuel ────────────────────────────────────
  Widget _monthlyCard(UserData user, AppColors colors, AppLocalizations t) {
    final monthly = user.postViewsMonthly ?? {};
    // Fusionner les clés : postViewsMonthly + postViewsMonthlyPostIds (source fiable)
    final allKeys = <String>{...monthly.keys, ..._monthlyPostIds.keys};
    if (allKeys.isEmpty) return const SizedBox.shrink();

    final now = DateTime.now();
    final currentYear = now.year;

    // Construire une map fusionnée : clé → nombre de vues
    // On prend le max entre la valeur stockée et le nombre de posts IDs du mois
    final merged = <String, int>{};
    for (final key in allKeys) {
      try {
        final year = int.parse(key.split('-').first);
        if (year < 2020 || year > currentYear + 1) continue;
      } catch (_) { continue; }
      final stored = monthly[key] ?? 0;
      final idCount = _monthlyPostIds[key]?.length ?? 0;
      merged[key] = stored > 0 ? stored : idCount;
    }

    if (merged.isEmpty) return const SizedBox.shrink();

    final sorted = merged.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));

    const int defaultVisible = 3;
    final visible = _showAllMonths ? sorted : sorted.take(defaultVisible).toList();
    final hiddenCount = sorted.length - defaultVisible;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.calendar_month_outlined, color: colors.info, size: 18),
            const SizedBox(width: 8),
            Text(t.gainsMonthTitle,
                style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
          ]),
          const SizedBox(height: 12),
          ...visible.map((e) {
            final views = e.value;
            final rate  = _fcfaPerView(user.creatorScore ?? 0);
            final fcfa  = (views * rate).toInt();
            return GestureDetector(
              onTap: () => _showMonthPostsBottomSheet(widget.userId, e.key, rate),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: colors.surfaceVariant,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: colors.border),
                ),
                child: Row(children: [
                  Expanded(child: Text(_formatMonth(e.key),
                      style: TextStyle(color: colors.textPrimary, fontSize: 13))),
                  Text(t.gainsMonthViews(views),
                      style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                  const SizedBox(width: 12),
                  Text(Money.fmt(fcfa),
                      style: TextStyle(color: colors.accent, fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(width: 8),
                  Icon(Icons.chevron_right, color: colors.textSecondary, size: 16),
                ]),
              ),
            );
          }),
          if (sorted.length > defaultVisible)
            GestureDetector(
              onTap: () => setState(() => _showAllMonths = !_showAllMonths),
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(
                    _showAllMonths ? t.gainsSeeLess : t.gainsSeeMore(hiddenCount),
                    style: TextStyle(color: colors.info, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 4),
                  Icon(_showAllMonths ? Icons.expand_less : Icons.expand_more,
                      color: colors.info, size: 18),
                ]),
              ),
            ),
        ],
      ),
    );
  }

  void _showMonthPostsBottomSheet(String userId, String monthKey, double rate) {
    showResponsiveBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MonthPostsSheet(
        userId: userId,
        monthKey: monthKey,
        fcfaPerView: rate,
        onPostTap: _openPostDetail,
        formatMonth: _formatMonth,
      ),
    );
  }

  void _openPostDetail(Post post) {
    final isVideo = post.dataType == PostDataType.VIDEO.name;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => isVideo
          ? VideoYoutubePageDetails(initialPost: post)
          : DetailsPost(post: post),
    ));
  }

  String _formatMonth(String key) {
    try {
      final p  = key.split('-');
      final dt = DateTime(int.parse(p[0]), int.parse(p[1]));
      return DateFormat('MMMM yyyy', 'fr_FR').format(dt);
    } catch (_) { return key; }
  }

  // ── Historique transactions ───────────────────────────────
  Widget _historyCard(AppColors colors, AppLocalizations t) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.history, color: colors.textSecondary, size: 18),
            const SizedBox(width: 8),
            Text(t.gainsHistoryTitle,
                style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
          ]),
          const SizedBox(height: 12),
          if (_isLoadingHistory)
            Center(child: CircularProgressIndicator(color: colors.accent, strokeWidth: 2))
          else if (_history.isEmpty)
            Text(t.gainsHistoryEmpty,
                style: TextStyle(color: colors.textSecondary, fontSize: 13))
          else
            ..._history.map((tx) => _txRow(tx, colors, t)),
        ],
      ),
    );
  }

  Widget _txRow(Map<String, dynamic> tx, AppColors colors, AppLocalizations t) {
    final montant = (tx['montant'] as num?)?.toInt() ?? 0;
    final ts   = tx['createdAt'] as int?;
    final date = ts != null
        ? DateFormat('dd/MM/yyyy HH:mm').format(DateTime.fromMillisecondsSinceEpoch(ts))
        : '—';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(children: [
        Icon(Icons.check_circle, color: colors.primary, size: 16),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t.gainsTxLabel(montant),
                style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
            Text(date, style: TextStyle(color: colors.textSecondary, fontSize: 11)),
          ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: colors.primary.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(t.gainsTxStatus,
              style: TextStyle(color: colors.primary, fontSize: 11, fontWeight: FontWeight.bold)),
        ),
      ]),
    );
  }

  // ── Helpers ───────────────────────────────────────────────
  Widget _infoBox(String msg, Color color, IconData icon, AppColors colors) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Expanded(child: Text(msg, style: TextStyle(color: color, fontSize: 12))),
      ]),
    );
  }

  OutlineInputBorder _border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: color));
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom sheet paginé — posts d'un mois
// ─────────────────────────────────────────────────────────────────────────────

class _MonthPostsSheet extends StatefulWidget {
  final String userId;
  final String monthKey;
  final double fcfaPerView;
  final void Function(Post) onPostTap;
  final String Function(String) formatMonth;

  const _MonthPostsSheet({
    required this.userId,
    required this.monthKey,
    required this.fcfaPerView,
    required this.onPostTap,
    required this.formatMonth,
  });

  @override
  State<_MonthPostsSheet> createState() => _MonthPostsSheetState();
}

class _MonthPostsSheetState extends State<_MonthPostsSheet> {
  static const int _pageSize = 20;

  final List<Post> _posts = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = false;

  List<String> _allPostIds = [];
  int _idOffset = 0;
  Map<String, int> _perPostViews = {};

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    // Le détail des publications d'un mois n'est pas encore exposé par l'API (voir lacunes_api_argent_creations.md).
    if (mounted) setState(() => _isLoading = false);
  }

  // Vues réelles d'un post : priorité postViewsPerPost du user > champs post
  int _viewsOf(Post p) =>
      _perPostViews[p.id] ?? p.users_vue_id!.length ?? p.vues ?? 0;

  Future<void> _loadMore() async {}

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    final ts = value is int ? value : int.tryParse(value.toString());
    if (ts == null) return null;
    return ts > 9999999999999
        ? DateTime.fromMicrosecondsSinceEpoch(ts)
        : DateTime.fromMillisecondsSinceEpoch(ts);
  }

  String _formatDate(dynamic value) {
    final dt = _parseDate(value);
    if (dt == null) return '—';
    return DateFormat('dd/MM/yyyy', 'fr_FR').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final t = AppLocalizations.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (ctx, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(children: [
          const SizedBox(height: 8),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: colors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              Icon(Icons.calendar_today_outlined, color: colors.info, size: 18),
              const SizedBox(width: 8),
              Text(
                widget.formatMonth(widget.monthKey),
                style: TextStyle(
                    color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: colors.accent, strokeWidth: 2))
                : _posts.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(t.gainsMonthPostsEmpty,
                              style: TextStyle(color: colors.textSecondary, fontSize: 14),
                              textAlign: TextAlign.center),
                        ),
                      )
                    : ListView.separated(
                        controller: scrollCtrl,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: _posts.length + (_hasMore ? 1 : 0),
                        separatorBuilder: (_, __) => Divider(color: colors.border, height: 1),
                        itemBuilder: (ctx, i) {
                          if (i == _posts.length) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: _isLoadingMore
                                    ? CircularProgressIndicator(
                                        color: colors.accent, strokeWidth: 2)
                                    : TextButton.icon(
                                        onPressed: _loadMore,
                                        icon: Icon(Icons.expand_more, color: colors.info),
                                        label: Text(
                                          context.tr('Voir plus ({a} restants)', {'a': _allPostIds.length - _idOffset}),
                                          style: TextStyle(color: colors.info),
                                        ),
                                      ),
                              ),
                            );
                          }
                          return _buildPostItem(_posts[i], colors, t);
                        },
                      ),
          ),
        ]),
      ),
    );
  }

  Widget _buildPostItem(Post post, AppColors colors, AppLocalizations t) {
    final thumb = (post.thumbnail?.isNotEmpty == true)
        ? post.thumbnail
        : (post.images?.isNotEmpty == true ? post.images!.first : null);
    final views = _viewsOf(post);
    final desc = post.description?.trim() ?? '';

    return GestureDetector(
      onTap: () => widget.onPostTap(post),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(children: [
          if (thumb != null && thumb.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                thumb,
                width: 54, height: 54, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _placeholder(colors),
              ),
            )
          else
            _placeholder(colors),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (desc.isNotEmpty)
                Text(desc,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: colors.textPrimary, fontSize: 13)),
              const SizedBox(height: 4),
              Text(_formatDate(post.createdAt),
                  style: TextStyle(color: colors.textSecondary, fontSize: 11)),
            ]),
          ),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: colors.info.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.visibility_outlined, color: colors.info, size: 12),
                const SizedBox(width: 4),
                Text('$views',
                    style: TextStyle(
                        color: colors.info, fontWeight: FontWeight.bold, fontSize: 12)),
              ]),
            ),
            const SizedBox(height: 4),
            Text(Money.fmt(views * widget.fcfaPerView),
                style: TextStyle(
                    color: colors.accent, fontWeight: FontWeight.bold, fontSize: 12)),
          ]),
        ]),
      ),
    );
  }

  Widget _placeholder(AppColors colors) => Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          color: colors.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.image_outlined, color: colors.textSecondary, size: 22),
      );
}
