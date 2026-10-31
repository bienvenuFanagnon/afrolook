import 'package:afrolook_api_client/afrolook_api_client.dart';

import '../api/api_gateway.dart';
import '../api/wallet_api.dart';

/// « Partage et gagne » : missions de partage d'annonces (WhatsApp, Telegram, Facebook, TikTok…) payées au clic valide.
/// Tout est décidé par l'API (profil validé, campagnes ouvertes, lien personnel, gains) : l'application affiche et ouvre le partage.
class ShareService {
  ShareService._();

  static ApiClient get _c => ApiGateway.instance.client;

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
          final r = WalletApi.map(await _c.get('/share/profile'));
          if (r['enabled'] != true) return false;
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
    final r = await Future.wait<dynamic>([_c.get('/share/missions'), _c.get('/share/profile'), _c.get('/share/earnings').catchError((_) => <String, dynamic>{} as dynamic)]);
    final missions = r[0] is Map ? Map<String, dynamic>.from(r[0] as Map) : <String, dynamic>{};
    final prof = WalletApi.map(r[1]);
    final earn = WalletApi.map(r[2]);
    // Missions : noms de champs de l'ancien écran
    final items = [
      for (final m in WalletApi.list(missions))
        {
          'campaignId': m['id'],
          'title': m['title'],
          'text': m['text'],
          'image': m['media_url'],
          'video': '${m['media_url'] ?? ''}'.toLowerCase().endsWith('.mp4'),
          'coinsPerClick': m['gain_coins_per_click'],
          'joined': m['joined'] == true,
          'results': m['results'],
        },
    ];
    final coins = items.isEmpty ? 0.0 : ((items.first['coinsPerClick'] as num?)?.toDouble() ?? 0);
    if (coins > 0) lastPerClickFcfa = coins / 2.5;
    final p = prof['profile'];
    final status = p is Map ? ({'approved': 'active', 'rejected': 'refused'}[p['status']] ?? '${p['status']}') : 'none';
    final out = ShareHome.fromJson({
      'enabled': missions['enabled'] == true || prof['enabled'] == true,
      'profileStatus': status,
      'perClickFcfa': lastPerClickFcfa,
      'coinsPerClick': coins,
      'dailyCapFcfa': lastDailyCapFcfa,
      'items': items,
      'me': {
        'pendingFcfa': ((earn['held_coins'] as num?) ?? 0) / 2.5,
        'paidCoins': earn['released_coins'] ?? 0,
        'validClicks': earn['valid_clicks'] ?? 0,
      },
    }, {
      'profile': p is Map ? {...Map<String, dynamic>.from(p), 'status': status, 'reason': p['reject_reason'] ?? p['reason'], 'retained': p['retained_audience'], 'declared': p['declared_audience']} : null,
      'rules': {'version': prof['rules_version'], 'text': const []},
    });
    return out;
  }

  /// Envoie le profil ; retourne son état (`pending` ou `active`).
  static Future<String> saveProfile(Map<String, dynamic> data) async {
    final r = WalletApi.map(await _c.put('/share/profile', body: {
      'whatsapp': data['whatsapp'],
      'country': data['country'],
      if ('${data['city'] ?? ''}'.isNotEmpty) 'city': data['city'],
      'status_audience': data['statusAudience'],
      'telegram_audience': data['telegramAudience'],
      'other_audience': data['otherAudience'],
      'groups': data['groups'],
      'about': data['about'],
      'accept_terms': data['acceptTerms'],
      'rules_version': data['rulesVersion'],
    }));
    return r['status'] == 'approved' ? 'active' : '${r['status']}';
  }

  static Future<ShareLink> createLink(String campaignId, String channel, String lang) async {
    final r = WalletApi.map(await _c.post('/share/links', body: {'campaign_id': campaignId, 'channel': channel}));
    final media = '${r['media_url'] ?? ''}';
    return ShareLink(url: '${r['url']}', caption: '${r['caption']}', video: media.toLowerCase().endsWith('.mp4'), mediaUrl: media, image: media);
  }

  /// Le partageur déclare combien de personnes ont vu sa publication. Point d'accès prévu : POST /share/report (absent pour l'instant,
  /// voir lacunes_api_argent_creations.md). Retourne `{counted, proven, plausible}`.
  static Future<Map<String, dynamic>> reportViews(String campaignId, int views) async =>
      WalletApi.map(await _c.post('/share/report', body: {'campaign_id': campaignId, 'views': views}));

  /// Message clair quand le compte lui-même est refusé.
  static String? accountReason(String m, String Function(String) tr) {
    if (m.contains('trop récent')) return tr('Ton compte est encore trop récent pour faire des missions. Réessaie dans quelques jours.');
    if (m.contains('e-mail non vérifié')) return tr('Vérifie ton adresse e-mail pour continuer.');
    if (m.contains('suspendu')) return tr('Ton compte est suspendu des tâches. Contacte-nous pour en savoir plus.');
    if (m.contains('suppression')) return tr('Ton compte est en cours de suppression.');
    return null;
  }

  /// Message simple et traduit pour une erreur d'envoi du profil : jamais le texte brut de l'erreur ni sa trace.
  static String profileError(Object e, String Function(String) tr) {
    final code = e is ApiException ? e.code : '';
    final m = (e is ApiException ? e.message : '').toLowerCase();
    if (code == 'rules_outdated') return tr('Les règles ont changé : relis-les et accepte la version actuelle.');
    if (code == 'audience_too_small' || m.contains('audience trop faible')) return tr('Ton audience doit compter au moins 20 personnes (statut, canal, groupes).');
    if (m.contains('whatsapp')) return tr('Ton numéro WhatsApp n\'est pas valide. Écris-le avec l\'indicatif du pays, par exemple +22890123456.');
    if (m.contains('pays') || m.contains('country')) return tr('Le pays s\'écrit avec 2 lettres, par exemple TG pour le Togo.');
    if (m.contains('groupe')) return tr('Chaque groupe doit avoir un nom et entre 1 et 1 024 membres.');
    if (m.contains('about') || m.contains('présente ton audience')) return tr('Présente ton audience en 20 caractères au moins : qui sont-ils, que partages-tu d\'habitude ?');
    return accountReason(m, tr) ?? tr('Impossible d\'envoyer ton profil pour le moment.');
  }

  /// Message simple pour une erreur de l'API.
  static String explain(Object e, String Function(String) tr) {
    final code = e is ApiException ? e.code : '';
    final m = e is ApiException ? e.message : '$e';
    switch (code) {
      case 'profile_not_approved':
        return tr('Ton profil n\'est pas encore validé.');
      case 'campaign_closed':
        return tr('Cette annonce n\'est plus disponible.');
      case 'link_limit':
        return tr('Tu as atteint la limite de partages pour aujourd\'hui.');
      case 'disabled':
        return tr('Partage et gagne n\'est pas encore ouvert.');
    }
    if (m.contains('compte')) return accountReason(m, tr) ?? tr('Ton compte ne peut pas faire cette mission pour le moment.');
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
