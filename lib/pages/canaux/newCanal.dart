import 'dart:io';
import 'package:afrotok/models/model_data.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as Path;
import '../../../providers/authProvider.dart';
import '../../../providers/userProvider.dart';

class NewCanal extends StatefulWidget {
  @override
  _NewCanalState createState() => _NewCanalState();
}

class _NewCanalState extends State<NewCanal> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titreController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  late UserAuthProvider authProvider = Provider.of<UserAuthProvider>(context, listen: false);
  late UserProvider userProvider = Provider.of<UserProvider>(context, listen: false);
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  bool onTapCreatePro = false;

  XFile? imageProfile;
  XFile? imageCouverture;

  final ImagePicker picker = ImagePicker();

  Future<void> _getImageProfile() async {
    final image = await picker.pickImage(source: ImageSource.gallery);
    setState(() {
      imageProfile = image;
    });
  }

  Future<void> _getImageCouverture() async {
    final image = await picker.pickImage(source: ImageSource.gallery);
    setState(() {
      imageCouverture = image;
    });
  }

  Future<bool> verifierCanalName(String nom) async {
    CollectionReference pseudos = firestore.collection("CanalNames");
    QuerySnapshot snapshot = await pseudos.get();
    final list = snapshot.docs.map((doc) => UserPseudo.fromJson(doc.data() as Map<String, dynamic>)).toList();
    bool existe = list.any((e) => e.name!.toLowerCase() == nom.toLowerCase());

    if (!existe) {
      return false;
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Le titre existe déjà", style: TextStyle(color: Colors.red)),
        ),
      );
      return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: IconThemeData(color: Colors.white),
        title: Text('Créer un Canal', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.green,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundImage: imageProfile != null ? FileImage(File(imageProfile!.path)) : null,
                      child: imageProfile == null ? const Icon(Icons.person) : null,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _getImageProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green, // Background color
                        // onPrimary: Colors.white, // Text color
                      ),
                      child: const Text('Modifier l\'image de profil',style: TextStyle(color: Colors.white),),
                    ),
                    const SizedBox(height: 20),
                    imageCouverture != null
                        ? Image.file(File(imageCouverture!.path))
                        : Container(
                      height: 150,
                      width: double.infinity,
                      color: Colors.grey[300],
                      child: const Icon(Icons.image),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _getImageCouverture,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green, // Background color
                        // onPrimary: Colors.white, // Text color
                      ),
                      child: const Text('Modifier l\'image de couverture',style: TextStyle(color: Colors.white),),
                    ),
                  ],
                ),
              ),
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Titre',
                        labelStyle: TextStyle(color: Colors.green),
                      ),
                      validator: (value) {
                        if (value!.isEmpty) {
                          return 'Veuillez entrer un titre';
                        }
                        return null;
                      },
                      controller: _titreController,
                    ),
                    SizedBox(height: 20),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: InputDecoration(
                        labelText: 'Description',
                        labelStyle: TextStyle(color: Colors.green),
                      ),
                      validator: (value) {
                        if (value!.isEmpty) {
                          return 'Veuillez entrer une description';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 50),
                    ElevatedButton(
                      onPressed: onTapCreatePro ? null : () async {
                        if (_formKey.currentState!.validate()) {
                          if (!await verifierCanalName(_titreController.text)) {
                            try {
                              if (imageProfile != null && imageCouverture != null) {
                                setState(() {
                                  onTapCreatePro = true;
                                });
                                String id = FirebaseFirestore.instance.collection('Canaux').doc().id;

                                Canal canal = Canal();
                                canal.titre = _titreController.text;
                                canal.type = "CANAL";
                                canal.isVerify = false;
                                canal.id = id;
                                canal.userId = authProvider.loginUserData.id!;
                                canal.description = _descriptionController.text;
                                canal.updatedAt =
                                    DateTime.now().microsecondsSinceEpoch;
                                canal.createdAt =
                                    DateTime.now().microsecondsSinceEpoch;
                                canal.usersSuiviId = [];

                                Reference storageReferenceProfile = FirebaseStorage.instance
                                    .ref()
                                    .child('canal_media/${Path.basename(File(imageProfile!.path).path)}');
                                UploadTask uploadTaskProfile = storageReferenceProfile.putFile(File(imageProfile!.path));
                                await uploadTaskProfile.whenComplete(() async {
                                  await storageReferenceProfile.getDownloadURL().then((fileURL) {
                                    canal.urlImage = fileURL;
                                  });
                                });

                                Reference storageReferenceCouverture = FirebaseStorage.instance
                                    .ref()
                                    .child('canal_media/${Path.basename(File(imageCouverture!.path).path)}');
                                UploadTask uploadTaskCouverture = storageReferenceCouverture.putFile(File(imageCouverture!.path));
                                await uploadTaskCouverture.whenComplete(() async {
                                  await storageReferenceCouverture.getDownloadURL().then((fileURL) {
                                    canal.urlCouverture = fileURL;
                                  });
                                });

                                await FirebaseFirestore.instance.collection('Canaux').doc(canal.id!).set(canal.toJson());
                                await firestore.collection('Users').doc(authProvider.loginUserData!.id).update(authProvider.loginUserData!.toJson());

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Le Canal a été validé avec succès !',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: Colors.green),
                                    ),
                                  ),
                                );

                                UserPseudo pseudo = UserPseudo();
                                pseudo.id = firestore.collection('CanalNames').doc().id;
                                pseudo.name = _titreController.text;
                                await firestore.collection('CanalNames').doc(pseudo.id).set(pseudo.toJson());

                                setState(() {
                                  _titreController.text = '';
                                  _descriptionController.text = '';
                                  imageProfile = null;
                                  imageCouverture = null;
                                });
                              }
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Erreur de création.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              );
                              setState(() {
                                onTapCreatePro = false;
                              });
                            }
                          }
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Veuillez choisir une image.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          );
                        }
                        setState(() {
                          onTapCreatePro = false;
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green, // Background color
                        // onPrimary: Colors.white, // Text color
                      ),
                      child: onTapCreatePro
                          ? Center(
                        child: LoadingAnimationWidget.flickr(
                          size: 20,
                          leftDotColor: Colors.green,
                          rightDotColor: Colors.black,
                        ),
                      )
                          : Text('Créer votre canal',style: TextStyle(color: Colors.white),),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}