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

const double _fcfaPerView = 2.0;
const double _minEncaissement = 1000.0;

class MesGainsPage extends StatefulWidget {
  final String userId;
  const MesGainsPage({Key? key, required this.userId}) : super(key: key);

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
    final available = user.postViewsAvailable ?? 0;

    if (input < _minEncaissement) { _snack(t.gainsErrMin, colors.danger); return; }
    if (input > available)        { _snack(t.gainsErrMax, colors.danger); return; }

    final enCours = await _remuService.isEncaissementEnCours(widget.userId);
    if (enCours) { _snack(t.gainsErrCooldown, colors.danger); return; }

    setState(() => _isEncashing = true);
    try {
      await _firestore.runTransaction((tx) async {
        final ref  = _firestore.collection('Users').doc(widget.userId);
        final snap = await tx.get(ref);
        final cur  = (snap.data()?['postViewsAvailable'] as num?)?.toDouble() ?? 0;
        if (input > cur) throw Exception('solde_insuffisant');
        tx.update(ref, {
          'postViewsAvailable':   FieldValue.increment(-input),
          'postViewsTotalCashed': FieldValue.increment(input),
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
    final user = Provider.of<UserAuthProvider>(context).loginUserData;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(t.gainsTitle,
            style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold)),
        backgroundColor: colors.background,
        iconTheme: IconThemeData(color: colors.textPrimary),
        elevation: 0,
      ),
      body: _isMigrating
          ? _migrationLoader(colors, t)
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _statsCard(user, colors, t),
                  const SizedBox(height: 16),
                  _encaissCard(user, colors, t),
                  const SizedBox(height: 16),
                  _monthlyCard(user, colors, t),
                  const SizedBox(height: 16),
                  _historyCard(colors, t),
                  const SizedBox(height: 32),
                ],
              ),
            ),
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

  // ── Carte statistiques ────────────────────────────────────
  Widget _statsCard(UserData user, AppColors colors, AppLocalizations t) {
    final totalViews = user.totalPostUniqueViews ?? 0;
    final available  = user.postViewsAvailable   ?? 0;
    final cashed     = user.postViewsTotalCashed  ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.surface, colors.surfaceVariant],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.accent.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.bar_chart_rounded, color: colors.accent, size: 20),
            const SizedBox(width: 8),
            Text(t.gainsStats,
                style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _statChip(t.gainsTotalViews, '$totalViews', Icons.visibility_outlined, colors.info, colors)),
            const SizedBox(width: 12),
            Expanded(child: _statChip(t.gainsPerView, t.gainsPerViewRate, Icons.attach_money, colors.primary, colors)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _statChip(t.gainsAvailable, '${available.toInt()} FCFA', Icons.account_balance_wallet_outlined, colors.accent, colors)),
            const SizedBox(width: 12),
            Expanded(child: _statChip(t.gainsTotalCashed, '${cashed.toInt()} FCFA', Icons.check_circle_outline, colors.primary, colors)),
          ]),
        ],
      ),
    );
  }

  Widget _statChip(String label, String value, IconData icon, Color color, AppColors colors) {
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
        ],
      ),
    );
  }

  // ── Carte encaissement ────────────────────────────────────
  Widget _encaissCard(UserData user, AppColors colors, AppLocalizations t) {
    final available = user.postViewsAvailable ?? 0;
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
    if (monthly.isEmpty) return const SizedBox.shrink();

    final now = DateTime.now();
    final threeMonthsAgo = now.subtract(const Duration(days: 90));

    // Garder uniquement les 3 derniers mois valides (pas de dates futures ni corrompues).
    final sorted = monthly.entries.where((e) {
      try {
        final p = e.key.split('-');
        final dt = DateTime(int.parse(p[0]), int.parse(p[1]));
        return !dt.isBefore(DateTime(threeMonthsAgo.year, threeMonthsAgo.month))
            && !dt.isAfter(DateTime(now.year, now.month));
      } catch (_) { return false; }
    }).toList()
      ..sort((a, b) => b.key.compareTo(a.key));

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
          ...sorted.take(3).map((e) {
            final views = e.value;
            final fcfa  = (views * _fcfaPerView).toInt();
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(children: [
                Expanded(child: Text(_formatMonth(e.key),
                    style: TextStyle(color: colors.textPrimary, fontSize: 13))),
                Text(t.gainsMonthViews(views),
                    style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                const SizedBox(width: 12),
                Text('$fcfa FCFA',
                    style: TextStyle(color: colors.accent, fontWeight: FontWeight.bold, fontSize: 13)),
              ]),
            );
          }),
        ],
      ),
    );
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
