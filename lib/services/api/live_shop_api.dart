import 'package:afrotok/l10n/tr.dart';
import 'package:afrolook_api_client/afrolook_api_client.dart';
import 'package:afrotok/services/api/api_gateway.dart';
import 'package:afrotok/services/api/wallet_api.dart';

/// Accès à l'API : Live Shopping (livraison, produits épinglés dans un live, négociation, commandes avec séquestre).
/// Toute erreur est transmise telle quelle ([ApiException], message en français) : voir [message].
class LiveShopApi {
  LiveShopApi._();

  static ApiClient get _c => ApiGateway.instance.client;

  static Map<String, dynamic> _map(dynamic r) => WalletApi.map(r);
  static List<Map<String, dynamic>> _list(dynamic r) => WalletApi.list(r);

  static String message(Object e, {String? fallback}) {
    if (e is ApiException && e.code == 'validation_failed') {
      // Le serveur indique quel champ pose problème : on le dit clairement, en français
      final errs = e.details['errors'];
      if (errs is Map && errs.isNotEmpty) {
        final field = '${errs.keys.first}';
        final labels = {
          'country': tr('Indique le pays en 2 lettres (par exemple TG pour le Togo).'),
          'city': tr('Indique ta ville.'),
          'address': tr("Écris une adresse plus précise (5 caractères au moins)."),
          'phone': tr('Indique un numéro de téléphone valide, avec au moins 6 chiffres.'),
          'amount_xof': tr('Indique un montant valide.'),
          'quantity': tr('La quantité doit être comprise entre 1 et 50.'),
        };
        return labels[field] ?? tr('Une information est invalide : {f}.', {'f': field});
      }
    }
    // messages du serveur (en français) : traduits ici quand ils sont connus
    if (e is ApiException && e.status >= 400 && e.message.isNotEmpty && e.code != 'insufficient_coins') return tr(e.message);
    return WalletApi.message(e, fallback: fallback ?? tr('Action impossible pour le moment. Vérifie ta connexion.'));
  }

  // ── Livraison ──

  static Future<List<Map<String, dynamic>>> rates() async => _list(await _c.get('/live-shop/delivery-rates'));

  static Future<List<Map<String, dynamic>>> setRate({required String country, String? city, required int fee}) async =>
      _list(await _c.put('/live-shop/delivery-rates', body: {'country': country, if (city != null && city.trim().isNotEmpty) 'city': city.trim(), 'fee_xof': fee}));

  static Future<List<Map<String, dynamic>>> deleteRate(int id) async => _list(await _c.delete('/live-shop/delivery-rates/$id'));

  /// Estimation des frais de livraison (null = « à convenir »). Elle n'est jamais ajoutée au prix : payée à la livraison.
  /// Estimation complète : `estimate_xof`, `seller_country`, `delivery_countries`, `delivers` (true, false, ou null quand le vendeur n'a indiqué aucun tarif).
  static Future<Map<String, dynamic>> estimateFull(String articleId, {String? country, String? city}) async =>
      _map(await _c.get('/live-shop/articles/$articleId/delivery-estimate', query: {if (country != null) 'country': country, if (city != null && city.isNotEmpty) 'city': city}));

  static Future<int?> estimate(String articleId, {String? country, String? city}) async {
    final r = _map(await _c.get('/live-shop/articles/$articleId/delivery-estimate', query: {if (country != null) 'country': country, if (city != null && city.isNotEmpty) 'city': city}));
    return (r['estimate_xof'] as num?)?.toInt();
  }

  // ── Produits épinglés ──

  static Future<List<Map<String, dynamic>>> pins(String liveId) async => _list(await _c.get('/live-shop/lives/$liveId/pins'));

  static Future<List<Map<String, dynamic>>> pin(String liveId, String articleId) async => _list(await _c.post('/live-shop/lives/$liveId/pins', body: {'article_id': articleId}));

  static Future<List<Map<String, dynamic>>> unpin(String liveId, String articleId) async => _list(await _c.delete('/live-shop/lives/$liveId/pins/$articleId'));

  /// Règle le stock d'un de ses articles (null = illimité) : à tout moment, même pendant le live.
  static Future<Map<String, dynamic>> setStock(String articleId, int? stock) async => _map(await _c.put('/live-shop/articles/$articleId/stock', body: {'stock': stock}));

  // ── Mes articles (pour en épingler un dans un live) ──

  static Future<List<Map<String, dynamic>>> myArticles() async => _list(await _c.get('/shop/articles', query: {'mine': 1, 'limit': 50}));

  /// Autorise l'achat en 1 clic (séquestre) sur un article du vendeur.
  static Future<void> enableSelling(String articleId) => _c.patch('/shop/articles/$articleId', body: {'live_sellable': true});

  // ── Confiance : code de livraison, avis, codes promo ──

  /// Le vendeur saisit le code de 4 chiffres que l'acheteur lui donne à la remise : livraison confirmée, argent versé.
  static Future<Map<String, dynamic>> deliver(String id, String code) async => _map(await _c.post('/live-shop/orders/$id/deliver', body: {'code': code}));

  static Future<Map<String, dynamic>> review(String id, int rating, {String? comment}) async =>
      _map(await _c.post('/live-shop/orders/$id/review', body: {'rating': rating, if (comment != null && comment.trim().isNotEmpty) 'comment': comment.trim()}));

  static Future<Map<String, dynamic>> reputation(String sellerId) async => _map(await _c.get('/live-shop/sellers/$sellerId/reputation'));

  static Future<List<Map<String, dynamic>>> promos() async => _list(await _c.get('/live-shop/promos'));

  static Future<Map<String, dynamic>> createPromo({required String code, required String kind, required int value, int? maxUses, int? minPrice, bool firstOrderOnly = false, DateTime? expiresAt, String? articleId}) async =>
      _map(await _c.post('/live-shop/promos', body: {
        'code': code, 'kind': kind, 'value': value,
        if (articleId != null) 'article_id': articleId,
        if (maxUses != null) 'max_uses': maxUses,
        if (minPrice != null && minPrice > 0) 'min_price_xof': minPrice,
        if (firstOrderOnly) 'first_order_only': true,
        if (expiresAt != null) 'expires_at': expiresAt.toUtc().toIso8601String(),
      }));

  static Future<List<Map<String, dynamic>>> deletePromo(String id) async => _list(await _c.delete('/live-shop/promos/$id'));

  /// Aperçu d'un code promo avant l'achat : réduction et prix à payer.
  static Future<Map<String, dynamic>> promoCheck(String articleId, String code, {int quantity = 1}) async =>
      _map(await _c.post('/live-shop/articles/$articleId/promo-check', body: {'code': code, 'quantity': quantity}));

  // ── Statistiques de vente ──

  /// Bilan d'un live : chiffres publics pour tout le monde, détails pour l'hôte (la réponse porte alors `received_xof`).
  /// Commandes de ce live qui attendent encore la réponse du vendeur (pastille rouge « Commandes »).
  /// Compteurs du vendeur dans ce live : à traiter (`pending`, `offers`) et ventes cumulées depuis le début (`sold` : orders, items, gross_xof, received_xof, escrow_xof).
  static Future<Map<String, dynamic>> liveSellerSummary(String liveId) async => _map(await _c.get('/live-shop/lives/$liveId/pending-orders'));

  static Future<int> pendingOrders(String liveId) async {
    final m = _map(await _c.get('/live-shop/lives/$liveId/pending-orders'));
    return ((m['pending'] as num?)?.toInt() ?? 0) + ((m['offers'] as num?)?.toInt() ?? 0);   // commandes à valider + offres à répondre
  }

  static Future<Map<String, dynamic>> liveSummary(String liveId) async => _map(await _c.get('/live-shop/lives/$liveId/summary'));

  /// Tableau de bord du vendeur : tout ce qu'il a vendu en ligne.
  static Future<Map<String, dynamic>> sellerStats() async => _map(await _c.get('/live-shop/seller/stats'));

  /// Comptabilité des ventes (consultation) : vendeur ([seller] vrai) ou acheteur, jours `from` / `to` (AAAA-MM-JJ).
  static Future<Map<String, dynamic>> ledger({required bool seller, String? from, String? to}) async =>
      _map(await _c.get('/live-shop/ledger', query: {'role': seller ? 'seller' : 'buyer', if (from != null) 'from': from, if (to != null) 'to': to}));

  /// Tableau de bord de l'acheteur : argent protégé, dépenses, ce qu'il doit faire maintenant, vendeurs habituels.
  static Future<Map<String, dynamic>> buyerStats() async => _map(await _c.get('/live-shop/buyer/stats'));

  // ── Administration (équipe, droit shop.manage) ──

  /// Réglages de l'équipe : commission sur les ventes et limites de lives (droit config.edit).
  static Future<Map<String, dynamic>> adminSettings() async => _map(await _c.get('/admin/live-shop/settings'));

  static Future<Map<String, dynamic>> setAdminSettings(Map<String, dynamic> body) async => _map(await _c.put('/admin/live-shop/settings', body: body));

  static Future<Map<String, dynamic>> adminStats() async => _map(await _c.get('/admin/live-shop/stats'));

  /// Vue d'ensemble du hub admin : ventes par type, marchés et étals, gains des lives, minutes Agora. `period` : today | 7d | 30d.
  static Future<Map<String, dynamic>> adminOverview({String period = 'today'}) async => _map(await _c.get('/admin/live-shop/overview', query: {'period': period}));

  static Future<List<Map<String, dynamic>>> adminDisputes() async => _list(await _c.get('/admin/live-shop/disputes'));

  static Future<List<Map<String, dynamic>>> adminOrders({String? status, String? q}) async =>
      _list(await _c.get('/admin/live-shop/orders', query: {'limit': 50, if (status != null) 'status': status, if (q != null) 'q': q}));

  static Future<Map<String, dynamic>> adminResolve(String id, String outcome) async => _map(await _c.post('/admin/live-shop/orders/$id/resolve', body: {'outcome': outcome}));

  static Future<bool>? _isAdmin;

  /// La personne connectée a-t-elle le droit « shop.manage » ? (lu une fois, jamais bloquant ; le serveur refuse de toute façon sans le droit)
  static Future<bool> isAdmin() => _isAdmin ??= () async {
        try {
          final r = _map(await _c.get('/me/capabilities'));
          final perms = (r['permissions'] as List?)?.map((e) => '$e').toList() ?? const <String>[];
          // le super-administrateur a tous les droits ; « content.moderate » couvre aussi « shop.manage » (droit large)
          return r['is_staff'] == true && (r['type'] == 'super_admin' || perms.contains('shop.manage') || perms.contains('content.moderate'));
        } catch (_) {
          _isAdmin = null;   // réessayer à la prochaine ouverture du menu
          return false;
        }
      }();

  // ── Négociation ──

  static Future<Map<String, dynamic>> offer(String articleId, int amount, {String? liveId}) async =>
      _map(await _c.post('/live-shop/articles/$articleId/offers', body: {'amount_xof': amount, if (liveId != null) 'live_id': liveId}));

  static Future<List<Map<String, dynamic>>> offers({String role = 'buyer'}) async => _list(await _c.get('/live-shop/offers', query: {'role': role}));

  static Future<Map<String, dynamic>> sellerReply(String id, String action, {int? amount}) async =>
      _map(await _c.post('/live-shop/offers/$id/seller-reply', body: {'action': action, if (amount != null) 'amount_xof': amount}));

  static Future<Map<String, dynamic>> buyerReply(String id, String action, {int? amount}) async =>
      _map(await _c.post('/live-shop/offers/$id/buyer-reply', body: {'action': action, if (amount != null) 'amount_xof': amount}));

  // ── Commandes ──

  static Future<Map<String, dynamic>> placeOrder({
    required String articleId,
    required String country,
    required String city,
    required String address,
    required String phone,
    int quantity = 1,
    String? offerId,
    String? liveId,
    String? promoCode,
  }) async =>
      _map(await _c.post('/live-shop/orders', body: {
        'article_id': articleId, 'country': country, 'city': city, 'address': address, 'phone': phone, 'quantity': quantity,
        if (offerId != null) 'offer_id': offerId,
        if (liveId != null) 'live_id': liveId,
        if (promoCode != null && promoCode.isNotEmpty) 'promo_code': promoCode,
      }));

  /// Mes commandes, une page à la fois : `group` = todo (à moi d'agir) | progress | done ; `q` = pseudo de l'autre personne.
  static Future<List<Map<String, dynamic>>> orders({String role = 'buyer', String? group, String? status, String? q, int offset = 0, int limit = 30}) async =>
      _list(await _c.get('/live-shop/orders', query: {'role': role, 'limit': limit, 'offset': offset, if (group != null) 'group': group, if (status != null) 'status': status, if (q != null && q.trim().isNotEmpty) 'q': q.trim()}));

  /// Compteurs des pastilles rouges : {seller: {todo, progress, done}, buyer: {todo, progress, done, to_rate}}.
  static Future<Map<String, dynamic>> orderCounts() async => _map(await _c.get('/live-shop/orders/counts'));

  static Future<Map<String, dynamic>> sellerValidate(String id, {int? deliveryFee}) async =>
      _map(await _c.post('/live-shop/orders/$id/seller-validate', body: {if (deliveryFee != null) 'delivery_fee_xof': deliveryFee}));

  static Future<Map<String, dynamic>> buyerFee(String id, bool accept) async => _map(await _c.post('/live-shop/orders/$id/buyer-fee', body: {'accept': accept}));

  static Future<Map<String, dynamic>> ship(String id) async => _map(await _c.post('/live-shop/orders/$id/ship', body: const {}));

  static Future<Map<String, dynamic>> confirm(String id) async => _map(await _c.post('/live-shop/orders/$id/confirm', body: const {}));

  static Future<Map<String, dynamic>> cancel(String id, {String? reason}) async => _map(await _c.post('/live-shop/orders/$id/cancel', body: {if (reason != null) 'reason': reason}));

  static Future<Map<String, dynamic>> dispute(String id, String reason) async => _map(await _c.post('/live-shop/orders/$id/dispute', body: {'reason': reason}));

  // ── Vérification d'identité des vendeurs ──

  /// Où j'en suis : niveau (1 inscrit, 2 identité vérifiée, 3 fiable), plafond mensuel avant vérification, dernière demande.
  static Future<Map<String, dynamic>> verification() async => _map(await _c.get('/live-shop/verification'));

  /// Dépose la demande : photos déjà envoyées en privé (`upload_id`).
  static Future<Map<String, dynamic>> submitVerification({required String fullName, required String idType, required String country, required String front, String? back, required String selfie}) async =>
      _map(await _c.post('/live-shop/verification', body: {'full_name': fullName, 'id_type': idType, 'country': country, 'front_upload_id': front, if (back != null) 'back_upload_id': back, 'selfie_upload_id': selfie}));

  // Équipe (droit « sellers.verify », connexion récente)
  static Future<Map<String, dynamic>> adminVerifications({String status = 'pending'}) async => _map(await _c.get('/admin/sellers/verifications', query: {'status': status}));

  static Future<Map<String, dynamic>> adminVerification(String id) async => _map(await _c.get('/admin/sellers/verifications/$id'));

  static Future<Map<String, dynamic>> adminDecideVerification(String id, {required bool approve, String? reason}) async =>
      _map(await _c.post('/admin/sellers/verifications/$id/decision', body: {'approve': approve, if (reason != null) 'reason': reason}));

  static Future<Map<String, dynamic>> adminRevokeVerification(String userId, String reason) async => _map(await _c.post('/admin/sellers/$userId/revoke', body: {'reason': reason}));
}
