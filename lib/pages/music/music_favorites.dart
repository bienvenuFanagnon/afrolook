// Favoris de la page Musique : un cœur sur n'importe quel titre (musique gratuite d'Afrolook ou son d'artiste).
// Collection MusicFavorites/{uid}_{kind}_{id} : chaque personne lit et écrit seulement les siens (règles Firestore).

import 'package:afrotok/services/read_meter.dart';
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class MusicFavorites {
  MusicFavorites._();

  /// Clés « kind:id » des favoris de la personne connectée.
  static final ValueNotifier<Set<String>> keys = ValueNotifier<Set<String>>({});
  static StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  static String? _uid;

  static String? get uid => FirebaseAuth.instance.currentUser?.uid;

  /// Démarre (ou relance après un changement de compte) l'écoute des favoris.
  static void start() {
    final u = uid;
    if (u == null) return;
    if (_uid == u && _sub != null) return;
    _sub?.cancel();
    _uid = u;
    _sub = FirebaseFirestore.instance.collection('MusicFavorites').where('uid', isEqualTo: u).snapshotsM('music_favorites.dart:27').listen((s) {
      keys.value = {for (final d in s.docs) '${d.data()['kind']}:${d.data()['id']}'};
    }, onError: (_) {});
  }

  static bool isFav(String kind, String id) => keys.value.contains('$kind:$id');

  /// Ajoute ou retire un favori ; [title] sert à l'affichage de l'onglet Favoris.
  static Future<void> toggle(String kind, String id, {required String title}) async {
    final u = uid;
    if (u == null) return;
    final ref = FirebaseFirestore.instance.collection('MusicFavorites').doc('${u}_${kind}_$id');
    final on = isFav(kind, id);
    // Mise à jour immédiate de l'écran, le serveur confirme ensuite
    keys.value = on ? ({...keys.value}..remove('$kind:$id')) : {...keys.value, '$kind:$id'};
    try {
      if (on) {
        await ref.delete();
      } else {
        await ref.set({'uid': u, 'kind': kind, 'id': id, 'title': title, 'createdAt': Timestamp.now()});
      }
    } catch (_) {
      keys.value = on ? {...keys.value, '$kind:$id'} : ({...keys.value}..remove('$kind:$id'));
    }
  }
}
