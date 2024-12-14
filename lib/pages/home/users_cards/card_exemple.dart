import 'package:afrotok/models/model_data.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:like_button/like_button.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:page_transition/page_transition.dart';
import 'package:provider/provider.dart';
import 'package:rate_in_stars/rate_in_stars.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../constant/sizeText.dart';
import '../../../constant/textCustom.dart';
import '../../../models/chatmodels/message.dart';
import '../../../providers/authProvider.dart';
import '../../../providers/postProvider.dart';
import '../../../providers/userProvider.dart';
import '../../chat/myChat.dart';
import '../../component/consoleWidget.dart';
import 'cardModel.dart';

class ExampleCard extends StatefulWidget {
  final UserData cardUser;

  const ExampleCard(
      this.cardUser, {
        super.key,
      });

  @override
  State<ExampleCard> createState() => _ExampleCardState();
}

class _ExampleCardState extends State<ExampleCard> {

  bool abonneTap =false;
  bool inviteTap =false;
  bool dejaInviter =false;

  late UserAuthProvider authProvider =
  Provider.of<UserAuthProvider>(context, listen: false);
  late UserProvider userProvider =
  Provider.of<UserProvider>(context, listen: false);
  final List<String> noms = ['Alice', 'Bob', 'Charlie'];
  late PostProvider postProvider =
  Provider.of<PostProvider>(context, listen: false);

  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  String formatNumber(int number) {
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
  bool isMyFriend(List<String> userfriendList, String userIdToCheck) {
    return userfriendList.any((userfriendId) => userfriendId == userIdToCheck);
  }
  bool isInvite(List<String> invitationList, String userIdToCheck) {
    return invitationList.any((invid) => invid == userIdToCheck);
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
      printVm("pas de chat ");
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
      printVm("le chat existe  ");
      printVm("stream :${friendsStream}");
      usersChat= await friendsStream.first.then((value) async {
        printVm("stream value l :${value.docs.length}");
        if (value.docs.length<=0) {
          printVm("pas de chat ");

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
        printVm("messgae vide ");
      }else{
        printVm("have messages");
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
  Widget build(BuildContext context) {
    double h = MediaQuery.of(context).size.height;
    double w = MediaQuery.of(context).size.width;
    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.all(Radius.circular(10)),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 3,
            blurRadius: 7,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: const [Color(0xFF0BA4E0), Color(0xFFA9E4BD)],
                ),
              ),
              child: Container(
                width: w*0.9,
                height: h*0.7,
                child: CachedNetworkImage(
                  fit: BoxFit.cover,

                  imageUrl: '${widget.cardUser.imageUrl!}',
                  progressIndicatorBuilder: (context, url, downloadProgress) =>
                  //  LinearProgressIndicator(),

                  Skeletonizer(
                      child: SizedBox(width: 120,height: 100, child:  ClipRRect(
                          borderRadius: BorderRadius.all(Radius.circular(10)),child: Image.asset('assets/images/404.png')))),
                  errorWidget: (context, url, error) =>  Container(width: 120,height: 100,child: Image.asset("assets/icon/user-removebg-preview.png",fit: BoxFit.cover,)),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "@${widget.cardUser.pseudo}",
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  "${widget.cardUser.abonnes} abonné(s)",
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Visibility(
                      visible: authProvider.loginUserData.id!=widget.cardUser.id,

                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          StatefulBuilder(

                              builder: (BuildContext context, void Function(void Function()) setState) {

                                return Container(
                                  // width: w*0.45,
                                  height: 50,
                                  child:  isMyFriend(widget.cardUser.friendsIds!,authProvider.loginUserData.id!)?
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8.0,bottom:8 ),
                                    child: ElevatedButton(

                                        onPressed: () async {
                                          getChatsData(widget.cardUser).then((chat) async {
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
                                      fontSize: 10,
                                      couleur: Colors.black,
                                      fontWeight: FontWeight.w600,
                                    ),)),
                                  )
                                      :!isInvite(widget.cardUser.autreInvitationsEnvoyerId!,authProvider.loginUserData.id!)?
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8.0,bottom:8 ),
                                    child: Container(
                                      //width: 120,
                                      //height: 30,
                                      child: ElevatedButton(
                                        onPressed:inviteTap?
                                            ()  { }:
                                            ()async{
                                          if (!isInvite(widget.cardUser.autreInvitationsEnvoyerId!,authProvider.loginUserData.id!)) {
                                            setState(() {
                                              inviteTap=true;
                                            });
                                            Invitation invitation = Invitation();
                                            invitation.senderId=authProvider.loginUserData.id;
                                            invitation.receiverId=widget.cardUser.id;
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
                                                notif.receiver_id=widget.cardUser.id;
                                                notif.updatedAt =
                                                    DateTime.now().microsecondsSinceEpoch;
                                                notif.createdAt =
                                                    DateTime.now().microsecondsSinceEpoch;
                                                notif.status = PostStatus.VALIDE.name;

                                                // users.add(pseudo.toJson());

                                                await firestore.collection('Notifications').doc(notif.id).set(notif.toJson());
                                                printVm("///////////-- save notification --///////////////");
                                                SnackBar snackBar = SnackBar(
                                                  content: Text('invitation envoyée',textAlign: TextAlign.center,style: TextStyle(color: Colors.green),),
                                                );
                                                ScaffoldMessenger.of(context).showSnackBar(snackBar);

                                                widget.cardUser.autreInvitationsEnvoyerId!.add(authProvider.loginUserData.id!);
                                                authProvider.loginUserData!.mesInvitationsEnvoyerId!.add(widget.cardUser.id!);
                                                userProvider.updateUser(widget.cardUser);
                                                userProvider.updateUser(authProvider.loginUserData!);

                                                if (widget.cardUser.oneIgnalUserid!=null&&widget.cardUser.oneIgnalUserid!.length>5) {

                                                  await authProvider.sendNotification(
                                                      userIds: [widget.cardUser.oneIgnalUserid!],
                                                      smallImage: "${authProvider.loginUserData.imageUrl!}",
                                                      send_user_id: "${authProvider.loginUserData.id!}",
                                                      recever_user_id: "${widget.cardUser.id!}",
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
                                          fontSize: 10,
                                          couleur: Colors.blue,
                                          fontWeight: FontWeight.w600,
                                        ),),
                                    ),
                                  ):
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8.0,bottom:8 ),
                                    child: Container(
                                      //width: 120,
                                      // height: 30,
                                      child: ElevatedButton(
                                        onPressed:
                                            ()  { },
                                        child:TextCustomerUserTitle(
                                          titre: "invitation déjà envoyée",
                                          fontSize: 10,
                                          couleur: Colors.black38,
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
                                  child:     isUserAbonne(widget.cardUser.userAbonnesIds!,authProvider.loginUserData.id!)?
                                  Container(
                                    // // width: w*0.5,

                                    height: 35,
                                    child: ElevatedButton(
                                      onPressed:
                                          ()  { },
                                      child: TextCustomerUserTitle(
                                        titre: "vous êtes déjà abonné",
                                        fontSize: 10,
                                        couleur: Colors.green,
                                        fontWeight: FontWeight.w600,
                                      ),),
                                  ):
                                  Container(
                                    // width: w*0.3,

                                    height: 35,

                                    child: ElevatedButton(
                                      onPressed:abonneTap?
                                          ()  { }:
                                          ()async{
                                        if (!isUserAbonne(widget.cardUser.userAbonnesIds!,authProvider.loginUserData.id!)) {
                                          setState(() {
                                            abonneTap=true;
                                          });
                                          UserAbonnes userAbonne = UserAbonnes();
                                          userAbonne.compteUserId=authProvider.loginUserData.id;
                                          userAbonne.abonneUserId=widget.cardUser!.id;

                                          userAbonne.createdAt  = DateTime.now().millisecondsSinceEpoch;
                                          userAbonne.updatedAt  = DateTime.now().millisecondsSinceEpoch;
                                          await  userProvider.sendAbonnementRequest(userAbonne,widget.cardUser,context).then((value) async {
                                            if (value) {


                                              // await userProvider.getUsers(authProvider.loginUserData!.id!);
                                              authProvider.loginUserData.userAbonnes!.add(userAbonne);
                                              await authProvider.getCurrentUser(authProvider.loginUserData!.id!);
                                              if (widget.cardUser.oneIgnalUserid!=null&&widget.cardUser.oneIgnalUserid!.length>5) {
                                                await authProvider.sendNotification(
                                                    userIds: [widget.cardUser.oneIgnalUserid!],
                                                    smallImage: "${authProvider.loginUserData.imageUrl!}",
                                                    send_user_id: "${authProvider.loginUserData.id!}",
                                                    recever_user_id: "${widget.cardUser.id!}",
                                                    message: "📢 @${authProvider.loginUserData.pseudo!} s'est abonné(e) à votre compte !",
                                                    type_notif: NotificationType.ABONNER.name,
                                                    post_id: "",
                                                    post_type: "", chat_id: ''
                                                );

                                                NotificationData notif=NotificationData();
                                                notif.id=firestore
                                                    .collection('Notifications')
                                                    .doc()
                                                    .id;
                                                notif.titre="Nouveau Abonnement ✅";
                                                notif.media_url=authProvider.loginUserData.imageUrl;
                                                notif.type=NotificationType.ABONNER.name;
                                                notif.description="@${authProvider.loginUserData.pseudo!} s'est abonné(e) à votre compte";
                                                notif.users_id_view=[];
                                                notif.user_id=authProvider.loginUserData.id;
                                                notif.receiver_id="";
                                                notif.post_id="";
                                                notif.post_data_type=PostDataType.IMAGE.name!;
                                                notif.updatedAt =
                                                    DateTime.now().microsecondsSinceEpoch;
                                                notif.createdAt =
                                                    DateTime.now().microsecondsSinceEpoch;
                                                notif.status = PostStatus.VALIDE.name;

                                                // users.add(pseudo.toJson());

                                                await firestore.collection('Notifications').doc(notif.id).set(notif.toJson());


                                              }
                                              SnackBar snackBar = SnackBar(
                                                content: Text('abonné, Bravo ! Vous avez gagné 4 points.',textAlign: TextAlign.center,style: TextStyle(color: Colors.green),),
                                              );
                                              widget.cardUser.userAbonnesIds!.add(authProvider.loginUserData.id!);
                                              userProvider.updateUser(widget.cardUser);
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
                                        titre: "abonnez vous",
                                        fontSize: 10,
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

                    Padding(
                      padding: const EdgeInsets.only(left: 0.0),
                      child: Column(
                        // mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [

                          RatingStars(
                            rating: 5*widget.cardUser.popularite!,
                            editable: true,
                            iconSize: 20,
                            color: Colors.green,
                          ),
                          SizedBox(height: 10,),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              LikeButton(
                                onTap: (isLiked) async {


                                    CollectionReference userCollect =
                                    FirebaseFirestore.instance.collection('Users');
                                    // Get docs from collection reference
                                    QuerySnapshot querySnapshotUser = await userCollect.where("id",isEqualTo: widget.cardUser!.id!).get();
                                    // Afficher la liste
                                    List<UserData>  listUsers = querySnapshotUser.docs.map((doc) =>
                                        UserData.fromJson(doc.data() as Map<String, dynamic>)).toList();
                                    if (listUsers.isNotEmpty) {
                                      listUsers.first!.userlikes=listUsers.first!.userlikes!+1;
                                      widget.cardUser!.userlikes=listUsers.first!.userlikes;

                                      printVm("user trouver ${listUsers.first!.toJson()}");
                                      await authProvider.updateUser( listUsers.first);


                                      if (widget.cardUser!.oneIgnalUserid!=null&&widget.cardUser!.oneIgnalUserid!.length>5) {

                                        await authProvider.sendNotification(
                                            userIds: [widget.cardUser!.oneIgnalUserid!],
                                            smallImage: "${authProvider.loginUserData.imageUrl!}",
                                            send_user_id: "${authProvider.loginUserData.id!}",
                                            recever_user_id: "${widget.cardUser!.id!}",
                                            message: "📢 @${authProvider.loginUserData.pseudo!} a liké votre profile",
                                            type_notif: NotificationType.USER.name,
                                            post_id: "",
                                            post_type: "",
                                            chat_id: ''
                                        );

                                        NotificationData notif=NotificationData();
                                        notif.id=firestore
                                            .collection('Notifications')
                                            .doc()
                                            .id;
                                        notif.titre="@${widget.cardUser!.pseudo} -> 👍🏾";
                                        notif.media_url=authProvider.loginUserData.imageUrl;
                                        notif.type=NotificationType.USER.name;
                                        notif.description="@${authProvider.loginUserData.pseudo!} a liké votre publication";
                                        notif.users_id_view=[];
                                        notif.user_id=authProvider.loginUserData.id;
                                        notif.receiver_id=widget.cardUser!.id!;
                                        // notif.post_id=post.id!;
                                        // notif.post_data_type=PostDataType.IMAGE.name!;

                                        notif.updatedAt =
                                            DateTime.now().microsecondsSinceEpoch;
                                        notif.createdAt =
                                            DateTime.now().microsecondsSinceEpoch;
                                        notif.status = PostStatus.VALIDE.name;

                                        // users.add(pseudo.toJson());

                                        await firestore.collection('Notifications').doc(notif.id).set(notif.toJson());
                                        //userProvider.updateUser(listUsers.first);
                                        // SnackBar snackBar = SnackBar(
                                        //   content: Text('+1 points.  Voir le classement',textAlign: TextAlign.center,style: TextStyle(color: Colors.green),),
                                        // );
                                        // ScaffoldMessenger.of(context).showSnackBar(snackBar);
                                        // postProvider.updatePost(post, listUsers.first,context);
                                        // await authProvider.getAppData();
                                        // authProvider.appDefaultData.nbr_loves=authProvider.appDefaultData.nbr_loves!+1;
                                        // authProvider.updateAppData(authProvider.appDefaultData);

// setState(() {
//
// });
                                      }






                                  }
                                  return true;
                                },
                                isLiked: false,
                                size: 20,
                                circleColor:
                                CircleColor(start: Color(0xff00ddff), end: Color(0xff0099cc)),
                                bubblesColor: BubblesColor(
                                  dotPrimaryColor: Color(0xff3b9ade),
                                  dotSecondaryColor: Color(0xff027f19),
                                ),
                                countPostion: CountPostion.bottom,
                                likeBuilder: (bool isLiked) {
                                  return Icon(
                                    !isLiked ?AntDesign.like1:AntDesign.like1,
                                    color: !isLiked ? Colors.black38 : Colors.blue,
                                    size: 20,
                                  );
                                },
                                likeCount: widget.cardUser.userlikes ==null?0:widget.cardUser.userlikes,

                                countBuilder: (int? count, bool isLiked, String text) {
                                  var color = isLiked ? Colors.black : Colors.black;
                                  Widget result;
                                  if (count == 0) {
                                    result = Text(
                                      "0",textAlign: TextAlign.center,
                                      style: TextStyle(color: color,),
                                    );
                                  } else
                                    result = Text(
                                      text,
                                      style: TextStyle(color: color),
                                    );
                                  return result;
                                },

                              ),
                              // SizedBox(width: 20,),
                              // LikeButton(
                              //   onTap: (isLiked) async {
                              //
                              //
                              //     CollectionReference userCollect =
                              //     FirebaseFirestore.instance.collection('Users');
                              //     // Get docs from collection reference
                              //     QuerySnapshot querySnapshotUser = await userCollect.where("id",isEqualTo: widget.cardUser!.id!).get();
                              //     // Afficher la liste
                              //     List<UserData>  listUsers = querySnapshotUser.docs.map((doc) =>
                              //         UserData.fromJson(doc.data() as Map<String, dynamic>)).toList();
                              //     if (listUsers.isNotEmpty) {
                              //       listUsers.first!.userjaimes=listUsers.first!.userjaimes!+1;
                              //       printVm("user trouver");
                              //       await  authProvider.updateUser( listUsers.first);
                              //       widget.cardUser!.userjaimes=listUsers.first!.userjaimes;
                              //
                              //       if (widget.cardUser!.oneIgnalUserid!=null&&widget.cardUser!.oneIgnalUserid!.length>5) {
                              //
                              //         await authProvider.sendNotification(
                              //             userIds: [widget.cardUser!.oneIgnalUserid!],
                              //             smallImage: "${authProvider.loginUserData.imageUrl!}",
                              //             send_user_id: "${authProvider.loginUserData.id!}",
                              //             recever_user_id: "${widget.cardUser!.id!}",
                              //             message: "📢 @${authProvider.loginUserData.pseudo!} a aimé votre profile",
                              //             type_notif: NotificationType.USER.name,
                              //             post_id: "",
                              //             post_type: "",
                              //             chat_id: ''
                              //         );
                              //
                              //         NotificationData notif=NotificationData();
                              //         notif.id=firestore
                              //             .collection('Notifications')
                              //             .doc()
                              //             .id;
                              //         notif.titre="@${widget.cardUser!.pseudo} -> ❤️";
                              //         notif.media_url=authProvider.loginUserData.imageUrl;
                              //         notif.type=NotificationType.USER.name;
                              //         notif.description="@${authProvider.loginUserData.pseudo!} a aimé votre publication";
                              //         notif.users_id_view=[];
                              //         notif.user_id=authProvider.loginUserData.id;
                              //         notif.receiver_id=widget.cardUser!.id!;
                              //         // notif.post_id=post.id!;
                              //         // notif.post_data_type=PostDataType.IMAGE.name!;
                              //
                              //         notif.updatedAt =
                              //             DateTime.now().microsecondsSinceEpoch;
                              //         notif.createdAt =
                              //             DateTime.now().microsecondsSinceEpoch;
                              //         notif.status = PostStatus.VALIDE.name;
                              //
                              //         // users.add(pseudo.toJson());
                              //
                              //         await firestore.collection('Notifications').doc(notif.id).set(notif.toJson());
                              //         //userProvider.updateUser(listUsers.first);
                              //         // SnackBar snackBar = SnackBar(
                              //         //   content: Text('+1 points.  Voir le classement',textAlign: TextAlign.center,style: TextStyle(color: Colors.green),),
                              //         // );
                              //         // ScaffoldMessenger.of(context).showSnackBar(snackBar);
                              //         // postProvider.updatePost(post, listUsers.first,context);
                              //         await authProvider.getAppData();
                              //         authProvider.appDefaultData.nbr_loves=authProvider.appDefaultData.nbr_loves!+1;
                              //         authProvider.updateAppData(authProvider.appDefaultData);
                              //
                              //
                              //       }
                              //
                              //
                              //
                              //
                              //
                              //
                              //     }
                              //     return true;
                              //   },
                              //
                              //   isLiked: false,
                              //   size: 20,
                              //   circleColor:
                              //   CircleColor(start: Color(0xff00ddff), end: Color(0xff0099cc)),
                              //   bubblesColor: BubblesColor(
                              //     dotPrimaryColor: Color(0xff3b9ade),
                              //     dotSecondaryColor: Color(0xff027f19),
                              //   ),
                              //   countPostion: CountPostion.bottom,
                              //   likeBuilder: (bool isLiked) {
                              //     return Icon(
                              //       !isLiked ?AntDesign.heart:AntDesign.heart,
                              //       color: !isLiked ? Colors.black38 : Colors.red,
                              //       size: 20,
                              //     );
                              //   },
                              //   likeCount: widget.cardUser.userjaimes ==null?0:widget.cardUser.userjaimes,
                              //   countBuilder: (int? count, bool isLiked, String text) {
                              //     var color = isLiked ? Colors.black : Colors.black;
                              //     Widget result;
                              //     if (count == 0) {
                              //       result = Text(
                              //         "0",textAlign: TextAlign.center,
                              //         style: TextStyle(color: color,),
                              //       );
                              //     } else
                              //       result = Text(
                              //         text,
                              //         style: TextStyle(color: color),
                              //       );
                              //     return result;
                              //   },
                              //
                              // ),

                            ],
                          ),



                        ],
                      ),
                    )
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}