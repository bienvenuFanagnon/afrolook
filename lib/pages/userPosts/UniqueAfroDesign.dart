
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:afrotok/pages/component/consoleWidget.dart';
import 'package:afrotok/pages/userPosts/utils/postLookImageTab.dart';
import 'package:afrotok/providers/authProvider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:image_watermark/image_watermark.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

class UniqueAfrolookDesign extends StatefulWidget {
  final Uint8List initialImage;

  UniqueAfrolookDesign({required this.initialImage});

  @override
  _UniqueAfrolookDesignState createState() => _UniqueAfrolookDesignState();
}

class _UniqueAfrolookDesignState extends State<UniqueAfrolookDesign> {
  List<Uint8List> images = [];
  late Uint8List selectedImage;
  bool isLoading=false;
  Uint8List? overlayImage;
  final StreamController<bool> _loadingController = StreamController<bool>();
  Future<bool> _saveImage2(Uint8List? image) async {
    try{
      if (image == null) return false;

      // Demander les permissions
      final status = await Permission.storage.request();
      if (status.isGranted) {
      // Enregistrer l'image dans la galerie
      final result = await ImageGallerySaverPlus.saveImage(image);
      print(result);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Image enregistrée dans la galerie',style: TextStyle(color: Colors.white),),backgroundColor: Colors.green,),
      );
      return true;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur d'enregistrement dans la galerie Permission refusée",style: TextStyle(color: Colors.white),),backgroundColor: Colors.red,));
        return false;

      }
    }catch(e){
      printVm('erreur: ${e}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur d'enregistrement dans la galerie ${e}",style: TextStyle(color: Colors.white),),backgroundColor: Colors.red,),
      );
      return false;

    }

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
  @override
  void initState() {
    super.initState();
    overlayImage = widget.initialImage;
    loadImages();
  }

  @override
  void dispose() {
    _loadingController.close();
    super.dispose();
  }

  Future<void> loadImages() async {
    _loadingController.add(true);

    List<String> assetPaths = [
      'assets/frames/1.png',
      'assets/frames/2.png',
      'assets/frames/3.png',
      'assets/frames/4.png',
      'assets/frames/5.png',
      'assets/frames/6.png',
      'assets/frames/7.png',
      'assets/frames/8.png',
      'assets/frames/9.png',
      'assets/frames/10.png',
      'assets/frames/11.png',
      'assets/frames/12.png',
      'assets/frames/13.png',
      'assets/frames/14.png',
      'assets/frames/15.png',
      'assets/frames/16.png',
      'assets/frames/17.png',
      'assets/frames/18.png',
      'assets/frames/19.png',
      'assets/frames/20.png',
      'assets/frames/21.png',
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

    await   _openPicker(overlayImage);
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

    // int selectedImageWidth = 1080;
    // int selectedImageHeight = 1080+height;

    // int logoWidth = logoImage.width + (selectedImageWidth * 0.1).toInt();
    // int logoHeight = logoImage.height + (selectedImageHeight * 0.1).toInt() + height+20;

    int logoWidth = width +300;
    int logoHeight = height+350;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:             Column(
        children: [
          SizedBox(
            height: 100,
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
          Expanded(
            child: Center(
              child: isLoading
                  ? Text("Chargement... \nVeuillez patienter un moment",style: TextStyle(color: Colors.green,fontSize: 15,fontWeight: FontWeight.w900),)
                  : Padding(
                padding: const EdgeInsets.all(8.0),
                child: Image.memory(overlayImage!),
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

                   await _saveImage(overlayImage).then((value) async {
                     if(value){
                       await Navigator.push(
                         context,
                         MaterialPageRoute(
                           builder: (context) {
                             return PostLookImageTab(
                               imgBytes: overlayImage!,
                               // generationTime: _generationTime,
                               // showThumbnail: showThumbnail,
                               // rawOriginalImage: rawOriginalImage,
                               // generationConfigs: generationConfigs,
                             );
                           },
                         ),
                       ).whenComplete(() {

                       });
                     }
                   },);
                    setState(() {
                      isLoading=false;
                    });

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
