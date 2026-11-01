import 'package:firebase_auth/firebase_auth.dart';

/// Identifiant de la personne connectée DANS L'API (pas celui de Firebase : les comptes créés par l'API ont un identifiant différent).
/// Renseigné à chaque lecture de `/bootstrap` ; sert aux convertisseurs de publications pour rendre `liked_by_me` / `favorited_by_me`
/// comparables à `loginUserData.id`, que tous les écrans utilisent. C'est aussi lui qui indexe les messages, la présence et les lives.
class ApiIdentity {
  ApiIdentity._();

  static String? _myId;

  /// Uid Firebase au moment où l'identifiant API a été enregistré : si un autre compte se connecte ensuite
  /// (sans que `clear()` ait été appelé), l'ancien identifiant API n'est plus renvoyé.
  static String? _forFirebaseUid;

  /// Lecture de l'uid Firebase courant ; remplaçable dans les tests (Firebase n'est pas initialisé dans un test Dart simple).
  static String? Function() firebaseUid = _defaultFirebaseUid;

  static String? _defaultFirebaseUid() {
    try {
      return FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      return null;
    }
  }

  static void set(String? id) {
    if (id != null && id.isNotEmpty) {
      _myId = id;
      _forFirebaseUid = firebaseUid();
    }
  }

  /// Identifiant API de la personne connectée ; à défaut (avant le premier chargement, ou si un autre compte Firebase
  /// est connecté depuis), l'identifiant Firebase.
  static String? get myId {
    final fb = firebaseUid();
    final mine = _myId;
    if (mine != null && (fb == null || _forFirebaseUid == null || _forFirebaseUid == fb)) return mine;
    return fb;
  }

  /// À la déconnexion.
  static void clear() {
    _myId = null;
    _forFirebaseUid = null;
  }
}
