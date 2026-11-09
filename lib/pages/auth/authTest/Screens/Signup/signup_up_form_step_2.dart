import '../../../../../services/media_shrink.dart';
import 'package:afrotok/widgets/language_selector.dart';
import 'package:afrotok/services/auth/google_auth_service.dart';
import 'package:afrotok/services/sessions/session_service.dart';
import 'package:afrotok/pages/splashChargement.dart';
import 'package:afrotok/services/auth/auth_email_service.dart';
import 'package:afrotok/utils/responsive_sheet.dart';

import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path/path.dart' as Path;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:afrolook_api_client/afrolook_api_client.dart' show ApiException;
import 'package:afrotok/services/api/users_api.dart';
import 'package:afrotok/services/api/compte_api.dart';
import 'package:afrotok/services/api/argent_upload.dart';
import 'package:afrotok/widgets/location_picker.dart';
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
  /// Compte déjà connecté avec Google (sans profil Afrolook) : on réutilise ce compte, sans mot de passe ni e-mail à valider.
  final User? googleUser;
  SignUpFormEtap3({Key? key, this.googleUser}) : super(key: key);

  @override
  State<SignUpFormEtap3> createState() => _SignUpFormEtap3State();
}

class _SignUpFormEtap3State extends State<SignUpFormEtap3> {
  bool get _google => widget.googleUser != null;
  late AppColors _colors;
  late AppLocalizations l10n;
  late UserAuthProvider authProvider;
  final TextEditingController adresseController = TextEditingController();
  final TextEditingController aproposController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
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
      await AuthEmailService.sendVerification(user);
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

  /// Crée le compte Firebase (ou reprend le compte Google déjà connecté). Le profil est créé ensuite par l'API.
  Future<User> _createAccount(String email, String password) async {
    if (_google) {
      // Compte Google : déjà créé et connecté, on ne crée rien.
      final current = _auth.currentUser;
      if (current == null) throw FirebaseAuthException(code: 'requires-recent-login');
      return current;
    }
    return (await _auth.createUserWithEmailAndPassword(email: email, password: password)).user!;
  }

  /// Annule une inscription inachevée : supprime le compte Firebase pour que la personne puisse réessayer avec le même e-mail.
  Future<void> _rollbackAccount(User user) async {
    if (_google) return; // compte Google : il reste connecté pour réessayer
    try {
      await user.delete();
    } catch (e) {
      printVm("Suppression du compte inachevé impossible : $e");
    }
  }

  /// Envoie la photo de profil au stockage (URL signée demandée à l'API) et renvoie l'identifiant d'envoi.
  Future<String> _uploadImage() async {
    try {
      if (_imageBytes == null && _imageFile == null) {
        throw Exception("Aucune image sélectionnée");
      }
      final Uint8List raw = kIsWeb ? _imageBytes! : await _imageFile!.readAsBytes();
      final bytes = await MediaShrink.bytes(raw);
      return await ArgentUpload.bytes(bytes, contentType: 'image/jpeg');
    } catch (e) {
      printVm("Erreur lors de l'upload de l'image: $e");
      throw Exception("Échec de l'upload de l'image");
    }
  }

  /// Création du profil par l'API (POST /me/register) puis remplissage : photo, centres d'intérêt, ville, genre, bio.
  /// Un échec de la création annule le compte Firebase tout juste créé (voir [signUp]) ; les compléments sont non bloquants.
  Future<void> _registerProfile(User user) async {
    final u = authProvider.registerUser;
    _applyCountryToUser();
    final cc = (u.countryData?['countryCode'] ?? '').toString();
    final name = '${u.prenom ?? ''} ${u.nom ?? ''}'.trim();
    await CompteApi.register(
      username: u.pseudo ?? '',
      displayName: name.isNotEmpty ? name : null,
      countryCode: cc.length == 2 ? cc.toUpperCase() : null,
      language: Localizations.localeOf(context).languageCode,
      referralCode: (u.codeParrain ?? '').trim().isEmpty ? null : u.codeParrain!.trim(),
    );
    final gender = switch ((u.genre ?? '').toLowerCase()) {
      'homme' || 'male' => 'male',
      'femme' || 'female' => 'female',
      _ => null,
    };
    final city = (u.countryData?['city'] ?? '').toString();
    final fields = <String, dynamic>{
      if ((u.apropos ?? '').trim().isNotEmpty) 'bio': u.apropos!.trim(),
      if (gender != null) 'gender': gender,
      if (city.isNotEmpty) 'city': city,
      if ((u.numeroDeTelephone ?? '').trim().isNotEmpty) 'phone': u.numeroDeTelephone!.trim(),
    };
    try {
      if (fields.isNotEmpty) await UsersApi.updateMe(fields);
      await UsersApi.updateInterests(_selectedInterests);
    } catch (e) {
      printVm("Compléments du profil non enregistrés : $e");
    }
    try {
      // La photo est envoyée après la création du profil (l'API refuse tout avant). Route d'association à ouvrir : voir lacunes.
      final uploadId = await _uploadImage();
      await UsersApi.updateMe({'avatar_upload_id': uploadId});
    } catch (e) {
      printVm("Photo de profil non enregistrée : $e");
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

      // Configuration des autres données
      authProvider.registerUser.adresse = adresseController.text;
      authProvider.registerUser.apropos = aproposController.text;
      authProvider.registerUser.votre_solde = 0.0;
      authProvider.registerUser.interests = List.from(_selectedInterests);

      // Compte Firebase, puis profil créé par l'API (le code de parrainage est vérifié et appliqué par le serveur).
      final User newUser = await _createAccount(email, password);
      authProvider.registerUser.id = newUser.uid;
      try {
        await _registerProfile(newUser);
      } on ApiException catch (e) {
        // Pseudo pris, code refusé, réseau coupé… : on annule le compte tout juste créé pour permettre un nouvel essai.
        await _rollbackAccount(newUser);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: _colors.danger,
            content: Text(UsersApi.message(e), style: TextStyle(color: _colors.onPrimary)),
          ),
        );
        setState(() => tap = false);
        return;
      }
      await _afterAccountCreated(newUser);

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

  /// Fin de l'inscription : compte Google → entrée directe dans l'application ; sinon e-mail de validation.
  Future<void> _afterAccountCreated(User user) async {
    if (_google) {
      _showSuccessAndNavigate();
      await SessionUserFirebaseService.saveUserSession(user.uid);
      await SessionUserFirebaseService.updateLastActive();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const SplashChargement()), (r) => false);
      return;
    }
    // Envoi de l'email de vérification
    await sendVerificationEmail(user);
    // Affichage du succès
    _showSuccessAndNavigate();
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

  Future<void> _leave() async {
    if (_google) await GoogleAuthService.abandon();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    _colors = AppColors.of(context);
    l10n = AppLocalizations.of(context);
    return PopScope(
      canPop: !_google,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: _buildScaffold(context),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    return Scaffold(
      backgroundColor: _colors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: primaryGreen),
          onPressed: _leave,
        ),
        title: Text(
          l10n.signupStep2Title,
          style: TextStyle(color: _colors.textPrimary, fontSize: 18),
        ),
        actions: const [Padding(padding: EdgeInsets.only(right: 12), child: Center(child: LanguageSelectorButton()))],
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
      child: LocationPicker(
        initialCountry: 'Togo',
        countryFilter: const ['Togo', 'Algeria', 'Angola', 'Benin', 'Botswana', 'Burkina Faso', 'Burundi', 'Cameroon', 'Chad', 'Comoros', 'Congo', 'Djibouti', 'Egypt', 'Eritrea', 'Ethiopia', 'Gabon', 'Gambia The', 'Ghana', 'Guinea', 'Kenya', 'Lesotho', 'Liberia', 'Libya', 'Madagascar', 'Malawi', 'Mali', 'Mauritania', 'Mauritius', 'Morocco', 'Mozambique', 'Namibia', 'Niger', 'Nigeria', 'Rwanda', 'Senegal', 'Seychelles', 'Sierra Leone', 'Somalia', 'South Africa', 'Sudan', 'Tanzania', 'Tunisia', 'Uganda', 'Zambia', 'Zimbabwe', 'France', 'Germany', 'Italy', 'Spain', 'Portugal', 'Netherlands The', 'Belgium', 'Sweden', 'Switzerland', 'Norway', 'United States', 'Canada', 'Brazil', 'Argentina', 'Mexico', 'Chile', 'Colombia', 'Peru', 'Venezuela', 'China', 'Japan', 'India', 'Thailand', 'Vietnam', 'Malaysia', 'Singapore', 'Philippines', 'Indonesia'],
        fillColor: _colors.surface,
        textColor: _colors.textPrimary,
        hintColor: _colors.textSecondary,
        onCountryChanged: (value) => setState(() => _countryValue = value),
        onStateChanged: (value) => setState(() => _stateValue = value),
        onCityChanged: (value) => setState(() => _cityValue = value),
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
