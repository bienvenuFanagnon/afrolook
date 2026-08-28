import 'dart:async';
import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/providers/authProvider.dart';
import 'package:afrotok/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Affiché lorsque le compte de l'utilisateur est suspendu.
class SuspensionScreen extends StatefulWidget {
  final UserData user;

  const SuspensionScreen({Key? key, required this.user}) : super(key: key);

  @override
  State<SuspensionScreen> createState() => _SuspensionScreenState();
}

class _SuspensionScreenState extends State<SuspensionScreen> {
  Timer? _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _computeRemaining();
    if (widget.user.suspendedPermanently != true) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        _computeRemaining();
        if (_remaining.isNegative || _remaining == Duration.zero) {
          _timer?.cancel();
          if (mounted) {
            Provider.of<UserAuthProvider>(context, listen: false)
                .refreshUserData();
          }
        }
      });
    }
  }

  void _computeRemaining() {
    if (widget.user.suspendedUntil != null) {
      final until = DateTime.fromMillisecondsSinceEpoch(widget.user.suspendedUntil!);
      setState(() {
        _remaining = until.difference(DateTime.now());
        if (_remaining.isNegative) _remaining = Duration.zero;
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    if (d.inDays > 0) {
      final h = d.inHours.remainder(24);
      final m = d.inMinutes.remainder(60);
      return '${d.inDays}j ${h}h ${m}min';
    }
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '${h}h ${m}min ${s}s';
    if (m > 0) return '${m}min ${s}s';
    return '${s}s';
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isPermanent = widget.user.suspendedPermanently == true;
    final reason = widget.user.suspensionReason ?? 'Non précisée';

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.block, size: 48, color: Colors.red),
                ),
                const SizedBox(height: 28),
                Text(
                  isPermanent
                      ? 'Compte suspendu définitivement'
                      : 'Compte suspendu temporairement',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                if (!isPermanent && _remaining > Duration.zero) ...[
                  Text(
                    'Levée de la suspension dans :',
                    style: TextStyle(
                        fontSize: 13, color: colors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Text(
                      _formatDuration(_remaining),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: Colors.red,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (!isPermanent && _remaining == Duration.zero)
                  Text(
                    'Suspension expirée — reconnectez-vous.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 13, color: Colors.green),
                  ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.divider),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Raison de la suspension',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: colors.textSecondary,
                            letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        reason,
                        style: TextStyle(
                            fontSize: 13,
                            color: colors.textPrimary,
                            height: 1.4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Si vous pensez que c\'est une erreur, contactez le support à contact@afrolookmedia.com',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 11,
                      color: colors.textSecondary,
                      height: 1.5),
                ),
                const SizedBox(height: 32),
                OutlinedButton.icon(
                  onPressed: () {
                    Provider.of<UserAuthProvider>(context, listen: false)
                        .logout(context);
                  },
                  icon: const Icon(Icons.logout, size: 18),
                  label: const Text('Se déconnecter'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.textSecondary,
                    side: BorderSide(color: colors.divider),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
