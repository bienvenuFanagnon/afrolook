import 'dart:math';

import '../../models/model_data.dart';
import 'dart:io';
import 'package:flutter/foundation.dart'; // Pour kIsWeb
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
String getTabBarTypeMessage(String type,Post post) {
  // switch (type) {
  //   case 'ACTUALITES':
  //     return 'a posté une actualité 📰 : ${post.description}';
  //   case 'LOOKS':
  //     return 'a posté un look 📸 : ${post.description}';
  //   case 'GAMER':
  //     return 'a posté un game story 🎮';
  //   case 'SPORT':
  //     return 'a posté un sport story ⚽⛹️ : : ${post.description}';
  //   case 'EVENEMENT':
  //     return 'a posté un événement 📅 : ${post.description}';
  //   case 'OFFRES':
  //     return 'a posté une offre 💼';
  //   default:
  //     return 'a posté un look 📸 : ${post.description}';
  // }
  return '${post.description}';

}
int genererNombreAleatoire() {
  // Créer un objet Random
  final random = Random();

  // Générer un nombre aléatoire entre 0 et 8 (11 - 3)
  final nombreAleatoire = random.nextInt(2);

  // Ajouter 3 pour obtenir un nombre entre 3 et 11
  return nombreAleatoire + 1;
}



Future<void> checkAndGenerateThumbnail({
  required String postId,
  required String videoUrl,
  String? currentThumbnail,
})
async {
  // 1. Vérifier si on est sur mobile et si le thumbnail est déjà présent
  if (kIsWeb) return; // On ne fait rien si c'est le web
  if (currentThumbnail != null && currentThumbnail.isNotEmpty) return;

  try {
    print("🎬 Génération du thumbnail pour le post: $postId");

    // 2. Générer le thumbnail dans un dossier temporaire
    // final String? fileName = await VideoThumbnail.thumbnailFile(
    //   video: videoUrl,
    //   thumbnailPath: (await getTemporaryDirectory()).path,
    //   imageFormat: ImageFormat.JPEG,
    //   maxHeight: 400, // Taille optimisée pour le partage
    //   quality: 75,
    // );

    final String? fileName = await VideoThumbnail.thumbnailFile(
      video: videoUrl,
      thumbnailPath: (await getTemporaryDirectory()).path,
      imageFormat: ImageFormat.JPEG,
      maxWidth: 1280, // Augmenté pour une haute résolution (720p ou plus)
      quality: 90,    // Augmenté pour éviter la pixellisation
    );

    if (fileName != null) {
      File file = File(fileName);

      // 3. Uploader vers Firebase Storage
      Reference ref = FirebaseStorage.instance
          .ref()
          .child('thumbnails')
          .child('$postId.jpg');

      UploadTask uploadTask = ref.putFile(file);
      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();

      // 4. Mettre à jour Firestore
      await FirebaseFirestore.instance.collection('Posts').doc(postId).update({
        'thumbnail': downloadUrl,
      });

      print("✅ Thumbnail mis à jour avec succès : $downloadUrl");
    }
  } catch (e) {
    print("❌ Erreur lors de la génération du thumbnail: $e");
  }
}