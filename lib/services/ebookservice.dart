import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'dart:isolate';

class EbookDownloader {
  static ReceivePort _port = ReceivePort();

  static void registerCallback() {
    IsolateNameServer.registerPortWithName(_port.sendPort, 'downloader_send_port');

    _port.listen((dynamic data) {
      String id = data[0];
      int status = data[1];
      int progress = data[2];

      print('Task ($id) status: $status, progress: $progress%');
    });

    FlutterDownloader.registerCallback(downloadCallback);
  }

  @pragma('vm:entry-point')
  static void downloadCallback(String id, int status, int progress) {
    final SendPort? send = IsolateNameServer.lookupPortByName('downloader_send_port');
    send?.send([id, status, progress]);
  }

  static Future<void> downloadEbook(BuildContext context, String pdfUrl, String title) async {
    try {
      if (pdfUrl.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Aucun ebook disponible'), backgroundColor: Colors.red),
        );
        return;
      }

      final directory = await getApplicationDocumentsDirectory();
      final downloadPath = directory.path;

      final fileName =
          '${title.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}_${DateTime.now().millisecondsSinceEpoch}.pdf';

      final taskId = await FlutterDownloader.enqueue(
        url: pdfUrl,
        savedDir: downloadPath,
        fileName: fileName,
        showNotification: true,
        openFileFromNotification: true,
        headers: {},
        saveInPublicStorage: false, // dossier privé, pas de permission
      );

      if (taskId != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Téléchargement démarré')),
        );
      }
    } catch (e) {
      print('❌ Erreur téléchargement ebook: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur téléchargement: ${e.toString()}'), backgroundColor: Colors.red),
      );
    }
  }
}
