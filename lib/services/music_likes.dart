// J'aime sur les musiques (sons d'artistes et musiques gratuites) : un cœur sur n'importe quel titre, avec le nombre de j'aime visible partout.
// Collection MusicLikes/{uid}_{kind}_{id} : chaque personne lit seulement les siens ; l'écriture et le compteur du titre passent par la fonction
// musicToggleLike (un j'aime par personne, jamais compté deux fois). Ne pas confondre avec les Favoris (liste privée de la page Musique).

import 'dart:async';

import 'package:afrotok/services/read_meter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'music_queue.dart';
import 'stream_counts.dart';

class MusicLikes {
  MusicLikes._();

  /// Clés « music_kind:id » des titres aimés par la personne connectée.
  static final ValueNotifier<Set<String>> keys = ValueNotifier<Set<String>>({});
  static StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  static String? _uid;
  static final Set<String> _busy = {};

  static String? get uid => FirebaseAuth.instance.currentUser?.uid;

  /// Démarre (ou relance après un changement de compte) l'écoute des j'aime de la personne.
  static void start() {
    final u = uid;
    if (u == null) return;
    if (_uid == u && _sub != null) return;
    _sub?.cancel();
    _uid = u;
    try {
      _sub = FirebaseFirestore.instance.collection('MusicLikes').where('uid', isEqualTo: u).snapshotsM('music_likes.dart:start').listen((s) {
        keys.value = {for (final d in s.docs) 'music_${d.data()['kind']}:${d.data()['id']}'};
      }, onError: (_) {});
    } catch (_) {
      // Firebase pas prêt (aperçus, tests)
    }
  }

  static bool isLiked(MusicTrack t) => keys.value.contains(t.key);

  /// J'aime / je n'aime plus : l'écran change tout de suite (cœur et compteur), puis le serveur confirme ; annulé si le serveur refuse.
  static Future<void> toggle(MusicTrack t) async {
    if (uid == null || _busy.contains(t.key)) return;
    start();
    final want = !isLiked(t);
    final before = StreamCounts.likesOf(t);
    _busy.add(t.key);
    keys.value = want ? {...keys.value, t.key} : ({...keys.value}..remove(t.key));
    StreamCounts.setLikes(t.key, want ? before + 1 : (before > 0 ? before - 1 : 0));
    try {
      final r = await FirebaseFunctions.instance.httpsCallable('musicToggleLike').call({'kind': t.kind, 'id': t.id, 'like': want});
      final data = r.data is Map ? Map<String, dynamic>.from(r.data as Map) : const <String, dynamic>{};
      final count = (data['count'] as num?)?.toInt();
      if (count != null) StreamCounts.setLikes(t.key, count);
    } catch (_) {
      keys.value = want ? ({...keys.value}..remove(t.key)) : {...keys.value, t.key};
      StreamCounts.setLikes(t.key, before);
    } finally {
      _busy.remove(t.key);
    }
  }

  /// 950 → « 950 » ; 1 234 → « 1,2 k » (même format que les écoutes).
  static String fmt(int n) => StreamCounts.fmt(n);
}
