import 'dart:convert';
import 'package:afrotok/pages/component/consoleWidget.dart';

import 'package:shared_preferences/shared_preferences.dart';
import '../../models/model_data.dart';

/// Cache de démarrage — stocke UserData + AppDefaultData dans SharedPreferences
/// pour permettre un lancement instantané (cache-first) sur les relances.
class StartupCacheService {
  static const _keyUserData = 'startup_cache_user';
  static const _keyAppData = 'startup_cache_app';
  static const _keyUserTime = 'startup_cache_user_time';
  static const _keyAppTime = 'startup_cache_app_time';

  static const _userTtl = Duration(hours: 24);
  static const _appTtl = Duration(hours: 6);

  // ── Sauvegarde ─────────────────────────────────────────────────────────────

  static Future<void> saveUserData(UserData user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyUserData, jsonEncode(_userToMap(user)));
      await prefs.setInt(_keyUserTime, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      printVm('⚠️ [StartupCache] saveUserData échoué: $e');
    }
  }

  static Future<void> saveAppData(AppDefaultData data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final map = data.toJson();
      // Correction du mismatch de clé dans AppDefaultData :
      // toJson() écrit 'one_signal_api_url' mais fromJson() lit 'one_signal_app_url'
      map['one_signal_app_url'] = data.one_signal_app_url;
      // Les champs late String ne supportent pas null → valeur par défaut
      map['app_logo'] ??= '';
      map['one_signal_api_key'] ??= '';
      map['one_signal_app_id'] ??= '';
      await prefs.setString(_keyAppData, jsonEncode(map));
      await prefs.setInt(_keyAppTime, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      printVm('⚠️ [StartupCache] saveAppData échoué: $e');
    }
  }

  // ── Chargement ─────────────────────────────────────────────────────────────

  static Future<UserData?> loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheTime = prefs.getInt(_keyUserTime) ?? 0;
      final age = DateTime.now().millisecondsSinceEpoch - cacheTime;
      if (age > _userTtl.inMilliseconds) return null;
      final raw = prefs.getString(_keyUserData);
      if (raw == null) return null;
      return _userFromMap(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      printVm('⚠️ [StartupCache] loadUserData échoué: $e');
      return null;
    }
  }

  static Future<AppDefaultData?> loadAppData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheTime = prefs.getInt(_keyAppTime) ?? 0;
      final age = DateTime.now().millisecondsSinceEpoch - cacheTime;
      if (age > _appTtl.inMilliseconds) return null;
      final raw = prefs.getString(_keyAppData);
      if (raw == null) return null;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      // Filet de sécurité : compatibilité avec des caches enregistrés avant la correction
      map['one_signal_app_url'] ??= map['one_signal_api_url'] ?? '';
      map['app_logo'] ??= '';
      map['one_signal_api_key'] ??= '';
      map['one_signal_app_id'] ??= '';
      return AppDefaultData.fromJson(map);
    } catch (e) {
      printVm('⚠️ [StartupCache] loadAppData échoué: $e');
      return null;
    }
  }

  static Future<bool> hasValidUserCache(String userId) async {
    final user = await loadUserData();
    return user != null && user.id == userId;
  }

  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyUserData);
      await prefs.remove(_keyAppData);
      await prefs.remove(_keyUserTime);
      await prefs.remove(_keyAppTime);
    } catch (_) {}
  }

  // ── Sérialisation ──────────────────────────────────────────────────────────

  static Map<String, dynamic> _userToMap(UserData u) => {
        'id': u.id,
        'pseudo': u.pseudo,
        'nom': u.nom,
        'prenom': u.prenom,
        'email': u.email,
        'imageUrl': u.imageUrl,
        'genre': u.genre,
        'role': u.role,
        'isVerify': u.isVerify,
        'codeParrainage': u.codeParrainage,
        'codeParrain': u.codeParrain,
        'countryData': u.countryData,
        'publi_cash': u.publi_cash,
        'votre_solde': u.votre_solde,
        'votre_solde_principal': u.votre_solde_principal,
        'abonnes': u.abonnes,
        'state': u.state,
        'oneIgnalUserid': u.oneIgnalUserid,
      };

  static UserData _userFromMap(Map<String, dynamic> j) {
    final user = UserData();
    user.id = j['id'];
    user.pseudo = j['pseudo'];
    user.nom = j['nom'];
    user.prenom = j['prenom'];
    user.email = j['email'];
    user.imageUrl = j['imageUrl'];
    user.genre = j['genre'];
    user.role = j['role'];
    user.isVerify = j['isVerify'];
    user.codeParrainage = j['codeParrainage'];
    user.codeParrain = j['codeParrain'];
    user.countryData =
        j['countryData'] != null ? Map<String, String>.from(j['countryData']) : {};
    user.publi_cash = (j['publi_cash'] as num?)?.toDouble() ?? 0.0;
    user.votre_solde = (j['votre_solde'] as num?)?.toDouble() ?? 0.0;
    user.votre_solde_principal =
        (j['votre_solde_principal'] as num?)?.toDouble() ?? 0.0;
    user.abonnes = j['abonnes'];
    user.state = j['state'];
    user.oneIgnalUserid = j['oneIgnalUserid'];
    return user;
  }
}
