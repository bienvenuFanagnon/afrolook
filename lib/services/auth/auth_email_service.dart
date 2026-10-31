import 'package:firebase_auth/firebase_auth.dart';

/// E-mails de validation d'adresse et de réinitialisation du mot de passe : envoi natif de Firebase Auth
/// (l'ancien serveur d'envoi par fonction n'existe plus ; un envoi par l'API pourra le remplacer, voir lacunes_api_utilisateurs.md).
class AuthEmailService {
  AuthEmailService._();

  /// Envoie (ou renvoie) le lien de validation de l'adresse du compte connecté.
  /// Retourne `true` si l'envoi a été demandé, `false` si trop de demandes (message à afficher par l'appelant).
  static Future<bool> sendVerification(User user) async {
    try {
      await user.sendEmailVerification();
      return true;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'too-many-requests') return false;
      rethrow;
    }
  }

  /// Envoie le lien de réinitialisation du mot de passe.
  static Future<bool> sendPasswordReset(String email) async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email.trim());
      return true;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'too-many-requests') return false;
      rethrow;
    }
  }
}
