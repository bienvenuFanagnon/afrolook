import 'dart:async';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:ayet_sdk_v2/ayet_sdk_v2.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tapjoy_offerwall/tapjoy_offerwall.dart';
import '../share/share_service.dart';

/// Mur de tâches (Tapjoy, puis ayeT-Studios en relais) — voir docs/OFFERWALL_TACHES.md.
///
///  - L'utilisateur est identifié auprès de la régie par son identifiant Firebase : c'est ce qui permet au serveur de créditer le bon compte.
///  - Les clés du SDK sont dans assets/env/tapjoy.env (fichier local ignoré par Git, comme functions/.env) : rien à fournir au lancement.
///    Sans ce fichier, la fonction est invisible dans l'application.
///  - Les pièces ne sont créditées que par le serveur (retour signé de la régie) ; l'application ne fait qu'ouvrir le mur et afficher.
class OfferwallService {
  OfferwallService._();

  // Clés du SDK (une par plateforme), lues dans assets/env/tapjoy.env : fichier LOCAL ignoré par Git, comme functions/.env (voir assets/env/README.md).
  // On peut aussi les donner au lancement : --dart-define=TAPJOY_SDK_KEY_ANDROID=… (prioritaire). Sans clé, la fonction est cachée.
  // La clé de REPORTING Tapjoy est un secret du serveur : elle n'a rien à faire dans l'application.
  static String _androidKey = const String.fromEnvironment('TAPJOY_SDK_KEY_ANDROID');
  static String _iosKey = const String.fromEnvironment('TAPJOY_SDK_KEY_IOS');
  static bool _keysLoaded = false;

  // ayeT-Studios : numéro du placement (un par plateforme) et nom de l'emplacement « mur d'offres », lus dans assets/env/ayet.env (même principe).
  static int _ayetAndroidPlacement = int.tryParse(const String.fromEnvironment('AYET_PLACEMENT_ID_ANDROID')) ?? 0;
  static int _ayetIosPlacement = int.tryParse(const String.fromEnvironment('AYET_PLACEMENT_ID_IOS')) ?? 0;
  static String _ayetAdslot = const String.fromEnvironment('AYET_ADSLOT');

  static Future<void> _loadKeys() async {
    if (_keysLoaded) return;
    _keysLoaded = true;
    for (final name in const ['tapjoy', 'ayet']) {
      try {
        final text = await rootBundle.loadString('assets/env/$name.env');
        for (final raw in text.split('\n')) {
          final line = raw.trim();
          if (line.isEmpty || line.startsWith('#')) continue;
          final i = line.indexOf('=');
          if (i <= 0) continue;
          final k = line.substring(0, i).trim();
          final v = line.substring(i + 1).trim();
          if (k == 'TAPJOY_SDK_KEY_ANDROID' && _androidKey.isEmpty) _androidKey = v;
          if (k == 'TAPJOY_SDK_KEY_IOS' && _iosKey.isEmpty) _iosKey = v;
          if (k == 'AYET_PLACEMENT_ID_ANDROID' && _ayetAndroidPlacement == 0) _ayetAndroidPlacement = int.tryParse(v) ?? 0;
          if (k == 'AYET_PLACEMENT_ID_IOS' && _ayetIosPlacement == 0) _ayetIosPlacement = int.tryParse(v) ?? 0;
          if (k == 'AYET_ADSLOT' && _ayetAdslot.isEmpty) _ayetAdslot = v;
        }
      } catch (_) {
        // fichier absent : cette régie reste cachée
      }
    }
  }

  static const String placementName = 'offerwall';
  static const String _kAgeOk = 'offerwall_age_ok_v1';

  static bool get _isIOS => defaultTargetPlatform == TargetPlatform.iOS;
  static bool get _isMobile => !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || _isIOS);
  static String get _sdkKey => _isIOS ? _iosKey : _androidKey;

  /// Les plateformes de tâches (Tapjoy, ayeT) sont en pause : décision du propriétaire du 29/10/2026, « on ne va pas appeler les plateformes en attendant ».
  /// Seule la tâche « Regarder une pub » est proposée. Passer à true quand une plateforme est approuvée (le code des plateformes est intact).
  static const bool partnersActive = false;

  /// La tâche « Regarder une pub » (vidéo récompensée Appodeal) existe seulement sur téléphone.
  static bool get adTaskSupported => _isMobile;

  /// Tapjoy : la clé du SDK de cette plateforme est-elle présente dans cette version de l'application ?
  static bool get tapjoyConfigured => partnersActive && _isMobile && _sdkKey.isNotEmpty;

  static int get _ayetPlacement => _isIOS ? _ayetIosPlacement : _ayetAndroidPlacement;
  static String get _adslotName => _ayetAdslot.isEmpty ? 'offerwall' : _ayetAdslot;

  /// ayeT-Studios : le numéro de placement de cette plateforme est-il présent ?
  static bool get ayetConfigured => partnersActive && _isMobile && _ayetPlacement > 0;

  /// Au moins une régie est utilisable sur cette plateforme.
  static bool get isConfigured => tapjoyConfigured || ayetConfigured;

  // ── Informations du serveur (historique, totaux, réglages) ─────────────────────────────────

  // ── Tâche « Regarder une pub » ──────────────────────────────────────────────────────────────

  /// Étape 1 : le serveur contrôle le compte, le plafond du jour et l'écart entre deux pubs, puis donne un jeton à usage unique.
  static Future<AdTaskTicket> adTaskStart() async {
    try {
      final res = await FirebaseFunctions.instance.httpsCallable('adTaskStart').call(<String, dynamic>{});
      final m = Map<String, dynamic>.from(res.data as Map);
      return AdTaskTicket(nonce: '${m['nonce']}', remaining: (m['remaining'] as num?)?.toInt() ?? 0, hundredths: (m['hundredths'] as num?)?.toInt() ?? 0);
    } on FirebaseFunctionsException catch (e) {
      final d = e.details is Map ? Map<String, dynamic>.from(e.details as Map) : const <String, dynamic>{};
      if (e.code == 'resource-exhausted') throw AdTaskRefused(d['reason'] == 'trop_tot' ? AdTaskRefusal.tooSoon : AdTaskRefusal.dayLimit, (d['waitSec'] as num?)?.toInt() ?? 0);
      throw AdTaskRefused(AdTaskRefusal.unavailable, 0);
    }
  }

  /// Étape 2 : la pub a été regardée en entier ; le serveur vérifie le jeton et la durée, puis crédite les pièces tout de suite. Retourne les pièces ajoutées.
  /// Pièces créditées tout de suite, centièmes gardés en réserve pour la prochaine pub, et valeur de cette pub en centièmes de pièce (ex. 164 = 1,64 pièce).
  static Future<({int coins, int carry, int value})> adTaskClaim(String nonce) async {
    final res = await FirebaseFunctions.instance.httpsCallable('adTaskClaim').call(<String, dynamic>{'nonce': nonce});
    final m = Map<String, dynamic>.from(res.data as Map);
    _cacheAt = null; // l'historique et les totaux sont à recharger
    return (coins: (m['credited'] as num?)?.toInt() ?? 0, carry: (m['carry'] as num?)?.toInt() ?? 0, value: (m['hundredths'] as num?)?.toInt() ?? 0);
  }

  static OfferwallInfo? _cache;
  static DateTime? _cacheAt;

  /// Historique et réglages de l'utilisateur connecté (fonction offerwallMyHistory). Mis en cache 5 minutes.
  static Future<OfferwallInfo> loadInfo({bool force = false}) async {
    await _loadKeys();
    final t = _cacheAt;
    if (!force && _cache != null && t != null && DateTime.now().difference(t) < const Duration(minutes: 5)) return _cache!;
    final res = await FirebaseFunctions.instance.httpsCallable('offerwallMyHistory').call(<String, dynamic>{});
    final info = OfferwallInfo.fromMap(Map<String, dynamic>.from(res.data as Map), iOS: _isIOS);
    _cache = info;
    _cacheAt = DateTime.now();
    return info;
  }

  /// Faut-il montrer l'entrée « Gagne des pièces » ? (clé du SDK présente, interrupteurs du serveur, compte non suspendu). Ne lève jamais d'erreur.
  static Future<bool> isAvailable() async {
    await _loadKeys();
    if (await _tasksAvailable()) return true;
    // « Partage et gagne » : le travail principal d'Afrolook, ouvert même quand aucune plateforme de tâches n'est active
    return ShareService.isEnabled();
  }

  static Future<bool> _tasksAvailable() async {
    if (!isConfigured && !adTaskSupported) return false;
    try {
      final i = await loadInfo();
      return i.availableHere && !i.blocked && (isConfigured || i.adEnabled);
    } catch (_) {
      return false;
    }
  }

  // ── Confirmation d'âge (18 ans ou plus), gardée sur l'appareil ────────────────────────────

  static Future<bool> ageConfirmed() async {
    try {
      return (await SharedPreferences.getInstance()).getBool(_kAgeOk) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> confirmAge() async {
    try {
      await (await SharedPreferences.getInstance()).setBool(_kAgeOk, true);
    } catch (_) {}
  }

  // ── SDK Tapjoy ────────────────────────────────────────────────────────────────────────

  static String? _connectedUid;
  static Future<bool>? _connecting;

  /// Connecte le SDK pour cet utilisateur (une seule fois par compte). Retourne false si la connexion échoue.
  static Future<bool> _ensureConnected(String uid) {
    if (_connectedUid == uid) return Future.value(true);
    return _connecting ??= _connect(uid).whenComplete(() => _connecting = null);
  }

  static Future<bool> _connect(String uid) async {
    if (!tapjoyConfigured) return false;
    try {
      // iPhone : consentement de suivi (ATT) demandé avant la connexion, comme pour les pubs
      if (_isIOS && await AppTrackingTransparency.trackingAuthorizationStatus == TrackingStatus.notDetermined) {
        await AppTrackingTransparency.requestTrackingAuthorization();
      }
      // en développement : journal détaillé du SDK (identifiant publicitaire reconnu ?, offres reçues ?) ; jamais en production
      if (kDebugMode) await Tapjoy.setDebugEnabled(true);
      final done = Completer<bool>();
      await Tapjoy.connect(
        sdkKey: _sdkKey,
        options: {TapjoyConnectFlags.user_id: uid},
        onConnectSuccess: () { if (!done.isCompleted) done.complete(true); },
        onConnectFailure: (int code, String? error) { debugPrint('Tapjoy connexion refusée ($code) : $error'); if (!done.isCompleted) done.complete(false); },
        onConnectWarning: (int code, String? warning) { debugPrint('Tapjoy avertissement ($code) : $warning'); },
      );
      final ok = await done.future.timeout(const Duration(seconds: 20), onTimeout: () => false);
      if (!ok) return false;
      // la personne a confirmé avoir 18 ans ou plus avant d'arriver ici
      await Tapjoy.getPrivacyPolicy().setBelowConsentAge(TJStatus.falseStatus);
      // le plugin appelle ces deux rappels sans vérifier qu'ils existent : sans eux, erreur « Null check » dans le journal
      await Tapjoy.setUserID(
        userId: uid,
        onSetUserIDSuccess: () {},
        onSetUserIDFailure: (String? e) => debugPrint('Tapjoy : identifiant refusé $e'),
      );
      _connectedUid = uid;
      return true;
    } catch (e) {
      debugPrint('Tapjoy : erreur de connexion $e');
      return false;
    }
  }

  /// Lance TOUT DE SUITE la vérification de Tapjoy (connexion, demande de contenu) sans rien afficher : la page l'appelle au toucher de « Voir les tâches »,
  /// pendant que la pub plein écran s'affiche ; à la fermeture de la pub, [open] n'a plus qu'à ouvrir la bonne page.
  /// (ayeT ne permet pas de vérifier ses offres à l'avance : son SDK affiche directement son propre écran.)
  static TapjoyPrefetch? prefetchTapjoy(String uid) {
    if (uid.isEmpty) return null;
    final p = TapjoyPrefetch();
    () async {
      try {
        await _loadKeys();
        if (!tapjoyConfigured || !await _ensureConnected(uid)) {
          p._finish(false, failed: true);
          return;
        }
        final placement = await Tapjoy.getPlacement(
          placementName: placementName,
          onRequestSuccess: (_) => debugPrint('Tapjoy : demande de contenu reçue (le contenu est prêt s\'il y en a)'),
          onRequestFailure: (_, error) {
            debugPrint('Tapjoy placement refusé : $error');
            p._finish(false, failed: true);
          },
          onContentReady: (pl) {
            p.placement = pl;
            p._finish(true);
          },
          onContentDismiss: (_) { _cacheAt = null; }, // au retour, les totaux sont relus
        );
        if (placement == null) {
          p._finish(false, failed: true);
          return;
        }
        await placement.requestContent();
      } catch (e) {
        debugPrint('Tapjoy : erreur de vérification $e');
        p._finish(false, failed: true);
      }
    }();
    return p;
  }

  /// Ouvre le mur de tâches : Tapjoy d'abord ; s'il n'a aucune offre (ou échoue), ayeT-Studios prend le relais pour ne jamais manquer de tâches.
  /// [prefetched] : vérification de Tapjoy déjà lancée par [prefetchTapjoy] (sinon elle est lancée ici).
  /// Résultat : ouvert, indisponible (aucune offre nulle part), ou erreur.
  static Future<OfferwallOpenResult> open(String uid, {TapjoyPrefetch? prefetched}) async {
    await _loadKeys();
    if (uid.isEmpty || !isConfigured) return OfferwallOpenResult.unavailable;
    var r = OfferwallOpenResult.unavailable;
    if (tapjoyConfigured) r = await _showTapjoy(prefetched ?? prefetchTapjoy(uid));
    if (r != OfferwallOpenResult.opened && ayetConfigured) {
      final a = await openAyet(uid);
      if (a == OfferwallOpenResult.opened) r = a;
    }
    return r;
  }

  /// Attend (20 s au plus) le résultat de la vérification de Tapjoy, puis affiche son mur s'il a du contenu.
  static Future<OfferwallOpenResult> _showTapjoy(TapjoyPrefetch? p) async {
    if (p == null) return OfferwallOpenResult.unavailable;
    final ready = await p.ready.timeout(const Duration(seconds: 20), onTimeout: () => false);
    final placement = p.placement;
    if (!ready || placement == null) return p.failed ? OfferwallOpenResult.error : OfferwallOpenResult.unavailable;
    try {
      await placement.showContent();
      return OfferwallOpenResult.opened;
    } catch (e) {
      debugPrint('Tapjoy : erreur à l\'ouverture $e');
      return OfferwallOpenResult.error;
    }
  }

  // ── ayeT-Studios ─────────────────────────────────────────────────────────────────────────

  static final AyetSdkV2 _ayet = AyetSdkV2();
  static String? _ayetUid;

  /// Ouvre le mur d'offres d'ayeT-Studios (le SDK affiche son propre écran ; il ne dit pas s'il a des offres).
  static Future<OfferwallOpenResult> openAyet(String uid) async {
    await _loadKeys();
    if (uid.isEmpty || !ayetConfigured) return OfferwallOpenResult.unavailable;
    try {
      if (_isIOS && await AppTrackingTransparency.trackingAuthorizationStatus == TrackingStatus.notDetermined) {
        await AppTrackingTransparency.requestTrackingAuthorization();
      }
      if (_ayetUid != uid) {
        await _ayet.init(placementId: _ayetPlacement, externalIdentifier: uid); // l'identifiant Firebase : c'est lui que le serveur reçoit pour créditer
        _ayetUid = uid;
      }
      await _ayet.showOfferwall(_adslotName);
      _cacheAt = null; // au retour, les totaux sont relus
      return OfferwallOpenResult.opened;
    } catch (e) {
      debugPrint('ayeT : erreur à l\'ouverture $e');
      return OfferwallOpenResult.error;
    }
  }
}

/// Vérification de Tapjoy en cours (voir [OfferwallService.prefetchTapjoy]).
class TapjoyPrefetch {
  final Completer<bool> _ready = Completer<bool>();
  TJPlacement? placement;
  bool failed = false;

  /// true quand Tapjoy a du contenu prêt à afficher ; false s'il n'en a pas ou en cas d'échec.
  Future<bool> get ready => _ready.future;

  void _finish(bool ok, {bool failed = false}) {
    if (failed) this.failed = true;
    if (!_ready.isCompleted) _ready.complete(ok);
  }
}

enum OfferwallOpenResult { opened, unavailable, error }

/// Une tâche de l'historique de l'utilisateur.
class OfferwallEntry {
  OfferwallEntry({required this.id, required this.status, required this.coins, required this.createdAt, required this.releaseAt, this.provider = '', this.platform = ''});
  final String id;
  final String status; // pending, validee, en_revue, refusee, refusee_admin, expiree
  final int coins;
  final int createdAt;
  final int releaseAt;
  /// D'où vient le gain : `whatsapp_partage` (+ plateforme whatsapp, telegram, facebook, tiktok, other) pour le partage, sinon une tâche d'un partenaire.
  final String provider;
  final String platform;
}

/// Jeton de départ d'une pub : à renvoyer au serveur quand elle a été regardée en entier.
class AdTaskTicket {
  AdTaskTicket({required this.nonce, required this.remaining, required this.hundredths});
  final String nonce;
  final int remaining;
  final int hundredths;
}

enum AdTaskRefusal { dayLimit, tooSoon, unavailable }

/// Départ refusé par le serveur : limite du jour, trop tôt après la pub précédente, ou compte / tâche indisponible.
class AdTaskRefused implements Exception {
  AdTaskRefused(this.reason, this.waitSec);
  final AdTaskRefusal reason;
  final int waitSec;
}

class OfferwallInfo {
  OfferwallInfo({
    required this.events, required this.earned, required this.pending, required this.blocked, required this.availableHere, required this.holdHours,
    required this.dailyCapCoins, required this.sponsorPct,
    this.adEnabled = false, this.adMaxPerDay = 10, this.adDoneToday = 0, this.adHundredths = 0,
  });

  /// Tâche « Regarder une pub » : activée, plafond du jour, pubs déjà regardées aujourd'hui, valeur d'une pub en centièmes de pièce.
  final bool adEnabled;
  final int adMaxPerDay;
  final int adDoneToday;
  final int adHundredths;

  final List<OfferwallEntry> events;
  final int earned;
  final int pending;
  final bool blocked;
  /// Interrupteurs du serveur : général + plateforme de cet appareil.
  final bool availableHere;
  final int holdHours;
  final int dailyCapCoins;
  final int sponsorPct;

  /// Total gagné grâce aux tâches : pièces validées + pièces en attente.
  int get total => earned + pending;

  factory OfferwallInfo.fromMap(Map<String, dynamic> m, {required bool iOS}) {
    final cfg = Map<String, dynamic>.from((m['config'] as Map?) ?? {});
    int i(dynamic v, int d) => v is num ? v.toInt() : d;
    final enabled = cfg['enabled'] != false && (iOS ? cfg['iosEnabled'] != false : cfg['androidEnabled'] != false);
    return OfferwallInfo(
      events: [
        for (final e in (m['events'] as List? ?? const []))
          OfferwallEntry(
            id: '${(e as Map)['id']}', status: '${e['status']}', coins: i(e['coins'], 0), createdAt: i(e['createdAt'], 0), releaseAt: i(e['releaseAt'], 0),
            provider: '${e['provider'] ?? ''}', platform: '${e['platform'] ?? ''}',
          ),
      ],
      earned: i(m['earned'], 0),
      pending: i(m['pending'], 0),
      blocked: m['blocked'] == true,
      availableHere: enabled,
      holdHours: i(cfg['holdHours'], 48),
      dailyCapCoins: i(cfg['dailyCapCoins'], 2000),
      sponsorPct: i(cfg['sponsorPct'], 20),
      adEnabled: ((m['adTask'] as Map?)?['enabled']) == true,
      adMaxPerDay: i((m['adTask'] as Map?)?['maxPerDay'], 10),
      adDoneToday: i((m['adTask'] as Map?)?['doneToday'], 0),
      adHundredths: i((m['adTask'] as Map?)?['hundredths'], 0),
    );
  }
}
