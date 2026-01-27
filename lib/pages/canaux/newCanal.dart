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
  final TextEditingController _priceController = TextEditingController();

  late UserAuthProvider authProvider = Provider.of<UserAuthProvider>(context, listen: false);
  late UserProvider userProvider = Provider.of<UserProvider>(context, listen: false);
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  bool onTapCreatePro = false;
  bool _isPrivate = false;

  // Couleurs personnalisées
  final Color _primaryBlack = Colors.black;
  final Color _primaryGreen = Color(0xFF2E7D32);
  final Color _primaryYellow = Color(0xFFFFD600);
  final Color _accentGreen = Color(0xFF4CAF50);
  final Color _accentYellow = Color(0xFFFFEB3B);
  final Color _backgroundColor = Color(0xFF0A0A0A);
  final Color _cardColor = Color(0xFF1A1A1A);
  final Color _textColor = Colors.white;

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
          backgroundColor: _primaryYellow,
        ),
      );
      return true;
    }
  }

  Widget _buildImageSection() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _primaryGreen.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            'Images du Canal',
            style: TextStyle(
              color: _primaryYellow,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: _primaryBlack,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: _primaryGreen),
                      ),
                      child: imageProfile != null
                          ? ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: Image.file(File(imageProfile!.path), fit: BoxFit.cover),
                      )
                          : Icon(Icons.person, color: _primaryGreen, size: 40),
                    ),
                    SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: _getImageProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryGreen,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      child: Text(
                        'Profil',
                        style: TextStyle(color: _textColor, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 20),
              Expanded(
                child: Column(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: _primaryBlack,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: _primaryYellow),
                      ),
                      child: imageCouverture != null
                          ? ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: Image.file(File(imageCouverture!.path), fit: BoxFit.cover),
                      )
                          : Icon(Icons.photo_library, color: _primaryYellow, size: 40),
                    ),
                    SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: _getImageCouverture,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryYellow,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      child: Text(
                        'Couverture',
                        style: TextStyle(color: _primaryBlack, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacySection() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _primaryYellow.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.security, color: _primaryGreen),
              SizedBox(width: 10),
              Text(
                'Type de Canal',
                style: TextStyle(
                  color: _textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: _buildPrivacyOption(
                  title: 'Public',
                  subtitle: 'Gratuit pour tous',
                  icon: Icons.public,
                  isSelected: !_isPrivate,
                  color: _primaryGreen,
                ),
              ),
              SizedBox(width: 15),
              Expanded(
                child: _buildPrivacyOption(
                  title: 'Privé',
                  subtitle: 'Abonnement payant',
                  icon: Icons.lock,
                  isSelected: _isPrivate,
                  color: _primaryYellow,
                ),
              ),
            ],
          ),
          if (_isPrivate) ...[
            SizedBox(height: 20),
            TextFormField(
              controller: _priceController,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(color: _textColor),
              decoration: InputDecoration(
                labelText: 'Prix d\'abonnement (FCFA)',
                labelStyle: TextStyle(color: _primaryYellow),
                prefixIcon: Icon(Icons.attach_money, color: _primaryYellow),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _primaryYellow),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _primaryYellow.withOpacity(0.5)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _primaryYellow),
                ),
                filled: true,
                fillColor: _primaryBlack,
              ),
              validator: _isPrivate ? (value) {
                if (value == null || value.isEmpty) {
                  return 'Veuillez entrer un prix';
                }
                final price = double.tryParse(value);
                if (price == null || price <= 0) {
                  return 'Prix invalide';
                }
                return null;
              } : null,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPrivacyOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required Color color,
  }) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isPrivate = title == 'Privé';
          if (!_isPrivate) {
            _priceController.clear();
          }
        });
      },
      child: Container(
        padding: EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: isSelected ? color : Colors.grey[700]!,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? color : Colors.grey[600], size: 30),
            SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? color : Colors.grey[600],
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: isSelected ? color : Colors.grey[600],
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormField() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _primaryGreen.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          TextFormField(
            style: TextStyle(color: _textColor),
            decoration: InputDecoration(
              labelText: 'Titre du Canal',
              labelStyle: TextStyle(color: _primaryGreen),
              prefixIcon: Icon(Icons.title, color: _primaryGreen),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _primaryGreen),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _primaryGreen.withOpacity(0.5)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _primaryGreen),
              ),
              filled: true,
              fillColor: _primaryBlack,
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
            maxLines: 4,
            style: TextStyle(color: _textColor),
            decoration: InputDecoration(
              labelText: 'Description',
              labelStyle: TextStyle(color: _primaryYellow),
              alignLabelWithHint: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _primaryYellow),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _primaryYellow.withOpacity(0.5)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _primaryYellow),
              ),
              filled: true,
              fillColor: _primaryBlack,
            ),
            validator: (value) {
              if (value!.isEmpty) {
                return 'Veuillez entrer une description';
              }
              if (value.length < 10) {
                return 'La description doit faire au moins 10 caractères';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCreateButton() {
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_primaryGreen, _primaryYellow],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: _primaryGreen.withOpacity(0.3),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(15),

          onTap: onTapCreatePro ? null : _createCanal,
          child: Center(
            child: onTapCreatePro
                ? LoadingAnimationWidget.flickr(
              size: 30,
              leftDotColor: _primaryGreen,
              rightDotColor: _primaryBlack,
            )
                : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_circle, color: _primaryBlack),
                SizedBox(width: 10),
                Text(
                  'CRÉER LE CANAL',
                  style: TextStyle(
                    color: _primaryBlack,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _createCanal() async {
    if (_formKey.currentState!.validate()) {
      if (imageProfile == null || imageCouverture == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Veuillez choisir les images de profil et de couverture',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (!await verifierCanalName(_titreController.text)) {
        try {
          setState(() {
            onTapCreatePro = true;
          });

          String id = FirebaseFirestore.instance.collection('Canaux').doc().id;
          // Création du canal avec les nouveaux champs
          Canal canal = Canal(
            titre: _titreController.text,
            type: "CANAL",
            isVerify: false,
            id: id,
            userId: authProvider.loginUserData.id!,
            description: _descriptionController.text,
            updatedAt: DateTime.now().microsecondsSinceEpoch,
            createdAt: DateTime.now().microsecondsSinceEpoch,
            usersSuiviId: [],
            isPrivate: _isPrivate,
            subscriptionPrice: _isPrivate ? double.parse(_priceController.text) : 0.0,
            subscribersId: [],
            adminIds: [authProvider.loginUserData.id!],
            allowedPostersIds: [authProvider.loginUserData.id!],
            allowAllMembersToPost: false,

          );

          // Upload image de profil
          Reference storageReferenceProfile = FirebaseStorage.instance
              .ref()
              .child('canal_media/${Path.basename(File(imageProfile!.path).path)}');
          UploadTask uploadTaskProfile = storageReferenceProfile.putFile(File(imageProfile!.path));
          await uploadTaskProfile.whenComplete(() async {
            await storageReferenceProfile.getDownloadURL().then((fileURL) {
              canal.urlImage = fileURL;
            });
          });

          // Upload image de couverture
          Reference storageReferenceCouverture = FirebaseStorage.instance
              .ref()
              .child('canal_media/${Path.basename(File(imageCouverture!.path).path)}');
          UploadTask uploadTaskCouverture = storageReferenceCouverture.putFile(File(imageCouverture!.path));
          await uploadTaskCouverture.whenComplete(() async {
            await storageReferenceCouverture.getDownloadURL().then((fileURL) {
              canal.urlCouverture = fileURL;
            });
          });

          // Sauvegarde dans Firestore
          await FirebaseFirestore.instance.collection('Canaux').doc(canal.id!).set(canal.toJson());

          // Mise à jour de l'utilisateur
          await firestore.collection('Users').doc(authProvider.loginUserData!.id).update(authProvider.loginUserData!.toJson());

          // Sauvegarde du nom du canal
          UserPseudo pseudo = UserPseudo();
          pseudo.id = firestore.collection('CanalNames').doc().id;
          pseudo.name = _titreController.text;
          await firestore.collection('CanalNames').doc(pseudo.id).set(pseudo.toJson());

          // Succès
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Canal créé avec succès ! 🎉',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              backgroundColor: _primaryGreen,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );

          // Réinitialisation du formulaire
          setState(() {
            _titreController.clear();
            _descriptionController.clear();
            _priceController.clear();
            imageProfile = null;
            imageCouverture = null;
            _isPrivate = false;
            onTapCreatePro = false;
          });

          // Retour à la page précédente après un délai
          Future.delayed(Duration(seconds: 2), () {
            Navigator.of(context).pop();
          });

        } catch (e) {
          print('Erreur création canal: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Erreur lors de la création du canal',
                style: TextStyle(color: Colors.white),
              ),
              backgroundColor: Colors.red,
            ),
          );
          setState(() {
            onTapCreatePro = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        iconTheme: IconThemeData(color: _textColor),
        title: Text(
          'Créer un Canal',
          style: TextStyle(
            color: _textColor,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: _primaryBlack,
        elevation: 0,
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Icon(Icons.group_work, color: _primaryYellow),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Section images
              _buildImageSection(),
              SizedBox(height: 20),

              // Section formulaire
              _buildFormField(),
              SizedBox(height: 20),

              // Section privé/public
              _buildPrivacySection(),
              SizedBox(height: 30),

              // Bouton de création
              _buildCreateButton(),
              SizedBox(height: 20),

              // Information
              Container(
                padding: EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: _primaryBlack,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _primaryGreen.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, color: _primaryYellow, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Les canaux privés nécessitent un abonnement payant pour accéder au contenu',
                        style: TextStyle(
                          color: _textColor.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
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

// class NewCanal extends StatefulWidget {
//   @override
//   _NewCanalState createState() => _NewCanalState();
// }
//
// class _NewCanalState extends State<NewCanal> {
//   final _formKey = GlobalKey<FormState>();
//   final TextEditingController _titreController = TextEditingController();
//   final TextEditingController _descriptionController = TextEditingController();
//   late UserAuthProvider authProvider = Provider.of<UserAuthProvider>(context, listen: false);
//   late UserProvider userProvider = Provider.of<UserProvider>(context, listen: false);
//   final FirebaseFirestore firestore = FirebaseFirestore.instance;
//   bool onTapCreatePro = false;
//
//   XFile? imageProfile;
//   XFile? imageCouverture;
//
//   final ImagePicker picker = ImagePicker();
//
//   Future<void> _getImageProfile() async {
//     final image = await picker.pickImage(source: ImageSource.gallery);
//     setState(() {
//       imageProfile = image;
//     });
//   }
//
//   Future<void> _getImageCouverture() async {
//     final image = await picker.pickImage(source: ImageSource.gallery);
//     setState(() {
//       imageCouverture = image;
//     });
//   }
//
//   Future<bool> verifierCanalName(String nom) async {
//     CollectionReference pseudos = firestore.collection("CanalNames");
//     QuerySnapshot snapshot = await pseudos.get();
//     final list = snapshot.docs.map((doc) => UserPseudo.fromJson(doc.data() as Map<String, dynamic>)).toList();
//     bool existe = list.any((e) => e.name!.toLowerCase() == nom.toLowerCase());
//
//     if (!existe) {
//       return false;
//     } else {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text("Le titre existe déjà", style: TextStyle(color: Colors.red)),
//         ),
//       );
//       return true;
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         iconTheme: IconThemeData(color: Colors.white),
//         title: Text('Créer un Canal', style: TextStyle(color: Colors.white)),
//         backgroundColor: Colors.green,
//       ),
//       body: SingleChildScrollView(
//         child: Padding(
//           padding: EdgeInsets.all(16.0),
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             crossAxisAlignment: CrossAxisAlignment.center,
//             children: [
//               Center(
//                 child: Column(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     CircleAvatar(
//                       radius: 50,
//                       backgroundImage: imageProfile != null ? FileImage(File(imageProfile!.path)) : null,
//                       child: imageProfile == null ? const Icon(Icons.person) : null,
//                     ),
//                     const SizedBox(height: 20),
//                     ElevatedButton(
//                       onPressed: _getImageProfile,
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: Colors.green, // Background color
//                         // onPrimary: Colors.white, // Text color
//                       ),
//                       child: const Text('Modifier l\'image de profil',style: TextStyle(color: Colors.white),),
//                     ),
//                     const SizedBox(height: 20),
//                     imageCouverture != null
//                         ? Image.file(File(imageCouverture!.path))
//                         : Container(
//                       height: 150,
//                       width: double.infinity,
//                       color: Colors.grey[300],
//                       child: const Icon(Icons.image),
//                     ),
//                     const SizedBox(height: 20),
//                     ElevatedButton(
//                       onPressed: _getImageCouverture,
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: Colors.green, // Background color
//                         // onPrimary: Colors.white, // Text color
//                       ),
//                       child: const Text('Modifier l\'image de couverture',style: TextStyle(color: Colors.white),),
//                     ),
//                   ],
//                 ),
//               ),
//               Form(
//                 key: _formKey,
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.stretch,
//                   children: [
//                     TextFormField(
//                       decoration: InputDecoration(
//                         labelText: 'Titre',
//                         labelStyle: TextStyle(color: Colors.green),
//                       ),
//                       validator: (value) {
//                         if (value!.isEmpty) {
//                           return 'Veuillez entrer un titre';
//                         }
//                         return null;
//                       },
//                       controller: _titreController,
//                     ),
//                     SizedBox(height: 20),
//                     TextFormField(
//                       controller: _descriptionController,
//                       decoration: InputDecoration(
//                         labelText: 'Description',
//                         labelStyle: TextStyle(color: Colors.green),
//                       ),
//                       validator: (value) {
//                         if (value!.isEmpty) {
//                           return 'Veuillez entrer une description';
//                         }
//                         return null;
//                       },
//                     ),
//                     SizedBox(height: 50),
//                     ElevatedButton(
//                       onPressed: onTapCreatePro ? null : () async {
//                         if (_formKey.currentState!.validate()) {
//                           if (!await verifierCanalName(_titreController.text)) {
//                             try {
//                               if (imageProfile != null && imageCouverture != null) {
//                                 setState(() {
//                                   onTapCreatePro = true;
//                                 });
//                                 String id = FirebaseFirestore.instance.collection('Canaux').doc().id;
//
//                                 Canal canal = Canal();
//                                 canal.titre = _titreController.text;
//                                 canal.type = "CANAL";
//                                 canal.isVerify = false;
//                                 canal.id = id;
//                                 canal.userId = authProvider.loginUserData.id!;
//                                 canal.description = _descriptionController.text;
//                                 canal.updatedAt =
//                                     DateTime.now().microsecondsSinceEpoch;
//                                 canal.createdAt =
//                                     DateTime.now().microsecondsSinceEpoch;
//                                 canal.usersSuiviId = [];
//
//                                 Reference storageReferenceProfile = FirebaseStorage.instance
//                                     .ref()
//                                     .child('canal_media/${Path.basename(File(imageProfile!.path).path)}');
//                                 UploadTask uploadTaskProfile = storageReferenceProfile.putFile(File(imageProfile!.path));
//                                 await uploadTaskProfile.whenComplete(() async {
//                                   await storageReferenceProfile.getDownloadURL().then((fileURL) {
//                                     canal.urlImage = fileURL;
//                                   });
//                                 });
//
//                                 Reference storageReferenceCouverture = FirebaseStorage.instance
//                                     .ref()
//                                     .child('canal_media/${Path.basename(File(imageCouverture!.path).path)}');
//                                 UploadTask uploadTaskCouverture = storageReferenceCouverture.putFile(File(imageCouverture!.path));
//                                 await uploadTaskCouverture.whenComplete(() async {
//                                   await storageReferenceCouverture.getDownloadURL().then((fileURL) {
//                                     canal.urlCouverture = fileURL;
//                                   });
//                                 });
//
//                                 await FirebaseFirestore.instance.collection('Canaux').doc(canal.id!).set(canal.toJson());
//                                 await firestore.collection('Users').doc(authProvider.loginUserData!.id).update(authProvider.loginUserData!.toJson());
//
//                                 ScaffoldMessenger.of(context).showSnackBar(
//                                   SnackBar(
//                                     content: Text(
//                                       'Le Canal a été validé avec succès !',
//                                       textAlign: TextAlign.center,
//                                       style: TextStyle(color: Colors.green),
//                                     ),
//                                   ),
//                                 );
//
//                                 UserPseudo pseudo = UserPseudo();
//                                 pseudo.id = firestore.collection('CanalNames').doc().id;
//                                 pseudo.name = _titreController.text;
//                                 await firestore.collection('CanalNames').doc(pseudo.id).set(pseudo.toJson());
//
//                                 setState(() {
//                                   _titreController.text = '';
//                                   _descriptionController.text = '';
//                                   imageProfile = null;
//                                   imageCouverture = null;
//                                 });
//                               }
//                             } catch (e) {
//                               ScaffoldMessenger.of(context).showSnackBar(
//                                 SnackBar(
//                                   content: Text(
//                                     'Erreur de création.',
//                                     textAlign: TextAlign.center,
//                                     style: TextStyle(color: Colors.red),
//                                   ),
//                                 ),
//                               );
//                               setState(() {
//                                 onTapCreatePro = false;
//                               });
//                             }
//                           }
//                         } else {
//                           ScaffoldMessenger.of(context).showSnackBar(
//                             SnackBar(
//                               content: Text(
//                                 'Veuillez choisir une image.',
//                                 textAlign: TextAlign.center,
//                                 style: TextStyle(color: Colors.red),
//                               ),
//                             ),
//                           );
//                         }
//                         setState(() {
//                           onTapCreatePro = false;
//                         });
//                       },
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: Colors.green, // Background color
//                         // onPrimary: Colors.white, // Text color
//                       ),
//                       child: onTapCreatePro
//                           ? Center(
//                         child: LoadingAnimationWidget.flickr(
//                           size: 20,
//                           leftDotColor: Colors.green,
//                           rightDotColor: Colors.black,
//                         ),
//                       )
//                           : Text('Créer votre canal',style: TextStyle(color: Colors.white),),
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }