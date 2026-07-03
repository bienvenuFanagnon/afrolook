// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'download_util.dart';

Future<DownloadResult> performDownload({
  required String url,
  required String fileName,
  void Function(double progress)? onProgress,
}) async {
  try {
    // Sur web, on déclenche le téléchargement natif du navigateur.
    // Le fichier va dans le dossier Téléchargements du navigateur.
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..style.display = 'none';
    html.document.body?.children.add(anchor);
    anchor.click();
    anchor.remove();
    // Le navigateur gère le reste — on ne peut pas suivre la progression
    return DownloadResult(success: true, filePath: null);
  } catch (e) {
    return DownloadResult(success: false, error: e.toString());
  }
}

Future<void> openDownloadedFile(String filePath) async {
  // Sur web, le fichier est déjà dans les téléchargements du navigateur
}
