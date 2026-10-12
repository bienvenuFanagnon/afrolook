import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// E-mails de validation d'adresse et de réinitialisation du mot de passe.
///
/// On passe d'abord par notre serveur d'envoi (fonctions `authSendVerificationEmail` / `authSendPasswordReset`),
/// beaucoup plus fiable que l'expéditeur par défaut de Firebase. Si notre serveur ne répond pas ou refuse l'envoi,
/// on se rabat sur l'envoi natif de Firebase : l'e-mail n'est jamais perdu. Marche sur mobile, iPhone et web.
class AuthEmailService {
  AuthEmailService._();

  /// Envoie (ou renvoie) le lien de validation de l'adresse du compte connecté.
  /// Retourne `true` si l'envoi a été demandé, `false` si trop de demandes (message à afficher par l'appelant).
  static Future<bool> sendVerification(User user) async {
    try {
      await FirebaseFunctions.instance
          .httpsCallable('authSendVerificationEmail')
          .call<dynamic>()
          .timeout(const Duration(seconds: 25));
      return true;
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'resource-exhausted') return false;
      debugPrint('Envoi serveur de l\'e-mail de vérification impossible (${e.code}) : repli Firebase');
    } catch (e) {
      debugPrint('Envoi serveur de l\'e-mail de vérification impossible ($e) : repli Firebase');
    }
    await user.sendEmailVerification();
    return true;
  }

  /// Envoie le lien de réinitialisation du mot de passe (réponse identique si le compte n'existe pas).
  static Future<bool> sendPasswordReset(String email) async {
    final mail = email.trim();
    try {
      await FirebaseFunctions.instance
          .httpsCallable('authSendPasswordReset')
          .call<dynamic>({'email': mail})
          .timeout(const Duration(seconds: 25));
      return true;
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'resource-exhausted') return false;
      if (e.code == 'invalid-argument') {
        throw FirebaseAuthException(code: 'invalid-email');
      }
      debugPrint('Envoi serveur de la réinitialisation impossible (${e.code}) : repli Firebase');
    } catch (e) {
      debugPrint('Envoi serveur de la réinitialisation impossible ($e) : repli Firebase');
    }
    await FirebaseAuth.instance.sendPasswordResetEmail(email: mail);
    return true;
  }
}
