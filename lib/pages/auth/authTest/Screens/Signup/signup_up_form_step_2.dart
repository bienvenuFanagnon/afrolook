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
     printVm(e);
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

      printVm("Adresse: $_currentAddress");
      setState(() {
        adreseLoging=false;
      });

    }).catchError((e) {
     printVm(e);
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
  void signUp(String email, String password) async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        tap= true;
      });
      try {
        authProvider.registerUser.role = UserRole.USER.name!;
        authProvider.registerUser.updatedAt =
            DateTime.now().microsecondsSinceEpoch;
        authProvider.registerUser.createdAt =
            DateTime.now().microsecondsSinceEpoch;
        UserPseudo pseudo=UserPseudo();
        String id="";
        NotificationData notif=NotificationData();

        SnackBar snackBar1 = SnackBar(
          backgroundColor: Colors.green,
          content: Text('Compte créé avec succès !',style: TextStyle(color: Colors.white),),
        );
        try{
          printVm("codeParrain : ${authProvider.registerUser.codeParrain!}");

          if(authProvider.registerUser.codeParrain!.isNotEmpty){
            printVm("codeParrain 2 : ${authProvider.registerUser.codeParrain!}");
            await verifierParrain(authProvider.registerUser.codeParrain!).then((user) async {
              if(user!=null){

                await _auth
                    .createUserWithEmailAndPassword(email: email, password: password)
                    .then((value) async =>
                {
                   id=value.user!.uid,
                pseudo.id=firestore
                    .collection('Pseudo')
                    .doc()
                    .id,
                pseudo.name=authProvider.registerUser.pseudo,
                authProvider.registerUser.id =id,

                await authProvider.getAppData(),

                    authProvider.registerUser!.pointContribution=authProvider.registerUser!.pointContribution! + authProvider.appDefaultData.default_point_new_user!,
                    authProvider.registerUser.votre_solde= 5.1,
                    authProvider.registerUser.publi_cash= 5.1,

                    printVm("current user trouver"),
                printVm("current user trouver :${user.toJson()}"),

                // Assure-toi que la liste n'est pas vide

                user.pointContribution=user.pointContribution! + authProvider.appDefaultData.default_point_new_user!,

                // Vérifie que usersParrainer n'est pas null avant d'ajouter un nouvel ID
                if (user.usersParrainer != null) {
                  user.usersParrainer!.add(authProvider.registerUser.id!),
                } else {
                  user.usersParrainer = [],
                  user.usersParrainer!.add(authProvider.registerUser.id!),

                },
                  user.votre_solde = (user.votre_solde==null? 0.0:user.votre_solde!) + 5.1,
                  user.publi_cash = (user.publi_cash==null? 0.0:user.publi_cash!) + 5.1,
                // user.publi_cash = (user.publi_cash ?? 0.0) + 5.1,

                // Mets à jour l'utilisateur dans Firebase

                // await authProvider.updateUser(user).then((value) {
                //   if(value){
                //
                //   }
                // },),

                await FirebaseFirestore.instance
                    .collection('Users')
                    .doc(user.id)
                    .update(user.toJson()),

                  printVm("after current user trouver :${user.toJson()}"),

                  await authProvider.sendNotification(
                    userIds: [user.oneIgnalUserid!],
                    smallImage: "${user.imageUrl!}",
                    send_user_id: "${authProvider.registerUser.id!}",
                    recever_user_id: "${user.id!}",
                    message: "🤑 Vous avez gagné 5 PubliCash grâce à un parrainage !",
                    type_notif: NotificationType.PARRAINAGE.name,
                    post_id: "",
                    post_type: "",
                    chat_id: ''
                ),

                notif.id=firestore
                    .collection('Notifications')
                    .doc()
                    .id,
                notif.titre="Parrainage 🤑",
                notif.media_url=user.imageUrl,
                notif.type=NotificationType.PARRAINAGE.name,
                notif.description="Vous avez gagné 5 PubliCash grâce à un parrainage ! Vérifiez votre solde dans la page Monétisation pour profiter de vos gains.N'oubliez pas de continuer à parrainer vos amis pour gagner encore plus d'argent !",
                notif.users_id_view=[],
                notif.user_id=authProvider.registerUser.id,
                notif.receiver_id=user.id!,
                notif.post_id="",
                notif.post_data_type="",

                notif.updatedAt =
                    DateTime.now().microsecondsSinceEpoch,
                notif.createdAt =
                    DateTime.now().microsecondsSinceEpoch,
                notif.status = PostStatus.VALIDE.name,

                // users.add(pseudo.toJson());

                await firestore.collection('Notifications').doc(notif.id).set(notif.toJson()),


                await firestore.collection('Users').doc(id).set( authProvider.registerUser.toJson()),

                    authProvider.appDefaultData.nbr_abonnes=authProvider.appDefaultData.nbr_abonnes!+1,
                    if (authProvider.appDefaultData.users_id!.any((element) => element==id)==false) {
              authProvider.appDefaultData.users_id!.add(id),
              },

              await firestore.collection('Pseudo').doc(pseudo.id).set(pseudo.toJson()),
              printVm("///////////-- save pseudo --///////////////"),
              await firestore.collection('AppData').doc( authProvider.appDefaultData.id!).update( authProvider.appDefaultData.toJson()),


              ScaffoldMessenger.of(context).showSnackBar(snackBar1),
              setState(() {
              tap= false;
              }),
                  Navigator.pop(context),

                  Navigator.pushNamed(context, '/bon_a_savoir'),
                })
                  .catchError((e) {

                  SnackBar snackBar = SnackBar(
                    backgroundColor: Colors.red,
                    content: Text("Une erreur s'est produite",style: TextStyle(color: Colors.white),),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(snackBar);
                  printVm('error ${e!.message}');
                  setState(() {
                    tap= false;
                  });

                });

              }else{

                SnackBar snackBar = SnackBar(
                  backgroundColor: Colors.red,
                  content: Text('Le code de parrainage est erroné !',style: TextStyle(color: Colors.white),),
                );

                ScaffoldMessenger.of(context).showSnackBar(snackBar);
              }
            },);
          }
          else{
            await _auth
                .createUserWithEmailAndPassword(email: email, password: password)
                .then((value) async =>
            {
              id=value.user!.uid,
              pseudo.id=firestore
                  .collection('Pseudo')
                  .doc()
                  .id,
              pseudo.name=authProvider.registerUser.pseudo,
              authProvider.registerUser.id =id,

              await firestore.collection('Users').doc(id).set( authProvider.registerUser.toJson()),

              authProvider.appDefaultData.nbr_abonnes=authProvider.appDefaultData.nbr_abonnes!+1,
              if (authProvider.appDefaultData.users_id!.any((element) => element==id)==false) {
                authProvider.appDefaultData.users_id!.add(id),
              },

              await firestore.collection('Pseudo').doc(pseudo.id).set(pseudo.toJson()),
              printVm("///////////-- save pseudo --///////////////"),
              await firestore.collection('AppData').doc( authProvider.appDefaultData.id!).update( authProvider.appDefaultData.toJson()),


              ScaffoldMessenger.of(context).showSnackBar(snackBar1),
              Navigator.pop(context),
              setState(() {
                tap= false;
              }),
              Navigator.pushNamed(context, '/bon_a_savoir'),
          })
        .catchError((e) {

    SnackBar snackBar = SnackBar(
    backgroundColor: Colors.red,
    content: Text("Une erreur s'est produite",style: TextStyle(color: Colors.white),),
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
    printVm('error ${e!.message}');
    setState(() {
    tap= false;
    });

    });
          }

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

      } on FirebaseAuthException catch (error) {
        switch (error.code) {

          case "invalid-email":
            errorMessage = "Votre email semble être malformé.";
            break;
          case "wrong-password":
            errorMessage = "Votre mot de passe est erroné.";
            break;
          case "email-already-in-use":
            errorMessage = "L'email est déjà utilisé par un autre compte.";
            break;
          case "user-not-found":
            errorMessage = "L'utilisateur avec cet email n'existe pas.";
            break;
          case "user-disabled":
            errorMessage = "L'utilisateur avec cet email a été désactivé.";
            break;
          case "too-many-requests":
            errorMessage = "Trop de demandes.";
            break;
          case "operation-not-allowed":
            errorMessage = "La connexion avec l'email et un mot de passe n'est pas activée.";
            break;

          default:
            errorMessage = "Une erreur indéfinie s'est produite.";
        }
        SnackBar snackBar = SnackBar(
          content: Text('${errorMessage}',style: TextStyle(color: Colors.red),),
        );
        ScaffoldMessenger.of(context).showSnackBar(snackBar);

        printVm("error code : ${error.code}");
        setState(() {
          tap= false;
        });
      }

    }
  }


  void signUp2(String email, String password) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => tap = true);

    try {
      // Initialisation des données utilisateur
      _setupUserData();

      if (authProvider.registerUser.codeParrain?.isNotEmpty ?? false) {
        await _handleParrainageSignUp(email, password);
      } else {
        await _handleRegularSignUp(email, password);
      }

      ScaffoldMessenger.of(context).showSnackBar(_successSnackBar());
      _navigateAfterSignUp();
    } on FirebaseAuthException catch (e) {
      _handleAuthError(e);
    } on FirebaseException catch (e) {
      _handleFirebaseError(e);
    } catch (e) {
      _handleGenericError(e);
    } finally {
      setState(() => tap = false);
    }
  }

// Helper methods

  void _setupUserData() {
    authProvider.registerUser
      ..role = UserRole.USER.name!
      ..updatedAt = DateTime.now().microsecondsSinceEpoch
      ..createdAt = DateTime.now().microsecondsSinceEpoch;
  }

  Future<void> _handleParrainageSignUp(String email, String password) async {
    final parrain = await verifierParrain(authProvider.registerUser.codeParrain!);
    if (parrain == null) throw Exception('Code de parrainage invalide');

    final userCredential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    await _updateParrainData(parrain);
    await _createUserData(userCredential.user!.uid);
    await _sendParrainageNotification(parrain);
  }

  Future<void> _handleRegularSignUp(String email, String password) async {
    final userCredential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    await _createUserData(userCredential.user!.uid);
  }
  int generateRandomNumber() {
    final random = Random();
    return random.nextInt(99999) + 1; // nextInt(99999) génère un nombre entre 0 et 99998, donc on ajoute 1
  }
  Future<void> _createUserData(String userId) async {
    final batch = firestore.batch();

    // Création du pseudo
    final pseudo = UserPseudo()
      ..id = firestore.collection('Pseudo').doc().id
      ..name = authProvider.registerUser.pseudo;

    // Configuration utilisateur
    authProvider.registerUser
      ..id = userId
      ..codeParrainage = "${pseudo}${generateRandomNumber()}"
      ..pointContribution = authProvider.appDefaultData.default_point_new_user!
      ..votre_solde = 5.1
      ..publi_cash = 5.1;

    // Configuration AppData
    authProvider.appDefaultData.nbr_abonnes = (authProvider.appDefaultData.nbr_abonnes ?? 0) + 1;
    if (!(authProvider.appDefaultData.users_id?.contains(userId) ?? false)) {
      authProvider.appDefaultData.users_id?.add(userId);
    }

    // Ajout des opérations batch
    batch.set(firestore.collection('Users').doc(userId), authProvider.registerUser.toJson());
    batch.set(firestore.collection('Pseudo').doc(pseudo.id), pseudo.toJson());
    batch.update(firestore.collection('AppData').doc(authProvider.appDefaultData.id!), {
      'nbr_abonnes': authProvider.appDefaultData.nbr_abonnes,
      'users_id': authProvider.appDefaultData.users_id,
    });

    await batch.commit();
  }

  Future<void> _updateParrainData(UserData parrain) async {
    final batch = firestore.batch();

    parrain
      ..pointContribution = (parrain.pointContribution ?? 0) + authProvider.appDefaultData.default_point_new_user!
      ..votre_solde = (parrain.votre_solde ?? 0.0) + 5.1
      ..publi_cash = (parrain.publi_cash ?? 0.0) + 5.1
      ..usersParrainer = [...parrain.usersParrainer ?? [], authProvider.registerUser.id!];

    batch.update(firestore.collection('Users').doc(parrain.id!), parrain.toJson());
    await batch.commit();
  }

  Future<void> _sendParrainageNotification(UserData parrain) async {
    final notif = NotificationData()
      ..id = firestore.collection('Notifications').doc().id
      ..titre = "Parrainage 🤑"
      ..media_url = parrain.imageUrl
      ..type = NotificationType.PARRAINAGE.name
      ..description = "Vous avez gagné 5 PubliCash grâce à un parrainage..."
      ..user_id = authProvider.registerUser.id
      ..receiver_id = parrain.id!
      ..updatedAt = DateTime.now().microsecondsSinceEpoch
      ..createdAt = DateTime.now().microsecondsSinceEpoch
      ..status = PostStatus.VALIDE.name;

    await firestore.collection('Notifications').doc(notif.id).set(notif.toJson());
    await authProvider.sendNotification(
      userIds: [parrain.oneIgnalUserid!],
      smallImage: parrain.imageUrl!,
      send_user_id: authProvider.registerUser.id!,
      recever_user_id: parrain.id!,
      message: "🤑 Vous avez gagné 5 PubliCash grâce à un parrainage !",
      type_notif: NotificationType.PARRAINAGE.name, post_id: '', post_type: '', chat_id: '',
    );
  }

// Gestion d'erreurs
  void _handleAuthError(FirebaseAuthException error) {
    final messages = {
      "invalid-email": "Votre email semble être malformé.",
      "wrong-password": "Votre mot de passe est erroné.",
      "email-already-in-use": "L'email est déjà utilisé par un autre compte.",
      "user-not-found": "L'utilisateur avec cet email n'existe pas.",
      "user-disabled": "L'utilisateur avec cet email a été désactivé.",
      "too-many-requests": "Trop de demandes.",
      "operation-not-allowed": "La connexion avec email/mot de passe n'est pas activée.",
    };

    final message = messages[error.code] ?? "Une erreur indéfinie s'est produite";
    _showErrorSnackBar(message);
  }

  void _handleFirebaseError(FirebaseException error) {
    printVm("_handleFirebaseError ${error.message ?? "Erreur Firebase"}");
    _showErrorSnackBar(error.message ?? "Erreur Firebase");
  }

  void _handleGenericError(dynamic error) {
    _showErrorSnackBar("Erreur inattendue: ${error.toString()}");
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text(message, style: const TextStyle(color: Colors.white)),
        ));
    }

  void _navigateAfterSignUp() {
    Navigator.pop(context);
    Navigator.pushNamed(context, '/bon_a_savoir');
  }

  SnackBar _successSnackBar() => SnackBar(
    backgroundColor: Colors.green,
    content: const Text('Compte créé avec succès !', style: TextStyle(color: Colors.white)),
  );

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
                    color: Colors.white70,
                    border: Border.all(color: Colors.green,width: 5),
                    borderRadius:BorderRadius.all(Radius.circular(10))
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Form(
                    key: _formKey,
                    child: Column(

                      children: [
                        Text("Votre photo"),
                        SizedBox(height: 5,),

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
                            hintStyle: TextStyle(color: Colors.green),
                            prefixIcon: Padding(
                              padding: EdgeInsets.all(defaultPadding),
                              child: adreseLoging==true? SizedBox( width: 10,height: 10, child: CircularProgressIndicator()):Icon(Icons.map,color: Colors.green,),
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
                          style: TextStyle(fontSize: 15.0, fontWeight: FontWeight.bold,color: Colors.green),
                        ),
                        SizedBox(height: 8.0),
                        TextFormField(
                          controller: aproposController,
                          maxLines: 3, // Permet à l'utilisateur de saisir plusieurs lignes
                          decoration: InputDecoration(
                            border: OutlineInputBorder(), // Ajoute une bordure autour du champ de texte
                          ),
                          validator: (value) {
                            printVm('apropos $value');

                          },
                        ),
                        SizedBox(height: 10,),

                        Text(
                          'En créant ce compte, vous acceptez les termes et conditions.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16.0),
                        ),


                        SizedBox(height: 10,),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              // width: 150,
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: ElevatedButton(
                                  onPressed: () {

                                    Navigator.pop(context);


                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(2.0),
                                    child: Row(
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.only(right: 5.0),
                                          child: Icon(Icons.arrow_back_ios_new_rounded,color: Colors.red,),
                                        ),
                                        Text("Précédent",
                                          style: TextStyle(color: Colors.red,fontWeight: FontWeight.bold),

                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Container(
                              // width: 150,
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
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

                                            printVm("url photo1");
                                            printVm(fileURL);



                                            authProvider.registerUser.imageUrl = fileURL;

                                            authProvider.registerUser.apropos=aproposController.text;
                                            authProvider.registerUser.votre_solde=0.0;
                                            authProvider.registerUser.userGlobalTags=tagsIds.toSet().toList();
                                            // Afficher une SnackBar
                                            // signUp('${authProvider.registerUser.numeroDeTelephone!}@gmail.com',authProvider.registerUser.password!);
                                            signUp(authProvider.registerUser.email!,authProvider.registerUser.password!);
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
                                    style: TextStyle(color: Colors.green,fontWeight: FontWeight.bold),

                                  ),
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