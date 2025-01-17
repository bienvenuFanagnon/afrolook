// Dart imports:
import 'dart:typed_data';
import 'dart:ui' as ui;

// Flutter imports:
import 'package:afrotok/pages/userPosts/utils/postLookImageTab.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:image_watermark/image_watermark.dart';
import 'package:permission_handler/permission_handler.dart';

// Package imports:
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:image/image.dart' as img;

// Project imports:

/// A mixin that provides helper methods and state management for image editing
/// using the [ProImageEditor]. It is intended to be used in a [StatefulWidget].
mixin ExampleHelperState<T extends StatefulWidget> on State<T> {
  /// The global key used to reference the state of [ProImageEditor].
  final editorKey = GlobalKey<ProImageEditorState>();

  /// Holds the edited image bytes after the editing is complete.
  Uint8List? editedBytes;

  /// The time it took to generate the edited image in milliseconds.
  double? _generationTime;

  /// Records the start time of the editing process.
  DateTime? startEditingTime;

  /// Called when the image editing process starts.
  /// Records the time when editing began.
  Future<void> onImageEditingStarted() async {
    startEditingTime = DateTime.now();
  }

  /// Called when the image editing process is complete.
  /// Saves the edited image bytes and calculates the generation time.
  ///
  /// [bytes] is the edited image in bytes.
  Future<void> onImageEditingComplete(Uint8List bytes) async {
    editedBytes = bytes;
    setGenerationTime();
  }

  /// Calculates the time taken for the image generation in milliseconds
  /// and stores it in [_generationTime].
  void setGenerationTime() {
    if (startEditingTime != null) {
      _generationTime = DateTime.now()
          .difference(startEditingTime!)
          .inMilliseconds
          .toDouble();
    }
  }
  Uint8List? watermarkedImgBytes;
  Future<Uint8List?> applyWatermark(Uint8List imgBytes) async {
    // String watermarkText = "@Afrolook @${authProvider.loginUserData.pseudo}";
    String watermarkText = "@Afrolook";
    final assetFont = await rootBundle.load('assets/fonts/file.zip');
    Uint8List file = assetFont.buffer.asUint8List(assetFont.offsetInBytes, assetFont.lengthInBytes);
    // Obtenir la taille de l'image
    img.Image? image = img.decodeImage(Uint8List.fromList(imgBytes));
    final imgWidth = image!.width;
    final imgHeight = image!.height;

    // Ajustement des coordonnées (marge de 20 pixels)
    final dstX = imgWidth - 300;  // Décale vers la droite
    final dstY = imgHeight - 60;  // Décale vers le bas
    watermarkedImgBytes =
    await ImageWatermark.addTextWatermark(

      ///image bytes
      imgBytes: imgBytes!,
      color: Colors.green,

      /// Change font
      // font:ImageFont.readOtherFontZip(file!),
      // font:ImageFont.readOtherFont("NINO",imgBytes),
      // font:null,

// rightJustify: true,
      ///watermark text
      watermarkText: watermarkText,
      dstX: dstX,
      dstY: dstY,

    );

    return watermarkedImgBytes;
  }

  Future<bool> _saveImage(Uint8List? image) async {
    try {
      if (image == null) return false;

      // Demander les permissions
      if (await Permission.storage.request().isGranted ||
          await Permission.photos.request().isGranted) {
        // Enregistrer l'image dans la galerie
        final result = await ImageGallerySaverPlus.saveImage(image);
        print(result);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Image enregistrée dans la galerie', style: TextStyle(color: Colors.white)),
            backgroundColor: Colors.green,
          ),
        );
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
  Future<Uint8List?> _openPickerText(Uint8List? bytes) async {

    if (bytes != null) {
      // Uint8List? watermarkedBytes = await applyWatermarkAndNavigate(bytes);
      Uint8List? watermarkedBytes = await applyWatermark(bytes);
      if (watermarkedBytes != null) {
        if (!mounted){
          return watermarkedBytes;
        }else{
          await precacheImage(MemoryImage(watermarkedBytes), context);
          _saveImage(watermarkedBytes);
          return watermarkedBytes;

        }

        // _loadingController.add(false);
        // Provider.of<UserAuthProvider>(context, listen: false).setLoading(false);

      }

    }

  }

  /// Closes the image editor and navigates to a preview page showing the
  /// edited image.
  ///
  /// If [showThumbnail] is true, a thumbnail of the image will be displayed.
  /// The [rawOriginalImage] can be passed if the unedited image needs to be
  /// shown.
  /// The [generationConfigs] can be used to pass additional configurations for
  /// generating the image.
  ///
  void onCloseEditor({
    bool showThumbnail = false,
    ui.Image? rawOriginalImage,
    final ImageGenerationConfigs? generationConfigs,
  }) async {
    if (editedBytes != null) {
      // Pre-cache the edited image to improve display performance.
      await precacheImage(MemoryImage(editedBytes!), context);
      if (!mounted) return;

      // Navigate to the preview page to display the edited image.
      editorKey.currentState?.disablePopScope = true;
      //  Navigator.pop(context);
      // Navigator.pop(context);
      _openPickerText(editedBytes).then((value) async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) {
              return PostLookImageTab(
                imgBytes: value!,
                generationTime: _generationTime,
                showThumbnail: showThumbnail,
                rawOriginalImage: rawOriginalImage,
                generationConfigs: generationConfigs,
              );
            },
          ),
        ).whenComplete(() {
          // Reset the state variables after navigation.
          editedBytes = null;
          _generationTime = null;
          startEditingTime = null;
        });
      },);

    }

    // Close the editor if no image editing is done.
    if (mounted) Navigator.pop(context);
  }
}
