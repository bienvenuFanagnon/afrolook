import 'package:afrolook_api_client/afrolook_api_client.dart';
import 'package:afrotok/l10n/tr.dart';

/// Lecture des réponses du lot B2 « contenu payant » (épisodes, aperçu d'un code promo, partages, commentaires modifiés) et messages d'erreur
/// traduits. Aucune dépendance à Firebase : ces fonctions se testent seules.

List<Map<String, dynamic>> _rows(dynamic r) {
  final d = r is Map ? r['data'] : r;
  return (d as List? ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
}

Map<String, dynamic> _row(dynamic r) {
  final d = ApiClient.data(r);
  return d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{};
}

int _int(dynamic v) => (v as num?)?.toInt() ?? 0;

/// Un épisode d'une série (`Episode` de la fiche 38). Les fichiers sont privés : ils ne sont JAMAIS dans la fiche, on les demande avec
/// [PaidSeriesApi.access] (lien signé de 10 minutes) après vérification de l'accès par le serveur.
class SeriesEpisode {
  const SeriesEpisode({
    required this.id,
    required this.seriesId,
    required this.number,
    required this.title,
    required this.description,
    required this.contentType,
    required this.isFree,
    required this.priceXof,
    required this.durationSec,
    required this.pageCount,
    required this.thumbnailUrl,
    required this.views,
    required this.likes,
    required this.dislikes,
    required this.shares,
    required this.hasAccess,
    required this.myReaction,
    required this.fileKinds,
    this.createdAt,
  });

  final String id;
  final String seriesId;
  final int number;
  final String title;
  final String description;

  /// `video` ou `ebook`.
  final String contentType;
  final bool isFree;
  final int priceXof;
  final int durationSec;
  final int pageCount;
  final String thumbnailUrl;
  final int views;
  final int likes;
  final int dislikes;
  final int shares;
  final bool hasAccess;

  /// `like`, `dislike` ou null.
  final String? myReaction;

  /// Fichiers présents (`video`, `pdf`) : renseigné par la fiche d'un épisode seulement (`GET /paid-content-episodes/{id}`).
  final List<String> fileKinds;
  final DateTime? createdAt;

  bool get isEbook => contentType == 'ebook';

  factory SeriesEpisode.fromJson(Map<String, dynamic> j) => SeriesEpisode(
        id: '${j['id']}',
        seriesId: '${j['series_id'] ?? ''}',
        number: _int(j['episode_number']),
        title: '${j['title'] ?? ''}',
        description: '${j['description'] ?? ''}',
        contentType: j['content_type'] == 'ebook' ? 'ebook' : 'video',
        isFree: j['is_free'] == true,
        priceXof: _int(j['price_xof']),
        durationSec: _int(j['duration_sec']),
        pageCount: _int(j['page_count']),
        thumbnailUrl: '${j['thumbnail_url'] ?? ''}',
        views: _int(j['views_count']),
        likes: _int(j['likes_count']),
        dislikes: _int(j['dislikes_count']),
        shares: _int(j['shares_count']),
        hasAccess: j['has_access'] == true,
        myReaction: j['my_reaction'] as String?,
        fileKinds: (j['file_kinds'] as List? ?? const []).map((e) => '$e').toList(),
        createdAt: DateTime.tryParse('${j['created_at']}'),
      );

  static List<SeriesEpisode> listFromResponse(dynamic r) => _rows(r).map(SeriesEpisode.fromJson).toList();

  static SeriesEpisode fromResponse(dynamic r) => SeriesEpisode.fromJson(_row(r));

  SeriesEpisode copyWith({int? views, int? likes, int? dislikes, int? shares, String? myReaction, bool clearReaction = false}) => SeriesEpisode(
        id: id,
        seriesId: seriesId,
        number: number,
        title: title,
        description: description,
        contentType: contentType,
        isFree: isFree,
        priceXof: priceXof,
        durationSec: durationSec,
        pageCount: pageCount,
        thumbnailUrl: thumbnailUrl,
        views: views ?? this.views,
        likes: likes ?? this.likes,
        dislikes: dislikes ?? this.dislikes,
        shares: shares ?? this.shares,
        hasAccess: hasAccess,
        myReaction: clearReaction ? null : (myReaction ?? this.myReaction),
        fileKinds: fileKinds,
        createdAt: createdAt,
      );
}

/// Réponse de `GET /paid-content-episodes/{id}/access` : lien signé et durée de validité (0 pour un ancien fichier importé).
class EpisodeAccess {
  const EpisodeAccess({required this.url, required this.expiresIn});

  final String url;
  final int expiresIn;

  factory EpisodeAccess.fromResponse(dynamic r) {
    final m = _row(r);
    return EpisodeAccess(url: '${m['url'] ?? ''}', expiresIn: _int(m['expires_in']));
  }
}

/// Aperçu d'un code promo (`GET /paid-contents/{id}/promo-codes/{code}`). Un code invalide n'est PAS une erreur : `valid` est faux et
/// [reason] vaut `unknown`, `inactive`, `expired` ou `exhausted`. Prix en FCFA ; l'aperçu ne consomme rien.
class PromoPreview {
  const PromoPreview({required this.valid, required this.reason, required this.type, required this.value, required this.priceXof, required this.priceAfterXof});

  final bool valid;
  final String? reason;

  /// `percent` ou `fixed` (null si invalide).
  final String? type;
  final int? value;
  final int priceXof;
  final int priceAfterXof;

  /// Réduction en FCFA.
  int get savingXof => priceXof - priceAfterXof;

  factory PromoPreview.fromResponse(dynamic r) {
    final m = _row(r);
    return PromoPreview(
      valid: m['valid'] == true,
      reason: m['reason'] as String?,
      type: m['type'] as String?,
      value: (m['value'] as num?)?.toInt(),
      priceXof: _int(m['price_xof']),
      priceAfterXof: _int(m['price_after_xof']),
    );
  }

  /// Phrase expliquant pourquoi le code ne marche pas (dans la langue de l'application).
  String get reasonMessage => switch (reason) {
        'inactive' => tr('Ce code n\'est plus actif.'),
        'expired' => tr('Ce code a expiré.'),
        'exhausted' => tr('Ce code a déjà été utilisé le nombre maximum de fois.'),
        _ => tr('Ce code n\'existe pas pour ce contenu.'),
      };
}

/// Réponse des partages (`POST /paid-contents/{id}/share` et `POST /paid-content-episodes/{id}/share`) : `{ok, counted, shares_count}`.
class ShareCounted {
  const ShareCounted({required this.counted, required this.sharesCount});

  final bool counted;
  final int sharesCount;

  factory ShareCounted.fromResponse(dynamic r) {
    final m = _row(r);
    return ShareCounted(counted: m['counted'] != false, sharesCount: _int(m['shares_count']));
  }
}

/// Réponse de `PATCH /paid-content-comments/{id}` : `{id, text, edited_at}`.
class EditedComment {
  const EditedComment({required this.id, required this.text, required this.editedAt});

  final String id;
  final String text;
  final DateTime? editedAt;

  factory EditedComment.fromResponse(dynamic r) {
    final m = _row(r);
    return EditedComment(id: '${m['id']}', text: '${m['text'] ?? ''}', editedAt: DateTime.tryParse('${m['edited_at']}'));
  }
}

/// Messages (dans la langue de l'application) des erreurs du contenu payant ; un code inconnu garde le message du serveur.
class PaidContentMessages {
  PaidContentMessages._();

  static String _generic() => tr('Une erreur est survenue. Réessaie.');

  static String of(Object e) {
    if (e is! ApiException) return _generic();
    if (e.isNetwork) return tr('Connexion impossible. Vérifie ta connexion puis réessaie.');
    return switch (e.code) {
      'not_a_series' => tr('Ce contenu n\'est pas une série.'),
      'series_not_found' => tr('Cette série n\'existe plus.'),
      'episode_number_taken' => tr('Ce numéro d\'épisode est déjà pris.'),
      'upload_not_private' => tr('Le fichier de l\'épisode doit être envoyé en privé.'),
      'upload_invalid' => tr('Le fichier envoyé n\'est pas valide. Réessaie.'),
      'not_purchased' => tr('Achète cette série pour regarder cet épisode.'),
      'no_file' => tr('Cet épisode n\'a pas encore de fichier.'),
      'forbidden' => tr('Tu n\'as pas le droit de faire cela.'),
      'not_found' => tr('Ce contenu n\'est plus disponible.'),
      _ => e.message.isNotEmpty ? e.message : _generic(),
    };
  }
}
