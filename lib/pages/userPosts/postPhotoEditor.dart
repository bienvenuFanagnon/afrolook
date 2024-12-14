// Dart imports:
import 'dart:io';
import 'dart:math';

// Flutter imports:
import 'package:afrotok/pages/userPosts/utils/example_helper.dart';
import 'package:afrotok/pages/userPosts/utils/postLookImageTab.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:path/path.dart' as Path;

// Package imports:
import 'package:image_picker/image_picker.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:provider/provider.dart';
import '../../constant/constColors.dart';
import '../../providers/authProvider.dart';
import '../../providers/postProvider.dart';
import '../../providers/userProvider.dart';

// Project imports:

/// The example how to pick images from the gallery or with the camera.
class PostPhotoEditor extends StatefulWidget {
  /// Creates a new [PostPhotoEditor] widget.
  const PostPhotoEditor({super.key});

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

  void _openPicker(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: source);

    if (image == null) return;

    String? path;
    Uint8List? bytes;

    if (kIsWeb) {
      bytes = await image.readAsBytes();

      if (!mounted) return;
      await precacheImage(MemoryImage(bytes), context);
    } else {
      path = image.path;
      if (!mounted) return;
      await precacheImage(FileImage(File(path)), context);
    }

    if (!mounted) return;
    if (kIsWeb ||
        (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS)) {
      Navigator.pop(context);
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _buildEditor(path: path, bytes: bytes),
      ),
    );
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
                  // GestureDetector(
                  //     onTap: () {
                  //       _getImages();
                  //     },
                  //     child: PostsButtons(
                  //       text: 'Sélectionner des images(2)',
                  //       hauteur: SizeButtons.hauteur,
                  //       largeur: SizeButtons.largeur,
                  //       urlImage: '',
                  //     )),
                  // listimages.isNotEmpty
                  //     ? Padding(
                  //   padding: const EdgeInsets.all(8.0),
                  //   child: Wrap(
                  //     children: listimages
                  //         .map(
                  //           (image) => Padding(
                  //         padding: const EdgeInsets.only(right: 8.0),
                  //         child: ClipRRect(
                  //
                  //           borderRadius:
                  //           BorderRadius.all(Radius.circular(20)),
                  //           child: Container(
                  //             width: 100.0,
                  //             height: 100.0,
                  //             child:Column(
                  //               children: [
                  //             //   PreviewImgPage(
                  //             //   imgBytes: editedBytes!,
                  //             //   generationTime: _generationTime,
                  //             //   showThumbnail: showThumbnail,
                  //             //   rawOriginalImage: rawOriginalImage,
                  //             //   generationConfigs: generationConfigs,
                  //             // ),
                  //                 Image.memory(
                  //                   editedBytes!,
                  //                   fit: BoxFit.cover,
                  //                 ),
                  //               ],
                  //             )
                  //           ),
                  //         ),
                  //       ),
                  //     )
                  //         .toList(),
                  //   ),
                  // )
                  //     : Container(),
                  //
                  // SizedBox(
                  //   height: 60,
                  // ),
                  // GestureDetector(
                  //     onTap:onTap?(){}: () async {
                  //       //_getImages();
                  //       if (_formKey.currentState!.validate()) {
                  //
                  //         setState(() {
                  //           onTap=true;
                  //         });
                  //         if (listimages.isEmpty) {
                  //           SnackBar snackBar = SnackBar(
                  //             content: Text(
                  //               'Veuillez choisir une image.',
                  //               textAlign: TextAlign.center,
                  //               style: TextStyle(color: Colors.red),
                  //             ),
                  //           );
                  //           ScaffoldMessenger.of(context)
                  //               .showSnackBar(snackBar);
                  //         } else {
                  //           try {
                  //             String postId = FirebaseFirestore.instance
                  //                 .collection('Posts')
                  //                 .doc()
                  //                 .id;
                  //             Post post = Post();
                  //             post.user_id = authProvider.loginUserData.id;
                  //             post.description = _descriptionController.text;
                  //             post.updatedAt =
                  //                 DateTime.now().microsecondsSinceEpoch;
                  //             post.createdAt =
                  //                 DateTime.now().microsecondsSinceEpoch;
                  //             post.status = PostStatus.VALIDE.name;
                  //
                  //             post.type = PostType.POST.name;
                  //             post.comments = 0;
                  //             post.nombrePersonneParJour = 60;
                  //             post.dataType = PostDataType.IMAGE.name;
                  //             post.likes = 0;
                  //             post.loves = 0;
                  //             post.id = postId;
                  //             post.images = [];
                  //             for (XFile _image in listimages) {
                  //               Reference storageReference =
                  //               FirebaseStorage.instance.ref().child(
                  //                   'post_media/${Path.basename(File(_image.path).path)}');
                  //
                  //               UploadTask uploadTask = storageReference
                  //                   .putFile(File(_image.path)!);
                  //               await uploadTask.whenComplete(() async {
                  //                 await storageReference
                  //                     .getDownloadURL()
                  //                     .then((fileURL) {
                  //                   print("url media");
                  //                   //  print(fileURL);
                  //
                  //                   post.images!.add(fileURL);
                  //                 });
                  //               });
                  //             }
                  //             print("images: ${post.images!.length}");
                  //             await FirebaseFirestore.instance
                  //                 .collection('Posts')
                  //                 .doc(postId)
                  //                 .set(post.toJson());
                  //             listimages=[];
                  //             _descriptionController.text='';
                  //             setState(() {
                  //               onTap=false;
                  //             });
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
                  //             print("///////////-- save notification --///////////////");
                  //
                  //             await authProvider
                  //                 .getAllUsersOneSignaUserId()
                  //                 .then(
                  //                   (userIds) async {
                  //                 if (userIds.isNotEmpty) {
                  //
                  //                   await authProvider.sendNotification(
                  //                       userIds: userIds,
                  //                       smallImage: "${authProvider.loginUserData.imageUrl!}",
                  //                       send_user_id: "${authProvider.loginUserData.id!}",
                  //                       recever_user_id: "",
                  //                       message: "📢 ${authProvider.loginUserData.pseudo!} a posté un look ✨",
                  //                       type_notif: NotificationType.POST.name,
                  //                       post_id: "${post!.id!}",
                  //                       post_type: PostDataType.IMAGE.name, chat_id: ''
                  //                   );
                  //
                  //                 }
                  //               },
                  //             );
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
                  //           } catch (e) {
                  //
                  //             print("erreur ${e}");
                  //             setState(() {
                  //               onTap=false;
                  //             });
                  //             /*
                  //
                  //               SnackBar snackBar = SnackBar(
                  //                 content: Text(
                  //                   'La validation du post a échoué. Veuillez réessayer.',
                  //                   textAlign: TextAlign.center,
                  //                   style: TextStyle(color: Colors.red),
                  //                 ),
                  //               );
                  //               ScaffoldMessenger.of(context)
                  //                   .showSnackBar(snackBar);
                  //
                  //                */
                  //           }
                  //         }
                  //       }
                  //     },
                  //     child:onTap? Center(
                  //       child: LoadingAnimationWidget.flickr(
                  //         size: 20,
                  //         leftDotColor: Colors.green,
                  //         rightDotColor: Colors.black,
                  //       ),
                  //     ): PostsButtons(
                  //       text: 'Créer',
                  //       hauteur: SizeButtons.creerButtonshauteur,
                  //       largeur: SizeButtons.creerButtonslargeur,
                  //       urlImage: 'assets/images/sender.png',
                  //     )),
                ],
              ),
            ),
          ),
          // ListTile(
          //   onTap: _chooseCameraOrGallery,
          //   leading: const Icon(Icons.attachment_outlined),
          //   title: const Text('Pick from Gallery or Camera'),
          //   subtitle: !kIsWeb &&
          //       (Platform.isWindows || Platform.isLinux || Platform.isMacOS)
          //       ? const Text('The camera is not supported on this platform.')
          //       : null,
          //   trailing: const Icon(Icons.chevron_right),
          // ),
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
}

/// A stateless widget that displays a material-styled icon button with a custom
/// circular background, half of which is a secondary color. Below the icon,
/// a label text is displayed.
///
/// The [MaterialIconActionButton] widget requires a primary color, secondary
/// color, icon, text, and a callback function to handle taps.
///
/// Example usage:
/// ```dart
/// MaterialIconActionButton(
///   primaryColor: Colors.blue,
///   secondaryColor: Colors.green,
///   icon: Icons.camera,
///   text: 'Camera',
///   onTap: () {
///     // Handle tap action
///   },
/// );
/// ```
class MaterialIconActionButton extends StatelessWidget {
  /// Creates a new [MaterialIconActionButton] widget.
  ///
  /// The [primaryColor] is the color of the circular background, while the
  /// [secondaryColor] is used for the half-circle overlay. The [icon] is the
  /// icon to display in the center, and [text] is the label displayed below
  /// the icon. The [onTap] callback is triggered when the button is tapped.
  const MaterialIconActionButton({
    super.key,
    required this.primaryColor,
    required this.secondaryColor,
    required this.icon,
    required this.text,
    required this.onTap,
  });

  /// The primary color for the button's background.
  final Color primaryColor;

  /// The secondary color for the half-circle overlay.
  final Color secondaryColor;

  /// The icon to display in the center of the button.
  final IconData icon;

  /// The label displayed below the icon.
  final String text;

  /// The callback function triggered when the button is tapped.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 65,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(60),
            onTap: onTap,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
                CustomPaint(
                  painter: CircleHalf(secondaryColor),
                  size: const Size(60, 60),
                ),
                Icon(icon, color: Colors.white),
              ],
            ),
          ),
          const SizedBox(height: 7),
          Text(
            text,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// A custom painter class that paints a half-circle.
///
/// The [CircleHalf] class takes a [color] parameter and paints half of a circle
/// on a canvas, typically used as an overlay for the
/// [MaterialIconActionButton].
class CircleHalf extends CustomPainter {
  /// Creates a new [CircleHalf] painter with the given [color].
  CircleHalf(this.color);

  /// The color to use for painting the half-circle.
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()..color = color;
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(size.height / 2, size.width / 2),
        height: size.height,
        width: size.width,
      ),
      pi,
      pi,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}