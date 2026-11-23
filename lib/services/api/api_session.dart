import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:afrolook_api_client/afrolook_api_client.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../pages/UserServices/deviceService.dart';
import 'api_gateway.dart';

/// Session Afrolook (23/11/2026, décision du propriétaire) : la personne reste connectée à l'API même quand Firebase perd sa session
/// sur le téléphone (constat : des milliers de requêtes par jour partaient sans jeton, toutes les pages affichaient « Connexion requise »
/// et il fallait se déconnecter puis se reconnecter).
///
/// - Ouverte toute seule dès que Firebase a une session (`POST /auth/session`), rangée dans le coffre du téléphone (Keystore / Keychain).
/// - L'API reçoit le jeton Firebase quand il marche ; sinon cette session (voir `ApiGateway.client`).
/// - Firebase sans session : reconnexion SILENCIEUSE avec un jeton fourni par l'API (`POST /auth/firebase-token`) ; rien n'est demandé à la personne.
/// - Valable tant que l'application sert au moins une fois tous les 90 jours ; fermée à la déconnexion.
/// - Téléphones seulement (le site garde la session Firebase du navigateur).
class ApiSession {
  ApiSession._();

  static const _key = 'afrolook_api_session_v1';
  static const _store = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
  );

  static String? _token;
  static String? _uid;
  static bool _loaded = false;
  static Future<void>? _loading;
  static Future<void>? _opening;
  static Future<bool>? _restoring;
  static DateTime _nextOpen = DateTime.fromMillisecondsSinceEpoch(0);
  static DateTime _nextRestore = DateTime.fromMillisecondsSinceEpoch(0);
  static bool _lossReported = false;
  static StreamSubscription<User?>? _sub;

  static bool get supported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// Vrai si une session Afrolook est enregistrée sur ce téléphone (après [load]).
  static bool get active => _token != null;

  /// Uid Firebase du compte de la session (sert tant que Firebase n'a pas retrouvé sa session).
  static String? get firebaseUid => _token == null ? null : _uid;

  /// Lecture du coffre (une seule fois). À appeler au démarrage, avant les premières requêtes.
  static Future<void> load() {
    if (_loaded || !supported) {
      _loaded = true;
      return Future.value();
    }
    return _loading ??= () async {
      try {
        final raw = await _store.read(key: _key);
        if (raw != null && raw.isNotEmpty) {
          final m = jsonDecode(raw) as Map;
          _token = m['t'] as String?;
          _uid = m['u'] as String?;
        }
      } catch (_) {
        _token = null;
      }
      _loaded = true;
    }();
  }

  static Future<String?> token() async {
    await load();
    return _token;
  }

  /// Démarrage : lit le coffre, ouvre la session dès que Firebase en a une, et répare Firebase s'il a perdu la sienne.
  static Future<void> start() async {
    if (!supported) return;
    await load();
    _sub ??= FirebaseAuth.instance.idTokenChanges().listen((u) {
      if (u != null) unawaited(ensure());
    });
    // Firebase relit sa session avec un léger retard : on ne répare qu'après l'avoir attendu
    unawaited(Future.delayed(const Duration(seconds: 5), () {
      if (FirebaseAuth.instance.currentUser == null && active) unawaited(restoreFirebase());
    }));
  }

  /// Ouvre la session Afrolook si Firebase a une session et que ce téléphone n'en a pas (ou en a une d'un autre compte).
  /// Sans effet en cas d'échec (nouvel essai au plus tôt une minute après) : la personne n'est jamais bloquée par ici.
  static Future<void> ensure() async {
    if (!supported) return;
    await load();
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return;
    if (_token != null && _uid == u.uid) return;
    if (_token != null && _uid != u.uid) await forget();   // autre compte connecté sur ce téléphone
    if (DateTime.now().isBefore(_nextOpen)) return;
    _opening ??= () async {
      try {
        final r = ApiClient.data(await ApiGateway.instance.client.post('/auth/session', body: {
          'device_id': await DeviceInfoService.getDeviceId(),
          'platform': Platform.isIOS ? 'ios' : 'android',
        }));
        final t = r is Map ? r['token'] as String? : null;
        if (t != null && t.startsWith('afk_') && FirebaseAuth.instance.currentUser?.uid == u.uid) {
          await _save(t, u.uid);
        }
      } catch (e) {
        // profil pas encore créé (inscription en cours), réseau… : nouvel essai plus tard
        _nextOpen = DateTime.now().add(const Duration(minutes: 1));
        if (kDebugMode) debugPrint('ApiSession : ouverture différée ($e)');
      }
    }().whenComplete(() => _opening = null);
    return _opening;
  }

  /// Firebase n'a plus de session alors qu'une session Afrolook existe : reconnexion silencieuse. Renvoie true si Firebase est reconnecté.
  static Future<bool> restoreFirebase() {
    if (!supported || !active || FirebaseAuth.instance.currentUser != null) return Future.value(FirebaseAuth.instance.currentUser != null);
    if (DateTime.now().isBefore(_nextRestore)) return Future.value(false);
    return _restoring ??= () async {
      _reportLoss();
      try {
        final r = ApiClient.data(await ApiGateway.instance.client.post('/auth/firebase-token'));
        final t = r is Map ? r['token'] as String? : null;
        if (t == null || t.isEmpty) return false;
        await FirebaseAuth.instance.signInWithCustomToken(t);
        _setKey('afk_firebase_restored', true);
        return FirebaseAuth.instance.currentUser != null;
      } catch (e) {
        _nextRestore = DateTime.now().add(const Duration(seconds: 30));
        _setKey('afk_firebase_restored', false);
        if (kDebugMode) debugPrint('ApiSession : reconnexion Firebase impossible ($e)');
        return false;
      }
    }().whenComplete(() => _restoring = null);
  }

  /// L'API a refusé la session (annulée, expirée) : elle est oubliée ; la personne garde Firebase si elle l'a.
  static Future<void> forget() async {
    _token = null;
    _uid = null;
    if (!supported) return;
    try {
      await _store.delete(key: _key);
    } catch (_) {}
  }

  /// Déconnexion volontaire : la session de ce téléphone est fermée sur le serveur (au plus 3 s d'attente) puis oubliée.
  static Future<void> close() async {
    if (!supported) return;
    await load();
    if (_token != null) {
      try {
        await ApiGateway.instance.client.delete('/auth/session').timeout(const Duration(seconds: 3));
      } catch (_) {}
    }
    await forget();
  }

  static Future<void> _save(String token, String uid) async {
    _token = token;
    _uid = uid;
    try {
      await _store.write(key: _key, value: jsonEncode({'t': token, 'u': uid}));
    } catch (_) {}
  }

  /// Rapport Crashlytics (sans donnée personnelle) à chaque perte de session Firebase, pour en trouver la cause : une fois par lancement.
  static void _reportLoss() {
    if (_lossReported || !kReleaseMode) return;
    _lossReported = true;
    try {
      FirebaseCrashlytics.instance.recordError(StateError('Session Firebase perdue (session Afrolook présente)'), null,
          fatal: false, reason: 'firebase_session_lost');
    } catch (_) {}
  }

  static void _setKey(String k, bool v) {
    if (!kReleaseMode) return;
    try {
      FirebaseCrashlytics.instance.setCustomKey(k, v);
    } catch (_) {}
  }
}
