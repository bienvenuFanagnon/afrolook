import 'package:afrotok/services/read_meter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Connexion / inscription avec Google (Android, iPhone, web).
///
/// Google ne fait que prouver l'identité et l'adresse e-mail (déjà vérifiée par Google) : le profil Afrolook
/// (pseudo, photo, centres d'intérêt…) reste à créer comme pour une inscription classique, voir [GoogleAuthFlow].
class GoogleAuthService {
  GoogleAuthService._();

  static final GoogleSignIn _google = GoogleSignIn(scopes: const ['email']);

  /// Le bouton Google n'est pas proposé sur iPhone : la règle 4.8 de l'App Store impose « Se connecter avec Apple »
  /// (ou équivalent) dès qu'une connexion par un service tiers existe. À rouvrir quand Apple sera ajouté
  /// (voir docs/AUTH_EMAILS_GOOGLE.md). Android et web gardent le bouton.
  static bool get isAvailable {
    if (kIsWeb) return true;
    if (defaultTargetPlatform == TargetPlatform.iOS) return false;
    return true;
  }

  /// Ouvre le choix du compte Google puis connecte Firebase. Retourne `null` si la personne annule.
  static Future<UserCredential?> signIn() async {
    if (kIsWeb) {
      final provider = GoogleAuthProvider()
        ..addScope('email')
        ..setCustomParameters({'prompt': 'select_account'});
      try {
        return await FirebaseAuth.instance.signInWithPopup(provider);
      } on FirebaseAuthException catch (e) {
        if (e.code == 'popup-closed-by-user' || e.code == 'cancelled-popup-request' || e.code == 'popup-blocked') {
          if (e.code == 'popup-blocked') rethrow;
          return null;
        }
        rethrow;
      }
    }
    // Sur mobile, on oublie le compte précédent pour toujours proposer le choix du compte.
    try {
      await _google.signOut();
    } catch (_) {}
    final account = await _google.signIn();
    if (account == null) return null; // annulé
    final tokens = await account.authentication;
    if (tokens.idToken == null && tokens.accessToken == null) {
      throw FirebaseAuthException(code: 'google-no-token');
    }
    final credential = GoogleAuthProvider.credential(idToken: tokens.idToken, accessToken: tokens.accessToken);
    return FirebaseAuth.instance.signInWithCredential(credential);
  }

  /// Le profil Afrolook existe-t-il déjà pour ce compte ?
  static Future<bool> hasProfile(String uid) async {
    final doc = await FirebaseFirestore.instance.collection('Users').doc(uid).getM('google_auth_service.dart:57');
    return doc.exists;
  }

  /// Quitte Google et Firebase (annulation en cours d'inscription).
  /// Si [deleteAccount] est vrai, le compte Firebase créé par Google sans profil est supprimé, pour que la même
  /// adresse puisse s'inscrire plus tard avec un mot de passe.
  static Future<void> abandon({bool deleteAccount = true}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (deleteAccount && user != null) {
      try {
        if (!await hasProfile(user.uid)) await user.delete();
      } catch (e) {
        debugPrint('Suppression du compte Google sans profil impossible : $e');
      }
    }
    try {
      await _google.signOut();
    } catch (_) {}
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
  }

  /// Message lisible pour une erreur de connexion Google.
  static String messageFor(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'account-exists-with-different-credential':
          return "Cette adresse e-mail a déjà un compte. Connectez-vous avec votre e-mail et votre mot de passe.";
        case 'user-disabled':
          return "Ce compte a été supprimé. Il sera effacé définitivement sous 15 jours. En cas d'erreur, contactez-nous : officiel.afrolook@gmail.com";
        case 'network-request-failed':
          return "Pas de connexion internet. Réessayez.";
        case 'popup-blocked':
          return "La fenêtre Google a été bloquée par le navigateur. Autorisez les fenêtres pour ce site puis réessayez.";
        case 'operation-not-allowed':
          return "La connexion avec Google n'est pas encore activée. Utilisez votre e-mail.";
      }
    }
    if (e is PlatformException) {
      if (e.code == 'network_error') return "Pas de connexion internet. Réessayez.";
      if (e.code == 'sign_in_canceled') return '';
    }
    return "Connexion avec Google impossible pour le moment. Réessayez ou utilisez votre e-mail.";
  }
}
