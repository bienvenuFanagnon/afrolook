/// « Lancer un défi » depuis l'espace Défis : le parcours de création s'ouvre avec le type « Défi 🏆 » déjà choisi.
/// L'indicateur est lu une seule fois par la page de publication (qui le remet à zéro), et remis à zéro au retour dans l'espace Défis.
class DefiLaunchIntent {
  DefiLaunchIntent._();
  static bool pending = false;

  /// Lit et remet à zéro.
  static bool take() {
    final v = pending;
    pending = false;
    return v;
  }
}
