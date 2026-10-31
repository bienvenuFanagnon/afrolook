import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/providers/authProvider.dart';
import 'package:afrotok/theme/app_colors.dart';
import 'package:afrolook_api_client/afrolook_api_client.dart' show ApiException;
import 'package:afrotok/services/api/compte_api.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import 'coins/coin_recharge_screen.dart';
import 'home/homeScreen.dart';

/// Compte restauré après une suppression : toutes les activités sont bloquées tant que le déblocage n'est pas payé
/// en pièces. La personne peut recharger son solde pour payer. Le serveur décide de tout (`payRestoreFee`).
class AccountRestoreFeeScreen extends StatefulWidget {
  const AccountRestoreFeeScreen({Key? key, required this.user}) : super(key: key);
  final UserData user;

  /// Ce compte doit-il passer par cet écran ?
  static bool requiredFor(UserData u) => u.accountStatus == 'RESTORE_FEE_DUE';

  @override
  State<AccountRestoreFeeScreen> createState() => _AccountRestoreFeeScreenState();
}

class _AccountRestoreFeeScreenState extends State<AccountRestoreFeeScreen> with WidgetsBindingObserver {
  bool _busy = false;
  String? _error;

  /// Montant du déblocage demandé par l'API (réponse 402 de `POST /me/restore-fee`) quand le profil ne le fournit pas encore.
  int? _knownFee;

  UserData get _user => context.read<UserAuthProvider>().loginUserData;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Retour d'un achat de pièces (ou de l'arrière-plan) : on relit le solde.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    await context.read<UserAuthProvider>().refreshUserData();
    if (mounted) setState(() {});
  }

  Future<void> _recharge() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const CoinRechargeScreen()));
    await _refresh();
  }

  Future<void> _pay() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await CompteApi.payRestoreFee();
      await context.read<UserAuthProvider>().refreshUserData();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => MyHomePage(title: '')),
        (_) => false,
      );
    } on ApiException catch (e) {
      if (e.status == 409 && e.code == 'no_fee_due') {
        // Plus rien à payer (déjà réglé ailleurs) : le compte est actif, on continue
        await context.read<UserAuthProvider>().refreshUserData();
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => MyHomePage(title: '')), (_) => false);
        return;
      }
      await _refresh();
      if (mounted) {
        setState(() {
          // L'API indique le prix dans sa réponse 402 : on le retient pour afficher le montant et ce qu'il manque
          if (e.isInsufficientCoins && e.coins != null) _knownFee = e.coins;
          _error = e.isInsufficientCoins
              ? tr('Solde de pièces insuffisant : recharge ton compte pour continuer.')
              : CompteApi.message(e, fallback: tr('Paiement impossible pour le moment.'));
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = tr('Paiement impossible pour le moment.'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final user = context.watch<UserAuthProvider>().loginUserData;
    final profileFee = user.restoreFeeDue ?? widget.user.restoreFeeDue ?? 0;
    final fee = profileFee > 0 ? profileFee : (_knownFee ?? 0);
    final feeKnown = fee > 0;
    final balance = user.giftCoinsBalance ?? 0;
    final missing = (fee - balance).clamp(0, 1 << 30);
    // Montant encore inconnu : on laisse payer, le serveur dit si le solde suffit
    final enough = !feeKnown || missing == 0;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: colors.background,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(color: colors.accent.withOpacity(0.16), shape: BoxShape.circle),
                      child: Icon(Icons.lock_open_rounded, size: 46, color: colors.supportAccent),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      tr('Ton compte a été restauré'),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: colors.textPrimary),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      tr('Pour le réactiver, règle le déblocage de ton compte. Tant qu\'il n\'est pas payé, toutes les activités restent bloquées.'),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, height: 1.4, color: colors.textSecondary),
                    ),
                    const SizedBox(height: 22),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: colors.border),
                      ),
                      child: Column(children: [
                        _row(colors, tr('Déblocage du compte'), feeKnown ? '$fee 🪙' : tr('Montant calculé au paiement'), bold: true),
                        const SizedBox(height: 8),
                        _row(colors, tr('Ton solde de pièces'), '$balance 🪙'),
                        if (!enough) ...[
                          const SizedBox(height: 8),
                          _row(colors, tr('Il te manque'), '$missing 🪙', color: colors.danger),
                        ],
                      ]),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: colors.danger, fontSize: 13)),
                    ],
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      child: enough
                          ? ElevatedButton(
                              onPressed: _busy ? null : _pay,
                              style: _btn(colors),
                              child: _busy
                                  ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: colors.onPrimary))
                                  : Text(feeKnown ? tr('Payer {n} pièces', {'n': fee}) : tr('Payer le déblocage'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                            )
                          : ElevatedButton.icon(
                              onPressed: _recharge,
                              icon: const Icon(Icons.add_card_rounded),
                              label: Text(tr('Recharger mes pièces'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                              style: _btn(colors),
                            ),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: _busy ? null : () => context.read<UserAuthProvider>().logout(context),
                      child: Text(tr('Se déconnecter'), style: TextStyle(color: colors.textSecondary)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  ButtonStyle _btn(AppColors colors) => ElevatedButton.styleFrom(
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      );

  Widget _row(AppColors colors, String label, String value, {bool bold = false, Color? color}) => Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(color: colors.textSecondary, fontSize: 13.5))),
          Text(value,
              style: TextStyle(
                color: color ?? colors.textPrimary,
                fontSize: bold ? 17 : 14,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              )),
        ],
      );
}
