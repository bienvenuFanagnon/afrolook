import 'package:shared_preferences/shared_preferences.dart';

/// Service singleton de rotation équitable des publicités.
///
/// Principe : un compteur global partagé par TOUS les slots pub (bannière + carousel).
/// Chaque slot qui "réclame" une pub avance le compteur → les slots adjacents
/// sur la même page ou le même scroll voient toujours des pubs différentes.
///
/// Persisté en SharedPreferences → la rotation continue d'une session à l'autre.
class AdRotationService {
  static final AdRotationService _instance = AdRotationService._();
  static AdRotationService get instance => _instance;
  AdRotationService._();

  static const _kIndexKey = 'ad_rotation_global_index';

  int _globalIndex = 0;
  bool _loaded = false;

  /// À appeler une seule fois au démarrage (ou après loadAdvertisements).
  Future<void> init() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    _globalIndex = prefs.getInt(_kIndexKey) ?? 0;
    _loaded = true;
  }

  /// Retourne l'index de la prochaine pub dans [totalAds] et avance le compteur.
  /// Deux appels consécutifs donnent toujours des indices différents (si totalAds > 1).
  int claimNext(int totalAds) {
    if (totalAds <= 0) return 0;
    final idx = _globalIndex % totalAds;
    _globalIndex++;
    _persist();
    return idx;
  }

  /// Lit l'index courant sans avancer (pour initialiser le carousel).
  int peekCurrent(int totalAds) {
    if (totalAds <= 0) return 0;
    return _globalIndex % totalAds;
  }

  /// Navigation carousel → page suivante (avance le compteur global).
  int carouselNext(int totalAds) => claimNext(totalAds);

  /// Navigation carousel → page précédente (recule de 2 pour revenir en arrière).
  int carouselPrev(int totalAds) {
    if (totalAds <= 0) return 0;
    _globalIndex = (_globalIndex - 2 + totalAds * 1000).clamp(0, 999999999);
    final idx = _globalIndex % totalAds;
    _globalIndex++;
    _persist();
    return idx;
  }

  /// Reset partiel — à appeler quand la liste des pubs change (nouvelles pubs chargées).
  /// Avance d'un seul cran pour éviter de recommencer exactement au même point.
  void onAdsReloaded() {
    _globalIndex++;
    _persist();
  }

  void _persist() {
    SharedPreferences.getInstance().then(
      (prefs) => prefs.setInt(_kIndexKey, _globalIndex),
    );
  }
}
