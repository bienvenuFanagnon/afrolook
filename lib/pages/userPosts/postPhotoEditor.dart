// Dart imports:
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:afrotok/models/model_data.dart';
import 'package:path/path.dart' as path;

// Flutter imports:
import 'package:afrotok/pages/component/consoleWidget.dart';
import 'package:afrotok/pages/userPosts/uniqueDesign.dart';
import 'package:afrotok/pages/userPosts/utils/example_helper.dart';
import 'package:afrotok/pages/userPosts/postTabs/postLookImageTab.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_watermark/image_watermark.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:path/path.dart' as Path;
import 'package:image/image.dart' as img;

// Package imports:
import 'package:image_picker/image_picker.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:provider/provider.dart';
import '../../constant/constColors.dart';
import '../../providers/authProvider.dart';
import '../../providers/postProvider.dart';
import '../../providers/userProvider.dart';
import 'materialEditor.dart';

// Project imports:

/// The example how to pick images from the gallery or with the camera.
class PostPhotoEditor extends StatefulWidget {
  /// Creates a new [PostPhotoEditor] widget.
  final Canal? canal;
  const PostPhotoEditor({super.key, required this.canal});

  @override
  State<PostPhotoEditor> createState() => _PostPhotoEditorState();
}

class _PostPhotoEditorState extends State<PostPhotoEditor>
    with ExampleHelperState<PostPhotoEditor> {

  final _formKey = GlobalKey<FormState>();

  GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final TextEditingController _titreController = TextEditingController();

  final TextEditingController _descriptionController = TextEditingController();
  late PostProvider postProvider =
  Provider.of<PostProvider>(context, listen: false);
  late UserAuthProvider authProvider =
  Provider.of<UserAuthProvider>(context, listen: false);

  late UserProvider userProvider =
  Provider.of<UserProvider>(context, listen: false);
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  bool onTap = false;

  late List<XFile> listimages = [];

  final ImagePicker picker = ImagePicker();
  late  Uint8List? fileReadAsStringContent;
  int  limitePosts = 30;

  Future<void> _getImages() async {
    await picker.pickMultiImage().then((images) {
      // Mettre à jour la liste des images
      setState(() async {
        listimages =
            images.where((image) => images.indexOf(image) < 2).toList();
        images.first.readAsBytes().then((value) {
          fileReadAsStringContent =value;
        },);

      });
    });
  }

// Fonction pour ajouter un cadre, le nom "Afrolook" sur chaque côté et le pseudo utilisateur
//   Future<Uint8List?> addCustomWatermark(Uint8List imgBytes, String userPseudo) async {
//     // Décoder l'image en Uint8List
//     img.Image image = img.decodeImage(Uint8List.fromList(imgBytes))!;
//     int imageWidth = image.width;
//     int imageHeight = image.height;
//
//     // Définir les couleurs
//     final Color frameColor = Color(0xFF000000); // Noir pour le cadre
//     final Color textColor = Color(0xFF00FF00); // Vert pour le texte
//     final double textSize = 20.0; // Taille du texte
//
//     // Créer une image vide pour y dessiner le cadre et les textes
//     img.Image watermarkedImage = img.Image(imageWidth, imageHeight);
//
//     // Remplir l'image d'origine avec la nouvelle image
//     img.copyCrop(watermarkedImage, x: null, y: null, width: null, height: null);
//
//     // Dessiner un cadre autour de l'image
//     img.drawRect(watermarkedImage, img.Rect(0, 0, imageWidth - 1, imageHeight - 1), img.getColor(0, 0, 0), x1: null, y1: null, x2: null, y2: null, color: null);
//
//     // Ajouter le nom "Afrolook" sur chaque côté du cadre
//     String appName = "Afrolook";
//
//     // Calculer la position du texte sur chaque côté
//     img.drawRect(
//       watermarkedImage,
//       img.arial_48, // Utiliser une police standard ici (vous pouvez en ajouter une custom)
//       (imageWidth - (appName.length * textSize)) ~/ 2,
//       10,
//       appName,
//       color: img.ColorFloat16.rgb(0, 255, 0), x1: null, y1: null, x2: null, y2: null, // Texte vert
//     );
//
//     img.drawRect(
//       watermarkedImage,
//       img.arial_48, // Vous pouvez également utiliser votre propre police
//       (imageWidth - (appName.length * textSize)) ~/ 2,
//       imageHeight - 30,
//       appName,
//       color: img.ColorFloat16.rgb(0, 255, 0), x1: null, y1: null, x2: null, y2: null, // Texte vert
//     );
//
//     // Ajouter le pseudo de l'utilisateur dans le coin inférieur droit
//     img.drawRect(
//       watermarkedImage,
//       img.arial_48, // Vous pouvez remplacer par votre propre police
//       imageWidth - 100,
//       imageHeight - 50,
//       userPseudo,
//       color: img.ColorFloat16.rgb(0, 255, 0), x1: null, y1: null, x2: null, y2: null, // Texte vert
//     );
//
//     // Convertir l'image modifiée en Uint8List
//     return Uint8List.fromList(img.encodePng(watermarkedImage));
//   }


  Future<Uint8List?> addWatermark(Uint8List imgBytes) async {
    printVm("addWatermark start");

    // Décoder l'image pour obtenir ses dimensions
    final image = await decodeImageFromList(imgBytes);
    final imageWidth = image.width;
    final imageHeight = image.height;

    // Calcul de la largeur et de la hauteur approximatives du texte
    final watermarkText = '@Afrolook';
    final textWidth = watermarkText.length*8;  // Largeur approximative du texte
    final textHeight = 10;  // Hauteur approximative du texte

    // Calcul des positions pour afficher le texte en bas à droite
    final dstX = imageWidth - textWidth - 180;  // 10 pixels de marge à droite
    final dstY = imageHeight - textHeight - 50;  // 10 pixels de marge en bas

    // Ajouter le texte en bas à droite
    Uint8List? finalImage = await ImageWatermark.addTextWatermark(
      imgBytes: imgBytes,
      color: Colors.green,

      dstX: dstX.toInt(),
      dstY: dstY.toInt(),
      watermarkText: watermarkText,
    );

    if (finalImage == null) {
      return null;
    }

    printVm("addWatermark saved");

    return finalImage;
  }

  Future<Uint8List?> applyWatermarkAndNavigate(Uint8List imgBytes) async {
    printVm("applyWatermarkAndNavigate... start");

    // Charger l'image de fond (frame)
    ByteData data = await rootBundle.load('assets/images/frame1.jpg');
    Uint8List logoBytes = data.buffer.asUint8List();

    // Décoder les images
    img.Image? image = img.decodeImage(Uint8List.fromList(imgBytes));
    img.Image? logoImage = img.decodeImage(Uint8List.fromList(logoBytes));
    if (image == null || logoImage == null) {
      printVm("Erreur de décodage des images.");
      return null;
    }

    int logoWidth = logoImage.width;
    int logoHeight = logoImage.height;

    // Ajuster la taille de l'image sélectionnée pour qu'elle couvre bien l'espace prévu
    int selectedImageWidth = (logoWidth * 0.8).toInt();  // 90% pour un meilleur ajustement
    int selectedImageHeight = (logoHeight * 0.8).toInt();
    //
    // int selectedImageWidth = 500;  // 90% pour un meilleur ajustement
    // int selectedImageHeight = 400;

    // Redimensionner l'image sélectionnée
    img.Image resizedImage = img.copyResize(image, width: selectedImageWidth, height: selectedImageHeight);

    // Vérifier les nouvelles dimensions
    printVm("Logo: $logoWidth x $logoHeight, Resized: $selectedImageWidth x $selectedImageHeight");

    // Ajuster l'alignement pour éviter les zones noires
    int dstX = (logoWidth - selectedImageWidth) ~/ 2;
    int dstY = (logoHeight - selectedImageHeight) ~/ 2;
    // int dstX = 0;
    // int dstY = 0;
    // S'assurer que l'image sélectionnée reste bien dans les limites
    dstX = dstX.clamp(0, logoWidth - selectedImageWidth);
    dstY = dstY.clamp(0, logoHeight - selectedImageHeight);

    // Fusionner les images
    Uint8List? watermarkedImgBytes = await ImageWatermark.addImageWatermark(
      originalImageBytes: logoBytes,
      waterkmarkImageBytes: Uint8List.fromList(img.encodePng(resizedImage)),
      // imgWidth: logoWidth,
      // imgHeight: logoHeight
      imgWidth: selectedImageWidth,
      imgHeight: selectedImageHeight,
      dstX: dstX,
      dstY: dstY,
    );

    printVm("applyWatermarkAndNavigate... finished");
    return watermarkedImgBytes;
  }
  Future<XFile> compressImageFile2(File file, String targetPath) async {
    var result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      quality: 90, // Ajustez la qualité selon vos besoins (0-100)
      minWidth: 1920, // Largeur minimale de l'image compressée
      minHeight: 1080, // Hauteur minimale de l'image compressée
    );

    print('Taille originale: ${file.lengthSync()} bytes');
    print('Taille compressée: ${result!.length()} bytes');

    return result;
  }
  Future<XFile> compressImageFile(
      {
        required File imageFile,
        int quality = 80,
        CompressFormat format = CompressFormat.jpeg
      })
  async {

    DateTime time = DateTime.now();
    final String targetPath = path.join(
        Directory.systemTemp.path, 'imagetemp-${format.name}-$quality-${time.second}.${format.name}'
    );
    printVm('debut compression *******************');

    final XFile? compressedImageFile = await FlutterImageCompress.compressAndGetFile(
        imageFile.path,
        targetPath,
        quality: quality,
        format: format
    );


    printVm('fin compression *******************');

    if (compressedImageFile == null){
      throw ("Image compression failed! Please try again.");
    }
    debugPrint("Compressed image saved to: ${compressedImageFile.path}");
    return compressedImageFile;
  }

  Future<Uint8List> testComporessList(Uint8List list) async {
    var result = await FlutterImageCompress.compressWithList(
      list,
      minHeight: 1920,
      minWidth: 1080,
      quality: 50,
      rotate: 0,
    );

    print('Taille originale: ${list.length} bytes');
    print('Taille compressée: ${result!.length} bytes');
    print(list.length);
    print(result.length);
    return result;
  }

  void _openPicker(ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: source);
      if (image == null) return;
      String? path;
      Uint8List? bytes;
      // bytes = await image.readAsBytes();
      // String targetPath =_generateRandomFileName(File.fromRawPath(bytes));
      // compressImageFile(
      //     imageFile: File.fromRawPath(await image.readAsBytes())!,
      //     quality: 10
      // );
      bytes = await    testComporessList(
     await image.readAsBytes()!,
      );
      // bytes =await imageCompress.readAsBytes();
      // bytes = await testCompressFile(File.fromRawPath(await image.readAsBytes()));
      final random = Random();
      final randomString = String.fromCharCodes(List.generate(10, (index) => random.nextInt(33) + 89));


      // XFile compressedFile = await compressImageFile(File.fromRawPath(bytes), targetPath);
      // bytes =await compressedFile.readAsBytes();
      printVm("bytes: **** :  ${bytes}");
      if (bytes != null) {
        // Appliquer le filigrane sur l'image sélectionnée
        // Provider.of<UserAuthProvider>(context, listen: false).setLoading(true);

        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => Uniquedesign(initialImage:bytes!, canal: widget.canal==null?null:widget.canal!, ),
          ),
        );
        // Uint8List? watermarkedBytes = await addWatermark(bytes);
        // if (watermarkedBytes != null) {
        //   if (!mounted) return;
        //   // Précacher l'image avec filigrane
        //   await precacheImage(MemoryImage(watermarkedBytes), context);
        //   printVm("Navigation vers l'éditeur...");
        //   // Naviguer vers l'éditeur d'image avec l'image modifiée
        //   await Navigator.push(
        //     context,
        //     MaterialPageRoute(
        //       builder: (context) => UniqueAfrolookDesign(initialImage:watermarkedBytes! ),
        //     ),
        //   );
        // }
      }
    } catch (e) {
      printVm('erreur image: $e');
    }
  }


  void _chooseCameraOrGallery() async {
    /// Open directly the gallery if the camera is not supported
    if (!kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      _openPicker(ImageSource.gallery);
      return;
    }

    if (!kIsWeb && Platform.isIOS) {
      await showCupertinoModalPopup(
        context: context,
        builder: (BuildContext context) => CupertinoTheme(
          data: const CupertinoThemeData(),
          child: CupertinoActionSheet(
            actions: <CupertinoActionSheetAction>[
              CupertinoActionSheetAction(
                onPressed: () => _openPicker(ImageSource.camera),
                child: const Wrap(
                  spacing: 7,
                  runAlignment: WrapAlignment.center,
                  children: [
                    Icon(CupertinoIcons.photo_camera),
                    Text('Camera'),
                  ],
                ),
              ),
              CupertinoActionSheetAction(
                onPressed: () => _openPicker(ImageSource.gallery),
                child: const Wrap(
                  spacing: 7,
                  runAlignment: WrapAlignment.center,
                  children: [
                    Icon(CupertinoIcons.photo),
                    Text('Gallery'),
                  ],
                ),
              ),
            ],
            cancelButton: CupertinoActionSheetAction(
              isDefaultAction: true,
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
          ),
        ),
      );
    } else {
      await showModalBottomSheet(
        context: context,
        showDragHandle: true,
        constraints: BoxConstraints(
          minWidth: min(MediaQuery.of(context).size.width, 360),
        ),
        builder: (context) {
          return Material(
            color: Colors.transparent,
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
                child: Wrap(
                  spacing: 45,
                  runSpacing: 30,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  runAlignment: WrapAlignment.center,
                  alignment: WrapAlignment.spaceAround,
                  children: [
                    MaterialIconActionButton(
                      primaryColor: const Color(0xFFEC407A),
                      secondaryColor: const Color(0xFFD3396D),
                      icon: Icons.photo_camera,
                      text: 'Camera',
                      onTap: () => _openPicker(ImageSource.camera),
                    ),
                    MaterialIconActionButton(
                      primaryColor: const Color(0xFFBF59CF),
                      secondaryColor: const Color(0xFFAC44CF),
                      icon: Icons.image,
                      text: 'Gallery',
                      onTap: () => _openPicker(ImageSource.gallery),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text("Type post: ${widget.canal==null?"Look":"Canal"}"),
                  ),
                  // TextFormField(
                  //   controller: _descriptionController,
                  //   decoration: InputDecoration(
                  //     hintText: 'Légende',
                  //     border: OutlineInputBorder(
                  //       borderRadius: BorderRadius.circular(10.0), // Add rounded corners
                  //       borderSide: BorderSide(color: Colors.blue, width: 2.0), // Customize color and thickness
                  //     ),
                  //   ),
                  //   maxLines: 2,
                  //   maxLength: 400,
                  //   validator: (value) {
                  //     if (value!.isEmpty) {
                  //       return 'La légende est obligatoire';
                  //     }
                  //
                  //     return null;
                  //   },
                  // ),
                  SizedBox(
                    height: 25.0,
                  ),

                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.all(Radius.circular(20)),
                      child: Container(
                        alignment: Alignment.center,
                        color: ConstColors.buttonsColors,
                        // width: largeur,
                        // height: hauteur,
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: ListTile(
                            onTap: _chooseCameraOrGallery,
                            leading: const Icon(Icons.attachment_outlined),
                            title: const Text("Galerie ou Appareil photo",style: TextStyle(fontSize: 16),),
                            subtitle: !kIsWeb &&
                                (Platform.isWindows || Platform.isLinux || Platform.isMacOS)
                                ? const Text('The camera is not supported on this platform.')
                                : null,
                            trailing: const Icon(Icons.chevron_right),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditor({String? path, Uint8List? bytes}) {
    if (path != null) {
      return ProImageEditor.file(
        File(path),
        callbacks: ProImageEditorCallbacks(
          onImageEditingStarted: onImageEditingStarted,
          onImageEditingComplete: onImageEditingComplete,
          onCloseEditor: () {
            onCloseEditor(canal: widget.canal!);
          },
        ),
        configs: ProImageEditorConfigs(
          designMode: platformDesignMode,
        ),
      );
    } else {
      return ProImageEditor.memory(
        bytes!,
        callbacks: ProImageEditorCallbacks(
          onImageEditingStarted: onImageEditingStarted,
          onImageEditingComplete: onImageEditingComplete,
          onCloseEditor: () {
            onCloseEditor(canal: widget.canal!);
          },        ),
        configs: ProImageEditorConfigs(
          designMode: platformDesignMode,
        ),
      );
    }
  }
}
