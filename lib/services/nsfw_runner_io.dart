import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

/// Exécution du modèle sur le téléphone (Android, iPhone) : seul fichier qui importe `tflite_flutter`.
/// Cette bibliothèque dépend de `dart:ffi`, qui n'existe pas sur le web : `nsfw_check.dart` charge donc ce fichier
/// uniquement quand `dart:io` est disponible, et `nsfw_runner_stub.dart` sinon.

Interpreter? _interpreter;

Future<Interpreter?> _load(String asset) async {
  if (kIsWeb) return null;
  try {
    return _interpreter ??= await Interpreter.fromAsset(asset, options: InterpreterOptions()..threads = 2);
  } catch (_) {
    return null;
  }
}

/// Prépare les pixels (décodage, 224×224, -1..1) : tourne dans un autre fil pour ne jamais ralentir l'écran.
/// Réglage vérifié sur des portraits ordinaires : les pixels doivent être normalisés de -1 à 1 (x / 127,5 - 1).
/// Avec x / 255, des visages normaux ressortaient « porn ».
Float32List? _prepare(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  final r = img.copyResize(decoded, width: 224, height: 224, interpolation: img.Interpolation.average);
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
  return input;
}

/// Probabilités des 5 classes pour une image (fichier JPEG/PNG), ou null si le modèle n'a pas pu tourner.
Future<List<double>?> nsfwScore(String imagePath, String asset) async {
  final interpreter = await _load(asset);
  if (interpreter == null) return null;
  try {
    final input = await compute(_prepare, await File(imagePath).readAsBytes());
    if (input == null) return null;
    final output = [List<double>.filled(5, 0)];
    interpreter.run(input.reshape([1, 224, 224, 3]), output);
    return output[0];
  } catch (_) {
    return null;
  }
}
