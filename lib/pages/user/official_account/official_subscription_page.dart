import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../models/model_data.dart';
import '../../../providers/authProvider.dart';
import '../../../services/official_account/official_account_service.dart';
import '../../../theme/app_colors.dart';

/// Page d'abonnement mensuel du compte officiel.
/// Affiche l'état de l'abonnement et permet le renouvellement manuel.
class OfficialSubscriptionPage extends StatefulWidget {
  const OfficialSubscriptionPage({super.key});

  @override
  State<OfficialSubscriptionPage> createState() =>
      _OfficialSubscriptionPageState();
}

class _OfficialSubscriptionPageState extends State<OfficialSubscriptionPage> {
  bool _loading = false;
  OfficialSubscription? _sub;
  double? _balance;
  bool _fetching = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    final me = context.read<UserAuthProvider>().loginUserData;
    final userId = me.id ?? '';
    final sub = await OfficialAccountService.instance.getSubscription(userId);
    final balanceSnap = await FirebaseFirestore.instance
        .collection('Users')
        .doc(userId)
        .get();
    if (!mounted) return;
    setState(() {
      _sub = sub;
      _balance = ((balanceSnap.data()?['votre_solde_principal'] ?? 0) as num).toDouble();
      _fetching = false;
    });
  }

  Future<void> _pay() async {
    final me = context.read<UserAuthProvider>().loginUserData;
    setState(() => _loading = true);
    try {
      final ok = await OfficialAccountService.instance.paySubscription(me.id ?? '');
      if (!mounted) return;
      if (ok) {
        await _fetchData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Abonnement renouvelé avec succès !'),
            backgroundColor: Color(0xFF4CAF50),
          ),
        );
      } else {
        _showInsufficientBalanceModal();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showInsufficientBalanceModal() {
    final colors = AppColors.of(context);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.account_balance_wallet_outlined, color: Colors.orange, size: 22),
            const SizedBox(width: 8),
            Text('Solde insuffisant',
                style: TextStyle(color: colors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        ),
        content: Text(
          'Votre solde est insuffisant pour renouveler l\'abonnement (5 000 FCFA requis).\n\n'
          'Rechargez votre compte pour maintenir votre statut de compte officiel.',
          style: TextStyle(color: colors.textSecondary, fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Fermer', style: TextStyle(color: colors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: naviguer vers la page de recharge
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Recharger', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final fmt = DateFormat('dd/MM/yyyy');

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: colors.textPrimary, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Abonnement officiel',
          style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
      body: _fetching
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Carte statut
                  _StatusCard(sub: _sub, colors: colors, fmt: fmt),
                  const SizedBox(height: 20),

                  // Solde actuel
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: colors.border.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.account_balance_wallet_outlined,
                            color: colors.primary, size: 22),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Votre solde',
                                style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                            Text(
                              '${_balance?.toStringAsFixed(0) ?? '0'} FCFA',
                              style: TextStyle(
                                  color: colors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 18),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Bouton payer
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _pay,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.primary,
                        disabledBackgroundColor: colors.border,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5, color: Colors.white))
                          : Text(
                              _sub?.active == true
                                  ? 'Renouveler maintenant (5 000 FCFA)'
                                  : 'Activer l\'abonnement (5 000 FCFA)',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15),
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Info
                  _InfoBlock(colors: colors),
                ],
              ),
            ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final OfficialSubscription? sub;
  final AppColors colors;
  final DateFormat fmt;

  const _StatusCard({required this.sub, required this.colors, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final isActive = sub?.active == true;
    final isLate = sub?.isLate == true;
    final daysLate = sub?.daysLate ?? 0;
    final isSuspendable = sub?.isSuspendable == true;

    Color statusColor;
    IconData statusIcon;
    String statusText;

    if (sub == null) {
      statusColor = colors.textSecondary;
      statusIcon = Icons.cancel_outlined;
      statusText = 'Aucun abonnement actif';
    } else if (isSuspendable) {
      statusColor = Colors.red;
      statusIcon = Icons.warning_rounded;
      statusText = '$daysLate jours de retard — Suspension imminente';
    } else if (isLate) {
      statusColor = Colors.orange;
      statusIcon = Icons.schedule_rounded;
      statusText = '$daysLate jour(s) de retard';
    } else if (isActive) {
      statusColor = const Color(0xFF4CAF50);
      statusIcon = Icons.check_circle_rounded;
      statusText = 'Actif';
    } else {
      statusColor = colors.textSecondary;
      statusIcon = Icons.cancel_outlined;
      statusText = 'Inactif';
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [statusColor.withValues(alpha: 0.12), statusColor.withValues(alpha: 0.04)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(statusIcon, color: statusColor, size: 20),
              const SizedBox(width: 8),
              Text('Statut de l\'abonnement',
                  style: TextStyle(color: colors.textSecondary, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 6),
          Text(statusText,
              style: TextStyle(
                  color: statusColor, fontWeight: FontWeight.w700, fontSize: 16)),
          if (sub != null) ...[
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            _Row(
              label: 'Dernier paiement',
              value: sub!.lastPaidAt != null ? fmt.format(sub!.lastPaidAt!) : '—',
              colors: colors,
            ),
            const SizedBox(height: 4),
            _Row(
              label: 'Prochain renouvellement',
              value: sub!.nextDueAt != null ? fmt.format(sub!.nextDueAt!) : '—',
              colors: colors,
              valueColor: isLate ? Colors.orange : null,
            ),
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label, value;
  final AppColors colors;
  final Color? valueColor;

  const _Row({
    required this.label,
    required this.value,
    required this.colors,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: TextStyle(color: colors.textSecondary, fontSize: 13)),
      Text(value,
          style: TextStyle(
              color: valueColor ?? colors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 13)),
    ],
  );
}

class _InfoBlock extends StatelessWidget {
  final AppColors colors;

  const _InfoBlock({required this.colors});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: colors.surfaceVariant,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      children: [
        _InfoItem(
          icon: Icons.autorenew_rounded,
          text: 'L\'abonnement est renouvelé automatiquement chaque mois sur votre solde.',
          colors: colors,
        ),
        const SizedBox(height: 8),
        _InfoItem(
          icon: Icons.notifications_active_outlined,
          text: 'Vous serez notifié à chaque prélèvement ou en cas de solde insuffisant.',
          colors: colors,
        ),
        const SizedBox(height: 8),
        _InfoItem(
          icon: Icons.block_rounded,
          text: 'Après 30 jours de retard, votre compte officiel peut être suspendu par l\'administration.',
          colors: colors,
        ),
      ],
    ),
  );
}

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String text;
  final AppColors colors;

  const _InfoItem({required this.icon, required this.text, required this.colors});

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 16, color: colors.textSecondary),
      const SizedBox(width: 8),
      Expanded(
        child: Text(text,
            style: TextStyle(color: colors.textSecondary, fontSize: 12, height: 1.4)),
      ),
    ],
  );
}
