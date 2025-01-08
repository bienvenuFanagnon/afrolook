import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../../constant/custom_theme.dart';
import '../../../../providers/afroshop/authAfroshopProvider.dart';
import '../../../../providers/afroshop/categorie_produits_provider.dart';
import 'abonement.dart';
class AddStore extends StatefulWidget {
  const AddStore({super.key});

  @override
  State<AddStore> createState() => _AddStoreState();
}

class _AddStoreState extends State<AddStore> {
  late UserShopAuthProvider authProvider =
  Provider.of<UserShopAuthProvider>(context, listen: false);
  late CategorieProduitProvider categorieProduitProvider =
  Provider.of<CategorieProduitProvider>(context, listen: false);
  bool onSaveTap=false;
  late TextEditingController nomController=TextEditingController();
  final _formKey = GlobalKey<FormState>();

  final ImagePicker picker = ImagePicker();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  List<XFile>? _mediaFileList = [];
  void pickImages() async {
    //List<ImageSource> selectedImages = await ImagePicker.pickMultipleImages();
    await picker.pickMultiImage().then((images) {
      setState(() {
        if (images != null && images.isNotEmpty) {
          _mediaFileList!.addAll(images);
          //  nbr_photos=_mediaFileList!.length;
        }
      });
    });
  }
  @override
  Widget build(BuildContext context) {
    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;
    return Scaffold(
        appBar: AppBar(
          title: Text('Ajouter un magasin'),
        ),
      bottomSheet:     Container(
        height: 100,
        width: width,

        child: TextButton(
          onPressed: () async {
            Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SubscriptionGridView(),
                ));

    if (_formKey.currentState!.validate()) {

    }
    /*
            if (_formKey.currentState!.validate()) {
              _formKey.currentState!.save();
              ArticleData annonceRegisterData =ArticleData();
              annonceRegisterData.images=[];
              annonceRegisterData.titre=_titre;
              annonceRegisterData.description=_description;
              annonceRegisterData.vues=0;
              annonceRegisterData.popularite=1;
              annonceRegisterData.jaime=0;
              annonceRegisterData.contact=0;
              annonceRegisterData.prix=_prix;
              annonceRegisterData.user_id=authProvider.loginData.id!;
              annonceRegisterData.categorie_id=categorieSelected.id;


              //  print('sous categorie id: $sousCategorieSelected.id');
              print('Titre: $_titre');
              print('Description: $_description');
              print('Prix: $_prix');



              if (_mediaFileList!.isNotEmpty) {
                setState(() {
                  onSaveTap = true;
                });
                // List<ProduitImages> listImages = [];

                // print("produit final : ${produit.toJson()}");
                //print("user token : ${authProvider.loginData.token!}");
                annonceRegisterData.updatedAt =
                    DateTime.now().microsecondsSinceEpoch;
                annonceRegisterData.createdAt =
                    DateTime.now().microsecondsSinceEpoch;



                for (XFile _image in _mediaFileList!) {
                  Reference storageReference =
                  FirebaseStorage.instance.ref().child(
                      'images_article/${Path.basename(File(_image.path).path)}');

                  UploadTask uploadTask = storageReference
                      .putFile(File(_image.path)!);
                  await uploadTask.whenComplete(() async {
                    await storageReference
                        .getDownloadURL()
                        .then((fileURL) {
                      print("url media");
                      //  print(fileURL);

                      annonceRegisterData.images!.add(fileURL);
                    });
                  });
                }


                String postId = FirebaseFirestore.instance
                    .collection('Articles')
                    .doc()
                    .id;
                annonceRegisterData.id=postId;

/*
                  setState(() {
                    onTap=false;
                  });

 */
                await categorieProduitProvider.createArticle(
                    annonceRegisterData
                )
                    .then((value) {
                  if (value) {
                    final snackBar = SnackBar(
                        backgroundColor: Colors.green,
                        duration: Duration(seconds: 1),
                        content: Text("Article ajouté",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.white),));

                    // Afficher le SnackBar en bas de la page
                    ScaffoldMessenger.of(context)
                        .showSnackBar(snackBar);



                    _titre='';
                    _description='';
                    _prix=0;
                    _mediaFileList = [];
                    _formKey.currentState!.reset();

                    setState(() {
                      onSaveTap = false;
                    });
                    //categorieProduitProvider.getCategories();
/*
                      Navigator.pushReplacementNamed(
                          context, "/home");

 */
                  } else {
                    final snackBar = SnackBar(
                        backgroundColor: Colors.red,
                        duration: Duration(seconds: 1),
                        content: Text(
                          "Erreur d'ajout du produit",
                          style: TextStyle(
                              color: Colors.white),));
                    // Afficher le SnackBar en bas de la page
                    ScaffoldMessenger.of(context)
                        .showSnackBar(snackBar);
                    setState(() {
                      onSaveTap = false;
                    });
                  }
                });


              }
              else {
                setState(() {
                  onSaveTap = false;
                });
                final snackBar = SnackBar(
                    duration: Duration(seconds: 2),
                    content: Text(
                      "Veillez ajouter les images",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.red),));

                // Afficher le SnackBar en bas de la page
                ScaffoldMessenger.of(context).showSnackBar(
                    snackBar);
              }
              // Navigator.push(context, MaterialPageRoute(builder: (context) => AddAnnonceStep4(annonceRegisterData: annonceRegisterData),));


            }

             */
          },
          child:onSaveTap?Container(
              height: 20,
              width: 20,

              child: CircularProgressIndicator()): Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: CustomConstants.kPrimaryColor,
                  borderRadius: BorderRadius.all(Radius.circular(5))
              ),
              height: 50,
              width: width*0.8,
              child: Text('Continuer',style: TextStyle(color: Colors.white),)),
        ),
      ),

      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(5.0),
              child: Card(
                elevation: 5,
                surfaceTintColor: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Container(
                    //height: 800,
                    width: width,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      //mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing:
                          8.0, // Espace horizontal entre les objets
                          runSpacing:
                          8.0, // Espace vertical entre les objets
                          children: _mediaFileList!.map((objet) {
                            return Padding(
                              padding: const EdgeInsets.all(5.0),
                              child: Stack(
                                children: [
                                  Container(
                                    height: 100,
                                    width: 100,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.all(
                                          Radius.circular(15)),
                                      child: Image.file(
                                        File(objet.path),
                                        errorBuilder: (BuildContext
                                        context,
                                            Object error,
                                            StackTrace? stackTrace) {
                                          return const Center(
                                              child: Text('not supported'));
                                        },
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      height: 30,
                                      width: 30,
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        borderRadius: BorderRadius.only(
                                            topLeft:
                                            Radius.circular(10)),
                                      ),
                                      child: IconButton(
                                        onPressed: () {
                                          setState(() {
                                            _mediaFileList!
                                                .remove(objet!);
                                          });
                                        },
                                        icon: Icon(
                                          FontAwesome.remove,
                                          size: 15,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                        TextButton(
                            onPressed: () {
                              pickImages();
                            },
                            child: Container(
                              height: 90,
                              width: width / 3,
                              decoration: BoxDecoration(
                                color: Colors.black12,
                                borderRadius: BorderRadius.all(
                                    Radius.circular(20)),
                              ),
                              child: Column(
                                mainAxisAlignment:
                                MainAxisAlignment.center,
                                children: [
                                  Container(
                                    child: Icon(
                                      AntDesign.pluscircle,
                                      color: CustomConstants.kSecondaryColor,
                                      size: height / 25,
                                    ),
                                  ),
                                  SizedBox(
                                    height: height / 70,
                                  ),
                                  Container(
                                    child: Text(
                                      "Ajouter photos",
                                      style: TextStyle(
                                        fontSize: height / 60,
                                        color: Colors.black45,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ))
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Form(
              key: _formKey,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    TextFormField(
                      controller: nomController,
                      decoration: InputDecoration(labelText: 'Nom du magasin'),
                      validator: (value) {
                        if (value!.isEmpty) {
                          return 'Veuillez entrer lenom';
                        }
                        return null;
                      },
                      onSaved: (value) {
                      //  _titre = value!;
                      },
                    ),
                    TextFormField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        labelText: 'Mot de passe',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez saisir un mot de passe';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16.0),
                    TextFormField(
                      controller: _confirmPasswordController,
                      decoration: InputDecoration(
                        labelText: 'Confirmer le mot de passe',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez confirmer le mot de passe';
                        }
                        if (_passwordController.text != _confirmPasswordController.text) {
                          return 'Les mots de passe ne correspondent pas';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
          ]
        ),
      ),
    );
    ;
  }
}
