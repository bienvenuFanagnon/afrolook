import 'package:flutter/material.dart';

import '../models/model_data.dart';
import '../pages/create/create_hub_page.dart';

/// « Répondre en vidéo » à une publication : un seul point d'entrée pour tous les écrans (carte du fil, pages vidéo verticale et paysage, pages de détails des images, vidéos et textes).
/// La caméra s'ouvre tout de suite (15 s au plus) ; la réponse garde un lien vers ce post et un bandeau « Tu réponds à @pseudo » l'annonce dans tout le parcours.
class PostReply {
  PostReply._();

  /// Une publication ordinaire (pas une pub, un défi ou un article) qui a un identifiant : on peut lui répondre.
  static bool canReply(Post p) => (p.id ?? '').isNotEmpty && p.isAdvertisement != true && p.type == PostType.POST.name;

  static Future<void> start(BuildContext context, Post p) async {
    if (!canReply(p)) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => CreateHubPage(start: CreateStart.video, replyToPostId: p.id)));
  }
}
