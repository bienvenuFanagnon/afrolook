import 'package:afrotok/models/model_data.dart';

/// Orientation d'une vidéo (portrait ou paysage). Source : le champ `is_portrait` de l'API ; quand il est inconnu (anciennes publications),
/// l'orientation est apprise à la première lecture (dimensions réelles de la vidéo) et gardée en mémoire jusqu'à la fermeture de l'application.
/// Tant qu'elle est inconnue, on suppose « portrait » (comportement historique).
class PostOrientation {
  PostOrientation._();

  static final Map<String, bool> _learned = {};

  /// Portrait ? (connu par l'API, sinon appris, sinon portrait par défaut)
  static bool of(Post post) => post.isPortrait ?? (post.id == null ? null : _learned[post.id!]) ?? true;

  /// Inconnue : ni l'API ni une lecture précédente ne l'ont dit.
  static bool isUnknown(Post post) => post.isPortrait == null && (post.id == null || !_learned.containsKey(post.id!));

  /// Retient l'orientation mesurée sur la vidéo réelle.
  static void learn(Post post, double width, double height) {
    if (width <= 0 || height <= 0) return;
    final portrait = height > width;
    post.isPortrait ??= portrait;
    if (post.id != null) _learned[post.id!] = portrait;
  }
}
