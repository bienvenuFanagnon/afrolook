import 'dart:math';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:encrypt_decrypt_plus/cipher/cipher.dart';
//import 'package:encrypt/encrypt.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as Path;
import 'package:encrypt_decrypt_plus/encrypt_decrypt_plus.dart';
import 'package:afrotok/pages/auth/authTest/Screens/Signup/signup_up_form_step_2.dart';

import 'package:flutter_vector_icons/flutter_vector_icons.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:provider/provider.dart';
import 'package:simple_tags/simple_tags.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import '../../../../../../constant/sizeButtons.dart';
import '../../../../../../models/model_data.dart';

import '../../../../../../providers/authProvider.dart';
import '../../../components/already_have_an_account_acheck.dart';
import '../../../constants.dart';
import 'dart:async';
import 'dart:io';

import '../../Login/loginPageUser.dart';

import '../function.dart';
import '../verificationOtps.dart';

class SignUpFormEtap1 extends StatefulWidget {
   SignUpFormEtap1({
    Key? key,
  }) : super(key: key);

  @override
  State<SignUpFormEtap1> createState() => _SignUpFormEtap1State();
}

class _SignUpFormEtap1State extends State<SignUpFormEtap1> {
  final TextEditingController telephoneController = TextEditingController();
  late UserAuthProvider authProvider =
  Provider.of<UserAuthProvider>(context, listen: false);

  final TextEditingController pseudoController = TextEditingController();

  final TextEditingController motDePasseController = TextEditingController();
  final TextEditingController code_parrainageController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  bool onTap=false;
  bool is_open=false;

  showErrorDialog(BuildContext context,String text) {
    AwesomeDialog(
      context: context,
      animType: AnimType.leftSlide,
      headerAnimationLoop: true,
      dialogType: DialogType.error,
      showCloseIcon: true,
      title: "Envoi code SMS",
      desc:
      text,
      btnCancelOnPress: () {
        debugPrint('OnClcik');
      },
      btnOkIcon: Icons.error,
      onDismissCallback: (type) {
        debugPrint('Dialog Dissmiss from callback $type');
      },
    ).show();

  }
  void
  sendOtpCode() {

    final _auth = FirebaseAuth.instance;
    if (telephoneController.text.isNotEmpty) {

     // notData=false;

      authWithPhoneNumber(telephoneController.text, onCodeSend: (verificationId, v) {
        onTap = false;
        setState(() {});
        Navigator.of(context).push(MaterialPageRoute(
            builder: (c) => VerificationOtp(
              verificationId: verificationId,
              phoneNumber: telephoneController.text,
            )));
      }, onAutoVerify: (v) async {
        await _auth.signInWithCredential(v);

        Navigator.of(context).pop();
      },  onFailed: (e) {
        onTap = false;
        setState(() {});
        var errorMessage = "An error occurred";
        switch (e.code) {
          case 'invalid-phone-number':
            errorMessage = 'Le numéro de téléphone saisi est invalide.';
            break;
          case 'too-many-requests':
            errorMessage = 'Vous avez fait trop de demandes. Veuillez réessayer plus tard.';
            break;
          default:
            errorMessage = 'Une erreur inconnue est survenue. Veuillez réessayer plus tard';
        //errorMessage = e.toString();
        }
        showErrorDialog( context, errorMessage);
        print(" erreur : ${e.toString()}");
      }, autoRetrieval: (v) {});
    }else{
      onTap = false;
     // notData=true;
      setState(() {

      });
    }
  }
  int genererNombreAleatoire() {
    // Générer un nombre aléatoire entre 0 et 99999
    Random random = Random();
    int nombreAleatoire = random.nextInt(100000);

    // Retourner le nombre aléatoire
    return nombreAleatoire;
  }
  Future<bool> verifierPseudo(String nom) async {


    // Récupérer la liste des utilisateurs
    CollectionReference pseudos = firestore.collection("Pseudo");
    QuerySnapshot snapshot = await pseudos.get();
   final list = snapshot.docs.map((doc) =>
        UserPseudo.fromJson(doc.data() as Map<String, dynamic>)).toList();
    bool existe= list.any((e) => e.name!.toLowerCase()==nom.toLowerCase());
    // Vérifier si le nom existe déjà
  //  bool existe = snapshot.docs.any((doc) => doc.data["nom"] == nom);

    if (!existe) {

      try{



        return false;
      } on FirebaseException catch(error){
        return true;
      }
      // Le nom n'existe pas, créer un nouveau document


    } else {
      // Le nom existe déjà, afficher un message d'erreur
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Le pseudo existe déjà",style: TextStyle(color: Colors.red),),
        ),
      );
      return true;
    }
  }
@override
  void initState() {
    // TODO: implement initState
    super.initState();
    //telephoneController.text ='';
    authProvider.initializeData();
    is_open=false;

  }
  @override
  Widget build(BuildContext context) {
    double height = MediaQuery.of(context).size.height;

    return Scaffold(

      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all( 10),
          child: Container(
           // height: height*1.1,
            child: Container(
              alignment: Alignment.center,
           //   height: height*0.6,
              decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius:BorderRadius.all(Radius.circular(10))
              ),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                    //  SizedBox(height: 30,),
                      IntlPhoneField(
                        //controller: telephoneController,
                       // invalidNumberMessage:'numero invalide' ,
                        onTap: () {

                        },

                        cursorColor: kPrimaryColor,
                        decoration: InputDecoration(
                          hintText: 'Téléphone',
                          focusColor: kPrimaryColor,
                          focusedBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: kPrimaryColor)),

                        ),
                        initialCountryCode: 'TG',
                        onChanged: (phone) {
                          telephoneController.text=phone.completeNumber;
                          print(phone.completeNumber);
                        },
                        onCountryChanged: (country) {
                          print('Country changed to: ' + country.name);
                        },
                        validator: (value) {
                          if (value!.completeNumber.isEmpty) {
                            return 'Le champ "Téléphone" est obligatoire.';
                          }

                          return null;
                        },

                      ),
                      TextFormField(
                        controller: code_parrainageController,
                        keyboardType: TextInputType.text,
                        textInputAction: TextInputAction.next,
                        cursorColor: kPrimaryColor,

                        onSaved: (email) {},
                        decoration: const InputDecoration(
                          focusColor: kPrimaryColor,
                          focusedBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: kPrimaryColor)),
                          hintText: "Code de parrainage(optionel)",
                          prefixIcon: Padding(
                            padding: EdgeInsets.all(defaultPadding),
                            child: Icon(Icons.person),
                          ),
                        ),
                      ),

                      TextFormField(
                        controller: pseudoController,
                        keyboardType: TextInputType.text,
                        textInputAction: TextInputAction.next,
                        cursorColor: kPrimaryColor,
                        validator: (value)  {
                          if (value!.isEmpty) {
                            return 'Le champ "Pseudo" est obligatoire.';
                          }
                          if (value!.length < 3) {
                            return 'Le pseudo doit comporter au moins 3 caractères.';
                          }
                          return null;
                        },
                        onSaved: (email) {},
                        decoration: const InputDecoration(
                          focusColor: kPrimaryColor,
                          focusedBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: kPrimaryColor)),
                          hintText: "Pseudo(unique)",
                          prefixIcon: Padding(
                            padding: EdgeInsets.all(defaultPadding),
                            child: Icon(Icons.person),
                          ),
                        ),
                      ),


                      TextFormField(
                        controller: motDePasseController,
                        textInputAction: TextInputAction.done,
                        obscureText: !is_open,
                        cursorColor: kPrimaryColor,
                        decoration:  InputDecoration(
                          focusColor: kPrimaryColor,
                          focusedBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: kPrimaryColor)),
                          hintText: "Votre mot de passe",
                          prefixIcon: Padding(
                            padding: EdgeInsets.all(defaultPadding),
                            child: Icon(Icons.lock),
                          ),

                          suffixIcon: GestureDetector(
                            onTap: () {
                              setState(() {
                                is_open=!is_open;

                              });
                            },
                            child: is_open? Icon(Entypo.eye):Icon(Entypo.eye_with_line),
                          ),
                        ),

                        validator: (value) {
                          if (value!.isEmpty) {
                            return 'Le champ "Mot de passe" est obligatoire.';
                          }
                          if (value!.length < 8) {
                            return 'Le mot de passe doit comporter au moins 8 caractères.';
                          }
                          return null;
                        },
                      ),
                      TextFormField(
                        textInputAction: TextInputAction.done,
                        obscureText: !is_open,
                        cursorColor: kPrimaryColor,
                        decoration:  InputDecoration(
                          focusColor: kPrimaryColor,
                          focusedBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: kPrimaryColor)),
                          hintText: "Confirmer mot de passe",
                          prefixIcon: Padding(
                            padding: EdgeInsets.all(defaultPadding),
                            child: Icon(Icons.lock),
                          ),
                          suffixIcon: GestureDetector(
                            onTap: () {
                              setState(() {
                                is_open=!is_open;

                              });
                            },
                            child: is_open? Icon(Entypo.eye):Icon(Entypo.eye_with_line),
                          ),

                        ),
                        validator: (value) {
                          if (value!.isEmpty) {
                            return 'Le champ "Confirmer Mot de passe" est obligatoire.';
                          }
                          if (value!.length < 8) {
                            return 'Le mot de passe doit comporter au moins 8 caractères.';
                          }
                          if (value != motDePasseController.text) {
                            return 'Les mots de passe ne correspondent pas';
                          }
                          return null;
                        },
                      ),
                       SizedBox(height: 50),
                      Container(
                        width: SizeButtons.loginAndSignupBtnlargeur,
                        child: ElevatedButton(
                          onPressed:onTap?() async { }:
                              () async {
                      
                              //  print(encrypted.base64);

                            if (_formKey.currentState!.validate()) {
                              setState(() {
                                onTap=true;
                              });
                              // Afficher une SnackBar
                              if (!await verifierPseudo(pseudoController.text)) {
                                await authProvider.getAppData();

                                authProvider.initializeData();
                                authProvider.registerUser.numeroDeTelephone=telephoneController.text;
                                authProvider.registerUser.codeParrain=code_parrainageController.text;
                                authProvider.registerUser.codeParrainage="${pseudoController.text}${genererNombreAleatoire()}";
                                authProvider.registerUser.pseudo=pseudoController.text;
                                authProvider.registerUser.password=motDePasseController.text;
                                //authProvider.registerUser.password=authProvider.encrypt(motDePasseController.text);
                                // sendOtpCode();
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) {
                                      return SignUpFormEtap3();
                                    },
                                  ),
                                );



                              }else{
                                setState(() {
                                  onTap=false;
                                });
                              }


                            }else{
                              setState(() {
                                onTap=false;
                              });

                            }




                          },
                          child:onTap? Center(
                            child: LoadingAnimationWidget.flickr(
                              size: 30,
                              leftDotColor: Colors.green,
                              rightDotColor: Colors.black,
                            ),
                          ): Text("Suivant",
                              style: TextStyle(color: Colors.black),

                        ),
                        ),
                      ),
                      const SizedBox(height: defaultPadding),
                      AlreadyHaveAnAccountCheck(
                        login: false,
                        press: () {

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) {
                                return  LoginPageUser();
                              },
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}




