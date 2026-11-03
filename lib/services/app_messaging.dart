import 'dart:io' show Platform;

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_in_app_messaging/firebase_in_app_messaging.dart';
import 'package:flutter/foundation.dart';

/// Messages dans l'application : campagnes créées dans la console Firebase (Engagement → In-App Messaging) avec titre, texte, images portrait et paysage et bouton.
///
/// Firebase affiche tout seul les campagnes actives quand leur déclencheur arrive (ouverture de l'application, retour au premier plan, événement). Ce service :
///  • démarre le module (Android et iPhone seulement : il n'existe pas sur le site web) ;
///  • publie quelques PROPRIÉTÉS de la personne (pays, langue, abonnement, équipe) pour cibler une campagne dans la console (« Audiences » / « Propriétés utilisateur ») ;
///  • permet de couper les messages pendant un moment qu'on ne doit pas interrompre (live, paiement) : [suppress].
/// Aucune donnée personnelle n'est envoyée (jamais de nom, d'e-mail ni de téléphone). Toute erreur est ignorée : un message ne doit jamais gêner l'application.
class AppMessaging {
  AppMessaging._();

  static bool get _native => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  static final Map<String, String> _last = {};

  /// À appeler une fois, juste après `Firebase.initializeApp`.
  static Future<void> init() async {
    if (!_native) return;
    try {
      await FirebaseInAppMessaging.instance.setAutomaticDataCollectionEnabled(true);
      await FirebaseInAppMessaging.instance.setMessagesSuppressed(false);
    } catch (e) {
      debugPrint('Messages dans l\'application indisponibles (non bloquant) : $e');
    }
  }

  /// Propriétés de ciblage, mises à jour seulement quand elles changent. [plan] : `free`, `premium` ou `gold`.
  static Future<void> syncUser({String? country, String? language, String plan = 'free', bool team = false}) async {
    if (!_native) return;
    final props = <String, String>{
      if (country != null && country.isNotEmpty) 'app_country': country.toUpperCase(),
      if (language != null && language.isNotEmpty) 'app_lang': language.toLowerCase(),
      'app_plan': plan,
      'app_team': team ? 'yes' : 'no',
    };
    for (final e in props.entries) {
      if (_last[e.key] == e.value) continue;
      try {
        await FirebaseAnalytics.instance.setUserProperty(name: e.key, value: e.value);
        _last[e.key] = e.value;
      } catch (_) {/* non bloquant */}
    }
  }

  /// Coupe (`true`) ou rétablit (`false`) l'affichage des messages : à utiliser pendant un live, un paiement ou une saisie sensible.
  static Future<void> suppress(bool on) async {
    if (!_native) return;
    try {
      await FirebaseInAppMessaging.instance.setMessagesSuppressed(on);
    } catch (_) {/* non bloquant */}
  }

  /// Déclenche une campagne dont le déclencheur est cet événement (ex. `after_first_post`) : se règle dans la console, « Événement de déclenchement ».
  static Future<void> trigger(String event) async {
    if (!_native) return;
    try {
      await FirebaseInAppMessaging.instance.triggerEvent(event);
    } catch (_) {/* non bloquant */}
  }
}
