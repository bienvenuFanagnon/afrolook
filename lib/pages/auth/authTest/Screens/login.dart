

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:provider/provider.dart';

import '../../../../../providers/authProvider.dart';

import '../components/already_have_an_account_acheck.dart';
import '../constants.dart';
import 'Login/components/login_screen_top_image.dart';
import 'Signup/components/signup_form.dart';
import 'Signup/signup_screen.dart';


class LoginPages extends StatefulWidget {

  LoginPages({
    Key? key,
  }) : super(key: key);
  @override
  State<LoginPages> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPages> {
  late UserAuthProvider authProvider =
  Provider.of<UserAuthProvider>(context, listen: false);

  late TextEditingController telephoneController = TextEditingController();

  late TextEditingController motDePasseController = TextEditingController();

  late GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late bool onboutonTap=false;

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
            .then((uid) async => {

          //serviceProvider.getLoginUser( _auth.currentUser!.uid!,context),




          if (await authProvider.getLoginUser(uid.user!.uid!)) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Connexion réussie',textAlign: TextAlign.center,style: TextStyle(color: Colors.green),),
            ),),
            Navigator.pushNamed(
                context,
                '/home'),
            Navigator.pushNamed(context, '/chargement'),
          }else{
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Erreur de Chargement',textAlign: TextAlign.center,style: TextStyle(color: Colors.red),),
            ),),
          },

          setState(() {

            telephoneController.clear();
            motDePasseController.clear();
            tap= false;

          }),

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
    print("loading");
    return  Scaffold(

      body: Padding(
        padding: const EdgeInsets.all(15.0),
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: SizedBox(
            height: height,
            width: width,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children:[
                LoginScreenTopImage(),
                Spacer(),
                Expanded(
                  flex: 8,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 25.0,left: 25,right: 25),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              IntlPhoneField(
                                //controller: telephoneController,
                                // invalidNumberMessage:'numero invalide' ,
                                //onTap: () {},

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
                                width: width*0.7,
                                child: ElevatedButton(
                                  onPressed: tap?() { }:() {
                                    setState(() {
                                      tap=true;
                                    });
                                    if (_formKey.currentState!.validate()) {
                                      // Afficher une SnackBar
                                      print("phone ${telephoneController.text}");

                                      if (telephoneController.text.isNotEmpty) {
                                        signIn( '${telephoneController.text}@gmail.com',motDePasseController.text);

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
                  ),
                ),
                Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
