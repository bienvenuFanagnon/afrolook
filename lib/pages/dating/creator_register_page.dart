// lib/pages/creator/creator_register_page.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/dating_data.dart';
import '../../providers/authProvider.dart';
import '../../models/enums.dart';

class CreatorRegisterPage extends StatefulWidget {
  const CreatorRegisterPage({Key? key}) : super(key: key);

  @override
  State<CreatorRegisterPage> createState() => _CreatorRegisterPageState();
}

class _CreatorRegisterPageState extends State<CreatorRegisterPage> {
  final TextEditingController _pseudoController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  CreatorType _selectedType = CreatorType.influencer;

  // Image handling (support web via Uint8List)
  File? _selectedImageFile;      // pour mobile
  Uint8List? _selectedImageBytes; // pour web
  bool _isLoading = false;

  final ImagePicker _picker = ImagePicker();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  final Color primaryRed = const Color(0xFFE63946);
  final Color primaryYellow = const Color(0xFFFFD700);
  final Color primaryBlack = Colors.black;
  final Color secondaryGrey = const Color(0xFF2C2C2C);

  @override
  void dispose() {
    _pseudoController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        if (kIsWeb) {
          // Web: lire les bytes
          final bytes = await pickedFile.readAsBytes();
          setState(() {
            _selectedImageBytes = bytes;
            _selectedImageFile = null;
          });
        } else {
          // Mobile: garder le File
          setState(() {
            _selectedImageFile = File(pickedFile.path);
            _selectedImageBytes = null;
          });
        }
      }
    } catch (e) {
      print('❌ Erreur sélection image: $e');
    }
  }

  Future<String?> _uploadImage() async {
    if (kIsWeb) {
      if (_selectedImageBytes == null) return null;
      try {
        final fileName = 'creator_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final ref = _storage.ref().child('creator_profiles').child(fileName);
        await ref.putData(_selectedImageBytes!);
        return await ref.getDownloadURL();
      } catch (e) {
        print('❌ Erreur upload image (web): $e');
        return null;
      }
    } else {
      if (_selectedImageFile == null) return null;
      try {
        final fileName = 'creator_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final ref = _storage.ref().child('creator_profiles').child(fileName);
        await ref.putFile(_selectedImageFile!);
        return await ref.getDownloadURL();
      } catch (e) {
        print('❌ Erreur upload image (mobile): $e');
        return null;
      }
    }
  }

  Future<void> _register() async {
    if (_pseudoController.text.trim().isEmpty) {
      _showSnackBar('Veuillez entrer un pseudo', Colors.red);
      return;
    }
    if (_bioController.text.trim().isEmpty) {
      _showSnackBar('Veuillez entrer une bio', Colors.red);
      return;
    }
    if ((_selectedImageFile == null && _selectedImageBytes == null)) {
      _showSnackBar('Veuillez ajouter une photo de profil', Colors.red);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
      final userId = authProvider.loginUserData.id;
      if (userId == null) throw Exception('Utilisateur non connecté');

      final imageUrl = await _uploadImage();
      if (imageUrl == null) throw Exception('Erreur upload image');

      final now = DateTime.now().millisecondsSinceEpoch;
      final creatorProfile = CreatorProfile(
        id: _firestore.collection('creator_profiles').doc().id,
        userId: userId,
        pseudo: _pseudoController.text.trim(),
        imageUrl: imageUrl,
        bio: _bioController.text.trim(),
        creatorType: _selectedType,
        isCreatorActive: true,
        isVerified: false,
        subscribersCount: 0,
        freeContentsCount: 0,
        paidContentsCount: 0,
        totalViews: 0,
        totalInteractions: 0,
        totalShares: 0,
        createdAt: now,
        updatedAt: now,
      );

      await _firestore
          .collection('creator_profiles')
          .doc(creatorProfile.id)
          .set(creatorProfile.toJson());

      // Mettre à jour UserData
      await _firestore.collection('Users').doc(userId).update({
        'isCreatorProfileEnabled': true,
        'updatedAt': now,
      });

      _showSnackBar('Félicitations ! Vous êtes maintenant créateur !', Colors.green);
      Navigator.pop(context);
    } catch (e) {
      print('❌ Erreur inscription créateur: $e');
      _showSnackBar('Erreur: ${e.toString()}', Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Préparer l'image à afficher
    ImageProvider? imageProvider;
    if (kIsWeb && _selectedImageBytes != null) {
      imageProvider = MemoryImage(_selectedImageBytes!);
    } else if (!kIsWeb && _selectedImageFile != null) {
      imageProvider = FileImage(_selectedImageFile!);
    }

    return Scaffold(
      backgroundColor: primaryBlack,
      appBar: AppBar(
        title: Text(
          'Devenir créateur',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryRed,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // En-tête
            Container(
              margin: EdgeInsets.only(bottom: 24),
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [primaryRed, primaryYellow]),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.people, size: 40, color: primaryBlack),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Partagez votre contenu et gagnez de l\'argent',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[400], fontSize: 14),
                  ),
                ],
              ),
            ),

            // Photo de profil
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 120,
                width: 120,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: secondaryGrey,
                  border: Border.all(color: primaryRed, width: 2),
                ),
                child: imageProvider != null
                    ? ClipOval(
                  child: Image(
                    image: imageProvider,
                    fit: BoxFit.cover,
                    width: 120,
                    height: 120,
                  ),
                )
                    : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_a_photo, color: primaryYellow, size: 30),
                    SizedBox(height: 8),
                    Text('Ajouter une photo', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                  ],
                ),
              ),
            ),
            SizedBox(height: 24),

            // Pseudo
            TextFormField(
              controller: _pseudoController,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Nom d\'artiste / Pseudo',
                labelStyle: TextStyle(color: Colors.grey[400]),
                prefixIcon: Icon(Icons.person, color: primaryRed),
                filled: true,
                fillColor: secondaryGrey,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            SizedBox(height: 16),

            // Bio
            TextFormField(
              controller: _bioController,
              style: TextStyle(color: Colors.white),
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Bio',
                labelStyle: TextStyle(color: Colors.grey[400]),
                prefixIcon: Icon(Icons.description, color: primaryRed),
                filled: true,
                fillColor: secondaryGrey,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            SizedBox(height: 16),

            // Type de créateur
            DropdownButtonFormField<CreatorType>(
              value: _selectedType,
              style: TextStyle(color: Colors.white),
              dropdownColor: secondaryGrey,
              decoration: InputDecoration(
                labelText: 'Type de créateur',
                labelStyle: TextStyle(color: Colors.grey[400]),
                prefixIcon: Icon(Icons.category, color: primaryRed),
                filled: true,
                fillColor: secondaryGrey,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              items: CreatorType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(_getTypeLabel(type)),
                );
              }).toList(),
              onChanged: (value) => setState(() => _selectedType = value!),
            ),
            SizedBox(height: 32),

            // Bouton d'inscription
            _isLoading
                ? Center(child: CircularProgressIndicator())
                : ElevatedButton(
              onPressed: _register,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryYellow,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: Text(
                'Devenir créateur',
                style: TextStyle(color: primaryBlack, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            SizedBox(height: 16),

            // Mentions légales
            Text(
              'En devenant créateur, vous acceptez les conditions d\'utilisation et la politique de monétisation.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  String _getTypeLabel(CreatorType type) {
    switch (type) {
      case CreatorType.influencer:
        return 'Influenceur';
      case CreatorType.artist:
        return 'Artiste';
      case CreatorType.educator:
        return 'Éducateur';
      case CreatorType.entertainer:
        return 'Divertissement';
      default:
        return 'Autre';
    }
  }
}