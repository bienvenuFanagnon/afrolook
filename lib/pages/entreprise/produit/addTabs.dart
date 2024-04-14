

import 'dart:io';

import 'package:afrotok/constant/constColors.dart';
import 'package:anim_search_bar/anim_search_bar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:contained_tab_bar_view_with_custom_page_navigator/contained_tab_bar_view_with_custom_page_navigator.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:provider/provider.dart';
import 'package:simple_tags/simple_tags.dart';
import 'package:video_player/video_player.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:path/path.dart' as Path;
import '../../../constant/buttons.dart';
import '../../../constant/sizeButtons.dart';
import '../../../constant/sizeText.dart';
import '../../../constant/textCustom.dart';
import '../../../models/model_data.dart';
import '../../../providers/authProvider.dart';
import '../../../providers/userProvider.dart';



class UserPostPubImage extends StatefulWidget {

  @override
  State<UserPostPubImage> createState() => _UserPostPubImageState();
}

class _UserPostPubImageState extends State<UserPostPubImage> {

  final _formKey = GlobalKey<FormState>();
  late String phone="";
  late bool isValidPhoneNumber=false;
  GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final TextEditingController _titreController = TextEditingController();

  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _nbrJour = TextEditingController();
  late UserAuthProvider authProvider =
  Provider.of<UserAuthProvider>(context, listen: false);

  late UserProvider userProvider =
  Provider.of<UserProvider>(context, listen: false);
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  bool onTap = false;
  double prixTotal=0;
  double publicashTotal=0;
  double convertirPicoVersFemto(double pubCash) {
    return (pubCash * authProvider.appDefaultData.tarifPubliCash_to_xof!);
  }

  void _showBottomSheetCompterNonValide(double width) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          width: width,
          //height: 200,
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  "Fonctionnalité non disponible",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 10),
                Text(
                  "Cette fonctionnalité est actuellement uniquement disponible pour les entreprises partenaires dans le cadre de la version bêta. veuillez nous contacter.",
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);

                    Navigator.pushNamed(context, '/contact');


                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.email,color: Colors.black,),
                      SizedBox(width: 5,),
                      const Text('Contacter',style: TextStyle(color: Colors.white),),
                    ],
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  String formaterDoubleEnK(double valeur) {
    if (valeur >= 1000000) {
      return "${valeur / 1000000}M";
    } else if (valeur >= 1000) {
      return "${valeur / 1000}K";
    } else {
      return valeur.toString();
    }
  }
  String formaterIntEnK(int valeur) {
    if (valeur >= 1000000) {
      return "${valeur / 1000000}M";
    } else if (valeur >= 1000) {
      return "${valeur / 1000}K";
    } else {
      return valeur.toString();
    }
  }
  int totalAbonnes = 0;
  double calculerSommePrixComptes(List<UserData> utilisateurs) {
    totalAbonnes = 0;
    double somme = 0.0;
    for (UserData utilisateur in utilisateurs) {
      somme += utilisateur.compteTarif!;
      totalAbonnes += utilisateur.abonnes!;
    }
    return somme;
  }

  late List<XFile> listimages = [];


  final ImagePicker picker = ImagePicker();

  Future<void> _getImages() async {
    await picker.pickMultiImage().then((images) {
      // Mettre à jour la liste des images
      setState(() {
        listimages =
            images.where((image) => images.indexOf(image) < 2).toList();
        publicashTotal=(listimages.length*authProvider.appDefaultData.tarifImage!)+(calculerSommePrixComptes(collaborateurs)*2)+(int.parse(_nbrJour.text)*authProvider.appDefaultData.tarifjour!);
        prixTotal=convertirPicoVersFemto(publicashTotal);
      });
    });
  }
  List<UserData> collaborateurs=[];
  UserData selectedUser=UserData();
  List<String> pseudocollaborateurs=[];
  List<UserData> listUsers=[];
  searchUserList(UserData user){
    return Container(

      padding: EdgeInsets.only(
          left: 6, bottom: 3, top: 3, right: 0),
      margin: EdgeInsets.symmetric(horizontal: 2),

      child:  Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 15.0),
                  child: CircleAvatar(
                    radius: 15,
                    backgroundImage: NetworkImage(
                        '${user.imageUrl}'),
                  ),
                ),
                SizedBox(
                  height: 2,
                ),
                Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          //width: 100,
                          child: TextCustomerUserTitle(
                            titre: "@${user.pseudo}",
                            fontSize: 10,
                            couleur: ConstColors.textColors,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextCustomerUserTitle(
                          titre: "${formaterIntEnK(user.abonnes!)}",
                          fontSize: 10,
                          couleur: Colors.green,
                          fontWeight: FontWeight.w400,
                        ),
                        TextCustomerUserTitle(
                          titre: "popularité: ${((user.popularite!*100).toStringAsFixed(2))}%",
                          fontSize: 9,
                          couleur: Colors.red,
                          fontWeight: FontWeight.w400,
                        ),
                      ],
                    ),

                  ],
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: Column(
                children: [
                  SizedBox(
                    //width: 100,
                    child: TextCustomerUserTitle(
                      titre: "Tarif",
                      fontSize: 10,
                      couleur: ConstColors.textColors,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextCustomerUserTitle(
                    titre: "${user.compteTarif!.toStringAsFixed(2)}",
                    fontSize: 10,
                    couleur: Colors.green,
                    fontWeight: FontWeight.w400,
                  ),

                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

@override
  void initState() {
  _nbrJour.text="30";
  selectedUser=userProvider.listUsers.first;
  listUsers=userProvider.listUsers;
    // TODO: implement initState
    super.initState();
  }


  @override
  Widget build(BuildContext context) {
    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;
    return  SingleChildScrollView(

      child: Padding(
        padding: const EdgeInsets.only(left: 16.0,right: 16),
        child: Form(
          key: _formKey,
          child: SizedBox(
            width: width,
            height: height*1.5,
            child: Column(
              children: [
                ListTile(
                  title: Row(
                    children: [
                      Icon(Fontisto.whatsapp,color: Colors.green,),
                      SizedBox(width: 10,),
                      Text("Contact WhatsApp"),
                    ],
                  ),
                  trailing: Text(listimages.length.toString()),
                ),
                IntlPhoneField(

                  decoration: InputDecoration(
                    labelText: 'Numéro de téléphone',
                    border: OutlineInputBorder(
                      borderSide: BorderSide(),
                    ),
                  ),
                  initialCountryCode: 'TG',
                  onChanged: (ph) {
                    print(ph.completeNumber);
                    phone=ph.completeNumber;
                  },
                  validator: (p0) {
                    /*
                    isValidPhoneNumber=p0!.isValidNumber();
                    if (!isValidPhoneNumber) {

                      return 'Le numéro de téléphone est obligatoire.';
                    }else{


                    }

                     */
                    return null;
                  },
                ),

                ListTile(
                  title: Text("Nombre d'images"),
                  trailing: Text(listimages.length.toString()),
                ),
                ListTile(
                  title: Text("Nombre de collaborateurs"),
                  trailing: Text(collaborateurs.length.toString()),
                ),
                ListTile(
                  title: Text("Publicash total"),
                  trailing: Text('${publicashTotal.toStringAsFixed(2)}'),
                ),

                ListTile(
                  title: Text("Nombre de jours"),
                  trailing: SizedBox(
                    width: 50,
                    child: TextFormField(
                      readOnly: true,
                      onChanged: (value) {
                        setState(() {
                          print('v ${value}');
                          publicashTotal=(listimages.length*authProvider.appDefaultData.tarifImage!)+(calculerSommePrixComptes(collaborateurs)*2)+(int.parse(_nbrJour.text)*authProvider.appDefaultData.tarifjour!);
                          prixTotal=convertirPicoVersFemto(publicashTotal);
                        });

                      },
                      onSaved: (newValue) {
                        print('valeur ${newValue}');
                        setState(() {
                          publicashTotal=(listimages.length*authProvider.appDefaultData.tarifImage!)+(calculerSommePrixComptes(collaborateurs)*2)+(int.parse(_nbrJour.text)*authProvider.appDefaultData.tarifjour!);
                          prixTotal=convertirPicoVersFemto(publicashTotal);

                        });

                      },
                      keyboardType: TextInputType.number,
                      controller: _nbrJour,
                      decoration: InputDecoration(
                      ),

                    ),
                  ),
                ),
                ListTile(
                  title: Row(
                    children: [

                      Icon(Icons.group),
                      Text(" / jour")
                    ],
                  ),
                  trailing: Text('${formaterDoubleEnK(totalAbonnes*5+211)}'),
                ),
                ListTile(
                  title: Text("Prix total"),
                  trailing: Text('${prixTotal.toStringAsFixed(2)} XOF',style: TextStyle(fontWeight: FontWeight.w600,fontSize: 15,color: Colors.green),),
                ),
                SizedBox(
                  height: 25.0,
                ),
                TextFormField(
                  controller: _descriptionController,
                  decoration: InputDecoration(
                    hintText: 'Légende',
                  ),
                  maxLines: 2,
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



                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 20.0,bottom: 10),
                      child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Collaborateurs : ')),
                    ),
                    IconButton(onPressed: () async {
                      await userProvider.getUsers(authProvider.loginUserData.id!,context).then((value) async {


                      },);

                    }, icon: Icon(AntDesign.reload1,color: Colors.black,size: 20,))
                  ],
                ),

                Center(
                  child: Container(

                    child: DropdownSearch<UserData>(
                      
                      onChanged: (value) {
                        setState(() {
                          if (!pseudocollaborateurs.any((element) => value!.pseudo==element)) {
                            pseudocollaborateurs=[];
                            collaborateurs=[];
                            pseudocollaborateurs.add(value!.pseudo!);

                            collaborateurs.add(value!);
                            publicashTotal=(listimages.length*authProvider.appDefaultData.tarifImage!)+(calculerSommePrixComptes(collaborateurs)*2)+(int.parse(_nbrJour.text)*authProvider.appDefaultData.tarifjour!);
                            prixTotal=convertirPicoVersFemto(publicashTotal);
                          }

                        });

                      },

                      items: listUsers,

                      dropdownBuilder: (context, selectedItem) {

                          selectedUser=selectedItem!;


                        return searchUserList(selectedItem!);

                      },


                       selectedItem: selectedUser,

                      popupProps: PopupProps.dialog(

                        searchFieldProps: TextFieldProps(
                          //controller: _userEditTextController,
                          decoration: InputDecoration(
                            prefixIcon:  IconButton(
                              icon: Icon(Icons.search),
                              onPressed: () {
                                // _userEditTextController.clear();
                              },

                            ),
                            suffixIcon: IconButton(
                              icon: Icon(Icons.clear),
                              onPressed: () {
                                // _userEditTextController.clear();
                              },
                            ),
                          ),
                        ),
                        showSearchBox: true,
                        showSelectedItems: false,

                        itemBuilder: (context, item, isSelected) {

                          return searchUserList(item!);
                        },


                        // disabledItemFn: (UserData s) => s.startsWith('I'),
                      ),

                    //  popupItemBuilder: (context, item, isSelected) => _buildPopupItem(context, item, isSelected),
                    ),
                  ),
                ),
                SizedBox(
                  height: 5,
                ),
                SimpleTags(
                  content: pseudocollaborateurs,

                  wrapSpacing: 4,
                  wrapRunSpacing: 4,
                  onTagPress: (tag) {print('pressed $tag');
                  setState(() {

                    collaborateurs.remove(userProvider.listUsers.firstWhere((element) => element.pseudo==tag));
                    pseudocollaborateurs.remove(tag);
                    publicashTotal=(listimages.length*authProvider.appDefaultData.tarifImage!)+(calculerSommePrixComptes(collaborateurs)*2)+(int.parse(_nbrJour.text)*authProvider.appDefaultData.tarifjour!);
                    prixTotal=convertirPicoVersFemto(publicashTotal);
                  });
                  },
                  onTagLongPress: (tag) {print('long pressed $tag');},
                  onTagDoubleTap: (tag) {print('double tapped $tag');

                  },
                  tagContainerPadding: EdgeInsets.all(6),
                  tagTextStyle: TextStyle(color: Colors.blueAccent),
                  tagIcon: Icon(Icons.clear, size: 12),
                  tagContainerDecoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.all(
                      Radius.circular(20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Color.fromRGBO(139, 139, 142, 0.16),
                        spreadRadius: 1,
                        blurRadius: 1,
                        offset: Offset(1.75, 3.5), // c
                      )
                    ],
                  ),
                ),
                SizedBox(height: 60,),
                GestureDetector(
                    onTap:onTap?(){}: () async {
                      //_getImages();
                      if (userProvider.entrepriseData.type=='partenaire') {
                        if (_formKey.currentState!.validate()) {
                          if (phone.length<5) {
                            SnackBar snackBar = SnackBar(
                              backgroundColor: Colors.red,
                              content: Text(
                                'le numero de contact whatsapp',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white),
                              ),
                            );
                            ScaffoldMessenger.of(context)
                                .showSnackBar(snackBar);
                          }  else{
                            setState(() {
                              onTap=true;
                            });
                            if (userProvider.entrepriseData.publicash!>=publicashTotal) {
                              if (listimages.isEmpty) {
                                SnackBar snackBar = SnackBar(
                                  backgroundColor: Colors.red,
                                  content: Text(
                                    'Veuillez choisir une image.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.white),
                                  ),
                                );
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(snackBar);
                              }
                              else {
                                try {
                                  if (pseudocollaborateurs.isNotEmpty) {
                                    await userProvider.getUserEntreprise(authProvider.loginUserData.id!).then((value) {

                                    },);
                                    for(String item in pseudocollaborateurs){
                                      UserData user=   userProvider.listUsers.firstWhere((element) => element.pseudo==item);
                                      String postId = FirebaseFirestore.instance
                                          .collection('Posts')
                                          .doc()
                                          .id;
                                      Post post = Post();
                                      post.user_id = user.id;
                                      post.contact_whatsapp = phone;
                                      post.entreprise_id = userProvider.entrepriseData.id;
                                      post.description = _descriptionController.text;
                                      post.updatedAt =
                                          DateTime.now().microsecondsSinceEpoch;
                                      post.createdAt =
                                          DateTime.now().microsecondsSinceEpoch;
                                      post.status = PostStatus.VALIDE.name;
                                      post.type = PostType.PUB.name;
                                      post.comments = 0;
                                      post.dataType = PostDataType.IMAGE.name;
                                      post.likes = 0;
                                      post.loves = 0;
                                      post.id = postId;
                                      post.images = [];


                                      post.publiCashTotal = publicashTotal;
                                      post.nombreCollaborateur = collaborateurs.length;
                                      post.nombreImage = listimages.length;
                                      post.nombrePersonneParJour = int.parse(_nbrJour.text);
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


                                      user.pubEntreprise=user.pubEntreprise!+1;
                                      user.publiCash=user.publiCash!+user.compteTarif!;


                                      userProvider.entrepriseData.publication=userProvider.entrepriseData.publication!+1;


                                      await userProvider.updateUser(user);

                                    }
                                    userProvider.entrepriseData.publicash=userProvider.entrepriseData.publicash!-publicashTotal;
                                    await userProvider.updateEntreprise(userProvider.entrepriseData!);
                                    listimages=[];
                                    _descriptionController.text='';
                                    collaborateurs=[];
                                    pseudocollaborateurs=[];
                                    publicashTotal=0;
                                    prixTotal=0;
                                    _nbrJour.text='';

                                    SnackBar snackBar = SnackBar(
                                      content: Text(
                                        'Le post a été validé avec succès !',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(color: Colors.green),
                                      ),
                                    );
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(snackBar);
                                  } else{
                                    SnackBar snackBar = SnackBar(
                                      content: Text(
                                        'Veillez choisir un collaborateur !',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    );
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(snackBar);
                                  }

                                  setState(() {
                                    onTap=false;
                                  });
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
                            }  else{
                              SnackBar snackBar = SnackBar(
                                content: Text(
                                  'Fonds insuffisants pour cette opération',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.red),
                                ),
                              );
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(snackBar);
                            }

                            setState(() {
                              onTap=false;
                            });
                          }


                        }
                      }  else{
                        _showBottomSheetCompterNonValide(width);
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
      ),
    );


  }


}

class UserPostPubVideo extends StatefulWidget {
  @override
  State<UserPostPubVideo> createState() => _UserPostPubVideoState();
}

class _UserPostPubVideoState extends State<UserPostPubVideo> {
  final _formKey = GlobalKey<FormState>();
  late String title;

  late String phone="";
  late bool isValidPhoneNumber=false;
  GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final TextEditingController _titreController = TextEditingController();

  final TextEditingController _descriptionController = TextEditingController();
  bool onTap=false;
  double _uploadProgress =0;
  late List<XFile> listimages = [];
  List<UserData> listUsers=[];
  late XFile videoFile;
  //late   XFile? galleryVideo;
  bool isVideo = false;

  VideoPlayerController? _controller;
  VideoPlayerController? _toBeDisposed;

  final ImagePicker picker = ImagePicker();

  Future<void> _getImages() async {
    await picker.pickVideo(source: ImageSource.gallery).then((video) async {
      late VideoPlayerController controller;

      controller = VideoPlayerController.file(File(video!.path));
      videoFile=video;
      _controller = controller;





      const double volume = kIsWeb ? 0.0 : 1.0;
      await controller.setVolume(volume);
      await controller.initialize();
      await controller.setLooping(true);
      await controller.play();
      setState(() {
        publicashTotal=((listimages.length+1)*authProvider.appDefaultData.tarifVideo!)+(calculerSommePrixComptes(collaborateurs)*2)+(int.parse(_nbrJour.text)*authProvider.appDefaultData.tarifjour!);
        prixTotal=convertirPicoVersFemto(publicashTotal);
      });
    });
  }

  void _showBottomSheetCompterNonValide(double width) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          width: width,
          //height: 200,
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  "Fonctionnalité non disponible",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 10),
                Text(
                  "Cette fonctionnalité est actuellement uniquement disponible pour les entreprises partenaires dans le cadre de la version bêta. veuillez nous contacter.",
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);

                    Navigator.pushNamed(context, '/contact');


                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.email,color: Colors.black,),
                      SizedBox(width: 5,),
                      const Text('Contacter',style: TextStyle(color: Colors.white),),
                    ],
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }


  late UserAuthProvider authProvider =
  Provider.of<UserAuthProvider>(context, listen: false);

  late UserProvider userProvider =
  Provider.of<UserProvider>(context, listen: false);
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  void _checkVideoDuration( Duration videoDuration) {
    Duration videoDuration = _controller!.value.duration;

    if (videoDuration.inSeconds > 30) {
      // La durée de la vidéo dépasse 30 secondes, vous pouvez afficher une erreur ici
      print("Erreur : La durée de la vidéo dépasse 30 secondes");
    } else {
      // La durée de la vidéo est inférieure ou égale à 30 secondes
      print("La durée de la vidéo est conforme");
    }
  }

  final TextEditingController _nbrJour = TextEditingController();


  double prixTotal=0;
  double publicashTotal=0;
  double convertirPicoVersFemto(double pubCash) {
    return (pubCash * authProvider.appDefaultData.tarifPubliCash_to_xof!+1500);
  }
  String formaterDoubleEnK(double valeur) {
    if (valeur >= 1000000) {
      return "${valeur / 1000000}M";
    } else if (valeur >= 1000) {
      return "${valeur / 1000}K";
    } else {
      return valeur.toString();
    }
  }
  String formaterIntEnK(int valeur) {
    if (valeur >= 1000000) {
      return "${valeur / 1000000}M";
    } else if (valeur >= 1000) {
      return "${valeur / 1000}K";
    } else {
      return valeur.toString();
    }
  }
  int totalAbonnes = 0;
  double calculerSommePrixComptes(List<UserData> utilisateurs) {
    totalAbonnes = 0;
    double somme = 0.0;
    for (UserData utilisateur in utilisateurs) {
      somme += utilisateur.compteTarif!;
      totalAbonnes += utilisateur.abonnes!;
    }
    return somme;
  }







  List<UserData> collaborateurs=[];
  UserData selectedUser=UserData();
  List<String> pseudocollaborateurs=[];
  searchUserList(UserData user){
    return Container(

      padding: EdgeInsets.only(
          left: 6, bottom: 3, top: 3, right: 0),
      margin: EdgeInsets.symmetric(horizontal: 2),

      child:  Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 15.0),
                  child: CircleAvatar(
                    radius: 15,
                    backgroundImage: NetworkImage(
                        '${user.imageUrl}'),
                  ),
                ),
                SizedBox(
                  height: 2,
                ),
                Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          //width: 100,
                          child: TextCustomerUserTitle(
                            titre: "@${user.pseudo}",
                            fontSize: 10,
                            couleur: ConstColors.textColors,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextCustomerUserTitle(
                          titre: "${formaterIntEnK(user.abonnes!)}",
                          fontSize: 10,
                          couleur: Colors.green,
                          fontWeight: FontWeight.w400,
                        ),
                        TextCustomerUserTitle(
                          titre: "popularité: ${((user.popularite!*100).toStringAsFixed(2))}%",
                          fontSize: 9,
                          couleur: Colors.red,
                          fontWeight: FontWeight.w400,
                        ),
                      ],
                    ),

                  ],
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: Column(
                children: [
                  SizedBox(
                    //width: 100,
                    child: TextCustomerUserTitle(
                      titre: "Tarif",
                      fontSize: 10,
                      couleur: ConstColors.textColors,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextCustomerUserTitle(
                    titre: "${user.compteTarif!.toStringAsFixed(2)}",
                    fontSize: 10,
                    couleur: Colors.green,
                    fontWeight: FontWeight.w400,
                  ),

                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    _nbrJour.text="30";
    selectedUser=userProvider.listUsers.first;
    listUsers=userProvider.listUsers;
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
        height: height*1.5,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                ListTile(
                  title: Row(
                    children: [
                      Icon(Fontisto.whatsapp,color: Colors.green,),
                      SizedBox(width: 10,),
                      Text("Contact WhatsApp"),
                    ],
                  ),
                  trailing: Text(listimages.length.toString()),
                ),
                IntlPhoneField(

                  decoration: InputDecoration(
                    labelText: 'Numéro de téléphone',
                    border: OutlineInputBorder(
                      borderSide: BorderSide(),
                    ),
                  ),
                  initialCountryCode: 'TG',
                  onChanged: (ph) {
                    print(ph.completeNumber);
                    phone=ph.completeNumber;
                  },
                  validator: (p0) {
                    /*
                    isValidPhoneNumber=p0!.isValidNumber();
                    if (!isValidPhoneNumber) {

                      return 'Le numéro de téléphone est obligatoire.';
                    }else{


                    }

                     */
                    return null;
                  },
                ),

                ListTile(
                  title: Text("Nombre de collaborateurs"),
                  trailing: Text(collaborateurs.length.toString()),
                ),
                ListTile(
                  title: Text("Publicash total"),
                  trailing: Text('${publicashTotal.toStringAsFixed(2)}'),
                ),

                ListTile(
                  title: Text("Nombre de jours"),
                  trailing: SizedBox(
                    width: 50,
                    child: TextFormField(
                      readOnly: true,
                      onChanged: (value) {
                        setState(() {
                          print('v ${value}');
                          publicashTotal=((listimages.length+1)*authProvider.appDefaultData.tarifVideo!)+(calculerSommePrixComptes(collaborateurs)*2)+(int.parse(_nbrJour.text)*authProvider.appDefaultData.tarifjour!);
                          prixTotal=convertirPicoVersFemto(publicashTotal);
                        });

                      },
                      onSaved: (newValue) {
                        print('valeur ${newValue}');
                        setState(() {
                          publicashTotal=((listimages.length+1)*authProvider.appDefaultData.tarifVideo!)+(calculerSommePrixComptes(collaborateurs)*2)+(int.parse(_nbrJour.text)*authProvider.appDefaultData.tarifjour!);
                          prixTotal=convertirPicoVersFemto(publicashTotal);

                        });

                      },
                      keyboardType: TextInputType.number,
                      controller: _nbrJour,
                      decoration: InputDecoration(
                      ),

                    ),
                  ),
                ),
                ListTile(
                  title: Row(
                    children: [

                      Icon(Icons.group),
                      Text(" / jour")
                    ],
                  ),
                  trailing: Text('${formaterDoubleEnK(totalAbonnes*5+211) }'),
                ),
                ListTile(
                  title: Text("Prix total"),
                  trailing: Text('${prixTotal.toStringAsFixed(2)} XOF',style: TextStyle(fontWeight: FontWeight.w600,fontSize: 15,color: Colors.green),),
                ),
                SizedBox(
                  height: 25.0,
                ),

                TextFormField(
                  controller: _descriptionController,
                  decoration: InputDecoration(
                    hintText: 'Légende',
                  ),
                  maxLines: 2,
                  validator: (value) {
                    if (value!.isEmpty) {
                      return 'La légende est obligatoire';
                    }

                    return null;
                  },
                ),
                SizedBox(
                  height: 60,
                ),



                Padding(
                  padding: const EdgeInsets.only(right: 20.0,bottom: 10),
                  child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Collaborateurs : ')),
                ),

                Center(
                  child: Container(

                    child: DropdownSearch<UserData>(
                      onChanged: (value) {
                        setState(() {
                          if (!pseudocollaborateurs.any((element) => value!.pseudo==element)) {
                            pseudocollaborateurs=[];
                            collaborateurs=[];
                            pseudocollaborateurs.add(value!.pseudo!);

                            collaborateurs.add(value!);
                            publicashTotal=((listimages.length+1)*authProvider.appDefaultData.tarifImage!)+(calculerSommePrixComptes(collaborateurs)*2)+(int.parse(_nbrJour.text)*authProvider.appDefaultData.tarifjour!);
                            prixTotal=convertirPicoVersFemto(publicashTotal);
                          }

                        });

                      },

                      items: listUsers,


                      dropdownBuilder: (context, selectedItem) {

                        selectedUser=selectedItem!;


                        return searchUserList(selectedItem!);

                      },


                      selectedItem: selectedUser,

                      popupProps: PopupProps.dialog(

                        searchFieldProps: TextFieldProps(
                          //controller: _userEditTextController,
                          decoration: InputDecoration(
                            prefixIcon:  IconButton(
                              icon: Icon(Icons.search),
                              onPressed: () {
                                // _userEditTextController.clear();
                              },

                            ),
                            suffixIcon: IconButton(
                              icon: Icon(Icons.clear),
                              onPressed: () {
                                // _userEditTextController.clear();
                              },
                            ),
                          ),
                        ),
                        showSearchBox: true,
                        showSelectedItems: false,

                        itemBuilder: (context, item, isSelected) {

                          return searchUserList(item!);
                        },


                        // disabledItemFn: (UserData s) => s.startsWith('I'),
                      ),

                      //  popupItemBuilder: (context, item, isSelected) => _buildPopupItem(context, item, isSelected),
                    ),
                  ),
                ),
                SizedBox(
                  height: 5,
                ),
                SimpleTags(
                  content: pseudocollaborateurs,

                  wrapSpacing: 4,
                  wrapRunSpacing: 4,
                  onTagPress: (tag) {print('pressed $tag');
                  setState(() {

                    collaborateurs.remove(userProvider.listUsers.firstWhere((element) => element.pseudo==tag));
                    pseudocollaborateurs.remove(tag);
                    publicashTotal=((listimages.length+1)*authProvider.appDefaultData.tarifImage!)+(calculerSommePrixComptes(collaborateurs)*2)+(int.parse(_nbrJour.text)*authProvider.appDefaultData.tarifjour!);
                    prixTotal=convertirPicoVersFemto(publicashTotal);
                  });
                  },
                  onTagLongPress: (tag) {print('long pressed $tag');},
                  onTagDoubleTap: (tag) {print('double tapped $tag');

                  },
                  tagContainerPadding: EdgeInsets.all(6),
                  tagTextStyle: TextStyle(color: Colors.blueAccent),
                  tagIcon: Icon(Icons.clear, size: 12),
                  tagContainerDecoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.all(
                      Radius.circular(20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Color.fromRGBO(139, 139, 142, 0.16),
                        spreadRadius: 1,
                        blurRadius: 1,
                        offset: Offset(1.75, 3.5), // c
                      )
                    ],
                  ),
                ),
                SizedBox(height: 60,),

                GestureDetector(
                    onTap: () {
                      _getImages();
                    },
                    child: PostsButtons(
                      text: 'Sélectionner une Vidéo (max 30 s)',
                      hauteur: SizeButtons.hauteur,
                      largeur: SizeButtons.largeur,
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
                      if (userProvider.entrepriseData.type=='partenaire'){
                        if (_formKey.currentState!.validate()) {
                          if (phone.length<5) {
                            SnackBar snackBar = SnackBar(
                              backgroundColor: Colors.red,
                              content: Text(
                                'le numero de contact whatsapp',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white),
                              ),
                            );
                            ScaffoldMessenger.of(context)
                                .showSnackBar(snackBar);
                          }else{

                            if (_controller==null) {
                              SnackBar snackBar = SnackBar(
                                content: Text(
                                  'Veuillez choisir une video (max 30 s).',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.red),
                                ),
                              );
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(snackBar);
                            }
                            else {
                              final size = await videoFile.length();

                              try {
                                setState(() {
                                  onTap=true;
                                });
                                Duration videoDuration = _controller!.value.duration;

                                if (videoDuration.inSeconds > 30) {
                                  // La durée de la vidéo dépasse 30 secondes, vous pouvez afficher une erreur ici
                                  print("Erreur : La durée de la vidéo dépasse 30 secondes");
                                  SnackBar snackBar = SnackBar(
                                    content: Text(
                                      'La durée de la vidéo dépasse 30 secondes !',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  );

                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(snackBar);
                                  setState(() {
                                    onTap=false;
                                  });
                                }
                                else  if (size > 20971520) {
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



                                  setState(() {
                                    onTap=true;
                                  });
                                  if (userProvider.entrepriseData.publicash!>=publicashTotal) {

                                    try {
                                      if (pseudocollaborateurs.isNotEmpty) {
                                        await userProvider.getUserEntreprise(authProvider.loginUserData.id!).then((value) {

                                        },);
                                        for(String item in pseudocollaborateurs){
                                          UserData user=   userProvider.listUsers.firstWhere((element) => element.pseudo==item);
                                          String postId = FirebaseFirestore.instance
                                              .collection('Posts')
                                              .doc()
                                              .id;
                                          Post post = Post();
                                          post.user_id = user.id;
                                          post.contact_whatsapp = phone;

                                          post.entreprise_id = userProvider.entrepriseData.id;
                                          post.description = _descriptionController.text;
                                          post.updatedAt =
                                              DateTime.now().microsecondsSinceEpoch;
                                          post.createdAt =
                                              DateTime.now().microsecondsSinceEpoch;
                                          post.status = PostStatus.VALIDE.name;
                                          post.type = PostType.PUB.name;
                                          post.comments = 0;
                                          post.dataType = PostDataType.VIDEO.name;
                                          post.likes = 0;
                                          post.loves = 0;
                                          post.id = postId;
                                          post.images = [];


                                          post.publiCashTotal = publicashTotal;
                                          post.nombreCollaborateur = collaborateurs.length;
                                          post.nombreImage = listimages.length;
                                          post.nombrePersonneParJour = int.parse(_nbrJour.text);
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


                                          user.pubEntreprise=user.pubEntreprise!+1;
                                          user.publiCash=user.publiCash!+user.compteTarif!;

                                          userProvider.entrepriseData.publication=userProvider.entrepriseData.publication!+1;



                                          await userProvider.updateUser(user);

                                        }
                                        userProvider.entrepriseData.publicash=userProvider.entrepriseData.publicash!-publicashTotal;
                                        await userProvider.updateEntreprise(userProvider.entrepriseData!);
                                        listimages=[];
                                        _descriptionController.text='';
                                        collaborateurs=[];
                                        pseudocollaborateurs=[];
                                        publicashTotal=0;
                                        prixTotal=0;
                                        _nbrJour.text='';

                                        SnackBar snackBar = SnackBar(
                                          content: Text(
                                            'Le post a été validé avec succès !',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(color: Colors.green),
                                          ),
                                        );
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(snackBar);
                                        setState(() {
                                          _controller!.pause();
                                          _controller=null;
                                        });
                                      } else{
                                        SnackBar snackBar = SnackBar(
                                          content: Text(
                                            'Veillez choisir un collaborateur !',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(color: Colors.red),
                                          ),
                                        );
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(snackBar);
                                      }

                                      setState(() {
                                        onTap=false;
                                      });


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

                                  }  else{
                                    SnackBar snackBar = SnackBar(
                                      content: Text(
                                        'Fonds insuffisants pour cette opération',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    );
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(snackBar);
                                  }

                                  setState(() {
                                    onTap=false;
                                  });



                                }


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
                          }

                        }
                      }else{
                        _showBottomSheetCompterNonValide( width);
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
                      hauteur: SizeButtons.creerButtonshauteur,
                      largeur: SizeButtons.creerButtonslargeur,
                      urlImage: 'assets/images/sender.png',
                    )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}