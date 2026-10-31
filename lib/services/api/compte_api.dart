import 'dart:convert';

import 'package:afrolook_api_client/afrolook_api_client.dart';
import 'package:afrotok/services/api/api_gateway.dart';
import 'package:afrotok/services/api/wallet_api.dart';

/// Accès à l'API pour le module « compte et boosts » : frais de restauration, tableau de bord de l'équipe, annonces de la régie Afrolook Ads.
/// Aucun retour à Firebase : en cas d'erreur, l'écran affiche le message et propose « Réessayer ».
/// Routes encore absentes de l'API : voir connaissances/lacunes_api_compte_boosts.md.
class CompteApi {
  CompteApi._();

  static ApiClient get _c => ApiGateway.instance.client;

  static Map<String, dynamic> _map(dynamic r) {
    final d = ApiClient.data(r);
    return d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{};
  }

  static List<Map<String, dynamic>> _list(dynamic r) =>
      ((r is Map ? r['data'] : r) as List? ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();

  /// Message en français prêt à afficher. 404/501 : fonctionnalité pas encore ouverte côté serveur.
  static String message(Object e, {String fallback = 'Une erreur est survenue. Réessaie.'}) {
    if (e is ApiException) {
      if (e.isNetwork) return 'Connexion impossible. Vérifie ta connexion puis réessaie.';
      if (e.status == 404 || e.status == 501) return 'Cette fonction n\'est pas encore disponible. Réessaie plus tard.';
      return e.message.isNotEmpty ? e.message : fallback;
    }
    return fallback;
  }

  // ── Inscription ──
  /// Création du profil (POST /me/register, idempotente). `referral_code` : code de parrainage saisi, vérifié et appliqué par le serveur
  /// (champ à accepter : voir lacunes_api_compte_boosts.md ; ignoré tant qu'il n'est pas géré).
  static Future<Map<String, dynamic>> register({required String username, String? displayName, String? countryCode, String? language, String? referralCode}) async =>
      _map(await _c.post('/me/register', body: {
        'username': username,
        if (displayName != null) 'display_name': displayName,
        if (countryCode != null) 'country_code': countryCode,
        if (language != null) 'language': language,
        if (referralCode != null) 'referral_code': referralCode,
      }));

  // ── Compte restauré : frais de déblocage en pièces (clé d'idempotence conservée, jamais de double débit) ──
  static Future<void> payRestoreFee() async {
    await WalletApi.instance.pay('restore_fee', '/me/restore-fee');
  }

  // ── Hub de l'équipe ──
  /// {profile:{name,widgets:[…]}, widgets:{stats_inscriptions:{period,total,points:[{label,count}]}}}
  static Future<Map<String, dynamic>> teamHub(String period) async => _map(await _c.get('/admin/team-hub', query: {'period': period}));

  // ── Annonces de la régie Afrolook Ads (mes annonces) ──
  static Future<List<Map<String, dynamic>>> myAds() async => _list(await _c.get('/ads/account/ads'));

  /// Une annonce par son identifiant (la liste est courte : 3 annonces gratuites au plus en même temps + payantes).
  static Future<Map<String, dynamic>?> myAd(String id) async {
    for (final a in await myAds()) {
      if ('${a['id']}' == id) return a;
    }
    return null;
  }

  /// Images d'une annonce (la colonne peut arriver en texte JSON ou en liste).
  static List<String> adImages(Map<String, dynamic> a) {
    final raw = a['images'];
    List<dynamic> l = const [];
    if (raw is List) {
      l = raw;
    } else if (raw is String && raw.isNotEmpty) {
      try {
        final d = jsonDecode(raw);
        if (d is List) l = d;
      } catch (_) {}
    }
    final out = l.map((e) => '$e').where((e) => e.isNotEmpty).toList();
    if (out.isEmpty) {
      final m = a['media_url'] ?? a['thumb_url'];
      if (m != null && '$m'.isNotEmpty) out.add('$m');
    }
    return out;
  }

  /// Libellé français du statut d'une annonce.
  static String statusLabel(String? s) => switch (s) {
        'pending' => 'En validation',
        'active' => 'En diffusion',
        'approved' => 'Validée',
        'rejected' => 'Refusée',
        'suspended' => 'Suspendue',
        'ended' || 'expired' => 'Terminée',
        _ => s ?? '',
      };

  /// Suppression d'une annonce par son propriétaire (route à ouvrir : `DELETE /ads/account/ads/{id}`).
  static Future<void> deleteAd(String id) => _c.delete('/ads/account/ads/$id');
}
