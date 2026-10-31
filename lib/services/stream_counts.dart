// Écoutes (streams) de chaque titre, en direct : les sons d'artistes (champ streamCount du son) et les musiques gratuites
// d'Afrolook (MusicStudioStats). Tout widget qui montre un titre affiche son nombre d'écoutes avec [StreamsText].

import 'dart:async';

import 'api/music_api.dart';
import 'package:flutter/foundation.dart';

import 'music_queue.dart';

class StreamCounts {
  StreamCounts._();

  /// Écoutes connues, par clé de titre (`music_artist:id`, `music_free:id`).
  static final ValueNotifier<Map<String, int>> counts = ValueNotifier<Map<String, int>>(const {});

  /// J'aime connus, par clé de titre : mêmes sources que les écoutes (le document du son, ou MusicStudioStats pour les musiques gratuites).
  static final ValueNotifier<Map<String, int>> likes = ValueNotifier<Map<String, int>>(const {});

  static final Map<String, int> _refs = {};
  static final Set<String> _fetched = {};

  /// Écoutes d'un titre : valeur en direct si on l'a, sinon celle du son chargé, sinon 0.
  static int of(MusicTrack t) => counts.value[t.key] ?? t.sound?.streamCount ?? 0;

  /// J'aime d'un titre : valeur en direct si on l'a, sinon celle du son chargé, sinon 0.
  static int likesOf(MusicTrack t) => likes.value[t.key] ?? t.sound?.likeCount ?? 0;

  static void setLikes(String key, int v) {
    if (likes.value[key] == v) return;
    likes.value = {...likes.value, key: v};
  }

  static void _set(String key, int v) {
    if (counts.value[key] == v) return;
    counts.value = {...counts.value, key: v};
  }

  /// Commence à suivre un titre (à appeler à l'affichage, avec [release] à la disparition du widget).
  static void listen(MusicTrack t) {
    if (t.kind == 'free') {
      _startStudio();
      return;
    }
    final key = t.key;
    _refs[key] = (_refs[key] ?? 0) + 1;
    if (!_fetched.add(key)) return;
    // Compteurs relus sur l'API (une fois par titre et par session ; plus de lecture en direct)
    MusicApi.sound(t.id).then((s) {
      if (s != null) {
        _set(key, s.streamCount);
        setLikes(key, s.likeCount);
      }
    }).catchError((_) {
      _fetched.remove(key);
    });
  }

  static void release(MusicTrack t) {
    if (t.kind == 'free') return;
    final key = t.key;
    final n = (_refs[key] ?? 1) - 1;
    if (n > 0) {
      _refs[key] = n;
      return;
    }
    _refs.remove(key);
  }

  /// Les écoutes des musiques gratuites d'Afrolook ne sont pas encore exposées par l'API (voir lacunes_api_argent_creations.md).
  static void _startStudio() {}

  /// 950 → « 950 » ; 1 234 → « 1,2 k » ; 1 500 000 → « 1,5 M ».
  static String fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(n >= 10000000 ? 0 : 1).replaceAll('.', ',')} M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(n >= 10000 ? 0 : 1).replaceAll('.', ',')} k';
    return '$n';
  }

  /// « 0 écoute », « 1 écoute », « 1,2 k écoutes ».
  static String label(int n) => '${fmt(n)} écoute${n > 1 ? 's' : ''}';
}
