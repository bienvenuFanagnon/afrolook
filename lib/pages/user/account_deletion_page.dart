import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/authProvider.dart';
import '../../theme/app_colors.dart';
import '../auth/authTest/Screens/Login/loginPageUser.dart';
import '../../utils/tx_amount.dart';
import '../../widgets/coin_balances_row.dart';
import 'monetisation.dart';
import 'UserRetrait/userRetraitForm.dart';
import '../../models/model_data.dart';
import '../../l10n/tr.dart';

class AccountDeletionPage extends StatefulWidget {
  const AccountDeletionPage({Key? key}) : super(key: key);

  @override
  State<AccountDeletionPage> createState() => _AccountDeletionPageState();
}

class _AccountDeletionPageState extends State<AccountDeletionPage> {
  final _passwordController = TextEditingController();
  bool _obscure = true;
  bool _isDeleting = false;
  bool _confirmed = false;
  bool _acceptLoss = false; // renonciation explicite aux soldes restants
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _onDelete() async {
    if (!_confirmed) {
      setState(() => _error = context.tr('Veuillez cocher la case de confirmation.'));
      return;
    }
    if (_passwordController.text.trim().isEmpty) {
      setState(() => _error = context.tr('Entrez votre mot de passe pour confirmer.'));
      return;
    }
    if (_hasBalances && !_acceptLoss) {
      setState(() => _error = context.tr('Retire tes soldes, ou coche la case pour y renoncer.'));
      return;
    }

    setState(() { _isDeleting = true; _error = null; });

    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final err = await authProvider.deleteAccount(
      password: _passwordController.text.trim(),
      acceptLoss: _acceptLoss,
    );

    if (!mounted) return;

    if (err != null) {
      setState(() { _isDeleting = false; _error = err; });
      return;
    }

    // Accès coupé — message puis retour à la connexion
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('Compte supprimé')),
        content: Text(
          context.tr('Ton compte est désactivé dès maintenant. Il sera supprimé définitivement dans 15 jours, avec toutes ses données.\n\nEn cas d\'erreur, contacte-nous avant cette date : officiel.afrolook@gmail.com'),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
      ),
    );
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => LoginPageUser()),
      (route) => false,
    );
  }

  UserData get _user => Provider.of<UserAuthProvider>(context, listen: false).loginUserData;

  bool get _hasBalances {
    final u = _user;
    return (u.giftCoinsBalance ?? 0) > 0 ||
        (u.votre_solde_principal ?? 0) > 0 ||
        (u.votre_solde_depot ?? 0) > 0 ||
        (u.postViewsAvailable ?? 0) > 0;
  }

  /// Soldes restants : l'utilisateur est invité à les retirer avant la suppression.
  Widget _buildBalances(AppColors colors) {
    final u = _user;
    Widget line(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            Expanded(child: Text(label, style: TextStyle(color: colors.textSecondary, fontSize: 13))),
            Text(value, style: TextStyle(color: colors.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w700)),
          ]),
        );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.warning.withOpacity(colors.isDark ? 0.14 : 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.warning.withOpacity(0.4)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.account_balance_wallet_rounded, color: colors.warning, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(context.tr('Il reste des soldes sur ton compte'),
                style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
          ),
        ]),
        const SizedBox(height: 8),
        Text(context.tr('Retire-les avant de supprimer ton compte : après la suppression, ils seront perdus.'),
            style: TextStyle(color: colors.textSecondary, fontSize: 13, height: 1.4)),
        const SizedBox(height: 10),
        if ((u.giftCoinsBalance ?? 0) > 0) ...[
          CoinBalancesInline(user: u),
          const SizedBox(height: 6),
        ],
        if ((u.votre_solde_principal ?? 0) > 0) line(context.tr('Gains à retirer'), '${TxAmount.fmt(u.votre_solde_principal!)} FCFA'),
        if ((u.votre_solde_depot ?? 0) > 0) line(context.tr('Dépôt FCFA'), '${TxAmount.fmt(u.votre_solde_depot!)} FCFA'),
        if ((u.postViewsAvailable ?? 0) > 0) line(context.tr('Revenus des vues à encaisser'), '${TxAmount.fmt(u.postViewsAvailable!)} FCFA'),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => UserDemandeRetraitPage())),
              icon: const Icon(Icons.north_east_rounded, size: 18),
              label: Text(context.tr('Retirer mes gains')),
              style: FilledButton.styleFrom(backgroundColor: colors.primary, foregroundColor: colors.onPrimary),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MonetisationPage())),
              child: Text(context.tr('Mon portefeuille')),
            ),
          ),
        ]),
        const SizedBox(height: 6),
        InkWell(
          onTap: () => setState(() => _acceptLoss = !_acceptLoss),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Checkbox(
              value: _acceptLoss,
              activeColor: colors.danger,
              onChanged: (v) => setState(() => _acceptLoss = v ?? false),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(context.tr('Je renonce à ces soldes : ils seront perdus avec mon compte.'),
                    style: TextStyle(color: colors.textPrimary, fontSize: 13, height: 1.4)),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(context.tr('Supprimer mon compte'), style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 17)),
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Avertissement ──────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colors.danger.withOpacity(0.07),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: colors.danger.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: colors.danger, size: 24),
                      const SizedBox(width: 10),
                      Text(
                        context.tr('Suppression du compte'),
                        style: TextStyle(color: colors.danger, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    context.tr('Ton compte sera désactivé immédiatement, puis supprimé définitivement au bout de 15 jours. Pendant ce délai, tu peux contacter notre service en cas d\'erreur. Seront supprimés :'),
                    style: TextStyle(color: colors.textPrimary, fontSize: 14, height: 1.5),
                  ),
                  const SizedBox(height: 10),
                  ...[
                    context.tr('Votre profil et toutes vos informations personnelles'),
                    context.tr('Vos posts, vidéos et contenus publiés'),
                    context.tr('Votre solde de pièces (Afrocoins)'),
                    context.tr('Vos abonnements actifs'),
                    context.tr('Vos messages et conversations'),
                    context.tr('Votre historique et vos favoris'),
                  ].map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.remove_circle_outline, color: colors.danger, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(item, style: TextStyle(color: colors.textSecondary, fontSize: 13, height: 1.4)),
                        ),
                      ],
                    ),
                  )),
                ],
              ),
            ),

            if (_hasBalances) ...[
              const SizedBox(height: 16),
              _buildBalances(colors),
            ],

            const SizedBox(height: 28),

            // ── Mot de passe ───────────────────────────────────────────────
            Text(
              context.tr('Confirmez avec votre mot de passe'),
              style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600, fontSize: 15),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _passwordController,
              obscureText: _obscure,
              style: TextStyle(color: colors.textPrimary),
              decoration: InputDecoration(
                hintText: context.tr('Mot de passe'),
                hintStyle: TextStyle(color: colors.textSecondary),
                filled: true,
                fillColor: colors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: colors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: colors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: colors.danger, width: 1.5),
                ),
                prefixIcon: Icon(Icons.lock_outline, color: colors.textSecondary, size: 20),
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: colors.textSecondary, size: 20),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ── Case à cocher ──────────────────────────────────────────────
            InkWell(
              onTap: () => setState(() => _confirmed = !_confirmed),
              borderRadius: BorderRadius.circular(10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: _confirmed,
                    activeColor: colors.danger,
                    onChanged: (v) => setState(() => _confirmed = v ?? false),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        context.tr('Je comprends que mon compte sera désactivé tout de suite et supprimé définitivement avec toutes mes données dans 15 jours.'),
                        style: TextStyle(color: colors.textPrimary, fontSize: 13, height: 1.4),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Erreur ────────────────────────────────────────────────────
            if (_error != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: colors.danger.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: colors.danger, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error!, style: TextStyle(color: colors.danger, fontSize: 13))),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 32),

            // ── Bouton supprimer ───────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isDeleting ? null : _onDelete,
                icon: _isDeleting
                    ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.delete_forever_rounded, size: 20),
                label: Text(
                  _isDeleting ? context.tr('Suppression...') : context.tr('Supprimer définitivement mon compte'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.danger,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: colors.danger.withOpacity(0.5),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Annuler ───────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(context.tr('Annuler'), style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
