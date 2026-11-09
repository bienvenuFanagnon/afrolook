import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

import '../models/model_data.dart';
import 'api/posts_api.dart';
import 'authentic_video_check.dart';

/// Contrôle d'authenticité d'une vidéo REGARDÉE (carte horizontale du fil), comme sur la page des vidéos verticales : gratuit, sur ce téléphone, seul le résultat est envoyé.
/// 3 secondes après le début de la lecture (une nouvelle tentative 3 s plus tard si la vidéo était en pause) d'une vidéo non encore validée ni marquée, quelques images sont lues avec la reconnaissance de texte de Google ; le téléphone envoie
/// « rien » ou « marque vue ». Une fois par vidéo et par personne, jamais pour sa propre vidéo ni une pub, 12 vidéos par séance au plus, une analyse à la fois ; l'analyse se termine même si la personne passe à la suite (20 s au plus).
class AuthenticityWatcher {
  Timer? _timer;
  static bool _busy = false;
  static int _scans = 0;

  /// Délai avant le contrôle (secondes) et nombre de vidéos contrôlées par séance (demande du propriétaire, 09/11/2026 : plus tôt, plus de vidéos).
  static const startAfterSeconds = 3;
  static const maxScansPerSession = 12;
  static Set<String>? _checked;

  static Future<Set<String>> _loadChecked() async {
    if (_checked != null) return _checked!;
    try {
      final p = await SharedPreferences.getInstance();
      _checked = (p.getStringList('auth_checked_ids') ?? const <String>[]).toSet();
    } catch (_) {
      _checked = <String>{};
    }
    return _checked!;
  }

  static Future<void> _remember(String id) async {
    final set = await _loadChecked();
    set.add(id);
    try {
      final list = set.toList();
      final p = await SharedPreferences.getInstance();
      await p.setStringList('auth_checked_ids', list.length > 300 ? list.sublist(list.length - 300) : list);
    } catch (_) {}
  }

  /// La vidéo doit-elle être contrôlée ? (pas sur le web, pas une pub, pas la sienne, pas déjà validée ou marquée)
  @visibleForTesting
  static bool needsCheck(Post post, String? me) => !kIsWeb && post.isAdvertisement != true && post.id != null && post.url_media != null && post.user_id != me && post.authenticity == null;

  /// Programme le contrôle (sans effet si un contrôle est déjà programmé pour cette vidéo). [controller] rend le lecteur en cours, [cdn] l'adresse lisible de la vidéo,
  /// [stillWanted] dit si la personne regarde toujours cette vidéo, [onState] reçoit le verdict du serveur (« validated » ou « flagged ») et la marque.
  void schedule({
    required Post post,
    required String? me,
    required VideoPlayerController? Function() controller,
    required String Function(String url) cdn,
    required bool Function() stillWanted,
    required void Function(String state, String? mark) onState,
  }) {
    if (_timer?.isActive == true || !needsCheck(post, me)) return;
    final id = post.id!;
    Future<void> attempt(bool retried) async {
      if (_scans >= maxScansPerSession || !stillWanted()) return;
      if ((await _loadChecked()).contains(id)) return;
      final vc = controller();
      // en pause, en chargement ou une autre analyse en cours : une seule nouvelle tentative, un peu plus tard
      if (_busy || vc == null || !vc.value.isInitialized || !vc.value.isPlaying) {
        if (!retried) _timer = Timer(const Duration(seconds: startAfterSeconds), () => attempt(true));
        return;
      }
      _busy = true;
      _scans++;
      try {
        final res = await AuthenticVideoCheck.scanUrl(cdn(post.url_media!), vc.value.duration.inMilliseconds);
        if (res == null) return;
        await _remember(id);
        final state = await PostsApi.reportAuthenticity(id, clean: res == 'clean', mark: res == 'clean' ? null : res);
        if (state != null && post.authenticity != state) onState(state, state == 'flagged' ? (res == 'clean' ? null : res) : null);
      } finally {
        _busy = false;
      }
    }

    _timer = Timer(const Duration(seconds: startAfterSeconds), () => attempt(false));
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
  }
}
