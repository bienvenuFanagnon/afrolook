
import 'package:afrotok/models/model_data.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:country_flags/country_flags.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:intl/intl.dart';
import 'package:like_button/like_button.dart';
import 'package:popup_menu/popup_menu.dart';
import 'package:provider/provider.dart';
import 'package:random_color/random_color.dart';
import 'package:rate_in_stars/rate_in_stars.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:tiktok_double_tap_like/double_tap_like_widget.dart';

import '../../constant/constColors.dart';
import '../../constant/textCustom.dart';


import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:afrotok/constant/sizeText.dart';

import 'package:badges/badges.dart' as badges;
import 'package:flutter/services.dart';

import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:marquee/marquee.dart';
import 'package:page_transition/page_transition.dart';
import 'package:popup_menu_plus/popup_menu_plus.dart';

import '../../models/chatmodels/message.dart';

import '../../providers/afroshop/authAfroshopProvider.dart';
import '../../providers/afroshop/categorie_produits_provider.dart';
import '../../providers/authProvider.dart';
import '../../providers/userProvider.dart';
import '../chat/myChat.dart';
import '../component/consoleWidget.dart';
import 'conponent.dart';
import 'operation.dart';
import 'otherUser/otherUser.dart';


class DetailsOtherUser extends StatefulWidget {
  late  UserData user;
  final double w;
  final double h;
   DetailsOtherUser({super.key, required this.user, required this.w, required this.h});

  @override
  State<DetailsOtherUser> createState() => _DetailsOtherUserState();
}

class _DetailsOtherUserState extends State<DetailsOtherUser> with TickerProviderStateMixin {

  late AnimationController _starController;
  late AnimationController _unlikeController;
  late Animation<double> _offsetAnimation ;
  late Animation<double> _starAnimation ;
  late UserAuthProvider authProvider =
  Provider.of<UserAuthProvider>(context, listen: false);
  late UserShopAuthProvider authProviderShop =
  Provider.of<UserShopAuthProvider>(context, listen: false);
  late CategorieProduitProvider categorieProduitProvider =
  Provider.of<CategorieProduitProvider>(context, listen: false);
  late UserProvider userProvider =
  Provider.of<UserProvider>(context, listen: false);

  String formatNumber(int number) {
    if (number >= 1000) {
      double nombre = number / 1000;
      return nombre.toStringAsFixed(1) + 'k';
    } else {
      return number.toString();
    }
  }






  RandomColor _randomColor = RandomColor();

  bool inviteTap = false;
  bool abonneTap = false;

  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  bool isLike=false;




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


  String formatAbonnes(int nbAbonnes) {
    if (nbAbonnes >= 1000) {
      double nombre = nbAbonnes / 1000;
      return nombre.toStringAsFixed(1) + 'k';
    } else {
      return nbAbonnes.toString();
    }
  }
  bool isUserAbonne(List<String> userAbonnesList, String userIdToCheck) {
    return userAbonnesList.any((userAbonneId) => userAbonneId == userIdToCheck);
  }

  bool isIn(List<String> users_id, String userIdToCheck) {
    return users_id.any((item) => item == userIdToCheck);
  }


  Future<Chat> getChatsData(UserData amigo) async {

    // Définissez la requête
    var friendsStream = FirebaseFirestore.instance.collection('Chats').where( Filter.or(
      Filter('docId', isEqualTo:  '${amigo.id}${authProvider.loginUserData.id!}'),
      Filter('docId', isEqualTo:  '${authProvider.loginUserData.id!}${amigo.id}'),

    )).snapshots();

// Obtenez la liste des utilisateurs
    //List<DocumentSnapshot> users = await usersQuery.sget();
    Chat usersChat=Chat();

    if (await friendsStream.isEmpty) {
      print("pas de chat ");
      String chatId = FirebaseFirestore.instance
          .collection('Chats')
          .doc()
          .id;
      Chat chat = Chat(
        docId:'${amigo.id}${authProvider.loginUserData.id!}',
        id: chatId,
        senderId: authProvider.loginUserData.id==amigo.id?'${amigo.id}':'${authProvider.loginUserData.id!}',
        receiverId: authProvider.loginUserData.id==amigo.id?'${authProvider.loginUserData.id!}':'${amigo.id}',
        lastMessage: 'hi',

        type: ChatType.USER.name,
        createdAt: DateTime.now().millisecondsSinceEpoch, // Get current time in milliseconds
        updatedAt: DateTime.now().millisecondsSinceEpoch,
        // Optional: You can initialize sender and receiver with UserData objects, and messages with a list of Message objects
      );
      await FirebaseFirestore.instance.collection('Chats').doc(chatId).set(chat.toJson());
      usersChat=chat;

    }  else{
      print("le chat existe  ");
      print("stream :${friendsStream}");
      usersChat= await friendsStream.first.then((value) async {
        print("stream value l :${value.docs.length}");
        if (value.docs.length<=0) {
          print("pas de chat ");

          String chatId = FirebaseFirestore.instance
              .collection('Chats')
              .doc()
              .id;
          Chat chat = Chat(
            docId:'${amigo.id}${authProvider.loginUserData.id!}',
            id: chatId,
            senderId: authProvider.loginUserData.id==amigo.id?'${amigo.id}':'${authProvider.loginUserData.id!}',
            receiverId: authProvider.loginUserData.id==amigo.id?'${authProvider.loginUserData.id!}':'${amigo.id}',
            lastMessage: 'hi',

            type: ChatType.USER.name,
            createdAt: DateTime.now().millisecondsSinceEpoch, // Get current time in milliseconds
            updatedAt: DateTime.now().millisecondsSinceEpoch,
            // Optional: You can initialize sender and receiver with UserData objects, and messages with a list of Message objects
          );
          await FirebaseFirestore.instance.collection('Chats').doc(chatId).set(chat.toJson());
          usersChat=chat;
          return chat;
        }  else{
          return  Chat.fromJson(value.docs.first.data());
        }

      });
      CollectionReference messageCollect = await FirebaseFirestore.instance.collection('Messages');
      QuerySnapshot querySnapshotMessage = await messageCollect.where("chat_id",isEqualTo:usersChat.id!).get();
      // Afficher la liste
      List<Message> messageList = querySnapshotMessage.docs.map((doc) =>
          Message.fromJson(doc.data() as Map<String, dynamic>)).toList();


      if (messageList.isEmpty) {
        usersChat.messages=[];
        userProvider.chat=usersChat;
        print("messgae vide ");
      }else{
        print("have messages");
        usersChat.messages=messageList;
        userProvider.chat=usersChat;
      }

      /////////////ami//////////
      CollectionReference friendCollect = await FirebaseFirestore.instance.collection('Users');
      QuerySnapshot querySnapshotUserSender = await friendCollect.where("id",isEqualTo:authProvider.loginUserData.id==amigo.id?'${amigo.id}':'${authProvider.loginUserData.id!}').get();
      // Afficher la liste
      QuerySnapshot querySnapshotUserReceiver= await friendCollect.where("id",isEqualTo:authProvider.loginUserData.id==amigo.id?'${authProvider.loginUserData.id!}':'${amigo.id}').get();


      List<UserData> receiverUserList = querySnapshotUserReceiver.docs.map((doc) =>
          UserData.fromJson(doc.data() as Map<String, dynamic>)).toList();
      usersChat.receiver=receiverUserList.first;

      List<UserData> senderUserList = querySnapshotUserSender.docs.map((doc) =>
          UserData.fromJson(doc.data() as Map<String, dynamic>)).toList();
      usersChat.sender=senderUserList.first;

    }

    return usersChat;
  }
  @override
  void initState() {
    // TODO: implement initState
    super.initState();

    _starController =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _unlikeController =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _offsetAnimation = Tween<double>(
      begin: 0.0,
      end: 90/360,
    ).animate(_unlikeController);

    _starAnimation = Tween<double>(
      begin: 1.0,
      end: 0.8,
    ).animate(_starController);
  }
  @override
  void dispose() {
    // TODO: implement dispose
    super.dispose();
    _starController.dispose();
    _unlikeController.dispose();

  }
  @override
  Widget build(BuildContext context) {
    double taux=widget.user.popularite!*100;
    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;
    double w = MediaQuery.of(context).size.width;
    return SingleChildScrollView(
      child: SizedBox(
        // width: widget.w,
        // height: widget.h,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.only(topLeft: Radius.circular(10),topRight: Radius.circular(10)),
              child: Container(
                width: widget.w,
                height: widget.h*0.5,
                child: CachedNetworkImage(
                  fit: BoxFit.cover,

                  imageUrl: '${widget.user.imageUrl!}',
                  progressIndicatorBuilder: (context, url, downloadProgress) =>
                  //  LinearProgressIndicator(),

                  Skeletonizer(
                      child: SizedBox(width: 120,height: 100, child:  ClipRRect(
                          borderRadius: BorderRadius.all(Radius.circular(10)),child: Image.asset('assets/images/404.png')))),
                  errorWidget: (context, url, error) =>  Container(width: 120,height: 100,child: Image.asset("assets/icon/user-removebg-preview.png",fit: BoxFit.cover,)),
                ),
              ),
            ),
            // Padding(
            //   padding: const EdgeInsets.all(5.0),
            //   child: Text(
            //     "Taper deux fois pour liker",
            //     style: const TextStyle(
            //       color: Colors.black,
            //       fontWeight: FontWeight.bold,
            //       fontSize: 10,
            //     ),
            //   ),
            // ),




            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0,bottom: 4),
                    child: SizedBox(
                      //width: 70,
                      child: Container(
                        alignment: Alignment.center,
                        child: TextCustomerPostDescription(
                          titre: "@${widget.user.pseudo}",
                          fontSize: 15,
                          couleur: ConstColors.textColors,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0,bottom: 4),
                    child: SizedBox(
                      //width: 70,
                      child: Container(
                        alignment: Alignment.center,
                        child: TextCustomerPostDescription(
                          titre: "${widget.user.userAbonnesIds!.length}",
                          fontSize: 15,
                          couleur: ConstColors.textColors,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0,bottom: 4),
                    child: SizedBox(
                      //width: 70,
                      child: Container(
                        alignment: Alignment.center,
                        child: TextCustomerPostDescription(
                          titre: "${taux.toStringAsFixed(2)} %",
                          fontSize: 15,
                          couleur: ConstColors.textColors,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Visibility(
              visible: widget.user!.isVerify!,
              child: const Icon(
                Icons.verified,
                color: Colors.green,
                size: 30,
              ),
            ),

            // Padding(
            //   padding: const EdgeInsets.only(top: 4.0,bottom: 4),
            //   child: SizedBox(
            //     //width: 70,
            //     child: Row(
            //       mainAxisAlignment: MainAxisAlignment.center,
            //       children: [
            //         Container(
            //           alignment: Alignment.center,
            //           child: TextCustomerPostDescription(
            //             titre: "${widget.user.userlikes}",
            //             fontSize: 15,
            //             couleur: Colors.green,
            //             fontWeight: FontWeight.w700,
            //           ),
            //         ),
            //         SizedBox(width: 5,),
            //         Icon(AntDesign.heart,color: Colors.red,),
            //       ],
            //     ),
            //   ),
            // ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 2,
              children: [
                Icon(Icons.group,color: Colors.blue,),
                Container(
                  alignment: Alignment.center,
                  child: TextCustomerPostDescription(
                    titre: "${widget. user.usersParrainer!.length} parrainages  ",
                    fontSize: 15,
                    couleur: Colors.black,
                    fontWeight: FontWeight.w900,
                  ),
                ),

              ],
            ),


            GestureDetector(
              onTap: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => OtherUserPage(otherUser: widget.user),
                    ));

              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                spacing: 5,
                children: [
                  SizedBox(width: 10,),
                  countryFlag(widget.user!.countryData!['countryCode']??"", size: 20),

                  Text("Voir le profil"),
                  IconButton(onPressed: () {

                  }, icon: Icon(Icons.remove_red_eye)),
                ],
              ),
            ),
            Visibility(
              visible:authProvider.loginUserData.id!=widget.user.id ,
              child: StatefulBuilder(

                  builder: (BuildContext context, void Function(void Function()) setState) {

                    return Container(
                      //width: w*0.45,
                      height: 50,
                      child:  isMyFriend(widget.user!,authProvider.loginUserData)?
                      Padding(
                        padding: const EdgeInsets.only(top: 1.0,bottom:8 ),
                        child: ElevatedButton(

                            onPressed: () async {
                              getChatsData(widget.user).then((chat) async {
                                CollectionReference friendCollect = await FirebaseFirestore.instance.collection('Messages');
                                QuerySnapshot querySnapshotUser = await friendCollect.where("chat_id",isEqualTo:chat.docId).get();
                                // Afficher la liste
                                List<Message> messages = querySnapshotUser.docs.map((doc) =>
                                    Message.fromJson(doc.data() as Map<String, dynamic>)).toList();
                                //snapshot.data![index].messages=messages;
                                userProvider.chat.messages=messages;
                                //Navigator.of(context).pop();
                                Navigator.push(context, PageTransition(type: PageTransitionType.fade, child: MyChat(title: 'mon chat', chat: chat,)));


                              },);

                            }, child:  Container(child: TextCustomerUserTitle(
                          titre: "envoyer un message",
                          fontSize: SizeText.homeProfileTextSize,
                          couleur: Colors.black,
                          fontWeight: FontWeight.w600,
                        ),)),
                      )
                          :!isInvite(widget.user,authProvider.loginUserData)?
                      Padding(
                        padding: const EdgeInsets.only(top: 1.0,bottom:8 ),
                        child: Container(
                          //width: 120,
                          //height: 30,
                          child: ElevatedButton(
                            onPressed:inviteTap?
                                ()  { }:
                                ()async{
                              if (!isInvite(widget.user,authProvider.loginUserData)) {
                                setState(() {
                                  inviteTap=true;
                                });
                                Invitation invitation = Invitation();
                                invitation.senderId=authProvider.loginUserData.id;
                                invitation.receiverId=widget.user.id;
                                invitation.status=InvitationStatus.ENCOURS.name;
                                invitation.createdAt  = DateTime.now().millisecondsSinceEpoch;
                                invitation.updatedAt  = DateTime.now().millisecondsSinceEpoch;

                                // invitation.inviteUser=authProvider.loginUserData!;
                                await  userProvider.sendInvitation(invitation,context).then((value) async {
                                  if (value) {

                                    // await userProvider.getUsers(authProvider.loginUserData!.id!);
                                    authProvider.loginUserData.mesInvitationsEnvoyer!.add(invitation);
                                    await authProvider.getCurrentUser(authProvider.loginUserData!.id!);
                                    NotificationData notif=NotificationData();
                                    notif.id=firestore
                                        .collection('Notifications')
                                        .doc()
                                        .id;
                                    notif.titre="Nouvelle Invitation";
                                    notif.media_url=authProvider.loginUserData.imageUrl;
                                    notif.type=NotificationType.INVITATION.name;
                                    notif.description="Une nouvelle invitation vous a été envoyé !";
                                    notif.users_id_view=[];
                                    notif.user_id=authProvider.loginUserData.id;
                                    notif.receiver_id=widget.user.id;
                                    notif.updatedAt =
                                        DateTime.now().microsecondsSinceEpoch;
                                    notif.createdAt =
                                        DateTime.now().microsecondsSinceEpoch;
                                    notif.status = PostStatus.VALIDE.name;

                                    // users.add(pseudo.toJson());

                                    await firestore.collection('Notifications').doc(notif.id).set(notif.toJson());
                                    print("///////////-- save notification --///////////////");
                                    SnackBar snackBar = SnackBar(
                                      content: Text('invitation envoyée',textAlign: TextAlign.center,style: TextStyle(color: Colors.green),),
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(snackBar);

                                    widget.user.autreInvitationsEnvoyerId!.add(authProvider.loginUserData.id!);
                                    authProvider.loginUserData!.mesInvitationsEnvoyerId!.add(widget.user.id!);
                                    userProvider.updateUser(widget.user);
                                    userProvider.updateUser(authProvider.loginUserData!);

                                    if (widget.user.oneIgnalUserid!=null&&widget.user.oneIgnalUserid!.length>5) {

                                      await authProvider.sendNotification(
                                          userIds: [widget.user.oneIgnalUserid!],
                                          smallImage: "${authProvider.loginUserData.imageUrl!}",
                                          send_user_id: "${authProvider.loginUserData.id!}",
                                          recever_user_id: "${widget.user.id!}",
                                          message: "📢 @${authProvider.loginUserData.pseudo!} vous a envoyé une invitation !",
                                          type_notif: NotificationType.INVITATION.name,
                                          post_id: "",
                                          post_type: "", chat_id: ''
                                      );

                                    }


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
                              titre: "envoyer une invitation",
                              fontSize: SizeText.homeProfileTextSize,
                              couleur: Colors.blue,
                              fontWeight: FontWeight.w600,
                            ),),
                        ),
                      ):
                      Padding(
                        padding: const EdgeInsets.only(top: 1.0,bottom:8 ),
                        child: Container(
                          //width: 120,
                          // height: 30,
                          child: ElevatedButton(
                            onPressed:
                                ()  { },
                            child:TextCustomerUserTitle(
                              titre: "invitation déjà envoyée",
                              fontSize: SizeText.homeProfileTextSize,
                              couleur: Colors.black38,
                              fontWeight: FontWeight.w600,
                            ),),
                        ),
                      ),
                    );
                  }
              ),
            ),
            SizedBox(height: 5,),
            Visibility(
              visible:authProvider.loginUserData.id!=widget.user.id ,

              child: StatefulBuilder(

                  builder: (BuildContext context, void Function(void Function()) setState) {
                    return Container(
                      child:    isUserAbonne(widget.user.userAbonnesIds!,authProvider.loginUserData.id!)?
                      Container(
                        width: w*0.45,
                        height: 35,
                        child: ElevatedButton(
                          onPressed:
                              ()  { },
                          child: TextCustomerUserTitle(
                            titre: "déjà abonné",
                            fontSize: SizeText.homeProfileTextSize,
                            couleur: Colors.green,
                            fontWeight: FontWeight.w600,
                          ),),
                      ):
                      Container(
                        width: w*0.45,
                        height: 35,


                        child: ElevatedButton(
                          onPressed:abonneTap?
                              ()  { }:
                              ()async{
                                setState(() {
                                  abonneTap=true;
                                });
                                await authProvider.abonner(widget.user!,context).then((value) {

                                },);

                                setState(() {
                                  abonneTap=false;
                                });

                          },
                          child:abonneTap? Center(
                            child: LoadingAnimationWidget.flickr(
                              size: 20,
                              leftDotColor: Colors.green,
                              rightDotColor: Colors.black,
                            ),
                          ): TextCustomerUserTitle(
                            titre: "abonnez vous",
                            fontSize: SizeText.homeProfileTextSize,
                            couleur: Colors.red,
                            fontWeight: FontWeight.w600,
                          ),),
                      ),
                    );
                  }
              ),
            )

            // Row(
            //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
            //   children: [
            //
            //     RatingStars(
            //       rating: 5*widget.user.popularite!,
            //       editable: true,
            //       iconSize: 35,
            //       color: Colors.green,
            //     ),
            //     LikeButton(
            //
            //       isLiked: false,
            //       size: 50,
            //       circleColor:
            //       CircleColor(start: Color(0xff00ddff), end: Color(0xff0099cc)),
            //       bubblesColor: BubblesColor(
            //         dotPrimaryColor: Color(0xff3b9ade),
            //         dotSecondaryColor: Color(0xff027f19),
            //       ),
            //       countPostion: CountPostion.bottom,
            //       likeBuilder: (bool isLiked) {
            //         return Icon(
            //           !isLiked ?AntDesign.like1:AntDesign.like1,
            //           color: !isLiked ? Colors.black38 : Colors.blue,
            //           size: 35,
            //         );
            //       },
            //      // likeCount: 30,
            //       countBuilder: (int? count, bool isLiked, String text) {
            //         var color = isLiked ? Colors.black : Colors.black;
            //         Widget result;
            //         if (count == 0) {
            //           result = Text(
            //             "0",textAlign: TextAlign.center,
            //             style: TextStyle(color: color),
            //           );
            //         } else
            //           result = Text(
            //             text,
            //             style: TextStyle(color: color),
            //           );
            //         return result;
            //       },
            //
            //     ),
            //
            //
            //
            //   ],
            // )

          ],
        ),
      ),
    );
  }
}
