import 'package:afrolook_api_client/afrolook_api_client.dart' show ApiException;
import 'package:afrotok/l10n/tr.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Les opérations sensibles de l'administration (argent, validation de partageurs et de campagnes…) exigent une connexion de moins de 10 minutes : sinon
/// l'API répond 403 `reauth_required`. [run] exécute l'appel ; dans ce cas il propose de se reconnecter (Google ou mot de passe) puis réessaie UNE fois.
class AdminReauth {
  AdminReauth._();

  static bool isReauth(Object e) => e is ApiException && e.status == 403 && e.code == 'reauth_required';

  static Future<T> run<T>(BuildContext context, Future<T> Function() call) async {
    try {
      return await call();
    } catch (e) {
      if (!isReauth(e) || !context.mounted) rethrow;
      if (!await reauthenticate(context)) rethrow;
      return await call();
    }
  }

  /// Reconnexion de sécurité : Google (compte lié) ou mot de passe. Renvoie true si le jeton a été renouvelé.
  static Future<bool> reauthenticate(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    final providers = user.providerData.map((p) => p.providerId).toSet();
    try {
      AuthCredential? cred;
      if (providers.contains('google.com')) {
        final g = await GoogleSignIn().signIn();
        final a = await g?.authentication;
        if (a == null) return false;
        cred = GoogleAuthProvider.credential(idToken: a.idToken, accessToken: a.accessToken);
      } else if (providers.contains('password') && (user.email ?? '').isNotEmpty) {
        final pwd = await _askPassword(context);
        if (pwd == null || pwd.isEmpty) return false;
        cred = EmailAuthProvider.credential(email: user.email!, password: pwd);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Pour cette action, déconnecte-toi puis reconnecte-toi, par sécurité.'))));
        }
        return false;
      }
      await user.reauthenticateWithCredential(cred);
      await user.getIdToken(true);   // nouveau jeton : sa date de connexion est celle d'à l'instant
      return true;
    } on FirebaseAuthException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.code == 'wrong-password' || e.code == 'invalid-credential' ? tr('Mot de passe incorrect.') : tr('Reconnexion impossible. Réessaie.'))));
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  static Future<String?> _askPassword(BuildContext context) {
    final ctl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.tr('Reconnexion de sécurité')),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(ctx.tr('Cette action demande une connexion de moins de 10 minutes. Saisis ton mot de passe.')),
          TextField(controller: ctl, obscureText: true, autofocus: true, decoration: InputDecoration(labelText: ctx.tr('Mot de passe'))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(ctx.tr('Annuler'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctl.text), child: Text(ctx.tr('Continuer'))),
        ],
      ),
    );
  }
}
