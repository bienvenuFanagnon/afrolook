import 'download_util_io.dart'
    if (dart.library.html) 'download_util_web.dart';

export 'download_util_io.dart'
    if (dart.library.html) 'download_util_web.dart';

class DownloadResult {
  final bool success;
  final String? filePath; // null sur web (navigateur gère)
  final String? error;

  const DownloadResult({
    required this.success,
    this.filePath,
    this.error,
  });
}

/// Lance le téléchargement et retourne le résultat.
/// [onProgress] : callback 0.0→1.0 pendant le téléchargement (mobile seulement).
Future<DownloadResult> downloadFile({
  required String url,
  required String fileName,
  void Function(double progress)? onProgress,
}) =>
    performDownload(url: url, fileName: fileName, onProgress: onProgress);
