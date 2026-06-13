import 'package:afrotok/models/model_data.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../../../../constant/constColors.dart';
import '../../../../../theme/app_colors.dart';
import '../../../../../constant/logo.dart';
import '../../../../../providers/authProvider.dart';
import '../widget/numbers_widget.dart';

class ProfilePage extends StatefulWidget {
  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late UserAuthProvider authProvider;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  bool change_profil_loading = false;
  bool isEditMode = false;
  File? _imageFile;
  Uint8List? _imageBytes;
  final _picker = ImagePicker();

  // Contrôleurs pour les champs éditables
  TextEditingController _nomController = TextEditingController();
  TextEditingController _prenomController = TextEditingController();
  TextEditingController _emailController = TextEditingController();
  TextEditingController _phoneController = TextEditingController();
  TextEditingController _aproposController = TextEditingController();

  late AppColors _colors;
  static const Color primaryRed = Color(0xFFE53935);
  static const Color accentRed = Color(0xFFFF5252);
  Future<void> _createProfileUpdatePost(String newImageUrl) async {
    try {
      print('📝 Création d\'un post de mise à jour de profil');

      String postId = FirebaseFirestore.instance.collection('Posts').doc().id;
      authProvider.loginUserData.imageUrl=newImageUrl;
      Post post = Post();
      post.user_id = authProvider.loginUserData.id;
      post.description = "👤 @${authProvider.loginUserData.pseudo} a mis à jour sa photo de profil";
      post.updatedAt = DateTime.now().microsecondsSinceEpoch;
      post.createdAt = DateTime.now().microsecondsSinceEpoch;
      post.status = PostStatus.VALIDE.name;
      post.type = PostType.POST.name;
      post.dataType = PostDataType.IMAGE.name;
      post.typeTabbar = 'LOOK'; // Type par défaut
      post.comments = 0;
      post.likes = 0;
      post.loves = 0;
      post.feedScore = 0.0;
      post.id = postId;
      post.images = [newImageUrl];
      if (authProvider.loginUserData.countryData?['countryCode'] != null) {
        String countryCode =authProvider.loginUserData.countryData!['countryCode']!;
        post.availableCountries = [countryCode];

      }
      // Visibilité : Tous les pays

      // Sauvegarder le post
      await FirebaseFirestore.instance
          .collection('Posts')
          .doc(postId)
          .set(post.toJson());

      print('✅ Post de mise à jour de profil créé avec succès');

      // Notifier les abonnés (optionnel)
      _notifyFollowersAboutProfileUpdate(postId);

    } catch (e) {
      print('❌ Erreur lors de la création du post: $e');
    }
  }

  void _notifyFollowersAboutProfileUpdate(String postId) async {
    try {
      // Notifier les abonnés via push notification
      authProvider.sendPushNotificationToUsers(
        sender: authProvider.loginUserData,
        message: "👤 @${authProvider.loginUserData.pseudo} a mis à jour sa photo de profil",
        typeNotif: NotificationType.POST.name,
        postId: postId,
        postType: PostDataType.IMAGE.name,
        chatId: '',
        smallImage: authProvider.loginUserData.imageUrl,
        isChannel: false,
      );

      // Ajouter des points pour l'action
      addPointsForAction(UserAction.post);

    } catch (e) {
      print('❌ Erreur notification: $e');
    }
  }
  @override
  void initState() {
    super.initState();
    authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    _initControllers();
  }

  void _initControllers() {
    _nomController.text = authProvider.loginUserData.nom ?? '';
    _prenomController.text = authProvider.loginUserData.prenom ?? '';
    _emailController.text = authProvider.loginUserData.email ?? '';
    _phoneController.text = authProvider.loginUserData.numeroDeTelephone ?? '';
    _aproposController.text = authProvider.loginUserData.apropos ?? '';
  }

  Future<void> _pickImage() async {
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        if (kIsWeb) {
          // Pour le web, lire les bytes directement
          final bytes = await pickedFile.readAsBytes();
          setState(() {
            _imageBytes = bytes;
            _imageFile = null;
          });
        } else {
          // Pour mobile, utiliser File
          setState(() {
            _imageFile = File(pickedFile.path);
            _imageBytes = null;
          });
        }
      }
    } catch (e) {
      print("Erreur lors de la sélection d'image: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur lors de la sélection d'image"),
          backgroundColor: primaryRed,
        ),
      );
    }
  }

  Future<void> _uploadProfileImage() async {
    if (_imageBytes == null && _imageFile == null) return;

    setState(() {
      change_profil_loading = true;
    });

    try {
      // Générer un nom de fichier unique
      String fileName = 'profile_${authProvider.loginUserData.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      Reference storageReference = FirebaseStorage.instance
          .ref()
          .child('user_profiles/$fileName');

      // Upload pour web et mobile
      UploadTask uploadTask;

      if (kIsWeb) {
        // Pour le web, utiliser les bytes
        uploadTask = storageReference.putData(
          _imageBytes!,
          SettableMetadata(
            contentType: 'image/jpeg',
          ),
        );
      } else {
        // Pour mobile, utiliser le fichier
        uploadTask = storageReference.putFile(_imageFile!);
      }

      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();

      // ✅ CRÉER LE POST AVANT DE METTRE À JOUR LE PROFIL
       _createProfileUpdatePost(downloadUrl);

      // Mettre à jour seulement l'URL de l'image
      await firestore.collection('Users').doc(authProvider.loginUserData.id).update({
        'imageUrl': downloadUrl,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });

      // Mettre à jour le provider
      authProvider.loginUserData.imageUrl = downloadUrl;
      authProvider.notifyListeners();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Photo de profil mise à jour avec succès',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      // Réinitialiser l'image après upload
      setState(() {
        _imageBytes = null;
        _imageFile = null;
      });

    } catch (error) {
      print("Erreur upload: $error");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur lors du téléchargement de l'image"),
          backgroundColor: primaryRed,
        ),
      );
    } finally {
      setState(() {
        change_profil_loading = false;
      });
    }
  }
  Future<void> _updateUserInfo() async {
    try {
      setState(() {
        change_profil_loading = true;
      });

      // Créer un map avec seulement les champs modifiés
      Map<String, dynamic> updates = {};

      if (_nomController.text != authProvider.loginUserData.nom) {
        updates['nom'] = _nomController.text;
      }
      if (_prenomController.text != authProvider.loginUserData.prenom) {
        updates['prenom'] = _prenomController.text;
      }
      if (_emailController.text != authProvider.loginUserData.email) {
        updates['email'] = _emailController.text;
      }
      if (_phoneController.text != authProvider.loginUserData.numeroDeTelephone) {
        updates['numero_de_telephone'] = _phoneController.text;
      }
      if (_aproposController.text != authProvider.loginUserData.apropos) {
        updates['apropos'] = _aproposController.text;
      }

      // Ajouter le timestamp de mise à jour
      updates['updatedAt'] = DateTime.now().millisecondsSinceEpoch;

      if (updates.isNotEmpty) {
        await firestore.collection('Users').doc(authProvider.loginUserData.id).update(updates);

        // Mettre à jour le provider local
        authProvider.loginUserData.nom = _nomController.text;
        authProvider.loginUserData.prenom = _prenomController.text;
        authProvider.loginUserData.email = _emailController.text;
        authProvider.loginUserData.numeroDeTelephone = _phoneController.text;
        authProvider.loginUserData.apropos = _aproposController.text;
        authProvider.notifyListeners();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Informations mises à jour avec succès',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.green,
          ),
        );
      }

    } catch (error) {
      print("Erreur update: $error");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur lors de la mise à jour"),
          backgroundColor: primaryRed,
        ),
      );
    } finally {
      setState(() {
        change_profil_loading = false;
        isEditMode = false;
      });
    }
  }

  Widget _buildProfileImage() {
    final hasSelectedImage = _imageBytes != null || _imageFile != null;
    final currentImageUrl = authProvider.loginUserData.imageUrl;

    return Stack(
      children: [
        Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [primaryRed, _colors.accent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(4.0),
            child: CircleAvatar(
              radius: 66,
              backgroundColor: _colors.surfaceVariant,
              child: ClipOval(
                child: hasSelectedImage
                    ? _buildSelectedImage()
                    : _buildCurrentProfileImage(currentImageUrl),
              ),
            ),
          ),
        ),
        if (isEditMode)
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: _pickImage,
              child: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _colors.background,
                  shape: BoxShape.circle,
                  border: Border.all(color: _colors.accent, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 5,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.camera_alt,
                  color: _colors.accent,
                  size: 20,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSelectedImage() {
    if (_imageBytes != null) {
      // Pour le web: utiliser Image.memory avec les bytes
      return Image.memory(
        _imageBytes!,
        width: 130,
        height: 130,
        fit: BoxFit.cover,
      );
    } else if (_imageFile != null) {
      // Pour mobile: utiliser Image.file
      return Image.file(
        _imageFile!,
        width: 130,
        height: 130,
        fit: BoxFit.cover,
      );
    }
    return _buildFallbackImage();
  }

  Widget _buildCurrentProfileImage(String? imageUrl) {
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return Image.network(
        imageUrl,
        width: 130,
        height: 130,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                  loadingProgress.expectedTotalBytes!
                  : null,
              color: _colors.accent,
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return _buildFallbackImage();
        },
      );
    }
    return _buildFallbackImage();
  }

  Widget _buildFallbackImage() {
    return Icon(
      Icons.person,
      size: 60,
      color: _colors.textSecondary,
    );
  }

  Widget _buildInfoCard(String title, String value, IconData icon, bool editable) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 6),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!, width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _colors.background,
              shape: BoxShape.circle,
              border: Border.all(color: _colors.accent.withOpacity(0.3)),
            ),
            child: Icon(
              icon,
              color: _colors.accent,
              size: 20,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: _colors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 4),
                if (editable && isEditMode)
                  TextField(
                    controller: title == 'Nom' ? _nomController :
                    title == 'Prénom' ? _prenomController :
                    title == 'Email' ? _emailController :
                    title == 'Téléphone' ? _phoneController : _aproposController,
                    style: TextStyle(
                      color: _colors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  )
                else
                  Text(
                    value.isNotEmpty ? value : 'Non renseigné',
                    style: TextStyle(
                      color: value.isNotEmpty ? _colors.textPrimary : _colors.textSecondary,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: title == 'À propos' ? 3 : 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParrainageCard() {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _colors.accent.withOpacity(0.3), width: 1),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _colors.background.withOpacity(0.8),
            _colors.background.withOpacity(0.9),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.share,
                color: _colors.accent,
                size: 20,
              ),
              SizedBox(width: 10),
              Text(
                "Parrainage",
                style: TextStyle(
                  color: _colors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 15),
          Container(
            padding: EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: _colors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: primaryRed.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Votre code",
                      style: TextStyle(
                        color: _colors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      "${authProvider.loginUserData.codeParrainage}",
                      style: TextStyle(
                        color: _colors.accent,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(
                        text: "${authProvider.loginUserData.codeParrainage}"));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Code copié dans le presse-papier !',
                          style: TextStyle(color: Colors.white),
                        ),
                        backgroundColor: Colors.green,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: primaryRed.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: primaryRed),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.copy,
                          color: primaryRed,
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Text(
                          "Copier",
                          style: TextStyle(
                            color: primaryRed,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 10),
          Text(
            "Partagez ce code avec vos amis pour gagner des récompenses !",
            style: TextStyle(
              color: _colors.textSecondary,
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _colors = AppColors.of(context);
    final hasSelectedImage = _imageBytes != null || _imageFile != null;

    return Scaffold(
      backgroundColor: _colors.background,
      appBar: AppBar(
        backgroundColor: _colors.background,
        elevation: 0,
        title: Text(
          "Mes Informations",
          style: TextStyle(
            color: _colors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _colors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Logo(),
            ),
          ),
        ],
        iconTheme: IconThemeData(color: _colors.textPrimary),
      ),
      body: RefreshIndicator(
        color: primaryRed,
        backgroundColor: _colors.background,
        onRefresh: () async {
          setState(() {});
          return Future.delayed(Duration(milliseconds: 500));
        },
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              // Section Photo de profil
              Center(
                child: Column(
                  children: [
                    _buildProfileImage(),
                    SizedBox(height: 10),
                    if (isEditMode && hasSelectedImage)
                      AnimatedOpacity(
                        opacity: hasSelectedImage ? 1.0 : 0.0,
                        duration: Duration(milliseconds: 300),
                        child: Container(
                          margin: EdgeInsets.only(bottom: 10),
                          child: change_profil_loading
                              ? CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(_colors.accent),
                          )
                              : ElevatedButton(
                            onPressed: _uploadProfileImage,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryRed,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25),
                              ),
                              padding: EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.cloud_upload, size: 18),
                                SizedBox(width: 8),
                                Text("Enregistrer la photo"),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              SizedBox(height: 24),

              // Section Pseudo (non éditable)
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _colors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _colors.accent.withOpacity(0.3)),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Text(
                        "Pseudo",
                        style: TextStyle(
                          color: _colors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        "@${authProvider.loginUserData.pseudo ?? ''}",
                        style: TextStyle(
                          color: _colors.accent,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                      Text(
                        "(Non modifiable)",
                        style: TextStyle(
                          color: _colors.textSecondary,
                          fontSize: 10,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 20),

              // Section Statistiques
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _colors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: primaryRed.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    Text(
                      "Statistiques",
                      style: TextStyle(
                        color: _colors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 15),
                    NumbersWidget(
                      followers: authProvider.loginUserData.userAbonnesIds?.length ?? 0,
                      taux: (authProvider.loginUserData.popularite ?? 0.0) * 100,
                      points: authProvider.loginUserData.pointContribution ?? 0,
                    ),
                    SizedBox(height: 15),
                    Container(
                      padding: EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: _colors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.favorite,
                            color: Colors.green,
                            size: 20,
                          ),
                          SizedBox(width: 10),
                          Text(
                            "${formatNumber(authProvider.loginUserData.userlikes ?? 0)} like(s)",
                            style: TextStyle(
                              color: Colors.green,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),

              // Section Informations personnelles
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _colors.surface,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Informations",
                          style: TextStyle(
                            color: _colors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            if (isEditMode) {
                              _updateUserInfo();
                            } else {
                              setState(() {
                                isEditMode = true;
                              });
                            }
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: isEditMode ? Colors.green : primaryRed,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isEditMode
                                      ? Icons.check
                                      : Icons.edit,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  isEditMode ? "Enregistrer" : "Modifier",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 20),

                    _buildInfoCard(
                      'Nom',
                      authProvider.loginUserData.nom ?? '',
                      Icons.person_outline,
                      true,
                    ),

                    _buildInfoCard(
                      'Prénom',
                      authProvider.loginUserData.prenom ?? '',
                      Icons.person_outline,
                      true,
                    ),

                    _buildInfoCard(
                      'Email',
                      authProvider.loginUserData.email ?? '',
                      Icons.email_outlined,
                      false,
                    ),

                    _buildInfoCard(
                      'Téléphone',
                      authProvider.loginUserData.numeroDeTelephone ?? '',
                      Icons.phone,
                      true,
                    ),

                    _buildInfoCard(
                      'À propos',
                      authProvider.loginUserData.apropos ?? '',
                      Icons.info_outline,
                      true,
                    ),
                  ],
                ),
              ),

              SizedBox(height: 20),

              // Section Parrainage
              _buildParrainageCard(),



              SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  String formatNumber(int number) {
    if (number < 1000) {
      return number.toString();
    } else if (number < 1000000) {
      return "${(number / 1000).toStringAsFixed(1)}k";
    } else if (number < 1000000000) {
      return "${(number / 1000000).toStringAsFixed(1)}M";
    } else {
      return "${(number / 1000000000).toStringAsFixed(1)}B";
    }
  }
}

