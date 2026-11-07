import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

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

  static Interpreter? _interpreter;

  static Future<Interpreter?> _load() async {
    if (kIsWeb) return null;
    try {
      return _interpreter ??= await Interpreter.fromAsset(_asset, options: InterpreterOptions()..threads = 2);
    } catch (_) {
      return null;
    }
  }

  /// Probabilités des 5 classes pour une image (fichier JPEG/PNG), ou null si le modèle n'a pas pu tourner.
  static Future<List<double>?> score(String imagePath) async {
    final interpreter = await _load();
    if (interpreter == null) return null;
    try {
      final decoded = img.decodeImage(await File(imagePath).readAsBytes());
      if (decoded == null) return null;
      final r = img.copyResize(decoded, width: 224, height: 224, interpolation: img.Interpolation.linear);
      final input = Float32List(224 * 224 * 3);
      var i = 0;
      for (var y = 0; y < 224; y++) {
        for (var x = 0; x < 224; x++) {
          final p = r.getPixel(x, y);
          input[i++] = p.r / 127.5 - 1;
          input[i++] = p.g / 127.5 - 1;
          input[i++] = p.b / 127.5 - 1;
        }
      }
      final output = [List<double>.filled(5, 0)];
      interpreter.run(input.reshape([1, 224, 224, 3]), output);
      return output[0];
    } catch (_) {
      return null;
    }
  }

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
