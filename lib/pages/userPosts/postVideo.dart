import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/pages/component/consoleWidget.dart';
import 'package:camera/camera.dart';
import 'package:fluttertagger/fluttertagger.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:path/path.dart' as Path;
import 'dart:io';

import 'package:anim_search_bar/anim_search_bar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:contained_tab_bar_view_with_custom_page_navigator/contained_tab_bar_view_with_custom_page_navigator.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:simple_tags/simple_tags.dart';
import 'package:video_player/video_player.dart';
import 'package:dropdown_search/dropdown_search.dart';

import '../../constant/buttons.dart';
import '../../constant/sizeButtons.dart';
import '../../providers/authProvider.dart';
import '../../providers/postProvider.dart';
import '../../providers/userProvider.dart';
import 'hashtag/textHashTag/views/view_models/home_view_model.dart';
import 'hashtag/textHashTag/views/view_models/search_view_model.dart';
import 'hashtag/textHashTag/views/widgets/comment_text_field.dart';
import 'hashtag/textHashTag/views/widgets/search_result_overlay.dart';




class PostVideoUser extends StatefulWidget {
    final String videoFilePath;

  const PostVideoUser({super.key, required this.videoFilePath});

  @override
  State<PostVideoUser> createState() => _PostVideoUserState();
}

class _PostVideoUserState extends State<PostVideoUser> {
  final _formKey = GlobalKey<FormState>();
  late String title;


  GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final TextEditingController _titreController = TextEditingController();

  final TextEditingController _descriptionController = TextEditingController();
  bool onTap=false;
  double _uploadProgress =0;
  late List<XFile> listimages = [];
  late XFile videoFile;
  //late   XFile? galleryVideo;
  bool isVideo = false;

  VideoPlayerController? _controller;
  VideoPlayerController? _toBeDisposed;

  final ImagePicker picker = ImagePicker();


  late UserAuthProvider authProvider =
  Provider.of<UserAuthProvider>(context, listen: false);

  late UserProvider userProvider =
  Provider.of<UserProvider>(context, listen: false);
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  void _checkVideoDuration( Duration videoDuration) {
    Duration videoDuration = _controller!.value.duration;

    if (videoDuration.inSeconds > 60*5) {
      // La durée de la vidéo dépasse 30 secondes, vous pouvez afficher une erreur ici
      print("Erreur : La durée de la vidéo dépasse 5 min");
    } else {
      // La durée de la vidéo est inférieure ou égale à 30 secondes
      print("La durée de la vidéo est conforme");
    }
  }

  @override
  void initState() {
   _initializeVideoPlayer();
   super.initState();
  }

  Future<void> _initializeVideoPlayer() async {
    videoFile=XFile(widget.videoFilePath);

    _controller = VideoPlayerController.file(File(widget.videoFilePath));
    await _controller!.initialize();
    setState(() {});
  }

  @override
  void dispose() {
    super.dispose();
    if (_controller!=null) {
      _controller!.pause();
      _controller!.dispose();
    }

  }

  @override
  Widget build(BuildContext context) {
    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;
    // printVm('controlleur : ${_controller!.value}');

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Text("Créer votre look video", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
        backgroundColor: Colors.green,
        iconTheme: IconThemeData(color: Colors.white),
      ),
body: SingleChildScrollView(
  child: SizedBox(
    width: width,
    height: height * 0.85,
    child: ListView(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
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
                  height: 16.0,
                ),

                _controller != null
                    ? Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Center(
                      child: SizedBox(
                          width: 250,
                          height: 150,
                          child: VideoPlayer(

                            _controller!,
                          ))),
                )
                    : Container(),

                SizedBox(
                  height: 60,
                ),
                GestureDetector(
                    onTap:onTap?(){}: () async {
                      //_getImages();
                      if (_formKey.currentState!.validate()) {

                        if (_controller==null) {
                          SnackBar snackBar = SnackBar(
                            content: Text(
                              'Veuillez choisir une video (max 5 min).',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.red),
                            ),
                          );
                          ScaffoldMessenger.of(context)
                              .showSnackBar(snackBar);
                        } else {

                          try {
                            setState(() {
                              onTap=true;
                            });
                            Duration videoDuration = _controller!.value.duration;
                            int size =await videoFile.length();

                            if (videoDuration.inSeconds > 60*5) {
                              // La durée de la vidéo dépasse 30 secondes, vous pouvez afficher une erreur ici
                              print("Erreur : La durée de la vidéo dépasse 5 min");
                              SnackBar snackBar = SnackBar(
                                content: Text(
                                  'La durée de la vidéo dépasse 5 min !',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.red),
                                ),
                              );

                              ScaffoldMessenger.of(context)
                                  .showSnackBar(snackBar);
                              setState(() {
                                onTap=false;
                              });
                            }else  if (size > 20971520) {
                              // La durée de la vidéo dépasse 30 secondes, vous pouvez afficher une erreur ici
                              SnackBar snackBar = SnackBar(
                                content: Text(
                                  'La vidéo est trop grande (plus de 20 Mo).',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.red),
                                ),
                              );

                              ScaffoldMessenger.of(context)
                                  .showSnackBar(snackBar);
                              setState(() {
                                onTap=false;
                              });
                            }else{
                              _uploadProgress =0;
                              String postId = FirebaseFirestore.instance
                                  .collection('Posts')
                                  .doc()
                                  .id;
                              Post post = Post();
                              post.user_id = authProvider.loginUserData.id;
                              post.description = _descriptionController.text;
                              post.updatedAt =
                                  DateTime.now().microsecondsSinceEpoch;
                              post.createdAt =
                                  DateTime.now().microsecondsSinceEpoch;
                              post.status = PostStatus.VALIDE.name;
                              post.type = PostType.POST.name;
                              post.dataType = PostDataType.VIDEO.name;
                              post.comments = 0;
                              post.likes = 0;
                              post.loves = 0;
                              post.id = postId;
                              post.images = [];
                              Reference storageReference =
                              FirebaseStorage.instance.ref().child(
                                  'post_media/${Path.basename(File(videoFile.path).path)}');

                              UploadTask uploadTask = storageReference
                                  .putFile(File(videoFile.path)!);
                              uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
                                setState(() {
                                  _uploadProgress =
                                      snapshot.bytesTransferred / snapshot.totalBytes;
                                });
                              });

                              await uploadTask.whenComplete(() {
                                // Tâche de téléchargement terminée avec succès
                                print('File uploaded successfully');
                              });
                              await uploadTask.whenComplete(() async {
                                await storageReference
                                    .getDownloadURL()
                                    .then((fileURL) {
                                  print("url media");
                                  //  print(fileURL);

                                  post.url_media=fileURL;
                                });
                              });
                              print("video: ${post.url_media}");
                              await FirebaseFirestore.instance
                                  .collection('Posts')
                                  .doc(postId)
                                  .set(post.toJson());
                              listimages=[];
                              _descriptionController.text='';
                              setState(() {
                                onTap=false;
                              });
                              authProvider.loginUserData.mesPubs=authProvider.loginUserData.mesPubs!+1;
                              await userProvider.updateUser(authProvider.loginUserData!);

                              NotificationData notif=NotificationData();
                              notif.id=firestore
                                  .collection('Notifications')
                                  .doc()
                                  .id;
                              notif.titre="Nouveau post";
                              notif.receiver_id="";

                              notif.description="Une nouvelle video a été publié !";
                              notif.users_id_view=[];
                              notif.user_id=authProvider.loginUserData.id;
                              notif.updatedAt =
                                  DateTime.now().microsecondsSinceEpoch;
                              notif.createdAt =
                                  DateTime.now().microsecondsSinceEpoch;
                              notif.status = PostStatus.VALIDE.name;

                              // users.add(pseudo.toJson());

                              await firestore.collection('Notifications').doc(notif.id).set(notif.toJson());
                              print("///////////-- save notification --///////////////");
                              await authProvider
                                  .getAllUsersOneSignaUserId()
                                  .then(
                                    (userIds) async {
                                  if (userIds.isNotEmpty) {
                                    // await authProvider.sendNotification(
                                    //     userIds: userIds,
                                    //     smallImage: "${authProvider.loginUserData.imageUrl!}",
                                    //     send_user_id: "${authProvider.loginUserData.id!}",
                                    //     recever_user_id: "",
                                    //     message: "📢 ${authProvider.loginUserData.pseudo!} a posté un look video ✨",
                                    //
                                    //     type_notif: NotificationType.POST.name,
                                    //     post_id: "${post!.id!}",
                                    //     post_type: PostDataType.VIDEO.name, chat_id: ''
                                    // );
                                  }
                                },
                              );

                              SnackBar snackBar = SnackBar(
                                content: Text(
                                  'Le post a été validé avec succès !',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.green),
                                ),
                              );
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(snackBar);
                              // _controller = null;
                              setState(() {
                                _controller!.pause();
                                _controller=null;
                              });
                            }


                          } catch (e) {
                            print("erreur ${e}");
                            setState(() {
                              onTap=false;
                            });
                            SnackBar snackBar = SnackBar(
                              content: Text(
                                'La validation du post a échouée. Veuillez réessayer.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.red),
                              ),
                            );
                            ScaffoldMessenger.of(context)
                                .showSnackBar(snackBar);
                          }
                        }
                      }
                    },
                    child:onTap? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment:  CrossAxisAlignment.center,
                      children: [
                        Text('Progression du téléchargement: ${(_uploadProgress * 100).toStringAsFixed(2)}%'),
                        Center(
                          child: LoadingAnimationWidget.flickr(
                            size: 20,
                            leftDotColor: Colors.green,
                            rightDotColor: Colors.black,
                          ),
                        ),
                      ],
                    ): PostsButtons(
                      text: 'Créer',
                      hauteur: height*0.07,
                      largeur: width*0.9,
                      urlImage: 'assets/images/sender.png',
                    )),
              ],
            ),
          ),
        ),
      ],
    ),
  ),
)
    ) ;
  }
}
