import 'package:afrotok/models/model_data.dart';
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

class NewAppInfo extends StatefulWidget {

  @override
  State<NewAppInfo> createState() => _NewAppInfoState();
}

class _NewAppInfoState extends State<NewAppInfo> {
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

  Future<void> _getImages() async {
    await picker.pickMultiImage().then((images) {
      // Mettre à jour la liste des images
      setState(() {
        listimages =
            images.where((image) => images.indexOf(image) < 2).toList();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;
    return  Scaffold(
        appBar: AppBar(
          title: Text('New app info'),
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _titreController,
                    decoration: InputDecoration(
                      hintText: 'Titre',
                    ),
                    validator: (value) {
                      if (value!.isEmpty) {
                        return 'Le titre est obligatoire';
                      }
          
                      return null;
                    },
                  ),
                  SizedBox(
                    height: 25.0,
                  ),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: InputDecoration(
                      hintText: 'Description',
                    ),
                    validator: (value) {
                      if (value!.isEmpty) {
                        return 'La Description est obligatoire';
                      }
          
                      return null;
                    },
                  ),
                  SizedBox(
                    height: 100.0,
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
                              child: Image.file(
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

                            try {
                              String postId = FirebaseFirestore.instance
                                  .collection('Informations')
                                  .doc()
                                  .id;
                              Information infos = Information();
                              infos.id = postId;

                              infos.description = _descriptionController.text;
                              infos.titre = _titreController.text;
                              infos.updatedAt =
                                  DateTime.now().microsecondsSinceEpoch;
                              infos.createdAt =
                                  DateTime.now().microsecondsSinceEpoch;
                              infos.status = PostStatus.VALIDE.name;
                              infos.type = InfoType.APPINFO.name;
          
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
          
                                    infos.media_url=fileURL;
                                  });
                                });
                              }
                              await FirebaseFirestore.instance
                                  .collection('Informations')
                                  .doc(postId)
                                  .set(infos.toJson());
                              _descriptionController.text='';
                              _titreController.text='';
                              listimages.clear();
                              setState(() {
                                onTap=false;
                              });
                              NotificationData notif=NotificationData();
                              notif.id=firestore
                                  .collection('Notifications')
                                  .doc()
                                  .id;
                              notif.titre="Nouvelle Information";
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
          
                              SnackBar snackBar = SnackBar(
                                content: Text(
                                  'Le post a été validé avec succès !',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.green),
                                ),
                              );
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(snackBar);
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
        )
    );
  }
}
