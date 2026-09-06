import 'package:afrotok/utils/responsive_sheet.dart';

import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as Path;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csc_picker_plus/csc_picker_plus.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import '../../../../../../models/model_data.dart';
import '../../../../../../constants/user_interests.dart';
import '../../../../../../widgets/interests_selector_widget.dart';

import '../../../../../../providers/authProvider.dart';
import 'dart:async';
import 'dart:io';
import '../../../../component/consoleWidget.dart';
import '../Login/loginPageUser.dart';
import '../../../../../theme/app_colors.dart';
import '../../../../../l10n/app_localizations.dart';

// Couleurs de base
const Color primaryGreen = Color(0xFF25D366);

class SignUpFormEtap3 extends StatefulWidget {
  SignUpFormEtap3({Key? key}) : super(key: key);

  @override
  State<SignUpFormEtap3> createState() => _SignUpFormEtap3State();
}

class _SignUpFormEtap3State extends State<SignUpFormEtap3> {
  late AppColors _colors;
  late AppLocalizations l10n;
  late UserAuthProvider authProvider;
  final TextEditingController adresseController = TextEditingController();
  final TextEditingController aproposController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  late bool tap = false;
  final _auth = FirebaseAuth.instance;
  bool adreseLoging = false;
  bool onTap = false;

  List<String> _selectedInterests = [];

  // Gestion de l'image pour mobile (File) et web (Uint8List)
  File? _imageFile;
  Uint8List? _imageBytes;
  String? _imageFileName;

  final ImagePicker _picker = ImagePicker();

  String? _currentAddress = '';
  Position? _currentPosition;

  // Pays
  String _countryValue = '';
  String _stateValue = '';
  String _cityValue = '';
  String? _detectedCountryCode;
  String? _detectedCountryName;
  bool _locationDetected = false;
  bool _locationLoading = false;

  static const Map<String, String> _countryCodes = {
    "Togo": "TG", "Benin": "BJ", "Burkina Faso": "BF", "Cameroon": "CM",
    "Ivory Coast": "CI", "Algeria": "DZ", "Angola": "AO", "Botswana": "BW",
    "Burundi": "BI", "Chad": "TD", "Congo": "CG", "Egypt": "EG",
    "Ethiopia": "ET", "Gabon": "GA", "Ghana": "GH", "Guinea": "GN",
    "Kenya": "KE", "Libya": "LY", "Madagascar": "MG", "Mali": "ML",
    "Morocco": "MA", "Mozambique": "MZ", "Namibia": "NA", "Niger": "NE",
    "Nigeria": "NG", "Rwanda": "RW", "Senegal": "SN", "Somalia": "SO",
    "South Africa": "ZA", "Sudan": "SD", "Tanzania": "TZ", "Tunisia": "TN",
    "Uganda": "UG", "Zambia": "ZM", "Zimbabwe": "ZW",
    "France": "FR", "Germany": "DE", "Italy": "IT", "Spain": "ES",
    "Portugal": "PT", "Belgium": "BE", "United Kingdom": "GB",
    "United States": "US", "Canada": "CA", "Brazil": "BR",
  };

  String _getCountryCodeFromName(String country) => _countryCodes[country] ?? '';

  @override
  void initState() {
    super.initState();
    authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    if (!kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _detectCountryMobile());
    }
  }

  Future<void> _detectCountryMobile() async {
    if (_locationLoading || _locationDetected) return;
    setState(() => _locationLoading = true);
    try {
      final permission = await Permission.location.request();
      if (!permission.isGranted) return;
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 10),
      );
      final placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty && mounted) {
        setState(() {
          _detectedCountryCode = placemarks[0].isoCountryCode;
          _detectedCountryName = placemarks[0].country;
          _locationDetected = true;
          if (_countryValue.isEmpty && _detectedCountryName != null) {
            _countryValue = _detectedCountryName!;
          }
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _locationLoading = false);
    }
  }

  // Méthode pour récupérer l'image (compatible web et mobile)
  Future<void> getImage() async {
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        if (kIsWeb) {
          // Pour le web : lire les bytes
          final bytes = await pickedFile.readAsBytes();
          setState(() {
            _imageBytes = bytes;
            _imageFileName = pickedFile.name;
            _imageFile = null;
          });
        } else {
          // Pour mobile : utiliser File
          setState(() {
            _imageFile = File(pickedFile.path);
            _imageBytes = null;
            _imageFileName = Path.basename(pickedFile.path);
          });
        }

        // Afficher un message de confirmation
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: _colors.success,
            content: Text(l10n.signupImageSelectedSuccess, style: TextStyle(color: _colors.onPrimary)),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      printVm("Erreur lors de la sélection de l'image: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: _colors.danger,
          content: Text(l10n.signupImageSelectError, style: TextStyle(color: _colors.onPrimary)),
        ),
      );
    }
  }

  // Méthode pour envoyer l'email de vérification
  Future<void> sendVerificationEmail(User user) async {
    try {
      await user.sendEmailVerification();
      _showVerificationModal();
    } catch (e) {
      printVm("Erreur lors de l'envoi de l'email de vérification: $e");
    }
  }

  // Modal de création et vérification d'email
  void _showVerificationModal() {
    showResponsiveBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: _colors.background,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(25),
            topRight: Radius.circular(25),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 80,
                color: _colors.success,
              ),
              SizedBox(height: 20),
              Text(
                l10n.signupAccountCreatedSuccess,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: _colors.success,
                ),
              ),
              SizedBox(height: 15),
              Icon(
                Icons.mark_email_read_outlined,
                size: 50,
                color: _colors.warning,
              ),
              SizedBox(height: 10),
              Text(
                l10n.signupOneStepLeft,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _colors.warning,
                ),
              ),
              SizedBox(height: 10),
              Text(
                l10n.signupVerificationEmailSentTo,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: _colors.textSecondary,
                ),
              ),
              SizedBox(height: 5),
              Text(
                authProvider.registerUser.email!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _colors.warning,
                ),
              ),
              SizedBox(height: 20),
              Text(
                l10n.signupCheckSpamFolder,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: _colors.textSecondary,
                ),
              ),
              SizedBox(height: 30),
              Container(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pushReplacementNamed(context, "/login");
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _colors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: Text(
                    l10n.signupUnderstood,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _colors.onPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<UserData?> verifierParrain(String codeParrain) async {
    CollectionReference users = firestore.collection("Users");
    QuerySnapshot snapshot = await users
        .where("code_parrainage", isEqualTo: codeParrain)
        .get();
    final list = snapshot.docs.map((doc) =>
        UserData.fromJson(doc.data() as Map<String, dynamic>)).toList();

    if (list.isNotEmpty) {
      printVm("user trouver");
      addPointsForOtherUserAction(list.first.id!, UserAction.autre);
      return list.first;
    } else {
      printVm("user non trouver^^^^^^^^^^^^^^^^^^^^");
      return null;
    }
  }

  // Méthode pour uploader l'image (compatible web et mobile)
  Future<String> _uploadImage() async {
    try {
      // Vérifier qu'une image est sélectionnée
      if (_imageBytes == null && _imageFile == null) {
        throw Exception("Aucune image sélectionnée");
      }

      // Générer un nom de fichier unique
      String fileName = 'profile_${authProvider.registerUser.pseudo}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      Reference storageReference = FirebaseStorage.instance
          .ref()
          .child('user_profile/$fileName');

      UploadTask uploadTask;

      if (kIsWeb) {
        // Pour le web : upload avec les bytes
        uploadTask = storageReference.putData(
          _imageBytes!,
          SettableMetadata(
            contentType: 'image/jpeg',
            customMetadata: {'pickedFileName': _imageFileName ?? 'web_image.jpg'},
          ),
        );
      } else {
        // Pour mobile : upload avec le fichier
        uploadTask = storageReference.putFile(_imageFile!);
      }

      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      printVm("Erreur lors de l'upload de l'image: $e");
      throw Exception("Échec de l'upload de l'image");
    }
  }

  // Vérification de la taille de l'image
  Future<bool> _checkImageSize() async {
    if (_imageBytes != null) {
      // Pour le web : vérifier la taille des bytes
      return _imageBytes!.length <= 5 * 1024 * 1024;
    } else if (_imageFile != null) {
      // Pour mobile : vérifier la taille du fichier
      final imageSize = await _imageFile!.length();
      return imageSize <= 5 * 1024 * 1024;
    }
    return false;
  }

  // Méthode d'inscription principale
  Future<void> signUp(String email, String password) async {
    if (!_formKey.currentState!.validate()) return;

    // Vérification de l'image
    if (_imageBytes == null && _imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: _colors.warning,
          content: Text(l10n.signupSelectProfilePhoto, style: TextStyle(color: _colors.onPrimary)),
        ),
      );
      return;
    }

    // Vérification des centres d'intérêt (min 3)
    if (_selectedInterests.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: _colors.warning,
          content: Text('Choisis au moins 3 centres d\'intérêt', style: TextStyle(color: _colors.onPrimary)),
        ),
      );
      return;
    }

    // Vérification de la taille de l'image (max 5MB)
    final bool isSizeValid = await _checkImageSize();
    if (!isSizeValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: _colors.warning,
          content: Text(l10n.signupImageTooLarge, style: TextStyle(color: _colors.onPrimary)),
        ),
      );
      return;
    }

    setState(() => tap = true);

    try {
      // Configuration des données utilisateur
      authProvider.registerUser
        ..role = UserRole.USER.name!
        ..updatedAt = DateTime.now().millisecondsSinceEpoch
        ..createdAt = DateTime.now().millisecondsSinceEpoch;

      // Upload de l'image
      String imageUrl = await _uploadImage();
      authProvider.registerUser.imageUrl = imageUrl;

      // Configuration des autres données
      authProvider.registerUser.adresse = adresseController.text;
      authProvider.registerUser.apropos = aproposController.text;
      authProvider.registerUser.votre_solde = 0.0;
      authProvider.registerUser.interests = List.from(_selectedInterests);

      UserPseudo pseudo = UserPseudo();
      String id = "";
      NotificationData notif = NotificationData();

      // Gestion du parrainage
      if (authProvider.registerUser.codeParrain!.isNotEmpty) {
        final UserData? parrain = await verifierParrain(authProvider.registerUser.codeParrain!);

        if (parrain != null) {
          // Création du compte avec parrainage
          final UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
            email: email,
            password: password,
          );

          id = userCredential.user!.uid;

          // Configuration des données
          await _configureUserDataWithParrainage(id, pseudo, parrain);

          // Rejoindre les groupes officiels en arrière-plan
          unawaited(_autoJoinOfficialGroups(id));

          // Envoi de la notification de parrainage
          await _sendParrainageNotification(parrain);

          // Envoi de l'email de vérification
          await sendVerificationEmail(userCredential.user!);

          // Affichage du succès
          _showSuccessAndNavigate();

        } else {
          // Code de parrainage invalide
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: _colors.danger,
              content: Text(l10n.signupCodeParrainInvalid, style: TextStyle(color: _colors.onPrimary)),
            ),
          );
          setState(() => tap = false);
          return;
        }
      } else {
        // Création du compte sans parrainage
        final UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        id = userCredential.user!.uid;

        // Configuration des données
        await _configureUserDataWithoutParrainage(id, pseudo);

        // Rejoindre les groupes officiels en arrière-plan
        unawaited(_autoJoinOfficialGroups(id));

        // Envoi de l'email de vérification
        await sendVerificationEmail(userCredential.user!);

        // Affichage du succès
        _showSuccessAndNavigate();
      }

    } on FirebaseAuthException catch (error) {
      _handleAuthError(error);
    } on FirebaseException catch (error) {
      _handleFirebaseError(error);
    } catch (error) {
      _handleGenericError(error);
    } finally {
      setState(() => tap = false);
    }
  }

  // Configuration des données avec parrainage
  Future<void> _configureUserDataWithParrainage(String id, UserPseudo pseudo, UserData parrain) async {
    pseudo.id = firestore.collection('Pseudo').doc().id;
    pseudo.name = authProvider.registerUser.pseudo;
    authProvider.registerUser.id = id;

    await authProvider.getAppData();

    // Pays détecté ou sélectionné
    _applyCountryToUser();

    // Configuration de l'utilisateur
    authProvider.registerUser.pointContribution = authProvider.appDefaultData.default_point_new_user!;
    authProvider.registerUser.votre_solde = 5.1;
    authProvider.registerUser.publi_cash = 5.1;

    // Mise à jour du parrain
    final usersRef = firestore.collection('Users');
    final parrainRef = usersRef.doc(parrain.id!);

    await parrainRef.update({
      'pointContribution': (parrain.pointContribution ?? 0) + authProvider.appDefaultData.default_point_new_user!,
      'votre_solde': (parrain.votre_solde ?? 0.0) + 5.1,
      'publi_cash': (parrain.publi_cash ?? 0.0) + 5.1,
      'usersParrainer': FieldValue.arrayUnion([id]),
      'userAbonnesIds': FieldValue.arrayUnion([id]),
      'abonnes': FieldValue.increment(1),
    });

    // Batch operations
    final batch = firestore.batch();
    batch.set(firestore.collection('Users').doc(id), authProvider.registerUser.toJson());
    batch.set(firestore.collection('Pseudo').doc(pseudo.id), pseudo.toJson());


    batch.update(firestore.collection('AppData').doc(authProvider.appDefaultData.id!), {
      'nbr_abonnes': FieldValue.increment(1),
      'users_id': FieldValue.arrayUnion([id]),
    });

    await batch.commit();
  }

  void _applyCountryToUser() {
    final country = _countryValue.isNotEmpty ? _countryValue : (_detectedCountryName ?? '');
    final code = kIsWeb
        ? _getCountryCodeFromName(country)
        : (_detectedCountryCode ?? _getCountryCodeFromName(country));
    authProvider.registerUser.countryData = {
      'country': country,
      'state': _stateValue,
      'city': _cityValue,
      'countryCode': code,
      'realCountry': _detectedCountryName ?? country,
    };
  }

  // Configuration des données sans parrainage
  Future<void> _configureUserDataWithoutParrainage(String id, UserPseudo pseudo) async {
    pseudo.id = firestore.collection('Pseudo').doc().id;
    pseudo.name = authProvider.registerUser.pseudo;
    authProvider.registerUser.id = id;

    await authProvider.getAppData();

    // Pays détecté ou sélectionné
    _applyCountryToUser();

    // Configuration de l'utilisateur
    authProvider.registerUser.pointContribution = authProvider.appDefaultData.default_point_new_user!;
    authProvider.registerUser.votre_solde = 0.0;
    authProvider.registerUser.publi_cash = 0.0;

    // Batch operations
    final batch = firestore.batch();
    batch.set(firestore.collection('Users').doc(id), authProvider.registerUser.toJson());
    batch.set(firestore.collection('Pseudo').doc(pseudo.id), pseudo.toJson());


    batch.update(firestore.collection('AppData').doc(authProvider.appDefaultData.id!), {
      'nbr_abonnes': FieldValue.increment(1),
      'users_id': FieldValue.arrayUnion([id]),
    });

    await batch.commit();
  }

  // Rejoindre automatiquement tous les groupes officiels à la création du compte
  Future<void> _autoJoinOfficialGroups(String userId) async {
    try {
      final userDoc = await firestore.collection('Users').doc(userId).get();
      final ud = userDoc.data();
      final now = DateTime.now().millisecondsSinceEpoch;

      final groupsSnap = await firestore
          .collection('GroupChats')
          .where('is_official', isEqualTo: true)
          .where('is_frozen', isEqualTo: false)
          .get();

      for (final groupDoc in groupsSnap.docs) {
        try {
          final memberIds = (groupDoc.data()['member_ids'] as List<dynamic>? ?? []).cast<String>();
          if (memberIds.contains(userId)) continue;

          final groupRef = firestore.collection('GroupChats').doc(groupDoc.id);
          await groupRef.collection('members').doc(userId).set({
            'user_id': userId,
            'pseudo': ud?['pseudo'] ?? '',
            'image_url': ud?['imageUrl'] ?? '',
            'role': 'member',
            'joined_at': now,
          });
          await groupRef.update({
            'member_ids': FieldValue.arrayUnion([userId]),
            'member_count': FieldValue.increment(1),
          });
          printVm('✅ [SIGNUP] Auto-join groupe officiel "${groupDoc.data()['name']}" pour $userId');
        } catch (e) {
          printVm('⚠️ [SIGNUP] Échec auto-join groupe ${groupDoc.id} : $e');
        }
      }
    } catch (e) {
      printVm('⚠️ [SIGNUP] Auto-join groupes officiels ignoré : $e');
    }
  }

  // Envoi de notification de parrainage
  Future<void> _sendParrainageNotification(UserData parrain) async {
    await authProvider.sendNotification(
      userIds: [parrain.oneIgnalUserid!],
      smallImage: parrain.imageUrl!,
      send_user_id: authProvider.registerUser.id!,
      recever_user_id: parrain.id!,
      message: "🤑 Vous avez gagné 1 abonné grâce à un parrainage !",
      type_notif: NotificationType.PARRAINAGE.name,
      post_id: "",
      post_type: "",
      chat_id: '',
    );
  }

  // Affichage du succès et navigation
  void _showSuccessAndNavigate() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: _colors.success,
        content: Text(l10n.signupAccountCreatedSuccess, style: TextStyle(color: _colors.onPrimary)),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // Gestion des erreurs
  void _handleAuthError(FirebaseAuthException error) {
    final errorMessages = {
      "invalid-email": l10n.signupErrorInvalidEmail,
      "wrong-password": l10n.signupErrorWrongPassword,
      "email-already-in-use": l10n.signupErrorEmailInUse,
      "user-not-found": l10n.signupErrorUserNotFound,
      "user-disabled": l10n.signupErrorUserDisabled,
      "too-many-requests": l10n.signupErrorTooManyRequests,
      "operation-not-allowed": l10n.signupErrorOperationNotAllowed,
      "weak-password": l10n.signupErrorWeakPassword,
    };

    final errorMessage = errorMessages[error.code] ?? l10n.signupErrorUndefined;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: _colors.danger,
        content: Text(errorMessage, style: TextStyle(color: _colors.onPrimary)),
      ),
    );
  }

  void _handleFirebaseError(FirebaseException error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: _colors.danger,
        content: Text("${l10n.signupErrorFirebase} ${error.message}", style: TextStyle(color: _colors.onPrimary)),
      ),
    );
  }

  void _handleGenericError(dynamic error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: _colors.danger,
        content: Text("${l10n.signupErrorUnexpected} ${error.toString()}", style: TextStyle(color: _colors.onPrimary)),
      ),
    );
  }

  // Widget pour afficher l'image sélectionnée (compatible web et mobile)
  Widget _buildSelectedImage() {
    if (_imageBytes != null) {
      // Pour le web : utiliser Image.memory
      return Image.memory(
        _imageBytes!,
        fit: BoxFit.cover,
      );
    } else if (_imageFile != null) {
      // Pour mobile : utiliser Image.file
      return Image.file(
        _imageFile!,
        fit: BoxFit.cover,
      );
    }
    // Pas d'image sélectionnée : icône par défaut
    return Container(
      color: Colors.grey.shade200,
      child: const Icon(Icons.person, size: 60, color: Colors.grey),
    );
  }

  @override
  Widget build(BuildContext context) {
    _colors = AppColors.of(context);
    l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: _colors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: primaryGreen),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l10n.signupStep2Title,
          style: TextStyle(color: _colors.textPrimary, fontSize: 18),
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              SizedBox(height: 20),

              // Photo de profil
              _buildProfilePhotoSection(),
              SizedBox(height: 30),

              // Formulaire
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Champ adresse
                    _buildTextField(
                      controller: adresseController,
                      hintText: l10n.signupAddress,
                      prefixIcon: Icons.location_on_outlined,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return l10n.signupAddressRequired;
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 20),

                    // Champ à propos
                    _buildAboutSection(),
                    SizedBox(height: 24),

                    // Centres d'intérêt
                    InterestsSelectorWidget(
                      selected: _selectedInterests,
                      onChanged: (codes) => setState(() => _selectedInterests = codes),
                      minRequired: 3,
                    ),
                    SizedBox(height: 20),

                    // Section pays
                    _buildCountrySection(),
                    SizedBox(height: 20),

                    // Texte conditions
                    Text(
                      l10n.signupTermsAcceptance,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: _colors.textSecondary,
                      ),
                    ),
                    SizedBox(height: 30),

                    // Boutons de navigation
                    _buildNavigationButtons(),
                    SizedBox(height: 20),

                    // Lien de connexion
                    _buildLoginLink(),
                    SizedBox(height: 30),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfilePhotoSection() {
    final hasImage = _imageBytes != null || _imageFile != null;

    return Column(
      children: [
        Text(
          l10n.signupProfilePhoto,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: _colors.textPrimary,
          ),
        ),
        SizedBox(height: 15),
        Stack(
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: primaryGreen, width: 3),
              ),
              child: ClipOval(
                child: _buildSelectedImage(),
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: primaryGreen,
                  shape: BoxShape.circle,
                  border: Border.all(color: _colors.background, width: 3),
                ),
                child: IconButton(
                  onPressed: getImage,
                  icon: Icon(Icons.camera_alt, size: 20, color: _colors.onPrimary),
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
          ],
        ),
        if (hasImage) ...[
          SizedBox(height: 8),
          Text(
            l10n.signupImageSelected,
            style: TextStyle(
              color: _colors.success,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAboutSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.signupAboutYou,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: _colors.textPrimary,
          ),
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: _colors.surface,
            borderRadius: BorderRadius.circular(15),
          ),
          child: TextFormField(
            controller: aproposController,
            maxLines: 4,
            style: TextStyle(color: _colors.textPrimary),
            decoration: InputDecoration(
              hintText: l10n.signupAboutYouHint,
              hintStyle: TextStyle(color: _colors.textSecondary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide.none,
              ),
              contentPadding: EdgeInsets.all(16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData prefixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      style: TextStyle(color: _colors.textPrimary),
      decoration: InputDecoration(
        filled: true,
        fillColor: _colors.surface,
        hintText: hintText,
        hintStyle: TextStyle(color: _colors.textSecondary),
        prefixIcon: Icon(prefixIcon, color: primaryGreen),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
        contentPadding: EdgeInsets.symmetric(vertical: 15, horizontal: 20),
      ),
      validator: validator,
    );
  }

  Widget _buildCountrySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.location_on_outlined, color: primaryGreen, size: 20),
            SizedBox(width: 6),
            Text(
              'Où te trouves-tu ?',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _colors.textPrimary,
              ),
            ),
          ],
        ),
        SizedBox(height: 8),

        // Mobile : détection automatique, lecture seule — pas de modification possible
        if (!kIsWeb) ...[
          if (_locationLoading)
            Row(
              children: [
                SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: primaryGreen)),
                SizedBox(width: 8),
                Text('Détection de ta localisation...', style: TextStyle(color: _colors.textSecondary, fontSize: 13)),
              ],
            )
          else if (_locationDetected && _detectedCountryName != null)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: _colors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: primaryGreen.withOpacity(0.5)),
              ),
              child: Row(
                children: [
                  Icon(Icons.my_location, color: primaryGreen, size: 18),
                  SizedBox(width: 10),
                  Text(
                    _detectedCountryName!,
                    style: TextStyle(color: _colors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  SizedBox(width: 6),
                  Icon(Icons.check_circle, color: primaryGreen, size: 16),
                ],
              ),
            )
          else
            Container(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: _colors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.location_off_outlined, color: _colors.textSecondary, size: 18),
                  SizedBox(width: 10),
                  Text('Localisation non disponible', style: TextStyle(color: _colors.textSecondary, fontSize: 13)),
                ],
              ),
            ),
        ],

        // Web : sélecteur manuel pays/région/ville
        if (kIsWeb) _buildCscPicker(),
      ],
    );
  }

  Widget _buildCscPicker() {
    return Container(
      margin: EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: _colors.surface,
        borderRadius: BorderRadius.circular(15),
      ),
      child: CSCPickerPlus(
        showStates: true,
        showCities: true,
        flagState: CountryFlag.SHOW_IN_DROP_DOWN_ONLY,
        defaultCountry: CscCountry.Togo,
        dropdownDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: _colors.surface,
        ),
        disabledDropdownDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: _colors.surface,
        ),
        countrySearchPlaceholder: "Rechercher un pays",
        stateSearchPlaceholder: "Rechercher une région",
        citySearchPlaceholder: "Rechercher une ville",
        countryDropdownLabel: "Sélectionnez un pays",
        stateDropdownLabel: "Sélectionnez une région",
        cityDropdownLabel: "Sélectionnez une ville",
        countryFilter: const [
          CscCountry.Togo, CscCountry.Algeria, CscCountry.Angola, CscCountry.Benin,
          CscCountry.Botswana, CscCountry.Burkina_Faso, CscCountry.Burundi,
          CscCountry.Cameroon, CscCountry.Chad, CscCountry.Comoros, CscCountry.Congo,
          CscCountry.Djibouti, CscCountry.Egypt, CscCountry.Eritrea, CscCountry.Ethiopia,
          CscCountry.Gabon, CscCountry.Gambia_The, CscCountry.Ghana, CscCountry.Guinea,
          CscCountry.Kenya, CscCountry.Lesotho, CscCountry.Liberia, CscCountry.Libya,
          CscCountry.Madagascar, CscCountry.Malawi, CscCountry.Mali, CscCountry.Mauritania,
          CscCountry.Mauritius, CscCountry.Morocco, CscCountry.Mozambique, CscCountry.Namibia,
          CscCountry.Niger, CscCountry.Nigeria, CscCountry.Rwanda, CscCountry.Senegal,
          CscCountry.Seychelles, CscCountry.Sierra_Leone, CscCountry.Somalia,
          CscCountry.South_Africa, CscCountry.Sudan, CscCountry.Tanzania, CscCountry.Tunisia,
          CscCountry.Uganda, CscCountry.Zambia, CscCountry.Zimbabwe,
          CscCountry.France, CscCountry.Germany, CscCountry.Italy, CscCountry.Spain,
          CscCountry.Portugal, CscCountry.Netherlands_The, CscCountry.Belgium,
          CscCountry.Sweden, CscCountry.Switzerland, CscCountry.Norway,
          CscCountry.United_States, CscCountry.Canada, CscCountry.Brazil,
          CscCountry.Argentina, CscCountry.Mexico, CscCountry.Chile,
          CscCountry.Colombia, CscCountry.Peru, CscCountry.Venezuela,
          CscCountry.China, CscCountry.Japan, CscCountry.India,
          CscCountry.Thailand, CscCountry.Vietnam, CscCountry.Malaysia,
          CscCountry.Singapore, CscCountry.Philippines, CscCountry.Indonesia,
        ],
        selectedItemStyle: TextStyle(color: _colors.primary, fontSize: 14),
        dropdownHeadingStyle: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold),
        dropdownItemStyle: TextStyle(color: Colors.black, fontSize: 14),
        dropdownDialogRadius: 14.0,
        searchBarRadius: 10.0,
        onCountryChanged: (value) => setState(() => _countryValue = value),
        onStateChanged: (value) => setState(() => _stateValue = value ?? ''),
        onCityChanged: (value) => setState(() => _cityValue = value ?? ''),
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: tap ? null : () async {
              if (_formKey.currentState!.validate()) {
                await signUp(
                  authProvider.registerUser.email!,
                  authProvider.registerUser.password!,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _colors.primary,
              padding: EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
            child: tap
                ? LoadingAnimationWidget.threeRotatingDots(
              color: _colors.onPrimary,
              size: 24,
            )
                : Text(
              l10n.signupRegister,
              style: TextStyle(
                color: _colors.onPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          l10n.signupAlreadyHaveAccount,
          style: TextStyle(color: _colors.textSecondary),
        ),
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => LoginPageUser()),
            );
          },
          child: Text(
            l10n.signupLoginNow,
            style: TextStyle(
              color: primaryGreen,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

// import 'dart:convert';
// import 'dart:math';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:firebase_storage/firebase_storage.dart';
// import 'package:path/path.dart' as Path;
// import 'package:afrotok/constant/constColors.dart';
// import 'package:afrotok/pages/auth/authTest/Screens/Signup/components/sign_up_top_image.dart';
// import 'package:afrotok/pages/auth/authTest/Screens/Signup/signup_screen.dart';
// import 'package:dropdown_search/dropdown_search.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_vector_icons/flutter_vector_icons.dart';
// import 'package:geocoding/geocoding.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:intl_phone_field/intl_phone_field.dart';
// import 'package:provider/provider.dart';
// import 'package:simple_tags/simple_tags.dart';
// import 'package:loading_animation_widget/loading_animation_widget.dart';
// import '../../../../../../constant/sizeButtons.dart';
// import '../../../../../../models/model_data.dart';
//
// import '../../../../../../providers/authProvider.dart';
//
// import 'dart:async';
// import 'dart:io';
//
// import '../../../../component/consoleWidget.dart';
// import '../../components/already_have_an_account_acheck.dart';
// import '../../constants.dart';
// import '../Login/loginPageUser.dart';
// import '../login.dart';
// import 'components/signup_form.dart';
//
//
// // Couleurs de base
// const Color primaryGreen = Color(0xFF25D366);
// const Color darkBackground = Color(0xFF121212);
// const Color lightBackground = Color(0xFF1E1E1E);
// const Color textColor = Colors.white;
//
// class SignUpFormEtap3 extends StatefulWidget {
//   SignUpFormEtap3({Key? key}) : super(key: key);
//
//   @override
//   State<SignUpFormEtap3> createState() => _SignUpFormEtap3State();
// }
//
// class _SignUpFormEtap3State extends State<SignUpFormEtap3> {
//   late UserAuthProvider authProvider;
//   final TextEditingController adresseController = TextEditingController();
//   final TextEditingController aproposController = TextEditingController();
//   final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
//   final FirebaseFirestore firestore = FirebaseFirestore.instance;
//   late bool tap= false;
//   final _auth = FirebaseAuth.instance;
//   bool adreseLoging = false;
//   bool onTap = false;
//   File? _image;
//   final ImagePicker _picker = ImagePicker();
//
//   String? _currentAddress = '';
//   Position? _currentPosition;
//
//   @override
//   void initState() {
//     super.initState();
//     authProvider = Provider.of<UserAuthProvider>(context, listen: false);
//   }
//
//   // Méthode pour récupérer l'image
//   Future<void> getImage() async {
//     final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
//     if (pickedFile != null) {
//       setState(() {
//         _image = File(pickedFile.path);
//       });
//     }
//   }
//
//   // Méthode pour envoyer l'email de vérification
//   Future<void> sendVerificationEmail(User user) async {
//     try {
//       await user.sendEmailVerification();
//
//       // Afficher le modal de confirmation
//       _showVerificationModal();
//     } catch (e) {
//       printVm("Erreur lors de l'envoi de l'email de vérification: $e");
//     }
//   }
//
// // Modal de création et vérification d'email
//   void _showVerificationModal() {
//     showResponsiveBottomSheet(
//       context: context,
//       isScrollControlled: true,
//       backgroundColor: Colors.transparent,
//       builder: (context) => Container(
//         height: MediaQuery.of(context).size.height * 0.8,
//         decoration: BoxDecoration(
//           color: darkBackground,
//           borderRadius: BorderRadius.only(
//             topLeft: Radius.circular(25),
//             topRight: Radius.circular(25),
//           ),
//         ),
//         child: Padding(
//           padding: const EdgeInsets.all(20.0),
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               Icon(
//                 Icons.check_circle_outline,
//                 size: 80,
//                 color: Colors.greenAccent, // succès création
//               ),
//               SizedBox(height: 20),
//               Text(
//                 'Compte créé avec succès !',
//                 style: TextStyle(
//                   fontSize: 24,
//                   fontWeight: FontWeight.bold,
//                   color: Colors.greenAccent,
//                 ),
//               ),
//               SizedBox(height: 15),
//               Icon(
//                 Icons.mark_email_read_outlined,
//                 size: 50,
//                 color: Colors.orangeAccent, // attention vérif
//               ),
//               SizedBox(height: 10),
//               Text(
//                 'Il reste une étape : vérification de votre email',
//                 textAlign: TextAlign.center,
//                 style: TextStyle(
//                   fontSize: 18,
//                   fontWeight: FontWeight.bold,
//                   color: Colors.orangeAccent,
//                 ),
//               ),
//               SizedBox(height: 10),
//               Text(
//                 'Un email de vérification a été envoyé à :',
//                 textAlign: TextAlign.center,
//                 style: TextStyle(
//                   fontSize: 16,
//                   color: Colors.grey[400],
//                 ),
//               ),
//               SizedBox(height: 5),
//               Text(
//                 authProvider.registerUser.email!,
//                 textAlign: TextAlign.center,
//                 style: TextStyle(
//                   fontSize: 16,
//                   fontWeight: FontWeight.bold,
//                   color: Colors.orangeAccent,
//                 ),
//               ),
//               SizedBox(height: 20),
//               Text(
//                 'Veuillez vérifier votre adresse email avant de vous connecter.\n'
//                     'Si vous ne voyez pas l’email dans votre boîte principale, pensez à vérifier votre dossier Spam ou Courrier indésirable.',
//                 textAlign: TextAlign.center,
//                 style: TextStyle(
//                   fontSize: 14,
//                   color: Colors.grey[400],
//                 ),
//               ),
//               SizedBox(height: 30),
//               Container(
//                 width: double.infinity,
//                 height: 50,
//                 child: ElevatedButton(
//                   onPressed: () {
//                     Navigator.pop(context);
//                     Navigator.pushReplacementNamed(
//                         context, "/login");
//                     // Navigator.pushNamed(context, '/bon_a_savoir');
//                   },
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: primaryGreen,
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(25),
//                     ),
//                   ),
//                   child: Text(
//                     'J\'ai compris',
//                     style: TextStyle(
//                       fontSize: 16,
//                       fontWeight: FontWeight.bold,
//                       color: Colors.white,
//                     ),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   Future<UserData?> verifierParrain(String codeParrain) async {
//
//
//     // Récupérer la liste des utilisateurs
//     CollectionReference appdatacollection = firestore.collection('Appdata');
//     CollectionReference users = firestore.collection("Users");
//     QuerySnapshot snapshot = await users
//         .where(
//         "code_parrainage", isEqualTo: codeParrain)
//         .get();
//     final list = snapshot.docs.map((doc) =>
//         UserData.fromJson(doc.data() as Map<String, dynamic>)).toList();
//     bool existe= list.any((e) => e.codeParrainage==codeParrain);
//     // Vérifier si le nom existe déjà
//     //  bool existe = snapshot.docs.any((doc) => doc.data["nom"] == nom);
//
//
//
//     if (list.isNotEmpty) {
//       printVm("user trouver");
//       addPointsForOtherUserAction(list.first.id!, UserAction.autre);
//
//       //
//       //     user.pointContribution=list.first.pointContribution! + authProvider.appDefaultData.default_point_new_user!;
//       //     // list.first.votre_solde=list.first.votre_solde! + 5.1;
//       //     // list.first.publi_cash=list.first.publi_cash! + 5.1;
//       //     list.first.usersParrainer!.add(authProvider.registerUser.id!);
//       //    await authProvider.ajouterAuSolde(list.first.id!,5.1).then((value) async {
//       //
//       //
//       //
//       //
//       //
//       //
//       //     });
//       //
//       // await authProvider.updateUser(list.first).then((value) async { });
//       //     // await firestore.collection('Users').doc(list.first.id!).update(list.first.toJson());
//
//
//
//       return list.first;
//
//     }else{
//       printVm("user non trouver^^^^^^^^^^^^^^^^^^^^");
//       return null;
//
//     }
//   }
//   // Méthode d'inscription principale
//   Future<void> signUp(String email, String password) async {
//
//     if (!_formKey.currentState!.validate()) return;
//
//
//
//     // Vérification de l'image
//     if (_image == null) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           backgroundColor: Colors.orange,
//           content: Text('Veuillez sélectionner une photo de profil', style: TextStyle(color: Colors.white)),
//         ),
//       );
//       return;
//     }
//
//     // Vérification de la taille de l'image (max 5MB)
//     final imageSize = await _image!.length();
//     if (imageSize > 5 * 1024 * 1024) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           backgroundColor: Colors.orange,
//           content: Text('L\'image est trop volumineuse (max 5MB)', style: TextStyle(color: Colors.white)),
//         ),
//       );
//       return;
//     }
//
//     setState(() => tap = true);
//
//     try {
//       // Configuration des données utilisateur
//       authProvider.registerUser
//         ..role = UserRole.USER.name!
//         ..updatedAt = DateTime.now().microsecondsSinceEpoch
//         ..createdAt = DateTime.now().microsecondsSinceEpoch;
//
//       // Upload de l'image
//       String imageUrl = await _uploadImage(_image!);
//       authProvider.registerUser.imageUrl = imageUrl;
//
//       // Configuration des autres données
//       authProvider.registerUser.adresse = adresseController.text;
//       authProvider.registerUser.apropos = aproposController.text;
//       authProvider.registerUser.votre_solde = 0.0;
//
//       UserPseudo pseudo = UserPseudo();
//       String id = "";
//       NotificationData notif = NotificationData();
//
//       // Gestion du parrainage
//       if (authProvider.registerUser.codeParrain!.isNotEmpty) {
//         final UserData? parrain = await verifierParrain(authProvider.registerUser.codeParrain!);
//
//         if (parrain != null) {
//
//
//           // Création du compte avec parrainage
//           final UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
//             email: email,
//             password: password,
//           );
//
//           id = userCredential.user!.uid;
//
//           // Configuration des données
//           await _configureUserDataWithParrainage(id, pseudo, parrain);
//
//           // Envoi de la notification de parrainage
//           await _sendParrainageNotification(parrain, notif);
//
//           // Envoi de l'email de vérification
//           await sendVerificationEmail(userCredential.user!);
//
//           // Affichage du succès
//           _showSuccessAndNavigate();
//
//         } else {
//           // Code de parrainage invalide
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//               backgroundColor: Colors.red,
//               content: Text('Le code de parrainage est erroné !', style: TextStyle(color: Colors.white)),
//             ),
//           );
//           setState(() => tap = false);
//           return;
//         }
//       } else {
//         // Création du compte sans parrainage
//         final UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
//           email: email,
//           password: password,
//         );
//
//         id = userCredential.user!.uid;
//
//         // Configuration des données
//         await _configureUserDataWithoutParrainage(id, pseudo);
//
//         // Envoi de l'email de vérification
//         await sendVerificationEmail(userCredential.user!);
//
//         // Affichage du succès
//         _showSuccessAndNavigate();
//       }
//
//     } on FirebaseAuthException catch (error) {
//       _handleAuthError(error);
//     } on FirebaseException catch (error) {
//       _handleFirebaseError(error);
//     } catch (error) {
//       _handleGenericError(error);
//     } finally {
//       setState(() => tap = false);
//     }
//   }
//
//   // Configuration des données avec parrainage
//   Future<void> _configureUserDataWithParrainage(String id, UserPseudo pseudo, UserData parrain) async {
//     pseudo.id = firestore.collection('Pseudo').doc().id;
//     pseudo.name = authProvider.registerUser.pseudo;
//     authProvider.registerUser.id = id;
//
//     await authProvider.getAppData();
//
//     // Configuration de l'utilisateur
//     authProvider.registerUser.pointContribution = authProvider.appDefaultData.default_point_new_user!;
//     authProvider.registerUser.votre_solde = 5.1;
//     authProvider.registerUser.publi_cash = 5.1;
//
//     // Mise à jour du parrain
//     final usersRef = firestore.collection('Users');
//     final parrainRef = usersRef.doc(parrain.id!);
//
// // Mise à jour directe des champs
//     await parrainRef.update({
//       'pointContribution': (parrain.pointContribution ?? 0) + authProvider.appDefaultData.default_point_new_user!,
//       'votre_solde': (parrain.votre_solde ?? 0.0) + 5.1,
//       'publi_cash': (parrain.publi_cash ?? 0.0) + 5.1,
//       'usersParrainer': FieldValue.arrayUnion([id]), // ajoute le nouvel utilisateur dans la liste
//       'userAbonnesIds': FieldValue.arrayUnion([id]), // ajoute le nouvel abonné
//     });
//
//     // Batch operations
//     final batch = firestore.batch();
//     batch.set(firestore.collection('Users').doc(id), authProvider.registerUser.toJson());
//     batch.set(firestore.collection('Pseudo').doc(pseudo.id), pseudo.toJson());
//
//     // Mise à jour des statistiques globales
//     authProvider.appDefaultData.nbr_abonnes = (authProvider.appDefaultData.nbr_abonnes ?? 0) + 1;
//     if (!authProvider.appDefaultData.users_id!.contains(id)) {
//       authProvider.appDefaultData.users_id!.add(id);
//     }
//     batch.update(firestore.collection('AppData').doc(authProvider.appDefaultData.id!), {
//       'nbr_abonnes': authProvider.appDefaultData.nbr_abonnes,
//       'users_id': authProvider.appDefaultData.users_id,
//     });
//
//     await batch.commit();
//   }
//
// // Configuration des données sans parrainage
//   Future<void> _configureUserDataWithoutParrainage(String id, UserPseudo pseudo) async {
//     pseudo.id = firestore.collection('Pseudo').doc().id;
//     pseudo.name = authProvider.registerUser.pseudo;
//     authProvider.registerUser.id = id;
//
//     await authProvider.getAppData();
//
//     // Configuration de l'utilisateur
//     authProvider.registerUser.pointContribution = authProvider.appDefaultData.default_point_new_user!;
//     authProvider.registerUser.votre_solde = 0.0;
//     authProvider.registerUser.publi_cash = 0.0;
//
//     // Batch operations
//     final batch = firestore.batch();
//     batch.set(firestore.collection('Users').doc(id), authProvider.registerUser.toJson());
//     batch.set(firestore.collection('Pseudo').doc(pseudo.id), pseudo.toJson());
//
//     // Mise à jour des statistiques globales
//     authProvider.appDefaultData.nbr_abonnes = (authProvider.appDefaultData.nbr_abonnes ?? 0) + 1;
//     if (!authProvider.appDefaultData.users_id!.contains(id)) {
//       authProvider.appDefaultData.users_id!.add(id);
//     }
//     batch.update(firestore.collection('AppData').doc(authProvider.appDefaultData.id!), {
//       'nbr_abonnes': authProvider.appDefaultData.nbr_abonnes,
//       'users_id': authProvider.appDefaultData.users_id,
//     });
//
//     await batch.commit();
//   }
//
// // Envoi de notification de parrainage
//   Future<void> _sendParrainageNotification(UserData parrain, NotificationData notif) async {
//     // notif.id = firestore.collection('Notifications').doc().id;
//     // notif.titre = "Parrainage 🤑";
//     // notif.media_url = parrain.imageUrl;
//     // notif.type = NotificationType.PARRAINAGE.name;
//     // notif.description = "Vous avez gagné 1 PubliCash grâce à un parrainage !";
//     // notif.user_id = authProvider.registerUser.id;
//     // notif.receiver_id = parrain.id!;
//     // notif.updatedAt = DateTime.now().microsecondsSinceEpoch;
//     // notif.createdAt = DateTime.now().microsecondsSinceEpoch;
//     // notif.status = PostStatus.VALIDE.name;
//     //
//     // await firestore.collection('Notifications').doc(notif.id).set(notif.toJson());
//
//     await authProvider.sendNotification(
//         userIds: [parrain.oneIgnalUserid!],
//         smallImage: parrain.imageUrl!,
//         send_user_id: authProvider.registerUser.id!,
//         recever_user_id: parrain.id!,
//         message: "🤑 Vous avez gagné 1 abonné grâce à un parrainage !",
//         type_notif: NotificationType.PARRAINAGE.name,
//         post_id: "",
//         post_type: "",
//         chat_id: ''
//     );
//   }
//
// // Méthode pour uploader l'image
//   Future<String> _uploadImage(File image) async {
//     try {
//       Reference storageReference = FirebaseStorage.instance
//           .ref()
//           .child('user_profile/${Path.basename(image.path)}_${DateTime.now().millisecondsSinceEpoch}');
//
//       UploadTask uploadTask = storageReference.putFile(image);
//       TaskSnapshot snapshot = await uploadTask;
//
//       return await snapshot.ref.getDownloadURL();
//     } catch (e) {
//       printVm("Erreur lors de l'upload de l'image: $e");
//       throw Exception("Échec de l'upload de l'image");
//     }
//   }
//
//
//
//
//
// // Affichage du succès et navigation
//   void _showSuccessAndNavigate() {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         backgroundColor: Colors.green,
//         content: Text('Compte créé avec succès !', style: TextStyle(color: Colors.white)),
//         duration: Duration(seconds: 2),
//       ),
//     );
//   }
//
// // Gestion des erreurs
//   void _handleAuthError(FirebaseAuthException error) {
//     final errorMessages = {
//       "invalid-email": "Votre email semble être malformé.",
//       "wrong-password": "Votre mot de passe est erroné.",
//       "email-already-in-use": "L'email est déjà utilisé par un autre compte.",
//       "user-not-found": "L'utilisateur avec cet email n'existe pas.",
//       "user-disabled": "L'utilisateur avec cet email a été désactivé.",
//       "too-many-requests": "Trop de demandes.",
//       "operation-not-allowed": "La connexion avec l'email et un mot de passe n'est pas activée.",
//       "weak-password": "Le mot de passe est trop faible.",
//     };
//
//     final errorMessage = errorMessages[error.code] ?? "Une erreur indéfinie s'est produite";
//
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         backgroundColor: Colors.red,
//         content: Text(errorMessage, style: TextStyle(color: Colors.white)),
//       ),
//     );
//   }
//
//   void _handleFirebaseError(FirebaseException error) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         backgroundColor: Colors.red,
//         content: Text("Erreur Firebase: ${error.message}", style: TextStyle(color: Colors.white)),
//       ),
//     );
//   }
//
//   void _handleGenericError(dynamic error) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         backgroundColor: Colors.red,
//         content: Text("Erreur inattendue: ${error.toString()}", style: TextStyle(color: Colors.white)),
//       ),
//     );
//   }
//
//
//   // Gestion des erreurs
//   void _handleError(dynamic error) {
//     String errorMessage = "Une erreur s'est produite lors de la création du compte";
//
//     if (error is FirebaseAuthException) {
//       switch (error.code) {
//         case "email-already-in-use":
//           errorMessage = "L'email est déjà utilisé par un autre compte.";
//           break;
//         case "invalid-email":
//           errorMessage = "Votre email semble être malformé.";
//           break;
//         case "weak-password":
//           errorMessage = "Le mot de passe est trop faible.";
//           break;
//         default:
//           errorMessage = error.message ?? "Erreur d'authentification";
//       }
//     }
//
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         backgroundColor: Colors.red,
//         content: Text(errorMessage, style: TextStyle(color: Colors.white)),
//       ),
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: darkBackground,
//       appBar: AppBar(
//         backgroundColor: Colors.transparent,
//         elevation: 0,
//         leading: IconButton(
//           icon: Icon(Icons.arrow_back, color: primaryGreen),
//           onPressed: () => Navigator.pop(context),
//         ),
//         title: Text(
//           "Finalisation du profil",
//           style: TextStyle(color: textColor, fontSize: 18),
//         ),
//       ),
//       body: GestureDetector(
//         onTap: () => FocusScope.of(context).unfocus(),
//         child: SingleChildScrollView(
//           padding: EdgeInsets.symmetric(horizontal: 20),
//           child: Column(
//             children: [
//               SizedBox(height: 20),
//
//               // Photo de profil
//               _buildProfilePhotoSection(),
//               SizedBox(height: 30),
//
//               // Formulaire
//               Form(
//                 key: _formKey,
//                 child: Column(
//                   children: [
//                     // Champ adresse
//                     _buildTextField(
//                       controller: adresseController,
//                       hintText: "Adresse",
//                       prefixIcon: Icons.location_on_outlined,
//                       validator: (value) {
//                         if (value == null || value.isEmpty) {
//                           return 'Ce champ est obligatoire';
//                         }
//                         return null;
//                       },
//                     ),
//                     SizedBox(height: 20),
//
//                     // Champ à propos
//                     _buildAboutSection(),
//                     SizedBox(height: 20),
//
//                     // Texte conditions
//                     Text(
//                       'En créant ce compte, vous acceptez les termes et conditions.',
//                       textAlign: TextAlign.center,
//                       style: TextStyle(
//                         fontSize: 14,
//                         color: Colors.grey[400],
//                       ),
//                     ),
//                     SizedBox(height: 30),
//
//                     // Boutons de navigation
//                     _buildNavigationButtons(),
//                     SizedBox(height: 20),
//
//                     // Lien de connexion
//                     _buildLoginLink(),
//                     SizedBox(height: 30),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildProfilePhotoSection() {
//     return Column(
//       children: [
//         Text(
//           "Votre photo de profil",
//           style: TextStyle(
//             fontSize: 18,
//             fontWeight: FontWeight.bold,
//             color: textColor,
//           ),
//         ),
//         SizedBox(height: 15),
//         Stack(
//           children: [
//             Container(
//               width: 120,
//               height: 120,
//               decoration: BoxDecoration(
//                 shape: BoxShape.circle,
//                 border: Border.all(color: primaryGreen, width: 3),
//               ),
//               child: ClipOval(
//                 child: _image == null
//                     ? Image.asset(
//                   'assets/icon/user-removebg-preview.png',
//                   fit: BoxFit.cover,
//                 )
//                     : Image.file(
//                   _image!,
//                   fit: BoxFit.cover,
//                 ),
//               ),
//             ),
//             Positioned(
//               bottom: 0,
//               right: 0,
//               child: Container(
//                 width: 40,
//                 height: 40,
//                 decoration: BoxDecoration(
//                   color: primaryGreen,
//                   shape: BoxShape.circle,
//                   border: Border.all(color: darkBackground, width: 3),
//                 ),
//                 child: IconButton(
//                   onPressed: getImage,
//                   icon: Icon(Icons.camera_alt, size: 20, color: Colors.white),
//                   padding: EdgeInsets.zero,
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ],
//     );
//   }
//
//   Widget _buildAboutSection() {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           'À propos de vous',
//           style: TextStyle(
//             fontSize: 16,
//             fontWeight: FontWeight.bold,
//             color: textColor,
//           ),
//         ),
//         SizedBox(height: 8),
//         Container(
//           decoration: BoxDecoration(
//             color: lightBackground,
//             borderRadius: BorderRadius.circular(15),
//           ),
//           child: TextFormField(
//             controller: aproposController,
//             maxLines: 4,
//             style: TextStyle(color: textColor),
//             decoration: InputDecoration(
//               hintText: 'Décrivez-vous en quelques mots...',
//               hintStyle: TextStyle(color: Colors.grey[500]),
//               border: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(15),
//                 borderSide: BorderSide.none,
//               ),
//               contentPadding: EdgeInsets.all(16),
//             ),
//           ),
//         ),
//       ],
//     );
//   }
//
//   Widget _buildTextField({
//     required TextEditingController controller,
//     required String hintText,
//     required IconData prefixIcon,
//     String? Function(String?)? validator,
//   }) {
//     return TextFormField(
//       controller: controller,
//       style: TextStyle(color: textColor),
//       decoration: InputDecoration(
//         filled: true,
//         fillColor: lightBackground,
//         hintText: hintText,
//         hintStyle: TextStyle(color: Colors.grey[500]),
//         prefixIcon: Icon(prefixIcon, color: primaryGreen),
//         border: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(15),
//           borderSide: BorderSide.none,
//         ),
//         contentPadding: EdgeInsets.symmetric(vertical: 15, horizontal: 20),
//       ),
//       validator: validator,
//     );
//   }
//
//   Widget _buildNavigationButtons() {
//     return Row(
//       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//       children: [
//         // Expanded(
//         //   child: OutlinedButton(
//         //     onPressed: () => Navigator.pop(context),
//         //     style: OutlinedButton.styleFrom(
//         //       padding: EdgeInsets.symmetric(vertical: 15),
//         //       shape: RoundedRectangleBorder(
//         //         borderRadius: BorderRadius.circular(25),
//         //       ),
//         //       side: BorderSide(color: Colors.red),
//         //     ),
//         //     child: Row(
//         //       mainAxisAlignment: MainAxisAlignment.center,
//         //       children: [
//         //         Icon(Icons.arrow_back, color: Colors.red, size: 20),
//         //         SizedBox(width: 8),
//         //         Text(
//         //           "Précédent",
//         //           style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
//         //         ),
//         //       ],
//         //     ),
//         //   ),
//         // ),
//         // SizedBox(width: 15),
//         Expanded(
//           child: ElevatedButton(
//             onPressed: tap ? null : () async {
//
//               if (_formKey.currentState!.validate()) {
//                 await signUp(
//                   authProvider.registerUser.email!,
//                   authProvider.registerUser.password!,
//                 );
//               }
//             },
//             style: ElevatedButton.styleFrom(
//               backgroundColor: primaryGreen,
//               padding: EdgeInsets.symmetric(vertical: 15),
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(25),
//               ),
//             ),
//             child: tap
//                 ? LoadingAnimationWidget.threeRotatingDots(
//               color: Colors.white,
//               size: 24,
//             )
//                 : Text(
//               "S'inscrire",
//               style: TextStyle(
//                 color: Colors.white,
//                 fontWeight: FontWeight.bold,
//                 fontSize: 16,
//               ),
//             ),
//           ),
//         ),
//       ],
//     );
//   }
//
//   Widget _buildLoginLink() {
//     return Row(
//       mainAxisAlignment: MainAxisAlignment.center,
//       children: [
//         Text(
//           "Vous avez déjà un compte? ",
//           style: TextStyle(color: Colors.grey[500]),
//         ),
//         GestureDetector(
//           onTap: () {
//             Navigator.push(
//               context,
//               MaterialPageRoute(builder: (context) => LoginPageUser()),
//             );
//           },
//           child: Text(
//             "Connectez-vous",
//             style: TextStyle(
//               color: primaryGreen,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//         ),
//       ],
//     );
//   }
//
//   // Les méthodes _handleParrainage et _createUserData restent similaires à votre code original
//   // mais adaptées pour le nouveau design
//   Future<void> _handleParrainage(String userId) async {
//     // Implémentation similaire à votre code original
//   }
//
//   Future<void> _createUserData(String userId) async {
//     // Implémentation similaire à votre code original
//   }
// }