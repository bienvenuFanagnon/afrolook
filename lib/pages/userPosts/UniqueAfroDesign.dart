
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:afrotok/pages/component/consoleWidget.dart';
import 'package:afrotok/pages/userPosts/utils/postLookImageTab.dart';
import 'package:afrotok/providers/authProvider.dart';
import 'package:afrotok/pages/userPosts/utils/example_helper.dart';
import 'package:afrotok/pages/userPosts/utils/example_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:image_watermark/image_watermark.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:provider/provider.dart';

class UniqueAfrolookDesign extends StatefulWidget {
  final Uint8List initialImage;

  UniqueAfrolookDesign({required this.initialImage});

  @override
  _UniqueAfrolookDesignState createState() => _UniqueAfrolookDesignState();
}

class _UniqueAfrolookDesignState extends State<UniqueAfrolookDesign>  with ExampleHelperState<UniqueAfrolookDesign>{
  List<Uint8List> images = [];
  late Uint8List selectedImage;
  bool isLoading=false;
  Uint8List? overlayImage;
  Uint8List? initialImage;
  final StreamController<bool> _loadingController = StreamController<bool>();
  late UserAuthProvider authProvider =
  Provider.of<UserAuthProvider>(context, listen: false);

  @override
  void initState() {
    super.initState();
    overlayImage = widget.initialImage;
    initialImage = widget.initialImage;
    loadImages();
  }

  @override
  void dispose() {
    _loadingController.close();
    super.dispose();
  }
  Widget _buildEditor({String? path, Uint8List? bytes}) {
    if (path != null) {
      return ProImageEditor.file(
        File(path),
        callbacks: ProImageEditorCallbacks(
          onImageEditingStarted: onImageEditingStarted,
          onImageEditingComplete: onImageEditingComplete,
          onCloseEditor: onCloseEditor,
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
          onCloseEditor: onCloseEditor,
        ),
        configs: ProImageEditorConfigs(
          designMode: platformDesignMode,
        ),
      );
    }
  }

  Future<void> loadImages() async {
    _loadingController.add(true);

    List<String> assetPaths = [

      'assets/frames/7.png',
      'assets/frames/8.png',
      'assets/frames/9.png',
      'assets/frames/10.png',
      'assets/frames/11.png',
      'assets/frames/12.png',
      'assets/frames/13.png',
      'assets/frames/23.png',
      'assets/frames/24.png',
      'assets/frames/25.png',
      'assets/frames/26.png',
      'assets/frames/27.png',
      'assets/frames/28.png',
      'assets/frames/29.png',
    ];

    List<Uint8List> loadedImages = [];
    assetPaths.shuffle();
    assetPaths.shuffle();
    for (String path in assetPaths) {
      ByteData data = await rootBundle.load(path);
      Uint8List bytes = data.buffer.asUint8List();
      loadedImages.add(bytes);
    }

    setState(() {
      images = loadedImages;
      if (images.isNotEmpty) {
        selectedImage = images[0];
isLoading=true;
      }
    });
    await Future.delayed(Duration(seconds: 1));

    // await   _openPickerText(overlayImage);
    setState(() {
      isLoading=false;

    });
    printVm('fin loading');
    Provider.of<UserAuthProvider>(context, listen: false).setLoading(false);
    setState(() {

    });

  }
  Future<void> _openPicker(Uint8List? bytes) async {

    if (bytes != null) {
      Uint8List? watermarkedBytes = await applyWatermarkAndNavigate(bytes);
      // Uint8List? watermarkedBytes = await applyWatermark(bytes);
      if (watermarkedBytes != null) {
        if (!mounted) return;
        await precacheImage(MemoryImage(watermarkedBytes), context);
        setState(() {
          overlayImage = watermarkedBytes;
        });
        // _loadingController.add(false);
        // Provider.of<UserAuthProvider>(context, listen: false).setLoading(false);

      }
    }
  }

  Future<Uint8List?> applyWatermarkAndNavigate2(Uint8List imgBytes) async {
    Uint8List logoBytes = selectedImage;
    img.Image? image = img.decodeImage(Uint8List.fromList(imgBytes));
    img.Image? logoImage = img.decodeImage(Uint8List.fromList(logoBytes));
    if (image == null || logoImage == null) {
      return null;
    }

    // Découper 200 pixels en bas de l'image
    int croppedHeight = image.height - 500;
    img.Image croppedImage = img.copyCrop(image, x: 0, y: 0, width: image.width, height: croppedHeight);

    int height = croppedImage.height;
    int width = croppedImage.width;
    int selectedImageHeight = height;
    int selectedImageWidth = width;

    int logoWidth = width + 300;
    int logoHeight = height + 300;

    img.Image resizedImageUser = img.copyResize(croppedImage, width: selectedImageWidth, height: selectedImageHeight);
    img.Image resizedImage = img.copyResize(logoImage, width: logoWidth, height: logoHeight);

    final List<img.Color> borderColors = [
      img.ColorInt8.rgb(0, 255, 0),
      img.ColorInt8.rgb(0, 0, 0),
      img.ColorInt8.rgb(255, 255, 0)
    ];
    final img.Color borderColor = borderColors[Random().nextInt(3)];

    int borderSize = 10;
    img.drawRect(
      resizedImageUser,
      x1: 0,
      y1: 0,
      x2: resizedImageUser.width - 1,
      y2: resizedImageUser.height - 1,
      color: borderColor,
      thickness: borderSize,
    );

    int dstX = (logoWidth - selectedImageWidth) ~/ 2;
    int dstY = (logoHeight - selectedImageHeight) ~/ 2;
    dstX = dstX.clamp(0, logoWidth - selectedImageWidth);
    dstY = dstY.clamp(0, logoHeight - selectedImageHeight);

    Uint8List? watermarkedImgBytes = await ImageWatermark.addImageWatermark(
      originalImageBytes: Uint8List.fromList(img.encodePng(resizedImage)),
      waterkmarkImageBytes: Uint8List.fromList(img.encodePng(resizedImageUser)),
      imgWidth: selectedImageWidth,
      imgHeight: selectedImageHeight,
      dstX: dstX,
      dstY: dstY,
    );

    return watermarkedImgBytes;
  }
  Future<Uint8List?> applyWatermarkAndNavigate(Uint8List imgBytes) async {

    Uint8List logoBytes = selectedImage;
    img.Image? image = img.decodeImage(Uint8List.fromList(imgBytes));
    img.Image? logoImage = img.decodeImage(Uint8List.fromList(logoBytes));
    if (image == null || logoImage == null) {
      return null;
    }

    // int height = (MediaQuery.of(context).size.height*0.18).toInt();
    int height = image.height;
    int width = image.width;
    int selectedImageHeight = height;
    int selectedImageWidth = width;
    int logoWidth = width +300;
    int logoHeight = height+350;

    // int selectedImageWidth = 1080;
    // int selectedImageHeight = 1080+height;
    //
    // int logoWidth = logoImage.width + (selectedImageWidth * 0.1).toInt();
    // int logoHeight = logoImage.height + (selectedImageHeight * 0.1).toInt() + height+20;



    img.Image resizedImageUser = img.copyResize(image, width: selectedImageWidth, height: selectedImageHeight);
    img.Image resizedImage = img.copyResize(logoImage, width: logoWidth, height: logoHeight);

    final List<img.Color> borderColors = [
      img.ColorInt8.rgb(0, 255, 0),
      img.ColorInt8.rgb(0, 0, 0),
      img.ColorInt8.rgb(255, 255, 0)
    ];
    final img.Color borderColor = borderColors[Random().nextInt(3)];

    int borderSize = 10;
    img.drawRect(
      resizedImageUser,
      x1: 0,
      y1: 0,
      x2: resizedImageUser.width - 1,
      y2: resizedImageUser.height - 1,
      color: borderColor,
      thickness: borderSize,
    );

    int dstX = (logoWidth - selectedImageWidth) ~/ 2;
    int dstY = (logoHeight - selectedImageHeight) ~/ 2;
    dstX = dstX.clamp(0, logoWidth - selectedImageWidth);
    dstY = dstY.clamp(0, logoHeight - selectedImageHeight);

    Uint8List? watermarkedImgBytes = await ImageWatermark.addImageWatermark(
      originalImageBytes: Uint8List.fromList(img.encodePng(resizedImage)),
      waterkmarkImageBytes: Uint8List.fromList(img.encodePng(resizedImageUser)),
      imgWidth: selectedImageWidth,
      imgHeight: selectedImageHeight,
      dstX: dstX,
      dstY: dstY,
    );

    return watermarkedImgBytes;
  }
  String  imgname = "image not selected";
  bool isLenovoFont = false;
  Uint8List? watermarkedImgBytes;
  Uint8List? file;


  @override
  Widget build(BuildContext context) {
    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;
    return Scaffold(
      body:             Column(
        children: [
          SingleChildScrollView(
            child: SizedBox(
              child: Row(
                mainAxisSize: MainAxisSize.max,
                children: [
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Container(
                        // width: 80,
                        // height: 80,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green, // Couleur de fond verte
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(0), // Forme carrée
                            ),
                          ),
                          onPressed: () {
                            // Action à effectuer lors du clic sur le bouton
                            setState(() {
                              overlayImage = initialImage;
                            });
                          },
                          child: Text(
                            'Effacer',
                            style: TextStyle(
                              color: Colors.white, // Couleur du texte blanc
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 100,
                    width: width*0.7,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: images.length,
                      itemBuilder: (context, index) {

                        return GestureDetector(
                          onTap: () async{
                            selectedImage = images[index];
                            print('debut de supperposition');

                            // Provider.of<UserAuthProvider>(context, listen: false).setLoading(true);

                            setState(() {
                              isLoading=true;
                              //  isLoading=false;

                            });
                            await Future.delayed(Duration(seconds: 1));

                            await _openPicker(widget.initialImage);
                            print('fin de supperposition');
                            // Provider.of<UserAuthProvider>(context, listen: false).setLoading(false);

                            setState(() {
                              isLoading=false;
                              //  isLoading=false;

                            });
                          },
                          child: Container(
                            margin: EdgeInsets.all(8.0),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: selectedImage == images[index] ? Colors.yellow : Colors.transparent,
                                width: 3,
                              ),
                            ),
                            child: Image.memory(images[index], width: 80, height: 80),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: isLoading
                  ? Text("Chargement... \nVeuillez patienter un moment",style: TextStyle(color: Colors.green,fontSize: 15,fontWeight: FontWeight.w900),)
                  : Padding(
                padding: const EdgeInsets.all(8.0),
                child:overlayImage!=null? Image.memory(overlayImage!):Container(),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [

              Container(
                child:isLoading?Center(child: SizedBox(width: 30, height: 30, child: CircularProgressIndicator(color: Colors.green,))): ElevatedButton(
                  onPressed: () async {
                    setState(() {
                      isLoading=true;
                    });
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) {
                              // return PostLookImageTab(
                              return _buildEditor(
                                bytes: overlayImage,
                                // imgBytes: overlayImage!,
                                // generationTime: _generationTime,
                                // showThumbnail: showThumbnail,
                                // rawOriginalImage: rawOriginalImage,
                                // generationConfigs: generationConfigs,
                              );
                            },
                          ),
                        ).whenComplete(() {
                          setState(() {
                            isLoading=false;
                          });
                        });
                   // await _saveImage(overlayImage).then((value) async {
                   //   if(value){
                   //     await Navigator.push(
                   //       context,
                   //       MaterialPageRoute(
                   //         builder: (context) {
                   //           // return PostLookImageTab(
                   //           return _buildEditor(
                   //             bytes: overlayImage,
                   //             // imgBytes: overlayImage!,
                   //             // generationTime: _generationTime,
                   //             // showThumbnail: showThumbnail,
                   //             // rawOriginalImage: rawOriginalImage,
                   //             // generationConfigs: generationConfigs,
                   //           );
                   //         },
                   //       ),
                   //     ).whenComplete(() {
                   //
                   //     });
                   //   }
                   // },);
                   //  setState(() {
                   //    isLoading=false;
                   //  });

                    // Logique de validation
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: Text('Valider et Enregistrer'),
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
        ],
      ),
    );
  }

}
