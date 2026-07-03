import 'dart:io';
import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import 'download_util.dart';

Future<DownloadResult> performDownload({
  required String url,
  required String fileName,
  void Function(double progress)? onProgress,
}) async {
  try {
    String savePath;

    if (Platform.isAndroid) {
      // Android 10+ : écriture dans Downloads sans permission
      // Android 9-  : demander WRITE_EXTERNAL_STORAGE
      if (Platform.isAndroid) {
        final info = await Permission.storage.status;
        if (info.isDenied) {
          final result = await Permission.storage.request();
          if (result.isPermanentlyDenied) {
            return DownloadResult(
                success: false,
                error:
                    'Permission de stockage refusée. Activez-la dans les paramètres.');
          }
        }
      }
      // Dossier public Téléchargements
      final dir = Directory('/storage/emulated/0/Download');
      if (!await dir.exists()) {
        final fallback = await getExternalStorageDirectory();
        savePath = '${fallback?.path ?? '/sdcard/Download'}/$fileName';
      } else {
        savePath = '${dir.path}/$fileName';
      }
    } else {
      // iOS / Desktop : dossier documents de l'app
      final dir = await getApplicationDocumentsDirectory();
      savePath = '${dir.path}/$fileName';
    }

    await Dio().download(
      url,
      savePath,
      onReceiveProgress: (received, total) {
        if (total > 0) onProgress?.call(received / total);
      },
    );

    return DownloadResult(success: true, filePath: savePath);
  } catch (e) {
    return DownloadResult(success: false, error: e.toString());
  }
}

Future<void> openDownloadedFile(String filePath) async {
  await OpenFilex.open(filePath);
}
