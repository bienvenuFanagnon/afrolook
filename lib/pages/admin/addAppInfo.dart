import '../../services/media_shrink.dart';
import 'package:afrotok/layout/centered_content.dart';
import 'package:afrotok/services/api/admin_complements_api.dart';
import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/pages/component/consoleWidget.dart';

import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:path/path.dart' as Path;

import 'dart:io';

import 'package:anim_search_bar/anim_search_bar.dart';


import 'package:contained_tab_bar_view_with_custom_page_navigator/contained_tab_bar_view_with_custom_page_navigator.dart';


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

  /// Création par l'équipe (droit « content.moderate ») : l'image part vers le stockage, puis le serveur crée l'information,
  /// la journalise et prévient tout le monde (« NOUVEAUTÉ Afrolook ! Découvrez : … »).
  Future<void> _createInformation() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedImages.isEmpty) {
      _showErrorSnackBar('Veuillez sélectionner au moins une image');
      return;
    }

    setState(() { _isLoading = true; });

    try {
      // Comme avant, on garde la dernière image sélectionnée
      final File shrunk = await MediaShrink.file(File(_selectedImages.last.path));
      final String uploadId = await AdminComplementsApi.uploadImage(await shrunk.readAsBytes(), shrunk.path);
      await AdminComplementsApi.createInfo(
        type: 'APPINFO',
        title: _titreController.text.trim(),
        description: _descriptionController.text.trim(),
        mediaUploadId: uploadId,
        featured: _isFeatured,
      );

      _resetForm();
      _showSuccessSnackBar('Information créée avec succès!');
      Future.delayed(Duration(seconds: 1), () {
        if (mounted) Navigator.pop(context);
      });
    } catch (e) {
      printVm('Erreur création info: $e');
      _showErrorSnackBar(AdminComplementsApi.message(e, fallback: 'Erreur lors de la création'));
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
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
    return CenteredContent(child: SingleChildScrollView(
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
    ));
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
