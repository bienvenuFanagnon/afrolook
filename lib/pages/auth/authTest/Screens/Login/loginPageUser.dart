
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'package:afrotok/pages/auth/authTest/Screens/Signup/signup_screen.dart';
import 'package:dropdown_search/dropdown_search.dart';
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

import '../../../update_pass_word/confirm_user.dart';
import '../../components/already_have_an_account_acheck.dart';
import '../../constants.dart';

class LoginPageUser extends StatefulWidget {
  LoginPageUser({
    Key? key,
  }) : super(key: key);

  @override
  State<LoginPageUser> createState() => _LoginPageUserState();
}

class _LoginPageUserState extends State<LoginPageUser> {
  final TextEditingController telephoneController = TextEditingController();
  late UserAuthProvider authProvider =
  Provider.of<UserAuthProvider>(context, listen: false);
  late UserProvider userProvider =
  Provider.of<UserProvider>(context, listen: false);

  final TextEditingController pseudoController = TextEditingController();

  final TextEditingController motDePasseController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  bool onTap=false;
  final TextEditingController code_parrainageController = TextEditingController();

  bool is_open=false;
  String? errorMessage;
  final _auth = FirebaseAuth.instance;
   signIn(String email, String password) async {

    if (_formKey.currentState!.validate()) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      try {
        await _auth
            .signInWithEmailAndPassword(email: email, password: password)
            .then((uid) async => {
          //serviceProvider.getLoginUser( _auth.currentUser!.uid!,context),

          await authProvider.getCurrentUser(uid.user!.uid!).then((value) async {
          //  PhoneVerification phoneverification = PhoneVerification(number:'22896198801' );

             //   phoneverification.sendotp('Your Otp');
            if (value) {

if(authProvider.loginUserData!=null ||authProvider.loginUserData.id!=null ||authProvider.loginUserData.id!.length>5){
  await authProvider.getAppData();
  await userProvider.getAllAnnonces();

  //print("app data2 : ${authProvider.appDefaultData.toJson()!}");
  // Obtenez les SharedPreferences
  userProvider.changeState(user: authProvider.loginUserData,
      state: UserState.ONLINE.name);
  prefs.setString('token', uid.user!.uid!);

  Navigator.pushReplacementNamed(
      context,
      '/home');
 // Navigator.pushNamed(context, '/chargement');


}


            }else{
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Erreur de Chargement',textAlign: TextAlign.center,style: TextStyle(color: Colors.red),),
            ),);
            }
          },),
            telephoneController.clear(),
            motDePasseController.clear(),
        });
      } on FirebaseAuthException catch (error) {

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
          case "invalid-credential":
          errorMessage = "information incorrecte";
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
          case "network-request-failed":
          errorMessage =
          "erreur de connexion.";
            break;
          default:
            errorMessage = "Une erreur indéfinie s'est produite.";
        }
        SnackBar snackBar = SnackBar(
          content: Text(errorMessage.toString(),textAlign: TextAlign.center,style: TextStyle(color: Colors.red),),
        );
        ScaffoldMessenger.of(context).showSnackBar(snackBar);
        print(error.code);
      }
    }
  }
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    is_open=false;

  }
  @override
  Widget build(BuildContext context) {
    double height = MediaQuery.of(context).size.height;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,

        title: Text("Connexion"),
        centerTitle: true,
      ),

      body: Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Center(
          child: Container(
            alignment: Alignment.center,
             height: height,
            child: ListView(
              children: [
               // SizedBox(height: height*0.1,),
                Padding(
                  padding:  EdgeInsets.only(top: height*0.08),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Image.asset('assets/logo/afrolook_logo.png',width: 100,),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Afrolook",style: TextStyle(fontSize: 20,color: Colors.green,fontWeight: FontWeight.w600)),
                          Text("Votre popularité est à la une",style: TextStyle(fontSize: 18,color: Colors.black54)),
                        ],
                      )
                    ],
                  ),
                ),
                SizedBox(height: height*0.06,),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Container(
                      alignment: Alignment.center,
                      height: height*0.5,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius:BorderRadius.all(Radius.circular(10))
                      ),
                      child: Form(
                        key: _formKey,
                        child: Padding(
                          padding: const EdgeInsets.all(25.0),
                          child: ListView(
                            children: [

                              SizedBox(height: height*0.005,),
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
                                keyboardType: TextInputType.visiblePassword,
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
                                  if (value!.length < 6) {
                                    return 'Le mot de passe doit comporter au moins 6 caractères.';
                                  }
                                  return null;
                                },
                              ),
                              SizedBox(height: height*0.01),
                              TextButton(onPressed: () {
                                Navigator.push(context, MaterialPageRoute(builder: (context) => ConfirmUser(),));

                              }, child:  Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text("Mot de passe oublier? Connecter sans mot de passe",textAlign: TextAlign.center,),
                              ),),


                              SizedBox(height: height*0.02),
                              Container(
                                width: SizeButtons.loginAndSignupBtnlargeur,
                                child: ElevatedButton(
                                  onPressed:onTap?() async { }:
                                      () async {

                                    if (_formKey.currentState!.validate()) {
                                      setState(() {
                                        onTap=true;
                                        print("on tap");
                                      });
                                      // Afficher une SnackBar
                                      try{
                                        await  signIn( '${telephoneController.text}@gmail.com',motDePasseController.text);

                                      }catch(e){
                                        print("Erreur connextion ---------------");
                                        print(e);
                                        setState(() {
                                          onTap=false;
                                          print("on tap");
                                        });
                                      }



                                    }

                                    setState(() {
                                     onTap=false;
                                    });


                                  },
                                  child:onTap? Center(
                                    child: LoadingAnimationWidget.flickr(
                                      size: 30,
                                      leftDotColor: Colors.green,
                                      rightDotColor: Colors.black,
                                    ),
                                  ): Text("Se Connecter",
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
                              SizedBox(height: height*0.02),

                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}




