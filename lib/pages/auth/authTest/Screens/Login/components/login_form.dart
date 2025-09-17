import 'package:contained_tab_bar_view_with_custom_page_navigator/contained_tab_bar_view_with_custom_page_navigator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:provider/provider.dart';

import '../../../../../../constant/constColors.dart';
import '../../../../../../constant/sizeButtons.dart';
import '../../../../../../constant/sizeText.dart';
import '../../../../../../constant/textCustom.dart';
import '../../../../../../providers/authProvider.dart';
import '../../../components/already_have_an_account_acheck.dart';
import '../../../constants.dart';
import '../../Signup/components/signup_form.dart';
import '../../Signup/signup_screen.dart';

class LoginForm extends StatefulWidget {
  LoginForm({
    Key? key,
  }) : super(key: key);

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  late UserAuthProvider authProvider =
  Provider.of<UserAuthProvider>(context, listen: false);

  final TextEditingController telephoneController = TextEditingController();

  final TextEditingController motDePasseController = TextEditingController();

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late bool onTap=false;
  late bool tap=false;
  late bool inputTap= false;
  final _auth = FirebaseAuth.instance;



  // string for displaying the error Message
  String? errorMessage;
  void signIn(String email, String password) async {
    setState(() {
      inputTap=false;
    });
    if (_formKey.currentState!.validate()) {
      setState(() {
        tap= true;
      });
      try {
        await _auth
            .signInWithEmailAndPassword(email: email, password: password)
            .then((uid) => {

          //serviceProvider.getLoginUser( _auth.currentUser!.uid!,context),


            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Connexion réussie',style: TextStyle(color: Colors.green),),
            ),),
        setState(() {
        onTap=false;
        telephoneController.clear();
        motDePasseController.clear();

        }),
            Navigator.pushNamed(
            context,
            '/home'),
        Navigator.pushNamed(context, '/chargement'),
          setState(() {
            tap= false;
          })


        });
      } on FirebaseAuthException catch (error) {
        setState(() {
          tap= false;
        });
        switch (error.code) {
          case "invalid-email":
            errorMessage = "Votre numero semble être malformée.";
            break;
          case "wrong-password":
            errorMessage = "Votre mot de passe est erroné.";
            break;
          case "user-not-found":
            errorMessage = "L'utilisateur avec cet numero n'existe pas.";
            break;
          case "user-disabled":
            errorMessage = "L'utilisateur avec cet numero a été désactivé.";
            break;
          case "too-many-requests":
            errorMessage = "Trop de demandes";
            break;
          case "operation-not-allowed":
            errorMessage =
            "La connexion avec le numero et un mot de passe n'est pas activée.";
            break;
          default:
            errorMessage = "Une erreur indéfinie s'est produite.";
        }
        SnackBar snackBar = SnackBar(
          content: Text(errorMessage.toString(),style: TextStyle(color: Colors.red),),
        );
            ScaffoldMessenger.of(context).showSnackBar(snackBar);
        print(error.code);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 25.0),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                IntlPhoneField(
                  //controller: telephoneController,
                  // invalidNumberMessage:'numero invalide' ,
                  onTap: () {},

                  cursorColor: kPrimaryColor,
                  decoration: InputDecoration(
                    hintText: 'Téléphone',
                    focusColor: kPrimaryColor,
                    focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: kPrimaryColor)),
                  ),
                  initialCountryCode: 'TG',
                  onChanged: (phone) {
                    telephoneController.text = phone.completeNumber;
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
                  controller: motDePasseController,
                  textInputAction: TextInputAction.done,
                  obscureText: true,
                  cursorColor: kPrimaryColor,
                  decoration: const InputDecoration(
                    focusColor: kPrimaryColor,
                    focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: kPrimaryColor)),
                    hintText: "Votre mot de passe",
                    prefixIcon: Padding(
                      padding: EdgeInsets.all(defaultPadding),
                      child: Icon(Icons.lock),
                    ),
                  ),
                  validator: (value) {
                    if (value!.isEmpty) {
                      return 'Le champ "Mot de passe" est obligatoire.';
                    }
                    if (value!.length < 6) {
                      return 'Le mot de passe doit comporter au moins 6 caractères.';
                    }
                    return null;
                  },
                ),
                SizedBox(height: height * 0.1),
                Container(
                  width: width*0.6,
                  child: ElevatedButton(
                    onPressed: tap?() { }:() {
                      setState(() {
                        tap=true;
                      });
                      if (_formKey.currentState!.validate()) {
                        // Afficher une SnackBar
                        print("phone ${telephoneController.text}");

                        if (telephoneController.text.isNotEmpty) {
                          signIn( telephoneController.text,motDePasseController.text);

                        } else {
                          SnackBar snackBar = SnackBar(
                            content: Text(
                              'phone number is not valide',
                              style: TextStyle(color: Colors.red),
                            ),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(snackBar);
                        }
                        setState(() {
                          tap=false;


                        });
                      }else{
                        setState(() {
                          tap=false;


                        });
                      }

                    },
                    child:tap? Center(
                      child: LoadingAnimationWidget.flickr(
                        size: 30,
                        leftDotColor: Colors.green,
                        rightDotColor: Colors.black,
                      ),
                    ): Text(
                      "Se connecter",
                      style: TextStyle(color: Colors.black),
                    ),
                  ),
                ),
                const SizedBox(height: defaultPadding),
                AlreadyHaveAnAccountCheck(
                  press: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) {
                          return  SignUpScreen();
                        },
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
