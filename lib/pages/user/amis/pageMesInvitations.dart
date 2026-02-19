

import 'dart:async';

import 'package:afrotok/services/api.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:provider/provider.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../constant/constColors.dart';
import '../../../models/model_data.dart';
import '../../../providers/authProvider.dart';
import '../../../providers/userProvider.dart';
import '../../auth/authTest/constants.dart';
import '../../pub/native_ad_widget.dart';
import '../detailsOtherUser.dart';


class MesInvitationsPage extends StatefulWidget {
  final BuildContext context;
  MesInvitationsPage({super.key, required this.context});

  @override
  State<MesInvitationsPage> createState() => _MesInvitationsState();
}

class _MesInvitationsState extends State<MesInvitationsPage> {
  String formatNumber(int number) {
    if (number >= 1000) {
      double nombre = number / 1000;
      return nombre.toStringAsFixed(1) + 'k';
    } else {
      return number.toString();
    }
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
  late UserAuthProvider authProvider =
  Provider.of<UserAuthProvider>(widget.context, listen: false);

  late UserProvider userProvider =
  Provider.of<UserProvider>(widget.context, listen: false);

  Widget invitationData(Invitation userInvitation) {
    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;
    bool inviteTap=false;
    bool refusInviteTap=false;
    return  Container(
      padding: EdgeInsets.only(left: 16,right: 16,top: 10,bottom: 10),
      child: Row(
        children: <Widget>[
          Expanded(
            child:  GestureDetector(


              onTap: () {
                _showUserDetailsModalDialog(userInvitation.inviteUser!,width,height);
              },
              child: Row(
                children: <Widget>[
                  CircleAvatar(
                    backgroundImage: NetworkImage("${userInvitation.inviteUser!.imageUrl!}"),
                    maxRadius: 30,
                    onBackgroundImageError: (exception, stackTrace) => AssetImage('assets/icon/user-removebg-preview.png'),
                  ),
                  SizedBox(width: 16,),
                  Container(
                    color: Colors.transparent,
                    child: Row(
                      spacing: 10,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text("@${userInvitation.inviteUser!.pseudo!}".toLowerCase(), style: TextStyle(fontSize: 16),),
                            SizedBox(height: 5,),
                            Text('${formatNumber(userInvitation.inviteUser!.abonnes!)} abonné(s)',style: TextStyle(fontSize: 13,color: Colors.grey.shade600, fontWeight: FontWeight.normal),),
                            SizedBox(height: 5,),
                            Text('${formatNumber(userInvitation.inviteUser!.userlikes!)} like(s)',style: TextStyle(fontSize: 13,color: Colors.grey.shade600, fontWeight: FontWeight.normal),),
                          ],
                        ),
                        Visibility(
                          visible: userInvitation.inviteUser!.isVerify!||userInvitation.inviteUser!.isVerify==false!?false:true,
                          child: Card(
                            child: const Icon(
                              Icons.verified,
                              color: Colors.green,
                              size: 17,
                            ),
                          ),
                        )
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Row(
            children: [
              TextButton(onPressed: inviteTap?() {}: () async {
                setState(() {
                  inviteTap =true;
                });



                await  userProvider.acceptInvitation(userInvitation).then((value) async {
                  if (value) {
                    authProvider.loginUserData.friendsIds!.add(userInvitation.inviteUser!.id!);
                    await userProvider.updateUser(authProvider.loginUserData);

                    await authProvider.sendNotification(
                        userIds: [userInvitation.inviteUser!.oneIgnalUserid!],
                        smallImage: "${authProvider.loginUserData.imageUrl!}",
                        send_user_id: "${authProvider.loginUserData.id!}",
                        recever_user_id: "${userInvitation.inviteUser!.id!}",
                        message: "📢 @${authProvider.loginUserData.pseudo!} a accepté(e) votre invitation !",
                        type_notif: NotificationType.ACCEPTINVITATION.name,
                        post_id: "",
                        post_type: "", chat_id: ''
                    );
                    final FirebaseFirestore firestore = FirebaseFirestore.instance;

                    NotificationData notif=NotificationData();
                    notif.id=firestore
                        .collection('Notifications')
                        .doc()
                        .id;
                    notif.titre="Abonnement ✅";
                    notif.media_url=authProvider.loginUserData.imageUrl;
                    notif.type=NotificationType.ACCEPTINVITATION.name;
                    notif.description="@${authProvider.loginUserData.pseudo!} a accepté(e) votre invitation !";
                    notif.users_id_view=[];
                    notif.user_id=authProvider.loginUserData.id;
                    notif.receiver_id="";
                    notif.post_id="";
                    notif.post_data_type="";
                    notif.updatedAt =
                        DateTime.now().microsecondsSinceEpoch;
                    notif.createdAt =
                        DateTime.now().microsecondsSinceEpoch;
                    notif.status = PostStatus.VALIDE.name;

                    // users.add(pseudo.toJson());

                    await firestore.collection('Notifications').doc(notif.id).set(notif.toJson());



                    ScaffoldMessenger.of(widget.context).showSnackBar(new SnackBar(
                      //  key: widget.formKey,
                      content: Center(child: Text("invitation acceptée!",style: TextStyle(color: Colors.green),)),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),

                      margin: EdgeInsets.only(
                          bottom: MediaQuery.of(widget.context).size.height - 100,
                          right: 20,
                          left: 20),
                    ));


                    await authProvider.getToken().then((value) {

                    },);
                   // await  authProvider.getUserByToken(token: authProvider.token!);
                    await userProvider.getUsersProfile(authProvider.loginUserData!.id!,context);


                  }  else{
                    ScaffoldMessenger.of(widget.context).showSnackBar(new SnackBar(
                      content: Center(child: Text("Erreur lors de l'acceptation.",style: TextStyle(color: Colors.red),)),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      margin: EdgeInsets.only(
                          bottom: MediaQuery.of(widget.context).size.height - 100,
                          right: 20,
                          left: 20),
                    ));



                  }




                },);

                setState(() {
                  inviteTap =false;
                });


              },
                  child:inviteTap?Center(
                    child: LoadingAnimationWidget.flickr(
                      size: 15,
                      leftDotColor: Colors.green,
                      rightDotColor: Colors.black,
                    ),
                  ): Text('Accepter',style: TextStyle(fontSize: 12,fontWeight:FontWeight.normal,color: Colors.blue),)
              ),


              TextButton(onPressed: refusInviteTap?() {}: () async {
                setState(() {
                  refusInviteTap =true;
                });



                await  userProvider.refuserInvitation(userInvitation).then((value) async {
                  if (value) {

                    ScaffoldMessenger.of(widget.context).showSnackBar(new SnackBar(
                      //  key: widget.formKey,
                      content: Center(child: Text("invitation refusée!",style: TextStyle(color: Colors.green),)),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),

                      margin: EdgeInsets.only(
                          bottom: MediaQuery.of(widget.context).size.height - 100,
                          right: 20,
                          left: 20),
                    ));


                    await authProvider.getToken().then((value) {

                    },);
                    //await  authProvider.getUserByToken(token: authProvider.token!);
                    await userProvider.getUsersProfile(authProvider.loginUserData!.id!,context);


                  }  else{
                    ScaffoldMessenger.of(widget.context).showSnackBar(new SnackBar(
                      content: Center(child: Text("Erreur.",style: TextStyle(color: Colors.red),)),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      margin: EdgeInsets.only(
                          bottom: MediaQuery.of(widget.context).size.height - 100,
                          right: 20,
                          left: 20),
                    ));



                  }




                },);

                setState(() {
                  refusInviteTap =false;
                });


              },
                  child:refusInviteTap?Center(
                    child: LoadingAnimationWidget.flickr(
                      size: 15,
                      leftDotColor: Colors.green,
                      rightDotColor: Colors.black,
                    ),
                  ): Text('Refuser',style: TextStyle(fontSize: 12,fontWeight:FontWeight.normal,color: Colors.red),)
              ),
            ],
          ),

        ],
      ),
    );
  }

  bool dejaAmi(List<Friends> invitationList, int userIdToCheck) {
    return invitationList.any((userAbonne) => userAbonne.friendId! == userIdToCheck);
  }

  Stream<List<Invitation>> getData() async* {
    List<Invitation> invitations = [];
    var invitationsStream =FirebaseFirestore.instance.collection('Invitations')
        .where('receiver_id', isEqualTo: authProvider.loginUserData.id!)
        .where('status', isEqualTo: "${InvitationStatus.ENCOURS.name}")
        .snapshots();




    await for (var invitationsSnapshot in invitationsStream) {

      for (var invitationDoc in invitationsSnapshot.docs) {

        CollectionReference userCollect = await FirebaseFirestore.instance.collection('Users');
        QuerySnapshot querySnapshotUser = await userCollect.where("id",isEqualTo: invitationDoc["sender_id"]!).get();
        // Afficher la liste
        List<UserData> userList = querySnapshotUser.docs.map((doc) =>
            UserData.fromJson(doc.data() as Map<String, dynamic>)).toList();
        //userData=userList.first;

        Invitation invitation;
        if (userList.first != null) {
          invitation=Invitation.fromJson(invitationDoc.data());
          invitation.inviteUser=userList.first;
          invitations.add(invitation);
        }

        userProvider.countInvitations=invitations.length;

      }
      yield invitations;
    }
  }



  final _myStreamController = StreamController.broadcast();

  Stream get myStream => _myStreamController.stream;

  // Autres méthodes pour ajouter des données au stream, etc.
  void dispose() {
    super.dispose();
    _myStreamController.close();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Mes Invitations'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.only(top: 16, left: 16, right: 16),
              child: TextField(
                cursorColor: kPrimaryColor,
                decoration: InputDecoration(
                  focusColor: ConstColors.buttonColors,
                  focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: kPrimaryColor)),
                  hintText: "Search...",
                  hintStyle: TextStyle(color: Colors.grey.shade600),
                  prefixIcon: Icon(Icons.search,
                      color: Colors.grey.shade600, size: 20),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  contentPadding: EdgeInsets.all(8),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(color: Colors.grey.shade100)),
                ),
              ),
            ),

            StreamBuilder<List<Invitation>>(
              stream: getData()!,
              builder: (context, AsyncSnapshot<List<Invitation>> snapshot) {
                if (snapshot.hasData) {
                  final invitations = snapshot.data!;

                  // ✅ Si la liste est vide, afficher la pub + message vide
                  if (invitations.isEmpty) {
                    return Column(
                      children: [
                        // La pub en premier
                        _buildAdBanner(key: 'invitations_empty_ad'),
                        SizedBox(height: 20),
                        Center(
                          child: Column(
                            children: [
                              Image.asset('assets/images/404.png',
                                  height: 200, width: 200),
                              SizedBox(height: 16),
                              Text(
                                "Aucune invitation",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                "Vous n'avez pas d'invitation en attente",
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }

                  // ✅ Liste avec pub en premier élément
                  return Column(
                    children: [
                      // La pub en premier
                      _buildAdBanner(key: 'invitations_list_first_ad'),
                      SizedBox(height: 8),

                      // Ensuite la liste des invitations
                      ListView.builder(
                        scrollDirection: Axis.vertical,
                        itemCount: invitations.length,
                        shrinkWrap: true,
                        padding: EdgeInsets.only(top: 16),
                        physics: NeverScrollableScrollPhysics(),
                        itemBuilder: (context, index) {
                          return GestureDetector(
                            onTap: () {
                              //Navigator.pushNamed(context, '/basic_chat');
                            },
                            child: invitationData(invitations[index]!),
                          );
                        },
                      ),
                    ],
                  );
                } else if (snapshot.hasError) {
                  // ✅ En cas d'erreur, afficher la pub + message d'erreur
                  return Column(
                    children: [
                      _buildAdBanner(key: 'invitations_error_ad'),
                      SizedBox(height: 20),
                      Center(
                        child: Column(
                          children: [
                            Image.asset('assets/images/404.png',
                                height: 200, width: 200),
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
                                // Réessayez de charger la page.
                                setState(() {});
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                } else {
                  // ✅ Pendant le chargement, afficher un skeleton
                  return Column(
                    children: [
                      _buildAdBanner(key: 'invitations_loading_ad'),
                      SizedBox(height: 20),
                      Center(
                        child: CircularProgressIndicator(color: Colors.green),
                      ),
                    ],
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

// ✅ Ajoutez cette fonction dans votre classe
  Widget _buildAdBanner({required String key}) {
    return Container(
      key: ValueKey(key),
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: NativeAdWidget(
        templateType: TemplateType.small,
        onAdLoaded: () {
          print('✅ Native Ad chargée dans invitations: $key');
        },
      ),
    );
  }
}


