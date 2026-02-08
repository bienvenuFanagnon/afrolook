
import 'dart:math';

import 'package:afrotok/pages/contact.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'package:afrotok/pages/auth/authTest/Screens/Signup/signup_screen.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';


import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';

import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:provider/provider.dart';
import 'package:simple_tags/simple_tags.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import '../../../../../../constant/sizeButtons.dart';
import '../../../../../../models/model_data.dart';

import '../../../../../../providers/authProvider.dart';
import '../../../../../providers/userProvider.dart';

import 'dart:async';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../component/consoleWidget.dart';
import '../../../../widgetGlobal.dart';
import '../../../update_pass_word/confirm_user.dart';
import '../../components/already_have_an_account_acheck.dart';
import '../../constants.dart';
import '../Signup/components/signup_form.dart';



const Color primaryGreen = Color(0xFF25D366);
const Color darkBackground = Color(0xFF121212);
const Color lightBackground = Color(0xFF1E1E1E);
const Color textColor = Colors.white;


class LoginPageUser extends StatefulWidget {
  LoginPageUser({Key? key}) : super(key: key);

  @override
  _LoginPageUserState createState() => _LoginPageUserState();
}

class _LoginPageUserState extends State<LoginPageUser> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController telephoneController = TextEditingController();
  late UserAuthProvider authProvider =
  Provider.of<UserAuthProvider>(context, listen: false);
  late UserProvider userProvider =
  Provider.of<UserProvider>(context, listen: false);
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showInstallModal(context);

      });
    }
  }
  // Fonction de connexion
  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    SharedPreferences prefs = await SharedPreferences.getInstance();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      final user = userCredential.user;

      if (user != null && !user.emailVerified) {
        // Afficher un modal pour demander la vérification
        _showEmailVerificationModal(user);
        return; // Stopper le reste de la connexion
      }

      // Si email vérifié, continuer la récupération des données
      if (await authProvider.getCurrentUser(user!.uid)) {
        if (authProvider.loginUserData != null &&
            authProvider.loginUserData.id != null &&
            authProvider.loginUserData.id!.length > 5) {

          await authProvider.getAppData();
          await userProvider.getAllAnnonces();

          userProvider.changeState(
              user: authProvider.loginUserData,
              state: UserState.ONLINE.name
          );
          prefs.setString('token', user.uid);

          Navigator.pushReplacementNamed(context, '/home');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur de chargement', textAlign: TextAlign.center),
              backgroundColor: Colors.red,
            ),
          );
        }
      }

      _emailController.clear();
      _passwordController.clear();

    } on FirebaseAuthException catch (error) {
      _handleFirebaseAuthError(error);
    } catch (e) {
      _errorMessage = "Une erreur inattendue s'est produite.";
    } finally {
      setState(() => _isLoading = false);
      if (_errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_errorMessage!, textAlign: TextAlign.center),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // Modal pour email non vérifié
  void _showEmailVerificationModal(User user) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.email, size: 60, color: Colors.orange),
                SizedBox(height: 10),
                Text(
                  "Vérification de l'email requise",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 10),
                Text(
                  "Pour continuer, vous devez vérifier votre adresse email. "
                      "Nous pouvons vous renvoyer un lien de vérification.",
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                  ),
                  onPressed: () async {
                    await user.sendEmailVerification();
                    Navigator.pop(context); // fermer le premier modal

                    // Afficher le deuxième modal informatif
                    _showCheckEmailModal();
                  },
                  child: Text("Renvoyer le lien"),
                ),
                SizedBox(height: 10),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text("Annuler"),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  // Deuxième modal après l'envoi du lien
  void _showCheckEmailModal() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.mark_email_read, size: 60, color: Colors.green),
                SizedBox(height: 10),
                Text(
                  "Lien envoyé !",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 10),
                Text(
                  "Veuillez vérifier votre boîte mail pour confirmer votre compte. "
                      "Pensez à regarder dans les spams si vous ne le trouvez pas.",
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: Text("Compris"),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Méthode pour gérer les erreurs FirebaseAuth
  void _handleFirebaseAuthError(FirebaseAuthException error) {
    print("Une erreur indéfinie : ${error.code}");

    switch (error.code) {
      case "invalid-email":
        _errorMessage = "Votre adresse email semble être malformée.";
        break;
      case "wrong-password":
        _errorMessage = "Votre mot de passe est erroné.";
        break;
      case "user-not-found":
        _errorMessage = "L'utilisateur avec cet email n'existe pas.";
        break;
      case "invalid-credential":
        _errorMessage = "Email ou mot de passe incorrect. Avez-vous déjà créé un compte ?";
        break;
      case "user-disabled":
        _errorMessage = "L'utilisateur avec cet email a été désactivé.";
        break;
      case "too-many-requests":
        _errorMessage = "Trop de tentatives de connexion. Réessayez plus tard.";
        break;
      case "operation-not-allowed":
        _errorMessage = "La connexion avec email et mot de passe n'est pas activée.";
        break;
      case "network-request-failed":
        _errorMessage = "Erreur de connexion. Vérifiez votre internet.";
        break;
      default:
        _errorMessage = "Une erreur indéfinie s'est produite.";
    }
  }

  bool isValidEmail(String email) {
    final RegExp emailRegExp = RegExp(
        r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$"
    );
    return emailRegExp.hasMatch(email);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkBackground,
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Container(
            height: MediaQuery.of(context).size.height,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  darkBackground.withOpacity(0.9),
                  darkBackground,
                ],
              ),
            ),
            child: SingleChildScrollView(
              physics: BouncingScrollPhysics(),
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header avec bouton d'inscription en haut à droite
                  _buildHeaderWithSignUpButton(),
                  SizedBox(height: 20),

                  // Logo et titre
                  _buildHeader(),
                  SizedBox(height: 40),

                  // Formulaire de connexion
                  _buildLoginForm(),
                  SizedBox(height: 20),

                  // Options supplémentaires avec bouton "Créer un compte"
                  _buildAdditionalOptions(),

                  // Bouton "Nous contacter" en bas
                  Container(
                    width: double.infinity,
                    margin: EdgeInsets.only(top: 30, bottom: 30),
                    child: _buildContactButton(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderWithSignUpButton() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          decoration: BoxDecoration(
            color: primaryGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: IconButton(
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => SignUpScreen()));
            },
            icon: Icon(
              Icons.person_add_alt_1,
              color: primaryGreen,
              size: 24,
            ),
            tooltip: "Créer un compte",
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        // Logo
        Container(
          width: min(120, MediaQuery.of(context).size.width * 0.3),
          height: min(120, MediaQuery.of(context).size.width * 0.3),
          child: Image.asset(
            'assets/logo/afrolook_logo.png',
            fit: BoxFit.contain,
          ),
        ),
        SizedBox(height: 15),

        // Titre
        Text(
          "Afrolook",
          style: TextStyle(
            fontSize: min(32, MediaQuery.of(context).size.width * 0.08),
            fontWeight: FontWeight.bold,
            color: primaryGreen,
          ),
        ),
        SizedBox(height: 5),

        // Slogan
        Text(
          "Votre popularité est à la une",
          style: TextStyle(
            fontSize: min(16, MediaQuery.of(context).size.width * 0.04),
            color: Colors.grey[400],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildLoginForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          // Champ email
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            style: TextStyle(color: textColor),
            decoration: InputDecoration(
              filled: true,
              fillColor: lightBackground,
              hintText: "Adresse email",
              hintStyle: TextStyle(color: Colors.grey[500]),
              prefixIcon: Icon(Icons.email_outlined, color: primaryGreen),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide.none,
              ),
              contentPadding: EdgeInsets.symmetric(vertical: 15, horizontal: 20),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Veuillez entrer votre adresse email';
              }
              if (!isValidEmail(value)) {
                return 'Adresse email invalide';
              }
              return null;
            },
          ),
          SizedBox(height: 20),

          // Champ mot de passe
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            style: TextStyle(color: textColor),
            decoration: InputDecoration(
              filled: true,
              fillColor: lightBackground,
              hintText: "Mot de passe",
              hintStyle: TextStyle(color: Colors.grey[500]),
              prefixIcon: Icon(Icons.lock_outline, color: primaryGreen),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: primaryGreen,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide.none,
              ),
              contentPadding: EdgeInsets.symmetric(vertical: 15, horizontal: 20),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Veuillez entrer votre mot de passe';
              }
              if (value.length < 6) {
                return 'Le mot de passe doit contenir au moins 6 caractères';
              }
              return null;
            },
          ),
          SizedBox(height: 10),

          // Mot de passe oublié
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => ConfirmUser()));
              },
              child: Text(
                "Mot de passe oublié?",
                style: TextStyle(
                  color: primaryGreen,
                  fontSize: min(14, MediaQuery.of(context).size.width * 0.035),
                ),
              ),
            ),
          ),
          SizedBox(height: 25),

          // Bouton de connexion
          Container(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _signIn,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
                elevation: 0,
              ),
              child: _isLoading
                  ? LoadingAnimationWidget.threeRotatingDots(
                color: Colors.white,
                size: 24,
              )
                  : Text(
                "Se connecter",
                style: TextStyle(
                  fontSize: min(16, MediaQuery.of(context).size.width * 0.04),
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdditionalOptions() {
    return Column(
      children: [
        // Ligne séparatrice
        Row(
          children: [
            Expanded(
              child: Divider(
                color: Colors.grey[700],
                thickness: 1,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                "Ou",
                style: TextStyle(
                  color: Colors.grey[500],
                ),
              ),
            ),
            Expanded(
              child: Divider(
                color: Colors.grey[700],
                thickness: 1,
              ),
            ),
          ],
        ),
        SizedBox(height: 20),

        // Bouton créer un compte (remplace le bouton nous contacter)
        Container(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => SignUpScreen()));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
                side: BorderSide(color: primaryGreen, width: 2),
              ),
              elevation: 0,
            ),
            child: Text(
              "Créer un compte",
              style: TextStyle(
                fontSize: min(16, MediaQuery.of(context).size.width * 0.04),
                fontWeight: FontWeight.bold,
                color: primaryGreen,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContactButton() {
    return Column(
      children: [
        // Ligne séparatrice
        Row(
          children: [
            Expanded(
              child: Divider(
                color: Colors.grey[700],
                thickness: 1,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                "Besoin d'aide?",
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: min(14, MediaQuery.of(context).size.width * 0.035),
                ),
              ),
            ),
            Expanded(
              child: Divider(
                color: Colors.grey[700],
                thickness: 1,
              ),
            ),
          ],
        ),
        SizedBox(height: 20),

        // Bouton nous contacter
        Container(
          width: double.infinity,
          height: 50,
          child: OutlinedButton(
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => ContactPage()));
            },
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
              side: BorderSide(color: Colors.grey[600]!),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.help_outline,
                  color: Colors.grey[400],
                  size: 20,
                ),
                SizedBox(width: 10),
                Text(
                  "Nous contacter",
                  style: TextStyle(
                    fontSize: min(16, MediaQuery.of(context).size.width * 0.04),
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[400],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
//
// class LoginPageUser extends StatefulWidget {
//   LoginPageUser({Key? key}) : super(key: key);
//
//   @override
//   _LoginPageUserState createState() => _LoginPageUserState();
// }
//
// class _LoginPageUserState extends State<LoginPageUser> {
//   final TextEditingController _emailController = TextEditingController();
//   final TextEditingController _passwordController = TextEditingController();
//   final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
//   final TextEditingController telephoneController = TextEditingController();
//   late UserAuthProvider authProvider =
//   Provider.of<UserAuthProvider>(context, listen: false);
//   late UserProvider userProvider =
//   Provider.of<UserProvider>(context, listen: false);
//   bool _isLoading = false;
//   bool _obscurePassword = true;
//   String? _errorMessage;
//
//   // Fonction de connexion
//   Future<void> _signIn2() async {
//     if (!_formKey.currentState!.validate()) return;
//       SharedPreferences prefs = await SharedPreferences.getInstance();
//
//     setState(() {
//       _isLoading = true;
//       _errorMessage = null;
//     });
//
//
//       try {
//          await FirebaseAuth.instance.signInWithEmailAndPassword(
//         email: _emailController.text.trim(),
//         password: _passwordController.text,
//       )
//             .then((uid) async => {
//           //serviceProvider.getLoginUser( _auth.currentUser!.uid!,context),
//
//           await authProvider.getCurrentUser(uid.user!.uid!).then((value) async {
//           //  PhoneVerification phoneverification = PhoneVerification(number:'22896198801' );
//
//              //   phoneverification.sendotp('Your Otp');
//             if (value) {
//
// if(authProvider.loginUserData!=null ||authProvider.loginUserData.id!=null ||authProvider.loginUserData.id!.length>5){
//   await authProvider.getAppData();
//   await userProvider.getAllAnnonces();
//
//   //printVm("app data2 : ${authProvider.appDefaultData.toJson()!}");
//   // Obtenez les SharedPreferences
//   userProvider.changeState(user: authProvider.loginUserData,
//       state: UserState.ONLINE.name);
//   prefs.setString('token', uid.user!.uid!);
//
//   Navigator.pushReplacementNamed(
//       context,
//       '/home');
//  // Navigator.pushNamed(context, '/chargement');
//
//
// }
//
//
//             }else{
//             ScaffoldMessenger.of(context).showSnackBar(SnackBar(
//             content: Text('Erreur de Chargement',textAlign: TextAlign.center,style: TextStyle(color: Colors.red),),
//             ),);
//             }
//           },),
//            _emailController.clear(),
//             _passwordController.clear(),
//         });
//       } on FirebaseAuthException catch (error) {
//       switch (error.code) {
//         case "invalid-email":
//           _errorMessage = "Votre adresse email semble être malformée.";
//           break;
//         case "wrong-password":
//           _errorMessage = "Votre mot de passe est erroné.";
//           break;
//         case "user-not-found":
//           _errorMessage = "L'utilisateur avec cet email n'existe pas.";
//           break;
//         case "invalid-credential":
//           _errorMessage = "Informations de connexion incorrectes.";
//           break;
//         case "user-disabled":
//           _errorMessage = "L'utilisateur avec cet email a été désactivé.";
//           break;
//         case "too-many-requests":
//           _errorMessage = "Trop de tentatives de connexion. Réessayez plus tard.";
//           break;
//         case "operation-not-allowed":
//           _errorMessage = "La connexion avec email et mot de passe n'est pas activée.";
//           break;
//         case "network-request-failed":
//           _errorMessage = "Erreur de connexion. Vérifiez votre internet.";
//           break;
//         default:
//           _errorMessage = "Une erreur indéfinie s'est produite.";
//       }
//     } catch (e) {
//       _errorMessage = "Une erreur inattendue s'est produite.";
//     } finally {
//       setState(() => _isLoading = false);
//
//       if (_errorMessage != null) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text(_errorMessage!, textAlign: TextAlign.center),
//             backgroundColor: Colors.red,
//             duration: Duration(seconds: 3),
//           ),
//         );
//       }
//     }
//   }
//
//
//   Future<void> _signIn() async {
//     if (!_formKey.currentState!.validate()) return;
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//
//     setState(() {
//       _isLoading = true;
//       _errorMessage = null;
//     });
//
//     try {
//       final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
//         email: _emailController.text.trim(),
//         password: _passwordController.text,
//       );
//
//       final user = userCredential.user;
//
//       if (user != null && !user.emailVerified) {
//         // Afficher un modal pour demander la vérification
//         _showEmailVerificationModal(user);
//         return; // Stopper le reste de la connexion
//       }
//
//       // Si email vérifié, continuer la récupération des données
//       if (await authProvider.getCurrentUser(user!.uid)) {
//         if (authProvider.loginUserData != null &&
//             authProvider.loginUserData.id != null &&
//             authProvider.loginUserData.id!.length > 5) {
//
//           await authProvider.getAppData();
//           await userProvider.getAllAnnonces();
//
//           userProvider.changeState(
//               user: authProvider.loginUserData,
//               state: UserState.ONLINE.name
//           );
//           prefs.setString('token', user.uid);
//
//           Navigator.pushReplacementNamed(context, '/home');
//         } else {
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//               content: Text('Erreur de chargement', textAlign: TextAlign.center),
//               backgroundColor: Colors.red,
//             ),
//           );
//         }
//       }
//
//       _emailController.clear();
//       _passwordController.clear();
//
//     } on FirebaseAuthException catch (error) {
//       _handleFirebaseAuthError(error);
//     } catch (e) {
//       _errorMessage = "Une erreur inattendue s'est produite.";
//     } finally {
//       setState(() => _isLoading = false);
//       if (_errorMessage != null) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text(_errorMessage!, textAlign: TextAlign.center),
//             backgroundColor: Colors.red,
//             duration: Duration(seconds: 3),
//           ),
//         );
//       }
//     }
//   }
//
// // Modal pour email non vérifié
//   void _showEmailVerificationModal(User user) {
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (context) {
//         return Dialog(
//           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//           child: Padding(
//             padding: const EdgeInsets.all(20.0),
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Icon(Icons.email, size: 60, color: Colors.orange),
//                 SizedBox(height: 10),
//                 Text(
//                   "Vérification de l'email requise",
//                   style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//                   textAlign: TextAlign.center,
//                 ),
//                 SizedBox(height: 10),
//                 Text(
//                   "Pour continuer, vous devez vérifier votre adresse email. "
//                       "Nous pouvons vous renvoyer un lien de vérification.",
//                   textAlign: TextAlign.center,
//                 ),
//                 SizedBox(height: 20),
//                 ElevatedButton(
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: Colors.orange,
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(10),
//                     ),
//                     padding: EdgeInsets.symmetric(horizontal: 30, vertical: 12),
//                   ),
//                   onPressed: () async {
//                     await user.sendEmailVerification();
//                     Navigator.pop(context); // fermer le premier modal
//
//                     // Afficher le deuxième modal informatif
//                     _showCheckEmailModal();
//                   },
//                   child: Text("Renvoyer le lien"),
//                 ),
//                 SizedBox(height: 10),
//                 TextButton(
//                   onPressed: () => Navigator.pop(context),
//                   child: Text("Annuler"),
//                 )
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }
//
// // Deuxième modal après l'envoi du lien
//   void _showCheckEmailModal() {
//     showDialog(
//       context: context,
//       barrierDismissible: true,
//       builder: (context) {
//         return Dialog(
//           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//           child: Padding(
//             padding: const EdgeInsets.all(20.0),
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Icon(Icons.mark_email_read, size: 60, color: Colors.green),
//                 SizedBox(height: 10),
//                 Text(
//                   "Lien envoyé !",
//                   style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//                   textAlign: TextAlign.center,
//                 ),
//                 SizedBox(height: 10),
//                 Text(
//                   "Veuillez vérifier votre boîte mail pour confirmer votre compte. "
//                       "Pensez à regarder dans les spams si vous ne le trouvez pas.",
//                   textAlign: TextAlign.center,
//                 ),
//                 SizedBox(height: 20),
//                 ElevatedButton(
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: Colors.green,
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(10),
//                     ),
//                     padding: EdgeInsets.symmetric(horizontal: 30, vertical: 12),
//                   ),
//                   onPressed: () => Navigator.pop(context),
//                   child: Text("Compris"),
//                 ),
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }
//
// // Méthode pour gérer les erreurs FirebaseAuth
//   void _handleFirebaseAuthError(FirebaseAuthException error) {
//     print("Une erreur indéfinie : ${error.code}");
//
//     switch (error.code) {
//       case "invalid-email":
//         _errorMessage = "Votre adresse email semble être malformée.";
//         break;
//       case "wrong-password":
//         _errorMessage = "Votre mot de passe est erroné.";
//         break;
//       case "user-not-found":
//         _errorMessage = "L'utilisateur avec cet email n'existe pas.";
//         break;
//       case "invalid-credential":
//         _errorMessage = "Informations de connexion incorrectes.";
//         break;
//       case "user-disabled":
//         _errorMessage = "L'utilisateur avec cet email a été désactivé.";
//         break;
//       case "too-many-requests":
//         _errorMessage = "Trop de tentatives de connexion. Réessayez plus tard.";
//         break;
//       case "operation-not-allowed":
//         _errorMessage = "La connexion avec email et mot de passe n'est pas activée.";
//         break;
//       case "network-request-failed":
//         _errorMessage = "Erreur de connexion. Vérifiez votre internet.";
//         break;
//       default:
//         _errorMessage = "Une erreur indéfinie s'est produite.";
//         }
//   }
//
//
//   bool isValidEmail(String email) {
//     final RegExp emailRegExp = RegExp(
//         r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$"
//     );
//     return emailRegExp.hasMatch(email);
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: darkBackground,
//       body: GestureDetector(
//         onTap: () => FocusScope.of(context).unfocus(),
//         child: Stack(
//           children: [
//             // Arrière-plan avec effet de dégradé
//             Container(
//               decoration: BoxDecoration(
//                 gradient: LinearGradient(
//                   begin: Alignment.topCenter,
//                   end: Alignment.bottomCenter,
//                   colors: [
//                     darkBackground.withOpacity(0.9),
//                     darkBackground,
//                   ],
//                 ),
//               ),
//             ),
//
//             // Contenu principal
//             SingleChildScrollView(
//               physics: ClampingScrollPhysics(),
//               child: Container(
//                 height: MediaQuery.of(context).size.height,
//                 padding: EdgeInsets.symmetric(horizontal: 20),
//                 child: Column(
//                   children: [
//                     SizedBox(height: MediaQuery.of(context).size.height * 0.1),
//
//                     // Logo et titre
//                     _buildHeader(),
//                     SizedBox(height: 40),
//
//                     // Formulaire de connexion
//                     _buildLoginForm(),
//                     SizedBox(height: 20),
//
//                     // Options supplémentaires
//                     _buildAdditionalOptions(),
//                     Spacer(),
//
//                     // Lien d'inscription
//                     _buildSignUpLink(),
//                     SizedBox(height: 30),
//                   ],
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildHeader() {
//     return Column(
//       children: [
//         // Logo
//         Image.asset(
//           'assets/logo/afrolook_logo.png',
//           width: 100,
//           height: 100,
//         ),
//         SizedBox(height: 15),
//
//         // Titre
//         Text(
//           "Afrolook",
//           style: TextStyle(
//             fontSize: 32,
//             fontWeight: FontWeight.bold,
//             color: primaryGreen,
//           ),
//         ),
//         SizedBox(height: 5),
//
//         // Slogan
//         Text(
//           "Votre popularité est à la une",
//           style: TextStyle(
//             fontSize: 16,
//             color: Colors.grey[400],
//           ),
//         ),
//       ],
//     );
//   }
//
//   Widget _buildLoginForm() {
//     return Form(
//       key: _formKey,
//       child: Column(
//         children: [
//           // Champ email
//           TextFormField(
//             controller: _emailController,
//             keyboardType: TextInputType.emailAddress,
//             textInputAction: TextInputAction.next,
//             style: TextStyle(color: textColor),
//             decoration: InputDecoration(
//               filled: true,
//               fillColor: lightBackground,
//               hintText: "Adresse email",
//               hintStyle: TextStyle(color: Colors.grey[500]),
//               prefixIcon: Icon(Icons.email_outlined, color: primaryGreen),
//               border: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(15),
//                 borderSide: BorderSide.none,
//               ),
//               contentPadding: EdgeInsets.symmetric(vertical: 15, horizontal: 20),
//             ),
//             validator: (value) {
//               if (value == null || value.isEmpty) {
//                 return 'Veuillez entrer votre adresse email';
//               }
//               if (!isValidEmail(value)) {
//                 return 'Adresse email invalide';
//               }
//               return null;
//             },
//           ),
//           SizedBox(height: 20),
//
//           // Champ mot de passe
//           TextFormField(
//             controller: _passwordController,
//             obscureText: _obscurePassword,
//             textInputAction: TextInputAction.done,
//             style: TextStyle(color: textColor),
//             decoration: InputDecoration(
//               filled: true,
//               fillColor: lightBackground,
//               hintText: "Mot de passe",
//               hintStyle: TextStyle(color: Colors.grey[500]),
//               prefixIcon: Icon(Icons.lock_outline, color: primaryGreen),
//               suffixIcon: IconButton(
//                 icon: Icon(
//                   _obscurePassword ? Icons.visibility_off : Icons.visibility,
//                   color: primaryGreen,
//                 ),
//                 onPressed: () {
//                   setState(() {
//                     _obscurePassword = !_obscurePassword;
//                   });
//                 },
//               ),
//               border: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(15),
//                 borderSide: BorderSide.none,
//               ),
//               contentPadding: EdgeInsets.symmetric(vertical: 15, horizontal: 20),
//             ),
//             validator: (value) {
//               if (value == null || value.isEmpty) {
//                 return 'Veuillez entrer votre mot de passe';
//               }
//               if (value.length < 6) {
//                 return 'Le mot de passe doit contenir au moins 6 caractères';
//               }
//               return null;
//             },
//           ),
//           SizedBox(height: 10),
//
//           // Mot de passe oublié
//           Align(
//             alignment: Alignment.centerRight,
//             child: TextButton(
//               onPressed: () {
//                 Navigator.push(context, MaterialPageRoute(builder: (context) => ConfirmUser()));
//               },
//               child: Text(
//                 "Mot de passe oublié?",
//                 style: TextStyle(
//                   color: primaryGreen,
//                   fontSize: 14,
//                 ),
//               ),
//             ),
//           ),
//           SizedBox(height: 25),
//
//           // Bouton de connexion
//           Container(
//             width: double.infinity,
//             height: 50,
//             child: ElevatedButton(
//               onPressed: _isLoading ? null : _signIn,
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: primaryGreen,
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(25),
//                 ),
//                 elevation: 0,
//               ),
//               child: _isLoading
//                   ? LoadingAnimationWidget.threeRotatingDots(
//                 color: Colors.white,
//                 size: 24,
//               )
//                   : Text(
//                 "Se connecter",
//                 style: TextStyle(
//                   fontSize: 16,
//                   fontWeight: FontWeight.bold,
//                   color: Colors.white,
//                 ),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildAdditionalOptions() {
//     return Column(
//       children: [
//         // Ligne séparatrice
//         Row(
//           children: [
//             Expanded(
//               child: Divider(
//                 color: Colors.grey[700],
//                 thickness: 1,
//               ),
//             ),
//             Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 10),
//               child: Text(
//                 "Ou",
//                 style: TextStyle(
//                   color: Colors.grey[500],
//                 ),
//               ),
//             ),
//             Expanded(
//               child: Divider(
//                 color: Colors.grey[700],
//                 thickness: 1,
//               ),
//             ),
//           ],
//         ),
//         SizedBox(height: 20),
//
//         // Bouton nous contacter
//         Container(
//           width: double.infinity,
//           height: 50,
//           child: OutlinedButton(
//             onPressed: () {
//               Navigator.push(context, MaterialPageRoute(builder: (context) => ContactPage()));
//             },
//             style: OutlinedButton.styleFrom(
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(25),
//               ),
//               side: BorderSide(color: primaryGreen),
//             ),
//             child: Text(
//               "Nous contacter",
//               style: TextStyle(
//                 fontSize: 16,
//                 fontWeight: FontWeight.bold,
//                 color: primaryGreen,
//               ),
//             ),
//           ),
//         ),
//       ],
//     );
//   }
//
//   Widget _buildSignUpLink() {
//     return Row(
//       mainAxisAlignment: MainAxisAlignment.center,
//       children: [
//         Text(
//           "Vous n'avez pas de compte? ",
//           style: TextStyle(
//             color: Colors.grey[500],
//           ),
//         ),
//         GestureDetector(
//           onTap: () {
//             Navigator.push(context, MaterialPageRoute(builder: (context) => SignUpScreen()));
//           },
//           child: Text(
//             "Inscrivez-vous",
//             style: TextStyle(
//               color: primaryGreen,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//         ),
//       ],
//     );
//   }
// }





