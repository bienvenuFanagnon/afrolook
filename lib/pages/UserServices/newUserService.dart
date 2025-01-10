import 'dart:io';

import 'package:afrotok/pages/userPosts/hashtag/textHashTag/views/widgets/loading_indicator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; // Pour sélectionner une image depuis la galerie
import 'package:path/path.dart' as Path;
import 'package:phone_form_field/phone_form_field.dart';
import 'package:provider/provider.dart';

import '../../models/model_data.dart';
import '../../providers/authProvider.dart';

class UserServiceForm extends StatefulWidget {
  @override
  _UserServiceFormState createState() => _UserServiceFormState();
}

class _UserServiceFormState extends State<UserServiceForm> {
  final _formKey = GlobalKey<FormState>();
  final _userService = UserServiceData();
  final _firestore = FirebaseFirestore.instance;
  XFile? _coverImage;
  late UserAuthProvider authProvider =
  Provider.of<UserAuthProvider>(context, listen: false);
  bool onTap=false;

  Future<void> _pickImage() async {
    final ImagePicker _picker = ImagePicker();
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    setState(() {
      _coverImage = image;
    });
  }

  @override
  Widget build(BuildContext context) {
    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;
    return Scaffold(
      appBar: AppBar(
        title: Text('Enregistrer un Service', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.green,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text('Image de couverture et non votre photo de profil', style: TextStyle(color: Colors.black87)),
                ),
                GestureDetector(
                  onTap: _pickImage,
                  child: _coverImage == null
                      ? Container(
                    height: 200,
                    color: Colors.grey[300],
                    child: Icon(Icons.add_a_photo, color: Colors.grey[800]),
                  )
                      : Image.file(File(_coverImage!.path),   height: height*0.25,
                      width: width*0.8, fit: BoxFit.cover),
                ),
                SizedBox(height: 16),
            /// params
            PhoneFormField(
              decoration: InputDecoration(helperText: 'Numero WhatsApp',labelText: 'Numero WhatsApp'),

              initialValue: PhoneNumber.parse('+228'), // or use the controller
              validator: PhoneValidator.compose(
                  [PhoneValidator.required(context), PhoneValidator.validMobile(context)]),
              countrySelectorNavigator: const CountrySelectorNavigator.page(),
              onChanged: (phoneNumber) {

                _userService.contact=phoneNumber.international;
                },
              onSaved: (newValue) {

                _userService.contact=newValue!.international;

              },

              enabled: true,
              isCountrySelectionEnabled: true,
              isCountryButtonPersistent: true,
              countryButtonStyle: const CountryButtonStyle(
                  showDialCode: true,
                  showIsoCode: true,
                  showFlag: true,
                  flagSize: 16
              ),

              // + all parameters of TextField
              // + all parameters of FormField
              // ...
            ),
                TextFormField(
                  decoration: InputDecoration(labelText: 'Titre'),
                  onSaved: (value) {
                    _userService.titre = value;
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Veuillez entrer un titre';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  decoration: InputDecoration(labelText: 'Description'),
                  onSaved: (value) {
                    _userService.description = value;
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Veuillez entrer une description';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: <Widget>[
                    Column(
                      children: <Widget>[
                        Icon(Icons.visibility),
                        Text('Vues'),
                      ],
                    ),
                    Column(
                      children: <Widget>[
                        Icon(Icons.thumb_up),
                        Text('Likes'),
                      ],
                    ),
                    Column(
                      children: <Widget>[
                        Icon(Icons.share),
                        Text('Partages'),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed:onTap?(){}: () async {
                    if (_formKey.currentState!.validate()) {
                      _formKey.currentState!.save();
                      setState(() {
                        onTap=true;
                      });
                      try {
                        _userService.createdAt = DateTime.now().millisecondsSinceEpoch;
                        _userService.updatedAt = DateTime.now().millisecondsSinceEpoch;
                        _userService.userId = authProvider.loginUserData.id;
                        _userService.disponible = true;
                        if(_coverImage!=null){
                          Reference storageReference =
                          FirebaseStorage.instance.ref().child(
                              'service_media/${Path.basename(File(_coverImage!.path).path)}');

                          UploadTask uploadTask = storageReference
                              .putFile(File(_coverImage!.path)!);
                          await uploadTask.whenComplete(() async {
                            await storageReference
                                .getDownloadURL()
                                .then((fileURL) {
                              print("url media");
                              print(fileURL);

                              _userService.imageCourverture= fileURL;
                            });
                          });
                          setState(() {
                            _formKey.currentState!.reset();
                            _coverImage=null;
                          });
                          String id = FirebaseFirestore.instance
                              .collection('UserServices')
                              .doc()
                              .id;
                          _userService.id=id;
                          await _firestore.collection('UserServices').doc( _userService.id).set( _userService.toJson());

                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Service enregistré avec succès'),backgroundColor: Colors.green,));
                          setState(() {
                            onTap=false;
                          });
                        }else{
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Veillez choisir une image de couverture'),backgroundColor: Colors.red));

                        }

                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur lors de l\'enregistrement du service'),backgroundColor: Colors.red));
                        setState(() {
                          onTap=false;
                        });
                      }
                    }
                  },
                  child:onTap?Center(child: SizedBox(height: 20,width: 20, child: CircularProgressIndicator())): Text('Enregistrer', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
