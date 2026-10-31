import 'dart:typed_data';

import 'package:afrolook_api_client/afrolook_api_client.dart';
import 'package:afrotok/services/api/api_gateway.dart';
import 'package:afrotok/services/api/argent_upload.dart';

import '../../models/official_account/official_account_enums.dart';
import '../../models/official_account/official_account_request.dart';

/// Compléments d'administration via l'API : comptes officiels, demandes d'influenceur, suivi des paiements, rémunération,
/// informations et annonces de l'application, catégories de la boutique.
/// Aucun retour à Firebase : une erreur est transmise telle quelle (ApiException, message déjà en français) et l'écran propose « Réessayer ».
class AdminComplementsApi {
  AdminComplementsApi._();

  static ApiClient get _c => ApiGateway.instance.client;

  static Map<String, dynamic> _map(dynamic r) {
    final d = ApiClient.data(r);
    return d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{};
  }

  static List<Map<String, dynamic>> _list(dynamic r) =>
      ((r is Map ? r['data'] : r) as List? ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();

  /// Message prêt à afficher. 404/501 : la fonction n'est pas encore ouverte côté serveur (ou pas de droit).
  static String message(Object e, {String fallback = 'Une erreur est survenue. Réessaie.'}) {
    if (e is ApiException) {
      if (e.isNetwork) return 'Connexion impossible. Vérifie ta connexion puis réessaie.';
      if (e.status == 404 || e.status == 501) return e.message.isNotEmpty ? e.message : 'Cette fonction n\'est pas disponible pour ce compte.';
      return e.message.isNotEmpty ? e.message : fallback;
    }
    return fallback;
  }

  static int _ms(Object? v) => v is String ? (DateTime.tryParse(v)?.millisecondsSinceEpoch ?? 0) : (v is num ? v.toInt() : 0);

  // ── Comptes officiels ──────────────────────────────────────────────────────

  /// Demande de l'API → modèle de l'application (dates en millisecondes, historique converti).
  static OfficialAccountRequest requestFromApi(Map<String, dynamic> j) {
    final history = ((j['action_history'] as List?) ?? const []).whereType<Map>().map((a) => <String, dynamic>{
          'action': a['action'] ?? '',
          'note': a['note'],
          'adminId': a['admin_id'] ?? '',
          'timestamp': _ms(a['at']),
        }).toList();
    final m = <String, dynamic>{
      'userId': j['user_id'] ?? '',
      'pseudo': j['pseudo'] ?? '',
      'imageUrl': j['image_url'] ?? '',
      'category': j['category'] ?? '',
      'officialName': j['official_name'] ?? '',
      'officialNameSlug': j['official_name_slug'] ?? '',
      'searchKeywords': (j['search_keywords'] as List?) ?? const [],
      'description': j['description'] ?? '',
      'country': j['country'] ?? '',
      'city': j['city'] ?? '',
      'phone': j['phone'] ?? '',
      'email': j['email'] ?? '',
      'website': j['website'] ?? '',
      'profilePhotoUrl': j['profile_photo_url'] ?? '',
      'coverPhotoUrl': j['cover_photo_url'] ?? '',
      'broadcastDomains': (j['broadcast_domains'] as List?) ?? const [],
      'socialNetworks': ((j['social_networks'] as List?) ?? const []).whereType<Map>().map((s) => Map<String, dynamic>.from(s)).toList(),
      'birthDate': j['birth_date'],
      'idDocumentType': j['id_document_type'],
      'idNumber': j['id_number'],
      'idDocumentUrl': j['id_document_url'],
      'status': j['status'] ?? 'pending',
      'adminNote': j['admin_note'],
      'actionHistory': history,
      'createdAt': _ms(j['created_at']),
      'updatedAt': _ms(j['updated_at']),
      'processedAt': j['processed_at'] == null ? null : _ms(j['processed_at']),
      'processedBy': j['processed_by'],
      'termsAcceptedAt': _ms(j['terms_accepted_at']),
    };
    return OfficialAccountRequest.fromMap(m, '${j['id'] ?? ''}');
  }

  /// Corps de création / modification : noms de champs de l'API. [idDocumentUploadId] : envoi PRIVÉ déjà terminé (jamais une adresse).
  static Map<String, dynamic> requestBody({
    OfficialAccountCategory? category,
    String? officialName,
    required String description,
    required String country,
    required String city,
    required String phone,
    required String email,
    required String website,
    required List<BroadcastDomain> domains,
    required List<SocialNetworkEntry> networks,
    String? birthDate,
    IdDocumentType? idType,
    String? idNumber,
    String? idDocumentUploadId,
    bool acceptTerms = false,
  }) =>
      {
        if (category != null) 'category': category.id,
        if (officialName != null) 'official_name': officialName,
        'description': description,
        'country': country,
        'city': city,
        'phone': phone,
        'email': email.isEmpty ? null : email,
        'website': website,
        'broadcast_domains': domains.map((d) => d.id).toList(),
        'social_networks': networks.map((s) => {'type': s.type.id, 'link': s.link, 'followers': s.followers}).toList(),
        'birth_date': birthDate,
        'id_document_type': idType?.id,
        'id_number': (idNumber ?? '').isEmpty ? null : idNumber,
        if (idDocumentUploadId != null) 'id_document_upload_id': idDocumentUploadId,
        if (acceptTerms) 'terms_accepted': true,
      };

  static Future<String> submitOfficial(Map<String, dynamic> body) async => '${_map(await _c.post('/official-accounts/requests', body: body))['id']}';

  static Future<OfficialAccountRequest?> myOfficialRequest() async {
    final d = ApiClient.data(await _c.get('/official-accounts/requests/mine'));
    return d is Map ? requestFromApi(Map<String, dynamic>.from(d)) : null;
  }

  static Future<void> updateOfficial(String id, Map<String, dynamic> body) => _c.patch('/official-accounts/requests/$id', body: body);

  static Future<bool> nameAvailable(String slug) async => _map(await _c.get('/official-accounts/name-available', query: {'slug': slug}))['available'] == true;

  /// Paiement de l'abonnement mensuel en pièces (clé conservée par l'appelant : jamais de double débit).
  static Future<void> paySubscription(String idempotencyKey) => _c.pay('/official-accounts/subscription', body: const {}, idempotencyKey: idempotencyKey);

  /// {active, last_paid_at, next_due_at, auto_pay_enabled, free, official_status}
  static Future<Map<String, dynamic>> subscription() async => _map(await _c.get('/official-accounts/subscription'));

  static Future<List<OfficialAccountRequest>> adminOfficialRequests({OfficialAccountStatus? status, OfficialAccountCategory? category}) async =>
      _list(await _c.get('/admin/official-accounts/requests', query: {if (status != null) 'status': status.id, if (category != null) 'category': category.id, 'limit': 300}))
          .map(requestFromApi)
          .toList();

  static Future<OfficialAccountRequest> adminOfficialDecide(String id, OfficialAccountStatus status, {String? note}) async =>
      requestFromApi(_map(await _c.post('/admin/official-accounts/requests/$id/decision', body: {'status': status.id, if (note != null) 'note': note})));

  // ── Demandes d'influenceur ─────────────────────────────────────────────────

  /// Lignes : {id, user_id, pseudo, image_url, follower_count, status, admin_note, created_at (ms), processed_at}
  static Future<List<Map<String, dynamic>>> influencerRequests(String status) async {
    final rows = _list(await _c.get('/admin/influencer-requests', query: {'status': status, 'limit': 300}));
    return [for (final r in rows) {...r, 'created_at': _ms(r['created_at']), 'processed_at': _ms(r['processed_at'])}];
  }

  static Future<void> decideInfluencer(String id, bool approve, String note) =>
      _c.post('/admin/influencer-requests/$id/decision', body: {'approve': approve, if (note.isNotEmpty) 'note': note});

  // ── Suivi des paiements ────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> paymentLogs({required bool errorsOnly}) async =>
      _list(await _c.get('/admin/payments/logs', query: {if (errorsOnly) 'errors': 1, 'limit': 200}));

  /// Compteurs du jour : {feexpay_ok: 3, feexpay_error: 1, …}
  static Future<Map<String, int>> paymentStats() async {
    final s = _map(await _c.get('/admin/payments/stats'))['stats'];
    return s is Map ? {for (final e in s.entries) '${e.key}': (e.value as num).toInt()} : <String, int>{};
  }

  /// Erreur de paiement vue par l'application (au plus 20 par jour et par compte côté serveur). Ne lève jamais d'erreur.
  static Future<void> reportPayment({required String provider, required String step, String? code, Object? message, double? amount, String? currency, bool expected = false}) async {
    try {
      await _c.post('/payments/report', body: {
        'provider': provider,
        'step': step,
        if (code != null) 'code': code,
        if (message != null) 'message': '$message',
        if (amount != null) 'amount': amount,
        if (currency != null) 'currency': currency,
        'expected': expected,
      });
    } catch (_) {/* le suivi ne doit jamais gêner un paiement */}
  }

  // ── Rémunération ───────────────────────────────────────────────────────────

  /// [period] : today, week, month30, thisMonth.
  static Future<Map<String, dynamic>> remuneration(String period) async => _map(await _c.get('/admin/remuneration', query: {'period': period}));

  // ── Informations et annonces de l'application ──────────────────────────────

  static Future<({List<Map<String, dynamic>> items, bool hasMore})> infos({String type = 'APPINFO', int page = 1, int limit = 5}) async {
    final r = await _c.get('/infos', query: {'type': type, 'page': page, 'limit': limit});
    return (items: _list(r), hasMore: r is Map && r['has_more'] == true);
  }

  static Future<void> viewInfo(String id) => _c.post('/infos/$id/view');

  /// Retourne le nombre de j'aime après l'action.
  static Future<int> setInfoLike(String id, bool liked) async =>
      (_map(liked ? await _c.put('/infos/$id/like') : await _c.delete('/infos/$id/like'))['likes'] as num?)?.toInt() ?? 0;

  static Future<List<Map<String, dynamic>>> annonces() async => _list(await _c.get('/annonces'));

  /// Envoi d'une image vers le stockage ; renvoie l'identifiant d'envoi à joindre à la création.
  static Future<String> uploadImage(Uint8List bytes, String path) => ArgentUpload.bytes(bytes, contentType: ArgentUpload.imageType(path));

  /// Envoi d'une pièce d'identité (image ou PDF) en stockage PRIVÉ.
  static Future<String> uploadPrivateDocument(Uint8List bytes, String path) {
    final p = path.toLowerCase();
    final type = p.endsWith('.pdf') ? 'application/pdf' : ArgentUpload.imageType(path);
    return ArgentUpload.bytes(bytes, contentType: type, private: true);
  }

  /// Création par l'équipe. Pour APPINFO une image est obligatoire ; la notification à tous est envoyée par le serveur.
  static Future<String> createInfo({required String type, required String title, required String description, String? mediaUploadId, bool featured = false}) async =>
      '${_map(await _c.post('/admin/infos', body: {'type': type, 'title': title, 'description': description, if (mediaUploadId != null) 'media_upload_id': mediaUploadId, 'is_featured': featured}))['id']}';

  static Future<void> setInfoFeatured(String id, bool featured) => _c.patch('/admin/infos/$id', body: {'is_featured': featured});

  static Future<void> deleteInfo(String id) => _c.delete('/admin/infos/$id');

  static Future<String> createAnnonce({required int days, required String mediaUploadId}) async =>
      '${_map(await _c.post('/admin/annonces', body: {'days': days, 'media_upload_id': mediaUploadId}))['id']}';

  // ── Catégories de la boutique (existantes côté API) ────────────────────────

  static Future<void> createCategory(String name) => _c.post('/admin/shop/categories', body: {'name': name});
}
