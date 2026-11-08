import 'ad_revenue_tracker.dart';

/// Moins de demandes de pubs pour rien (08/11/2026) : trois outils sans dépendance, faciles à tester.
///
///  - [AdBackoff] : après un échec (« pas de pub disponible »), on attend un peu avant de redemander la même sorte de pub (45 s, 90 s, puis 3 min au plus) ;
///    un succès remet tout à zéro. Une demande explicite d'une personne qui veut voir une pub ne passe jamais par l'attente.
///  - [AdPlan.interstitialWorthLoading] : une pub plein écran n'est demandée d'avance que si elle peut vraiment passer à la fermeture de la prochaine vidéo.
///  - [AdFunnel] : compteurs anonymes (demandée, reçue, échouée, affichée) par sorte de pub, envoyés avec les revenus pour voir enfin où part chaque demande.
class AdBackoff {
  AdBackoff._();

  static final Map<String, int> _fails = {};
  static final Map<String, DateTime> _until = {};

  /// Durées d'attente après le 1er, 2e, 3e échec de suite (le dernier palier est gardé ensuite).
  static const waits = [Duration(seconds: 45), Duration(seconds: 90), Duration(minutes: 3)];

  /// Vrai tant qu'on attend avant de redemander ce type de pub.
  static bool blocked(String key, {DateTime? now}) {
    final u = _until[key];
    return u != null && (now ?? DateTime.now()).isBefore(u);
  }

  static void failed(String key, {DateTime? now}) {
    final n = (_fails[key] ?? 0) + 1;
    _fails[key] = n;
    _until[key] = (now ?? DateTime.now()).add(waits[(n - 1).clamp(0, waits.length - 1)]);
  }

  static void succeeded(String key) {
    _fails.remove(key);
    _until.remove(key);
  }

  static void reset() {
    _fails.clear();
    _until.clear();
  }
}

class AdPlan {
  AdPlan._();

  /// La pub plein écran du fil passe toutes les [every] vidéos fermées, pas pendant les [warmupMinutes] premières minutes, pas avant [minGapMinutes] depuis la précédente,
  /// et au plus [capReached] fois par jour. On ne la demande d'avance que si la PROCHAINE fermeture de vidéo peut la montrer (avec une minute de marge).
  static bool interstitialWorthLoading({
    required int videosClosed,
    required int every,
    required Duration sinceSessionStart,
    required int warmupMinutes,
    required Duration? sinceLastInterstitial,
    required int minGapMinutes,
    required bool underDailyCap,
  }) {
    if (!underDailyCap || every < 1) return false;
    if ((videosClosed + 1) % every != 0) return false;
    if (sinceSessionStart.inSeconds + 60 < warmupMinutes * 60) return false;
    if (sinceLastInterstitial != null && sinceLastInterstitial.inSeconds + 60 < minGapMinutes * 60) return false;
    return true;
  }
}

class AdFunnel {
  AdFunnel._();

  /// [type] : native, banner, interstitial, rewarded ; [event] : request, loaded, failed, shown.
  static void count(String type, String event) => AdRevenueTracker.count('funnel:$type:$event');
}
