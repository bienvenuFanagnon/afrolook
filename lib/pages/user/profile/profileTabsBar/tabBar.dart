
import 'dart:math';

import 'package:afrotok/pages/user/profile/profileTabsBar/profileImageTab.dart';
import 'package:afrotok/pages/user/profile/profileTabsBar/profileVideosTab.dart';
import 'package:anim_search_bar/anim_search_bar.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:contained_tab_bar_view_with_custom_page_navigator/contained_tab_bar_view_with_custom_page_navigator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:intl/intl.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:popup_menu/popup_menu.dart';
import 'package:provider/provider.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../../constant/constColors.dart';
import '../../../../constant/iconGradient.dart';
import '../../../../constant/listItemsCarousel.dart';
import '../../../../constant/sizeText.dart';
import '../../../../constant/textCustom.dart';
import '../../../../models/model_data.dart';
import '../../../../providers/authProvider.dart';
import '../../../../providers/postProvider.dart';
import '../../../../providers/userProvider.dart';
import 'entreprise/postImage.dart';
import 'entreprise/postVideo.dart';

class UserPublicationView extends StatefulWidget {
  @override
  State<UserPublicationView> createState() => _UserPublicationViewState();
}

class _UserPublicationViewState extends State<UserPublicationView> {
  final _formKey = GlobalKey<FormState>();

  GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  late UserAuthProvider authProvider =
  Provider.of<UserAuthProvider>(context, listen: false);

  late UserProvider userProvider =
  Provider.of<UserProvider>(context, listen: false);

  late PostProvider postProvider =
  Provider.of<PostProvider>(context, listen: false);

  TextEditingController commentController =TextEditingController();
  String formaterDateTime2(DateTime dateTime) {
    DateTime now = DateTime.now();

    if (dateTime.year == now.year &&
        dateTime.month == now.month &&
        dateTime.day == now.day) {
      // Si la date est aujourd'hui, afficher seulement l'heure et la minute
      return DateFormat.Hm().format(dateTime);
    } else {
      // Sinon, afficher la date complète
      return DateFormat.yMd().add_Hms().format(dateTime);
    }
  }

  String formaterDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays < 1) {
      // Si c'est le même jour
      if (difference.inHours < 1) {
        // Si moins d'une heure
        if (difference.inMinutes < 1) {
          return "publié il y a quelques secondes";
        } else {
          return "publié il y a ${difference.inMinutes} minutes";
        }
      } else {
        return "publié il y a ${difference.inHours} heures";
      }
    } else if (difference.inDays < 7) {
      // Si la semaine n'est pas passée
      return "publié ${difference.inDays} jours plus tôt";
    } else {
      // Si le jour est passé
      return "publié depuis ${DateFormat('dd MMMM yyyy').format(dateTime)}";
    }
  }
  PopupMenu? postmenu;


  bool isUserAbonne(List<UserAbonnes> userAbonnesList, String userIdToCheck) {
    return userAbonnesList.any((userAbonne) => userAbonne.abonneUserId == userIdToCheck);
  }

  bool isIn(List<String> users_id, String userIdToCheck) {
    return users_id.any((item) => item == userIdToCheck);
  }

  bool isMyFriend(List<Friends> userfriendList, String userIdToCheck) {
    return userfriendList.any((userAbonne) => userAbonne.friendId == userIdToCheck);
  }
  bool isInvite(List<Invitation> invitationList, String userIdToCheck) {
    return invitationList.any((inv) => inv.receiverId == userIdToCheck);
  }

  void _showModalDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Menu d\'options'),
          content: SingleChildScrollView(
            child: Column(
              children: <Widget>[
                ListTile(
                  onTap: () {
                    Navigator.pop(context);
                  },
                  leading: Icon(Icons.flag,color: Colors.blueGrey,),
                  title: Text('Signaler',),
                ),
                ListTile(
                  onTap: () {
                    Navigator.pop(context);
                  },
                  leading: Icon(Icons.edit,color: Colors.blue,),
                  title: Text('Modifier'),
                ),
                ListTile(
                  onTap: () {
                    Navigator.pop(context);
                  },
                  leading: Icon(Icons.delete,color: Colors.red,),
                  title: Text('Supprimer'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  Widget homeProfileUsers(UserData user)  {


    //authProvider.getCurrentUser(authProvider.loginUserData!.id!);
    //  print("invitation : ${authProvider.loginUserData.mesInvitationsEnvoyer!.length}");

    bool abonneTap =false;
    bool inviteTap =false;
    bool dejaInviter =false;

    return Padding(
      padding: const EdgeInsets.all(1.0),
      child: Card(
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(4.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [


              ClipRRect(
                borderRadius: BorderRadius.all(Radius.circular(10)),
                child: Container(
                  width: 120,height: 100,
                  child: CachedNetworkImage(
                    fit: BoxFit.cover,

                    imageUrl: '${user.imageUrl!}',
                    progressIndicatorBuilder: (context, url, downloadProgress) =>
                    //  LinearProgressIndicator(),

                    Skeletonizer(
                        child: SizedBox(width: 120,height: 100, child:  ClipRRect(
                            borderRadius: BorderRadius.all(Radius.circular(10)),child: Image.asset('assets/images/404.png')))),
                    errorWidget: (context, url, error) =>  Container(width: 120,height: 100,child: Image.asset("assets/icon/user-removebg-preview.png",fit: BoxFit.cover,)),
                  ),
                ),
              ),


              Padding(
                padding: const EdgeInsets.only(top: 2.0,bottom: 2),
                child: SizedBox(
                  //width: 70,
                  child: Container(
                    alignment: Alignment.center,
                    child: TextCustomerPostDescription(
                      titre: "@${user.pseudo}",
                      fontSize: SizeText.homeProfileTextSize,
                      couleur: ConstColors.textColors,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              StatefulBuilder(

                  builder: (BuildContext context, void Function(void Function()) setState) {

                    return Container(
                      child:  isMyFriend(authProvider.loginUserData.friends!, user.id!)?
                      ElevatedButton(

                          onPressed: (){}, child:  Container(child: TextCustomerUserTitle(
                        titre: "discuter",
                        fontSize: SizeText.homeProfileTextSize,
                        couleur: Colors.blue,
                        fontWeight: FontWeight.w600,
                      ),))
                          :!isInvite(authProvider.loginUserData.mesInvitationsEnvoyer!, user.id!)?
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0,bottom:8 ),
                        child: Container(
                          width: 120,
                          height: 30,
                          child: ElevatedButton(
                            onPressed:inviteTap?
                                ()  { }:
                                ()async{
                              if (!isInvite(authProvider.loginUserData.mesInvitationsEnvoyer!, user.id!)) {
                                setState(() {
                                  inviteTap=true;
                                });
                                Invitation invitation = Invitation();
                                invitation.senderId=authProvider.loginUserData.id;
                                invitation.receiverId=user.id;
                                invitation.status=InvitationStatus.ENCOURS.name;
                                invitation.createdAt  = DateTime.now().millisecondsSinceEpoch;
                                invitation.updatedAt  = DateTime.now().millisecondsSinceEpoch;

                                // invitation.inviteUser=authProvider.loginUserData!;
                                await  userProvider.sendInvitation(invitation,context).then((value) async {
                                  if (value) {

                                    // await userProvider.getUsers(authProvider.loginUserData!.id!);
                                    authProvider.loginUserData.mesInvitationsEnvoyer!.add(invitation);
                                    await authProvider.getCurrentUser(authProvider.loginUserData!.id!);
                                    SnackBar snackBar = SnackBar(
                                      content: Text('invitation envoyée',textAlign: TextAlign.center,style: TextStyle(color: Colors.green),),
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(snackBar);

                                  }  else{
                                    SnackBar snackBar = SnackBar(
                                      content: Text('une erreur',textAlign: TextAlign.center,style: TextStyle(color: Colors.red),),
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(snackBar);

                                  }
                                },);


                                setState(() {
                                  inviteTap=false;
                                });
                              }
                            },
                            child:inviteTap? Center(
                              child: LoadingAnimationWidget.flickr(
                                size: 20,
                                leftDotColor: Colors.green,
                                rightDotColor: Colors.black,
                              ),
                            ): TextCustomerUserTitle(
                              titre: "inviter",
                              fontSize: SizeText.homeProfileTextSize,
                              couleur: Colors.blue,
                              fontWeight: FontWeight.w600,
                            ),),
                        ),
                      ):Padding(
                        padding: const EdgeInsets.only(top: 8.0,bottom:8 ),
                        child: Container(
                          width: 120,
                          height: 30,
                          child: ElevatedButton(
                            onPressed:
                                ()  { },
                            child:TextCustomerUserTitle(
                              titre: "déjà invité",
                              fontSize: SizeText.homeProfileTextSize,
                              couleur: Colors.green,
                              fontWeight: FontWeight.w600,
                            ),),
                        ),
                      ),
                    );
                  }
              ),
              StatefulBuilder(

                  builder: (BuildContext context, void Function(void Function()) setState) {
                    return Container(
                      child:    isUserAbonne(authProvider.loginUserData.userAbonnes!, user.id!)?
                      Container(
                        width: 120,
                        height: 30,
                        child: ElevatedButton(
                          onPressed:
                              ()  { },
                          child: TextCustomerUserTitle(
                            titre: "abonné",
                            fontSize: SizeText.homeProfileTextSize,
                            couleur: Colors.green,
                            fontWeight: FontWeight.w600,
                          ),),
                      ):Container(
                        width: 120,
                        height: 30,
                        child: ElevatedButton(
                          onPressed:abonneTap?
                              ()  { }:
                              ()async{
                            if (!isUserAbonne(authProvider.loginUserData.userAbonnes!, user!.id!)) {
                              setState(() {
                                abonneTap=true;
                              });
                              UserAbonnes userAbonne = UserAbonnes();
                              userAbonne.compteUserId=authProvider.loginUserData.id;
                              userAbonne.abonneUserId=user!.id;

                              userAbonne.createdAt  = DateTime.now().millisecondsSinceEpoch;
                              userAbonne.updatedAt  = DateTime.now().millisecondsSinceEpoch;
                              await  userProvider.sendAbonnementRequest(userAbonne,user,context).then((value) async {
                                if (value) {

                                  // await userProvider.getUsers(authProvider.loginUserData!.id!);
                                  authProvider.loginUserData.userAbonnes!.add(userAbonne);
                                  await authProvider.getCurrentUser(authProvider.loginUserData!.id!);
                                  SnackBar snackBar = SnackBar(
                                    content: Text('abonné',textAlign: TextAlign.center,style: TextStyle(color: Colors.green),),
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(snackBar);
                                  setState(() {
                                    abonneTap=false;
                                  });
                                }  else{
                                  SnackBar snackBar = SnackBar(
                                    content: Text('une erreur',textAlign: TextAlign.center,style: TextStyle(color: Colors.red),),
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(snackBar);
                                  setState(() {
                                    abonneTap=false;
                                  });
                                }
                              },);


                              setState(() {
                                abonneTap=false;
                              });
                            }
                          },
                          child:abonneTap? Center(
                            child: LoadingAnimationWidget.flickr(
                              size: 20,
                              leftDotColor: Colors.green,
                              rightDotColor: Colors.black,
                            ),
                          ): TextCustomerUserTitle(
                            titre: "S'abonner",
                            fontSize: SizeText.homeProfileTextSize,
                            couleur: Colors.red,
                            fontWeight: FontWeight.w600,
                          ),),
                      ),
                    );
                  }
              )



            ],
          ),
        ),
      ),
    );


  }





  @override
  Widget build(BuildContext context) {
    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;
    return Container(
        child:   SizedBox(
          // width: width,
          //height:height*0.86 ,
          child: ContainedTabBarView(
            tabs: [
              Container(
                child: TextCustomerMenu(
                  titre: "Simple",
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
              ProfileImageTab(),
              ProfileVideoTab(),
            ],
            onChange: (index) => print(index),
          ),
        ),

      );
  }
}

class EntreprisePublicationView extends StatefulWidget {
  @override
  State<EntreprisePublicationView> createState() => _EntreprisePublicationViewState();
}

class _EntreprisePublicationViewState extends State<EntreprisePublicationView> {

  final _formKey = GlobalKey<FormState>();

  GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  late UserAuthProvider authProvider =
  Provider.of<UserAuthProvider>(context, listen: false);

  late UserProvider userProvider =
  Provider.of<UserProvider>(context, listen: false);

  late PostProvider postProvider =
  Provider.of<PostProvider>(context, listen: false);

  TextEditingController commentController =TextEditingController();
  String formaterDateTime2(DateTime dateTime) {
    DateTime now = DateTime.now();

    if (dateTime.year == now.year &&
        dateTime.month == now.month &&
        dateTime.day == now.day) {
      // Si la date est aujourd'hui, afficher seulement l'heure et la minute
      return DateFormat.Hm().format(dateTime);
    } else {
      // Sinon, afficher la date complète
      return DateFormat.yMd().add_Hms().format(dateTime);
    }
  }

  String formaterDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays < 1) {
      // Si c'est le même jour
      if (difference.inHours < 1) {
        // Si moins d'une heure
        if (difference.inMinutes < 1) {
          return "publié il y a quelques secondes";
        } else {
          return "publié il y a ${difference.inMinutes} minutes";
        }
      } else {
        return "publié il y a ${difference.inHours} heures";
      }
    } else if (difference.inDays < 7) {
      // Si la semaine n'est pas passée
      return "publié ${difference.inDays} jours plus tôt";
    } else {
      // Si le jour est passé
      return "publié depuis ${DateFormat('dd MMMM yyyy').format(dateTime)}";
    }
  }
  PopupMenu? postmenu;


  bool isUserAbonne(List<UserAbonnes> userAbonnesList, String userIdToCheck) {
    return userAbonnesList.any((userAbonne) => userAbonne.abonneUserId == userIdToCheck);
  }

  bool isIn(List<String> users_id, String userIdToCheck) {
    return users_id.any((item) => item == userIdToCheck);
  }

  bool isMyFriend(List<Friends> userfriendList, String userIdToCheck) {
    return userfriendList.any((userAbonne) => userAbonne.friendId == userIdToCheck);
  }
  bool isInvite(List<Invitation> invitationList, String userIdToCheck) {
    return invitationList.any((inv) => inv.receiverId == userIdToCheck);
  }

  void _showModalDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Menu d\'options'),
          content: SingleChildScrollView(
            child: Column(
              children: <Widget>[
                ListTile(
                  onTap: () {
                    Navigator.pop(context);
                  },
                  leading: Icon(Icons.flag,color: Colors.blueGrey,),
                  title: Text('Signaler',),
                ),
                ListTile(
                  onTap: () {
                    Navigator.pop(context);
                  },
                  leading: Icon(Icons.edit,color: Colors.blue,),
                  title: Text('Modifier'),
                ),
                ListTile(
                  onTap: () {
                    Navigator.pop(context);
                  },
                  leading: Icon(Icons.delete,color: Colors.red,),
                  title: Text('Supprimer'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  Widget homeProfileUsers(UserData user)  {


    //authProvider.getCurrentUser(authProvider.loginUserData!.id!);
    //  print("invitation : ${authProvider.loginUserData.mesInvitationsEnvoyer!.length}");

    bool abonneTap =false;
    bool inviteTap =false;
    bool dejaInviter =false;

    return Padding(
      padding: const EdgeInsets.all(1.0),
      child: Card(
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(4.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [


              ClipRRect(
                borderRadius: BorderRadius.all(Radius.circular(10)),
                child: Container(
                  width: 120,height: 100,
                  child: CachedNetworkImage(
                    fit: BoxFit.cover,

                    imageUrl: '${user.imageUrl!}',
                    progressIndicatorBuilder: (context, url, downloadProgress) =>
                    //  LinearProgressIndicator(),

                    Skeletonizer(
                        child: SizedBox(width: 120,height: 100, child:  ClipRRect(
                            borderRadius: BorderRadius.all(Radius.circular(10)),child: Image.asset('assets/images/404.png')))),
                    errorWidget: (context, url, error) =>  Container(width: 120,height: 100,child: Image.asset("assets/icon/user-removebg-preview.png",fit: BoxFit.cover,)),
                  ),
                ),
              ),


              Padding(
                padding: const EdgeInsets.only(top: 2.0,bottom: 2),
                child: SizedBox(
                  //width: 70,
                  child: Container(
                    alignment: Alignment.center,
                    child: TextCustomerPostDescription(
                      titre: "@${user.pseudo}",
                      fontSize: SizeText.homeProfileTextSize,
                      couleur: ConstColors.textColors,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              StatefulBuilder(

                  builder: (BuildContext context, void Function(void Function()) setState) {

                    return Container(
                      child:  isMyFriend(authProvider.loginUserData.friends!, user.id!)?
                      ElevatedButton(

                          onPressed: (){}, child:  Container(child: TextCustomerUserTitle(
                        titre: "discuter",
                        fontSize: SizeText.homeProfileTextSize,
                        couleur: Colors.blue,
                        fontWeight: FontWeight.w600,
                      ),))
                          :!isInvite(authProvider.loginUserData.mesInvitationsEnvoyer!, user.id!)?
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0,bottom:8 ),
                        child: Container(
                          width: 120,
                          height: 30,
                          child: ElevatedButton(
                            onPressed:inviteTap?
                                ()  { }:
                                ()async{
                              if (!isInvite(authProvider.loginUserData.mesInvitationsEnvoyer!, user.id!)) {
                                setState(() {
                                  inviteTap=true;
                                });
                                Invitation invitation = Invitation();
                                invitation.senderId=authProvider.loginUserData.id;
                                invitation.receiverId=user.id;
                                invitation.status=InvitationStatus.ENCOURS.name;
                                invitation.createdAt  = DateTime.now().millisecondsSinceEpoch;
                                invitation.updatedAt  = DateTime.now().millisecondsSinceEpoch;

                                // invitation.inviteUser=authProvider.loginUserData!;
                                await  userProvider.sendInvitation(invitation,context).then((value) async {
                                  if (value) {

                                    // await userProvider.getUsers(authProvider.loginUserData!.id!);
                                    authProvider.loginUserData.mesInvitationsEnvoyer!.add(invitation);
                                    await authProvider.getCurrentUser(authProvider.loginUserData!.id!);
                                    SnackBar snackBar = SnackBar(
                                      content: Text('invitation envoyée',textAlign: TextAlign.center,style: TextStyle(color: Colors.green),),
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(snackBar);

                                  }  else{
                                    SnackBar snackBar = SnackBar(
                                      content: Text('une erreur',textAlign: TextAlign.center,style: TextStyle(color: Colors.red),),
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(snackBar);

                                  }
                                },);


                                setState(() {
                                  inviteTap=false;
                                });
                              }
                            },
                            child:inviteTap? Center(
                              child: LoadingAnimationWidget.flickr(
                                size: 20,
                                leftDotColor: Colors.green,
                                rightDotColor: Colors.black,
                              ),
                            ): TextCustomerUserTitle(
                              titre: "inviter",
                              fontSize: SizeText.homeProfileTextSize,
                              couleur: Colors.blue,
                              fontWeight: FontWeight.w600,
                            ),),
                        ),
                      ):Padding(
                        padding: const EdgeInsets.only(top: 8.0,bottom:8 ),
                        child: Container(
                          width: 120,
                          height: 30,
                          child: ElevatedButton(
                            onPressed:
                                ()  { },
                            child:TextCustomerUserTitle(
                              titre: "déjà invité",
                              fontSize: SizeText.homeProfileTextSize,
                              couleur: Colors.green,
                              fontWeight: FontWeight.w600,
                            ),),
                        ),
                      ),
                    );
                  }
              ),
              StatefulBuilder(

                  builder: (BuildContext context, void Function(void Function()) setState) {
                    return Container(
                      child:    isUserAbonne(authProvider.loginUserData.userAbonnes!, user.id!)?
                      Container(
                        width: 120,
                        height: 30,
                        child: ElevatedButton(
                          onPressed:
                              ()  { },
                          child: TextCustomerUserTitle(
                            titre: "abonné",
                            fontSize: SizeText.homeProfileTextSize,
                            couleur: Colors.green,
                            fontWeight: FontWeight.w600,
                          ),),
                      ):Container(
                        width: 120,
                        height: 30,
                        child: ElevatedButton(
                          onPressed:abonneTap?
                              ()  { }:
                              ()async{
                            if (!isUserAbonne(authProvider.loginUserData.userAbonnes!, user!.id!)) {
                              setState(() {
                                abonneTap=true;
                              });
                              UserAbonnes userAbonne = UserAbonnes();
                              userAbonne.compteUserId=authProvider.loginUserData.id;
                              userAbonne.abonneUserId=user!.id;

                              userAbonne.createdAt  = DateTime.now().millisecondsSinceEpoch;
                              userAbonne.updatedAt  = DateTime.now().millisecondsSinceEpoch;
                              await  userProvider.sendAbonnementRequest(userAbonne,user,context).then((value) async {
                                if (value) {

                                  // await userProvider.getUsers(authProvider.loginUserData!.id!);
                                  authProvider.loginUserData.userAbonnes!.add(userAbonne);
                                  await authProvider.getCurrentUser(authProvider.loginUserData!.id!);
                                  SnackBar snackBar = SnackBar(
                                    content: Text('abonné',textAlign: TextAlign.center,style: TextStyle(color: Colors.green),),
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(snackBar);
                                  setState(() {
                                    abonneTap=false;
                                  });
                                }  else{
                                  SnackBar snackBar = SnackBar(
                                    content: Text('une erreur',textAlign: TextAlign.center,style: TextStyle(color: Colors.red),),
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(snackBar);
                                  setState(() {
                                    abonneTap=false;
                                  });
                                }
                              },);


                              setState(() {
                                abonneTap=false;
                              });
                            }
                          },
                          child:abonneTap? Center(
                            child: LoadingAnimationWidget.flickr(
                              size: 20,
                              leftDotColor: Colors.green,
                              rightDotColor: Colors.black,
                            ),
                          ): TextCustomerUserTitle(
                            titre: "S'abonner",
                            fontSize: SizeText.homeProfileTextSize,
                            couleur: Colors.red,
                            fontWeight: FontWeight.w600,
                          ),),
                      ),
                    );
                  }
              )



            ],
          ),
        ),
      ),
    );


  }





  @override
  Widget build(BuildContext context) {
    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;
    return Container(
      child:   SizedBox(
        // width: width,
        //height:height*0.86 ,
        child: ContainedTabBarView(
          tabs: [
            Container(
              child: TextCustomerMenu(
                titre: "Simple",
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
            ProfileUserEntrepriseImageTab(),
            ProfileUserEntrepriseVideoTab(),
          ],
          onChange: (index) => print(index),
        ),
      ),

    );
  }
}