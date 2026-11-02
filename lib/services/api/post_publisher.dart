import 'dart:io';
import 'dart:typed_data';

import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/services/api/defis_api.dart';
import 'package:afrotok/services/api/posts_api.dart';
import 'package:afrotok/services/template_link.dart';

/// Publication d'un contenu via l'API : téléversement des fichiers (URL signée vers R2, puis confirmation), puis création de la publication.
/// Utilisé par les quatre onglets de création (image, vidéo, audio, texte). Les erreurs sont des `ApiException` à afficher telles quelles.
class PostPublisher {
  PostPublisher._();

  /// Publie. [files] : fichiers locaux déjà prêts (images réduites, vidéo compressée, audio) ; [bytes] : images en mémoire (type [bytesContentType]).
  /// [onProgress] : avancement global 0.0 à 1.0 du téléversement.
  static Future<Post> publish({
    String? description,
    List<File> files = const [],
    List<Uint8List> bytes = const [],
    String bytesContentType = 'image/jpeg',
    String? linkUrl,
    String? category,
    bool monetized = true,
    List<String> countries = const [],
    List<String> interests = const [],
    Canal? canal,
    bool? freePreview,
    DateTime? eventDate,
    File? thumbnail,
    Uint8List? thumbnailBytes,
    String? studioTemplate,
    int? videoWidth,
    int? videoHeight,
    void Function(double)? onProgress,
  }) async {
    final ids = await _upload(files, bytes, bytesContentType, onProgress);
    final thumbId = await _uploadThumbnail(thumbnail, thumbnailBytes);
    return PostsApi.create(
      description: description,
      linkUrl: linkUrl,
      category: category,
      isMonetized: monetized,
      uploadIds: ids,
      countries: _countries(countries),
      interests: interests,
      channelId: canal?.id,
      freePreview: freePreview,
      eventDate: eventDate,
      thumbnailUploadId: thumbId,
      studioTemplate: studioTemplate ?? _currentTemplate(),
      videoWidth: videoWidth,
      videoHeight: videoHeight,
    );
  }

  /// Crée un DÉFI : téléverse les fichiers puis `POST /defis` (la cagnotte est débitée dans la même opération côté serveur).
  /// Un DÉFI n'est jamais monétisé ni publié dans un canal. Erreurs : 402 `insufficient_coins`, 422 `invalid_config`, 403 `account_blocked`…
  static Future<Post> publishDefi({
    required DefiConfig config,
    String? description,
    List<File> files = const [],
    List<Uint8List> bytes = const [],
    String bytesContentType = 'image/jpeg',
    String? linkUrl,
    String? category,
    List<String> countries = const [],
    List<String> interests = const [],
    File? thumbnail,
    Uint8List? thumbnailBytes,
    String? studioTemplate,
    void Function(double)? onProgress,
  }) async {
    final ids = await _upload(files, bytes, bytesContentType, onProgress);
    final thumbId = await _uploadThumbnail(thumbnail, thumbnailBytes);
    return DefisApi.create(
      _defiContent(
        description: description, linkUrl: linkUrl, category: category, uploadIds: ids, countries: countries, interests: interests,
        thumbnailUploadId: thumbId, studioTemplate: studioTemplate ?? _currentTemplate(),
      ),
      config,
    );
  }

  /// Participe à un DÉFI : téléverse les fichiers puis `POST /defis/{id}/participations` (frais éventuels débités et réponse publiée
  /// dans la même opération). [presetId] : identifiant réservé par `DefisApi.reserve` (carte « Vote pour moi » déjà imprimée avec ce lien).
  /// Erreurs : 402, 409 `already_participating` / `defi_ended` / `id_taken`, 422 `reservation_invalid`…
  static Future<Post> participateDefi(
    String defiId, {
    String? description,
    List<File> files = const [],
    List<Uint8List> bytes = const [],
    String bytesContentType = 'image/jpeg',
    String? linkUrl,
    String? category,
    List<String> countries = const [],
    List<String> interests = const [],
    String? presetId,
    File? thumbnail,
    Uint8List? thumbnailBytes,
    String? studioTemplate,
    void Function(double)? onProgress,
  }) async {
    final ids = await _upload(files, bytes, bytesContentType, onProgress);
    final thumbId = await _uploadThumbnail(thumbnail, thumbnailBytes);
    return DefisApi.participate(
      defiId,
      _defiContent(
        description: description, linkUrl: linkUrl, category: category, uploadIds: ids, countries: countries, interests: interests,
        thumbnailUploadId: thumbId, studioTemplate: studioTemplate ?? _currentTemplate(),
      ),
      id: presetId,
    );
  }

  /// Téléverse les fichiers et renvoie leurs identifiants (dans l'ordre : fichiers puis images en mémoire).
  static Future<List<String>> _upload(List<File> files, List<Uint8List> bytes, String bytesContentType, void Function(double)? onProgress) async {
    final total = files.length + bytes.length;
    final ids = <String>[];
    var done = 0;
    void progress(double p) => onProgress?.call(total == 0 ? 1 : (done + p) / total);

    for (final f in files) {
      ids.add(await UploadsApi.upload(f, onProgress: progress));
      done++;
    }
    for (final b in bytes) {
      ids.add(await UploadsApi.uploadBytes(b, contentType: bytesContentType, onProgress: progress));
      done++;
    }
    return ids;
  }

  /// Miniature d'une vidéo : image téléversée à part (`thumbnail_upload_id`). Facultative : un échec ne bloque jamais la publication.
  static Future<String?> _uploadThumbnail(File? file, Uint8List? bytes) async {
    try {
      if (file != null) return await UploadsApi.upload(file, contentType: _imageType(file.path));
      if (bytes != null) return await UploadsApi.uploadBytes(bytes, contentType: 'image/jpeg');
    } catch (_) {}
    return null;
  }

  static String _imageType(String path) {
    final t = UploadsApi.contentTypeFor(path);
    return t.startsWith('image/') ? t : 'image/jpeg';
  }

  /// Référence du template (Studio ou carte) mémorisée pour la publication en cours, ou null.
  static String? _currentTemplate() => PostTemplateLink.fields()['studioTemplate'] as String?;

  /// Pays valides à 2 lettres ; vide ou plus de 60 pays = « tous les pays ».
  static List<String> _countries(List<String> countries) {
    final codes = countries.map((c) => c.toUpperCase()).where((c) => RegExp(r'^[A-Z]{2}$').hasMatch(c)).toSet().toList();
    return codes.length > 60 || codes.isEmpty ? const ['ALL'] : codes;
  }

  /// Contenu d'un DÉFI ou d'une participation, au format de l'API.
  static Map<String, dynamic> _defiContent({
    String? description,
    String? linkUrl,
    String? category,
    required List<String> uploadIds,
    required List<String> countries,
    required List<String> interests,
    String? thumbnailUploadId,
    String? studioTemplate,
  }) =>
      {
        if (description != null && description.trim().isNotEmpty) 'description': description.trim(),
        if (linkUrl != null && linkUrl.trim().isNotEmpty) 'link_url': linkUrl.trim(),
        if (category != null && category.isNotEmpty) 'category': category,
        if (uploadIds.isNotEmpty) 'upload_ids': uploadIds,
        'countries': _countries(countries),
        if (interests.isNotEmpty) 'interests': interests,
        if (thumbnailUploadId != null) 'thumbnail_upload_id': thumbnailUploadId,
        if (studioTemplate != null && studioTemplate.isNotEmpty) 'studio_template': studioTemplate.length > 120 ? studioTemplate.substring(0, 120) : studioTemplate,
      };
}
