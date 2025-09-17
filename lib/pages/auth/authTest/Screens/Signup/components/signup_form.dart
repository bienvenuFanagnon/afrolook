import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:provider/provider.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';

import '../../../../../../models/model_data.dart';
import '../../../../../../providers/authProvider.dart';
import '../../../../../../providers/userProvider.dart';
import '../../Login/loginPageUser.dart';
import '../signup_up_form_step_2.dart';

// Couleurs de base
const Color primaryGreen = Color(0xFF25D366);
const Color darkBackground = Color(0xFF121212);
const Color lightBackground = Color(0xFF1E1E1E);
const Color textColor = Colors.white;

class SignUpScreen extends StatefulWidget {
  SignUpScreen({Key? key}) : super(key: key);

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final TextEditingController telephoneController = TextEditingController();
  final TextEditingController pseudoController = TextEditingController();
  final TextEditingController motDePasseController = TextEditingController();
  final TextEditingController code_parrainageController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  bool onTap = false;
  bool is_open = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  final List<String> genres = ['Homme', 'Femme'];
  String? selectedGenre;

  int genererNombreAleatoire() {
    Random random = Random();
    return random.nextInt(100000);
  }

  Future<bool> verifierPseudo(String nom) async {
    CollectionReference pseudos = firestore.collection("Pseudo");
    QuerySnapshot snapshot = await pseudos.get();
    final list = snapshot.docs.map((doc) =>
        UserPseudo.fromJson(doc.data() as Map<String, dynamic>)).toList();
    bool existe = list.any((e) => e.name!.toLowerCase() == nom.toLowerCase());

    if (!existe) {
      try {
        return false;
      } on FirebaseException catch(error) {
        return true;
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Le pseudo existe déjà", style: TextStyle(color: Colors.red)),
        ),
      );
      return true;
    }
  }

  bool isValidEmail(String email) {
    final RegExp emailRegExp = RegExp(
        r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$");
    return emailRegExp.hasMatch(email);
  }
  late UserAuthProvider authProvider =
  Provider.of<UserAuthProvider>(context, listen: false);
  late UserProvider userProvider =
  Provider.of<UserProvider>(context, listen: false);
  @override
  void initState() {
    super.initState();
    authProvider.initializeData();
    is_open = false;
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
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 20),

              // Titre
              Text(
                "Créer un compte",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              SizedBox(height: 5),
              Text(
                "Rejoignez la communauté Afrolook",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[400],
                ),
              ),
              SizedBox(height: 30),

              // Formulaire
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Champ téléphone
                    Container(
                      decoration: BoxDecoration(
                        color: lightBackground,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: IntlPhoneField(
                        onChanged: (phone) {
                          telephoneController.text = phone.completeNumber;
                        },
                        decoration: InputDecoration(
                          hintText: 'Numéro de téléphone',
                          hintStyle: TextStyle(color: Colors.grey[500]),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: EdgeInsets.symmetric(vertical: 15),
                        ),
                        initialCountryCode: 'TG',
                        style: TextStyle(color: textColor),
                        dropdownTextStyle: TextStyle(color: textColor),
                        validator: (value) {
                          if (value == null || value.number.isEmpty) {
                            return 'Le champ "Téléphone" est obligatoire.';
                          }
                          return null;
                        },
                      ),
                    ),
                    SizedBox(height: 15),

                    // Champ code parrainage
                    _buildTextField(
                      controller: code_parrainageController,
                      hintText: "Code de parrainage (optionnel)",
                      prefixIcon: Icons.person_add_alt_1_outlined,
                    ),
                    SizedBox(height: 15),

                    // Champ email
                    _buildTextField(
                      controller: emailController,
                      hintText: "Adresse email",
                      keyboardType: TextInputType.emailAddress,
                      prefixIcon: Icons.email_outlined,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Le champ "Email" est obligatoire.';
                        }
                        if (!isValidEmail(value)) {
                          return 'Email invalide';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 15),

                    // Champ pseudo
                    _buildTextField(
                      controller: pseudoController,
                      hintText: "Pseudo (unique)",
                      prefixIcon: Icons.person_outline,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Le champ "Pseudo" est obligatoire.';
                        }
                        if (value.length < 3) {
                          return 'Le pseudo doit comporter au moins 3 caractères.';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 15),

                    // Sélecteur de genre
                    Container(
                      decoration: BoxDecoration(
                        color: lightBackground,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      padding: EdgeInsets.symmetric(horizontal: 15),
                      child: DropdownButtonFormField<String>(
                        value: selectedGenre,
                        dropdownColor: lightBackground,
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Genre',
                          hintStyle: TextStyle(color: Colors.grey[500]),
                          prefixIcon: Icon(Icons.person_outline, color: primaryGreen),
                        ),
                        items: genres.map((genre) {
                          return DropdownMenuItem(
                            value: genre,
                            child: Text(genre, style: TextStyle(color: textColor)),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            selectedGenre = newValue;
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Le champ "genre" est obligatoire.';
                          }
                          return null;
                        },
                      ),
                    ),
                    SizedBox(height: 15),

                    // Champ mot de passe
                    _buildPasswordField(
                      controller: motDePasseController,
                      hintText: "Mot de passe",
                      obscureText: _obscurePassword,
                      onToggle: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Le champ "Mot de passe" est obligatoire.';
                        }
                        if (value.length < 8) {
                          return 'Le mot de passe doit comporter au moins 8 caractères.';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 15),

                    // Champ confirmation mot de passe
                    _buildPasswordField(
                      controller: TextEditingController(),
                      hintText: "Confirmer le mot de passe",
                      obscureText: _obscureConfirmPassword,
                      onToggle: () {
                        setState(() {
                          _obscureConfirmPassword = !_obscureConfirmPassword;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Le champ "Confirmer Mot de passe" est obligatoire.';
                        }
                        if (value.length < 8) {
                          return 'Le mot de passe doit comporter au moins 8 caractères.';
                        }
                        if (value != motDePasseController.text) {
                          return 'Les mots de passe ne correspondent pas';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 30),

                    // Bouton suivant
                    Container(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: onTap ? null : () async {
                          if (_formKey.currentState!.validate()) {
                            setState(() => onTap = true);

                            if (!await verifierPseudo(pseudoController.text)) {
                              await authProvider.getAppData();
                              authProvider.initializeData();
                              authProvider.registerUser.numeroDeTelephone = telephoneController.text;
                              authProvider.registerUser.codeParrain = code_parrainageController.text;
                              authProvider.registerUser.codeParrainage = "${pseudoController.text}${genererNombreAleatoire()}";
                              authProvider.registerUser.pseudo = pseudoController.text;
                              authProvider.registerUser.genre = selectedGenre;
                              authProvider.registerUser.password = motDePasseController.text;
                              authProvider.registerUser.email = emailController.text;

                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => SignUpFormEtap3()),
                              );
                            }
                            setState(() => onTap = false);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryGreen,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                        child: onTap
                            ? LoadingAnimationWidget.threeRotatingDots(
                          color: Colors.white,
                          size: 24,
                        )
                            : Text(
                          "Suivant",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 20),

                    // Lien de connexion
                    Row(
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
                    ),
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData prefixIcon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
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

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String hintText,
    required bool obscureText,
    required VoidCallback onToggle,
    required String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      style: TextStyle(color: textColor),
      decoration: InputDecoration(
        filled: true,
        fillColor: lightBackground,
        hintText: hintText,
        hintStyle: TextStyle(color: Colors.grey[500]),
        prefixIcon: Icon(Icons.lock_outline, color: primaryGreen),
        suffixIcon: IconButton(
          icon: Icon(
            obscureText ? Icons.visibility_off : Icons.visibility,
            color: primaryGreen,
          ),
          onPressed: onToggle,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
        contentPadding: EdgeInsets.symmetric(vertical: 15, horizontal: 20),
      ),
      validator: validator,
    );
  }
}