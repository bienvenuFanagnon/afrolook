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


class NewEntreprise extends StatefulWidget {
  @override
  _NewEntrepriseState createState() => _NewEntrepriseState();
}

class _NewEntrepriseState extends State<NewEntreprise> {
  final _formKey = GlobalKey<FormState>();


  final TextEditingController _titreController = TextEditingController();

  final TextEditingController _descriptionController = TextEditingController();
  late UserAuthProvider authProvider =
  Provider.of<UserAuthProvider>(context, listen: false);

  late UserProvider userProvider =
  Provider.of<UserProvider>(context, listen: false);
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  bool onTapCreatePro = false;

   XFile? imageProfile;

  final ImagePicker picker = ImagePicker();

  Future<void> _getImages() async {
    await picker.pickImage(source: ImageSource.gallery).then((image) {
      // Mettre à jour la liste des images
      setState(() {
        imageProfile = image!;
      });
    });
  }

  Future<bool> verifierEntrepriseName(String nom) async {


    // Récupérer la liste des utilisateurs
    CollectionReference pseudos = firestore.collection("EntrepriseNames");
    QuerySnapshot snapshot = await pseudos.get();
    final list = snapshot.docs.map((doc) =>
        UserPseudo.fromJson(doc.data() as Map<String, dynamic>)).toList();
    bool existe= list.any((e) => e.name!.toLowerCase()==nom.toLowerCase());
    // Vérifier si le nom existe déjà
    //  bool existe = snapshot.docs.any((doc) => doc.data["nom"] == nom);

    if (existe==false) {

      try{

        //
        // UserPseudo pseudo=UserPseudo();
        // pseudo.id=firestore
        //     .collection('EntrepriseNames')
        //     .doc()
        //     .id;
        // pseudo.name=nom;
        //
        // // users.add(pseudo.toJson());
        //
        // await firestore.collection('EntrepriseNames').doc(pseudo.id).set(pseudo.toJson());
        // print("///////////-- save pseudo --///////////////");
        return false;
      } on FirebaseException catch(error){
        return true;
      }
      // Le nom n'existe pas, créer un nouveau document


    } else {
      // Le nom existe déjà, afficher un message d'erreur
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Le nom existe déjà",style: TextStyle(color: Colors.red),),
        ),
      );
      return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Créer un profil entreprise'),
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
                      backgroundImage: imageProfile != null ? FileImage(File(imageProfile!.path)!) : null,
                      child: imageProfile == null
                          ? const Icon(Icons.person)
                          : null,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _getImages,
                      child: const Text('Modifier l\'image'),
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
                      decoration: InputDecoration(labelText: 'Titre'),
                      validator: (value) {
                        if (value!.isEmpty) {
                          return 'Veuillez entrer un titre';
                        }
                        return null;
                      },
                      onSaved: (value) {
                      },
                      controller: _titreController,
                    ),
                    SizedBox(height: 20,),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: InputDecoration(labelText: 'Description'),
                      validator: (value) {
                        if (value!.isEmpty) {
                          return 'Veuillez entrer une description';
                        }
                        return null;
                      },
                      onSaved: (value) {
                       // _description = value!;
                      },
                    ),
                    SizedBox(height: 50,),
                    ElevatedButton(
                      onPressed:onTapCreatePro?(){}: () async {
                        if (_formKey.currentState!.validate()) {
                         // _formKey.currentState!.save();
                          if (!await verifierEntrepriseName(_titreController.text)) {
                            try{
                              if (imageProfile!=null) {
                                setState(() {
                                  onTapCreatePro=true;
                                });
                                String id = FirebaseFirestore.instance
                                    .collection('Entreprises')
                                    .doc()
                                    .id;


                                EntrepriseAbonnement abonnement = EntrepriseAbonnement()
                                  ..type = TypeAbonement.GRATUIT.name
                                  ..id = "idabn"
                                  ..entrepriseId = id
                                  ..description = "Abonnement gratuit pour entreprise"
                                  ..nombre_pub = 3
                                  ..nombre_image_pub = 1
                                  ..nbr_jour_pub_afrolook = 0
                                  ..nbr_jour_pub_annonce_afrolook = 0
                                  ..userId = authProvider.loginUserData.id
                                  ..afroshop_user_magasin_id = "magasin456"
                                  ..createdAt = DateTime.now().millisecondsSinceEpoch
                                  ..updatedAt = DateTime.now().millisecondsSinceEpoch
                                  ..star = DateTime.now().millisecondsSinceEpoch
                                  ..end = DateTime.now().add(Duration(days: 365)).millisecondsSinceEpoch
                                  ..isFinished = false
                                  ..dispo_afrolook = false;



                                EntrepriseData entreprise=EntrepriseData();
                                entreprise.titre=_titreController.text;
                                entreprise.type=TypeEntreprise.personnel.name;

                                entreprise.id=id;
                                entreprise.userId=authProvider.loginUserData.id!;
                                entreprise.description=_descriptionController.text;
                                entreprise.abonnements=[];
                                entreprise.usersSuiviId=[];
                                entreprise.produitsIds=[];
                                // entreprise.abonnements!.add(abonnement);

                                entreprise.abonnement=abonnement;


                                Reference storageReference =
                                FirebaseStorage.instance.ref().child(
                                    'post_media/${Path.basename(File(imageProfile!.path).path)}');

                                UploadTask uploadTask = storageReference
                                    .putFile(File(imageProfile!.path)!);
                                await uploadTask.whenComplete(() async {
                                  await storageReference
                                      .getDownloadURL()
                                      .then((fileURL) {
                                    print("url media");
                                     print(fileURL);

                                    entreprise.urlImage= fileURL;
                                  });
                                });
                                print(entreprise.toJson());

                                await FirebaseFirestore.instance
                                    .collection('Entreprises')
                                    .doc(entreprise.id!)
                                    .set(entreprise.toJson());
                                authProvider.loginUserData.hasEntreprise=true;
                                await firestore.collection('Users').doc( authProvider.loginUserData!.id).update( authProvider.loginUserData!.toJson());

                                SnackBar snackBar = SnackBar(
                                  content: Text(
                                    'Le Profile entreprise a été validé avec succès !',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.green),
                                  ),
                                );
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(snackBar);


                                UserPseudo pseudo=UserPseudo();
                                pseudo.id=firestore
                                    .collection('EntrepriseNames')
                                    .doc()
                                    .id;
                                pseudo.name=   _titreController.text;

                                // users.add(pseudo.toJson());

                                await firestore.collection('EntrepriseNames').doc(pseudo.id).set(pseudo.toJson());
                                print("///////////-- save pseudo --///////////////");
                               // Navigator.pop(context);
                                setState(() {
                                  _titreController.text='';
                                  _descriptionController.text='';
                                  imageProfile=null;
                                });
                              }
                            }catch(e){
                              SnackBar snackBar = SnackBar(
                                content: Text(
                                  'Erreur de création.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.red),
                                ),
                              );
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(snackBar);
                              print("erreur : ${e}");
                              setState(() {
                                onTapCreatePro=false;
                              });
                            }
                          }

        
                          } else{
                            SnackBar snackBar = SnackBar(
                              content: Text(
                                'Veuillez choisir une image.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.red),
                              ),
                            );
                            ScaffoldMessenger.of(context)
                                .showSnackBar(snackBar);
                          }
                        setState(() {
                          onTapCreatePro=false;
                        });
        
                      },
                      child:onTapCreatePro?Center(
                        child: LoadingAnimationWidget.flickr(
                          size: 20,
                          leftDotColor: Colors.green,
                          rightDotColor: Colors.black,
                        ),
                      ): Text('Créer votre entreprise'),
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
