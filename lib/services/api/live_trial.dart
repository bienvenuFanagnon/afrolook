/// Essai gratuit d'un live payant, tel que le serveur le chronomètre.
///
/// Forme lue (API, fiche « lot restes » §6) :
/// `trial: { minutes, started_at, ends_at, seconds_left, expired }`
/// - `GET /lives/{id}` → `data.me.trial` ;
/// - `POST /lives/{id}/token` → `data.trial` (réponse 200 pendant l'essai) ;
/// - 402 `entry_required` → `details.trial` (essai fini : `seconds_left` 0, `expired` vrai).
/// Le chrono démarre à la première demande de jeton (`started_at` vaut `null` avant).
/// `trial` vaut `null` pour l'hôte, un intervenant, une personne qui a payé l'entrée, un live gratuit ou sans minutes offertes.
class LiveTrial {
  const LiveTrial({required this.minutes, required this.secondsLeft, required this.expired, this.startedAt, this.endsAt});

  /// Minutes offertes au départ.
  final int minutes;

  /// Secondes restantes selon le serveur (0 quand l'essai est fini).
  final int secondsLeft;
  final bool expired;
  final DateTime? startedAt;
  final DateTime? endsAt;

  /// Lit le bloc `trial` ; renvoie `null` s'il est absent ou illisible (aucun essai à afficher).
  static LiveTrial? fromJson(Object? json) {
    if (json is! Map) return null;
    final minutes = _int(json['minutes']);
    final expired = json['expired'] == true;
    var left = _int(json['seconds_left']);
    if (expired || left < 0) left = 0;
    return LiveTrial(
      minutes: minutes,
      secondsLeft: left,
      expired: expired || (left == 0 && json['started_at'] != null),
      startedAt: _date(json['started_at']),
      endsAt: _date(json['ends_at']),
    );
  }

  /// Cherche l'essai dans une réponse de l'API : `data.me.trial` (détail du live), `data.trial` (jeton) ou `details.trial` (402).
  static LiveTrial? fromLive(Map<String, dynamic> live) {
    final me = live['me'];
    if (me is Map && me.containsKey('trial')) return fromJson(me['trial']);
    return fromJson(live['trial']);
  }

  static int _int(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

  static DateTime? _date(Object? v) => v is String && v.isNotEmpty ? DateTime.tryParse(v) : null;
}
