import 'dart:io';
import 'package:afrotok/models/model_data.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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

class EditCanal extends StatefulWidget {
  final Canal canal;

  EditCanal({required this.canal});

  @override
  _EditCanalState createState() => _EditCanalState();
}

class _EditCanalState extends State<EditCanal> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titreController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();

  late UserAuthProvider authProvider = Provider.of<UserAuthProvider>(context, listen: false);
  late UserProvider userProvider = Provider.of<UserProvider>(context, listen: false);
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  bool onTapUpdate = false;

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
  bool _isPrivate = false;

  final ImagePicker picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _titreController.text = widget.canal.titre!;
    _descriptionController.text = widget.canal.description!;
    _isPrivate = widget.canal.isPrivate ?? false;
    if (_isPrivate) {
      _priceController.text = widget.canal.subscriptionPrice?.toString() ?? '0';
    }
  }

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
                    Stack(
                      children: [
                        Container(
                          width: 120,
                          height: 120,
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
                              : widget.canal.urlImage != null
                              ? ClipRRect(
                            borderRadius: BorderRadius.circular(15),
                            child: Image.network(widget.canal.urlImage!, fit: BoxFit.cover),
                          )
                              : Icon(Icons.person, color: _primaryGreen, size: 40),
                        ),
                        Positioned(
                          bottom: 5,
                          right: 5,
                          child: Container(
                            padding: EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: _primaryGreen,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.edit, color: _textColor, size: 12),
                          ),
                        ),
                      ],
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
                        'Modifier Profil',
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
                    Stack(
                      children: [
                        Container(
                          width: 120,
                          height: 120,
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
                              : widget.canal.urlCouverture != null
                              ? ClipRRect(
                            borderRadius: BorderRadius.circular(15),
                            child: Image.network(widget.canal.urlCouverture!, fit: BoxFit.cover),
                          )
                              : Icon(Icons.photo_library, color: _primaryYellow, size: 40),
                        ),
                        Positioned(
                          bottom: 5,
                          right: 5,
                          child: Container(
                            padding: EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: _primaryYellow,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.edit, color: _primaryBlack, size: 12),
                          ),
                        ),
                      ],
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
                        'Modifier Couverture',
                        style: TextStyle(color: _primaryBlack, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          Text(
            'Cliquez sur les images pour les modifier',
            style: TextStyle(
              color: _textColor.withOpacity(0.6),
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
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
          SizedBox(height: 10),
          _buildSubscribersInfo(),
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

  Widget _buildSubscribersInfo() {
    final subscribersCount = widget.canal.subscribersId?.length ?? 0;
    if (_isPrivate && subscribersCount > 0) {
      return Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _primaryYellow.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _primaryYellow.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.people, color: _primaryYellow, size: 16),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                '$subscribersCount abonné(s) actuel(s) seront affectés par ce changement',
                style: TextStyle(
                  color: _primaryYellow,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return SizedBox();
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

  Widget _buildStatsSection() {
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
            'Statistiques du Canal',
            style: TextStyle(
              color: _primaryYellow,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                icon: Icons.people,
                value: '${widget.canal.usersSuiviId?.length ?? 0}',
                label: 'Abonnés',
                color: _primaryGreen,
              ),
              _buildStatItem(
                icon: Icons.post_add,
                value: '${widget.canal.publication ?? 0}',
                label: 'Publications',
                color: _primaryYellow,
              ),
              // _buildStatItem(
              //   icon: Icons.visibility,
              //   value: '${widget.canal.suivi ?? 0}',
              //   label: 'Vues',
              //   color: _accentGreen,
              // ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        SizedBox(height: 5),
        Text(
          value,
          style: TextStyle(
            color: _textColor,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: _textColor.withOpacity(0.7),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildUpdateButton() {
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
          onTap: onTapUpdate ? null : _updateCanal,
          child: Center(
            child: onTapUpdate
                ? LoadingAnimationWidget.flickr(
              size: 30,
              leftDotColor: _primaryGreen,
              rightDotColor: _primaryBlack,
            )
                : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.update, color: _primaryBlack),
                SizedBox(width: 10),
                Text(
                  'METTRE À JOUR',
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

  Future<void> _updateCanal() async {
    if (_formKey.currentState!.validate()) {
      try {
        setState(() {
          onTapUpdate = true;
        });

        // Upload nouvelle image de profil si modifiée
        if (imageProfile != null) {
          Reference storageReferenceProfile = FirebaseStorage.instance
              .ref()
              .child('canal_media/${Path.basename(File(imageProfile!.path).path)}');
          UploadTask uploadTaskProfile = storageReferenceProfile.putFile(File(imageProfile!.path));
          await uploadTaskProfile.whenComplete(() async {
            await storageReferenceProfile.getDownloadURL().then((fileURL) {
              widget.canal.urlImage = fileURL;
            });
          });
        }

        // Upload nouvelle image de couverture si modifiée
        if (imageCouverture != null) {
          Reference storageReferenceCouverture = FirebaseStorage.instance
              .ref()
              .child('canal_media/${Path.basename(File(imageCouverture!.path).path)}');
          UploadTask uploadTaskCouverture = storageReferenceCouverture.putFile(File(imageCouverture!.path));
          await uploadTaskCouverture.whenComplete(() async {
            await storageReferenceCouverture.getDownloadURL().then((fileURL) {
              widget.canal.urlCouverture = fileURL;
            });
          });
        }

        // Mise à jour des informations du canal
        widget.canal.titre = _titreController.text;
        widget.canal.description = _descriptionController.text;
        widget.canal.isPrivate = _isPrivate;
        widget.canal.subscriptionPrice = _isPrivate ? double.parse(_priceController.text) : 0.0;
        widget.canal.updatedAt = DateTime.now().microsecondsSinceEpoch;

        // Si le canal devient public, on garde les abonnés existants mais sans frais
        if (!_isPrivate) {
          // On conserve les abonnés existants, mais le canal devient gratuit
          // Les abonnés actuels gardent l'accès gratuitement
        }

        // Sauvegarde dans Firestore
        await FirebaseFirestore.instance.collection('Canaux').doc(widget.canal.id).update(widget.canal.toJson());

        // Succès
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Canal mis à jour avec succès ! ✅',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            backgroundColor: _primaryGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );

        // Retour à la page précédente après un délai
        Future.delayed(Duration(seconds: 2), () {
          Navigator.of(context).pop();
        });

      } catch (e) {
        print('Erreur mise à jour canal: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Erreur lors de la mise à jour du canal',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        setState(() {
          onTapUpdate = false;
        });
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
          'Modifier le Canal',
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
            child: Icon(Icons.edit, color: _primaryYellow),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Section statistiques
              _buildStatsSection(),
              SizedBox(height: 20),

              // Section images
              _buildImageSection(),
              SizedBox(height: 20),

              // Section formulaire
              _buildFormField(),
              SizedBox(height: 20),

              // Section privé/public
              _buildPrivacySection(),
              SizedBox(height: 30),

              // Bouton de mise à jour
              _buildUpdateButton(),
              SizedBox(height: 20),

              // Information importante
              Container(
                padding: EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: _primaryBlack,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _primaryYellow.withOpacity(0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info, color: _primaryYellow, size: 20),
                        SizedBox(width: 10),
                        Text(
                          'Information importante',
                          style: TextStyle(
                            color: _primaryYellow,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Si vous rendez un canal privé public, tous les abonnés actuels garderont l\'accès gratuitement. '
                          'Si vous rendez un canal public privé, les nouveaux membres devront payer l\'abonnement.',
                      style: TextStyle(
                        color: _textColor.withOpacity(0.7),
                        fontSize: 12,
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

// class EditCanal extends StatefulWidget {
//   final Canal canal;
//
//   EditCanal({required this.canal});
//
//   @override
//   _EditCanalState createState() => _EditCanalState();
// }
//
// class _EditCanalState extends State<EditCanal> {
//   final _formKey = GlobalKey<FormState>();
//   final TextEditingController _titreController = TextEditingController();
//   final TextEditingController _descriptionController = TextEditingController();
//   late UserAuthProvider authProvider = Provider.of<UserAuthProvider>(context, listen: false);
//   late UserProvider userProvider = Provider.of<UserProvider>(context, listen: false);
//   final FirebaseFirestore firestore = FirebaseFirestore.instance;
//
//   XFile? imageProfile;
//   XFile? imageCouverture;
//
//   final ImagePicker picker = ImagePicker();
//
//   @override
//   void initState() {
//     super.initState();
//     _titreController.text = widget.canal.titre!;
//     _descriptionController.text = widget.canal.description!;
//   }
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
//   Future<void> _updateCanal() async {
//     if (_formKey.currentState!.validate()) {
//       try {
//         if (imageProfile != null) {
//           Reference storageReferenceProfile = FirebaseStorage.instance
//               .ref()
//               .child('canal_media/${Path.basename(File(imageProfile!.path).path)}');
//           UploadTask uploadTaskProfile = storageReferenceProfile.putFile(File(imageProfile!.path));
//           await uploadTaskProfile.whenComplete(() async {
//             await storageReferenceProfile.getDownloadURL().then((fileURL) {
//               widget.canal.urlImage = fileURL;
//             });
//           });
//         }
//
//         if (imageCouverture != null) {
//           Reference storageReferenceCouverture = FirebaseStorage.instance
//               .ref()
//               .child('canal_media/${Path.basename(File(imageCouverture!.path).path)}');
//           UploadTask uploadTaskCouverture = storageReferenceCouverture.putFile(File(imageCouverture!.path));
//           await uploadTaskCouverture.whenComplete(() async {
//             await storageReferenceCouverture.getDownloadURL().then((fileURL) {
//               widget.canal.urlCouverture = fileURL;
//             });
//           });
//         }
//
//         widget.canal.titre = _titreController.text;
//         widget.canal.description = _descriptionController.text;
//
//         await FirebaseFirestore.instance.collection('Canaux').doc(widget.canal.id).update(widget.canal.toJson());
//
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text(
//               'Le Canal a été mis à jour avec succès !',
//               textAlign: TextAlign.center,
//               style: TextStyle(color: Colors.green),
//             ),
//           ),
//         );
//       } catch (e) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text(
//               'Erreur de mise à jour.',
//               textAlign: TextAlign.center,
//               style: TextStyle(color: Colors.red),
//             ),
//           ),
//         );
//       }
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Détails du Canal'),
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
//                       backgroundImage: imageProfile != null
//                           ? FileImage(File(imageProfile!.path)) as ImageProvider<Object>
//                           : widget.canal.urlImage != null
//                           ? NetworkImage(widget.canal.urlImage!) as ImageProvider<Object>
//                           : null,
//                       child: imageProfile == null && widget.canal.urlImage == null
//                           ? const Icon(Icons.person)
//                           : null,
//                     ),
//                     const SizedBox(height: 20),
//                     ElevatedButton(
//                       onPressed: _getImageProfile,
//                       child: const Text('Modifier l\'image de profil'),
//                     ),
//                     const SizedBox(height: 20),
//                     imageCouverture != null
//                         ? Image.file(File(imageCouverture!.path))
//                         : widget.canal.urlCouverture != null
//                         ? Image.network(widget.canal.urlCouverture!)
//                         : Container(
//                       height: 150,
//                       width: double.infinity,
//                       color: Colors.grey[300],
//                       child: const Icon(Icons.image),
//                     ),
//                     const SizedBox(height: 20),
//                     ElevatedButton(
//                       onPressed: _getImageCouverture,
//                       child: const Text('Modifier l\'image de couverture'),
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
//                       decoration: InputDecoration(labelText: 'Titre'),
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
//                       decoration: InputDecoration(labelText: 'Description'),
//                       validator: (value) {
//                         if (value!.isEmpty) {
//                           return 'Veuillez entrer une description';
//                         }
//                         return null;
//                       },
//                     ),
//                     SizedBox(height: 50),
//                     ElevatedButton(
//                       onPressed: _updateCanal,
//                       child: Text('Mettre à jour le canal'),
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