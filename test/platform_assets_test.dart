import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Chaque plateforme n'embarque QUE ce qui la concerne (règle du propriétaire, 09/11/2026) : l'application ne doit pas être alourdie pour rien.
///  - les modèles et bibliothèques du moteur de visage d'Android restent dans le dossier d'Android (jamais dans `assets/` de Flutter, partagé avec l'iPhone) ;
///  - l'iPhone n'en reçoit aucun, et ses propres composants iPhone (pods) restent dans `ios/` ;
///  - le dossier `assets/` partagé a un budget : toute nouvelle pièce lourde doit être justifiée (voir docs/FILTRES_VISAGE_IPHONE.md).
void main() {
  String read(String p) => File(p).readAsStringSync();

  int sizeMb(String dir) {
    var total = 0;
    final d = Directory(dir);
    if (!d.existsSync()) return 0;
    for (final f in d.listSync(recursive: true).whereType<File>()) {
      total += f.lengthSync();
    }
    return (total / (1024 * 1024)).ceil();
  }

  test('les modèles du moteur de visage Android sont dans le dossier Android, pas dans les ressources partagées', () {
    for (final name in ['face_landmarker.task', 'selfie_multiclass_256x256.tflite']) {
      expect(File('android/app/src/main/assets/$name').existsSync(), isTrue, reason: '$name doit rester côté Android');
      expect(File('assets/models/$name').existsSync(), isFalse, reason: '$name ne doit pas être dans assets/ (partagé avec l\'iPhone)');
      expect(Directory('ios').listSync(recursive: true).whereType<File>().any((f) => f.path.endsWith(name)), isFalse, reason: '$name ne doit pas être livré à l\'iPhone');
    }
    expect(read('pubspec.yaml').contains('face_landmarker'), isFalse);
    expect(read('pubspec.yaml').contains('selfie_multiclass'), isFalse);
  });

  test('les bibliothèques de visage d\'Android sont déclarées dans Gradle, pas dans les pods de l\'iPhone', () {
    final gradle = read('android/app/build.gradle');
    expect(gradle.contains('com.google.mediapipe:tasks-vision'), isTrue);
    expect(gradle.contains('play-services-mlkit-face-detection'), isTrue);   // version Google Play : modèle non embarqué
    final podfile = read('ios/Podfile');
    expect(RegExp('MediaPipe|MLKitFace|mediapipe', caseSensitive: false).hasMatch(podfile), isFalse, reason: 'aucun composant de visage d\'Android dans l\'iPhone');
  });

  test('le moteur de visage actuel est coupé hors Android (rien n\'est chargé sur iPhone ni sur le web)', () {
    expect(read('lib/services/face_filters.dart').contains('static bool get available => !kIsWeb && Platform.isAndroid;'), isTrue);
    expect(read('lib/services/face_engine.dart').contains('Platform.isAndroid'), isTrue);
  });

  test('budget : les ressources partagées par Android et iPhone restent sous 45 Mo', () {
    // aujourd'hui environ 38 Mo, dont 24 Mo pour le contrôle de contenu explicite (nsfw), nécessaire sur les deux plateformes
    expect(sizeMb('assets'), lessThanOrEqualTo(45), reason: 'ressources partagées trop lourdes : déplace ce qui ne sert qu\'à une plateforme dans son dossier natif');
    expect(File('assets/models/nsfw_mobilenet_v2_140_224.tflite').existsSync(), isTrue);
  });
}
