import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/pages/user/otherUser/otherUserLookTab.dart';
import 'package:afrotok/pages/user/otherUser/otherUserLookVideoTab.dart';
import 'package:afrotok/pages/user/profile/profileDetail/utils/user_preferences.dart';
import 'package:afrotok/pages/user/profile/profileDetail/widget/button_widget.dart';
import 'package:afrotok/pages/user/profile/profileDetail/widget/numbers_widget.dart';
import 'package:afrotok/pages/user/profile/profileDetail/widget/profile_widget.dart';
import 'package:afrotok/pages/user/profile/profileTabsBar/profileImageTab.dart';
import 'package:afrotok/pages/user/profile/profileTabsBar/profileVideosTab.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:contained_tab_bar_view_with_custom_page_navigator/contained_tab_bar_view_with_custom_page_navigator.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../../../../constant/logo.dart';
import '../../../../../../providers/authProvider.dart';
import '../../../../../../services/api.dart';

import 'dart:convert';

import 'package:path/path.dart' as Path;
import 'package:afrotok/constant/constColors.dart';

import 'package:image_picker/image_picker.dart';


import 'dart:async';
import 'dart:io';

import '../../../constant/sizeText.dart';
import '../../../constant/textCustom.dart';
import '../../component/consoleWidget.dart';
import '../../component/showImage.dart';
import '../detailsOtherUser.dart';


class OtherUserPage extends StatefulWidget {
  final UserData otherUser;

  const OtherUserPage({super.key, required this.otherUser});
  @override
  _OtherUserPageState createState() => _OtherUserPageState();
}

class _OtherUserPageState extends State<OtherUserPage> {
  late UserAuthProvider authProviders =
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
    // final user = UserPreferences.myUser;

    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;

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
              Container(
                alignment: Alignment.center,
                child: Center(
                  child:                   ProfileWidget(
                    imagePath: '${widget.otherUser.imageUrl!}',
                    onClicked: () async {
                      showImageDetailsModalDialog(widget.otherUser.imageUrl!, width, height,context);

                    },
                  ),

                ),
              ),
              const SizedBox(height: 15),
              buildName(widget.otherUser),
              const SizedBox(height: 15),
              Text("Code de parrainage :",style: TextStyle(fontSize: 12,fontWeight: FontWeight.w900),),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text("${widget.otherUser.codeParrainage}",style: TextStyle(fontSize: 12,fontWeight: FontWeight.w900),),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.copy,size: 15,),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: "${widget.otherUser.codeParrainage}"));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Code de parrainage copié !')),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),

              NumbersWidget(followers: widget.otherUser!.abonnes!, taux: widget.otherUser!.popularite!*100, points: widget.otherUser.pointContribution!,),
              const SizedBox(height: 10),
              TextCustomerUserTitle(
                titre:
                "${formatNumberLike(widget.otherUser!.userlikes!)} like(s)",
                fontSize: 16,
                couleur: Colors.green,
                fontWeight: FontWeight.w700,
              ),
              const SizedBox(height: 10),

              buildAbout(widget.otherUser),

              const SizedBox(height: 15),


              Container(
                child:   SizedBox(
                  width: width,
                  height:height*0.8 ,
                  child: ContainedTabBarView(
                    tabs: [
                      Container(
                        child: TextCustomerMenu(
                          titre: "Look",
                          fontSize: SizeText.homeProfileTextSize,
                          couleur: ConstColors.textColors,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Container(
                        child: TextCustomerMenu(
                          titre: "Videos",
                          fontSize: SizeText.homeProfileTextSize,
                          couleur: ConstColors.textColors,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    tabBarProperties: TabBarProperties(
                      height: 32.0,
                      indicatorColor: ConstColors.menuItemsColors,
                      indicatorWeight: 6.0,
                      labelColor: Colors.black,
                      unselectedLabelColor: Colors.grey[400],
                    ),
                    views: [
                      OtherUserLookTab(otherUser: widget.otherUser,),
                      OtherUserLookVideoTab(otherUser: widget.otherUser),
                    ],
                    onChange: (index) => print(index),
                  ),
                ),

              )
            ],
          ),
        ),
      ),
    );
  }


  Widget buildName(UserData user) => Column(
    children: [
      Text(
        "@${user.pseudo!}",
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
      ),
      const SizedBox(height: 4),
      // Text(
      //   user.numeroDeTelephone!,
      //   style: TextStyle(color: Colors.grey),
      // ),
      /*
          Text(
            "+228 96198801",
            style: TextStyle(color: Colors.grey),
          )

           */
    ],
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

  String formatNumberLike(int number) {
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
    text: 'Tarif :',

    onClicked: () {},
  );
  Widget buildUpgradeButtonTarif(UserData user) => ButtonWidget(
    text: '${user.compteTarif!.toStringAsFixed(2)} PubliCash(s)',
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
