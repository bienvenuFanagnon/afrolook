import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../l10n/tr.dart';
import '../../models/model_data.dart';
import '../../services/api/posts_api.dart';
import '../../services/authentic_video_check.dart';
import '../../services/media_fingerprint.dart';
import '../../services/post_source_link.dart';
import '../studio/studio_models.dart';
import 'chronique_flow.dart';
import 'create_publish_page.dart';
import 'create_result.dart';

/// Ouvre le « Formulaire unique » du parcours « Créer un post » ([CreatePublishPage]) pour ce qui vient d'être préparé : une vidéo, des photos, un audio ou un texte.
///
/// [source] : origine du média ([PostSourceLink.captured], [PostSourceLink.edited] ou [PostSourceLink.imported]) ; elle part avec la publication. Retour : [kCreateBack]
/// si la personne revient en arrière (l'écran précédent reste ouvert), sinon [kCreateDone] (publié ou fermé : tout le parcours se referme).
Future<String> openCreateForm(
  BuildContext context, {
  StudioResult? studio,
  CreatePostKind? kind,
  List<Uint8List>? images,
  Canal? canal,
  String? defiPostId,
  String? source,
  File? audio,
  int? audioSeconds,
  File? audioCover,
}) async {
  // chronique en cours de création : même Studio, mais la fin du parcours est l'aperçu puis la publication de la chronique
  final ck = ChroniqueFlow.active;
  if (ck != null) {
    return finishChronique(context, studio: studio, audio: audio, audioCover: audioCover, images: images, kind: ck);
  }
  var k = kind ?? CreatePostKind.text;
  File? video;
  final imageFiles = <File>[];
  File? audioFile = audio;
  String? description;
  final notes = <String>[];
  if (studio != null) {
    description = studio.textContent;
    switch (studio.type) {
      case StudioContentType.video:
        k = CreatePostKind.video;
        video = studio.mediaFile;
      case StudioContentType.image:
        k = CreatePostKind.image;
        if (studio.mediaFile != null) imageFiles.add(studio.mediaFile!);
      case StudioContentType.audio:
        k = CreatePostKind.audio;
        audioFile = studio.mediaFile;
      case StudioContentType.text:
        k = CreatePostKind.text;
    }
    if (studio.templateId != null && studio.templateId!.startsWith('montage_')) notes.add(context.tr('Modèle Afrolook ajouté.'));
    if (studio.artistSoundId != null) notes.add(context.tr('Musique d\'artiste ajoutée.'));
  } else if (audioFile != null) {
    k = CreatePostKind.audio;
  } else if (images != null && images.isNotEmpty) {
    k = CreatePostKind.image;
  }
  // Contenu déjà publié par un autre compte ? L'empreinte visuelle est calculée ici (sur le téléphone) ; un doublon est refusé, sauf « C'est le mien » (la modération vérifie)
  PostFingerprintLink.clear();
  if (video != null || imageFiles.isNotEmpty || (images != null && images.isNotEmpty)) {
    final isVideo = video != null;
    final hashes = isVideo ? await MediaFingerprint.ofVideo(video) : await MediaFingerprint.ofImageBytes(imageFiles.isNotEmpty ? await imageFiles.first.readAsBytes() : images!.first);
    final author = await PostsApi.duplicateOf(isVideo ? 'video' : 'image', hashes);
    if (author != null) {
      if (!context.mounted) return kCreateBack;
      if (!await AuthenticVideoCheck.duplicateDialog(context, author: author, video: isVideo)) return kCreateBack;
    }
    PostFingerprintLink.set(hashes);
  }
  PostSourceLink.set(source);
  final r = await Navigator.of(context).push<String>(
    MaterialPageRoute(
      builder: (_) => CreatePublishPage(
        kind: k,
        video: video,
        images: images ?? const [],
        imageFiles: imageFiles,
        audio: audioFile,
        audioSeconds: audioSeconds,
        audioCover: audioCover,
        canal: canal,
        defiPostId: defiPostId,
        initialDescription: description,
        notes: notes,
      ),
    ),
  );
  PostSourceLink.clear();
  PostVoiceLink.clear();
  PostFingerprintLink.clear();
  return r == kCreateBack ? kCreateBack : kCreateDone;
}
