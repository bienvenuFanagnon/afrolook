import 'package:afrotok/pages/splashChargement.dart';
import 'package:afrotok/pages/auth/authTest/Screens/Signup/components/signup_form.dart';
import 'package:afrotok/services/auth/google_auth_service.dart';
import 'package:afrotok/services/sessions/session_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';

/// Parcours « Continuer avec Google » commun à la connexion et à l'inscription.
/// Compte déjà complet → connexion directe. Pas encore de profil Afrolook → création du profil (sans mot de passe).
class GoogleAuthFlow {
  GoogleAuthFlow._();

  /// Retourne `true` si une navigation a été lancée (connexion ou création de profil).
  static Future<bool> start(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final cred = await GoogleAuthService.signIn();
      final user = cred?.user;
      if (user == null) return false; // annulé
      if (await GoogleAuthService.hasProfile(user.uid)) {
        await SessionUserFirebaseService.saveUserSession(user.uid);
        await SessionUserFirebaseService.updateLastActive();
        navigator.pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const SplashChargement()), (r) => false);
        return true;
      }
      navigator.push(MaterialPageRoute(builder: (_) => SignUpScreen(googleUser: user)));
      return true;
    } catch (e) {
      debugPrint('Connexion Google : $e');
      final msg = GoogleAuthService.messageFor(e);
      if (msg.isNotEmpty) {
        messenger.showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red.shade700, duration: const Duration(seconds: 6)));
      }
      return false;
    }
  }
}

/// Bouton blanc « Continuer avec Google » (les couleurs de marque Google restent les mêmes en thème sombre).
class GoogleSignInButton extends StatefulWidget {
  const GoogleSignInButton({Key? key}) : super(key: key);

  @override
  State<GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<GoogleSignInButton> {
  bool _busy = false;

  Future<void> _tap() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await GoogleAuthFlow.start(context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!GoogleAuthService.isAvailable) return const SizedBox.shrink();
    final en = Localizations.localeOf(context).languageCode == 'en';
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton(
        onPressed: _busy ? null : _tap,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          side: const BorderSide(color: Color(0xFFDADCE0)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        ),
        child: _busy
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4285F4)))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(AntDesign.google, size: 20, color: Color(0xFF4285F4)),
                  const SizedBox(width: 12),
                  Text(en ? 'Continue with Google' : 'Continuer avec Google',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF3C4043))),
                ],
              ),
      ),
    );
  }
}
