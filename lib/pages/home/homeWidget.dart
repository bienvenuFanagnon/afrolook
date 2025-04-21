import 'dart:math';

import '../../models/model_data.dart';

String getTabBarTypeMessage(String type) {
  switch (type) {
    case 'ACTUALITES':
      return 'a posté une actualité 📰';
    case 'LOOKS':
      return 'a posté un look 📸';
    case 'GAMER':
      return 'a posté un game story 🎮';
    case 'SPORT':
      return 'a posté un sport story ⚽⛹️';
    case 'EVENEMENT':
      return 'a posté un événement 📅';
    case 'OFFRES':
      return 'a posté une offre 💼';
    default:
      return 'a posté un look 📸';
  }
}
int genererNombreAleatoire() {
  // Créer un objet Random
  final random = Random();

  // Générer un nombre aléatoire entre 0 et 8 (11 - 3)
  final nombreAleatoire = random.nextInt(9);

  // Ajouter 3 pour obtenir un nombre entre 3 et 11
  return nombreAleatoire + 3;
}