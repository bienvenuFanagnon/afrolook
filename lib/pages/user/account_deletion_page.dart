import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/authProvider.dart';
import '../../theme/app_colors.dart';
import '../auth/authTest/Screens/Login/loginPageUser.dart';

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
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _onDelete() async {
    if (!_confirmed) {
      setState(() => _error = 'Veuillez cocher la case de confirmation.');
      return;
    }
    if (_passwordController.text.trim().isEmpty) {
      setState(() => _error = 'Entrez votre mot de passe pour confirmer.');
      return;
    }

    setState(() { _isDeleting = true; _error = null; });

    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final err = await authProvider.deleteAccount(password: _passwordController.text.trim());

    if (!mounted) return;

    if (err != null) {
      setState(() { _isDeleting = false; _error = err; });
      return;
    }

    // Compte supprimé — déconnexion + redirection
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => LoginPageUser()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text('Supprimer mon compte', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 17)),
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
                        'Action irréversible',
                        style: TextStyle(color: colors.danger, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'La suppression de votre compte est définitive. Les données suivantes seront perdues :',
                    style: TextStyle(color: colors.textPrimary, fontSize: 14, height: 1.5),
                  ),
                  const SizedBox(height: 10),
                  ...[
                    'Votre profil et toutes vos informations personnelles',
                    'Vos posts, vidéos et contenus publiés',
                    'Votre solde de pièces (Afrocoins)',
                    'Vos abonnements actifs',
                    'Vos messages et conversations',
                    'Votre historique et vos favoris',
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

            const SizedBox(height: 28),

            // ── Mot de passe ───────────────────────────────────────────────
            Text(
              'Confirmez avec votre mot de passe',
              style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600, fontSize: 15),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _passwordController,
              obscureText: _obscure,
              style: TextStyle(color: colors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Mot de passe',
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
                        'Je comprends que cette action est irréversible et que toutes mes données seront définitivement supprimées.',
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
                  _isDeleting ? 'Suppression...' : 'Supprimer définitivement mon compte',
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
                child: Text('Annuler', style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
