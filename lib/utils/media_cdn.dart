// Médias de la musique (extraits, pochettes, musiques gratuites) servis par le CDN Afrolook (cdn.afrolookmedia.com),
// avec retour automatique sur Firebase Storage si le CDN ne répond pas.
// Les titres complets (liens d'écoute temporaires, payants) ne passent PAS par le CDN : leur lien meurt après 10 minutes
// et un cache public les garderait en ligne.

import 'package:firebase_storage/firebase_storage.dart';

import '../services/remote_config_service.dart';

class MediaCdn {
  MediaCdn._();
  static const _host = 'https://cdn.afrolookmedia.com/media/';
  static const _fb = 'firebasestorage.googleapis.com/v0/b/';

  /// URL Firebase Storage → URL CDN (inchangée si le CDN est coupé, si l'URL n'est pas Firebase, ou si c'est un lien temporaire).
  static String url(String? u) {
    if (u == null || u.isEmpty) return u ?? '';
    try {
      if (!RemoteConfigService.instance.isPageActive('cdn_active')) return u;
    } catch (_) {}
    if (u.contains('artist_sound_tmp') || !u.contains(_fb)) return u;
    final i = u.indexOf('/o/');
    if (i < 0) return u;
    return '$_host${u.substring(i + 3)}';
  }

  /// URL CDN → URL Firebase Storage d'origine (pour le repli).
  static String? original(String u) {
    if (!u.startsWith(_host)) return null;
    String bucket;
    try {
      bucket = FirebaseStorage.instance.app.options.storageBucket ?? 'afrolooki.appspot.com';
    } catch (_) {
      bucket = 'afrolooki.appspot.com';
    }
    return 'https://firebasestorage.googleapis.com/v0/b/$bucket/o/${u.substring(_host.length)}';
  }
}
