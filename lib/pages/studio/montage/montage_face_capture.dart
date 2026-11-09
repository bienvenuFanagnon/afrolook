import 'package:flutter/material.dart';

import '../../../l10n/tr.dart';
import '../../../services/face_engine.dart';
import '../../create/create_camera_page.dart';
import 'montage_catalog.dart';

/// Modèle à filtres de visage (09/11/2026) : on se filme d'abord, avec l'avatar et l'effet de bouche du modèle déjà choisis (la personne peut tout changer), puis le modèle
/// s'ouvre sur ce qu'elle vient de filmer. Le moteur de visage n'existe que sur Android pour l'instant : ailleurs, un message clair et rien d'autre.
/// Rend ce que la personne a filmé ou photographié, ou null (annulé, ou moteur indisponible). Un choix « galerie » n'applique pas les filtres : il est ignoré.
Future<CreateCaptureResult?> captureForFaceTemplate(BuildContext context, TemplateFace face) async {
  if (!FaceEngine.enabled) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(context.tr('Ce modèle utilise les filtres de visage, disponibles sur Android pour le moment.'))));
    return null;
  }
  final r = await Navigator.of(context).push<CreateCaptureResult>(
    MaterialPageRoute(builder: (_) => CreateCameraPage(presetAvatar: face.avatar, presetMagic: face.magic, presetGesture: face.gesture)),
  );
  if (r == null || r.openGallery || r.path == null) return null;
  return r;
}
