import 'package:firebase_auth/firebase_auth.dart';

/// Identifiant de la personne connectée DANS L'API (pas celui de Firebase : les comptes créés par l'API ont un identifiant différent).
/// Renseigné à chaque lecture de `/bootstrap` ; sert aux convertisseurs de publications pour rendre `liked_by_me` / `favorited_by_me`
/// comparables à `loginUserData.id`, que tous les écrans utilisent.
class ApiIdentity {
  ApiIdentity._();

  static String? _myId;

  static void set(String? id) {
    if (id != null && id.isNotEmpty) _myId = id;
  }

  /// Identifiant API de la personne connectée ; à défaut (avant le premier chargement), l'identifiant Firebase.
  static String? get myId => _myId ?? FirebaseAuth.instance.currentUser?.uid;

  /// À la déconnexion.
  static void clear() => _myId = null;
}
