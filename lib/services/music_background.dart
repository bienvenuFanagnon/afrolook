import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Réglage de la personne : la musique continue-t-elle quand elle quitte l'application ou verrouille l'écran ?
/// Désactivé par défaut : la lecture se met en pause dès que l'application passe en arrière-plan et reprend à son retour
/// (voir `MusicOverlayHost`). Activé : la lecture continue en arrière-plan (notification de lecture sur le téléphone).
class MusicBackground {
  MusicBackground._();

  static const _key = 'music_background_play';

  /// Vrai quand la personne a autorisé la lecture en arrière-plan.
  static final ValueNotifier<bool> enabled = ValueNotifier<bool>(false);
  static bool _loaded = false;

  /// Lit le réglage enregistré (une seule fois). Sans valeur enregistrée : désactivé.
  static Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final sp = await SharedPreferences.getInstance();
      enabled.value = sp.getBool(_key) ?? false;
    } catch (_) {}
  }

  static Future<void> set(bool value) async {
    enabled.value = value;
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setBool(_key, value);
    } catch (_) {}
  }
}
