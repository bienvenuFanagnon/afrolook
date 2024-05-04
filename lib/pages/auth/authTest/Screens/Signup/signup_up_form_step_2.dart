import 'dart:convert';
import 'dart:math';
import 'package:afrotok/pages/auth/authTest/Screens/Signup/signup_up_form_step_3.dart';
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

import '../../components/already_have_an_account_acheck.dart';
import '../../constants.dart';
import '../Login/loginPageUser.dart';
import '../login.dart';
import 'components/signup_form.dart';
class SignUpFormEtap3 extends StatefulWidget {

  SignUpFormEtap3({
    Key? key,
  }) : super(key: key);

  @override
  State<SignUpFormEtap3> createState() => _SignUpFormEtap3State();
}

class _SignUpFormEtap3State extends State<SignUpFormEtap3> {
  String? _currentAddress='';
  late String? address='';
  late UserAuthProvider authProvider =
  Provider.of<UserAuthProvider>(context, listen: false);
  final TextEditingController nomController = TextEditingController();

  final TextEditingController prenomController = TextEditingController();

  final TextEditingController adresseController = TextEditingController();
  final TextEditingController genreController = TextEditingController();

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  Position? _currentPosition;
  late bool adreseLoging=false;
  late String? subAdministrativeArea='';
  late String? country='';
  late String? name='';
  bool edit = false;
  bool onTap = false;

  final TextEditingController aproposController = TextEditingController();
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
          print("update user data loading : ${element.toJson()}");
          await firestore.collection('Users').doc(element.id!).update(element.toJson());
          print("update user data");
        }
      },);



    }
  }

  Future<bool> _handleLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Location services are disabled. Please enable the services')));
      return false;
    }
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are denied')));
        return false;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Location permissions are permanently denied, we cannot request permissions.')));
      return false;
    }
    return true;
  }
  Future<void> _getAddressFromLatLng(Position position) async {
    await placemarkFromCoordinates(
        _currentPosition!.latitude, _currentPosition!.longitude)
        .then((List<Placemark> placemarks) async {
      Placemark place = await placemarks.first;
      setState(() {
        authProvider.registerUser.latitude=_currentPosition!.latitude;
        authProvider.registerUser.longitude=_currentPosition!.longitude;
        _currentAddress =
        '${place.subAdministrativeArea}, ${place.country}';
        adresseController.text=_currentAddress!;
        subAdministrativeArea=place.subAdministrativeArea;
        country=place.country;
        name=place.name;
        authProvider.registerUser.userPays=UserPays();
        authProvider.registerUser.userPays!.subAdministrativeArea=subAdministrativeArea;
        authProvider.registerUser.userPays!.name=country;
        authProvider.registerUser.userPays!.placeName=name;
        String adress=_currentAddress!;
      });
    }).catchError((e) {
      debugPrint(e);
    });
  }
  Future<void> _getCurrentPosition() async {
    final hasPermission = await _handleLocationPermission();

    if (!hasPermission) return;
    setState(() {
      adreseLoging=true;
    });
    await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high)
        .then((Position position) {
      setState(() => _currentPosition = position);
      _getAddressFromLatLng(_currentPosition!);

      print("Adresse: $_currentAddress");
      setState(() {
        adreseLoging=false;
      });

    }).catchError((e) {
      debugPrint(e);
      setState(() {
        adreseLoging=false;
      });
    });
  }

  File? _image;
  // ignore: unused_field
  PickedFile? _pickedFile;
  final _picker = ImagePicker();

  String? getStringImage(File? file) {
    if (file == null) return null;
    return base64Encode(file.readAsBytesSync());
  }


  Future getImage() async {
    // ignore: deprecated_member_use, no_leading_underscores_for_local_identifiers
    final _pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (_pickedFile != null){
      setState(() {
        _image = File(_pickedFile.path);
      });
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
            backgroundColor: Colors.red,
            content: Text("Une erreur s'est produite",style: TextStyle(color: Colors.white),),
          );
          ScaffoldMessenger.of(context).showSnackBar(snackBar);
          print('error ${e!.message}');
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

        print(error.code);
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
      UserPseudo pseudo=UserPseudo();
      pseudo.id=firestore
          .collection('Pseudo')
          .doc()
          .id;
      pseudo.name=authProvider.registerUser.pseudo;

      // users.add(pseudo.toJson());

      await firestore.collection('Pseudo').doc(pseudo.id).set(pseudo.toJson());
      print("///////////-- save pseudo --///////////////");
      await firestore.collection('AppData').doc( authProvider.appDefaultData.id!).update( authProvider.appDefaultData.toJson());

      SnackBar snackBar = SnackBar(
        backgroundColor: Colors.green,
        content: Text('Compte créé avec succès !',style: TextStyle(color: Colors.white),),
      );
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
      Navigator.pop(context);
      Navigator.pushNamed(context, '/bon_a_savoir');



    } on FirebaseException catch(error){

      SnackBar snackBar = SnackBar(
        content: Text('${error}',style: TextStyle(color: Colors.red),),
      );
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
      print('error ${error}');
    }
    setState(() {
      tap= false;
    });

  }


  //Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);

  @override
  Widget build(BuildContext context) {
    double height = MediaQuery.of(context).size.height;
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(15),
        child: SingleChildScrollView(
          //height: height*1.1,
          child: Column(
            children: [
              SizedBox(height: 50,),
              SignUpScreenTopImage(),
              SizedBox(height: 40,),
              Container(
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
                        Text("Votre photo"),

                        Container(
                          alignment: Alignment.center,
                          // height: 200,
                          //width: largeur,
                          child: Stack(
                            children: [
                              Container(
                                height: 85,
                                width: 85,
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.all(Radius.circular(200)),
                                    border: Border.all(width: 3, color: ConstColors.buttonsColors)),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.all(Radius.circular(200)),
                                  child: Container(
                                    height: 80,
                                    width: 80,
                                    child: Padding(
                                        padding: const EdgeInsets.all(4.0),
                                        child: _image == null
                                            ? CircleAvatar(


                                          backgroundImage: AssetImage('assets/icon/user-removebg-preview.png',),

                                        )
                                            :CircleAvatar(
                                          foregroundImage: FileImage(File(_image!.path),),

                                          backgroundImage: AssetImage('assets/icon/user-removebg-preview.png',),

                                        )
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 50,
                                left: 50,
                                child: Container(
                                  alignment: Alignment.center,
                                  child: Center(
                                      child: IconButton(
                                        onPressed:() async {
                                          // selectedImagePath = await _pickImage();
                                          await  getImage();

                                        } ,
                                        icon: Icon(
                                          Icons.edit,
                                          size: 50,
                                          color: Colors.black,
                                        ),
                                      )),
                                ),
                              )
                            ],
                          ),
                        ),
                        SizedBox(height: 10,),


                        TextFormField(
                         // readOnly: true,
                          controller: adresseController,
                          keyboardType: TextInputType.text,
                          textInputAction: TextInputAction.next,
                          cursorColor: kPrimaryColor,
                          onTap: () {
                           // _getCurrentPosition();
                          },

                          onSaved: (email) {},
                          decoration:  InputDecoration(
                            focusColor: kPrimaryColor,
                            focusedBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: kPrimaryColor),
                            ),
                            hintText: "Adresse",
                            prefixIcon: Padding(
                              padding: EdgeInsets.all(defaultPadding),
                              child: adreseLoging==true? SizedBox( width: 10,height: 10, child: CircularProgressIndicator()):Icon(Icons.map),
                            ),
                          ),
                          validator: (value) {
                            if (value!.isEmpty) {
                              return 'obligatoire.';
                            }

                            return null;
                          },
                        ),
                        SizedBox(height: 10,),


                        Text(
                          'À propos de toi :',
                          style: TextStyle(fontSize: 15.0, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8.0),
                        TextFormField(
                          controller: aproposController,
                          maxLines: 3, // Permet à l'utilisateur de saisir plusieurs lignes
                          decoration: InputDecoration(
                            border: OutlineInputBorder(), // Ajoute une bordure autour du champ de texte
                          ),
                          validator: (value) {
                            print('apropos $value');

                          },
                        ),
                        Text(
                          'En créant ce compte, vous acceptez les termes et conditions.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16.0),
                        ),
                        SizedBox(
                          height: 5,
                        ),


                        SizedBox(height: 50,),
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
                                        return SignUpScreen();
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
                                onPressed:onTap?() async { }:
                                    () async {
                                  setState(() {
                                    onTap=true;
                                  });
                                  if (_formKey.currentState!.validate()) {

                                    authProvider.registerUser.adresse=adresseController.text;
                                    authProvider.registerUser.nom=nomController.text;
                                    authProvider.registerUser.prenom=prenomController.text;
                                    if (_image != null) {
                                      Reference storageReference = FirebaseStorage.instance
                                          .ref()
                                          .child('user_profile/${Path.basename(_image!.path)}');
                                      UploadTask uploadTask = storageReference.putFile(_image!);
                                      await uploadTask.whenComplete((){

                                        storageReference.getDownloadURL().then((fileURL) {

                                          print("url photo1");
                                          print(fileURL);



                                          authProvider.registerUser.imageUrl = fileURL;

                                          authProvider.registerUser.apropos=aproposController.text;
                                          authProvider.registerUser.votre_solde=1000.0;
                                          authProvider.registerUser.userGlobalTags=tagsIds.toSet().toList();
                                          // Afficher une SnackBar
                                          signUp('${authProvider.registerUser.numeroDeTelephone!}@gmail.com',authProvider.registerUser.password!);
/*
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) {
                                                return SignUpFormEtap2(imageFile:  _image!,);
                                              },
                                            ),
                                          );

 */

                                        });
                                      });

                                    }else{
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content:
                                          Text('image invalide',style: TextStyle(color: Colors.red),),
                                        ),
                                      );

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
                                ): Text("S'inscrire",
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}