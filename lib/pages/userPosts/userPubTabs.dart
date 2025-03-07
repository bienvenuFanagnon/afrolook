import 'dart:math';

import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/pages/component/consoleWidget.dart';
import 'package:camera/camera.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
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
import 'package:video_compress/video_compress.dart';
import 'package:video_player/video_player.dart';
import 'package:dropdown_search/dropdown_search.dart';

import '../../constant/buttons.dart';
import '../../constant/sizeButtons.dart';
import '../../providers/authProvider.dart';
import '../../providers/postProvider.dart';
import '../../providers/userProvider.dart';
import '../home/homeWidget.dart';
import 'hashtag/textHashTag/views/view_models/home_view_model.dart';
import 'hashtag/textHashTag/views/view_models/search_view_model.dart';
import 'hashtag/textHashTag/views/widgets/comment_text_field.dart';
import 'hashtag/textHashTag/views/widgets/search_result_overlay.dart';





class UserPubText extends StatefulWidget {
   final Canal? canal;
  UserPubText({super.key, required this.canal});
  @override
  State<UserPubText> createState() => _UserPubTextState();
}

class _UserPubTextState extends State<UserPubText> with TickerProviderStateMixin{
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

  late List<XFile> listimages = [];

  final ImagePicker picker = ImagePicker();

  int  limitePosts = 30;

  Future<void> _getImages() async {
    await picker.pickMultiImage().then((images) {
      // Mettre à jour la liste des images
      setState(() {
        listimages =
            images.where((image) => images.indexOf(image) < 2).toList();
      });
    });
  }


  // Liste initiale des hashtags avec popularité
  Map<String, int> hashtags = {
    "#Afrolook": 50,
    "#Entrepreneur": 35,
    "#Music": 20,
    "#Lifestyle": 15,
    "#Travel": 10,
    "#Fitness": 8,
    "#Food": 5,
    "#Technology": 3,
    "#Education": 2,
    "#Flutter": 1,
  };

  List<String> filteredHashtags = [];
  String currentHashtag = "";

  // Filtre les hashtags en fonction de la saisie
  void _onTextChanged(String value) {
    setState(() {
      final words = value.split(" ");
      final lastWord = words.isNotEmpty ? words.last : "";

      if (lastWord.startsWith("#")) {
        currentHashtag = lastWord;
        filteredHashtags = hashtags.keys
            .where((tag) =>
            tag.toLowerCase().contains(currentHashtag.toLowerCase()))
            .toList();
        // Trie par popularité décroissante
        filteredHashtags.sort((a, b) => hashtags[b]!.compareTo(hashtags[a]!));
      } else {
        currentHashtag = "";
        filteredHashtags.clear();
      }
    });
  }

  // Ajoute un hashtag ou augmente sa popularité
  void _addHashtag(String hashtag) {
    setState(() {
      if (!hashtags.containsKey(hashtag)) {
        hashtags[hashtag] = 1; // Nouveau hashtag avec une popularité initiale
      } else {
        hashtags[hashtag] = hashtags[hashtag]! + 1; // Augmente la popularité
      }
      // Met à jour le champ de texte
      _descriptionController.text += " $hashtag ";
      currentHashtag = "";
      filteredHashtags.clear();
    });
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
  String? _selectedPostType; // Variable pour stocker la valeur sélectionnée (code)
  String? _selectedPostTypeLibeller; // Variable pour stocker la valeur sélectionnée (code)

  // Map des types de post avec code et libellé
  final Map<String, Map<String, dynamic>> _postTypes = {
    'ACTUALITES': {
      'label': 'Actualités',
      'icon': Icons.article,
    },
    'LOOKS': {
      'label': 'Looks',
      'icon': Icons.style,
    },
    'SPORT': {
      'label': 'Sport',
      'icon': Icons.sports,
    },
    'EVENEMENT': {
      'label': 'Événement',
      'icon': Icons.event,
    },
    'OFFRES': {
      'label': 'Offres',
      'icon': Icons.local_offer,
    },
    'GAMER': {
      'label': 'Games story',
      'icon': Icons.gamepad,
    },
  };
  @override
  void initState() {
    super.initState();
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
    return SingleChildScrollView(
      child: SizedBox(
        width: width,
        height: height * 0.85,
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text("Type post: ${widget.canal==null?"Look":"Canal"}"),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _descriptionController,
                      onChanged: _onTextChanged,
                      // readOnly: true, // Empêche la modification

                      decoration: InputDecoration(
                        hintText: 'Exprimez votre pensée',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0), // Add rounded corners
                          borderSide: BorderSide(color: Colors.green, width: 2.0), // Customize color and thickness
                        ),
                      ),
                      keyboardType: TextInputType.multiline,
                      maxLines: null,
                      maxLength: 300,

                      validator: (value) {
                        if (value!.isEmpty) {
                          return 'La légende est obligatoire';
                        }

                        return null;
                      },
                    ),

                    // Liste déroulante pour le type de post
                    SizedBox(height: 20),

                    // Liste déroulante pour le type de post
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        hintText: 'Type de post',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0), // Add rounded corners
                          borderSide: BorderSide(color: Colors.green, width: 2.0), // Customize color and thickness
                        ),
                      ),

                      value: _selectedPostType,
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedPostType = newValue;
                          printVm('_selectedPostType: ${_selectedPostType}');
                          String? selectedLabel = _postTypes[_selectedPostType]?['label'];
                          _selectedPostTypeLibeller=selectedLabel;

                          printVm('selectedLabel: ${selectedLabel}');
                        });
                      },
                      items: _postTypes.entries.map<DropdownMenuItem<String>>((entry) {
                        return DropdownMenuItem<String>(
                          value: entry.key, // Utilisez la clé (code) comme valeur
                          child: Row(
                            children: [
                              Icon(entry.value['icon'], color: Colors.green), // Icône
                              SizedBox(width: 10),
                              Text(entry.value['label']), // Libellé
                            ],
                          ),
                        );
                      }).toList(),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez sélectionner un type de post';
                        }
                        return null;
                      },
                    ),
                    SizedBox(
                      height: 60,
                    ),
                    FlutterTagger(
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

                              setState(() {
                                onTap=true;
                              });

                              try {
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
                                post.comments = 0;
                                post.nombrePersonneParJour = 60;
                                post.dataType = PostDataType.TEXT.name;
                            post.typeTabbar = _selectedPostType;
                                post.likes = 0;
                                post.loves = 0;
                                post.id = postId;
                                post.images = [];
                                String postMId = FirebaseFirestore.instance
                                    .collection('PostsMonetiser')
                                    .doc()
                                    .id;
                                PostMonetiser postMonetiser = PostMonetiser(
                                  id: postMId,
                                  user_id: authProvider.loginUserData.id,
                                  post_id: postId,
                                  users_like_id: [],
                                  users_love_id: [],
                                  users_comments_id: [],
                                  users_partage_id: [],
                                  solde: 0.1,
                                  createdAt: DateTime.now().millisecondsSinceEpoch,
                                  updatedAt: DateTime.now().millisecondsSinceEpoch,
                                );

                                if(widget.canal!=null){
                                  post.canal_id=widget.canal!.id;
                                  post.categorie="CANAL";
                                }

                                await FirebaseFirestore.instance
                                    .collection('Posts')
                                    .doc(postId)
                                    .set(post.toJson());
                                await FirebaseFirestore.instance
                                    .collection('PostsMonetiser')
                                    .doc(postMId)
                                    .set(postMonetiser.toJson());
                                listimages=[];
                                _descriptionController.text='';
                                setState(() {
                                  onTap=false;
                                });
                                authProvider.loginUserData.mesPubs=authProvider.loginUserData.mesPubs!+1;
                                await userProvider.updateUser(authProvider.loginUserData!);
                                postProvider.listConstposts.add(post);

                                if(widget.canal!=null){
                                  await authProvider
                                      .getAllUsersOneSignaUserId()
                                      .then(
                                        (userIds) async {
                                      if (userIds.isNotEmpty) {
                                        await authProvider.sendNotification(
                                            userIds: userIds,
                                            smallImage: "${widget.canal!.urlImage}",
                                            send_user_id: "${authProvider.loginUserData.id!}",
                                            recever_user_id: "",
                                            message: "📢 Canal ${widget.canal!.titre} ${getTabBarTypeMessage(_selectedPostType!)}",
                                            type_notif: NotificationType.POST.name,
                                            post_id: "${post!.id!}",
                                            post_type: PostDataType.IMAGE.name, chat_id: ''
                                        );

                                      }
                                    },
                                  );
                                  widget.canal!.updatedAt =
                                      DateTime.now().microsecondsSinceEpoch;
                                  postProvider.updateCanal( widget.canal!, context);
                                }else{
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
                                            message: "📢 ${authProvider.loginUserData.pseudo!} ${getTabBarTypeMessage(_selectedPostType!)}",
                                            type_notif: NotificationType.POST.name,
                                            post_id: "${post!.id!}",
                                            post_type: PostDataType.IMAGE.name, chat_id: ''
                                        );

                                      }
                                    },
                                  );
                                }



                                // NotificationData notif=NotificationData();
                                // notif.id=firestore
                                //     .collection('Notifications')
                                //     .doc()
                                //     .id;
                                // notif.titre="Nouveau post";
                                // notif.description="Un nouveau look a été publié !";
                                // notif.users_id_view=[];
                                // notif.receiver_id="";
                                //
                                // notif.user_id=authProvider.loginUserData.id;
                                // notif.updatedAt =
                                //     DateTime.now().microsecondsSinceEpoch;
                                // notif.createdAt =
                                //     DateTime.now().microsecondsSinceEpoch;
                                // notif.status = PostStatus.VALIDE.name;

                                // users.add(pseudo.toJson());

                                // await firestore.collection('Notifications').doc(notif.id).set(notif.toJson());
                                print("///////////-- save notification --///////////////");

                                SnackBar snackBar = SnackBar(
                                  content: Text(
                                    'Le post a été validé avec succès !',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.green),
                                  ),
                                );
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(snackBar);
                                // postProvider.getPostsImages(limitePosts).then((value) {
                                //   // value.forEach((element) {
                                //   //   print(element.toJson());
                                //   // },);
                                //
                                // },);

                              } catch (e) {
                                print("erreur ${e}");
                                setState(() {
                                  onTap=false;
                                });
                                SnackBar snackBar = SnackBar(
                                  content: Text(
                                    'La validation du post a échoué. Veuillez réessayer.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.red),
                                  ),
                                );
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(snackBar);
                              }

                            }



                            _descriptionController.clear();
                          },
                        );
                      },
                    ),

                    // GestureDetector(
                    //     onTap:onTap?(){}: () async {
                    //       //_getImages();
                    //       if (_formKey.currentState!.validate()) {
                    //
                    //         setState(() {
                    //           onTap=true;
                    //         });
                    //
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
                    //             post.dataType = PostDataType.TEXT.name;
                    //             post.likes = 0;
                    //             post.loves = 0;
                    //             post.id = postId;
                    //             post.images = [];
                    //
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
                    //             await authProvider
                    //                 .getAllUsersOneSignaUserId()
                    //                 .then(
                    //                   (userIds) async {
                    //                 if (userIds.isNotEmpty) {
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
                    //             print("erreur ${e}");
                    //             setState(() {
                    //               onTap=false;
                    //             });
                    //             SnackBar snackBar = SnackBar(
                    //               content: Text(
                    //                 'La validation du post a échoué. Veuillez réessayer.',
                    //                 textAlign: TextAlign.center,
                    //                 style: TextStyle(color: Colors.red),
                    //               ),
                    //             );
                    //             ScaffoldMessenger.of(context)
                    //                 .showSnackBar(snackBar);
                    //           }
                    //
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
                    //       hauteur: height*0.07,
                    //       largeur: width*0.9,
                    //       urlImage: 'assets/images/sender.png',
                    //     )),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
class UserPubImage extends StatefulWidget {
  @override
  State<UserPubImage> createState() => _UserPubImageState();
}

class _UserPubImageState extends State<UserPubImage> {
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
  late CameraController _cameraController;

  late List<XFile> listimages = [];

  final ImagePicker picker = ImagePicker();
  late  Uint8List? fileReadAsStringContent;
  int  limitePosts = 30;

  bool isSwitched = false;
  Future<XFile> compressImageFile(File file, String targetPath) async {
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

  Future<void> _getImages() async {
    await picker.pickMultiImage().then((images) {
      // Mettre à jour la liste des images
      setState(() async {
        listimages =
            images.where((image) => images.indexOf(image) < 2).toList();
       images.first.readAsBytes().then((value) async {
         final random = Random();
         final randomString = String.fromCharCodes(List.generate(10, (index) => random.nextInt(33) + 89));
         String targetPath = '${File.fromRawPath(value).path}/compressed_${randomString}';

         XFile compressedFile = await compressImageFile(File.fromRawPath(value), targetPath);
         fileReadAsStringContent =await compressedFile.readAsBytes();
        },);

      });
    });
  }






  @override
  void dispose() {
    // TODO: implement dispose
    super.dispose();
     // Tflite.close();
    // _cameraController.dispose();
  }
  @override
  void initState() {
    // TODO: implement initState
    super.initState();



  }
  @override
  Widget build(BuildContext context) {
    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;
    // if (!_cameraController.value.isInitialized) {
    //   return Container();
    // }
    // return CameraPreview(_cameraController);
    // return TfLiteSnap();
    return SingleChildScrollView(
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
                      height: 25.0,
                    ),
                    GestureDetector(
                        onTap: () {
                          _getImages();
                        },
                        child: PostsButtons(
                          text: 'Sélectionner des images(2)',
                          hauteur: SizeButtons.hauteur,
                          largeur: SizeButtons.largeur,
                          urlImage: '',
                        )),
                    listimages.isNotEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Wrap(
                              children: listimages
                                  .map(
                                    (image) => Padding(
                                      padding: const EdgeInsets.only(right: 8.0),
                                      child: ClipRRect(

                                        borderRadius:
                                            BorderRadius.all(Radius.circular(20)),
                                        child: Container(
                                          width: 100.0,
                                          height: 100.0,
                                          child:kIsWeb?Image.memory(
                                            fileReadAsStringContent!,
                                            fit: BoxFit.cover,
                                          ): Image.file(
                                            File(image.path),
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          )
                        : Container(),

                    SizedBox(
                      height: 60,
                    ),
                    GestureDetector(
                        onTap:onTap?(){}: () async {
                          //_getImages();
                          if (_formKey.currentState!.validate()) {

                            setState(() {
                              onTap=true;
                            });
                            if (listimages.isEmpty) {
                              SnackBar snackBar = SnackBar(
                                content: Text(
                                  'Veuillez choisir une image.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.red),
                                ),
                              );
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(snackBar);
                            } else {
                              try {
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
                                post.comments = 0;
                                post.nombrePersonneParJour = 60;
                                post.dataType = PostDataType.IMAGE.name;
                                post.likes = 0;
                                post.loves = 0;
                                post.id = postId;
                                post.images = [];
                                for (XFile _image in listimages) {
                                  Reference storageReference =
                                      FirebaseStorage.instance.ref().child(
                                          'post_media/${Path.basename(File(_image.path).path)}');

                                  UploadTask uploadTask = storageReference
                                      .putFile(File(_image.path)!);
                                  await uploadTask.whenComplete(() async {
                                    await storageReference
                                        .getDownloadURL()
                                        .then((fileURL) {
                                      print("url media");
                                      //  print(fileURL);

                                      post.images!.add(fileURL);
                                    });
                                  });
                                }
                                print("images: ${post.images!.length}");
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
                                postProvider.listConstposts.add(post);



                                NotificationData notif=NotificationData();
                                notif.id=firestore
                                    .collection('Notifications')
                                    .doc()
                                    .id;
                                notif.titre="Nouveau post";
                                notif.description="Un nouveau post a été publié !";
                                notif.users_id_view=[];
                                notif.receiver_id="";

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
                                SnackBar snackBar = SnackBar(
                                  content: Text(
                                    'Le post a été validé avec succès !',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.green),
                                  ),
                                );
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(snackBar);
                                postProvider.getPostsImages(limitePosts).then((value) {
                                  // value.forEach((element) {
                                  //   print(element.toJson());
                                  // },);

                                },);

                              } catch (e) {

                                print("erreur ${e}");
                                setState(() {
                                  onTap=false;
                                });
                                /*

                                SnackBar snackBar = SnackBar(
                                  content: Text(
                                    'La validation du post a échoué. Veuillez réessayer.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.red),
                                  ),
                                );
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(snackBar);

                                 */
                              }
                            }
                          }
                        },
                        child:onTap? Center(
                          child: LoadingAnimationWidget.flickr(
                            size: 20,
                            leftDotColor: Colors.green,
                            rightDotColor: Colors.black,
                          ),
                        ): PostsButtons(
                          text: 'Créer',
                          hauteur: SizeButtons.creerButtonshauteur,
                          largeur: SizeButtons.creerButtonslargeur,
                          urlImage: 'assets/images/sender.png',
                        )),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class UserPubVideo extends StatefulWidget {
  @override
  State<UserPubVideo> createState() => _UserPubVideoState();
}

class _UserPubVideoState extends State<UserPubVideo> {
  final _formKey = GlobalKey<FormState>();
  late String title;


  GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final TextEditingController _titreController = TextEditingController();

  final TextEditingController _descriptionController = TextEditingController();
bool onTap=false;
  double _uploadProgress =0;
  late List<XFile> listimages = [];

  late XFile originalvideoFile;
  late XFile videoFile;
  //late   XFile? galleryVideo;
  bool isVideo = false;

  VideoPlayerController? _controller;
  VideoPlayerController? _toBeDisposed;

  final ImagePicker picker = ImagePicker();



  Future<void> _getImages() async {
    await picker.pickVideo(source: ImageSource.gallery).then((video) async {
      late VideoPlayerController controller;
      if(kIsWeb){
        controller = VideoPlayerController.networkUrl(Uri.parse(video!.path));
        videoFile=video;
        _controller = controller;
      }else{
        final thumbnailFile = await VideoCompress.getFileThumbnail(
            video!.path,
            quality: 50, // default(100)
            position: -1 // default(-1)
        );
        videoFile=video!;
        // originalvideoFile=video!;
        // videoFile=XFile(thumbnailFile.path)!;
        // originalvideoFile.length()
        // print('Vidéo originale: ${originalvideoFile.length} bytes');
        // print('Vidéo compressée: ${videoFile.length()} bytes');
        controller = VideoPlayerController.file(File(video!.path));
        _controller = controller;
      }



      Future<void> getVideo() async {
        await picker.pickVideo(source: ImageSource.gallery).then((video) async {
          late VideoPlayerController controller;
          if(kIsWeb){
            controller = VideoPlayerController.networkUrl(Uri.parse(video!.path));
            videoFile=video;
            _controller = controller;
          }else{
            final thumbnailFile = await VideoCompress.getFileThumbnail(
                video!.path,
                quality: 80, // default(100)
                position: -1 // default(-1)
            );
            originalvideoFile=video!;
            videoFile=XFile(thumbnailFile.path)!;
            originalvideoFile.length().then((value) {
              print('Vidéo originale: ${value} bytes');

            },);
            videoFile.length().then((value) {
              print('Vidéo compressée: ${value} bytes');

            },);
            // controller = VideoPlayerController.file(File(video!.path));
            controller = VideoPlayerController.file(File(videoFile!.path));
            _controller = controller;
          }







          const double volume = kIsWeb ? 0.0 : 1.0;
          await controller.setVolume(volume);
          await controller.initialize();
          await controller.setLooping(true);
          await controller.play();
          setState(() {});
        });
      }




      const double volume = kIsWeb ? 0.0 : 1.0;
      await controller.setVolume(volume);
      await controller.initialize();
      await controller.setLooping(true);
      await controller.play();
      setState(() {});
    });
  }

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
    super.initState();
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
    return SingleChildScrollView(
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
                    SizedBox(
                      height: 16.0,
                    ),
                    GestureDetector(
                        onTap: () {
                          _getImages();
                        },
                        child: PostsButtons(
                          text: 'Sélectionner une Vidéo (max 5 min 20 mo)',
                          hauteur: height*0.07,
                          largeur: width*0.9,
                          urlImage: '',
                        )),
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

                              String postMId = FirebaseFirestore.instance
                                  .collection('PostsMonetiser')
                                  .doc()
                                  .id;
                              PostMonetiser postMonetiser = PostMonetiser(
                                id: postMId,
                                user_id: authProvider.loginUserData.id,
                                post_id: postId,
                                users_like_id: [],
                                users_love_id: [],
                                users_comments_id: [],
                                users_partage_id: [],
                                solde: 0.1,
                                createdAt: DateTime.now().millisecondsSinceEpoch,
                                updatedAt: DateTime.now().millisecondsSinceEpoch,
                              );
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

                              await FirebaseFirestore.instance
                                  .collection('PostsMonetiser')
                                  .doc(postMId)
                                  .set(postMonetiser.toJson());
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
                                    await authProvider.sendNotification(
                                        userIds: userIds,
                                        smallImage: "${authProvider.loginUserData.imageUrl!}",
                                        send_user_id: "${authProvider.loginUserData.id!}",
                                        recever_user_id: "",
                                        message: "📢 ${authProvider.loginUserData.pseudo!} a posté un look video ✨",

                                        type_notif: NotificationType.POST.name,
                                        post_id: "${post!.id!}",
                                        post_type: PostDataType.VIDEO.name, chat_id: ''
                                    );
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
    );
  }
}
