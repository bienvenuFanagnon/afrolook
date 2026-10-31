// J'aime sur les musiques (sons d'artistes et musiques gratuites) : un cœur sur n'importe quel titre, avec le nombre de j'aime visible partout.
// Les j'aime passent par l'API (PUT/DELETE /music/likes/{kind}/{id}) : un j'aime par personne, jamais compté deux fois. Ne pas confondre avec les Favoris (liste privée de la page Musique).

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'api/music_api.dart';
import 'music_queue.dart';
import 'stream_counts.dart';

class MusicLikes {
  MusicLikes._();

  /// Clés « music_kind:id » des titres aimés par la personne connectée.
  static final ValueNotifier<Set<String>> keys = ValueNotifier<Set<String>>({});
  static String? _uid;
  static final Set<String> _busy = {};

  static String? get uid => FirebaseAuth.instance.currentUser?.uid;

  /// Démarre (ou relance après un changement de compte) le suivi des j'aime de la personne.
  /// L'API dit « aimé ou non » avec chaque titre chargé (champ `me.liked`) : les cœurs se remplissent au fil des chargements.
  static void start() {
    final u = uid;
    if (u == null) return;
    if (_uid == u) return;
    _uid = u;
    keys.value = {};
    MusicApi.onMe = (soundId, me) {
      final k = 'music_artist:$soundId';
      final has = keys.value.contains(k);
      if (me['liked'] == true && !has) keys.value = {...keys.value, k};
      if (me['liked'] == false && has) keys.value = ({...keys.value}..remove(k));
      if (me['owns'] == true && !MusicQueue.ownedIds.value.contains(soundId)) MusicQueue.ownedIds.value = {...MusicQueue.ownedIds.value, soundId};
    };
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
      await MusicApi.setLike(t.kind, t.id, want);
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
