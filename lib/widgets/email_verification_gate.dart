import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../l10n/tr.dart';
import '../services/api/audit_errors.dart';

/// Opérations Firebase Auth nécessaires à la confirmation de l'e-mail (remplaçables dans les tests).
abstract class EmailVerifier {
  /// Adresse e-mail du compte (null si le compte n'en a pas).
  String? get email;

  /// Renvoie le lien de vérification (Firebase Auth `sendEmailVerification`).
  Future<void> sendLink();

  /// Relit le compte, recharge le jeton (`getIdToken(true)`) puis dit si l'e-mail est confirmé.
  Future<bool> checkConfirmed();
}

/// Implémentation Firebase Auth.
class FirebaseEmailVerifier implements EmailVerifier {
  const FirebaseEmailVerifier();

  @override
  String? get email => FirebaseAuth.instance.currentUser?.email;

  @override
  Future<void> sendLink() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) throw StateError('no-user');
    await u.sendEmailVerification();
  }

  @override
  Future<bool> checkConfirmed() async {
    final auth = FirebaseAuth.instance;
    await auth.currentUser?.reload();
    // Le jeton garde l'ancien état tant qu'il n'est pas renouvelé : l'API lit l'état de l'e-mail dans le jeton.
    await auth.currentUser?.getIdToken(true);
    return auth.currentUser?.emailVerified ?? false;
  }
}

/// Un seul composant pour tous les écrans d'argent : quand l'API répond 403 `email_unverified`, il propose de renvoyer le lien de
/// confirmation, puis (bouton « J'ai confirmé ») recharge le jeton et rejoue l'action.
class EmailVerificationGate {
  EmailVerificationGate._();

  /// Pour les tests : remplace l'accès à Firebase Auth.
  static EmailVerifier verifier = const FirebaseEmailVerifier();

  static bool isUnverified(Object e) => AuditErrors.isEmailUnverified(e);

  /// Exécute [action]. Si l'API répond `email_unverified`, ouvre la fenêtre « Confirme ton e-mail » ; une fois l'e-mail confirmé,
  /// [action] est rejouée UNE fois. Si la personne renonce, l'erreur d'origine est relancée (l'écran affiche son message habituel).
  static Future<T> run<T>(BuildContext context, Future<T> Function() action) async {
    try {
      return await action();
    } catch (e) {
      if (!isUnverified(e) || !context.mounted) rethrow;
      final confirmed = await confirm(context);
      if (!confirmed) rethrow;
      return await action();
    }
  }

  /// Ouvre la fenêtre et renvoie true quand l'e-mail est confirmé et le jeton rechargé.
  static Future<bool> confirm(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => EmailVerificationDialog(verifier: verifier),
    );
    return ok == true;
  }
}

/// Fenêtre « Confirme ton e-mail ».
class EmailVerificationDialog extends StatefulWidget {
  const EmailVerificationDialog({super.key, required this.verifier});
  final EmailVerifier verifier;

  @override
  State<EmailVerificationDialog> createState() => _EmailVerificationDialogState();
}

class _EmailVerificationDialogState extends State<EmailVerificationDialog> {
  bool _busy = false;
  String? _info;
  bool _error = false;

  Future<void> _resend() async {
    setState(() { _busy = true; _info = null; _error = false; });
    try {
      await widget.verifier.sendLink();
      if (!mounted) return;
      setState(() { _info = tr('Lien envoyé. Ouvre ta boîte mail (et le dossier des courriers indésirables), puis touche le lien.'); _error = false; });
    } catch (e) {
      if (!mounted) return;
      final tooMany = '$e'.contains('too-many-requests');
      setState(() {
        _info = tooMany ? tr('Trop de demandes. Patiente quelques minutes avant de renvoyer le lien.') : tr("Le lien n'a pas pu être envoyé. Vérifie ta connexion puis réessaie.");
        _error = true;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmed() async {
    setState(() { _busy = true; _info = null; _error = false; });
    try {
      final ok = await widget.verifier.checkConfirmed();
      if (!mounted) return;
      if (ok) {
        Navigator.of(context).pop(true);
        return;
      }
      setState(() { _info = tr("Ton e-mail n'est pas encore confirmé. Touche le lien reçu par e-mail, puis reviens ici."); _error = true; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _info = tr("La vérification n'a pas pu être faite. Vérifie ta connexion puis réessaie."); _error = true; });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = widget.verifier.email;
    final hasEmail = email != null && email.isNotEmpty;
    return AlertDialog(
      title: Text(tr('Confirme ton e-mail')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(hasEmail
                ? tr('Pour utiliser cette fonction (argent, pièces, retraits), confirme ton adresse e-mail {a}. Touche « Renvoyer le lien », ouvre le message reçu, puis reviens ici et touche « J\'ai confirmé ».', {'a': email})
                : tr('Pour utiliser cette fonction, ton compte doit avoir une adresse e-mail confirmée. Ajoute-en une dans les réglages de ton compte.')),
            if (_info != null) ...[
              const SizedBox(height: 12),
              Text(_info!, key: const Key('email_gate_info'), style: TextStyle(color: _error ? Colors.red : Colors.green.shade700, fontSize: 13)),
            ],
            if (_busy) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(false), child: Text(tr('Plus tard'))),
        if (hasEmail) TextButton(key: const Key('email_gate_resend'), onPressed: _busy ? null : _resend, child: Text(tr('Renvoyer le lien'))),
        FilledButton(key: const Key('email_gate_confirmed'), onPressed: _busy || !hasEmail ? null : _confirmed, child: Text(tr("J'ai confirmé"))),
      ],
    );
  }
}

/// Raccourci pour les écrans qui affichent l'erreur d'une action déjà jouée : renvoie true si l'e-mail vient d'être confirmé
/// (l'écran peut alors rejouer l'action).
Future<bool> confirmEmailIfNeeded(BuildContext context, Object error) async {
  if (!EmailVerificationGate.isUnverified(error) || !context.mounted) return false;
  return EmailVerificationGate.confirm(context);
}
