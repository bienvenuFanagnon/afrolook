
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
import '../../providers/profilLikeProvider.dart';
import '../../providers/userProvider.dart';
import '../../services/utils/abonnement_utils.dart';
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
  bool isUserAbonne2(List<String> userAbonnesList, String userIdToCheck) {
    return userAbonnesList.any((userAbonneId) => userAbonneId == userIdToCheck);
  }

  bool isUserAbonne(List<String> abonnesIds, String userId) {
    return abonnesIds.contains(userId);
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
                Icon(Icons.remove_red_eye),
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
                            titre: "Déjà abonné",
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


          ],
        ),
      ),
    );
  }
}



class UserProfileModal extends StatefulWidget {
  final UserData user;
  final double w;
  final double h;

  const UserProfileModal({
    Key? key,
    required this.user,
    required this.w,
    required this.h,
  }) : super(key: key);

  @override
  State<UserProfileModal> createState() => _UserProfileModalState();
}

class _UserProfileModalState extends State<UserProfileModal> {
  late UserAuthProvider authProvider;
  late UserProvider userProvider;
  bool inviteTap = false;
  bool abonneTap = false;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    userProvider = Provider.of<UserProvider>(context, listen: false);
  }

  String formatNumber(int number) {
    if (number >= 1000) {
      double nombre = number / 1000;
      return nombre.toStringAsFixed(1) + 'k';
    } else {
      return number.toString();
    }
  }

  bool isMyFriend(UserData otherUser, UserData currentUser) {
    return currentUser.friendsIds?.contains(otherUser.id!) == true;
  }

  bool isInvite(UserData otherUser, UserData currentUser) {
    return currentUser.mesInvitationsEnvoyerId?.contains(otherUser.id!) == true;
  }

  bool isUserAbonne(List<String> abonnesIds, String userId) {
    return abonnesIds.contains(userId);
  }

  String _getCountryName(String countryCode) {
    final countryNames = {

      // 🌍 AFRIQUE
      'DZ': 'Algérie',
      'AO': 'Angola',
      'BJ': 'Bénin',
      'BW': 'Botswana',
      'BF': 'Burkina Faso',
      'BI': 'Burundi',
      'CM': 'Cameroun',
      'CV': 'Cap-Vert',
      'CF': 'République centrafricaine',
      'TD': 'Tchad',
      'KM': 'Comores',
      'CD': 'RD Congo',
      'CG': 'République du Congo',
      'CI': 'Côte d\'Ivoire',
      'DJ': 'Djibouti',
      'EG': 'Égypte',
      'GQ': 'Guinée équatoriale',
      'ER': 'Érythrée',
      'SZ': 'Eswatini',
      'ET': 'Éthiopie',
      'GA': 'Gabon',
      'GM': 'Gambie',
      'GH': 'Ghana',
      'GN': 'Guinée',
      'GW': 'Guinée-Bissau',
      'KE': 'Kenya',
      'LS': 'Lesotho',
      'LR': 'Libéria',
      'LY': 'Libye',
      'MG': 'Madagascar',
      'MW': 'Malawi',
      'ML': 'Mali',
      'MR': 'Mauritanie',
      'MU': 'Maurice',
      'YT': 'Mayotte',
      'MA': 'Maroc',
      'MZ': 'Mozambique',
      'NA': 'Namibie',
      'NE': 'Niger',
      'NG': 'Nigeria',
      'RE': 'La Réunion',
      'RW': 'Rwanda',
      'SH': 'Sainte-Hélène',
      'ST': 'Sao Tomé-et-Principe',
      'SN': 'Sénégal',
      'SC': 'Seychelles',
      'SL': 'Sierra Leone',
      'SO': 'Somalie',
      'ZA': 'Afrique du Sud',
      'SS': 'Soudan du Sud',
      'SD': 'Soudan',
      'TZ': 'Tanzanie',
      'TG': 'Togo',
      'TN': 'Tunisie',
      'UG': 'Ouganda',
      'EH': 'Sahara occidental',
      'ZM': 'Zambie',
      'ZW': 'Zimbabwe',

      // 🌎 AMÉRIQUES
      'AR': 'Argentine',
      'BS': 'Bahamas',
      'BB': 'Barbade',
      'BZ': 'Belize',
      'BO': 'Bolivie',
      'BR': 'Brésil',
      'CA': 'Canada',
      'CL': 'Chili',
      'CO': 'Colombie',
      'CR': 'Costa Rica',
      'CU': 'Cuba',
      'DO': 'République dominicaine',
      'EC': 'Équateur',
      'SV': 'Salvador',
      'US': 'États-Unis',
      'GD': 'Grenade',
      'GT': 'Guatemala',
      'GY': 'Guyana',
      'HT': 'Haïti',
      'HN': 'Honduras',
      'JM': 'Jamaïque',
      'MX': 'Mexique',
      'NI': 'Nicaragua',
      'PA': 'Panama',
      'PY': 'Paraguay',
      'PE': 'Pérou',
      'PR': 'Porto Rico',
      'TT': 'Trinité-et-Tobago',
      'UY': 'Uruguay',
      'VE': 'Venezuela',

      // 🌍 EUROPE
      'AL': 'Albanie',
      'AD': 'Andorre',
      'AM': 'Arménie',
      'AT': 'Autriche',
      'AZ': 'Azerbaïdjan',
      'BY': 'Biélorussie',
      'BE': 'Belgique',
      'BA': 'Bosnie-Herzégovine',
      'BG': 'Bulgarie',
      'HR': 'Croatie',
      'CY': 'Chypre',
      'CZ': 'Tchéquie',
      'DK': 'Danemark',
      'EE': 'Estonie',
      'FI': 'Finlande',
      'FR': 'France',
      'GE': 'Géorgie',
      'DE': 'Allemagne',
      'GR': 'Grèce',
      'HU': 'Hongrie',
      'IS': 'Islande',
      'IE': 'Irlande',
      'IT': 'Italie',
      'LV': 'Lettonie',
      'LI': 'Liechtenstein',
      'LT': 'Lituanie',
      'LU': 'Luxembourg',
      'MT': 'Malte',
      'MD': 'Moldavie',
      'MC': 'Monaco',
      'ME': 'Monténégro',
      'NL': 'Pays-Bas',
      'MK': 'Macédoine du Nord',
      'NO': 'Norvège',
      'PL': 'Pologne',
      'PT': 'Portugal',
      'RO': 'Roumanie',
      'RU': 'Russie',
      'SM': 'Saint-Marin',
      'RS': 'Serbie',
      'SK': 'Slovaquie',
      'SI': 'Slovénie',
      'ES': 'Espagne',
      'SE': 'Suède',
      'CH': 'Suisse',
      'UA': 'Ukraine',
      'GB': 'Royaume-Uni',
      'VA': 'Vatican',

      // 🌏 ASIE
      'AF': 'Afghanistan',
      'SA': 'Arabie saoudite',
      'AM': 'Arménie',
      'AZ': 'Azerbaïdjan',
      'BH': 'Bahreïn',
      'BD': 'Bangladesh',
      'BT': 'Bhoutan',
      'BN': 'Brunei',
      'KH': 'Cambodge',
      'CN': 'Chine',
      'KR': 'Corée du Sud',
      'KP': 'Corée du Nord',
      'AE': 'Émirats arabes unis',
      'IN': 'Inde',
      'ID': 'Indonésie',
      'IR': 'Iran',
      'IQ': 'Irak',
      'IL': 'Israël',
      'JP': 'Japon',
      'JO': 'Jordanie',
      'KZ': 'Kazakhstan',
      'KW': 'Koweït',
      'KG': 'Kirghizistan',
      'LA': 'Laos',
      'LB': 'Liban',
      'MY': 'Malaisie',
      'MV': 'Maldives',
      'MN': 'Mongolie',
      'MM': 'Myanmar',
      'NP': 'Népal',
      'OM': 'Oman',
      'PK': 'Pakistan',
      'PH': 'Philippines',
      'QA': 'Qatar',
      'SG': 'Singapour',
      'LK': 'Sri Lanka',
      'SY': 'Syrie',
      'TW': 'Taïwan',
      'TJ': 'Tadjikistan',
      'TH': 'Thaïlande',
      'TR': 'Turquie',
      'TM': 'Turkménistan',
      'AE': 'Émirats Arabes Unis',
      'UZ': 'Ouzbékistan',
      'VN': 'Vietnam',
      'YE': 'Yémen',

      // 🌏 OCÉANIE
      'AU': 'Australie',
      'FJ': 'Fidji',
      'KI': 'Kiribati',
      'MH': 'Îles Marshall',
      'FM': 'Micronésie',
      'NR': 'Nauru',
      'NZ': 'Nouvelle-Zélande',
      'PW': 'Palaos',
      'PG': 'Papouasie-Nouvelle-Guinée',
      'WS': 'Samoa',
      'SB': 'Îles Salomon',
      'TO': 'Tonga',
      'TV': 'Tuvalu',
      'VU': 'Vanuatu',
    };

    return countryNames[countryCode] ?? countryCode;
  }

  Future<Chat> getChatsData(UserData amigo) async {
    try {
      var friendsQuery = FirebaseFirestore.instance
          .collection('Chats')
          .where('docId', whereIn: [
        '${amigo.id}${authProvider.loginUserData.id!}',
        '${authProvider.loginUserData.id!}${amigo.id}'
      ]);

      var querySnapshot = await friendsQuery.get();

      if (querySnapshot.docs.isEmpty) {
        String chatId = FirebaseFirestore.instance.collection('Chats').doc().id;
        Chat chat = Chat(
          docId: '${amigo.id}${authProvider.loginUserData.id!}',
          id: chatId,
          senderId: authProvider.loginUserData.id!,
          receiverId: amigo.id!,
          lastMessage: 'Salut! 👋',
          type: ChatType.USER.name,
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        );
        await FirebaseFirestore.instance.collection('Chats').doc(chatId).set(chat.toJson());
        return chat;
      } else {
        return Chat.fromJson(querySnapshot.docs.first.data());
      }
    } catch (e) {
      print('Erreur getChatsData: $e');
      rethrow;
    }
  }

  Future<void> _sendInvitation(UserData user) async {
    setState(() => inviteTap = true);

    try {
      Invitation invitation = Invitation();
      invitation.senderId = authProvider.loginUserData.id;
      invitation.receiverId = user.id;
      invitation.status = InvitationStatus.ENCOURS.name;
      invitation.createdAt = DateTime.now().millisecondsSinceEpoch;
      invitation.updatedAt = DateTime.now().millisecondsSinceEpoch;

      bool success = await userProvider.sendInvitation(invitation, context);

      if (success) {
        authProvider.loginUserData.mesInvitationsEnvoyer!.add(invitation);
        authProvider.loginUserData.mesInvitationsEnvoyerId!.add(user.id!);

        if (user.oneIgnalUserid != null && user.oneIgnalUserid!.isNotEmpty) {
          await authProvider.sendNotification(
            appName: '@${authProvider.loginUserData.pseudo!}',
            userIds: [user.oneIgnalUserid!],
            smallImage: authProvider.loginUserData.imageUrl!,
            send_user_id: authProvider.loginUserData.id!,
            recever_user_id: user.id!,
            message: "📢 @${authProvider.loginUserData.pseudo!} vous a envoyé une invitation !",
            type_notif: 'INVITATION',
            post_id: "",
            post_type: "",
            chat_id: '',
          );
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green,
            content: Text(
              'Invitation envoyée avec succès!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white),
            ),
          ),
        );

        setState(() {});
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            'Erreur lors de l\'envoi de l\'invitation',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    } finally {
      setState(() => inviteTap = false);
    }
  }

  Future<void> _toggleAbonnement(UserData user) async {
    setState(() => abonneTap = true);

    try {
      await authProvider.abonner(user, context);
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            'Erreur lors de l\'abonnement',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    } finally {
      setState(() => abonneTap = false);
    }
  }

  Widget _buildActionButton({
    required String text,
    required Color color,
    required VoidCallback onPressed,
    bool isLoading = false,
    bool isDisabled = false,
    IconData? icon,
    double width = 160,
  }) {
    return Container(
      width: width,
      height: 45,
      decoration: BoxDecoration(
        color: isDisabled ? Colors.grey[800] : color.withOpacity(0.9),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          if (!isDisabled)
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
        ],
      ),
      child: TextButton(
        onPressed: isDisabled ? null : onPressed,
        child: isLoading
            ? LoadingAnimationWidget.flickr(
          size: 20,
          leftDotColor: Colors.white,
          rightDotColor: color,
        )
            : Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.white, size: 18),
              SizedBox(width: 6),
            ],
            Text(
              text,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCountryInfo() {
    String countryCode = 'TG';

   if (widget.user.countryData?['countryCode'] != null) {
      countryCode = widget.user.countryData!['countryCode']!;
    }

    countryCode = countryCode.toUpperCase();
    final countryName = _getCountryName(countryCode);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Color(0xFFFFD700)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CountryFlag.fromCountryCode(
            countryCode,
            height: 16,
            width: 24,
          ),
          SizedBox(width: 6),
          Text(
            countryName,
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double taux = widget.user.popularite!;
    bool isFriend = isMyFriend(widget.user, authProvider.loginUserData);
    bool isInvited = isInvite(widget.user, authProvider.loginUserData);
    bool isAbonne = isUserAbonne(widget.user.userAbonnesIds!, authProvider.loginUserData.id!);
    bool isOwnProfile = authProvider.loginUserData.id == widget.user.id;

    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
      ),
      child: Stack(
        children: [
          // Image de fond en plein écran
          Container(
            width: double.infinity,
            height: double.infinity,
            child: CachedNetworkImage(
              imageUrl: widget.user.imageUrl ?? '',
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: Colors.grey[900],
                child: Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFFFFD700),
                  ),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                color: Colors.grey[900],
                child: Center(
                  child: Icon(
                    Icons.person,
                    color: Colors.grey[600],
                    size: 80,
                  ),
                ),
              ),
            ),
          ),

          // Overlay gradient pour meilleure lisibilité
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.7),
                  Colors.black.withOpacity(0.9),
                ],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),

          // Contenu superposé
          Column(
            children: [
              // Header avec bouton fermer
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildCountryInfo(),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: Icon(Icons.close, color: Colors.white, size: 24),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              Spacer(),

              // Informations utilisateur
              Container(
                padding: EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Nom et badge vérifié
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          constraints: BoxConstraints(maxWidth: widget.w * 0.7),
                          child: Text(
                            '@${widget.user.pseudo ?? "Utilisateur"}',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                  blurRadius: 10,
                                  color: Colors.black,
                                ),
                              ],
                            ),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: 8),
                          AbonnementUtils.getUserBadge(abonnement: widget.user!.abonnement,isVerified: widget.user!.isVerify!)
                      ],
                    ),

                    SizedBox(height: 10),

                    // Statistiques
                    Container(
                      padding: EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.2)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatItem(
                            formatNumber(widget.user.userAbonnesIds!.length),
                            'Abonnés',
                            Color(0xFFFFD700),
                          ),
                          _buildStatItem(
                            '${taux.toStringAsFixed(1)}%',
                            'Popularité',
                            Color(0xFF8B0000),
                          ),
                          _buildStatItem(
                            widget.user.usersParrainer!.length.toString(),
                            'Parrainages',
                            Colors.lightBlue,
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 5),
                    _buildProfileLikesSection(),
                    SizedBox(height: 10),

                    // Actions
                    if (!isOwnProfile) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Bouton Message/Invitation
                          _buildActionButton(
                            text: isFriend
                                ? 'Message'
                                : (isInvited ? 'Invitation envoyée' : 'Inviter'),
                            color: isFriend ? Colors.green : (isInvited ? Colors.grey : Colors.blue),
                            isDisabled: isInvited,
                            isLoading: inviteTap,
                            icon: isFriend ? Icons.message : Icons.person_add,
                            width: isFriend ? 140 : 160,
                            onPressed: isFriend
                                ? () async {
                              try {
                                Chat chat = await getChatsData(widget.user);
                                Navigator.of(context).pop();
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => MyChat(
                                      title: 'Chat avec ${widget.user.pseudo}',
                                      chat: chat,
                                    ),
                                  ),
                                );
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: Colors.red,
                                    content: Text('Erreur: $e', style: TextStyle(color: Colors.white)),
                                  ),
                                );
                              }
                            }
                                : () => _sendInvitation(widget.user),
                          ),

                          // Bouton Abonnement
                          _buildActionButton(
                            text: isAbonne ? 'Abonné' : "S'abonner",
                            color: isAbonne ? Colors.green : Colors.red,
                            isDisabled: isAbonne,
                            isLoading: abonneTap,
                            icon: isAbonne ? Icons.check : Icons.add,
                            width: 140,
                            onPressed: () => _toggleAbonnement(widget.user),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                    ],

                    // Bouton Voir le profil complet
                    Container(
                      width: double.infinity,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFFFFD700), Color(0xFF8B0000)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0xFFFFD700).withOpacity(0.4),
                            blurRadius: 15,
                            offset: Offset(0, 5),
                          ),
                        ],
                      ),
                      child: TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => OtherUserPage(otherUser: widget.user),
                            ),
                          );
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.remove_red_eye, color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Voir le profil complet',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(height: 10),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String value, String label, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(
                blurRadius: 10,
                color: Colors.black,
              ),
            ],
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 12,
            shadows: [
              Shadow(
                blurRadius: 5,
                color: Colors.black,
              ),
            ],
          ),
        ),
      ],
    );
  }
  String _formatCount(int count) {
    if (count < 1000) return count.toString();
    if (count < 1000000) return '${(count / 1000).toStringAsFixed(1)}K';
    return '${(count / 1000000).toStringAsFixed(1)}M';
  }
  // Dans le UserProfileModal, ajoutez cette section après les statistiques existantes
  Widget _buildProfileLikesSection() {
    final profileLikeProvider = Provider.of<ProfileLikeProvider>(context);

    return StreamBuilder<int>(
      stream: profileLikeProvider.getProfileLikesStream(widget.user.id!),
      builder: (context, snapshot) {
        final likesCount = snapshot.data ?? widget.user.userlikes ?? 0;
        final authProvider = Provider.of<UserAuthProvider>(context);
        final isOwnProfile = authProvider.loginUserData.id == widget.user.id;

        return Container(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.favorite, color: Colors.red, size: 20),
              SizedBox(width: 8),
              Text(
                _formatCount(likesCount),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(width: 4),
              Text(
                'Likes profil',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 14,
                ),
              ),
              if (!isOwnProfile) ...[
                SizedBox(width: 20),
                _buildProfileLikeButton(),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildProfileLikeButton() {
    final authProvider = Provider.of<UserAuthProvider>(context);
    final profileLikeProvider = Provider.of<ProfileLikeProvider>(context);

    return FutureBuilder<bool>(
      future: profileLikeProvider.hasLikedProfile(widget.user.id!, authProvider.loginUserData.id!),
      builder: (context, snapshot) {
        final hasLiked = snapshot.data ?? false;

        return GestureDetector(
          onTap: () async {
            try {
              if (hasLiked) {
                await profileLikeProvider.unlikeProfile(widget.user.id!, authProvider.loginUserData.id!);
              } else {
                await profileLikeProvider.likeProfile(widget.user.id!, authProvider.loginUserData.id!);

                // Envoyer notification
                if (widget.user.oneIgnalUserid != null && widget.user.oneIgnalUserid!.isNotEmpty) {
                  await authProvider.sendNotification(
                    appName: '@${authProvider.loginUserData.pseudo!}',
                    userIds: [widget.user.oneIgnalUserid!],
                    smallImage: authProvider.loginUserData.imageUrl!,
                    send_user_id: authProvider.loginUserData.id!,
                    recever_user_id: widget.user.id!,
                    message: "❤️ a aimé votre profil !",
                    type_notif: 'PROFILE_LIKE',
                    post_id: "",
                    post_type: "",
                    chat_id: '',
                  );
                }
              }
            } catch (e) {
              print('Erreur like profil: $e');
            }
          },
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: hasLiked ? Colors.red : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: hasLiked ? Colors.red : Colors.grey[600]!,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  hasLiked ? Icons.favorite : Icons.favorite_border,
                  color: hasLiked ? Colors.white : Colors.grey[400],
                  size: 16,
                ),
                SizedBox(width: 6),
                Text(
                  hasLiked ? 'Liked' : 'Like',
                  style: TextStyle(
                    color: hasLiked ? Colors.white : Colors.grey[400],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Fonction pour afficher le modal

// Fonction pour afficher le modal

// Fonction pour afficher le modal
