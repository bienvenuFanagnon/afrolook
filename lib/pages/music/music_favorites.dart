// Favoris de la page Musique : un cœur sur n'importe quel titre (musique gratuite d'Afrolook ou son d'artiste).
// Liste privée, gardée par l'API (GET/PUT/DELETE /music/favorites) : chaque personne ne voit que les siens.

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../services/api/music_api.dart';

class MusicFavorites {
  MusicFavorites._();

  /// Clés « kind:id » des favoris de la personne connectée.
  static final ValueNotifier<Set<String>> keys = ValueNotifier<Set<String>>({});
  static String? _uid;

  static String? get uid => FirebaseAuth.instance.currentUser?.uid;

  /// Démarre (ou relance après un changement de compte) le chargement des favoris.
  static void start() {
    final u = uid;
    if (u == null) return;
    if (_uid == u) return;
    _uid = u;
    keys.value = {};
    MusicApi.favorites().then((rows) {
      keys.value = {for (final r in rows) '${r['kind']}:${r['item_id']}'};
    }).catchError((_) {
      _uid = null; // sera retenté
    });
  }

  static bool isFav(String kind, String id) => keys.value.contains('$kind:$id');

  /// Ajoute ou retire un favori ([title] n'est plus enregistré : l'API relit le titre).
  static Future<void> toggle(String kind, String id, {required String title}) async {
    if (uid == null) return;
    final on = isFav(kind, id);
    // Mise à jour immédiate de l'écran, l'API confirme ensuite
    keys.value = on ? ({...keys.value}..remove('$kind:$id')) : {...keys.value, '$kind:$id'};
    try {
      await MusicApi.setFavorite(kind, id, !on);
    } catch (_) {
      keys.value = on ? {...keys.value, '$kind:$id'} : ({...keys.value}..remove('$kind:$id'));
    }
  }
}
