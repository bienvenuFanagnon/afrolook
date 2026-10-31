import 'package:afrotok/services/read_meter.dart';
import '../../../services/media_shrink.dart';
import 'dart:io';
import 'package:afrotok/pages/component/consoleWidget.dart';

import 'package:afrotok/models/model_data.dart';
import '../../../services/api/shop_api.dart';


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
    // Le nom d'entreprise est unique : l'API refuse aussi un nom déjà pris à la création (message en français).
    bool existe = false;
    try {
      final all = await ShopApi.businesses(search: nom);
      existe = all.any((e) => (e.titre ?? '').toLowerCase() == nom.toLowerCase());
    } catch (_) {}
    if (existe) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Le nom existe déjà", style: TextStyle(color: Colors.red)),
        ),
      );
    }
    return existe;
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
                                // Entreprise créée par l'API (image envoyée en direct, abonnement gratuit géré par le serveur)
                                final created = await ShopApi.createBusiness(
                                  name: _titreController.text,
                                  type: TypeEntreprise.personnel.name,
                                  description: _descriptionController.text,
                                  image: File(imageProfile!.path),
                                );
                                printVm('entreprise créée : ${created.id}');
                                authProvider.loginUserData.hasEntreprise = true;

                                SnackBar snackBar = SnackBar(
                                  content: Text(
                                    'Le Profile entreprise a été validé avec succès !',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.green),
                                  ),
                                );
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(snackBar);

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
                              printVm("erreur : ${e}");
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
