import 'package:afrotok/layout/centered_content.dart';
import 'package:afrotok/utils/responsive_sheet.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../models/model_data.dart';
import '../../providers/authProvider.dart';
import '../../services/postService/post_view_service.dart';
import '../../services/remuneration_service.dart';
import '../../theme/app_colors.dart';
import '../postDetails.dart';
import '../postDetailsVideo.dart';

const double _minEncaissement = 1000.0;
const double _baseViewRate = 1.0;

const _scoreTiers = [
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

double _fcfaPerView(double creatorScore) {
  final t = _getTier(creatorScore);
  return _baseViewRate * (t['multiplier'] as double);
}

class MesGainsPage extends StatefulWidget {
  final String userId;
  final bool isAdminView;
  const MesGainsPage({Key? key, required this.userId, this.isAdminView = false}) : super(key: key);

  @override
  State<MesGainsPage> createState() => _MesGainsPageState();
}

class _MesGainsPageState extends State<MesGainsPage> {
  final _firestore = FirebaseFirestore.instance;
  final _remuService = RemunerationService();
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    if (widget.isAdminView) {
      // Mode lecture admin : charger les données de l'utilisateur ciblé depuis Firestore
      setState(() => _isLoadingViewedUser = true);
      try {
        final snap = await _firestore.collection('Users').doc(widget.userId).get();
        if (snap.exists && mounted) {
          final data = Map<String, dynamic>.from(snap.data()!);
          data['id'] = snap.id;
          final rawIds = data['postViewsMonthlyPostIds'] as Map<String, dynamic>?;
          setState(() {
            _viewedUser = UserData.fromJson(data);
            _monthlyPostIds = rawIds?.map((k, v) =>
                MapEntry(k, List<String>.from(v as List? ?? []))) ?? {};
          });
        }
      } catch (_) {}
      if (mounted) setState(() => _isLoadingViewedUser = false);
      _loadHistory();
      return;
    }

    final auth = Provider.of<UserAuthProvider>(context, listen: false);
    final user = auth.loginUserData;

    if (user.postViewsMigrationDone != true) {
      setState(() => _isMigrating = true);
      await PostViewService.migrateUserPostViews(widget.userId);
      await auth.refreshUserData();
      if (mounted) setState(() => _isMigrating = false);
    } else if (_hasCorruptMonthly(user)) {
      // Migration déjà faite mais map mensuelle corrompue (dates en µs traitées
      // en ms lors d'une ancienne version → années comme 57708). On recalcule
      // uniquement la map mensuelle sans toucher les soldes.
      setState(() => _isMigrating = true);
      await PostViewService.fixMonthlyData(widget.userId);
      await auth.refreshUserData();
      if (mounted) setState(() => _isMigrating = false);
    }
    // Lire postViewsMonthlyPostIds directement depuis Firestore (source fiable des mois)
    try {
      final snap = await _firestore.collection('Users').doc(widget.userId).get();
      if (snap.exists && mounted) {
        final raw = snap.data()?['postViewsMonthlyPostIds'] as Map<String, dynamic>?;
        setState(() {
          _monthlyPostIds = raw?.map((k, v) =>
              MapEntry(k, List<String>.from(v as List? ?? []))) ?? {};
        });
      }
    } catch (_) {}
    _loadHistory();
  }

  bool _hasCorruptMonthly(UserData user) {
    final monthly = user.postViewsMonthly ?? {};
    final currentYear = DateTime.now().year;
    return monthly.keys.any((k) {
      try { return int.parse(k.split('-').first) > currentYear + 1; }
      catch (_) { return false; }
    });
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoadingHistory = true);
    try {
      final snap = await _firestore
          .collection('TransactionSoldes')
          .where('user_id', isEqualTo: widget.userId)
          .where('type', isEqualTo: 'ENCAISSEMENT_VUES_POST')
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get();
      _history = snap.docs.map((d) {
        final data = d.data();
        data['id'] = d.id;
        return data;
      }).toList();
    } catch (_) {}
    if (mounted) setState(() => _isLoadingHistory = false);
  }

  Future<void> _encaisser(UserData user, AppLocalizations t, AppColors colors) async {
    final input = double.tryParse(_amountController.text.trim()) ?? 0;
    final totalViews = user.totalPostUniqueViews ?? 0;
    final cashed     = user.postViewsTotalCashed  ?? 0;
    final rate       = _fcfaPerView(user.creatorScore ?? 0);
    final available  = ((totalViews * rate) - cashed).clamp(0.0, double.infinity);

    if (input < _minEncaissement) { _snack(t.gainsErrMin, colors.danger); return; }
    if (input > available)        { _snack(t.gainsErrMax, colors.danger); return; }

    final enCours = await _remuService.isEncaissementEnCours(widget.userId);
    if (enCours) { _snack(t.gainsErrCooldown, colors.danger); return; }

    setState(() => _isEncashing = true);
    try {
      await _firestore.runTransaction((tx) async {
        final ref  = _firestore.collection('Users').doc(widget.userId);
        final snap = await tx.get(ref);
        final views = (snap.data()?['totalPostUniqueViews'] as num?)?.toInt() ?? 0;
        final cur   = (snap.data()?['postViewsTotalCashed'] as num?)?.toDouble() ?? 0;
        final score = (snap.data()?['creatorScore'] as num?)?.toDouble() ?? 0;
        final curRate = _fcfaPerView(score);
        final curAvailable = ((views * curRate) - cur).clamp(0.0, double.infinity);
        if (input > curAvailable) throw Exception('solde_insuffisant');
        tx.update(ref, {
          'postViewsTotalCashed':  FieldValue.increment(input),
          'votre_solde_principal': FieldValue.increment(input),
          'votre_solde':           FieldValue.increment(input),
        });
        tx.set(_firestore.collection('TransactionSoldes').doc(), {
          'user_id': widget.userId,
          'type': 'ENCAISSEMENT_VUES_POST',
          'statut': 'VALIDER',
          'montant': input,
          'description': 'Encaissement ${input.toInt()} FCFA — vues posts',
          'methode_paiement': 'solde_principal',
          'createdAt': DateTime.now().millisecondsSinceEpoch,
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        });
      });
      _amountController.clear();
      await Provider.of<UserAuthProvider>(context, listen: false).refreshUserData();
      await _loadHistory();
      _snack(t.gainsSuccess(input.toInt()), colors.primary);
    } on Exception catch (e) {
      _snack(e.toString().contains('solde_insuffisant') ? t.gainsErrInsuff : t.gainsErrGeneral, colors.danger);
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
      titleText = 'Gains de @${_viewedUser!.pseudo ?? ''}';
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
                child: Text('Votre niveau créateur',
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
                Text('Niveau actuel',
                    style: TextStyle(color: colors.textSecondary, fontSize: 11)),
                const SizedBox(height: 2),
                Text(tierLabel,
                    style: TextStyle(color: tierColor, fontWeight: FontWeight.w800, fontSize: 22)),
              ]),
              const Spacer(),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('Votre RPM',
                    style: TextStyle(color: colors.textSecondary, fontSize: 11)),
                const SizedBox(height: 2),
                Text('${(myRate * 1000).toInt()} FCFA',
                    style: TextStyle(color: tierColor, fontWeight: FontWeight.bold, fontSize: 20)),
                Text('pour 1 000 vues',
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
            Text('Tous les paliers',
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
                      '$tLabel  (score ≥ ${tMin.toStringAsFixed(0)})',
                      style: TextStyle(
                        color: isActive ? colors.textPrimary : colors.textSecondary,
                        fontWeight: isActive ? FontWeight.w700 : FontWeight.normal,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Text(
                    '${(tRate * 1000).toInt()} FCFA RPM',
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
                  Text('Comment progresser ?',
                      style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(
                    'Publie régulièrement du contenu de qualité. Plus tes posts reçoivent de likes, loves et commentaires de ta communauté, plus ton score créateur monte — et plus ton RPM augmente.',
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
                    'Certains créateurs Élite touchent déjà plus de 5 000 FCFA RPM. Comment ? Le RPM de base augmente avec la croissance de la plateforme — et les créateurs avec le meilleur score en bénéficient en premier. Plus tôt tu montes de palier, plus tu en profites.',
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
    final totalViews = user.totalPostUniqueViews ?? 0;
    final cashed     = user.postViewsTotalCashed  ?? 0;
    final available  = ((totalViews * rate) - cashed).clamp(0.0, double.infinity);

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
            '${(rate * 1000).toInt()} FCFA RPM  ·  ${((tier['multiplier'] as double) * 100).toStringAsFixed(0)}% du taux de base (1 000 FCFA RPM max)',
            style: TextStyle(color: colors.textSecondary, fontSize: 11),
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _statChip(t.gainsTotalViews, '$totalViews', Icons.visibility_outlined, colors.info, colors)),
            const SizedBox(width: 12),
            Expanded(child: _statChip(t.gainsPerView, '${(rate * 1000).toInt()} FCFA RPM', Icons.attach_money, tierColor, colors)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _statChip(t.gainsAvailable, '${available.toInt()} FCFA', Icons.account_balance_wallet_outlined, tierColor, colors,
                subtitle: '$totalViews vues')),
            const SizedBox(width: 12),
            Expanded(child: _statChip(t.gainsTotalCashed, '${cashed.toInt()} FCFA', Icons.check_circle_outline, colors.primary, colors)),
          ]),
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
    final rate       = _fcfaPerView(user.creatorScore ?? 0);
    final totalViews = user.totalPostUniqueViews ?? 0;
    final cashed     = user.postViewsTotalCashed  ?? 0;
    final available  = ((totalViews * rate) - cashed).clamp(0.0, double.infinity);
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
                  Text('$fcfa FCFA',
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
        firestore: _firestore,
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
  final FirebaseFirestore firestore;
  final void Function(Post) onPostTap;
  final String Function(String) formatMonth;

  const _MonthPostsSheet({
    required this.userId,
    required this.monthKey,
    required this.fcfaPerView,
    required this.firestore,
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
    final userDoc = await widget.firestore.collection('Users').doc(widget.userId).get();
    final data = userDoc.data() ?? {};

    // Vues par post (source de vérité pour l'affichage)
    final rawPerPost = data['postViewsPerPost'] as Map<String, dynamic>?;
    _perPostViews = rawPerPost?.map((k, v) => MapEntry(k, (v as num).toInt())) ?? {};

    final monthlyIds = (data['postViewsMonthlyPostIds'] as Map<String, dynamic>?) ?? {};
    final rawIds = monthlyIds[widget.monthKey];
    _allPostIds = rawIds is List ? List<String>.from(rawIds.whereType<String>()) : [];

    if (_allPostIds.isNotEmpty) {
      await _loadNextIdBatch();
    } else {
      await _loadFallback();
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadNextIdBatch() async {
    final end = (_idOffset + _pageSize).clamp(0, _allPostIds.length);
    final batch = _allPostIds.sublist(_idOffset, end);
    if (batch.isEmpty) { _hasMore = false; return; }

    final newPosts = <Post>[];
    for (int i = 0; i < batch.length; i += 30) {
      final sub = batch.sublist(i, (i + 30).clamp(0, batch.length));
      final snap = await widget.firestore
          .collection('Posts')
          .where(FieldPath.documentId, whereIn: sub)
          .get();
      newPosts.addAll(snap.docs.map((d) {
        final data = Map<String, dynamic>.from(d.data());
        data['id'] = d.id;
        return Post.fromJson(data);
      }).where((p) {
        if (p.isAdvertisement == true) return false;
        return true;
      }));
    }

    _posts.addAll(newPosts);
    _posts.sort((a, b) => _viewsOf(b).compareTo(_viewsOf(a)));
    _idOffset = end;
    _hasMore = _idOffset < _allPostIds.length;
  }

  Future<void> _loadFallback() async {
    final snap = await widget.firestore
        .collection('Posts')
        .where('user_id', isEqualTo: widget.userId)
        .where('type', isEqualTo: PostType.POST.name)
        .orderBy('created_at', descending: true)
        .limit(300)
        .get();

    final loaded = snap.docs.map((d) {
      final data = Map<String, dynamic>.from(d.data());
      data['id'] = d.id;
      return Post.fromJson(data);
    }).where((p) {
      if (p.isAdvertisement == true) return false;
      return _viewsOf(p) >= 1;
    }).toList()
      ..sort((a, b) => _viewsOf(b).compareTo(_viewsOf(a)));

    _posts.addAll(loaded);
    _hasMore = false;
  }

  // Vues réelles d'un post : priorité postViewsPerPost du user > champs post
  int _viewsOf(Post p) =>
      _perPostViews[p.id] ?? p.users_vue_id!.length ?? p.vues ?? 0;

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    await _loadNextIdBatch();
    if (mounted) setState(() => _isLoadingMore = false);
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
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
                                          'Voir plus (${_allPostIds.length - _idOffset} restants)',
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
            Text('${(views * widget.fcfaPerView).toInt()} FCFA',
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
