import 'package:cloud_functions/cloud_functions.dart';

/// « Partage et gagne » : missions de partage d'annonces (WhatsApp, Telegram, Facebook, TikTok…) payées au clic valide.
/// Tout est décidé par le serveur (profil validé, campagnes ouvertes, lien personnel, gains) : l'application affiche et ouvre le partage.
class ShareService {
  ShareService._();

  static final FirebaseFunctions _fn = FirebaseFunctions.instanceFor(region: 'us-central1');

  static Future<Map<String, dynamic>> _call(String name, [Map<String, dynamic>? data]) async {
    final res = await _fn.httpsCallable(name).call(data ?? <String, dynamic>{});
    return Map<String, dynamic>.from(res.data as Map);
  }

  /// Derniers gains annoncés par le serveur (utilisés dans les cartes d'entrée, avant d'ouvrir la page).
  static double lastPerClickFcfa = 5;
  static double lastDailyCapFcfa = 500;
  static Future<bool>? _enabled;
  static int _enabledAt = 0;

  /// Fonction disponible ? (interrupteur général côté serveur). Gardé 5 minutes : plusieurs écrans la demandent. Ne lève jamais d'erreur.
  static Future<bool> isEnabled() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_enabled == null || now - _enabledAt > 300000) {
      _enabledAt = now;
      _enabled = () async {
        try {
          final r = await _call('adsShareList');
          if (r['enabled'] != true) return false;
          final p = (r['perClickFcfa'] as num?)?.toDouble(), d = (r['dailyCapFcfa'] as num?)?.toDouble();
          if (p != null && p > 0) lastPerClickFcfa = p;
          if (d != null && d > 0) lastDailyCapFcfa = d;
          return true;
        } catch (_) {
          _enabledAt = 0; // réessayer au prochain affichage
          return false;
        }
      }();
    }
    return _enabled!;
  }

  /// Les informations de la page, ou l'aperçu de départ si le service n'est pas joignable.
  static Future<ShareHome> homeOrPreview() async {
    try {
      return await load();
    } catch (_) {
      return ShareHome.preview();
    }
  }

  static Future<ShareHome> load() async {
    final r = await Future.wait([_call('adsShareList'), _call('adsShareProfileMe')]);
    return ShareHome.fromJson(r[0], r[1]);
  }

  /// Envoie le profil ; retourne son état (`pending` ou `active`).
  static Future<String> saveProfile(Map<String, dynamic> data) async => '${(await _call('adsShareProfileSave', data))['status']}';

  static Future<ShareLink> createLink(String campaignId, String channel, String lang) async {
    final r = await _call('adsShareCreate', {'campaignId': campaignId, 'channel': channel, 'lang': lang});
    return ShareLink(url: '${r['url']}', caption: '${r['caption']}', video: r['video'] == true, mediaUrl: '${r['mediaUrl']}', image: '${r['image']}');
  }

  /// Le partageur déclare combien de personnes ont vu sa publication. Retourne `{counted, proven, plausible}`.
  static Future<Map<String, dynamic>> reportViews(String campaignId, int views) => _call('adsShareReport', {'campaignId': campaignId, 'views': views});

  /// Message simple et traduit pour une erreur d'envoi du profil : jamais le texte brut de l'erreur ni sa trace.
  static String profileError(Object e, String Function(String) tr) {
    final m = (e is FirebaseFunctionsException ? '${e.message}' : '').toLowerCase();
    if (m.contains('whatsapp')) return tr('Ton numéro WhatsApp n\'est pas valide. Écris-le avec l\'indicatif du pays, par exemple +22890123456.');
    if (m.contains('pays')) return tr('Le pays s\'écrit avec 2 lettres, par exemple TG pour le Togo.');
    if (m.contains('audience du statut')) return tr('Vérifie le nombre de personnes qui voient ton statut.');
    if (m.contains('groupe')) return tr('Chaque groupe doit avoir un nom et entre 1 et 1 024 membres.');
    if (m.contains('audience trop faible')) return tr('Ton audience doit compter au moins 20 personnes (statut, canal, groupes).');
    if (m.contains('présente ton audience')) return tr('Présente ton audience en 20 caractères au moins : qui sont-ils, que partages-tu d\'habitude ?');
    if (m.contains('règles')) return tr('Accepte d\'abord les règles.');
    return tr('Impossible d\'envoyer ton profil pour le moment.');
  }

  /// Message simple pour une erreur du serveur.
  static String explain(Object e, String Function(String) tr) {
    final m = e is FirebaseFunctionsException ? '${e.message}' : '$e';
    if (m.contains('profil_a_valider')) return tr('Ton profil n\'est pas encore validé.');
    if (m.contains('regles_a_accepter')) return tr('Accepte d\'abord les règles.');
    if (m.contains('campagne_complete')) return tr('Cette annonce a déjà assez de partageurs. Essaie une autre.');
    if (m.contains('limite_du_jour')) return tr('Tu as atteint la limite de partages pour aujourd\'hui.');
    if (m.contains('campagne_indisponible') || m.contains('indisponible')) return tr('Cette annonce n\'est plus disponible.');
    if (m.contains('compte')) return tr('Ton compte ne peut pas faire cette mission pour le moment.');
    return tr('Impossible pour le moment. Réessaie plus tard.');
  }
}

class ShareMission {
  ShareMission(this.json);
  final Map<String, dynamic> json;
  String get id => '${json['campaignId']}';
  String get brand => '${json['brand'] ?? ''}';
  String get title => '${json['title'] ?? ''}';
  String get text => '${json['text'] ?? ''}';
  String get image => '${json['image'] ?? ''}';
  bool get video => json['video'] == true;
  bool get joined => json['joined'] == true;
  double get coinsPerClick => (json['coinsPerClick'] as num?)?.toDouble() ?? 0;
  /// Gain par clic valide en FCFA (2,5 pièces = 1 F).
  double get fcfaPerClick => coinsPerClick / 2.5;

  /// Résultats du partageur sur cette mission (null s'il n'a pas encore partagé) : ouvertures du lien, clics valides, vues déclarées, publication prouvée.
  Map<String, dynamic>? get results => json['results'] is Map ? Map<String, dynamic>.from(json['results'] as Map) : null;
}

class ShareProfile {
  ShareProfile(this.json);
  final Map<String, dynamic> json;
  String get status => '${json['status']}';
  String get reason => '${json['reason'] ?? ''}';
  int get declared => (json['declared'] as num?)?.toInt() ?? 0;
  int get retained => (json['retained'] as num?)?.toInt() ?? 0;
}

class ShareLink {
  ShareLink({required this.url, required this.caption, required this.video, required this.mediaUrl, required this.image});
  final String url;
  final String caption;
  final bool video;
  final String mediaUrl;
  final String image;
}

class ShareHome {
  ShareHome({
    required this.enabled, required this.status, required this.perClickFcfa, required this.coinsPerClick, required this.dailyCapFcfa, required this.holdHours,
    required this.sponsorPct, required this.expectedCtr, required this.retained, required this.todayFcfa, required this.pendingFcfa, required this.paidCoins,
    required this.validClicks, required this.missions, required this.profile, required this.rulesVersion, required this.rules,
  });

  factory ShareHome.fromJson(Map<String, dynamic> list, Map<String, dynamic> prof) {
    final me = Map<String, dynamic>.from((list['me'] ?? const {}) as Map);
    num n(Object? v) => v is num ? v : 0;
    final p = prof['profile'];
    final rules = Map<String, dynamic>.from((prof['rules'] ?? const {}) as Map);
    return ShareHome(
      enabled: list['enabled'] == true,
      status: '${list['profileStatus'] ?? (p is Map ? p['status'] : 'none')}',
      perClickFcfa: n(list['perClickFcfa']).toDouble(),
      coinsPerClick: n(list['coinsPerClick']).toDouble(),
      dailyCapFcfa: n(list['dailyCapFcfa']).toDouble(),
      holdHours: n(list['holdHours']).toInt(),
      sponsorPct: n(list['sponsorPct']).toInt(),
      expectedCtr: n(list['expectedCtr']).toDouble(),
      retained: n(list['retainedAudience']).toInt(),
      todayFcfa: n(me['todayFcfa']).toDouble(),
      pendingFcfa: n(me['pendingFcfa']).toDouble(),
      paidCoins: n(me['paidCoins']).toInt(),
      validClicks: n(me['validClicks']).toInt(),
      missions: ((list['items'] ?? const []) as List).map((e) => ShareMission(Map<String, dynamic>.from(e as Map))).toList(),
      profile: p is Map ? ShareProfile(Map<String, dynamic>.from(p)) : null,
      rulesVersion: '${rules['version'] ?? ''}',
      rules: ((rules['text'] ?? const []) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList(),
    );
  }

  /// Aperçu des informations quand le service n'est pas (encore) joignable : valeurs de départ du pilote, à titre d'estimation.
  factory ShareHome.preview() => ShareHome(
        enabled: false, status: 'none', perClickFcfa: 5, coinsPerClick: 12.5, dailyCapFcfa: 500, holdHours: 72, sponsorPct: 10, expectedCtr: 0.02, retained: 0,
        todayFcfa: 0, pendingFcfa: 0, paidCoins: 0, validClicks: 0, missions: const [], profile: null, rulesVersion: '', rules: const [],
      );

  final bool enabled;
  final String status; // none, pending, active, refused, suspended
  final double perClickFcfa;
  final double coinsPerClick;
  final double dailyCapFcfa;
  final int holdHours;
  final int sponsorPct;
  final double expectedCtr;
  final int retained;
  final double todayFcfa;
  final double pendingFcfa;
  final int paidCoins;
  final int validClicks;
  final List<ShareMission> missions;
  final ShareProfile? profile;
  final String rulesVersion;
  final List<Map<String, dynamic>> rules;

  /// Clics valides maximum par jour (plafond de gains ÷ gain par clic).
  int get maxClicksPerDay => perClickFcfa > 0 ? (dailyCapFcfa / perClickFcfa).floor() : 0;
}
