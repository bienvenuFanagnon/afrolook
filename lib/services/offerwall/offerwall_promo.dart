import 'package:intl/intl.dart';

/// Montants annoncés à la personne pour les tâches (page « Travaille et gagne », carte du fil, page Récompenses, tutoriel).
/// Thème décidé par le propriétaire (27/10/2026) : TOUT SE GAGNE EN TRAVAILLANT DANS AFROLOOK ; les pièces gagnées se convertissent en argent réel.
///
/// Ces chiffres sont ceux donnés par le propriétaire (« jusqu'à ») ; 1 pièce = 0,4 FCFA, donc 10 000 F = 25 000 pièces et 1 200 F = 3 000 pièces (plafond du jour porté de 6 000 F à 10 000 F le 11/11/2026).
/// ATTENTION : ils ne sont vrais que si les plafonds du serveur (AppConfig/offerwall : dailyCapCoins, weeklyCapCoins) les permettent
/// (au-delà, la tâche passe « en revue »). Garder ces constantes et les textes du tutoriel (tuto_catalog.dart, scène « taches ») alignés.
class OfferwallPromo {
  OfferwallPromo._();

  static const int maxPerDayFcfa = 10000;   // décision du propriétaire (11/11/2026) : 10 000 F par jour
  static const int maxPerMonthFcfa = 300000; // 30 jours
  static const int maxPerTaskFcfa = 1200;

  static final NumberFormat _n = NumberFormat.decimalPattern('fr');

  /// « 6 000 », « 180 000 »…
  static String f(int v) => _n.format(v);
}
