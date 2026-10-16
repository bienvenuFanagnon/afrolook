// Lien entre un montage du Studio fait avec un son d'artiste et le post publié ensuite : le serveur vérifie que le
// montage est bien celui de la personne (voir la fonction artistSoundLinkPost), puis le post apparaît dans la liste
// « posts faits avec ce son » de la page du son.

import 'package:cloud_functions/cloud_functions.dart';

class StudioSoundLink {
  StudioSoundLink._();

  static String? _jobId;

  /// À appeler quand un montage fait avec un son d'artiste revient du Studio (null efface).
  static void set(String? jobId) => _jobId = jobId;

  static void clear() => _jobId = null;

  /// À appeler juste après la création d'un post : relie le post au son, sans jamais bloquer ni faire échouer la publication.
  static void linkIfPending(String postId) {
    final job = _jobId;
    if (job == null) return;
    _jobId = null;
    () async {
      try {
        await FirebaseFunctions.instance.httpsCallable('artistSoundLinkPost').call({'postId': postId, 'jobId': job});
      } catch (_) {}
    }();
  }
}
