import 'dart:io';
import 'dart:typed_data';

import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/services/api/posts_api.dart';

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
    void Function(double)? onProgress,
  }) async {
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

    final codes = countries.map((c) => c.toUpperCase()).where((c) => RegExp(r'^[A-Z]{2}$').hasMatch(c)).toSet().toList();
    return PostsApi.create(
      description: description,
      linkUrl: linkUrl,
      category: category,
      isMonetized: monetized,
      uploadIds: ids,
      countries: codes.length > 60 || codes.isEmpty ? const ['ALL'] : codes,
      interests: interests,
      channelId: canal?.id,
      freePreview: freePreview,
    );
  }
}
