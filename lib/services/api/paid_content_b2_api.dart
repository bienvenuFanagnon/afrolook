import 'package:afrolook_api_client/afrolook_api_client.dart';
import 'package:afrotok/services/api/api_gateway.dart';
import 'package:afrotok/services/api/paid_content_b2_models.dart';

export 'package:afrotok/services/api/paid_content_b2_models.dart';

/// Lot B2 « contenu payant » : épisodes de séries, aperçu d'un code promo, clic d'affiliation, partages, modification d'un commentaire.
/// L'achat se fait sur la SÉRIE : un épisode gratuit est ouvert à tous, les autres à qui a acheté la série (ou la possède). Prix en FCFA.
/// Aucun retour à Firebase : une erreur est remontée à l'écran ([PaidContentMessages.of] + « Réessayer »).
class PaidSeriesApi {
  PaidSeriesApi._();

  static ApiClient get _c => ApiGateway.instance.client;

  /// Épisodes d'une série, classés par numéro (200 au plus). Erreurs : 422 `not_a_series`, 404 `series_not_found`.
  static Future<List<SeriesEpisode>> episodes(String seriesId) async => SeriesEpisode.listFromResponse(await _c.get('/paid-contents/$seriesId/episodes'));

  /// Fiche d'un épisode avec `file_kinds` (null s'il n'existe plus).
  static Future<SeriesEpisode?> episode(String episodeId) async {
    try {
      return SeriesEpisode.fromResponse(await _c.get('/paid-content-episodes/$episodeId'));
    } on ApiException catch (e) {
      if (e.isNotFound) return null;
      rethrow;
    }
  }

  /// Ajoute un épisode (créateur de la série seulement). [videoUploadId] / [pdfUploadId] : envois PRIVÉS déjà confirmés ;
  /// [thumbnailUploadId] : image publique. Erreurs : 403 `forbidden`, 409 `episode_number_taken`, 422 `upload_not_private`, `upload_invalid`, `not_a_series`.
  static Future<SeriesEpisode> create(
    String seriesId, {
    required String title,
    String? description,
    String contentType = 'video',
    int? episodeNumber,
    bool isFree = false,
    int? priceXof,
    int? durationSec,
    int? pageCount,
    String? thumbnailUploadId,
    String? videoUploadId,
    String? pdfUploadId,
  }) async =>
      SeriesEpisode.fromResponse(await _c.post('/paid-contents/$seriesId/episodes', body: {
        'title': title.trim(),
        if (description != null) 'description': description,
        'content_type': contentType,
        if (episodeNumber != null) 'episode_number': episodeNumber,
        'is_free': isFree,
        if (priceXof != null) 'price_xof': priceXof,
        if (durationSec != null) 'duration_sec': durationSec,
        if (pageCount != null) 'page_count': pageCount,
        if (thumbnailUploadId != null) 'thumbnail_upload_id': thumbnailUploadId,
        if (videoUploadId != null || pdfUploadId != null)
          'files': {
            if (videoUploadId != null) 'video': videoUploadId,
            if (pdfUploadId != null) 'pdf': pdfUploadId,
          },
      }));

  /// Modifie un épisode (créateur) : seuls les champs de [fields] changent (mêmes noms que la création).
  static Future<SeriesEpisode> update(String episodeId, Map<String, dynamic> fields) async =>
      SeriesEpisode.fromResponse(await _c.patch('/paid-content-episodes/$episodeId', body: fields));

  /// Supprime un épisode (créateur ou administrateur ; le numéro redevient libre).
  static Future<void> delete(String episodeId) => _c.delete('/paid-content-episodes/$episodeId');

  /// Lien signé du fichier [fileKey] (`video` ou `pdf`) de l'épisode, valable 10 minutes. Erreurs : 403 `not_purchased`, 404 `no_file`.
  static Future<EpisodeAccess> access(String episodeId, {String? fileKey}) async =>
      EpisodeAccess.fromResponse(await _c.get('/paid-content-episodes/$episodeId/access', query: {if (fileKey != null) 'file_key': fileKey}));

  /// J'aime / je n'aime pas ([kind] : `like` ou `dislike`) ; une réaction par personne, la changer déplace le compteur.
  static Future<void> react(String episodeId, String kind) => _c.put('/paid-content-episodes/$episodeId/reactions/$kind');

  static Future<void> unreact(String episodeId) => _c.delete('/paid-content-episodes/$episodeId/reactions');

  static final Set<String> _viewed = {};

  /// Compte ma vue (une seule fois par personne, côté serveur). Jamais bloquant : une erreur est ignorée et la vue sera retentée plus tard.
  static Future<void> view(String episodeId) async {
    if (!_viewed.add(episodeId)) return;
    try {
      await _c.post('/paid-content-episodes/$episodeId/view');
    } catch (_) {
      _viewed.remove(episodeId);
    }
  }

  /// Compte un partage (une fois par personne) et renvoie le total tenu par le serveur.
  static Future<ShareCounted> share(String episodeId) async => ShareCounted.fromResponse(await _c.post('/paid-content-episodes/$episodeId/share'));
}

/// Compléments du contenu payant (hors épisodes) du lot B2.
class PaidExtrasApi {
  PaidExtrasApi._();

  static ApiClient get _c => ApiGateway.instance.client;

  /// Aperçu d'un code promo pour ce contenu : prix avant / après, ou motif du refus. Ne consomme rien, 20 essais par minute (429 au-delà).
  /// La casse du code est ignorée.
  static Future<PromoPreview> previewPromo(String contentId, String code) async =>
      PromoPreview.fromResponse(await _c.get('/paid-contents/$contentId/promo-codes/${Uri.encodeComponent(code.trim())}'));

  /// Clic sur un lien d'affiliation (`affiliateId` = identifiant de la personne qui a partagé). Compté une fois par personne, par lien et par jour ;
  /// jamais pour le partageur lui-même. Renvoie faux si ce clic n'a pas été compté. 404 si le partageur n'a pas de lien pour ce contenu.
  static Future<bool> affiliateClick(String contentId, String affiliateId) async {
    final d = ApiClient.data(await _c.post('/paid-contents/$contentId/affiliate-click', body: {'affiliate_id': affiliateId}));
    return d is Map ? d['counted'] == true : false;
  }

  /// Compte un partage du contenu (une fois par personne) et renvoie le total du serveur.
  static Future<ShareCounted> share(String contentId) async => ShareCounted.fromResponse(await _c.post('/paid-contents/$contentId/share'));

  /// Modifie MON commentaire (1 à 1000 caractères). Erreur 403 pour tout autre auteur, même le créateur du contenu.
  static Future<EditedComment> editComment(String commentId, String text) async =>
      EditedComment.fromResponse(await _c.patch('/paid-content-comments/$commentId', body: {'text': text.trim()}));
}
