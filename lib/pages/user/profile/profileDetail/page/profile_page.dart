import 'package:afrotok/models/model_data.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../../constant/logo.dart';
import '../../../../../providers/authProvider.dart';
import '../../../../../services/api.dart';
import '../../../../component/consoleWidget.dart';
import '../utils/user_preferences.dart';
import '../widget/appbar_widget.dart';
import '../widget/button_widget.dart';
import '../widget/numbers_widget.dart';
import '../widget/profile_widget.dart';
import 'dart:convert';

import 'package:path/path.dart' as Path;
import 'package:afrotok/constant/constColors.dart';

import 'package:image_picker/image_picker.dart';


import 'dart:async';
import 'dart:io';


class ProfilePage extends StatefulWidget {
  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late UserAuthProvider authProvider =
  Provider.of<UserAuthProvider>(context, listen: false);
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
bool change_profil_loading= false;
  bool isEdite =false;
  File? _image;
  // ignore: unused_field
  PickedFile? _pickedFile;
  final _picker = ImagePicker();
  Widget buildEditIcon(Color color) => buildCircle(
    color: Colors.white,
    all: 3,
    child: buildCircle(
      color: color,
      all: 8,
      child: Icon(
        Icons.edit,
        color: Colors.black,
        size: 20,
      ),
    ),
  );

  Widget buildCircle({
    required Widget child,
    required double all,
    required Color color,
  }) =>
      ClipOval(
        child: Container(
          padding: EdgeInsets.all(all),
          color: color,
          child: child,
        ),
      );
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

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
     //authProvider.getToken().then((value) {},);
      //authProvider.getUserByToken(token: authProvider.token!);
  }
  @override
  Widget build(BuildContext context) {
    final user = UserPreferences.myUser;



    return Scaffold(
      appBar: AppBar(
        /*
        title: TextCustomerPageTitle(
          titre: "Mon Profile",
          fontSize: SizeText.homeProfileTextSize,
          couleur: ConstColors.textColors,
          fontWeight: FontWeight.bold,
        ),

         */

        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Logo(),
          )
        ],
        //title: Text(widget.title),
      ),
      body: RefreshIndicator(

        onRefresh: ()async {
          setState(() {

          });
        },
        child: SingleChildScrollView(
          child: Column(
          //  physics: NeverScrollableScrollPhysics(),
            children: [
              isEdite?   Stack(
                children: [
                  GestureDetector(
                    onTap: () async {
                     await  getImage();
                    },
                    child: Container(
                      height: 140,
                      width: 140,
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.all(Radius.circular(200)),
                          border: Border.all(width: 3, color: ConstColors.buttonsColors)),
                      child: ClipRRect(
                        borderRadius: BorderRadius.all(Radius.circular(200)),
                        child: Container(
                          height: 139,
                          width: 139,
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
                  ),
                  Positioned(
                    bottom: 2,
                    left: 0,
                    right: 0,

                    child: Container(
                      alignment: Alignment.center,
                      child: Center(
                          child: TextButton(
                            onPressed:_image == null
                                ?() async {
                               await  getImage();
                                }:change_profil_loading?() {

                            }: () async {
                              // selectedImagePath = await _pickImage();
                            //  await  getImage();
                              if (_image != null) {
                                setState(() {
                                  change_profil_loading= true;
                                });
                                Reference storageReference = FirebaseStorage.instance
                                    .ref()
                                    .child('user_profile/${Path.basename(_image!.path)}');
                                UploadTask uploadTask = storageReference.putFile(_image!);
                                await uploadTask.whenComplete((){

                                  storageReference.getDownloadURL().then((fileURL) async {

                                    printVm("url photo1");
                                    printVm(fileURL);



                                    authProvider.loginUserData.imageUrl = fileURL;
                                    await firestore.collection('Users').doc( authProvider.loginUserData!.id).update( authProvider.loginUserData!.toJson());


                                  });
                                });

                              }
                              SnackBar snackBar = SnackBar(
                                content: Text('Votre photo de profil a été changée',textAlign: TextAlign.center,style: TextStyle(color: Colors.green),),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(snackBar);
                              setState(() {
                                change_profil_loading= true;
                                isEdite =false;
                              });

                            } ,
                            child: Container(
                              alignment: Alignment.center,
                            //  height: 20,
                                width: 100,
                                decoration: BoxDecoration(
                                  color:_image == null
                                      ?Colors.black45: Colors.green,
                                  borderRadius: BorderRadius.all(Radius.circular(10))
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child:_image == null
                                      ? Text("Choisir",style: TextStyle(fontSize: 12,fontWeight: FontWeight.w900,color: _image == null
                                      ?Colors.white: Colors.black,),):change_profil_loading?Container(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator()):Text("Valider",style: TextStyle(fontSize: 12,fontWeight: FontWeight.w900,color: _image != null
                                      ?Colors.white: Colors.black,),),
                                )),

                          )),
                    ),
                  )
                ],
              ):
              Stack(
                children: [
                  ProfileWidget(
                    imagePath: '${authProvider.loginUserData.imageUrl!}',
                    onClicked: () async {

                    },
                  ),
                  Positioned(
                    bottom: 0,
                    right: 150,
                    child:   GestureDetector(
                        onTap: () {
                          setState(() {
                            isEdite =true;
                          });
                        },child: buildEditIcon(Colors.green)),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              buildName(authProvider.loginUserData),
              const SizedBox(height: 24),
              Text("Code de parrainage :",style: TextStyle(fontSize: 20,fontWeight: FontWeight.w900),),
              const SizedBox(height: 10),
              Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text("${authProvider.loginUserData.codeParrainage}",style: TextStyle(fontSize: 20,fontWeight: FontWeight.w900),),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.copy),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: "${authProvider.loginUserData.codeParrainage}"));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Code de parrainage copié !')),
                  );
                },
              ),
            ],
          ),
              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Center(child: buildUpgradeButton()),
                  Center(child: buildUpgradeButtonTarif(authProvider.loginUserData)),
                ],
              ),
              const SizedBox(height: 24),
              NumbersWidget(followers: authProvider.loginUserData!.abonnes!, taux: authProvider.loginUserData!.popularite!*100, points: authProvider.loginUserData!.pointContribution!,),
              const SizedBox(height: 48),
              buildAbout(authProvider.loginUserData),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildName(UserData user) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              "@${user.pseudo!}",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(Icons.phone),
                Text(
                  user.numeroDeTelephone!,
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(Icons.email),
                Text(
                  user.email!,
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
            /*
            Text(
              "+228 96198801",
              style: TextStyle(color: Colors.grey),
            )

             */
          ],
        ),
  );
  String formatNumber(double number) {
    if (number < 1000) {
      return number.toString();
    } else if (number < 1000000) {
      return "${number / 1000} k";
    } else if (number < 1000000000) {
      return "${number / 1000000} m";
    } else {
      return "${number / 1000000000} b";
    }
  }
  Widget buildUpgradeButton() => ButtonWidget(
        text: 'Votre tarif :',

        onClicked: () {},
      );
  Widget buildUpgradeButtonTarif(UserData user) => ButtonWidget(
    text: '${user.compteTarif!.toStringAsFixed(2)} PubliCach(s)',
    onClicked: () {},
  );

  Widget buildAbout(UserData user) => Container(
        padding: EdgeInsets.symmetric(horizontal: 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'A propos',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              user.apropos!,
              style: TextStyle(fontSize: 16, height: 1.4),
            ),
          ],
        ),
      );
}
