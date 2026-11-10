// Le modèle tourne dans nsfw_runner_io.dart (téléphone). Sur le web, nsfw_runner_stub.dart le remplace :
// sans cela, l'import de tflite_flutter (dart:ffi) empêche toute compilation de l'application web.
import 'nsfw_runner_stub.dart' if (dart.library.io) 'nsfw_runner_io.dart' as runner;

/// Détection de contenu sexuellement EXPLICITE, gratuite et sur le téléphone (modèle libre nsfw_model, MIT, voir assets/models/NSFW_MODEL_LICENSE.txt).
/// 5 classes : drawings, hentai, neutral, porn, sexy. On ne bloque que « porn » (acte sexuel, nudité explicite) : « sexy » (tenue légère, danse, maillot) passe.
/// Aucune image ne quitte le téléphone. En cas d'échec technique, rien n'est bloqué.
///
/// Réglage vérifié sur des portraits ordinaires : les pixels doivent être normalisés de -1 à 1 (x / 127,5 - 1). Avec x / 255, des visages normaux ressortaient « porn ».
class NsfwCheck {
  NsfwCheck._();

  static const _asset = 'assets/models/nsfw_mobilenet_v2_140_224.tflite';
  static const labels = ['drawings', 'hentai', 'neutral', 'porn', 'sexy'];
  static const iPorn = 3;
  static const iSexy = 4;

  /// Seuils (à régler avec l'écran de test et l'équipe de modération) : une image très sûre suffit ; sinon plusieurs images moyennement sûres ensemble.
  static const strongPorn = 0.85;
  static const mediumPorn = 0.6;

  /// Probabilités des 5 classes pour une image (fichier JPEG/PNG), ou null si le modèle n'a pas pu tourner (toujours null sur le web).
  static Future<List<double>?> score(String imagePath) => runner.nsfwScore(imagePath, _asset);

  /// Décision sur les images d'une vidéo (séparée du modèle pour être testée sans téléphone) :
  /// explicite si une image est très sûre (≥ 0,85), ou si au moins deux images sont assez sûres (≥ 0,6), ou si la moyenne des images dépasse 0,5.
  static bool decide(List<List<double>> frames) {
    if (frames.isEmpty) return false;
    final porn = frames.map((f) => f[iPorn]).toList();
    if (porn.any((p) => p >= strongPorn)) return true;
    if (porn.where((p) => p >= mediumPorn).length >= 2) return true;
    final avg = porn.reduce((a, b) => a + b) / porn.length;
    return frames.length >= 3 && avg >= 0.5;
  }
}
