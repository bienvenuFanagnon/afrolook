/// Billet de live : quand les minutes gratuites d'Agora du mois sont épuisées, chaque spectateur prend un billet de 15 minutes
/// (le serveur compte les minutes ; Afrolook ne paie jamais au-delà du gratuit). Formes lues :
/// - `POST /lives/{id}/token` → `data.ticket: { by, kind, ends_at }` (`by` : ticket, offered, trial, grace) ; `null` tant que le gratuit dure ;
/// - 402 `ticket_required` → `details: { coins, minutes, tier, audio_coins, trial }` ;
/// - `GET /lives/{id}` → `data.me.ticket: { mode, coins, minutes, tier, audio_coins, covered_by, kind, ends_at }` ;
/// - `GET /lives/{id}` (hôte) → `data.me.host_fee: { coins, paid_until }`.
class LiveTicket {
  const LiveTicket({this.by, this.kind, this.endsAt});

  /// Ce qui couvre la personne : `ticket` (payé), `offered` (offert par l'hôte), `trial` (essai), `grace` (passe pris pendant le gratuit).
  final String? by;

  /// `video`, `stage`, `audio` (son seul), `offered` ou `free`.
  final String? kind;
  final DateTime? endsAt;

  /// Le spectateur a pris un billet « son seul » : la vidéo reçue est coupée.
  bool get audioOnly => kind == 'audio';

  /// Secondes restantes selon l'heure du téléphone (le serveur fait foi : le jeton expire à `endsAt`).
  int get secondsLeft {
    final e = endsAt;
    if (e == null) return 1 << 30;
    final s = e.difference(DateTime.now()).inSeconds;
    return s < 0 ? 0 : s;
  }

  /// Lit `data.ticket` de la réponse du jeton ; `null` quand il n'y a rien à compter (gratuit, hôte, intervenant).
  static LiveTicket? fromToken(Object? json) {
    if (json is! Map) return null;
    final ends = json['ends_at'];
    return LiveTicket(
      by: json['by'] as String?,
      kind: json['kind'] as String?,
      endsAt: ends is String && ends.isNotEmpty ? DateTime.tryParse(ends)?.toLocal() : null,
    );
  }
}

/// Ce qu'il faut payer pour continuer (402 `ticket_required`).
class LiveTicketOffer {
  const LiveTicketOffer({required this.coins, required this.minutes, required this.audioCoins, this.tier = 'video'});

  /// Prix du billet vidéo (pièces) pour [minutes] minutes.
  final int coins;
  final int minutes;

  /// Prix du billet « son seul » (pièces).
  final int audioCoins;

  /// `video`, `stage` (invités en vidéo) ou `audio` (salon audio).
  final String tier;

  bool get isAudioRoom => tier == 'audio';

  static LiveTicketOffer? fromDetails(Map<String, dynamic> d) {
    final coins = _int(d['coins']);
    if (coins <= 0) return null;
    return LiveTicketOffer(coins: coins, minutes: _int(d['minutes'], 15), audioCoins: _int(d['audio_coins'], 13), tier: '${d['tier'] ?? 'video'}');
  }

  /// Lit `data.me.ticket` d'une fiche de live (prix affichés avant d'entrer) ; `null` si le gratuit dure encore.
  static LiveTicketOffer? fromLive(Map<String, dynamic> live) {
    final me = live['me'];
    final t = me is Map ? me['ticket'] : null;
    if (t is! Map || t['mode'] != 'ticket') return null;
    return fromDetails(Map<String, dynamic>.from(t));
  }

  static int _int(Object? v, [int fallback = 0]) => v is num ? v.toInt() : int.tryParse('$v') ?? fallback;
}

/// Frais de diffusion de l'hôte (mode billet) : payés par tranches de 15 minutes, le live s'arrête sinon.
class LiveHostFee {
  const LiveHostFee({required this.coins, this.paidUntil});

  final int coins;
  final DateTime? paidUntil;

  int get secondsLeft {
    final e = paidUntil;
    if (e == null) return 0;
    final s = e.difference(DateTime.now()).inSeconds;
    return s < 0 ? 0 : s;
  }

  /// Lit `host_fee` (réponse du signal de l'hôte ou `data.me.host_fee`) ; `null` quand le live est gratuit.
  static LiveHostFee? fromJson(Object? json) {
    if (json is! Map) return null;
    final until = json['paid_until'];
    final coins = json['coins'];
    return LiveHostFee(
      coins: coins is num ? coins.toInt() : int.tryParse('$coins') ?? 0,
      paidUntil: until is String && until.isNotEmpty ? DateTime.tryParse(until)?.toLocal() : null,
    );
  }
}
