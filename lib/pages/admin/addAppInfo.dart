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

import 'dart:io';
import 'package:afrotok/models/model_data.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as Path;
import 'package:provider/provider.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

import '../../constant/buttons.dart';
import '../../constant/sizeButtons.dart';
import '../../providers/authProvider.dart';
import '../../providers/userProvider.dart';

class NewAppInfo extends StatefulWidget {
  @override
  State<NewAppInfo> createState() => _NewAppInfoState();
}

class _NewAppInfoState extends State<NewAppInfo> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titreController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  late UserAuthProvider authProvider;
  late UserProvider userProvider;

  bool _isLoading = false;
  bool _isFeatured = false;
  List<XFile> _selectedImages = [];
  final ImagePicker _picker = ImagePicker();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      authProvider = Provider.of<UserAuthProvider>(context, listen: false);
      userProvider = Provider.of<UserProvider>(context, listen: false);
    });
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage(
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (images.isNotEmpty) {
        setState(() {
          _selectedImages = images.take(2).toList(); // Limite à 2 images
        });
      }
    } catch (e) {
      _showErrorSnackBar('Erreur lors de la sélection des images: $e');
    }
  }

  Future<String?> _uploadImage(File imageFile, String postId, int index) async {
    try {
      final String fileName = '${postId}_${DateTime.now().millisecondsSinceEpoch}_$index.jpg';
      final Reference storageRef = FirebaseStorage.instance
          .ref()
          .child('informations/$postId/$fileName');

      final UploadTask uploadTask = storageRef.putFile(
        imageFile,
        SettableMetadata(
          contentType: 'image/jpeg',
        ),
      );

      final TaskSnapshot snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print('Erreur upload image: $e');
      return null;
    }
  }

  Future<void> _createInformation() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedImages.isEmpty) {
      _showErrorSnackBar('Veuillez sélectionner au moins une image');
      return;
    }

    setState(() { _isLoading = true; });

    try {
      final String postId = _firestore.collection('Informations').doc().id;

      // Upload des images
      String? mediaUrl;
      for (int i = 0; i < _selectedImages.length; i++) {
        final File imageFile = File(_selectedImages[i].path);
        final String? uploadedUrl = await _uploadImage(imageFile, postId, i);
        if (uploadedUrl != null) {
          mediaUrl = uploadedUrl; // On garde la dernière image pour l'instant
          // Pour gérer plusieurs images, vous devriez utiliser une liste
        }
      }

      if (mediaUrl == null) {
        throw Exception('Erreur lors de l\'upload des images');
      }

      // Création de l'information
      final Information info = Information(
        id: postId,
        titre: _titreController.text.trim(),
        description: _descriptionController.text.trim(),
        media_url: mediaUrl,
        type: InfoType.APPINFO.name,
        status: PostStatus.VALIDE.name,
        isFeatured: _isFeatured,
        featuredAt: _isFeatured ? DateTime.now().millisecondsSinceEpoch : 0,
        views: 0,
        likes: 0,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );

      // Sauvegarde dans Firestore
      await _firestore.collection('Informations').doc(postId).set(info.toJson());

      // Création de la notification
      await _createNotification(postId);

      // Réinitialisation du formulaire
      _resetForm();

      _showSuccessSnackBar('Information créée avec succès!');

      // Retour à la page précédente après un délai
      Future.delayed(Duration(seconds: 1), () {
        if (mounted) Navigator.pop(context);
      });
      await authProvider.getAllUsersOneSignaUserId().then((userIds) async {
        if (userIds.isNotEmpty) {
          await authProvider.sendNotification(
            userIds: userIds,
            smallImage: mediaUrl!,
            send_user_id: authProvider.loginUserData!.id!,
            recever_user_id: '',
            message: "🚨 NOUVEAUTÉ Afrolook ! Découvrez : ${info.titre}",
            type_notif: NotificationType.POST.name,
            post_id: info.id ?? '',
            post_type: PostDataType.IMAGE.name,
            chat_id: '',
          );
        }
      });

    } catch (e) {
      print('Erreur création info: $e');
      _showErrorSnackBar('Erreur lors de la création: $e');
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  Future<void> _createNotification(String postId) async {
    try {
      final NotificationData notif = NotificationData(
        id: _firestore.collection('Notifications').doc().id,
        titre: "Nouvelle Information Afrolook",
        description: _titreController.text.trim(),
        users_id_view: [],
        receiver_id: "",
        user_id: authProvider.loginUserData.id,
        post_id: postId,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        status: PostStatus.VALIDE.name,
      );

      await _firestore.collection('Notifications').doc(notif.id).set(notif.toJson());
    } catch (e) {
      print('Erreur création notification: $e');
    }
  }

  void _resetForm() {
    _titreController.clear();
    _descriptionController.clear();
    setState(() {
      _selectedImages.clear();
      _isFeatured = false;
    });
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.green,
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.red,
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white),
        ),
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final double height = MediaQuery.of(context).size.height;
    final double width = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          'Nouvelle Information',
          style: TextStyle(
            color: Colors.yellow,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.yellow),
          onPressed: _isLoading ? null : () => Navigator.pop(context),
        ),
        elevation: 0,
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _buildForm(height, width),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          LoadingAnimationWidget.flickr(
            size: 60,
            leftDotColor: Colors.green,
            rightDotColor: Colors.yellow,
          ),
          SizedBox(height: 20),
          Text(
            'Création en cours...',
            style: TextStyle(
              color: Colors.yellow,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Veuillez patienter',
            style: TextStyle(
              color: Colors.green,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm(double height, double width) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFeaturedToggle(),
            SizedBox(height: 20),
            _buildTitreField(),
            SizedBox(height: 20),
            _buildDescriptionField(),
            SizedBox(height: 25),
            _buildImageSelectionSection(),
            SizedBox(height: 30),
            _buildSelectedImagesGrid(),
            SizedBox(height: 40),
            _buildCreateButton(),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturedToggle() {
    return Card(
      color: Colors.grey[900],
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.star,
              color: _isFeatured ? Colors.yellow : Colors.grey,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Mettre en avant',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Switch(
              value: _isFeatured,
              activeColor: Colors.green,
              activeTrackColor: Colors.green.withOpacity(0.4),
              onChanged: (value) {
                setState(() {
                  _isFeatured = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTitreField() {
    return Card(
      color: Colors.grey[900],
      child: Padding(
        padding: EdgeInsets.all(16),
        child: TextFormField(
          controller: _titreController,
          style: TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Titre *',
            labelStyle: TextStyle(color: Colors.yellow),
            hintText: 'Entrez le titre de l\'information',
            hintStyle: TextStyle(color: Colors.grey),
            border: InputBorder.none,
            icon: Icon(Icons.title, color: Colors.green),
          ),
          maxLength: 100,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Le titre est obligatoire';
            }
            if (value.trim().length < 5) {
              return 'Le titre doit faire au moins 5 caractères';
            }
            return null;
          },
        ),
      ),
    );
  }

  Widget _buildDescriptionField() {
    return Card(
      color: Colors.grey[900],
      child: Padding(
        padding: EdgeInsets.all(16),
        child: TextFormField(
          controller: _descriptionController,
          style: TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Description *',
            labelStyle: TextStyle(color: Colors.yellow),
            hintText: 'Décrivez l\'information en détail...',
            hintStyle: TextStyle(color: Colors.grey),
            border: InputBorder.none,
            alignLabelWithHint: true,
            icon: Icon(Icons.description, color: Colors.green),
          ),
          maxLines: 5,
          maxLength: 1000,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'La description est obligatoire';
            }
            if (value.trim().length < 10) {
              return 'La description doit faire au moins 10 caractères';
            }
            return null;
          },
        ),
      ),
    );
  }

  Widget _buildImageSelectionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Images *',
          style: TextStyle(
            color: Colors.yellow,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Sélectionnez 1 ou 2 images (${_selectedImages.length}/2)',
          style: TextStyle(
            color: Colors.green,
            fontSize: 12,
          ),
        ),
        SizedBox(height: 12),
        GestureDetector(
          onTap: _pickImages,
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green, width: 2),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.photo_library, color: Colors.green),
                SizedBox(width: 10),
                Text(
                  'Sélectionner des images',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedImagesGrid() {
    if (_selectedImages.isEmpty) return SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Images sélectionnées:',
          style: TextStyle(
            color: Colors.yellow,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.0,
          ),
          itemCount: _selectedImages.length,
          itemBuilder: (context, index) {
            return Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green, width: 2),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(
                      File(_selectedImages[index].path),
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
                ),
                Positioned(
                  top: 5,
                  right: 5,
                  child: GestureDetector(
                    onTap: () => _removeImage(index),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close,
                        color: Colors.red,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildCreateButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _createInformation,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.black,
          padding: EdgeInsets.symmetric(vertical: 16, horizontal: 32),
          textStyle: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 3,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.create, size: 24),
            SizedBox(width: 10),
            Text('CRÉER L\'INFORMATION'),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titreController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}
