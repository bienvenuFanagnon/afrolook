import 'dart:async';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Rapport de plantages (Firebase Crashlytics) : on voit enfin combien de personnes sont touchées, sur quel modèle de téléphone et à quel endroit.
///
/// Règles :
///  - actif seulement dans une version publiée ou l'APK de test (jamais en développement : pas de bruit) ;
///  - AUCUNE donnée personnelle : ni nom, ni e-mail, ni identifiant de compte. Seulement le modèle (déjà connu de Crashlytics) et la mémoire du téléphone ;
///  - ne fait jamais échouer le démarrage : toute erreur ici est ignorée.
///
/// Limite à connaître : quand Android ferme une application SANS la faire planter (manque de mémoire, « tuée » en arrière-plan), aucun rapport n'est envoyé.
/// C'est pourquoi la mémoire du téléphone est jointe à chaque rapport : on pourra voir si les plantages se concentrent sur certains appareils ou sur tous.
class CrashReporting {
  CrashReporting._();

  /// Téléphone à peu de mémoire (≤ 4 Go, ou signalé « low RAM » par Android). Renseigné par [init] ; faux tant qu'on ne sait pas.
  static bool lowMemoryDevice = false;

  /// Mémoire totale en Mo (0 si inconnue).
  static int totalRamMb = 0;

  /// Seuil : jusqu'à 4,2 Go de mémoire utile, on considère le téléphone comme « petit » (un téléphone « 4 Go » affiche environ 3 600 à 3 900 Mo).
  static const int lowRamThresholdMb = 4200;

  static bool get _supported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// À appeler une fois, APRÈS `Firebase.initializeApp`.
  static Future<void> init() async {
    if (!_supported) return;
    try {
      final crashlytics = FirebaseCrashlytics.instance;
      await crashlytics.setCrashlyticsCollectionEnabled(kReleaseMode || const bool.fromEnvironment('TEST_BUILD'));

      // Erreurs de l'interface et erreurs asynchrones non rattrapées : enregistrées sans faire croire à un plantage (l'application a continué).
      // Les vrais plantages (natifs, fermeture brutale) sont rapportés tout seuls par Crashlytics, comme « fatals ».
      final previous = FlutterError.onError;
      FlutterError.onError = (FlutterErrorDetails details) {
        previous?.call(details);
        unawaited(crashlytics.recordFlutterError(details));
      };
      PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
        unawaited(crashlytics.recordError(error, stack));
        return true;
      };

      await _describeDevice(crashlytics);
    } catch (e) {
      debugPrint('Crashlytics indisponible (sans gravité) : $e');
    }
  }

  static Future<void> _describeDevice(FirebaseCrashlytics crashlytics) async {
    try {
      if (Platform.isAndroid) {
        final info = await DeviceInfoPlugin().androidInfo;
        totalRamMb = info.physicalRamSize;
        lowMemoryDevice = info.isLowRamDevice || (totalRamMb > 0 && totalRamMb <= lowRamThresholdMb);
        await crashlytics.setCustomKey('ram_total_mb', totalRamMb);
        await crashlytics.setCustomKey('ram_free_mb_au_demarrage', info.availableRamSize);
        await crashlytics.setCustomKey('android_low_ram', info.isLowRamDevice);
        await crashlytics.setCustomKey('android_sdk', info.version.sdkInt);
      }
      await crashlytics.setCustomKey('petit_telephone', lowMemoryDevice);
      await crashlytics.setCustomKey('apk_de_test', const bool.fromEnvironment('TEST_BUILD'));
    } catch (_) {/* modèle illisible : le rapport part quand même, sans ces informations */}
  }

  /// Note une étape qui aide à comprendre un plantage (ex. « accueil ouvert », « vidéo lancée »). Texte court, jamais de donnée personnelle.
  static void breadcrumb(String message) {
    if (!_supported) return;
    try {
      unawaited(FirebaseCrashlytics.instance.log(message));
    } catch (_) {}
  }
}
