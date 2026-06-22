
import 'dart:math';

import 'package:afrotok/pages/contact.dart';
import 'package:afrotok/pages/splashChargement.dart';
import 'package:afrotok/services/sessions/session_service.dart';
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
import '../../../../../theme/app_colors.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../widgetGlobal.dart';
import '../../../update_pass_word/confirm_user.dart';
import '../../components/already_have_an_account_acheck.dart';
import '../../constants.dart';
import '../Signup/components/signup_form.dart';



class LoginPageUser extends StatefulWidget {
  LoginPageUser({Key? key}) : super(key: key);

  @override
  _LoginPageUserState createState() => _LoginPageUserState();
}

class _LoginPageUserState extends State<LoginPageUser> {
  late AppColors _colors;
  late AppLocalizations l10n;
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
      await SessionUserFirebaseService.saveUserSession(user!.uid)

      .then((value) async {
        await SessionUserFirebaseService.updateLastActive().then((value) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => SplashChargement(),));
        },);

     },);


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
            backgroundColor: _colors.danger,
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
                Icon(Icons.email, size: 60, color: _colors.warning),
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
                    backgroundColor: _colors.warning,
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
                Icon(Icons.mark_email_read, size: 60, color: _colors.primary),
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
                    backgroundColor: _colors.primary,
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
    _colors = AppColors.of(context);
    l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: _colors.background,
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
                  _colors.background.withOpacity(0.9),
                  _colors.background,
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
            color: _colors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: IconButton(
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => SignUpScreen()));
            },
            icon: Icon(
              Icons.person_add_alt_1,
              color: _colors.primary,
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
            color: _colors.primary,
          ),
        ),
        SizedBox(height: 5),

        // Slogan
        Text(
          l10n.authSlogan,
          style: TextStyle(
            fontSize: min(16, MediaQuery.of(context).size.width * 0.04),
            color: _colors.textSecondary,
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
            style: TextStyle(color: _colors.textPrimary),
            decoration: InputDecoration(
              filled: true,
              fillColor: _colors.surfaceVariant,
              hintText: l10n.authEmail,
              hintStyle: TextStyle(color: _colors.textSecondary),
              prefixIcon: Icon(Icons.email_outlined, color: _colors.primary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide.none,
              ),
              contentPadding: EdgeInsets.symmetric(vertical: 15, horizontal: 20),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return l10n.authEmailRequired;
              }
              if (!isValidEmail(value)) {
                return l10n.authEmailInvalid;
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
            style: TextStyle(color: _colors.textPrimary),
            decoration: InputDecoration(
              filled: true,
              fillColor: _colors.surfaceVariant,
              hintText: l10n.authPassword,
              hintStyle: TextStyle(color: _colors.textSecondary),
              prefixIcon: Icon(Icons.lock_outline, color: _colors.primary),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: _colors.primary,
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
                return l10n.authPasswordRequired;
              }
              if (value.length < 6) {
                return l10n.authPasswordTooShort;
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
                l10n.authForgotPassword,
                style: TextStyle(
                  color: _colors.primary,
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
                backgroundColor: _colors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
                elevation: 0,
              ),
              child: _isLoading
                  ? LoadingAnimationWidget.threeRotatingDots(
                color: _colors.onPrimary,
                size: 24,
              )
                  : Text(
                l10n.authSignIn,
                style: TextStyle(
                  fontSize: min(16, MediaQuery.of(context).size.width * 0.04),
                  fontWeight: FontWeight.bold,
                  color: _colors.onPrimary,
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
                color: _colors.border,
                thickness: 1,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                "Ou",
                style: TextStyle(
                  color: _colors.textSecondary,
                ),
              ),
            ),
            Expanded(
              child: Divider(
                color: _colors.border,
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
                side: BorderSide(color: _colors.primary, width: 2),
              ),
              elevation: 0,
            ),
            child: Text(
              "Créer un compte",
              style: TextStyle(
                fontSize: min(16, MediaQuery.of(context).size.width * 0.04),
                fontWeight: FontWeight.bold,
                color: _colors.primary,
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
                color: _colors.border,
                thickness: 1,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                "Besoin d'aide?",
                style: TextStyle(
                  color: _colors.textSecondary,
                  fontSize: min(14, MediaQuery.of(context).size.width * 0.035),
                ),
              ),
            ),
            Expanded(
              child: Divider(
                color: _colors.border,
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
              side: BorderSide(color: _colors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.help_outline,
                  color: _colors.textSecondary,
                  size: 20,
                ),
                SizedBox(width: 10),
                Text(
                  "Nous contacter",
                  style: TextStyle(
                    fontSize: min(16, MediaQuery.of(context).size.width * 0.04),
                    fontWeight: FontWeight.bold,
                    color: _colors.textSecondary,
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





