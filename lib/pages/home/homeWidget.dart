import 'dart:math';

import '../../models/model_data.dart';

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