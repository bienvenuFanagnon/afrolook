import 'dart:async';
import 'dart:math';

import 'package:afrotok/pages/home/postMenu.dart';
import 'package:afrotok/pages/postComments.dart';
import 'package:afrotok/providers/postProvider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:afrotok/constant/constColors.dart';
import 'package:afrotok/constant/iconGradient.dart';
import 'package:afrotok/constant/logo.dart';
import 'package:afrotok/constant/sizeText.dart';
import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/providers/userProvider.dart';
import 'package:afrotok/services/api.dart';
import 'package:flutter/material.dart';
import 'package:badges/badges.dart' as badges;
import 'package:flutter/services.dart';
import 'package:flutter_image_slideshow/flutter_image_slideshow.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:hashtagable_v3/widgets/hashtag_text.dart';
import 'package:insta_image_viewer/insta_image_viewer.dart';
import 'package:intl/intl.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:page_transition/page_transition.dart';
import 'package:popup_menu/popup_menu.dart';

import 'package:provider/provider.dart';
import 'package:random_color/random_color.dart';
import 'package:share_plus/share_plus.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:stories_for_flutter/stories_for_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../constant/listItemsCarousel.dart';
import '../../constant/textCustom.dart';
import '../../models/chatmodels/message.dart';
import '../../providers/authProvider.dart';
import 'canaux/detailsCanal.dart';
import 'canaux/listCanal.dart';
import 'chat/entrepriseChat.dart';
import 'component/consoleWidget.dart';

class DetailsPost extends StatefulWidget {
  final Post post;
  const DetailsPost({super.key, required this.post});

  @override
  State<DetailsPost> createState() => _DetailsPostState();
}

class _DetailsPostState extends State<DetailsPost> {

  String token='';
  bool dejaVuPub=true;

  GlobalKey btnKey = GlobalKey();
  GlobalKey btnKey2 = GlobalKey();
  GlobalKey btnKey3 = GlobalKey();
  GlobalKey btnKey4 = GlobalKey();
  final _formKey = GlobalKey<FormState>();
  GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late UserAuthProvider authProvider =
  Provider.of<UserAuthProvider>(context, listen: false);
  late UserProvider userProvider =
  Provider.of<UserProvider>(context, listen: false);
  int imageIndex=0;
  late PostProvider postProvider =
  Provider.of<PostProvider>(context, listen: false);

  bool _buttonEnabled=false;
  bool contact_whatsapp=false;
  bool contact_afrolook=false;


  TextEditingController commentController =TextEditingController();
  Future<void> launchWhatsApp(String phone) async {
    //  var whatsappURl_android = "whatsapp://send?phone="+whatsapp+"&text=hello";
    // String url = "https://wa.me/?tel:+228$phone&&text=YourTextHere";
    String url = "whatsapp://send?phone="+phone+"";
    if (!await launchUrl(Uri.parse(url))) {
      final snackBar = SnackBar(duration: Duration(seconds: 2),content: Text("Impossible d\'ouvrir WhatsApp",textAlign: TextAlign.center, style: TextStyle(color: Colors.red),));

      // Afficher le SnackBar en bas de la page
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
      throw Exception('Impossible d\'ouvrir WhatsApp');
    }
  }

  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  late AnimationController _starController;
  late AnimationController _unlikeController;
  String formatNumber(int number) {
    if (number >= 1000) {
      double nombre = number / 1000;
      return nombre.toStringAsFixed(1) + 'k';
    } else {
      return number.toString();
    }
  }

  Future<Chat> getChatsEntrepriseData(UserData amigo,Post post,EntrepriseData entreprise) async {

    // Définissez la requête
    var friendsStream = FirebaseFirestore.instance.collection('Chats').where( Filter.or(
      Filter('docId', isEqualTo:  '${post.id}${authProvider.loginUserData!.id}'),
      Filter('docId', isEqualTo:  '${authProvider.loginUserData!.id}${post.id}'),

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
        docId:'${post.id}${authProvider.loginUserData!.id}',
        id: chatId,
        senderId: '${authProvider.loginUserData!.id}',
        receiverId: '${amigo.id}',
        lastMessage: 'hi',
        post_id: post.id,
        entreprise_id: post.entreprise_id,
        type: ChatType.ENTREPRISE.name,
        createdAt: DateTime.now().millisecondsSinceEpoch, // Get current time in milliseconds
        updatedAt: DateTime.now().millisecondsSinceEpoch,
        // Optional: You can initialize sender and receiver with UserData objects, and messages with a list of Message objects
      );
      await FirebaseFirestore.instance.collection('Chats').doc(chatId).set(chat.toJson());
      usersChat=chat;

    }  else{
      printVm("le chat existe  ");
      // printVm("stream :${friendsStream}");
      usersChat= await friendsStream.first.then((value) async {
        // printVm("stream value l :${value.docs.length}");
        if (value.docs.length<=0) {
          printVm("pas de chat ");
          String chatId = FirebaseFirestore.instance
              .collection('Chats')
              .doc()
              .id;
          Chat chat = Chat(
            docId:'${post.id}${authProvider.loginUserData!.id}',
            id: chatId,
            senderId: '${authProvider.loginUserData!.id}',
            receiverId: '${amigo.id}',
            lastMessage: 'hi',
            entreprise_id: post.entreprise_id,
            post_id: post.id,
            type: ChatType.ENTREPRISE.name,
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
        printVm("messages vide ");
      }else{
        printVm("have messages");
        usersChat.messages=messageList;
        userProvider.chat=usersChat;
      }

      /////////////ami//////////
      CollectionReference friendCollect = await FirebaseFirestore.instance.collection('Users');
      QuerySnapshot querySnapshotUserSender = await friendCollect.where("id",isEqualTo:authProvider.loginUserData.id==amigo.id!?'${amigo.id}':'${authProvider.loginUserData!.id}').get();
      // Afficher la liste
      QuerySnapshot querySnapshotUserReceiver= await friendCollect.where("id",isEqualTo:authProvider.loginUserData.id==amigo.id?'${authProvider.loginUserData!.id}':'${amigo.id}').get();


      List<UserData> receiverUserList = querySnapshotUserReceiver.docs.map((doc) =>
          UserData.fromJson(doc.data() as Map<String, dynamic>)).toList();
      usersChat.receiver=receiverUserList.first;

      List<UserData> senderUserList = querySnapshotUserSender.docs.map((doc) =>
          UserData.fromJson(doc.data() as Map<String, dynamic>)).toList();
      usersChat.sender=senderUserList.first;

      /////////////entreprise//////////
      CollectionReference entrepriseCollect = await FirebaseFirestore.instance.collection('Entreprises');
      QuerySnapshot querySnapshotentreprise = await entrepriseCollect.where("id",isEqualTo:'${post.entreprise_id}').get();
      List<EntrepriseData> entrepriseList = querySnapshotentreprise.docs.map((doc) =>
          EntrepriseData.fromJson(doc.data() as Map<String, dynamic>)).toList();
      usersChat.entreprise=entrepriseList.first;



    }

    return usersChat;
  }

  RandomColor _randomColor = RandomColor();



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
  bool isMyFriend(List<Friends> userfriendList, String userIdToCheck) {
    return userfriendList.any((userAbonne) => userAbonne.friendId == userIdToCheck);
  }
  bool isInvite(List<Invitation> invitationList, String userIdToCheck) {
    return invitationList.any((inv) => inv.receiverId == userIdToCheck);
  }
  Future<void> suivreCanal(Canal canal) async {
      canal.usersSuiviId!.add(authProvider.loginUserData.id!);
      await firestore.collection('Canaux').doc(canal.id).update({
        'usersSuiviId': canal.usersSuiviId,
      });
      setState(() {
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Vous suivez maintenant ce canal.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.green),
          ),
        ),
      );
    }


  void onShow() {
    printVm('Menu is show');
  }
  void _showModalDialog(Post post) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Menu d\'options'),
          content: SingleChildScrollView(
            child: Column(
              children: <Widget>[
                ListTile(
                  onTap: () async {

                    post.status=PostStatus.SIGNALER.name;
                    await postProvider.updateVuePost(post, context).then((value) {
                      if (value) {
                        SnackBar snackBar = SnackBar(
                          content: Text(
                            'Post signalé !',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.green),
                          ),
                        );
                        ScaffoldMessenger.of(context)
                            .showSnackBar(snackBar);
                      }  else{
                        SnackBar snackBar = SnackBar(
                          content: Text(
                            'échec !',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.red),
                          ),
                        );
                        ScaffoldMessenger.of(context)
                            .showSnackBar(snackBar);
                      }
                      Navigator.pop(context);
                    },);
                    setState(() {
                    });

                  },
                  leading: Icon(Icons.flag,color: Colors.blueGrey,),
                  title: Text('Signaler',),
                ),
                /*
                ListTile(
                  onTap: () {
                    Navigator.pop(context);
                  },
                  leading: Icon(Icons.edit,color: Colors.blue,),
                  title: Text('Modifier'),
                ),

                 */
                ListTile(
                  onTap: () async {
                    if (authProvider.loginUserData.role==UserRole.ADM.name) {
                      post.status=PostStatus.NONVALIDE.name;
                      await postProvider.updateVuePost(post, context).then((value) {
                        if (value) {
                          SnackBar snackBar = SnackBar(
                            content: Text(
                              'Post bloqué !',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.green),
                            ),
                          );
                          ScaffoldMessenger.of(context)
                              .showSnackBar(snackBar);
                        }  else{
                          SnackBar snackBar = SnackBar(
                            content: Text(
                              'échec !',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.red),
                            ),
                          );
                          ScaffoldMessenger.of(context)
                              .showSnackBar(snackBar);
                        }
                      },);
                    }  else
                    if (post.type==PostType.POST.name){
                      if (post.user!.id==authProvider.loginUserData.id) {
                        post.status=PostStatus.SUPPRIMER.name;
                        await postProvider.updateVuePost(post, context).then((value) {
                          if (value) {
                            SnackBar snackBar = SnackBar(

                              content: Text(
                                'Post supprimé !',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.green),
                              ),
                            );
                            ScaffoldMessenger.of(context)
                                .showSnackBar(snackBar);
                          }  else{
                            SnackBar snackBar = SnackBar(
                              content: Text(
                                'échec !',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.red),
                              ),
                            );
                            ScaffoldMessenger.of(context)
                                .showSnackBar(snackBar);
                          }
                        },);
                      }

                    }



                    setState(() {
                      Navigator.pop(context);

                    });

                  },
                  leading: Icon(Icons.delete,color: Colors.red,),
                  title:authProvider.loginUserData.role==UserRole.ADM.name? Text('Bloquer'):Text('Supprimer'),
                ),
              ],
            ),
          ),
        );
      },
    );
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

  Widget homePostUsers(Post post,double height, double width) {
    double h = MediaQuery.of(context).size.height;
    double w = MediaQuery.of(context).size.width;

    Random random = Random();
    bool abonneTap =false;
    int like=post!.likes!;
    int imageIndex=0;
    int love=post!.loves!;
    int vue=post!.vues!;
    int comments=post!.comments!;
    bool tapLove=isIn(post.users_love_id!,authProvider.loginUserData.id!);
    bool tapLike=isIn(post.users_like_id!,authProvider.loginUserData.id!);
    List<int> likes =[];
    List<int> loves =[];
    int idUser=7;
    // Color _color = _randomColor.randomColor(
    //     colorHue: ColorHue.multiple(colorHues: [ColorHue.red, ColorHue.blue,ColorHue.green, ColorHue.orange,ColorHue.yellow, ColorHue.purple])
    // );

    int limitePosts=30;



    return Container(
      child:
      StatefulBuilder(
          builder: (BuildContext context, StateSetter setStateImages) {
            return Padding(
              padding: const EdgeInsets.all(5.0),
              child: Column(
                children: [
                  post.canal!=null?GestureDetector(
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => CanalListPage(isUserCanals: false,),));
                      Navigator.push(context, MaterialPageRoute(builder: (context) => CanalDetails(canal: post.canal!),));

                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: CircleAvatar(
                                backgroundImage: NetworkImage(
                                    '${post.canal!.urlImage!}'),
                              ),
                            ),
                            SizedBox(
                              height: 2,
                            ),
                            Row(
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      //width: 100,
                                      child: TextCustomerUserTitle(
                                        titre: "#${post.canal!.titre!}",
                                        fontSize: SizeText.homeProfileTextSize,
                                        couleur: ConstColors.textColors,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    TextCustomerUserTitle(
                                      titre: "${formatNumber(post.canal!.usersSuiviId!.length)} abonné(s)",
                                      fontSize: SizeText.homeProfileTextSize,
                                      couleur: ConstColors.textColors,
                                      fontWeight: FontWeight.w400,
                                    ),
                                    // TextCustomerUserTitle(
                                    //   titre: "${formatNumber(post.user!.userlikes!)} like(s)",
                                    //   fontSize: SizeText.homeProfileTextSize,
                                    //   couleur: Colors.green,
                                    //   fontWeight: FontWeight.w700,
                                    // ),

                                  ],
                                ),
                                // StatefulBuilder(
                                //
                                //     builder: (BuildContext context, void Function(void Function()) setState) {
                                //       return Container(
                                //         child: isUserAbonne(post.user!.userAbonnesIds!,
                                //             authProvider.loginUserData.id!)?Container(): TextButton(
                                //
                                //             onPressed:abonneTap?
                                //                 ()  { }:
                                //                 ()async{
                                //               if (!isUserAbonne(post.user!.userAbonnesIds!,
                                //                   authProvider.loginUserData.id!)) {
                                //                 setState(() {
                                //                   abonneTap=true;
                                //                 });
                                //                 UserAbonnes userAbonne = UserAbonnes();
                                //                 userAbonne.compteUserId=authProvider.loginUserData.id;
                                //                 userAbonne.abonneUserId=post.user!.id;
                                //
                                //                 userAbonne.createdAt  = DateTime.now().millisecondsSinceEpoch;
                                //                 userAbonne.updatedAt  = DateTime.now().millisecondsSinceEpoch;
                                //                 await  userProvider.sendAbonnementRequest(userAbonne,post.user!,context).then((value) async {
                                //                   if (value) {
                                //                     authProvider.loginUserData.userAbonnes!.add(userAbonne);
                                //                     // await userProvider.getUsers(authProvider.loginUserData!.id!);
                                //                     await authProvider.getCurrentUser(authProvider.loginUserData!.id!);
                                //                     if (post.user!.oneIgnalUserid!=null&&post.user!.oneIgnalUserid!.length>5) {
                                //                       await authProvider.sendNotification(
                                //                           userIds: [post.user!.oneIgnalUserid!],
                                //                           smallImage: "${authProvider.loginUserData.imageUrl!}",
                                //                           send_user_id: "${authProvider.loginUserData.id!}",
                                //                           recever_user_id: "${post.user!.id!}",
                                //                           message: "📢 @${authProvider.loginUserData.pseudo!} s'est abonné(e) à votre compte",
                                //                           type_notif: NotificationType.ABONNER.name,
                                //                           post_id: "${post!.id!}",
                                //                           post_type: PostDataType.IMAGE.name, chat_id: ''
                                //                       );
                                //                       NotificationData notif=NotificationData();
                                //                       notif.id=firestore
                                //                           .collection('Notifications')
                                //                           .doc()
                                //                           .id;
                                //                       notif.titre="Nouveau Abonnement ✅";
                                //                       notif.media_url=authProvider.loginUserData.imageUrl;
                                //                       notif.type=NotificationType.ABONNER.name;
                                //                       notif.description="@${authProvider.loginUserData.pseudo!} s'est abonné(e) à votre compte";
                                //                       notif.users_id_view=[];
                                //                       notif.user_id=authProvider.loginUserData.id;
                                //                       notif.receiver_id=post.user!.id!;
                                //                       notif.post_id=post.id!;
                                //                       notif.post_data_type=PostDataType.IMAGE.name!;
                                //                       notif.updatedAt =
                                //                           DateTime.now().microsecondsSinceEpoch;
                                //                       notif.createdAt =
                                //                           DateTime.now().microsecondsSinceEpoch;
                                //                       notif.status = PostStatus.VALIDE.name;
                                //
                                //                       // users.add(pseudo.toJson());
                                //
                                //                       await firestore.collection('Notifications').doc(notif.id).set(notif.toJson());
                                //
                                //
                                //                     }
                                //                     SnackBar snackBar = SnackBar(
                                //                       content: Text('abonné, Bravo ! Vous avez gagné 4 points.',textAlign: TextAlign.center,style: TextStyle(color: Colors.green),),
                                //                     );
                                //                     ScaffoldMessenger.of(context).showSnackBar(snackBar);
                                //                     setState(() {
                                //                       abonneTap=false;
                                //                     });
                                //                   }  else{
                                //                     SnackBar snackBar = SnackBar(
                                //                       content: Text('une erreur',textAlign: TextAlign.center,style: TextStyle(color: Colors.red),),
                                //                     );
                                //                     ScaffoldMessenger.of(context).showSnackBar(snackBar);
                                //                     setState(() {
                                //                       abonneTap=false;
                                //                     });
                                //                   }
                                //                 },);
                                //
                                //
                                //                 setState(() {
                                //                   abonneTap=false;
                                //                 });
                                //               }
                                //
                                //             },
                                //             child:abonneTap? Center(
                                //               child: LoadingAnimationWidget.flickr(
                                //                 size: 20,
                                //                 leftDotColor: Colors.green,
                                //                 rightDotColor: Colors.black,
                                //               ),
                                //             ): Text("S'abonner",style: TextStyle(fontSize: 12,fontWeight:FontWeight.normal,color: Colors.blue),)
                                //         ),
                                //       );
                                //     }
                                // ),
                                /*
                              IconButton(
                                  onPressed: () {},
                                  icon: Icon(
                                    Icons.add_circle_outlined,
                                    size: 20,
                                    color: ConstColors.regIconColors,
                                  )),

                               */
                              ],
                            ),

                          ],
                        ),
                        Visibility(
                          visible: post.canal!.isVerify!,
                          child: Card(
                            child: const Icon(
                              Icons.verified,
                              color: Colors.blue,
                              size: 20,
                            ),
                          ),
                        ),
                        Container(
                          child: post.canal!.usersSuiviId!.contains(authProvider.loginUserData.id)
                              ? null
                              : TextButton(
                            onPressed: () {
                              suivreCanal(post.canal!);
                            },
                            style: ElevatedButton.styleFrom(

                              backgroundColor: Colors.green, // Background color
                              // onPrimary: Colors.white, // Text color
                            ),
                            child: Text('Suivre', style: TextStyle(color: Colors.white)),
                          ),
                        ),
                        ElevatedButton(onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => CanalListPage(isUserCanals: false,),));
                          // Navigator.push(context, MaterialPageRoute(builder: (context) => CanalDetails(canal: post.canal!),));

                        }, child: Text('Voir plus',style: TextStyle(color: Colors.green),))
                        // IconButton(
                        //     onPressed: () {
                        //       _showModalDialog(post);
                        //     },
                        //     icon: Icon(
                        //       Icons.more_horiz,
                        //       size: 30,
                        //       color: ConstColors.blackIconColors,
                        //     )),
                      ],
                    ),
                  ): Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: CircleAvatar(
                              backgroundImage: NetworkImage(
                                  '${post.user!.imageUrl!}'),
                            ),
                          ),
                          SizedBox(
                            height: 2,
                          ),
                          Row(
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    //width: 100,
                                    child: TextCustomerUserTitle(
                                      titre: "@${post.user!.pseudo!}",
                                      fontSize: SizeText.homeProfileTextSize,
                                      couleur: ConstColors.textColors,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  TextCustomerUserTitle(
                                    titre: "${formatNumber(post.user!.abonnes!)} abonné(s)",
                                    fontSize: SizeText.homeProfileTextSize,
                                    couleur: ConstColors.textColors,
                                    fontWeight: FontWeight.w400,
                                  ),
                                  TextCustomerUserTitle(
                                    titre: "${formatNumber(post.user!.userlikes!)} like(s)",
                                    fontSize: SizeText.homeProfileTextSize,
                                    couleur: Colors.green,
                                    fontWeight: FontWeight.w700,
                                  ),

                                ],
                              ),
                              // StatefulBuilder(
                              //
                              //     builder: (BuildContext context, void Function(void Function()) setState) {
                              //       return Container(
                              //         child: isUserAbonne(post.user!.userAbonnesIds!,
                              //             authProvider.loginUserData.id!)?Container(): TextButton(
                              //
                              //             onPressed:abonneTap?
                              //                 ()  { }:
                              //                 ()async{
                              //               if (!isUserAbonne(post.user!.userAbonnesIds!,
                              //                   authProvider.loginUserData.id!)) {
                              //                 setState(() {
                              //                   abonneTap=true;
                              //                 });
                              //                 UserAbonnes userAbonne = UserAbonnes();
                              //                 userAbonne.compteUserId=authProvider.loginUserData.id;
                              //                 userAbonne.abonneUserId=post.user!.id;
                              //
                              //                 userAbonne.createdAt  = DateTime.now().millisecondsSinceEpoch;
                              //                 userAbonne.updatedAt  = DateTime.now().millisecondsSinceEpoch;
                              //                 await  userProvider.sendAbonnementRequest(userAbonne,post.user!,context).then((value) async {
                              //                   if (value) {
                              //                     authProvider.loginUserData.userAbonnes!.add(userAbonne);
                              //                     // await userProvider.getUsers(authProvider.loginUserData!.id!);
                              //                     await authProvider.getCurrentUser(authProvider.loginUserData!.id!);
                              //                     if (post.user!.oneIgnalUserid!=null&&post.user!.oneIgnalUserid!.length>5) {
                              //                       await authProvider.sendNotification(
                              //                           userIds: [post.user!.oneIgnalUserid!],
                              //                           smallImage: "${authProvider.loginUserData.imageUrl!}",
                              //                           send_user_id: "${authProvider.loginUserData.id!}",
                              //                           recever_user_id: "${post.user!.id!}",
                              //                           message: "📢 @${authProvider.loginUserData.pseudo!} s'est abonné(e) à votre compte",
                              //                           type_notif: NotificationType.ABONNER.name,
                              //                           post_id: "${post!.id!}",
                              //                           post_type: PostDataType.IMAGE.name, chat_id: ''
                              //                       );
                              //                       NotificationData notif=NotificationData();
                              //                       notif.id=firestore
                              //                           .collection('Notifications')
                              //                           .doc()
                              //                           .id;
                              //                       notif.titre="Nouveau Abonnement ✅";
                              //                       notif.media_url=authProvider.loginUserData.imageUrl;
                              //                       notif.type=NotificationType.ABONNER.name;
                              //                       notif.description="@${authProvider.loginUserData.pseudo!} s'est abonné(e) à votre compte";
                              //                       notif.users_id_view=[];
                              //                       notif.user_id=authProvider.loginUserData.id;
                              //                       notif.receiver_id=post.user!.id!;
                              //                       notif.post_id=post.id!;
                              //                       notif.post_data_type=PostDataType.IMAGE.name!;
                              //                       notif.updatedAt =
                              //                           DateTime.now().microsecondsSinceEpoch;
                              //                       notif.createdAt =
                              //                           DateTime.now().microsecondsSinceEpoch;
                              //                       notif.status = PostStatus.VALIDE.name;
                              //
                              //                       // users.add(pseudo.toJson());
                              //
                              //                       await firestore.collection('Notifications').doc(notif.id).set(notif.toJson());
                              //
                              //
                              //                     }
                              //                     SnackBar snackBar = SnackBar(
                              //                       content: Text('abonné, Bravo ! Vous avez gagné 4 points.',textAlign: TextAlign.center,style: TextStyle(color: Colors.green),),
                              //                     );
                              //                     ScaffoldMessenger.of(context).showSnackBar(snackBar);
                              //                     setState(() {
                              //                       abonneTap=false;
                              //                     });
                              //                   }  else{
                              //                     SnackBar snackBar = SnackBar(
                              //                       content: Text('une erreur',textAlign: TextAlign.center,style: TextStyle(color: Colors.red),),
                              //                     );
                              //                     ScaffoldMessenger.of(context).showSnackBar(snackBar);
                              //                     setState(() {
                              //                       abonneTap=false;
                              //                     });
                              //                   }
                              //                 },);
                              //
                              //
                              //                 setState(() {
                              //                   abonneTap=false;
                              //                 });
                              //               }
                              //
                              //             },
                              //             child:abonneTap? Center(
                              //               child: LoadingAnimationWidget.flickr(
                              //                 size: 20,
                              //                 leftDotColor: Colors.green,
                              //                 rightDotColor: Colors.black,
                              //               ),
                              //             ): Text("S'abonner",style: TextStyle(fontSize: 12,fontWeight:FontWeight.normal,color: Colors.blue),)
                              //         ),
                              //       );
                              //     }
                              // ),
                              /*
                            IconButton(
                                onPressed: () {},
                                icon: Icon(
                                  Icons.add_circle_outlined,
                                  size: 20,
                                  color: ConstColors.regIconColors,
                                )),

                             */
                            ],
                          ),

                        ],
                      ),
                      // IconButton(
                      //     onPressed: () {
                      //       _showModalDialog(post);
                      //     },
                      //     icon: Icon(
                      //       Icons.more_horiz,
                      //       size: 30,
                      //       color: ConstColors.blackIconColors,
                      //     )),
                    ],
                  ),
                  Visibility(
                      visible: post.type==PostType.PUB.name,
                      child: Row(
                        children: [
                          Icon(Icons.public,color: Colors.green,),
                          Text("Publicité",style: TextStyle(fontSize: 12,fontWeight: FontWeight.w900),),
                        ],
                      )
                  ),

                  SizedBox(
                    height: 5,
                  ),
                  Visibility(
                    visible: post.dataType!=PostDataType.TEXT.name?true:false,
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: SizedBox(
                        width: width*0.8,
                        // height: 50,
                        child: Container(
                          alignment: Alignment.centerLeft,
                          child: Column(
                            children: [
                              Visibility(
                                  visible: post.type==PostType.PUB.name,
                                  child: TextButton(onPressed: () async {
                                    if (!await launchUrl(Uri.parse('${post.urlLink}'))) {
                                      throw Exception('Could not launch ${'${post.urlLink}'}');
                                    }

                                  }, child: Text('${post.urlLink}',style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.green,
                                    fontWeight: FontWeight.normal,
                                    fontFamily: 'Nunito', // Définir la police Nunito
                                  ),))),
                              HashTagText(
                                text: "${post.description}",
                                decoratedStyle: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,

                                  color: Colors.green,
                                  fontFamily: 'Nunito', // Définir la police Nunito
                                ),
                                basicStyle: TextStyle(
                                  fontSize: 12,
                                  color: Colors.black87,
                                  fontWeight: FontWeight.normal,
                                  fontFamily: 'Nunito', // Définir la police Nunito
                                ),
                                textAlign: TextAlign.left, // Centrage du texte
                                maxLines: null, // Permet d'afficher le texte sur plusieurs lignes si nécessaire
                                softWrap: true, // Assure que le texte se découpe sur plusieurs lignes si nécessaire
                                // overflow: TextOverflow.ellipsis, // Ajoute une ellipse si le texte dépasse
                                onTap: (text) {
                                  print(text);
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 5,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: TextCustomerPostDescription(
                        titre: "${formaterDateTime(DateTime.fromMicrosecondsSinceEpoch(post.createdAt!))}",
                        fontSize: SizeText.homeProfileDateTextSize,
                        couleur: ConstColors.textColors,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Visibility(
                    visible: post.dataType==PostDataType.TEXT.name?true:false,

                    child: Container(
                      color: Colors.brown,
                      child: Align(
                        alignment: Alignment.center,
                        child: SizedBox(
                          width: width*0.8,
                          // height: 50,
                          child: Container(
                            // height: 200,
                            constraints: BoxConstraints(
                              // minHeight: 100.0, // Set your minimum height
                              maxHeight: height*0.6, // Set your maximum height
                            ),                          alignment: Alignment.center,
                            child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child:HashTagText(
                                  text: "${post.description}",
                                  decoratedStyle: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,

                                    color: Colors.green,
                                    fontFamily: 'Nunito', // Définir la police Nunito
                                  ),
                                  basicStyle: TextStyle(
                                    fontSize: 15,
                                    color: Colors.white,
                                    fontWeight: FontWeight.normal,
                                    fontFamily: 'Nunito', // Définir la police Nunito
                                  ),
                                  textAlign: TextAlign.center, // Centrage du texte
                                  maxLines: null, // Permet d'afficher le texte sur plusieurs lignes si nécessaire
                                  softWrap: true, // Assure que le texte se découpe sur plusieurs lignes si nécessaire
                                  // overflow: TextOverflow.ellipsis, // Ajoute une ellipse si le texte dépasse
                                  onTap: (text) {
                                    print(text);
                                  },
                                ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 5,
                  ),
                  /*
                Visibility(
                  visible: post.dataType!=PostDataType.TEXT.name?true:false,

                  child: Container(

                    child:    post!.images==null? Container():  Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [

                          for(int i=0;i<post!.images!.length;i++)
                            TextButton(onPressed: ()
                            {
                              setStateImages(() {
                                imageIndex=i;
                              });

                            }, child:   Container(
                              width: 100,
                              height: 50,

                              child: ClipRRect(
                                borderRadius: BorderRadius.all(Radius.circular(10)),
                                child: Container(

                                  child: CachedNetworkImage(

                                    fit: BoxFit.cover,
                                    imageUrl: '${post!.images![i]}',
                                    progressIndicatorBuilder: (context, url, downloadProgress) =>
                                    //  LinearProgressIndicator(),

                                    Skeletonizer(
                                        child: SizedBox(width: 400,height: 450, child:  ClipRRect(
                                            borderRadius: BorderRadius.all(Radius.circular(10)),child: Image.asset('assets/images/404.png')))),
                                    errorWidget: (context, url, error) =>  Skeletonizer(child: Container(width: 400,height: 450,child: Image.asset("assets/images/404.png",fit: BoxFit.cover,))),
                                  ),
                                ),
                              ),
                            ),)
                        ],
                      ),
                    ),
                  ),
                ),

                 */


                  Visibility(
                    visible: post.dataType!=PostDataType.TEXT.name?true:false,

                    child: GestureDetector(
                      onTap: () {
                       // Navigator.push(context, MaterialPageRoute(builder: (context) => DetailsPost(post: post),));
                      },

                      child: Container(
                        //width: w*0.9,
                        //height: h*0.5,

                        child: ClipRRect(
                          borderRadius: BorderRadius.all(Radius.circular(5)),
                          child: Container(


                            child: ImageSlideshow(

                              width: w,
                              height: h*0.5,

                              /// The page to show when first creating the [ImageSlideshow].
                              initialPage: 0,


                              /// The color to paint the indicator.
                              indicatorColor: Colors.green,

                              /// The color to paint behind th indicator.
                              indicatorBackgroundColor: Colors.grey,

                              /// Called whenever the page in the center of the viewport changes.
                              onPageChanged: (value) {
                                print('Page changed: $value');
                              },

                              /// Auto scroll interval.
                              /// Do not auto scroll with null or 0.
                              // autoPlayInterval: 9000,


                              /// Loops back to first slide.
                              isLoop: true,

                              /// The widgets to display in the [ImageSlideshow].
                              /// Add the sample image file into the images folder
                              children: post!.images!.map((e) =>     InstaImageViewer(
                                child:CachedNetworkImage(

                                  fit: BoxFit.contain,

                                  imageUrl: '$e',
                                  progressIndicatorBuilder: (context, url, downloadProgress) =>
                                  //  LinearProgressIndicator(),

                                  Skeletonizer(
                                      child: SizedBox(

                                          width: w * 0.9,
                                          height: h * 0.4,
                                          child:  ClipRRect(
                                              borderRadius: BorderRadius.all(Radius.circular(10)),child: Image.asset('assets/images/404.png')))),
                                  errorWidget: (context, url, error) =>  Skeletonizer(child: Container(
                                      width: w * 0.9,
                                      height: h * 0.4,
                                      child: Image.asset("assets/images/404.png",fit: BoxFit.cover,))),
                                ),
                              ),).toList(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),



                  SizedBox(
                    height: 10,
                  ),
                  Container(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        StatefulBuilder(builder:
                            (BuildContext context, StateSetter setState) {
                          return GestureDetector(
                            onTap: () async {
                              if (!isIn(post.users_love_id!,
                                  authProvider.loginUserData.id!)) {
                                setState(() {
                                  post.loves = post.loves! + 1;

                                  post.users_love_id!
                                      .add(authProvider!.loginUserData.id!);
                                  love = post.loves!;
                                  //loves.add(idUser);
                                });
                                CollectionReference userCollect =
                                FirebaseFirestore.instance
                                    .collection('Users');
                                // Get docs from collection reference
                                QuerySnapshot querySnapshotUser =
                                await userCollect
                                    .where("id",
                                    isEqualTo: post.user!.id!)
                                    .get();
                                // Afficher la liste
                                List<UserData> listUsers = querySnapshotUser
                                    .docs
                                    .map((doc) => UserData.fromJson(
                                    doc.data() as Map<String, dynamic>))
                                    .toList();
                                if (listUsers.isNotEmpty) {
                                  listUsers.first!.jaimes =
                                      listUsers.first!.jaimes! + 1;
                                  printVm("user trouver");
                                  if (post.user!.oneIgnalUserid != null &&
                                      post.user!.oneIgnalUserid!.length > 5) {
                                    await authProvider.sendNotification(
                                        userIds: [post.user!.oneIgnalUserid!],
                                        smallImage:
                                        "${authProvider.loginUserData.imageUrl!}",
                                        send_user_id:
                                        "${authProvider.loginUserData.id!}",
                                        recever_user_id: "${post.user!.id!}",
                                        message:
                                        "📢 @${authProvider.loginUserData.pseudo!} a aimé votre look",
                                        type_notif:
                                        NotificationType.POST.name,
                                        post_id: "${post!.id!}",
                                        post_type: PostDataType.IMAGE.name,
                                        chat_id: '');

                                    NotificationData notif =
                                    NotificationData();
                                    notif.id = firestore
                                        .collection('Notifications')
                                        .doc()
                                        .id;
                                    notif.titre = "Nouveau j'aime ❤️";
                                    notif.media_url =
                                        authProvider.loginUserData.imageUrl;
                                    notif.type = NotificationType.POST.name;
                                    notif.description =
                                    "@${authProvider.loginUserData.pseudo!} a aimé votre look";
                                    notif.users_id_view = [];
                                    notif.user_id =
                                        authProvider.loginUserData.id;
                                    notif.receiver_id = post.user!.id!;
                                    notif.post_id = post.id!;
                                    notif.post_data_type =
                                    PostDataType.IMAGE.name!;

                                    notif.updatedAt =
                                        DateTime.now().microsecondsSinceEpoch;
                                    notif.createdAt =
                                        DateTime.now().microsecondsSinceEpoch;
                                    notif.status = PostStatus.VALIDE.name;

                                    // users.add(pseudo.toJson());

                                    await firestore
                                        .collection('Notifications')
                                        .doc(notif.id)
                                        .set(notif.toJson());
                                  }
                                  // postProvider.updateVuePost(post, context);

                                  //userProvider.updateUser(listUsers.first);
                                  SnackBar snackBar = SnackBar(
                                    content: Text(
                                      '+2 points.  Voir le classement',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: Colors.green),
                                    ),
                                  );
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(snackBar);
                                  postProvider.updatePost(
                                      post, listUsers.first, context);
                                  await authProvider.getAppData();
                                  authProvider.appDefaultData.nbr_loves =
                                      authProvider.appDefaultData.nbr_loves! +
                                          2;
                                  authProvider.updateAppData(
                                      authProvider.appDefaultData);
                                } else {
                                  post.user!.jaimes = post.user!.jaimes! + 1;
                                  SnackBar snackBar = SnackBar(
                                    content: Text(
                                      '+2 points.  Voir le classement',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: Colors.green),
                                    ),
                                  );
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(snackBar);
                                  postProvider.updatePost(
                                      post, post.user!, context);
                                  await authProvider.getAppData();
                                  authProvider.appDefaultData.nbr_loves =
                                      authProvider.appDefaultData.nbr_loves! +
                                          2;
                                  authProvider.updateAppData(
                                      authProvider.appDefaultData);
                                }

                                tapLove = true;
                              }
                              printVm("jaime");
                              // setState(() {
                              // });
                            },
                            child: Container(
                              //height: 20,
                              width: 70,
                              height: 30,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                // mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        isIn(
                                            post.users_love_id!,
                                            authProvider
                                                .loginUserData.id!)
                                            ? Ionicons.heart
                                            : Ionicons.md_heart_outline,
                                        color: Colors.red,
                                        size: 20,
                                        // color: ConstColors.likeColors,
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.only(
                                            left: 1.0, right: 1),
                                        child: TextCustomerPostDescription(
                                          titre: "${formatAbonnes(love)}",
                                          fontSize: SizeText
                                              .homeProfileDateTextSize,
                                          couleur: ConstColors.textColors,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  /*
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.only(left: 1.0,right: 1),
                                        child: SizedBox(
                                          height: 2,
                                          width: 5,
                                          child: LinearProgressIndicator(
                                            color: Colors.red,
                                            value: love/post.user!.abonnes!+1,
                                            semanticsLabel: 'Linear progress indicator',
                                          ),
                                        ),
                                      ),
                                    ),
                                    TextCustomerPostDescription(
                                      titre: "${((love/post.user!.abonnes!+1)).toStringAsFixed(2)}%",
                                      fontSize: SizeText.homeProfileDateTextSize,
                                      couleur: ConstColors.textColors,
                                      fontWeight: FontWeight.bold,
                                    ),

                                     */
                                ],
                              ),
                            ),
                          );
                        }),
                        // StatefulBuilder(builder:
                        //     (BuildContext context, StateSetter setState) {
                        //   return GestureDetector(
                        //     onTap: () async {
                        //       if (!isIn(post.users_like_id!,
                        //           authProvider.loginUserData.id!)) {
                        //         setState(() {
                        //           post.likes = post.likes! + 1;
                        //
                        //           like = post.likes!;
                        //           post.users_like_id!
                        //               .add(authProvider!.loginUserData.id!);
                        //
                        //           //loves.add(idUser);
                        //         });
                        //         CollectionReference userCollect =
                        //             FirebaseFirestore.instance
                        //                 .collection('Users');
                        //         // Get docs from collection reference
                        //         QuerySnapshot querySnapshotUser =
                        //             await userCollect
                        //                 .where("id",
                        //                     isEqualTo: post.user!.id!)
                        //                 .get();
                        //         // Afficher la liste
                        //         List<UserData> listUsers = querySnapshotUser
                        //             .docs
                        //             .map((doc) => UserData.fromJson(
                        //                 doc.data() as Map<String, dynamic>))
                        //             .toList();
                        //
                        //         if (post.user!.oneIgnalUserid != null &&
                        //             post.user!.oneIgnalUserid!.length > 5) {
                        //           await authProvider.sendNotification(
                        //               userIds: [post.user!.oneIgnalUserid!],
                        //               smallImage:
                        //                   "${authProvider.loginUserData.imageUrl!}",
                        //               send_user_id:
                        //                   "${authProvider.loginUserData.id!}",
                        //               recever_user_id: "${post.user!.id!}",
                        //               message:
                        //                   "📢 @${authProvider.loginUserData.pseudo!} a liké votre look",
                        //               type_notif: NotificationType.POST.name,
                        //               post_id: "${post!.id!}",
                        //               post_type: PostDataType.IMAGE.name,
                        //               chat_id: '');
                        //
                        //           NotificationData notif = NotificationData();
                        //           notif.id = firestore
                        //               .collection('Notifications')
                        //               .doc()
                        //               .id;
                        //           notif.titre = "Nouveau like 👍🏾";
                        //           notif.media_url =
                        //               authProvider.loginUserData.imageUrl;
                        //           notif.type = NotificationType.POST.name;
                        //           notif.description =
                        //               "@${authProvider.loginUserData.pseudo!} a liké votre look";
                        //           notif.users_id_view = [];
                        //           notif.user_id =
                        //               authProvider.loginUserData.id;
                        //           notif.receiver_id = post.user!.id!;
                        //           notif.post_id = post.id!;
                        //           notif.post_data_type =
                        //               PostDataType.IMAGE.name!;
                        //
                        //           notif.updatedAt =
                        //               DateTime.now().microsecondsSinceEpoch;
                        //           notif.createdAt =
                        //               DateTime.now().microsecondsSinceEpoch;
                        //           notif.status = PostStatus.VALIDE.name;
                        //
                        //           // users.add(pseudo.toJson());
                        //
                        //           await firestore
                        //               .collection('Notifications')
                        //               .doc(notif.id)
                        //               .set(notif.toJson());
                        //         }
                        //         if (listUsers.isNotEmpty) {
                        //           SnackBar snackBar = SnackBar(
                        //             content: Text(
                        //               '+1 point.  Voir le classement',
                        //               textAlign: TextAlign.center,
                        //               style: TextStyle(color: Colors.green),
                        //             ),
                        //           );
                        //           ScaffoldMessenger.of(context)
                        //               .showSnackBar(snackBar);
                        //           listUsers.first!.likes =
                        //               listUsers.first!.likes! + 1;
                        //           printVm("user trouver");
                        //
                        //           //userProvider.updateUser(listUsers.first);
                        //           postProvider.updatePost(
                        //               post, listUsers.first, context);
                        //           await authProvider.getAppData();
                        //           authProvider.appDefaultData.nbr_likes =
                        //               authProvider.appDefaultData.nbr_likes! +
                        //                   1;
                        //           authProvider.updateAppData(
                        //               authProvider.appDefaultData);
                        //         } else {
                        //           SnackBar snackBar = SnackBar(
                        //             content: Text(
                        //               '+1 point.  Voir le classement',
                        //               textAlign: TextAlign.center,
                        //               style: TextStyle(color: Colors.green),
                        //             ),
                        //           );
                        //           ScaffoldMessenger.of(context)
                        //               .showSnackBar(snackBar);
                        //           post.user!.likes = post.user!.likes! + 1;
                        //           postProvider.updatePost(
                        //               post, post.user!, context);
                        //           await authProvider.getAppData();
                        //           authProvider.appDefaultData.nbr_likes =
                        //               authProvider.appDefaultData.nbr_likes! +
                        //                   1;
                        //           authProvider.updateAppData(
                        //               authProvider.appDefaultData);
                        //         }
                        //       }
                        //
                        //       setState(() {
                        //         //loves.add(idUser);
                        //       });
                        //     },
                        //     child: Container(
                        //       width: 70,
                        //       height: 30,
                        //       child: Row(
                        //         crossAxisAlignment: CrossAxisAlignment.center,
                        //         // mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        //         children: [
                        //           Row(
                        //             children: [
                        //               Icon(
                        //                 isIn(
                        //                         post.users_like_id!,
                        //                         authProvider
                        //                             .loginUserData.id!)
                        //                     ? MaterialCommunityIcons.thumb_up
                        //                     : MaterialCommunityIcons
                        //                         .thumb_up_outline,
                        //                 size: 20,
                        //                 color: isIn(
                        //                         post.users_like_id!,
                        //                         authProvider
                        //                             .loginUserData.id!)
                        //                     ? Colors.blue
                        //                     : Colors.black,
                        //               ),
                        //               Padding(
                        //                 padding: const EdgeInsets.only(
                        //                     left: 1.0, right: 1),
                        //                 child: TextCustomerPostDescription(
                        //                   titre: "${formatAbonnes(like)}",
                        //                   fontSize: SizeText
                        //                       .homeProfileDateTextSize,
                        //                   couleur: ConstColors.textColors,
                        //                   fontWeight: FontWeight.bold,
                        //                 ),
                        //               ),
                        //             ],
                        //           ),
                        //           /*
                        //           Expanded(
                        //             child: Padding(
                        //               padding: const EdgeInsets.only(left: 1.0,right: 1),
                        //               child: SizedBox(
                        //                 height: 2,
                        //                 // width: width*0.75,
                        //                 child: LinearProgressIndicator(
                        //                   color: Colors.blue,
                        //                   value: like/post.user!.abonnes!+1,
                        //                   semanticsLabel: 'Linear progress indicator',
                        //                 ),
                        //               ),
                        //             ),
                        //           ),
                        //           TextCustomerPostDescription(
                        //             titre: "${(like/post.user!.abonnes!+1).toStringAsFixed(2)}%",
                        //             fontSize: SizeText.homeProfileDateTextSize,
                        //             couleur: ConstColors.textColors,
                        //             fontWeight: FontWeight.bold,
                        //           ),
                        //
                        //            */
                        //         ],
                        //       ),
                        //     ),
                        //   );
                        // }),
                        StatefulBuilder(builder:
                            (BuildContext context, StateSetter setState) {
                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        PostComments(post: post),
                                  ));

                              //sheetComments(height*0.7,width,post);
                            },
                            child: Container(
                              width: 70,
                              height: 30,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                // mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        FontAwesome.comments,
                                        size: 20,
                                        color: Colors.green,
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.only(
                                            left: 1.0, right: 1),
                                        child: TextCustomerPostDescription(
                                          titre: "${formatAbonnes(comments)}",
                                          fontSize: SizeText
                                              .homeProfileDateTextSize,
                                          couleur: ConstColors.textColors,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  /*
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.only(left: 1.0,right: 1),
                                        child: SizedBox(
                                          height: 2,
                                          //width: width*0.75,
                                          child: LinearProgressIndicator(
                                            color: Colors.blueGrey,
                                            value: comments/post.user!.abonnes!+1,
                                            semanticsLabel: 'Linear progress indicator',
                                          ),
                                        ),
                                      ),
                                    ),
                                    TextCustomerPostDescription(
                                      titre: "${(comments/post.user!.abonnes!+1).toStringAsFixed(2)}%",
                                      fontSize: SizeText.homeProfileDateTextSize,
                                      couleur: ConstColors.textColors,
                                      fontWeight: FontWeight.bold,
                                    ),

                                     */
                                ],
                              ),
                            ),
                          );
                        }),

                        StatefulBuilder(builder:
                            (BuildContext context, StateSetter setState) {
                          return GestureDetector(
                            onTap: () async {
                              // await authProvider.createLink(post).then((value) {
                              final box = context.findRenderObject() as RenderBox?;

                              await authProvider.createLink(true,post).then((url) async {
                                await Share.shareUri(
                                  Uri.parse(
                                      '${url}'),
                                  sharePositionOrigin:
                                  box!.localToGlobal(Offset.zero) & box.size,
                                );


                                setState(() {
                                  post.partage = post.partage! + 1;

                                  // post.users_love_id!
                                  //     .add(authProvider!.loginUserData.id!);
                                  // love = post.loves!;
                                  // //loves.add(idUser);
                                });
                                CollectionReference userCollect =
                                FirebaseFirestore.instance
                                    .collection('Users');
                                // Get docs from collection reference
                                QuerySnapshot querySnapshotUser =
                                await userCollect
                                    .where("id",
                                    isEqualTo: post.user!.id!)
                                    .get();
                                // Afficher la liste
                                List<UserData> listUsers = querySnapshotUser
                                    .docs
                                    .map((doc) => UserData.fromJson(
                                    doc.data() as Map<String, dynamic>))
                                    .toList();
                                if (listUsers.isNotEmpty) {
                                  listUsers.first!.partage =
                                      listUsers.first!.partage! + 1;
                                  printVm("user trouver");
                                  if (post.user!.oneIgnalUserid != null &&
                                      post.user!.oneIgnalUserid!.length > 5) {
                                    await authProvider.sendNotification(
                                        userIds: [post.user!.oneIgnalUserid!],
                                        smallImage:
                                        "${authProvider.loginUserData.imageUrl!}",
                                        send_user_id:
                                        "${authProvider.loginUserData.id!}",
                                        recever_user_id: "${post.user!.id!}",
                                        message:
                                        "📢 @${authProvider.loginUserData.pseudo!} a partagé votre look",
                                        type_notif:
                                        NotificationType.POST.name,
                                        post_id: "${post!.id!}",
                                        post_type: PostDataType.IMAGE.name,
                                        chat_id: '');

                                    NotificationData notif =
                                    NotificationData();
                                    notif.id = firestore
                                        .collection('Notifications')
                                        .doc()
                                        .id;
                                    notif.titre = "Nouveau partage 📲";
                                    notif.media_url =
                                        authProvider.loginUserData.imageUrl;
                                    notif.type = NotificationType.POST.name;
                                    notif.description =
                                    "@${authProvider.loginUserData.pseudo!} a partagé votre look";
                                    notif.users_id_view = [];
                                    notif.user_id =
                                        authProvider.loginUserData.id;
                                    notif.receiver_id = post.user!.id!;
                                    notif.post_id = post.id!;
                                    notif.post_data_type =
                                    PostDataType.IMAGE.name!;

                                    notif.updatedAt =
                                        DateTime.now().microsecondsSinceEpoch;
                                    notif.createdAt =
                                        DateTime.now().microsecondsSinceEpoch;
                                    notif.status = PostStatus.VALIDE.name;

                                    // users.add(pseudo.toJson());

                                    await firestore
                                        .collection('Notifications')
                                        .doc(notif.id)
                                        .set(notif.toJson());
                                  }
                                  // postProvider.updateVuePost(post, context);

                                  //userProvider.updateUser(listUsers.first);
                                  // SnackBar snackBar = SnackBar(
                                  //   content: Text(
                                  //     '+2 points.  Voir le classement',
                                  //     textAlign: TextAlign.center,
                                  //     style: TextStyle(color: Colors.green),
                                  //   ),
                                  // );
                                  // ScaffoldMessenger.of(context)
                                  //     .showSnackBar(snackBar);
                                  postProvider.updatePost(
                                      post, listUsers.first, context);
                                  // await authProvider.getAppData();
                                  // authProvider.appDefaultData.nbr_loves =
                                  //     authProvider.appDefaultData.nbr_loves! +
                                  //         2;
                                  // authProvider.updateAppData(
                                  //     authProvider.appDefaultData);


                                  tapLove = true;
                                }

                              },);
                              // if (!isIn(post.users_love_id!,
                              //     authProvider.loginUserData.id!)) {
                              //   setState(() {
                              //     post.loves = post.loves! + 1;
                              //
                              //     post.users_love_id!
                              //         .add(authProvider!.loginUserData.id!);
                              //     love = post.loves!;
                              //     //loves.add(idUser);
                              //   });
                              //   CollectionReference userCollect =
                              //   FirebaseFirestore.instance
                              //       .collection('Users');
                              //   // Get docs from collection reference
                              //   QuerySnapshot querySnapshotUser =
                              //   await userCollect
                              //       .where("id",
                              //       isEqualTo: post.user!.id!)
                              //       .get();
                              //   // Afficher la liste
                              //   List<UserData> listUsers = querySnapshotUser
                              //       .docs
                              //       .map((doc) => UserData.fromJson(
                              //       doc.data() as Map<String, dynamic>))
                              //       .toList();
                              //   if (listUsers.isNotEmpty) {
                              //     listUsers.first!.jaimes =
                              //         listUsers.first!.jaimes! + 1;
                              //     printVm("user trouver");
                              //     if (post.user!.oneIgnalUserid != null &&
                              //         post.user!.oneIgnalUserid!.length > 5) {
                              //       await authProvider.sendNotification(
                              //           userIds: [post.user!.oneIgnalUserid!],
                              //           smallImage:
                              //           "${authProvider.loginUserData.imageUrl!}",
                              //           send_user_id:
                              //           "${authProvider.loginUserData.id!}",
                              //           recever_user_id: "${post.user!.id!}",
                              //           message:
                              //           "📢 @${authProvider.loginUserData.pseudo!} a aimé votre look",
                              //           type_notif:
                              //           NotificationType.POST.name,
                              //           post_id: "${post!.id!}",
                              //           post_type: PostDataType.IMAGE.name,
                              //           chat_id: '');
                              //
                              //       NotificationData notif =
                              //       NotificationData();
                              //       notif.id = firestore
                              //           .collection('Notifications')
                              //           .doc()
                              //           .id;
                              //       notif.titre = "Nouveau j'aime ❤️";
                              //       notif.media_url =
                              //           authProvider.loginUserData.imageUrl;
                              //       notif.type = NotificationType.POST.name;
                              //       notif.description =
                              //       "@${authProvider.loginUserData.pseudo!} a aimé votre look";
                              //       notif.users_id_view = [];
                              //       notif.user_id =
                              //           authProvider.loginUserData.id;
                              //       notif.receiver_id = post.user!.id!;
                              //       notif.post_id = post.id!;
                              //       notif.post_data_type =
                              //       PostDataType.IMAGE.name!;
                              //
                              //       notif.updatedAt =
                              //           DateTime.now().microsecondsSinceEpoch;
                              //       notif.createdAt =
                              //           DateTime.now().microsecondsSinceEpoch;
                              //       notif.status = PostStatus.VALIDE.name;
                              //
                              //       // users.add(pseudo.toJson());
                              //
                              //       await firestore
                              //           .collection('Notifications')
                              //           .doc(notif.id)
                              //           .set(notif.toJson());
                              //     }
                              //     // postProvider.updateVuePost(post, context);
                              //
                              //     //userProvider.updateUser(listUsers.first);
                              //     SnackBar snackBar = SnackBar(
                              //       content: Text(
                              //         '+2 points.  Voir le classement',
                              //         textAlign: TextAlign.center,
                              //         style: TextStyle(color: Colors.green),
                              //       ),
                              //     );
                              //     ScaffoldMessenger.of(context)
                              //         .showSnackBar(snackBar);
                              //     postProvider.updatePost(
                              //         post, listUsers.first, context);
                              //     await authProvider.getAppData();
                              //     authProvider.appDefaultData.nbr_loves =
                              //         authProvider.appDefaultData.nbr_loves! +
                              //             2;
                              //     authProvider.updateAppData(
                              //         authProvider.appDefaultData);
                              //   } else {
                              //     post.user!.jaimes = post.user!.jaimes! + 1;
                              //     SnackBar snackBar = SnackBar(
                              //       content: Text(
                              //         '+2 points.  Voir le classement',
                              //         textAlign: TextAlign.center,
                              //         style: TextStyle(color: Colors.green),
                              //       ),
                              //     );
                              //     ScaffoldMessenger.of(context)
                              //         .showSnackBar(snackBar);
                              //     postProvider.updatePost(
                              //         post, post.user!, context);
                              //     await authProvider.getAppData();
                              //     authProvider.appDefaultData.nbr_loves =
                              //         authProvider.appDefaultData.nbr_loves! +
                              //             2;
                              //     authProvider.updateAppData(
                              //         authProvider.appDefaultData);
                              //   }
                              //
                              //   tapLove = true;
                              // }
                              // printVm("jaime");
                              // // setState(() {
                              // // });
                            },
                            child: Container(
                              //height: 20,
                              width: 70,
                              height: 30,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                // mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        isIn(
                                            post.users_love_id!,
                                            authProvider
                                                .loginUserData.id!)
                                            ? Icons.share
                                            : Icons.share,
                                        color: Colors.red,
                                        size: 20,
                                        // color: ConstColors.likeColors,
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.only(
                                            left: 1.0, right: 1),
                                        child: TextCustomerPostDescription(
                                          titre: "${formatAbonnes(post.partage!)}",
                                          fontSize: SizeText
                                              .homeProfileDateTextSize,
                                          couleur: ConstColors.textColors,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  /*
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.only(left: 1.0,right: 1),
                                        child: SizedBox(
                                          height: 2,
                                          width: 5,
                                          child: LinearProgressIndicator(
                                            color: Colors.red,
                                            value: love/post.user!.abonnes!+1,
                                            semanticsLabel: 'Linear progress indicator',
                                          ),
                                        ),
                                      ),
                                    ),
                                    TextCustomerPostDescription(
                                      titre: "${((love/post.user!.abonnes!+1)).toStringAsFixed(2)}%",
                                      fontSize: SizeText.homeProfileDateTextSize,
                                      couleur: ConstColors.textColors,
                                      fontWeight: FontWeight.bold,
                                    ),

                                     */
                                ],
                              ),
                            ),
                          );
                        }),





                      ],
                    ),
                  ),


                  SizedBox(
                    height: 10,
                  ),
                  Divider(
                    height: 3,
                  )

                ],
              ),
            );
          }
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;
    return  Scaffold(
        appBar: AppBar(
          actions: [
           Padding(
             padding: const EdgeInsets.only(right: 8.0),
             child: Logo(),
           ),

          ],
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
            children: <Widget>[
              homePostUsers(widget.post, height, width),
            ]
                  ),
          ),
        ),
    );
  }
}
