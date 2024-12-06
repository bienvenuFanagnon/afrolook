import 'dart:convert';
import 'dart:math';
import 'package:afrotok/pages/auth/authTest/Screens/Signup/signup_up_form_step_2.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as Path;
import 'package:afrotok/constant/constColors.dart';
import 'package:afrotok/pages/auth/authTest/Screens/Login/loginPage.dart';
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
class SignUpFormEtap2 extends StatefulWidget {
  final File imageFile;
  SignUpFormEtap2({
    Key? key, required this.imageFile,
  }) : super(key: key);

  @override
  State<SignUpFormEtap2> createState() => _SignUpFormEtap2State();
}

class _SignUpFormEtap2State extends State<SignUpFormEtap2> {
  late UserAuthProvider authProvider =
  Provider.of<UserAuthProvider>(context, listen: false);
  final TextEditingController aproposController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late List<UserGlobalTag> listGlobaltags = [];
  late List<String> listGlobaltagString = [];
  late List<String> content = [];
  late List<int> tagsIds = [];
  late bool onTaps=false;
  String? errorMessage;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  late bool tap= false;
  final _auth = FirebaseAuth.instance;
  Future<void> verifierParrain(String codeParrain) async {


    // Récupérer la liste des utilisateurs
    CollectionReference appdatacollection = firestore.collection('Appdata');
    CollectionReference users = firestore.collection("Users");
    QuerySnapshot snapshot = await users.get();
    final list = snapshot.docs.map((doc) =>
        UserData.fromJson(doc.data() as Map<String, dynamic>)).toList();
    bool existe= list.any((e) => e.codeParrainage==codeParrain);
    // Vérifier si le nom existe déjà
    //  bool existe = snapshot.docs.any((doc) => doc.data["nom"] == nom);

    if (existe) {
      await authProvider.getAppData();

        authProvider.registerUser!.pointContribution=authProvider.registerUser!.pointContribution! + authProvider.appDefaultData.default_point_new_user!;
       list.forEach((element) async {
          if (element.codeParrainage==codeParrain) {
            element.pointContribution=element.pointContribution! + authProvider.appDefaultData.default_point_new_user!;
            printVm("update user data loading : ${element.toJson()}");
            await firestore.collection('Users').doc(element.id!).update(element.toJson());
            printVm("update user data");
          }  
        },);



    }
  }
  void signUp(String email, String password) async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        tap= true;
      });



      try {
        await _auth
            .createUserWithEmailAndPassword(email: email, password: password)
            .then((value) => {

          postDetailsToFirestore(value.user!.uid!),
          setState(() {
            tap= false;
          }),
        }).catchError((e) {

          SnackBar snackBar = SnackBar(
            content: Text("Une erreur s'est produite",style: TextStyle(color: Colors.red),),
          );
          ScaffoldMessenger.of(context).showSnackBar(snackBar);
          printVm('error ${e!.message}');
          setState(() {
            tap= false;
          });

        });
        setState(() {
          tap= false;
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
          content: Text('${errorMessage}',style: TextStyle(color: Colors.red),),
        );
        ScaffoldMessenger.of(context).showSnackBar(snackBar);

        printVm(error.code);
        setState(() {
          tap= false;
        });
      }




    }
  }
  postDetailsToFirestore(String id) async {

    authProvider.registerUser.role = UserRole.USER.name!;
    authProvider.registerUser.updatedAt =
        DateTime.now().microsecondsSinceEpoch;
    authProvider.registerUser.createdAt =
        DateTime.now().microsecondsSinceEpoch;
    try{
      await verifierParrain( authProvider.registerUser.codeParrain!);

      authProvider.registerUser.id =id;
      await firestore.collection('Users').doc(id).set( authProvider.registerUser.toJson());

      authProvider.appDefaultData.nbr_abonnes=authProvider.appDefaultData.nbr_abonnes!+1;
      if (authProvider.appDefaultData.users_id!.any((element) => element==id)==false) {
        authProvider.appDefaultData.users_id!.add(id);
      }
      await firestore.collection('AppData').doc( authProvider.appDefaultData.id!).update( authProvider.appDefaultData.toJson());

      SnackBar snackBar = SnackBar(
        content: Text('Compte créé avec succès !',style: TextStyle(color: Colors.green),),
      );
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
      Navigator.pop(context);
      Navigator.pushNamed(context, '/bon_a_savoir');



    } on FirebaseException catch(error){

      SnackBar snackBar = SnackBar(
        content: Text('${error}',style: TextStyle(color: Colors.red),),
      );
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
      printVm('error ${error}');
    }
    setState(() {
      tap= false;
    });

  }
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    tagsIds = [];
    content = [];
    listGlobaltagString = authProvider.listUserGlobalTagString;
  }
  @override
  Widget build(BuildContext context) {
    double height = MediaQuery.of(context).size.height;
    // authProvider.getUserGlobalTags();
    listGlobaltagString = authProvider.listUserGlobalTagString;
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(15),
        child:SingleChildScrollView(
          //height: height*1.1,
          child: Column(

            children: [
              SizedBox(height: 50,),
              SignUpScreenTopImage(),
              SizedBox(height: 50,),
              Text(
                'À propos de toi :',
                style: TextStyle(fontSize: 15.0, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8.0),
              Form(
                key: _formKey,
                child: TextFormField(
                  controller: aproposController,
                  maxLines: 3, // Permet à l'utilisateur de saisir plusieurs lignes
                  decoration: InputDecoration(
                    border: OutlineInputBorder(), // Ajoute une bordure autour du champ de texte
                  ),
                  validator: (value) {
                    printVm('apropos $value');

                  },
                ),
              ),
              SizedBox(
                height: 30,
              ),
              Text(
                'En créant ce compte, vous acceptez les termes et conditions.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16.0),
              ),
              SizedBox(
                height: 5,
              ),


              SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 150,
                    child: ElevatedButton(
                      onPressed: () {

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) {
                              return SignUpFormEtap3();
                            },
                          ),
                        );


                      },
                      child: Padding(
                        padding: const EdgeInsets.all(2.0),
                        child: Row(
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(right: 5.0),
                              child: Icon(Icons.arrow_back_ios_new_rounded),
                            ),
                            Text("Précédent",
                              style: TextStyle(color: Colors.black),

                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Container(
                    width: 150,
                    child: ElevatedButton(
                      onPressed:tap?() {
                      }: ()  {

                        if (_formKey.currentState!.validate()) {

                          authProvider.registerUser.apropos=aproposController.text;
                          authProvider.registerUser.userGlobalTags=tagsIds.toSet().toList();
                          // Afficher une SnackBar
                          signUp('${authProvider.registerUser.numeroDeTelephone!}@gmail.com',authProvider.registerUser.password!);

                        }else{
                          setState(() {
                            tap=false;
                          });
                        }
                      },
                      child: tap? Center(
                        child: LoadingAnimationWidget.flickr(
                          size: 30,
                          leftDotColor: Colors.green,
                          rightDotColor: Colors.black,
                        ),
                      ):Text("S'inscrire",
                        style: TextStyle(color: Colors.black),

                      ),
                    ),
                  ),
                ],
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
    );
  }
}