// Écoutes (streams) de chaque titre, en direct : les sons d'artistes (champ streamCount du son) et les musiques gratuites
// d'Afrolook (MusicStudioStats). Tout widget qui montre un titre affiche son nombre d'écoutes avec [StreamsText].

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'music_queue.dart';

class StreamCounts {
  StreamCounts._();

  /// Écoutes connues, par clé de titre (`music_artist:id`, `music_free:id`).
  static final ValueNotifier<Map<String, int>> counts = ValueNotifier<Map<String, int>>(const {});

  static final Map<String, int> _refs = {};
  static final Map<String, StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>> _subs = {};
  static StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _studioSub;

  /// Écoutes d'un titre : valeur en direct si on l'a, sinon celle du son chargé, sinon 0.
  static int of(MusicTrack t) => counts.value[t.key] ?? t.sound?.streamCount ?? 0;

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
    if (_subs.containsKey(key)) return;
    try {
      _subs[key] = FirebaseFirestore.instance.collection('artist_sounds').doc(t.id).snapshots().listen((d) {
        if (d.exists) _set(key, (d.data()?['streamCount'] as num?)?.toInt() ?? 0);
      }, onError: (_) {});
    } catch (_) {
      // Firebase pas prêt (aperçus, tests) : on garde la valeur du son
    }
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
    _subs.remove(key)?.cancel();
  }

  static void _startStudio() {
    if (_studioSub != null) return;
    try {
      _studioSub = FirebaseFirestore.instance.collection('MusicStudioStats').snapshots().listen((s) {
        final m = {...counts.value};
        for (final d in s.docs) {
          m['music_free:${d.id}'] = (d.data()['streamCount'] as num?)?.toInt() ?? 0;
        }
        counts.value = m;
      }, onError: (_) {});
    } catch (_) {}
  }

  /// 950 → « 950 » ; 1 234 → « 1,2 k » ; 1 500 000 → « 1,5 M ».
  static String fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(n >= 10000000 ? 0 : 1).replaceAll('.', ',')} M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(n >= 10000 ? 0 : 1).replaceAll('.', ',')} k';
    return '$n';
  }

  /// « 0 écoute », « 1 écoute », « 1,2 k écoutes ».
  static String label(int n) => '${fmt(n)} écoute${n > 1 ? 's' : ''}';
}
