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
