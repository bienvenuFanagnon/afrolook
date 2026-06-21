import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../cache/startup_cache_service.dart';

class SessionUserFirebaseService {
  static const String TOKEN_KEY = 'token';
  static const String LAST_ACTIVE_KEY = 'last_active_timestamp';
  static const int MAX_INACTIVE_DAYS = 3;
  static const int ONE_DAY_IN_MILLISECONDS = 24 * 60 * 60 * 1000;

  /// Sauvegarde l'ID utilisateur et la date de connexion
  static Future<void> saveUserSession(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(TOKEN_KEY, userId);
    await prefs.setInt(LAST_ACTIVE_KEY, DateTime.now().millisecondsSinceEpoch);
    print('✅ Session sauvegardée pour: $userId');
  }

  /// Récupère l'ID utilisateur stocké
  static Future<String?> getStoredUserId() async {
    final prefs = await SharedPreferences.getInstance();
    print('✅ get Session TOKEN_KEY: $TOKEN_KEY');

    return prefs.getString(TOKEN_KEY);
  }

  /// Vérifie si l'utilisateur peut rester connecté (moins de 3 jours d'inactivité)
  static Future<bool> canStayConnected() async {
    final prefs = await SharedPreferences.getInstance();
    final lastActive = prefs.getInt(LAST_ACTIVE_KEY);

    if (lastActive == null) return false;

    final now = DateTime.now().millisecondsSinceEpoch;
    final daysInactive = (now - lastActive) ~/ ONE_DAY_IN_MILLISECONDS;

    print('📊 Vérification session: daysInactive=$daysInactive, max=$MAX_INACTIVE_DAYS');

    return daysInactive < MAX_INACTIVE_DAYS;
  }

  /// Met à jour la date de dernière activité
  static Future<void> updateLastActive() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(LAST_ACTIVE_KEY, DateTime.now().millisecondsSinceEpoch);
  }

  /// Efface la session (déconnexion)
  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(TOKEN_KEY);
    await prefs.remove(LAST_ACTIVE_KEY);
    await StartupCacheService.clear();
    print('🗑️ Session et cache effacés');
  }

  /// Vérifie si l'utilisateur est inactif depuis plus de 3 jours (Firestore)
  static Future<bool> isUserInactive(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(userId)
          .get();

      if (!userDoc.exists) return true;

      final userData = userDoc.data()!;
      final lastTimeActive = userData['last_time_active'] ?? 0;

      if (lastTimeActive == 0) return true;

      final now = DateTime.now().millisecondsSinceEpoch;
      int lastActiveMillis = lastTimeActive;

      // Conversion si timestamp est en microsecondes

      final daysInactive = (now - lastActiveMillis) ~/ ONE_DAY_IN_MILLISECONDS;

      print('📊 isUserInactive: userId=$userId, daysInactive=$daysInactive');

      return daysInactive >= MAX_INACTIVE_DAYS;
    } catch (e) {
      print('Erreur isUserInactive: $e');
      return true;
    }
  }
}