// Dart imports:
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:afrotok/pages/component/consoleWidget.dart';
import 'package:fluttertagger/fluttertagger.dart';
import 'package:path/path.dart' as Path;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_storage/firebase_storage.dart';

// Flutter imports:
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
// Package imports:
import 'package:intl/intl.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:mime/mime.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:provider/provider.dart';

import '../../../constant/buttons.dart';
import '../../../constant/constColors.dart';
import '../../../constant/logo.dart';
import '../../../constant/sizeButtons.dart';
import '../../../constant/sizeText.dart';
import '../../../constant/textCustom.dart';
import '../../../models/model_data.dart';
import '../../../providers/authProvider.dart';
import '../../../providers/postProvider.dart';
import '../../../providers/userProvider.dart';
import '../hashtag/textHashTag/views/view_models/home_view_model.dart';
import '../hashtag/textHashTag/views/view_models/search_view_model.dart';
import '../hashtag/textHashTag/views/widgets/comment_text_field.dart';
import '../hashtag/textHashTag/views/widgets/search_result_overlay.dart';
import '../utils/pixel_transparent_painter.dart';

/// A page that displays a preview of the generated image.
///
/// The [PostLookImageTab] widget is a stateful widget that shows a preview of
/// an image created using the provided [imgBytes]. It also supports showing
/// a thumbnail of the original image if [showThumbnail] is set to true.
///
/// The page can display additional information such as [generationTime], the
/// original raw image as [rawOriginalImage], and optional [generationConfigs]
/// used during the image creation process.
///
/// If [showThumbnail] is set to true, [rawOriginalImage] must be provided.
///
/// Example usage:
/// ```dart
/// PreviewImgPage(
///   imgBytes: generatedImageBytes,
///   generationTime: 1200,
///   rawOriginalImage: originalImage,
///   showThumbnail: true,
/// );
/// ```
class PostLookImageTab extends StatefulWidget {
  /// Creates a new [PostLookImageTab] widget.
  ///
  /// The [imgBytes] parameter is required and contains the generated image
  /// data to be displayed. The [generationTime] is optional and represents
  /// the time taken to generate the image. If [showThumbnail] is true,
  /// [rawOriginalImage] must be provided.
  const PostLookImageTab({
    super.key,
    required this.imgBytes,
    this.generationTime,
    this.rawOriginalImage,
    this.generationConfigs,
    this.showThumbnail = false,
  }) : assert(
          showThumbnail == false || rawOriginalImage != null,
          'rawOriginalImage is required if you want to display a thumbnail.',
        );

  /// The image data in bytes to be displayed.
   final Uint8List imgBytes;

  /// The time taken to generate the image, in milliseconds.
  final double? generationTime;

  /// Whether or not to show a thumbnail of the original image.
  final bool showThumbnail;

  /// The original raw image, required if [showThumbnail] is true.
  final ui.Image? rawOriginalImage;

  /// Optional configurations used during image generation.
  final ImageGenerationConfigs? generationConfigs;

  @override
  State<PostLookImageTab> createState() => _PostLookImageTabState();
}

/// The state for the [PostLookImageTab] widget.
///
/// This class manages the logic and display of the preview image and optional
/// thumbnail, along with any associated generation information.
class _PostLookImageTabState extends State<PostLookImageTab> with TickerProviderStateMixin {
  final _valueStyle = const TextStyle(fontStyle: FontStyle.italic);

  Future<ImageInfos>? _decodedImageInfos;
  String _contentType = 'Unknown';
  double? _generationTime;

  Future<Uint8List?>? _highQualityGeneration;

  late Uint8List? _imageBytes;

  final _numberFormatter = NumberFormat();



  final _formKey = GlobalKey<FormState>();

  GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final TextEditingController _titreController = TextEditingController();

  // final TextEditingController _descriptionController = TextEditingController();
  late PostProvider postProvider =
  Provider.of<PostProvider>(context, listen: false);
  late UserAuthProvider authProvider =
  Provider.of<UserAuthProvider>(context, listen: false);

  late UserProvider userProvider =
  Provider.of<UserProvider>(context, listen: false);
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  bool onTap = false;

  int  limitePosts = 40;
  File? _selectedFile;
  final ImagePicker _picker = ImagePicker();

  // Capture an image or video
  Future<void> _captureMedia(bool isPhoto) async {
    final XFile? file = await (isPhoto
        ? _picker.pickImage(source: ImageSource.camera)
        : _picker.pickVideo(source: ImageSource.camera));

    if (file != null) {
      setState(() {
        _selectedFile = File(file.path);
      });
    }
  }
  // Convert Uint8List to File
  Future<File> _convertUint8ListToFile(Uint8List uint8List, String fileName) async {
    // final Directory tempDir = await getTemporaryDirectory();
    // final Directory? downloadsDir = await getDownloadsDirectory();
    final Directory? downloadsDir = await getApplicationDocumentsDirectory();
    // final Directory? downloadsDir = await getExternalStorageDirectory();

    final String filePath = '${downloadsDir!.path}/afrolook_image${DateTime.now().microsecond}.png';
    // printVm("filePath: $filePath");
    final File file = File(filePath);

    await file.writeAsBytes(uint8List);
    printVm("**********************filePath: ${file.path}");

    return file;
  }
  void save(BuildContext pagecontext) {
    if (_imageBytes! == null) {
      setState(() {
        onTap = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Veuillez choisir une image.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.red),
          ),
        ),
      );
      return;
    }

    setState(() {
      onTap = true; // Désactive le bouton
    });

    // Afficher un indicateur de chargement
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Center(
          child: CircularProgressIndicator(),
        );
      },
    );

    try {
      String postId = FirebaseFirestore.instance.collection('Posts').doc().id;

      Post post = Post()
        ..user_id = authProvider.loginUserData.id
        ..description = _descriptionController.text
        ..updatedAt = DateTime.now().microsecondsSinceEpoch
        ..createdAt = DateTime.now().microsecondsSinceEpoch
        ..status = PostStatus.VALIDE.name
        ..type = PostType.POST.name
        ..comments = 0
        ..nombrePersonneParJour = 60
        ..dataType = PostDataType.IMAGE.name
        ..likes = 0
        ..loves = 0
        ..id = postId
        ..images = [];

      _convertUint8ListToFile(
        _imageBytes!,
        '${Path.basename(File.fromRawPath(_imageBytes!).path)}',
      ).then((file) async {
        Reference storageReference =
        FirebaseStorage.instance.ref().child('post_media/${file.path}');
        UploadTask uploadTask = storageReference.putFile(file);

        await uploadTask.whenComplete(() async {
          String fileURL = await storageReference.getDownloadURL();
          post.images!.add(fileURL);

          await FirebaseFirestore.instance.collection('Posts').doc(postId).set(post.toJson());

          _descriptionController.clear();
          authProvider.loginUserData.mesPubs = authProvider.loginUserData.mesPubs! + 1;
          await userProvider.updateUser(authProvider.loginUserData!);
          postProvider.listConstposts.add(post);

          // Notification logic
          NotificationData notif = NotificationData()
            ..id = firestore.collection('Notifications').doc().id
            ..titre = "Nouveau post"
            ..description = "Un nouveau post a été publié !"
            ..users_id_view = []
            ..receiver_id = ""
            ..user_id = authProvider.loginUserData.id
            ..updatedAt = DateTime.now().microsecondsSinceEpoch
            ..createdAt = DateTime.now().microsecondsSinceEpoch
            ..status = PostStatus.VALIDE.name;

          await firestore.collection('Notifications').doc(notif.id).set(notif.toJson());

                      await authProvider
                          .getAllUsersOneSignaUserId()
                          .then(
                            (userIds) async {
                          if (userIds.isNotEmpty) {

                            await authProvider.sendNotification(
                                userIds: userIds,
                                smallImage: "${authProvider.loginUserData.imageUrl!}",
                                send_user_id: "${authProvider.loginUserData.id!}",
                                recever_user_id: "",
                                message: "📢 ${authProvider.loginUserData.pseudo!} a posté un look ✨",
                                type_notif: NotificationType.POST.name,
                                post_id: "${post!.id!}",
                                post_type: PostDataType.IMAGE.name, chat_id: ''
                            );

                          }
                        },
                      );

          // postProvider.getPostsImages(limitePosts);
          _imageBytes!=null;

          Navigator.pop(context); // Fermer le dialog de chargement
          Navigator.pop(pagecontext); // Fermer la page

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Le post a été validé avec succès !',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.green),
              ),
            ),
          );
        });
      }).catchError((error) {
        Navigator.pop(context); // Fermer le dialog de chargement en cas d'erreur
        throw error; // Relancer pour le catch suivant
      });
    } catch (e) {
      print("Erreur : $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'La validation du post a échoué. Veuillez réessayer.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.red),
          ),
        ),
      );
    } finally {
      setState(() {
        onTap = false; // Réactiver le bouton
      });
    }
  }


  // save(){
  //   if (_imageBytes!==null) {
  //     setState(() {
  //       onTap=false;
  //     });
  //     SnackBar snackBar = SnackBar(
  //       content: Text(
  //         'Veuillez choisir une image.',
  //         textAlign: TextAlign.center,
  //         style: TextStyle(color: Colors.red),
  //       ),
  //     );
  //     ScaffoldMessenger.of(context)
  //         .showSnackBar(snackBar);
  //   }
  //   else {
  //     try {
  //
  //
  //       String postId = FirebaseFirestore.instance
  //           .collection('Posts')
  //           .doc()
  //           .id;
  //       Post post = Post();
  //       post.user_id = authProvider.loginUserData.id;
  //       post.description = _descriptionController.text;
  //       post.updatedAt =
  //           DateTime.now().microsecondsSinceEpoch;
  //       post.createdAt =
  //           DateTime.now().microsecondsSinceEpoch;
  //       post.status = PostStatus.VALIDE.name;
  //
  //       post.type = PostType.POST.name;
  //       post.comments = 0;
  //       post.nombrePersonneParJour = 60;
  //       post.dataType = PostDataType.IMAGE.name;
  //       post.likes = 0;
  //       post.loves = 0;
  //       post.id = postId;
  //       post.images = [];
  //       // for (XFile _image in listimages) {
  //       //
  //       // }
  //       _convertUint8ListToFile(_imageBytes!, '${Path.basename(File.fromRawPath(_imageBytes!).path)}').then((file) async {
  //         Reference storageReference =
  //         FirebaseStorage.instance.ref().child(
  //             'post_media/${file.path}');
  //
  //         UploadTask uploadTask = storageReference
  //             .putFile(file);
  //         await uploadTask.whenComplete(() async {
  //           await storageReference
  //               .getDownloadURL()
  //               .then((fileURL) async {
  //             printVm("url media");
  //             printVm(fileURL);
  //
  //             post.images!.add(fileURL);
  //
  //             printVm("images: ${post.images!.length}");
  //             await FirebaseFirestore.instance
  //                 .collection('Posts')
  //                 .doc(postId)
  //                 .set(post.toJson());
  //
  //             _descriptionController.text='';
  //             // setState(() {
  //             //   onTap=false;
  //             // });
  //             authProvider.loginUserData.mesPubs=authProvider.loginUserData.mesPubs!+1;
  //             await userProvider.updateUser(authProvider.loginUserData!);
  //             postProvider.listConstposts.add(post);
  //
  //
  //
  //             NotificationData notif=NotificationData();
  //             notif.id=firestore
  //                 .collection('Notifications')
  //                 .doc()
  //                 .id;
  //             notif.titre="Nouveau post";
  //             notif.description="Un nouveau post a été publié !";
  //             notif.users_id_view=[];
  //             notif.receiver_id="";
  //
  //             notif.user_id=authProvider.loginUserData.id;
  //             notif.updatedAt =
  //                 DateTime.now().microsecondsSinceEpoch;
  //             notif.createdAt =
  //                 DateTime.now().microsecondsSinceEpoch;
  //             notif.status = PostStatus.VALIDE.name;
  //
  //             // users.add(pseudo.toJson());
  //
  //             await firestore.collection('Notifications').doc(notif.id).set(notif.toJson());
  //             printVm("///////////-- save notification --///////////////");
  //
  //             await authProvider
  //                 .getAllUsersOneSignaUserId()
  //                 .then(
  //                   (userIds) async {
  //                 if (userIds.isNotEmpty) {
  //
  //                   // await authProvider.sendNotification(
  //                   //     userIds: userIds,
  //                   //     smallImage: "${authProvider.loginUserData.imageUrl!}",
  //                   //     send_user_id: "${authProvider.loginUserData.id!}",
  //                   //     recever_user_id: "",
  //                   //     message: "📢 ${authProvider.loginUserData.pseudo!} a posté un look ✨",
  //                   //     type_notif: NotificationType.POST.name,
  //                   //     post_id: "${post!.id!}",
  //                   //     post_type: PostDataType.IMAGE.name, chat_id: ''
  //                   // );
  //
  //                 }
  //               },
  //             );
  //             printVm("///////////-- poste saved  ${post.toJson()} --///////////////");
  //
  //             SnackBar snackBar = SnackBar(
  //               content: Text(
  //                 'Le post a été validé avec succès !',
  //                 textAlign: TextAlign.center,
  //                 style: TextStyle(color: Colors.green),
  //               ),
  //             );
  //             ScaffoldMessenger.of(context)
  //                 .showSnackBar(snackBar);
  //             postProvider.getPostsImages(limitePosts).then((value) {
  //               // value.forEach((element) {
  //               //   print(element.toJson());
  //               // },);
  //
  //             },);
  //
  //             Navigator.pop(context);
  //           });
  //         });
  //
  //       },);
  //
  //
  //
  //
  //       setState(() {
  //         onTap=false;
  //       });
  //     } catch (e) {
  //
  //       print("erreur ${e}");
  //       setState(() {
  //         onTap=false;
  //       });
  //
  //
  //       SnackBar snackBar = SnackBar(
  //         content: Text(
  //           'La validation du post a échoué. Veuillez réessayer.',
  //           textAlign: TextAlign.center,
  //           style: TextStyle(color: Colors.red),
  //         ),
  //       );
  //       ScaffoldMessenger.of(context)
  //           .showSnackBar(snackBar);
  //
  //
  //     }
  //   }
  // }


  // Upload file to Firebase Storage
  Future<void> _uploadToFirebase(File file) async {
    try {
      final String fileName = 'uploads/${DateTime.now().millisecondsSinceEpoch}_${file.uri.pathSegments.last}';
      final Reference storageRef = FirebaseStorage.instance.ref().child(fileName);
      await storageRef.putFile(file);

      final String downloadURL = await storageRef.getDownloadURL();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fichier uploadé : $downloadURL')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Échec de l\'upload : $e')),
      );
    }
  }

  // Save the file locally and upload to Firebase
  Future<void> _saveAndUploadMedia() async {
    if (_selectedFile == null) return;

    final Directory appDir = await getApplicationDocumentsDirectory();
    final String savePath = '${appDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';

    final File savedFile = await _selectedFile!.copy(savePath);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Fichier sauvegardé : $savePath')),
    );

    await _uploadToFirebase(savedFile);
  }




  void _setContentType() {
    _contentType = lookupMimeType('', headerBytes: _imageBytes!) ?? 'Unknown';
  }

  String formatBytes(int bytes, [int decimals = 2]) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = (log(bytes) / log(1024)).floor();
    var size = bytes / pow(1024, i);
    return '${size.toStringAsFixed(decimals)} ${suffixes[i]}';
  }

  late AnimationController _animationController;
  late Animation<Offset> _animation;

  double overlayHeight = 380;

  late final homeViewModel = HomeViewModel();
  late final _descriptionController = FlutterTaggerController(
    //Initial text value with tag is formatted internally
    //following the construction of FlutterTaggerController.
    //After this controller is constructed, if you
    //wish to update its text value with raw tag string,
    //call (_controller.formatTags) after that.
    text:
    "",
  );
  late final _focusNode = FocusNode();

  void _focusListener() {
    if (!_focusNode.hasFocus) {
      _descriptionController.dismissOverlay();
    }
  }

  @override
  void initState() {
    super.initState();
    _generationTime = widget.generationTime;
    _imageBytes = widget.imgBytes;
    _setContentType();
    _focusNode.addListener(_focusListener);
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );

    _animation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _focusNode.removeListener(_focusListener);
    _focusNode.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var insets = MediaQuery.of(context).viewInsets;
    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;
    return LayoutBuilder(builder: (context, constraints) {
      _decodedImageInfos ??=
          decodeImageInfos(bytes: _imageBytes!, screenSize: constraints.biggest);

      if (widget.showThumbnail) {
        Stopwatch stopwatch = Stopwatch()..start();
        _highQualityGeneration ??= generateHighQualityImage(
          widget.rawOriginalImage!,

          /// Set optional configs for the output
          configs: widget.generationConfigs ?? const ImageGenerationConfigs(),
          context: context,
        ).then((res) {
          if (res == null) return res;
          _imageBytes = res;
          _generationTime = stopwatch.elapsedMilliseconds.toDouble();
          stopwatch.stop();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _decodedImageInfos = null;
            _setContentType();
            setState(() {});
          });
          return res;
        });
      }
      return Scaffold(
        backgroundColor: ConstColors.backgroundColor,
        appBar: AppBar(
          title: TextCustomerPageTitle(
            titre: "Poster un look",
            fontSize: SizeText.homeProfileTextSize,
            couleur: ConstColors.textColors,
            fontWeight: FontWeight.bold,
          ),



          //backgroundColor: Colors.blue,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Logo(),
            )
          ],
          //title: Text(widget.title),
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Stack(
              children: [
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _descriptionController,
                        decoration: InputDecoration(
                          hintText: 'Légende',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10.0), // Add rounded corners
                            borderSide: BorderSide(color: Colors.blue, width: 2.0), // Customize color and thickness
                          ),
                        ),
                        maxLines: 2,
                        maxLength: 400,
                        validator: (value) {
                          if (value!.isEmpty) {
                            return 'La légende est obligatoire';
                          }

                          return null;
                        },
                      ),
                      SizedBox(
                        height: 25.0,
                      ),

                      if (!widget.showThumbnail)
                        ClipRRect(

                          borderRadius:
                          BorderRadius.all(Radius.circular(20)),
                          child: Container(
                              height: height*0.5,
                              width: width,
                              child: _buildFinalImage()),
                        ),
                      // else
                      //   _buildThumbnailPreview(),
                      // if (_generationTime != null) _buildGenerationInfos(),

                      SizedBox(
                        height: 60,
                      ),
                      // StatefulBuilder(
                      //     builder: (BuildContext context, StateSetter setState) {
                      //     return GestureDetector(
                      //         onTap:onTap?(){}: () async {
                      //           //_getImages();
                      //           setState(() {
                      //             onTap=true;
                      //           });
                      //           printVm('tap');
                      //           if (_formKey.currentState!.validate()) {
                      //
                      //             save(context);
                      //           }else{
                      //             setState(() {
                      //             onTap=false;
                      //           });
                      //
                      //           }
                      //         },
                      //         child:onTap? Center(
                      //           child: LoadingAnimationWidget.flickr(
                      //             size: 20,
                      //             leftDotColor: Colors.green,
                      //             rightDotColor: Colors.black,
                      //           ),
                      //         ): PostsButtons(
                      //           text: 'Créer votre look',
                      //           hauteur: height*0.07,
                      //           largeur: width*0.9,
                      //           urlImage: 'assets/images/sender.png',
                      //         ));
                      //   }
                      // ),
                    ],
                  ),
                ),
                // if (onTap)
                  // Container(
                  //   height: height*0.8,
                  //   width: width,
                  //   color: Colors.black.withOpacity(0.5),
                  //   child: Center(
                  //     child: CircularProgressIndicator(),
                  //   ),
                  // ),
              ],
            ),
          ),
        ),

        bottomNavigationBar:  FlutterTagger(
          controller: _descriptionController,
          animationController: _animationController,

          onSearch: (query, triggerChar) {
            // if (triggerChar == "@") {
            //   searchViewModel.searchUser(query);
            // }
            if (triggerChar == "#") {
              searchViewModel.searchHashtag(query);
            }
          },
          triggerCharacterAndStyles: const {
            // "@": TextStyle(color: Colors.pinkAccent),
            "#": TextStyle(color: Colors.green),
          },
          tagTextFormatter: (id, tag, triggerCharacter) {
            return "$triggerCharacter$id#$tag#";
          },
          overlayHeight: overlayHeight,
          overlay: SearchResultOverlay(
            animation: _animation,
            tagController: _descriptionController,
          ),
          builder: (context, containerKey) {
            return CommentTextField(

              focusNode: _focusNode,
              containerKey: containerKey,
              insets: insets,
              controller: _descriptionController,
              onSend:  onTap?(){}: () async {
                printVm("***************send comment;");


                //_getImages();
                String textComment=_descriptionController.text;

                if (_formKey.currentState!.validate()) {
                  save(context);


                }



                _descriptionController.clear();
              },
            );
          },
        ),
      );
    });
  }

  Widget _buildFinalImage({Uint8List? bytes}) {
    return InteractiveViewer(
      maxScale: 7,
      minScale: 1,
      child: Image.memory(
        bytes ?? _imageBytes!,
        fit: BoxFit.contain,
      ),
    );
  }

  Widget _buildGenerationInfos() {
    TableRow tableSpace = const TableRow(
      children: [SizedBox(height: 3), SizedBox()],
    );
    return Positioned(
      top: 10,
      child: ClipRect(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(7),
            ),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: FutureBuilder<ImageInfos>(
                future: _decodedImageInfos,
                builder: (context, snapshot) {
                  return Table(
                    defaultColumnWidth: const IntrinsicColumnWidth(),
                    children: [
                      TableRow(children: [
                        const Text('Generation-Time'),
                        Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: Text(
                            '${_numberFormatter.format(_generationTime)} ms',
                            style: _valueStyle,
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ]),
                      tableSpace,
                      TableRow(children: [
                        const Text('Image-Size'),
                        Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: Text(
                            formatBytes(_imageBytes!.length),
                            style: _valueStyle,
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ]),
                      tableSpace,
                      TableRow(children: [
                        const Text('Content-Type'),
                        Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: Text(
                            _contentType,
                            style: _valueStyle,
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ]),
                      tableSpace,
                      TableRow(children: [
                        const Text('Dimension'),
                        Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: Text(
                            snapshot.connectionState == ConnectionState.done
                                ? '${_numberFormatter.format(
                                    snapshot.data!.rawSize.width.round(),
                                  )} x ${_numberFormatter.format(
                                    snapshot.data!.rawSize.height.round(),
                                  )}'
                                : 'Loading...',
                            style: _valueStyle,
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ]),
                      tableSpace,
                      TableRow(children: [
                        const Text('Pixel-Ratio'),
                        Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: Text(
                            snapshot.connectionState == ConnectionState.done
                                ? snapshot.data!.pixelRatio.toStringAsFixed(3)
                                : 'Loading...',
                            style: _valueStyle,
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ]),
                    ],
                  );
                }),
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnailPreview() {
    if (_highQualityGeneration == null) return Container();
    return FutureBuilder<Uint8List?>(
        future: _highQualityGeneration,
        builder: (context, snapshot) {
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: snapshot.connectionState == ConnectionState.done
                ? _buildFinalImage(bytes: snapshot.data)
                : Stack(
                    fit: StackFit.expand,
                    alignment: Alignment.center,
                    children: [
                      Hero(
                        tag: const ProImageEditorConfigs().heroTag,
                        child: Image.memory(
                          widget.imgBytes,
                          fit: BoxFit.contain,
                        ),
                      ),
                      if (snapshot.connectionState != ConnectionState.done)
                        const Center(
                          child: SizedBox(
                            width: 60,
                            height: 60,
                            child: FittedBox(
                              child: PlatformCircularProgressIndicator(
                                configs: ProImageEditorConfigs(),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
          );
        });
  }
}
