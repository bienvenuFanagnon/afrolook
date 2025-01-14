import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:afrotok/pages/component/consoleWidget.dart';
import 'package:afrotok/pages/userPosts/postVideo.dart';
import 'package:afrotok/pages/userPosts/utils/postLookImageTab.dart';
import 'package:afrotok/providers/authProvider.dart';
import 'package:dio/dio.dart';
import 'package:ffmpeg_kit_flutter/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter/return_code.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as path;

import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';

import '../socialVideos/videoPlayer.dart';

class VideoEditorPage extends StatefulWidget {
  final XFile initialVideo;

  VideoEditorPage({required this.initialVideo});

  @override
  _VideoEditorPageState createState() => _VideoEditorPageState();
}

class _VideoEditorPageState extends State<VideoEditorPage> {
  List<String> videoFrames = [];
  late String selectedFrame;
  bool isLoading = false;
  double progress = 50.0;
  String? overlayVideo;

  @override
  void initState() {
    super.initState();
    loadFrames();
  }

  Future<void> loadFrames() async {
    List<String> assetPaths = List.generate(29, (index) => 'assets/frames/${index + 1}.png');
    assetPaths.shuffle();

    setState(() {
      videoFrames = assetPaths;
      if (videoFrames.isNotEmpty) {
        selectedFrame = videoFrames[0];
      }
    });
  }

  Future<void> createVideoWithBackgroundAndBorders(Uint8List videoData, Uint8List imageData) async {
    final tempDir = await getTemporaryDirectory();

    // Générer des noms de fichiers uniques
    final randomSuffix = Random().nextInt(1000000).toString();
    final videoFile = File('${tempDir.path}/temp_video_$randomSuffix.mp4');
    final imageFile = File('${tempDir.path}/temp_image_$randomSuffix.jpg');
    final outputVideoFile = File('${tempDir.path}/output_$randomSuffix.mp4');

    await videoFile.writeAsBytes(videoData);
    await imageFile.writeAsBytes(imageData);

    // Obtenir les dimensions de l'image
    final imageInfo = await decodeImageFromList(imageData);
    final imageWidth = imageInfo.width;
    final imageHeight = imageInfo.height;

    // Créer la vidéo avec l'image de fond, et la vidéo centrée et prenant les dimensions de l'image
    await FFmpegKit.executeAsync(
      '-i ${imageFile.path} -i ${videoFile.path} -filter_complex "[1:v]scale=${imageWidth-100}:${imageHeight-100}[scaled];[0:v][scaled]overlay=(W-w)/2:(H-h)/2,format=yuv420p" -c:a copy ${outputVideoFile.path}',
          (session) async {
        final returnCode = await session.getReturnCode();

        if (ReturnCode.isSuccess(returnCode)) {
          setState(() {
            overlayVideo = outputVideoFile.path;
            isLoading = false;
          });
        }
      },
          (log) => print(log.getMessage()),
          (statistics) {
        // Mise à jour de la progression
        setState(() {
          progress = statistics.getTime().toDouble() / 1000000.0;
        });
      },
    );
  }


  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Text("Vous êtes unique, alors Votre look sera unique", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
        backgroundColor: Colors.green,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: Column(
          children: [
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: videoFrames.length,
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () async {
                      setState(() {
                        selectedFrame = videoFrames[index];
                        isLoading = true;
                        progress = 0.0;
                        overlayVideo=null;
                      });
                      Uint8List videoData = await widget.initialVideo.readAsBytes();
                      ByteData imageData = await rootBundle.load(videoFrames[index]);
                      await createVideoWithBackgroundAndBorders(videoData, imageData.buffer.asUint8List());
                      // await reduceVideoSizeAndQuality(videoData);
                    },
                    child: Container(
                      margin: EdgeInsets.all(8.0),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: selectedFrame == videoFrames[index] ? Colors.yellow : Colors.transparent,
                          width: 3,
                        ),
                      ),
                      child: Image.asset(videoFrames[index], width: 80, height: 80),
                    ),
                  );
                },
              ),
            ),
            if (isLoading)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: LinearProgressIndicator(value: progress, minHeight: 10),
              ),
            Expanded(
              child: Center(
                child: overlayVideo != null
                    ? VideoPlayerWidget(videoUrl: overlayVideo!)
                    : isLoading?Text("Chargement... \nVeuillez patienter un moment",style: TextStyle(color: Colors.green,fontSize: 15,fontWeight: FontWeight.w900),):Text("Sélectionnez un cadre pour appliquer un effet"),
              ),
            ),
            ElevatedButton(
              onPressed: overlayVideo != null ? () async => await _saveVideo(overlayVideo!) : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: Text('Valider et Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  Future<String> getAbsolutePath(String uri) async {
    final file = File(uri);
    if (await file.exists()) {
      return file.path;
    } else {
      final directory = await getApplicationDocumentsDirectory();
      final filePath = path.join(directory.path, path.basename(uri));
      final bytes = await File(uri).readAsBytes();
      await File(filePath).writeAsBytes(bytes);
      return filePath;
    }
  }
  Future<String?> getAbsolutePath3(String uri) async {
    try {
      if (uri.startsWith('content://')) {
        // Lire les octets depuis l’URI
        final ByteData byteData = await rootBundle.load(uri);
        final Uint8List bytes = byteData.buffer.asUint8List();

        // Enregistrer le fichier dans un dossier accessible
        final directory = await getApplicationDocumentsDirectory();
        final filePath = path.join(directory.path, 'video.mp4');
        final file = File(filePath);
        await file.writeAsBytes(bytes);

        return file.path;
      } else {
        final file = File(uri);
        return file.existsSync() ? file.path : null;
      }
    } catch (e) {
      print("Erreur lors de la récupération du chemin absolu : $e");
      return null;
    }
  }
  Future<String> getAbsolutePath2(String uri) async {
    final file = File(uri);
    if (await file.exists()) {
      return file.path;
    } else {
      final directory = await getApplicationDocumentsDirectory();
      final filePath = path.join(directory.path, path.basename(uri));
      final bytes = await File(uri).readAsBytes();
      await File(filePath).writeAsBytes(bytes);
      return filePath;
    }
  }
  Future<bool> _saveVideo2(String videoPath) async {
    try {
      if (videoPath == null) return false;

      // Demander les permissions
      if (await Permission.storage.request().isGranted ||
          await Permission.photos.request().isGranted) {
        // Enregistrer l'image dans la galerie
        // final result = await ImageGallerySaverPlus.saveImage(image);
        await ImageGallerySaverPlus.saveFile(videoPath).then((value) async {

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Vidéo enregistrée dans la galerie', style: TextStyle(color: Colors.white)),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PostVideoUser(videoFilePath: overlayVideo!,),
            ),
          );
        },);
        // print(result);

        return true;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erreur d'enregistrement dans la galerie : Permission refusée", style: TextStyle(color: Colors.white)),
            backgroundColor: Colors.red,
          ),
        );
        return false;
      }
    } catch (e) {
      print('erreur: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur d'enregistrement dans la galerie : $e", style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }
  }
  Future<bool> _saveVideo(String videoPath) async {
    try {
      if (videoPath == null) return false;

      // Demander les permissions
      if (await Permission.storage.request().isGranted ||
          await Permission.photos.request().isGranted) {
        Directory tempDir = await getTemporaryDirectory();
        String tempPath = '${tempDir.path}/temp_video.mp4';

        await XFile(videoPath).saveTo(tempPath);
        printVm('video tempPath : ${tempPath}');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Vidéo enregistrée dans la galerie', style: TextStyle(color: Colors.white)),
            backgroundColor: Colors.green,
          ),
        );
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PostVideoUser(videoFilePath: tempPath!),
          ),
        );

        // await ImageGallerySaver.saveFile(savePath);
        // Enregistrer la vidéo dans la galerie
        // await ImageGallerySaverPlus.saveFile(savePath).then((result) async {
        //   ScaffoldMessenger.of(context).showSnackBar(
        //     SnackBar(
        //       content: Text('Vidéo enregistrée dans la galerie', style: TextStyle(color: Colors.white)),
        //       backgroundColor: Colors.green,
        //     ),
        //   );
        //   printVm('video enregistrerpath : ${result}');
        //   String absolutePath='';
        //   // Récupérer le chemin de la vidéo enregistrée
        //   final savedVideoPath = result['filePath'];
        //   await Navigator.push(
        //     context,
        //     MaterialPageRoute(
        //       builder: (context) => PostVideoUser(videoFilePath: savedVideoPath!),
        //     ),
        //   );
        //   //  await getAbsolutePath(savedVideoPath).then((value) async {
        //   //   printVm('absolutePath: ${value!}');
        //   //   absolutePath=value;
        //   //   // Naviguer vers la nouvelle page avec le chemin de la vidéo
        //   //   await Navigator.push(
        //   //     context,
        //   //     MaterialPageRoute(
        //   //       builder: (context) => PostVideoUser(videoFilePath: savedVideoPath!),
        //   //     ),
        //   //   );
        //   // },);
        //
        //
        // });

        return true;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erreur d'enregistrement dans la galerie : Permission refusée", style: TextStyle(color: Colors.white)),
            backgroundColor: Colors.red,
          ),
        );
        return false;
      }
    } catch (e) {
      print('erreur: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur d'enregistrement dans la galerie : $e", style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }
  }

}
