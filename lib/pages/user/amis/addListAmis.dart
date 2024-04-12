import 'dart:math';

import 'package:afrotok/models/model_data.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:provider/provider.dart';
import 'package:searchable_listview/searchable_listview.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../constant/constColors.dart';
import '../../../constant/logo.dart';
import '../../../constant/sizeText.dart';
import '../../../constant/textCustom.dart';
import '../../../providers/authProvider.dart';
import '../../../providers/userProvider.dart';
import '../../auth/authTest/constants.dart';
import '../detailsOtherUser.dart';



class AddListAmis extends StatefulWidget {
  const AddListAmis({super.key});

  @override
  State<AddListAmis> createState() => _ListUserChatsState();
}

class _ListUserChatsState extends State<AddListAmis> {


  late UserAuthProvider authProvider =
      Provider.of<UserAuthProvider>(context, listen: false);

  late UserProvider userProvider =
      Provider.of<UserProvider>(context, listen: false);
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  late List<UserData> listUser = [];
  bool isUserAbonne(List<UserAbonnes> userAbonnesList, String userIdToCheck) {
    return userAbonnesList.any((userAbonne) => userAbonne.abonneUserId == userIdToCheck);
  }
  bool isMyFriend(List<Friends> userfriendList, String userIdToCheck) {
    return userfriendList.any((userAbonne) => userAbonne.friendId == userIdToCheck);
  }
  bool isInvite(List<Invitation> invitationList, String userIdToCheck) {

    return invitationList.any((inv) {
      return inv.receiverId == userIdToCheck?true:false;
    },);
  }
  List<String> alphabet = [];

  Future<void> searchListDialogue(
      BuildContext context, double h, double w, List<UserData> users) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Liste d\'utilisateur'),
          content: Container(
            height: h, // Ajustez la hauteur selon vos besoins
            width: w, // Ajustez la largeur selon vos besoins
            child: ListView(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.all(2.0),
                  child: SizedBox(
                    height: h, // Ajustez la hauteur selon vos besoins
                    width: w,
                    child: SearchableList<UserData>(
                      initialList: listUser,
                      builder: (displayedList, itemIndex, user) =>
                          GestureDetector(
                              onTap: () {
                                //  Navigator.pushNamed(context, '/basic_chat');
                              },
                              child: otherUsers(user, true)),
                      filter: (value) => listUser
                          .where(
                            (element) => element!.pseudo!
                                .toLowerCase()
                                .contains(value.toLowerCase()),
                          )
                          .toList(),
                      emptyWidget: Container(
                        child: Text('vide'),
                      ),
                      inputDecoration: InputDecoration(
                        labelText: "Utilisateurs",
                        fillColor: Colors.white,
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(
                            color: Colors.blue,
                            width: 1.0,
                          ),
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                      ),
                    ),
                  ),
                ),
                // Ajoutez d'autres éléments de liste ici
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Fermer'),
            ),
          ],
        );
      },
    );
  }

  void _showUserDetailsModalDialog(UserData user,double w,double h) {

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          content: DetailsOtherUser(user: user, w: w, h: h,),
        );
      },
    );
  }
  String formatNumber(int number) {
    if (number >= 1000) {
      double nombre = number / 1000;
      return nombre.toStringAsFixed(1) + 'k';
    } else {
      return number.toString();
    }
  }
  Widget otherUsers(UserData user, bool isSearch) {
    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;
    bool inviteTap = false;
    bool isAbonne = false;
    return Container(
      padding: EdgeInsets.only(left: 16, right: 16, top: 10, bottom: 10),
      child: Row(
        children: <Widget>[
          Expanded(
            child:     GestureDetector(


              onTap: () {
                _showUserDetailsModalDialog(user!,width,height);
              },
              child: Row(
                children: <Widget>[
                  CircleAvatar(
                    backgroundImage: NetworkImage("${user!.imageUrl!}"),
                    maxRadius: isSearch ? 20 : 30,
                  ),
                  SizedBox(
                    width: 16,
                  ),
                  Expanded(
                    child: Container(
                      color: Colors.transparent,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                        '@${user.pseudo}',
                            style: TextStyle(fontSize: isSearch ? 10 : 16),
                          ),
                          SizedBox(
                            height: 6,
                          ),
                          Text(
                            '${formatNumber(user.abonnes!)} abonne(s)',
                            style: TextStyle(
                                fontSize: isSearch ? 8 : 13,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.normal),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Row(
            children: [
              TextButton(
                  onPressed:  () {},

                  child: Text(
                    isAbonne ? '' : 'abonner',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.normal,
                        color: isAbonne ? Colors.red : Colors.green),
                  )),
    StatefulBuilder(

    builder: (BuildContext context, void Function(void Function()) setState) {
      return isInvite(authProvider.loginUserData.mesInvitationsEnvoyer!, user.id!)?Container(): TextButton(
          onPressed: inviteTap
              ? () {}

              : () async {
            setState(() {
              inviteTap = true;
            });
            Invitation invitation = Invitation();
            invitation.senderId = authProvider.loginUserData.id;
            invitation.receiverId = user.id;
            invitation.status = InvitationStatus.ENCOURS.name;
            invitation.createdAt =
                DateTime
                    .now()
                    .millisecondsSinceEpoch;
            invitation.updatedAt =
                DateTime
                    .now()
                    .millisecondsSinceEpoch;

            // invitation.inviteUser=authProvider.loginUserData!;
            await userProvider.sendInvitation(invitation,context).then(
                  (value) async {
                if (value) {
                  // await userProvider.getUsers(authProvider.loginUserData!.id!);
                  await authProvider.getCurrentUser(
                      authProvider.loginUserData!.id!);
                  SnackBar snackBar = SnackBar(
                    content: Text(
                      'invitation envoyée',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.green),
                    ),
                  );
                  ScaffoldMessenger.of(context)
                      .showSnackBar(snackBar);
                } else {
                  SnackBar snackBar = SnackBar(
                    content: Text(
                      'une erreur',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.red),
                    ),
                  );
                  ScaffoldMessenger.of(context)
                      .showSnackBar(snackBar);
                }
              },
            );

            setState(() {
              inviteTap = false;
            });
          },
          child:inviteTap? Center(
            child: LoadingAnimationWidget.flickr(
              size: 20,
              leftDotColor: Colors.green,
              rightDotColor: Colors.black,
            ),
          ): Text(
            'inviter',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
                color: Colors.blue),
          )
      );
    }
              ),
            ],
          ),
        ],
      ),
    );
  }



  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    //print("alphabetlg : ${authProvider.appDefaultData.users_id!.length}");
    alphabet= authProvider.appDefaultData.users_id!;


    alphabet.shuffle();
   // alphabet = alphabet.sublist(0,alphabet.length>5?5:alphabet.length>2?3:alphabet.length>10?10: alphabet.length>20?20:alphabet.length>30?30:alphabet.length>50?50:alphabet.length>70?70:alphabet.length>100?100:1);
    alphabet = alphabet.length<100?alphabet.sublist(0,alphabet.length-1):alphabet.sublist(0,100);


  }
  @override
  Widget build(BuildContext context) {
    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;
    return Scaffold(
      appBar: AppBar(
        title: TextCustomerPageTitle(
          titre: "Nouveau amis",
          fontSize: SizeText.homeProfileTextSize,
          couleur: ConstColors.textColors,
          fontWeight: FontWeight.bold,
        ),

        //backgroundColor: Colors.blue,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Logo(),
          )
        ],
        //title: Text(widget.title),
      ),
      body: SingleChildScrollView(
        physics: BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: EdgeInsets.only(top: 16, left: 16, right: 16),
              child: TextField(
                onTap: () {
                  searchListDialogue(
                      context, height * 0.6, width * 0.8, listUser);
                },
                readOnly: true,
                cursorColor: kPrimaryColor,
                decoration: InputDecoration(
                  focusColor: ConstColors.buttonColors,
                  focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: kPrimaryColor)),
                  hintText: "Recherche...",
                  hintStyle: TextStyle(color: Colors.grey.shade600),
                  prefixIcon: Icon(
                    Icons.search,
                    color: Colors.grey.shade600,
                    size: 20,
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  contentPadding: EdgeInsets.all(8),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(color: Colors.grey.shade100)),
                ),
              ),
            ),
            StreamBuilder<QuerySnapshot>(
              //initialData: [],
              stream: FirebaseFirestore.instance
                  .collection('Users')
                  .where('id', isNotEqualTo: authProvider.loginUserData.id!)
              //.orderBy('popularite', descending: true)
                 // .orderBy('pseudo').startAt([alphabet.elementAt(Random().nextInt(alphabet.length))])
                  .where('id', whereIn: alphabet) // Remplacez id1, id2, id3 par les ID de document des utilisateurs


                .limit(100)
                  .snapshots()!,

              // key: _formKey,

              builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                if (snapshot.hasData) {
                  QuerySnapshot data = snapshot.requireData as QuerySnapshot;
                  // Get data from docs and convert map to List
                  List<UserData> list = data.docs
                      .map((doc) =>
                          UserData.fromJson(doc.data() as Map<String, dynamic>))
                      .toList();
                  if (list.isNotEmpty) {

                  }
                  listUser = list;

                  return ListView.builder(
                    scrollDirection: Axis.vertical,
                    itemCount: snapshot.data!.size,
                    shrinkWrap: true,
                    padding: EdgeInsets.only(top: 16),
                    physics: NeverScrollableScrollPhysics(),
                    itemBuilder: (context, index) {
                      bool isAbonne = false;
                      return GestureDetector(
                        onTap: () {
                          //  Navigator.pushNamed(context, '/basic_chat');
                        },
                        child: otherUsers(list[index], false),
                      );
                    },
                  );
                } else if (snapshot.hasError) {
                  print("${snapshot.error}");
                  return Center(
                    child: Column(
                      children: [
                        Image.asset(
                          'assets/images/404.png',
                          height: 200,
                          width: 200,
                        ),
                        Text(
                          "Erreurs lors du chargement",
                          style: TextStyle(color: Colors.red),
                        ),
                        TextButton(
                          child: Text(
                            'Réessayer',
                            style: TextStyle(color: Colors.green),
                          ),
                          onPressed: () {
                            setState(() {});
                            // Réessayez de charger la page.
                          },
                        ),
                      ],
                    ),
                  );
                } else {
                  // Utiliser les données de snapshot.data

                  return Skeletonizer(
                    //enabled: _loading,
                    child: Column(
                      children: [
                        Container(
                          padding: EdgeInsets.only(
                              left: 16, right: 16, top: 10, bottom: 10),
                          child: Row(
                            children: <Widget>[
                              Expanded(
                                child: Row(
                                  children: <Widget>[
                                    CircleAvatar(
                                      backgroundImage:
                                          AssetImage("assets/images/404.png"),
                                      maxRadius: 30,
                                    ),
                                    SizedBox(
                                      width: 16,
                                    ),
                                    Expanded(
                                      child: Container(
                                        color: Colors.transparent,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: <Widget>[
                                            Text(
                                              "amigo!.friend!.pseudo!",
                                              style: TextStyle(fontSize: 16),
                                            ),
                                            SizedBox(
                                              height: 6,
                                            ),
                                            Text(
                                              ' abonne(s)',
                                              style: TextStyle(
                                                  fontSize: 13,
                                                  color: Colors.grey.shade600,
                                                  fontWeight:
                                                      FontWeight.normal),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    Icon(
                                      Icons.send_sharp,
                                      color: Colors.green,
                                    )
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.only(
                              left: 16, right: 16, top: 10, bottom: 10),
                          child: Row(
                            children: <Widget>[
                              Expanded(
                                child: Row(
                                  children: <Widget>[
                                    CircleAvatar(
                                      backgroundImage:
                                          AssetImage("assets/images/404.png"),
                                      maxRadius: 30,
                                    ),
                                    SizedBox(
                                      width: 16,
                                    ),
                                    Expanded(
                                      child: Container(
                                        color: Colors.transparent,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: <Widget>[
                                            Text(
                                              "amigo!.friend!.pseudo!",
                                              style: TextStyle(fontSize: 16),
                                            ),
                                            SizedBox(
                                              height: 6,
                                            ),
                                            Text(
                                              ' abonne(s)',
                                              style: TextStyle(
                                                  fontSize: 13,
                                                  color: Colors.grey.shade600,
                                                  fontWeight:
                                                      FontWeight.normal),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    Icon(
                                      Icons.send_sharp,
                                      color: Colors.green,
                                    )
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.only(
                              left: 16, right: 16, top: 10, bottom: 10),
                          child: Row(
                            children: <Widget>[
                              Expanded(
                                child: Row(
                                  children: <Widget>[
                                    CircleAvatar(
                                      backgroundImage:
                                          AssetImage("assets/images/404.png"),
                                      maxRadius: 30,
                                    ),
                                    SizedBox(
                                      width: 16,
                                    ),
                                    Expanded(
                                      child: Container(
                                        color: Colors.transparent,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: <Widget>[
                                            Text(
                                              "amigo!.friend!.pseudo!",
                                              style: TextStyle(fontSize: 16),
                                            ),
                                            SizedBox(
                                              height: 6,
                                            ),
                                            Text(
                                              ' abonne(s)',
                                              style: TextStyle(
                                                  fontSize: 13,
                                                  color: Colors.grey.shade600,
                                                  fontWeight:
                                                      FontWeight.normal),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    Icon(
                                      Icons.send_sharp,
                                      color: Colors.green,
                                    )
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.only(
                              left: 16, right: 16, top: 10, bottom: 10),
                          child: Row(
                            children: <Widget>[
                              Expanded(
                                child: Row(
                                  children: <Widget>[
                                    CircleAvatar(
                                      backgroundImage:
                                          AssetImage("assets/images/404.png"),
                                      maxRadius: 30,
                                    ),
                                    SizedBox(
                                      width: 16,
                                    ),
                                    Expanded(
                                      child: Container(
                                        color: Colors.transparent,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: <Widget>[
                                            Text(
                                              "amigo!.friend!.pseudo!",
                                              style: TextStyle(fontSize: 16),
                                            ),
                                            SizedBox(
                                              height: 6,
                                            ),
                                            Text(
                                              ' abonne(s)',
                                              style: TextStyle(
                                                  fontSize: 13,
                                                  color: Colors.grey.shade600,
                                                  fontWeight:
                                                      FontWeight.normal),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    Icon(
                                      Icons.send_sharp,
                                      color: Colors.green,
                                    )
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.only(
                              left: 16, right: 16, top: 10, bottom: 10),
                          child: Row(
                            children: <Widget>[
                              Expanded(
                                child: Row(
                                  children: <Widget>[
                                    CircleAvatar(
                                      backgroundImage:
                                          AssetImage("assets/images/404.png"),
                                      maxRadius: 30,
                                    ),
                                    SizedBox(
                                      width: 16,
                                    ),
                                    Expanded(
                                      child: Container(
                                        color: Colors.transparent,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: <Widget>[
                                            Text(
                                              "amigo!.friend!.pseudo!",
                                              style: TextStyle(fontSize: 16),
                                            ),
                                            SizedBox(
                                              height: 6,
                                            ),
                                            Text(
                                              ' abonne(s)',
                                              style: TextStyle(
                                                  fontSize: 13,
                                                  color: Colors.grey.shade600,
                                                  fontWeight:
                                                      FontWeight.normal),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    Icon(
                                      Icons.send_sharp,
                                      color: Colors.green,
                                    )
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
