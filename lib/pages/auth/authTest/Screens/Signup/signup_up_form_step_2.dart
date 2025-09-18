



import 'dart:convert';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as Path;
import 'package:afrotok/constant/constColors.dart';
import 'package:afrotok/pages/auth/authTest/Screens/Signup/components/sign_up_top_image.dart';
import 'package:afrotok/pages/auth/authTest/Screens/Signup/signup_screen.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:geocoding/geocoding.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:provider/provider.dart';
import 'package:simple_tags/simple_tags.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import '../../../../../../constant/sizeButtons.dart';
import '../../../../../../models/model_data.dart';

import '../../../../../../providers/authProvider.dart';

import 'dart:async';
import 'dart:io';

import '../../../../component/consoleWidget.dart';
import '../../components/already_have_an_account_acheck.dart';
import '../../constants.dart';
import '../Login/loginPageUser.dart';
import '../login.dart';
import 'components/signup_form.dart';


// Couleurs de base
const Color primaryGreen = Color(0xFF25D366);
const Color darkBackground = Color(0xFF121212);
const Color lightBackground = Color(0xFF1E1E1E);
const Color textColor = Colors.white;

class SignUpFormEtap3 extends StatefulWidget {
  SignUpFormEtap3({Key? key}) : super(key: key);

  @override
  State<SignUpFormEtap3> createState() => _SignUpFormEtap3State();
}

class _SignUpFormEtap3State extends State<SignUpFormEtap3> {
  late UserAuthProvider authProvider;
  final TextEditingController adresseController = TextEditingController();
  final TextEditingController aproposController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  late bool tap= false;
  final _auth = FirebaseAuth.instance;
  bool adreseLoging = false;
  bool onTap = false;
  File? _image;
  final ImagePicker _picker = ImagePicker();

  String? _currentAddress = '';
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    authProvider = Provider.of<UserAuthProvider>(context, listen: false);
  }

  // Méthode pour récupérer l'image
  Future<void> getImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  // Méthode pour envoyer l'email de vérification
  Future<void> sendVerificationEmail(User user) async {
    try {
      await user.sendEmailVerification();

      // Afficher le modal de confirmation
      _showVerificationModal();
    } catch (e) {
      print("Erreur lors de l'envoi de l'email de vérification: $e");
    }
  }

// Modal de création et vérification d'email
  void _showVerificationModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: darkBackground,
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
                color: Colors.greenAccent, // succès création
              ),
              SizedBox(height: 20),
              Text(
                'Compte créé avec succès !',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.greenAccent,
                ),
              ),
              SizedBox(height: 15),
              Icon(
                Icons.mark_email_read_outlined,
                size: 50,
                color: Colors.orangeAccent, // attention vérif
              ),
              SizedBox(height: 10),
              Text(
                'Il reste une étape : vérification de votre email',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.orangeAccent,
                ),
              ),
              SizedBox(height: 10),
              Text(
                'Un email de vérification a été envoyé à :',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[400],
                ),
              ),
              SizedBox(height: 5),
              Text(
                authProvider.registerUser.email!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.orangeAccent,
                ),
              ),
              SizedBox(height: 20),
              Text(
                'Veuillez vérifier votre adresse email avant de vous connecter.\n'
                    'Si vous ne voyez pas l’email dans votre boîte principale, pensez à vérifier votre dossier Spam ou Courrier indésirable.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[400],
                ),
              ),
              SizedBox(height: 30),
              Container(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pushReplacementNamed(
                        context, "/login");
                    // Navigator.pushNamed(context, '/bon_a_savoir');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: Text(
                    'J\'ai compris',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
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


    // Récupérer la liste des utilisateurs
    CollectionReference appdatacollection = firestore.collection('Appdata');
    CollectionReference users = firestore.collection("Users");
    QuerySnapshot snapshot = await users
        .where(
        "code_parrainage", isEqualTo: codeParrain)
        .get();
    final list = snapshot.docs.map((doc) =>
        UserData.fromJson(doc.data() as Map<String, dynamic>)).toList();
    bool existe= list.any((e) => e.codeParrainage==codeParrain);
    // Vérifier si le nom existe déjà
    //  bool existe = snapshot.docs.any((doc) => doc.data["nom"] == nom);



    if (list.isNotEmpty) {
      printVm("user trouver");

      //
      //     user.pointContribution=list.first.pointContribution! + authProvider.appDefaultData.default_point_new_user!;
      //     // list.first.votre_solde=list.first.votre_solde! + 5.1;
      //     // list.first.publi_cash=list.first.publi_cash! + 5.1;
      //     list.first.usersParrainer!.add(authProvider.registerUser.id!);
      //    await authProvider.ajouterAuSolde(list.first.id!,5.1).then((value) async {
      //
      //
      //
      //
      //
      //
      //     });
      //
      // await authProvider.updateUser(list.first).then((value) async { });
      //     // await firestore.collection('Users').doc(list.first.id!).update(list.first.toJson());



      return list.first;

    }else{
      printVm("user non trouver^^^^^^^^^^^^^^^^^^^^");
      return null;

    }
  }
  // Méthode d'inscription principale
  Future<void> signUp(String email, String password) async {

    if (!_formKey.currentState!.validate()) return;



    // Vérification de l'image
    if (_image == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.orange,
          content: Text('Veuillez sélectionner une photo de profil', style: TextStyle(color: Colors.white)),
        ),
      );
      return;
    }

    // Vérification de la taille de l'image (max 5MB)
    final imageSize = await _image!.length();
    if (imageSize > 5 * 1024 * 1024) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.orange,
          content: Text('L\'image est trop volumineuse (max 5MB)', style: TextStyle(color: Colors.white)),
        ),
      );
      return;
    }

    setState(() => tap = true);

    try {
      // Configuration des données utilisateur
      authProvider.registerUser
        ..role = UserRole.USER.name!
        ..updatedAt = DateTime.now().microsecondsSinceEpoch
        ..createdAt = DateTime.now().microsecondsSinceEpoch;

      // Upload de l'image
      String imageUrl = await _uploadImage(_image!);
      authProvider.registerUser.imageUrl = imageUrl;

      // Configuration des autres données
      authProvider.registerUser.adresse = adresseController.text;
      authProvider.registerUser.apropos = aproposController.text;
      authProvider.registerUser.votre_solde = 0.0;

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

          // Envoi de la notification de parrainage
          await _sendParrainageNotification(parrain, notif);

          // Envoi de l'email de vérification
          await sendVerificationEmail(userCredential.user!);

          // Affichage du succès
          _showSuccessAndNavigate();

        } else {
          // Code de parrainage invalide
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.red,
              content: Text('Le code de parrainage est erroné !', style: TextStyle(color: Colors.white)),
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

    // Configuration de l'utilisateur
    authProvider.registerUser.pointContribution = authProvider.appDefaultData.default_point_new_user!;
    authProvider.registerUser.votre_solde = 5.1;
    authProvider.registerUser.publi_cash = 5.1;

    // Mise à jour du parrain
    final usersRef = firestore.collection('Users');
    final parrainRef = usersRef.doc(parrain.id!);

// Mise à jour directe des champs
    await parrainRef.update({
      'pointContribution': (parrain.pointContribution ?? 0) + authProvider.appDefaultData.default_point_new_user!,
      'votre_solde': (parrain.votre_solde ?? 0.0) + 5.1,
      'publi_cash': (parrain.publi_cash ?? 0.0) + 5.1,
      'usersParrainer': FieldValue.arrayUnion([id]), // ajoute le nouvel utilisateur dans la liste
      'userAbonnesIds': FieldValue.arrayUnion([id]), // ajoute le nouvel abonné
    });

    // Batch operations
    final batch = firestore.batch();
    batch.set(firestore.collection('Users').doc(id), authProvider.registerUser.toJson());
    batch.set(firestore.collection('Pseudo').doc(pseudo.id), pseudo.toJson());

    // Mise à jour des statistiques globales
    authProvider.appDefaultData.nbr_abonnes = (authProvider.appDefaultData.nbr_abonnes ?? 0) + 1;
    if (!authProvider.appDefaultData.users_id!.contains(id)) {
      authProvider.appDefaultData.users_id!.add(id);
    }
    batch.update(firestore.collection('AppData').doc(authProvider.appDefaultData.id!), {
      'nbr_abonnes': authProvider.appDefaultData.nbr_abonnes,
      'users_id': authProvider.appDefaultData.users_id,
    });

    await batch.commit();
  }

// Configuration des données sans parrainage
  Future<void> _configureUserDataWithoutParrainage(String id, UserPseudo pseudo) async {
    pseudo.id = firestore.collection('Pseudo').doc().id;
    pseudo.name = authProvider.registerUser.pseudo;
    authProvider.registerUser.id = id;

    await authProvider.getAppData();

    // Configuration de l'utilisateur
    authProvider.registerUser.pointContribution = authProvider.appDefaultData.default_point_new_user!;
    authProvider.registerUser.votre_solde = 0.0;
    authProvider.registerUser.publi_cash = 0.0;

    // Batch operations
    final batch = firestore.batch();
    batch.set(firestore.collection('Users').doc(id), authProvider.registerUser.toJson());
    batch.set(firestore.collection('Pseudo').doc(pseudo.id), pseudo.toJson());

    // Mise à jour des statistiques globales
    authProvider.appDefaultData.nbr_abonnes = (authProvider.appDefaultData.nbr_abonnes ?? 0) + 1;
    if (!authProvider.appDefaultData.users_id!.contains(id)) {
      authProvider.appDefaultData.users_id!.add(id);
    }
    batch.update(firestore.collection('AppData').doc(authProvider.appDefaultData.id!), {
      'nbr_abonnes': authProvider.appDefaultData.nbr_abonnes,
      'users_id': authProvider.appDefaultData.users_id,
    });

    await batch.commit();
  }

// Envoi de notification de parrainage
  Future<void> _sendParrainageNotification(UserData parrain, NotificationData notif) async {
    // notif.id = firestore.collection('Notifications').doc().id;
    // notif.titre = "Parrainage 🤑";
    // notif.media_url = parrain.imageUrl;
    // notif.type = NotificationType.PARRAINAGE.name;
    // notif.description = "Vous avez gagné 1 PubliCash grâce à un parrainage !";
    // notif.user_id = authProvider.registerUser.id;
    // notif.receiver_id = parrain.id!;
    // notif.updatedAt = DateTime.now().microsecondsSinceEpoch;
    // notif.createdAt = DateTime.now().microsecondsSinceEpoch;
    // notif.status = PostStatus.VALIDE.name;
    //
    // await firestore.collection('Notifications').doc(notif.id).set(notif.toJson());

    await authProvider.sendNotification(
        userIds: [parrain.oneIgnalUserid!],
        smallImage: parrain.imageUrl!,
        send_user_id: authProvider.registerUser.id!,
        recever_user_id: parrain.id!,
        message: "🤑 Vous avez gagné 1 abonné grâce à un parrainage !",
        type_notif: NotificationType.PARRAINAGE.name,
        post_id: "",
        post_type: "",
        chat_id: ''
    );
  }

// Méthode pour uploader l'image
  Future<String> _uploadImage(File image) async {
    try {
      Reference storageReference = FirebaseStorage.instance
          .ref()
          .child('user_profile/${Path.basename(image.path)}_${DateTime.now().millisecondsSinceEpoch}');

      UploadTask uploadTask = storageReference.putFile(image);
      TaskSnapshot snapshot = await uploadTask;

      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print("Erreur lors de l'upload de l'image: $e");
      throw Exception("Échec de l'upload de l'image");
    }
  }





// Affichage du succès et navigation
  void _showSuccessAndNavigate() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.green,
        content: Text('Compte créé avec succès !', style: TextStyle(color: Colors.white)),
        duration: Duration(seconds: 2),
      ),
    );
  }

// Gestion des erreurs
  void _handleAuthError(FirebaseAuthException error) {
    final errorMessages = {
      "invalid-email": "Votre email semble être malformé.",
      "wrong-password": "Votre mot de passe est erroné.",
      "email-already-in-use": "L'email est déjà utilisé par un autre compte.",
      "user-not-found": "L'utilisateur avec cet email n'existe pas.",
      "user-disabled": "L'utilisateur avec cet email a été désactivé.",
      "too-many-requests": "Trop de demandes.",
      "operation-not-allowed": "La connexion avec l'email et un mot de passe n'est pas activée.",
      "weak-password": "Le mot de passe est trop faible.",
    };

    final errorMessage = errorMessages[error.code] ?? "Une erreur indéfinie s'est produite";

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.red,
        content: Text(errorMessage, style: TextStyle(color: Colors.white)),
      ),
    );
  }

  void _handleFirebaseError(FirebaseException error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.red,
        content: Text("Erreur Firebase: ${error.message}", style: TextStyle(color: Colors.white)),
      ),
    );
  }

  void _handleGenericError(dynamic error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.red,
        content: Text("Erreur inattendue: ${error.toString()}", style: TextStyle(color: Colors.white)),
      ),
    );
  }


  // Gestion des erreurs
  void _handleError(dynamic error) {
    String errorMessage = "Une erreur s'est produite lors de la création du compte";

    if (error is FirebaseAuthException) {
      switch (error.code) {
        case "email-already-in-use":
          errorMessage = "L'email est déjà utilisé par un autre compte.";
          break;
        case "invalid-email":
          errorMessage = "Votre email semble être malformé.";
          break;
        case "weak-password":
          errorMessage = "Le mot de passe est trop faible.";
          break;
        default:
          errorMessage = error.message ?? "Erreur d'authentification";
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.red,
        content: Text(errorMessage, style: TextStyle(color: Colors.white)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: primaryGreen),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Finalisation du profil",
          style: TextStyle(color: textColor, fontSize: 18),
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
                      hintText: "Adresse",
                      prefixIcon: Icons.location_on_outlined,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Ce champ est obligatoire';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 20),

                    // Champ à propos
                    _buildAboutSection(),
                    SizedBox(height: 20),

                    // Texte conditions
                    Text(
                      'En créant ce compte, vous acceptez les termes et conditions.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[400],
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
    return Column(
      children: [
        Text(
          "Votre photo de profil",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: textColor,
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
                child: _image == null
                    ? Image.asset(
                  'assets/icon/user-removebg-preview.png',
                  fit: BoxFit.cover,
                )
                    : Image.file(
                  _image!,
                  fit: BoxFit.cover,
                ),
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
                  border: Border.all(color: darkBackground, width: 3),
                ),
                child: IconButton(
                  onPressed: getImage,
                  icon: Icon(Icons.camera_alt, size: 20, color: Colors.white),
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAboutSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'À propos de vous',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: lightBackground,
            borderRadius: BorderRadius.circular(15),
          ),
          child: TextFormField(
            controller: aproposController,
            maxLines: 4,
            style: TextStyle(color: textColor),
            decoration: InputDecoration(
              hintText: 'Décrivez-vous en quelques mots...',
              hintStyle: TextStyle(color: Colors.grey[500]),
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
      style: TextStyle(color: textColor),
      decoration: InputDecoration(
        filled: true,
        fillColor: lightBackground,
        hintText: hintText,
        hintStyle: TextStyle(color: Colors.grey[500]),
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

  Widget _buildNavigationButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Expanded(
        //   child: OutlinedButton(
        //     onPressed: () => Navigator.pop(context),
        //     style: OutlinedButton.styleFrom(
        //       padding: EdgeInsets.symmetric(vertical: 15),
        //       shape: RoundedRectangleBorder(
        //         borderRadius: BorderRadius.circular(25),
        //       ),
        //       side: BorderSide(color: Colors.red),
        //     ),
        //     child: Row(
        //       mainAxisAlignment: MainAxisAlignment.center,
        //       children: [
        //         Icon(Icons.arrow_back, color: Colors.red, size: 20),
        //         SizedBox(width: 8),
        //         Text(
        //           "Précédent",
        //           style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        //         ),
        //       ],
        //     ),
        //   ),
        // ),
        // SizedBox(width: 15),
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
              backgroundColor: primaryGreen,
              padding: EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
            child: tap
                ? LoadingAnimationWidget.threeRotatingDots(
              color: Colors.white,
              size: 24,
            )
                : Text(
              "S'inscrire",
              style: TextStyle(
                color: Colors.white,
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
          "Vous avez déjà un compte? ",
          style: TextStyle(color: Colors.grey[500]),
        ),
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => LoginPageUser()),
            );
          },
          child: Text(
            "Connectez-vous",
            style: TextStyle(
              color: primaryGreen,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  // Les méthodes _handleParrainage et _createUserData restent similaires à votre code original
  // mais adaptées pour le nouveau design
  Future<void> _handleParrainage(String userId) async {
    // Implémentation similaire à votre code original
  }

  Future<void> _createUserData(String userId) async {
    // Implémentation similaire à votre code original
  }
}