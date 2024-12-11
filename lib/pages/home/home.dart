import 'dart:async';
import 'dart:math';
import 'package:afrotok/pages/afroshop/marketPlace/acceuil/home_afroshop.dart';
import 'package:afrotok/pages/home/users_cards/allUsersCard.dart';

import 'package:afrotok/pages/user/detailsOtherUser.dart';
import 'package:afrotok/pages/user/otherUser/otherUser.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_slideshow/flutter_image_slideshow.dart';
import 'package:restart_app/restart_app.dart';
import 'package:afrotok/pages/postComments.dart';
import 'package:afrotok/pages/postDetails.dart';
import 'package:afrotok/pages/simpleChargement.dart';
import 'package:afrotok/providers/postProvider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flash/flash.dart';
import 'package:flash/flash_helper.dart';
import 'package:flutter/foundation.dart';
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
import 'package:flutter_carousel_widget/flutter_carousel_widget.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:intl/intl.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:marquee/marquee.dart';
import 'package:page_transition/page_transition.dart';
import 'package:popup_menu_plus/popup_menu_plus.dart';
import 'package:provider/provider.dart';
import 'package:random_color/random_color.dart';
import 'package:share_plus/share_plus.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:upgrader/upgrader.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../constant/custom_theme.dart';
import '../../constant/textCustom.dart';
import '../../models/chatmodels/message.dart';
import '../../providers/afroshop/authAfroshopProvider.dart';
import '../../providers/afroshop/categorie_produits_provider.dart';
import '../../providers/authProvider.dart';
import '../afroshop/marketPlace/acceuil/produit_details.dart';
import '../chat/entrepriseChat.dart';
import '../chat/ia_Chat.dart';
import '../chat/myChat.dart';
import '../component/consoleWidget.dart';
import '../ia/compagnon/introIaCompagnon.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../user/amis/addListAmis.dart';
import '../user/amis/pageMesInvitations.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  String token = '';
  bool dejaVuPub = true;
  bool contact_whatsapp = false;
  bool contact_afrolook = false;

  GlobalKey btnKey = GlobalKey();
  GlobalKey btnKey2 = GlobalKey();
  GlobalKey btnKey3 = GlobalKey();
  GlobalKey btnKey4 = GlobalKey();
  final _formKey = GlobalKey<FormState>();
  GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late UserAuthProvider authProvider =
      Provider.of<UserAuthProvider>(context, listen: false);
  late UserShopAuthProvider authProviderShop =
      Provider.of<UserShopAuthProvider>(context, listen: false);
  late CategorieProduitProvider categorieProduitProvider =
      Provider.of<CategorieProduitProvider>(context, listen: false);
  late UserProvider userProvider =
      Provider.of<UserProvider>(context, listen: false);
  final List<String> noms = ['Alice', 'Bob', 'Charlie'];
  late PostProvider postProvider =
      Provider.of<PostProvider>(context, listen: false);
  TextEditingController commentController = TextEditingController();
  Future<void> launchWhatsApp(String phone) async {
    //  var whatsappURl_android = "whatsapp://send?phone="+whatsapp+"&text=hello";
    // String url = "https://wa.me/?tel:+228$phone&&text=YourTextHere";
    String url = "whatsapp://send?phone=" + phone + "";
    if (!await launchUrl(Uri.parse(url))) {
      final snackBar = SnackBar(
          duration: Duration(seconds: 2),
          content: Text(
            "Impossible d\'ouvrir WhatsApp",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.red),
          ));

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

  Future<Chat> getIAChatsData(UserIACompte amigo) async {
    // Définissez la requête
    var friendsStream = FirebaseFirestore.instance
        .collection('Chats')
        .where(Filter.or(
          Filter('docId',
              isEqualTo: '${authProvider.loginUserData.id}${amigo.id}'),
          Filter('docId',
              isEqualTo: '${amigo.id}${authProvider.loginUserData.id}'),
        ))
        .snapshots();

// Obtenez la liste des utilisateurs
    //List<DocumentSnapshot> users = await usersQuery.sget();
    Chat usersChat = Chat();

    if (await friendsStream.isEmpty) {
      printVm("pas de chat ");
      String chatId = FirebaseFirestore.instance.collection('Chats').doc().id;
      Chat chat = Chat(
        docId: '${amigo.id}${authProvider.loginUserData.id}',
        id: chatId,
        senderId: '${authProvider.loginUserData.id}',
        receiverId: '${amigo.id}',
        lastMessage: 'hi',

        type: ChatType.USER.name,
        createdAt: DateTime.now()
            .millisecondsSinceEpoch, // Get current time in milliseconds
        updatedAt: DateTime.now().millisecondsSinceEpoch,
        // Optional: You can initialize sender and receiver with UserData objects, and messages with a list of Message objects
      );
      await FirebaseFirestore.instance
          .collection('Chats')
          .doc(chatId)
          .set(chat.toJson());
      usersChat = chat;
    } else {
      printVm("le chat existe  ");
      printVm("stream :${friendsStream}");
      usersChat = await friendsStream.first.then((value) async {
        printVm("stream value l :${value.docs.length}");
        if (value.docs.length <= 0) {
          printVm("pas de chat ");
          String chatId =
              FirebaseFirestore.instance.collection('Chats').doc().id;
          Chat chat = Chat(
            docId: '${amigo.id}${authProvider.loginUserData.id}',
            id: chatId,
            senderId: '${authProvider.loginUserData.id}',
            receiverId: '${amigo.id}',
            lastMessage: 'hi',

            type: ChatType.USER.name,
            createdAt: DateTime.now()
                .millisecondsSinceEpoch, // Get current time in milliseconds
            updatedAt: DateTime.now().millisecondsSinceEpoch,
            // Optional: You can initialize sender and receiver with UserData objects, and messages with a list of Message objects
          );
          await FirebaseFirestore.instance
              .collection('Chats')
              .doc(chatId)
              .set(chat.toJson());
          usersChat = chat;
          return chat;
        } else {
          return Chat.fromJson(value.docs.first.data());
        }
      });
      CollectionReference messageCollect =
          await FirebaseFirestore.instance.collection('Messages');
      QuerySnapshot querySnapshotMessage =
          await messageCollect.where("chat_id", isEqualTo: usersChat.id!).get();
      // Afficher la liste
      List<Message> messageList = querySnapshotMessage.docs
          .map((doc) => Message.fromJson(doc.data() as Map<String, dynamic>))
          .toList();

      if (messageList.isEmpty) {
        usersChat.messages = [];
        userProvider.chat = usersChat;
        printVm("messgae vide ");
      } else {
        printVm("have messages");
        usersChat.messages = messageList;
        userProvider.chat = usersChat;
      }

      /////////////ami//////////
      /*
      CollectionReference friendCollect = await FirebaseFirestore.instance.collection('Users');
      QuerySnapshot querySnapshotUserSender = await friendCollect.where("id",isEqualTo:authProvider.loginUserData.id==amigo.friendId?'${amigo.friendId}':'${amigo.currentUserId}').get();
      // Afficher la liste
      QuerySnapshot querySnapshotUserReceiver= await friendCollect.where("id",isEqualTo:authProvider.loginUserData.id==amigo.friendId?'${amigo.currentUserId}':'${amigo.friendId}').get();


      List<UserData> receiverUserList = querySnapshotUserReceiver.docs.map((doc) =>
          UserData.fromJson(doc.data() as Map<String, dynamic>)).toList();
      usersChat.receiver=receiverUserList.first;

      List<UserData> senderUserList = querySnapshotUserSender.docs.map((doc) =>
          UserData.fromJson(doc.data() as Map<String, dynamic>)).toList();
      usersChat.sender=senderUserList.first;

       */
    }

    return usersChat;
  }

  Future<Chat> getChatsEntrepriseData(
      UserData amigo, Post post, EntrepriseData entreprise)
  async {
    // Définissez la requête
    var friendsStream = FirebaseFirestore.instance
        .collection('Chats')
        .where(Filter.or(
          Filter('docId',
              isEqualTo: '${post.id}${authProvider.loginUserData!.id}'),
          Filter('docId',
              isEqualTo: '${authProvider.loginUserData!.id}${post.id}'),
        ))
        .snapshots();

// Obtenez la liste des utilisateurs
    //List<DocumentSnapshot> users = await usersQuery.sget();
    Chat usersChat = Chat();

    if (await friendsStream.isEmpty) {
      printVm("pas de chat ");
      String chatId = FirebaseFirestore.instance.collection('Chats').doc().id;
      Chat chat = Chat(
        docId: '${post.id}${authProvider.loginUserData!.id}',
        id: chatId,
        senderId: '${authProvider.loginUserData!.id}',
        receiverId: '${amigo.id}',
        lastMessage: 'hi',
        post_id: post.id,
        entreprise_id: post.entreprise_id,
        type: ChatType.ENTREPRISE.name,
        createdAt: DateTime.now()
            .millisecondsSinceEpoch, // Get current time in milliseconds
        updatedAt: DateTime.now().millisecondsSinceEpoch,
        // Optional: You can initialize sender and receiver with UserData objects, and messages with a list of Message objects
      );
      await FirebaseFirestore.instance
          .collection('Chats')
          .doc(chatId)
          .set(chat.toJson());
      usersChat = chat;
    } else {
      printVm("le chat existe  ");
      // printVm("stream :${friendsStream}");
      usersChat = await friendsStream.first.then((value) async {
        // printVm("stream value l :${value.docs.length}");
        if (value.docs.length <= 0) {
          printVm("pas de chat ");
          String chatId =
              FirebaseFirestore.instance.collection('Chats').doc().id;
          Chat chat = Chat(
            docId: '${post.id}${authProvider.loginUserData!.id}',
            id: chatId,
            senderId: '${authProvider.loginUserData!.id}',
            receiverId: '${amigo.id}',
            lastMessage: 'hi',
            entreprise_id: post.entreprise_id,
            post_id: post.id,
            type: ChatType.ENTREPRISE.name,
            createdAt: DateTime.now()
                .millisecondsSinceEpoch, // Get current time in milliseconds
            updatedAt: DateTime.now().millisecondsSinceEpoch,
            // Optional: You can initialize sender and receiver with UserData objects, and messages with a list of Message objects
          );
          await FirebaseFirestore.instance
              .collection('Chats')
              .doc(chatId)
              .set(chat.toJson());
          usersChat = chat;
          return chat;
        } else {
          return Chat.fromJson(value.docs.first.data());
        }
      });
      CollectionReference messageCollect =
          await FirebaseFirestore.instance.collection('Messages');
      QuerySnapshot querySnapshotMessage =
          await messageCollect.where("chat_id", isEqualTo: usersChat.id!).get();
      // Afficher la liste
      List<Message> messageList = querySnapshotMessage.docs
          .map((doc) => Message.fromJson(doc.data() as Map<String, dynamic>))
          .toList();

      if (messageList.isEmpty) {
        usersChat.messages = [];
        userProvider.chat = usersChat;
        printVm("messages vide ");
      } else {
        printVm("have messages");
        usersChat.messages = messageList;
        userProvider.chat = usersChat;
      }

      /////////////ami//////////
      CollectionReference friendCollect =
          await FirebaseFirestore.instance.collection('Users');
      QuerySnapshot querySnapshotUserSender = await friendCollect
          .where("id",
              isEqualTo: authProvider.loginUserData.id == amigo.id!
                  ? '${amigo.id}'
                  : '${authProvider.loginUserData!.id}')
          .get();
      // Afficher la liste
      QuerySnapshot querySnapshotUserReceiver = await friendCollect
          .where("id",
              isEqualTo: authProvider.loginUserData.id == amigo.id
                  ? '${authProvider.loginUserData!.id}'
                  : '${amigo.id}')
          .get();

      List<UserData> receiverUserList = querySnapshotUserReceiver.docs
          .map((doc) => UserData.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
      usersChat.receiver = receiverUserList.first;

      List<UserData> senderUserList = querySnapshotUserSender.docs
          .map((doc) => UserData.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
      usersChat.sender = senderUserList.first;

      /////////////entreprise//////////
      CollectionReference entrepriseCollect =
          await FirebaseFirestore.instance.collection('Entreprises');
      QuerySnapshot querySnapshotentreprise = await entrepriseCollect
          .where("id", isEqualTo: '${post.entreprise_id}')
          .get();
      List<EntrepriseData> entrepriseList = querySnapshotentreprise.docs
          .map((doc) =>
              EntrepriseData.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
      usersChat.entreprise = entrepriseList.first;
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

  bool isMyFriend(List<String> userfriendList, String userIdToCheck) {
    return userfriendList.any((userfriendId) => userfriendId == userIdToCheck);
  }

  bool isInvite(List<String> invitationList, String userIdToCheck) {
    return invitationList.any((invid) => invid == userIdToCheck);
  }

  void onClickMenu(PopUpMenuItemProvider item) {
    printVm('Click menu -> ${item.menuTitle}');
  }

  void onDismiss() {
    printVm('Menu is dismiss');
  }

  void onShow() {
    printVm('Menu is show');
  }

  void _showPostMenuModalDialog(Post post) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Menu'),
          content: SingleChildScrollView(
            child: Column(
              children: <Widget>[
                Visibility(
                  visible: post.user!.id != authProvider.loginUserData.id,
                  child: ListTile(
                    onTap: () async {
                      post.status = PostStatus.SIGNALER.name;
                      await postProvider.updateVuePost(post, context).then(
                        (value) {
                          if (value) {
                            SnackBar snackBar = SnackBar(
                              content: Text(
                                'Post signalé !',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.green),
                              ),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(snackBar);
                          } else {
                            SnackBar snackBar = SnackBar(
                              content: Text(
                                'échec !',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.red),
                              ),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(snackBar);
                          }
                          Navigator.pop(context);
                        },
                      );
                      setState(() {});
                    },
                    leading: Icon(
                      Icons.flag,
                      color: Colors.blueGrey,
                    ),
                    title: Text(
                      'Signaler',
                    ),
                  ),
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
                Visibility(
                  visible: authProvider.loginUserData.role == UserRole.ADM.name,
                  child: ListTile(
                    onTap: () async {
                      if (authProvider.loginUserData.role == UserRole.ADM.name) {
                        post.status = PostStatus.NONVALIDE.name;
                        await postProvider.updateVuePost(post, context).then(
                              (value) {
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
                            } else {
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
                          },
                        );
                      } else if (post.type == PostType.POST.name) {
                        if (post.user!.id == authProvider.loginUserData.id) {
                          post.status = PostStatus.SUPPRIMER.name;
                          await postProvider.updateVuePost(post, context).then(
                                (value) {
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
                              } else {
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
                            },
                          );
                        }
                      }

                      setState(() {
                        Navigator.pop(context);
                      });
                    },
                    leading: Icon(
                      Icons.delete,
                      color: Colors.red,
                    ),
                    title: authProvider.loginUserData.role == UserRole.ADM.name
                        ? Text('Bloquer')
                        : Text('Supprimer'),
                  ),
                ),

                Visibility(
                  visible: post.user!.id == authProvider.loginUserData.id,
                  child: ListTile(
                    onTap: () async {
                      if (authProvider.loginUserData.role == UserRole.ADM.name) {
                        post.status = PostStatus.NONVALIDE.name;
                        await postProvider.updateVuePost(post, context).then(
                          (value) {
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
                            } else {
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
                          },
                        );
                      } else if (post.type == PostType.POST.name) {
                        if (post.user!.id == authProvider.loginUserData.id) {
                          post.status = PostStatus.SUPPRIMER.name;
                          await postProvider.updateVuePost(post, context).then(
                            (value) {
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
                              } else {
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
                            },
                          );
                        }
                      }

                      setState(() {
                        Navigator.pop(context);
                      });
                    },
                    leading: Icon(
                      Icons.delete,
                      color: Colors.red,
                    ),
                    title: authProvider.loginUserData.role == UserRole.ADM.name
                        ? Text('Bloquer')
                        : Text('Supprimer'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showUserDetailsAnnonceDialog(String url, Annonce annonce) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Container(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(10),
                      topRight: Radius.circular(10)),
                  child: Container(
                    child: CachedNetworkImage(
                      fit: BoxFit.cover,
                      imageUrl: '${url}',
                      progressIndicatorBuilder: (context, url,
                              downloadProgress) =>
                          //  LinearProgressIndicator(),

                          Skeletonizer(
                              child: SizedBox(
                                  width: 120,
                                  height: 100,
                                  child: ClipRRect(
                                      borderRadius:
                                          BorderRadius.all(Radius.circular(10)),
                                      child: Image.asset(
                                          'assets/images/404.png')))),
                      errorWidget: (context, url, error) => Container(
                          width: 120,
                          height: 100,
                          child: Image.asset(
                            "assets/icon/user-removebg-preview.png",
                            fit: BoxFit.cover,
                          )),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Center(
                    child: Container(
                      //width: 100,
                      decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.5),
                          borderRadius: BorderRadius.all(Radius.circular(50))),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "vues: ",
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              "${annonce.vues}",
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showUserDetailsModalDialog(UserData user, double w, double h) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          content: DetailsOtherUser(
            user: user,
            w: w,
            h: h,
          ),
        );
      },
    );
  }

  Future<Chat> getChatsData(UserData amigo) async {
    // Définissez la requête
    var friendsStream = FirebaseFirestore.instance
        .collection('Chats')
        .where(Filter.or(
          Filter('docId',
              isEqualTo: '${amigo.id}${authProvider.loginUserData.id!}'),
          Filter('docId',
              isEqualTo: '${authProvider.loginUserData.id!}${amigo.id}'),
        ))
        .snapshots();

// Obtenez la liste des utilisateurs
    //List<DocumentSnapshot> users = await usersQuery.sget();
    Chat usersChat = Chat();

    if (await friendsStream.isEmpty) {
      printVm("pas de chat ");
      String chatId = FirebaseFirestore.instance.collection('Chats').doc().id;
      Chat chat = Chat(
        docId: '${amigo.id}${authProvider.loginUserData.id!}',
        id: chatId,
        senderId: authProvider.loginUserData.id == amigo.id
            ? '${amigo.id}'
            : '${authProvider.loginUserData.id!}',
        receiverId: authProvider.loginUserData.id == amigo.id
            ? '${authProvider.loginUserData.id!}'
            : '${amigo.id}',
        lastMessage: 'hi',

        type: ChatType.USER.name,
        createdAt: DateTime.now()
            .millisecondsSinceEpoch, // Get current time in milliseconds
        updatedAt: DateTime.now().millisecondsSinceEpoch,
        // Optional: You can initialize sender and receiver with UserData objects, and messages with a list of Message objects
      );
      await FirebaseFirestore.instance
          .collection('Chats')
          .doc(chatId)
          .set(chat.toJson());
      usersChat = chat;
    } else {
      printVm("le chat existe  ");
      printVm("stream :${friendsStream}");
      usersChat = await friendsStream.first.then((value) async {
        printVm("stream value l :${value.docs.length}");
        if (value.docs.length <= 0) {
          printVm("pas de chat ");

          String chatId =
              FirebaseFirestore.instance.collection('Chats').doc().id;
          Chat chat = Chat(
            docId: '${amigo.id}${authProvider.loginUserData.id!}',
            id: chatId,
            senderId: authProvider.loginUserData.id == amigo.id
                ? '${amigo.id}'
                : '${authProvider.loginUserData.id!}',
            receiverId: authProvider.loginUserData.id == amigo.id
                ? '${authProvider.loginUserData.id!}'
                : '${amigo.id}',
            lastMessage: 'hi',

            type: ChatType.USER.name,
            createdAt: DateTime.now()
                .millisecondsSinceEpoch, // Get current time in milliseconds
            updatedAt: DateTime.now().millisecondsSinceEpoch,
            // Optional: You can initialize sender and receiver with UserData objects, and messages with a list of Message objects
          );
          await FirebaseFirestore.instance
              .collection('Chats')
              .doc(chatId)
              .set(chat.toJson());
          usersChat = chat;
          return chat;
        } else {
          return Chat.fromJson(value.docs.first.data());
        }
      });
      CollectionReference messageCollect =
          await FirebaseFirestore.instance.collection('Messages');
      QuerySnapshot querySnapshotMessage =
          await messageCollect.where("chat_id", isEqualTo: usersChat.id!).get();
      // Afficher la liste
      List<Message> messageList = querySnapshotMessage.docs
          .map((doc) => Message.fromJson(doc.data() as Map<String, dynamic>))
          .toList();

      if (messageList.isEmpty) {
        usersChat.messages = [];
        userProvider.chat = usersChat;
        printVm("messgae vide ");
      } else {
        printVm("have messages");
        usersChat.messages = messageList;
        userProvider.chat = usersChat;
      }

      /////////////ami//////////
      CollectionReference friendCollect =
          await FirebaseFirestore.instance.collection('Users');
      QuerySnapshot querySnapshotUserSender = await friendCollect
          .where("id",
              isEqualTo: authProvider.loginUserData.id == amigo.id
                  ? '${amigo.id}'
                  : '${authProvider.loginUserData.id!}')
          .get();
      // Afficher la liste
      QuerySnapshot querySnapshotUserReceiver = await friendCollect
          .where("id",
              isEqualTo: authProvider.loginUserData.id == amigo.id
                  ? '${authProvider.loginUserData.id!}'
                  : '${amigo.id}')
          .get();

      List<UserData> receiverUserList = querySnapshotUserReceiver.docs
          .map((doc) => UserData.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
      usersChat.receiver = receiverUserList.first;

      List<UserData> senderUserList = querySnapshotUserSender.docs
          .map((doc) => UserData.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
      usersChat.sender = senderUserList.first;
    }

    return usersChat;
  }

  Widget homeProfileUsers(UserData user, double w, double h) {
    //authProvider.getCurrentUser(authProvider.loginUserData!.id!);
    //  printVm("invitation : ${authProvider.loginUserData.mesInvitationsEnvoyer!.length}");

    bool abonneTap = false;
    bool inviteTap = false;
    bool dejaInviter = false;

    return SizedBox(
      // width: w * 0.45,
      // height: h * 0.15,
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: () {
                _showUserDetailsModalDialog(user, w, h);
              },
              child: ClipRRect(
                borderRadius: BorderRadius.all( Radius.circular(10)),
                child: Stack(
                  children: [
                    Container(
                      width: w*0.45,
                      height: h*0.32,
                      child: CachedNetworkImage(
                        fit: BoxFit.cover,
                        imageUrl: '${user.imageUrl!}',
                        progressIndicatorBuilder:
                            (context, url, downloadProgress) =>
                                //  LinearProgressIndicator(),

                                Skeletonizer(
                                    child: SizedBox(
                                        width: w*0.45,
                                        height: h*0.32,
                                        child: ClipRRect(
                                            borderRadius: BorderRadius.all(
                                                Radius.circular(10)),
                                            child: Image.asset(
                                                'assets/images/404.png',fit: BoxFit.cover,)))),
                        errorWidget: (context, url, error) => Container(
                            width: w*0.45,
                            height: h*0.32,
                            child: Image.asset(
                              "assets/icon/user-removebg-preview.png",
                              fit: BoxFit.cover,
                            )),
                      ),
                    ),
                    Positioned(
                      bottom: 0.0,
                      left: 0.0,
                      right: 0.0,
                      child: Stack(
                        children: [
                          Container(
                            height: 100,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  // ConstColors.buttonColors,
                                  Colors.green.shade300,

                                  // ConstColors.secondaryColor,

                                  Color.fromARGB(0, 0, 0, 0)
                                ],
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                              ),
                            ),
                            padding: EdgeInsets.symmetric(
                                vertical: 10.0, horizontal: 20.0),
                          ),
                          Positioned(
                            bottom: 0.0,
                            left: 0.0,
                            // right: 0.0,
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: SizedBox(
                                //width: 70,
                                child: Container(
                                  alignment: Alignment.center,
                                  child: TextCustomerPostDescription(
                                    titre: "@${user.pseudo}",
                                    fontSize: 17,
                                    couleur: Colors.white,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _buttonEnabled = true;

  bool is_actualised = false;

  Widget homePostUsersSkele(double height, double width) {
    double h = MediaQuery.of(context).size.height;
    double w = MediaQuery.of(context).size.width;

    return Skeletonizer(
      child: StatefulBuilder(
          builder: (BuildContext context, StateSetter setStateImages) {
        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (PointerDownEvent details) {},
          child: Padding(
            padding: const EdgeInsets.all(5.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Row(
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: CircleAvatar(
                                backgroundImage:
                                    AssetImage('assets/images/404.png'),
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
                                        titre: "#afrolook",
                                        fontSize: SizeText.homeProfileTextSize,
                                        couleur: ConstColors.textColors,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(
                                      //width: 100,
                                      child: TextCustomerUserTitle(
                                        titre: "&afrolook",
                                        fontSize: SizeText.homeProfileTextSize,
                                        couleur: ConstColors.textColors,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                    TextCustomerUserTitle(
                                      titre: "0suivi(s)",
                                      fontSize: 10,
                                      couleur: ConstColors.textColors,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ],
                                ),

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
                        SizedBox(
                          width: 20,
                        ),
                        Icon(
                          Entypo.arrow_long_right,
                          color: Colors.green,
                        ),
                        SizedBox(
                          width: 20,
                        ),
                        Row(
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: CircleAvatar(
                                backgroundImage:
                                    AssetImage('assets/images/404.png'),
                              ),
                            ),
                            SizedBox(
                              height: 2,
                            ),
                            Row(
                              children: [
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      //width: 100,
                                      child: TextCustomerUserTitle(
                                        titre: "@afrolook",
                                        fontSize: SizeText.homeProfileTextSize,
                                        couleur: ConstColors.textColors,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    TextCustomerUserTitle(
                                      titre: "0 abonné(s)",
                                      fontSize: 10,
                                      couleur: ConstColors.textColors,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ],
                                ),

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
                      ],
                    ),
                    IconButton(
                        onPressed: () {
                          // _showModalDialog(post);
                        },
                        icon: Icon(
                          Icons.more_horiz,
                          size: 30,
                          color: ConstColors.blackIconColors,
                        )),
                  ],
                ),
                SizedBox(
                  height: 5,
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      Icon(
                        Entypo.network,
                        size: 15,
                      ),
                      SizedBox(
                        width: 10,
                      ),
                      TextCustomerUserTitle(
                        titre: "publicité",
                        fontSize: SizeText.homeProfileTextSize,
                        couleur: Colors.green,
                        fontWeight: FontWeight.w400,
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 5,
                ),
                Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: width * 0.8,
                    height: 50,
                    child: Container(
                      alignment: Alignment.centerLeft,
                      child: TextCustomerPostDescription(
                        titre: "afrolook",
                        fontSize: SizeText.homeProfileTextSize,
                        couleur: ConstColors.textColors,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  height: 5,
                ),
                Align(
                  alignment: Alignment.topLeft,
                  child: TextCustomerPostDescription(
                    titre: "afrolook",
                    fontSize: SizeText.homeProfileDateTextSize,
                    couleur: ConstColors.textColors,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(
                  height: 5,
                ),
                GestureDetector(
                  onTap: () {
                    //Navigator.push(context, MaterialPageRoute(builder: (context) => DetailsPost(post: post),));
                  },
                  child: Container(
                    //width: w*0.9,
                    // height: h*0.5,

                    child: ClipRRect(
                      borderRadius: BorderRadius.all(Radius.circular(5)),
                      child: Container(
                        child: Image.asset('assets/images/404.png'),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  height: 10,
                ),
                SizedBox(
                  height: 10,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                        onPressed: () {},
                        child: contact_afrolook
                            ? Center(
                                child: LoadingAnimationWidget.flickr(
                                  size: 30,
                                  leftDotColor: Colors.green,
                                  rightDotColor: Colors.black,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    AntDesign.message1,
                                    color: Colors.black,
                                  ),
                                  SizedBox(
                                    width: 5,
                                  ),
                                  Text(
                                    "Afrolook",
                                    style: TextStyle(
                                        color: Colors.black,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ],
                              )),
                    ElevatedButton(
                        onPressed: () {},
                        child: contact_whatsapp
                            ? Center(
                                child: LoadingAnimationWidget.flickr(
                                  size: 30,
                                  leftDotColor: Colors.green,
                                  rightDotColor: Colors.black,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Fontisto.whatsapp,
                                    color: Colors.green,
                                  ),
                                  SizedBox(
                                    width: 5,
                                  ),
                                  Text(
                                    "WhatsApp",
                                    style: TextStyle(
                                        color: Colors.green,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ],
                              )),
                  ],
                ),
                SizedBox(
                  height: 10,
                ),
                Divider(
                  height: 3,
                )
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget homePostUsers(Post post, double height, double width) {
    double h = MediaQuery.of(context).size.height;
    double w = MediaQuery.of(context).size.width;

    Random random = Random();
    bool abonneTap = false;
    int like = post!.likes!;
    int imageIndex = 0;
    int love = post!.loves!;
    int vue = post!.vues!;
    int comments = post!.comments!;
    bool tapLove = isIn(post.users_love_id!, authProvider.loginUserData.id!);
    bool tapLike = isIn(post.users_like_id!, authProvider.loginUserData.id!);
    List<int> likes = [];
    List<int> loves = [];
    int idUser = 7;
    Color _color = _randomColor.randomColor(
        colorHue: ColorHue.multiple(colorHues: [
      ColorHue.red,
      ColorHue.blue,
      ColorHue.green,
      ColorHue.orange,
      ColorHue.yellow,
      ColorHue.purple
    ]));

    int limitePosts = 30;

    AnimationController _controller = AnimationController(
      duration: Duration(seconds: 1),
      vsync: this,
    );

    Animation<double> _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(_controller);

    return Container(
      child: post.type == PostType.PUB.name
          ? StatefulBuilder(
              builder: (BuildContext context, StateSetter setStateImages) {
              return Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (PointerDownEvent details) {
                  bool isReady = true;
                  if (_buttonEnabled) {
                    _buttonEnabled = false;
                    Future.delayed(Duration(seconds: 5), () {
                      printVm('Contact léger détecté !');
                      if (post.type == PostType.PUB.name) {
                        if (!isIn(post.users_vue_id!,
                            authProvider.loginUserData.id!)) {
                        } else {
                          post.users_vue_id!
                              .add(authProvider!.loginUserData.id!);
                        }

                        post.vues = post.vues! + 1;
                        vue = post.vues!;

                        postProvider.updateVuePost(post, context);
                        //loves.add(idUser);

                        // }
                      }
                      _buttonEnabled = true;
                    });
                  } else {
                    printVm('indispo!');
                  }

                  //  if (isReady) {
                },
                child: Padding(
                  padding: const EdgeInsets.all(5.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Row(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(right: 8.0),
                                    child: CircleAvatar(
                                      backgroundImage: NetworkImage(
                                          '${post.entrepriseData!.urlImage!}'),
                                    ),
                                  ),
                                  SizedBox(
                                    height: 2,
                                  ),
                                  Row(
                                    children: [
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          SizedBox(
                                            //width: 100,
                                            child: TextCustomerUserTitle(
                                              titre:
                                                  "#${post.entrepriseData!.titre!}",
                                              fontSize:
                                                  SizeText.homeProfileTextSize,
                                              couleur: ConstColors.textColors,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          SizedBox(
                                            //width: 100,
                                            child: TextCustomerUserTitle(
                                              titre:
                                                  "&${post.entrepriseData!.type!}",
                                              fontSize:
                                                  SizeText.homeProfileTextSize,
                                              couleur: ConstColors.textColors,
                                              fontWeight: FontWeight.w400,
                                            ),
                                          ),
                                          TextCustomerUserTitle(
                                            titre:
                                                "${formatNumber(post.entrepriseData!.suivi!)} suivi(s)",
                                            fontSize: 10,
                                            couleur: ConstColors.textColors,
                                            fontWeight: FontWeight.w400,
                                          ),
                                        ],
                                      ),

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
                              SizedBox(
                                width: 20,
                              ),
                              Icon(
                                Entypo.arrow_long_right,
                                color: Colors.green,
                              ),
                              SizedBox(
                                width: 20,
                              ),
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
                                        mainAxisAlignment:
                                            MainAxisAlignment.start,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          SizedBox(
                                            //width: 100,
                                            child: TextCustomerUserTitle(
                                              titre: "@${post.user!.pseudo!}",
                                              fontSize:
                                                  SizeText.homeProfileTextSize,
                                              couleur: ConstColors.textColors,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          TextCustomerUserTitle(
                                            titre:
                                                "${formatNumber(post.user!.abonnes!)} abonné(s)",
                                            fontSize: 10,
                                            couleur: ConstColors.textColors,
                                            fontWeight: FontWeight.w400,
                                          ),
                                        ],
                                      ),

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
                            ],
                          ),
                          IconButton(
                              onPressed: () {
                                _showPostMenuModalDialog(post);
                              },
                              icon: Icon(
                                Icons.more_horiz,
                                size: 30,
                                color: ConstColors.blackIconColors,
                              )),
                        ],
                      ),
                      SizedBox(
                        height: 5,
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          children: [
                            Icon(
                              Entypo.network,
                              size: 15,
                            ),
                            SizedBox(
                              width: 10,
                            ),
                            TextCustomerUserTitle(
                              titre: "publicité",
                              fontSize: SizeText.homeProfileTextSize,
                              couleur: Colors.green,
                              fontWeight: FontWeight.w400,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        height: 5,
                      ),
                      Align(
                        alignment: Alignment.topLeft,
                        child: SizedBox(
                          width: width * 0.8,
                          height: 50,
                          child: Container(
                            alignment: Alignment.centerLeft,
                            child: TextCustomerPostDescription(
                              titre: "${post.description}",
                              fontSize: SizeText.homeProfileTextSize,
                              couleur: ConstColors.textColors,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 5,
                      ),
                      Align(
                        alignment: Alignment.topLeft,
                        child: TextCustomerPostDescription(
                          titre:
                              "${formaterDateTime(DateTime.fromMicrosecondsSinceEpoch(post.createdAt!))}",
                          fontSize: SizeText.homeProfileDateTextSize,
                          couleur: ConstColors.textColors,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(
                        height: 5,
                      ),
                      /*
                    post!.images==null? Container():  Padding(
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

                            }, child:
                            Container(
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

                     */
                      GestureDetector(
                        onTap: () {
                          postProvider.updateVuePost(post, context);

                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => DetailsPost(post: post),
                              ));
                        },
                        child: Container(
                          width: w * 0.9,
                          height: h * 0.4,
                          child: ClipRRect(
                            borderRadius: BorderRadius.all(Radius.circular(5)),
                            child: Container(
                              child: CachedNetworkImage(
                                fit: BoxFit.cover,
                                imageUrl:
                                    '${post!.images == null ? '' : post!.images!.isEmpty ? '' : post!.images![imageIndex]}',
                                progressIndicatorBuilder: (context, url,
                                        downloadProgress) =>
                                    //  LinearProgressIndicator(),

                                    Skeletonizer(
                                        child: SizedBox(
                                            width: 400,
                                            height: 450,
                                            child: ClipRRect(
                                                borderRadius: BorderRadius.all(
                                                    Radius.circular(10)),
                                                child: Image.asset(
                                                    'assets/images/404.png')))),
                                errorWidget: (context, url, error) =>
                                    Skeletonizer(
                                        child: Container(
                                            width: 400,
                                            height: 450,
                                            child: Image.asset(
                                              "assets/images/404.png",
                                              fit: BoxFit.cover,
                                            ))),
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

                                      love = post.loves!;
                                      post.users_love_id!
                                          .add(authProvider!.loginUserData.id!);

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
                                              "📢 @${authProvider.loginUserData.pseudo!} a aimé ❤️ votre look",
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
                                          "@${authProvider.loginUserData.pseudo!} a aimé ❤️ votre look";
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

                                    if (listUsers.isNotEmpty) {
                                      SnackBar snackBar = SnackBar(
                                        content: Text(
                                          '+2 points.  Voir le classement',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(color: Colors.green),
                                        ),
                                      );
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(snackBar);

                                      listUsers.first!.jaimes =
                                          listUsers.first!.jaimes! + 1;
                                      postProvider.updatePost(
                                          post, listUsers.first!!, context);
                                      await authProvider.getAppData();
                                      authProvider.appDefaultData.nbr_loves =
                                          authProvider
                                                  .appDefaultData.nbr_loves! +
                                              2;
                                      await authProvider.updateAppData(
                                          authProvider.appDefaultData);
                                    } else {
                                      SnackBar snackBar = SnackBar(
                                        content: Text(
                                          '+2 points.  Voir le classement',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(color: Colors.green),
                                        ),
                                      );
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(snackBar);
                                      post.user!.jaimes =
                                          post.user!.jaimes! + 1;
                                      postProvider.updatePost(
                                          post, post.user!, context);
                                      await authProvider.getAppData();
                                      authProvider.appDefaultData.nbr_loves =
                                          authProvider
                                                  .appDefaultData.nbr_loves! +
                                              2;
                                      await authProvider.updateAppData(
                                          authProvider.appDefaultData);
                                    }
                                  }
                                },
                                child: Container(
                                  //height: 20,
                                  width: 70,
                                  height: 30,
                                  child: Row(
                                    children: [
                                      Icon(
                                        isIn(post.users_love_id!,
                                                authProvider.loginUserData.id!)
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
                                          fontSize:
                                              SizeText.homeProfileDateTextSize,
                                          couleur: ConstColors.textColors,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                            StatefulBuilder(builder:
                                (BuildContext context, StateSetter setState) {
                              return GestureDetector(
                                onTap: () async {
                                  if (!isIn(post.users_like_id!,
                                      authProvider.loginUserData.id!)) {
                                    setState(() {
                                      post.likes = post.likes! + 1;

                                      like = post.likes!;
                                      post.users_like_id!
                                          .add(authProvider!.loginUserData.id!);

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
                                              "📢 @${authProvider.loginUserData.pseudo!} a liké votre look",
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
                                      notif.titre = "Nouveau like 👍🏾";
                                      notif.media_url =
                                          authProvider.loginUserData.imageUrl;
                                      notif.type = NotificationType.POST.name;
                                      notif.description =
                                          "@${authProvider.loginUserData.pseudo!} a liké votre look";
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
                                    if (listUsers.isNotEmpty) {
                                      SnackBar snackBar = SnackBar(
                                        content: Text(
                                          '+1 point. Voir le classement',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(color: Colors.green),
                                        ),
                                      );
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(snackBar);

                                      listUsers.first!.likes =
                                          listUsers.first!.likes! + 1;
                                      postProvider.updatePost(
                                          post, listUsers.first!!, context);
                                      await authProvider.getAppData();
                                      authProvider.appDefaultData.nbr_likes =
                                          authProvider
                                                  .appDefaultData.nbr_likes! +
                                              1;
                                      authProvider.updateAppData(
                                          authProvider.appDefaultData);
                                    } else {
                                      SnackBar snackBar = SnackBar(
                                        content: Text(
                                          '+1 point. Voir le classement',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(color: Colors.green),
                                        ),
                                      );
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(snackBar);
                                      post.user!.likes = post.user!.likes! + 1;
                                      postProvider.updatePost(
                                          post, post.user!, context);
                                      await authProvider.getAppData();
                                      authProvider.appDefaultData.nbr_likes =
                                          authProvider
                                                  .appDefaultData.nbr_likes! +
                                              1;
                                      authProvider.updateAppData(
                                          authProvider.appDefaultData);
                                    }
                                  }
                                },
                                child: Container(
                                  width: 70,
                                  height: 30,
                                  child: Row(
                                    children: [
                                      Icon(
                                        isIn(post.users_like_id!,
                                                authProvider.loginUserData.id!)
                                            ? MaterialCommunityIcons.thumb_up
                                            : MaterialCommunityIcons
                                                .thumb_up_outline,
                                        size: 20,
                                        color: isIn(post.users_like_id!,
                                                authProvider.loginUserData.id!)
                                            ? Colors.blue
                                            : Colors.black,
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.only(
                                            left: 1.0, right: 1),
                                        child: TextCustomerPostDescription(
                                          titre: "${formatAbonnes(like)}",
                                          fontSize:
                                              SizeText.homeProfileDateTextSize,
                                          couleur: ConstColors.textColors,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                            StatefulBuilder(builder:
                                (BuildContext context, StateSetter setState) {
                              return GestureDetector(
                                onTap: () async {
                                  Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            PostComments(post: post),
                                      ));

                                  //sheetComments(height*0.7,width,post);
                                  /*
                                    postProvider.listConstpostsComment=[];
                                   await postProvider.getPostCommentsNoStream(post).then((value) {
                                     Navigator.push(context, MaterialPageRoute(builder: (context) => PostComments(post: post),));

                                   },);

                                     */
                                },
                                child: Container(
                                  width: 70,
                                  height: 30,
                                  child: Row(
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
                                          fontSize:
                                              SizeText.homeProfileDateTextSize,
                                          couleur: ConstColors.textColors,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                            StatefulBuilder(builder:
                                (BuildContext context, StateSetter setState) {
                              return GestureDetector(
                                onTap: () {},
                                child: Container(
                                  width: 70,
                                  height: 30,
                                  child: Row(
                                    children: [
                                      Icon(
                                        FontAwesome.eye,
                                        size: 20,
                                        color: Colors.black,
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.only(
                                            left: 1.0, right: 1),
                                        child: TextCustomerPostDescription(
                                          titre: "${vue}",
                                          fontSize:
                                              SizeText.homeProfileDateTextSize,
                                          couleur: ConstColors.textColors,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton(
                              onPressed: contact_afrolook
                                  ? () {}
                                  : () async {
                                      setState(() {
                                        contact_afrolook = true;
                                      });
                                      await getChatsEntrepriseData(post.user!,
                                              post, post.entrepriseData!)
                                          .then(
                                        (chat) async {
                                          userProvider.chat.messages =
                                              chat.messages;

                                          Navigator.push(
                                              context,
                                              PageTransition(
                                                  type: PageTransitionType.fade,
                                                  child: EntrepriseMyChat(
                                                    title: 'mon chat',
                                                    chat: chat,
                                                    post: post,
                                                    isEntreprise: false,
                                                  )));

                                          setState(() {
                                            contact_afrolook = false;
                                          });
                                        },
                                      );
                                    },
                              child: contact_afrolook
                                  ? Center(
                                      child: LoadingAnimationWidget.flickr(
                                        size: 30,
                                        leftDotColor: Colors.green,
                                        rightDotColor: Colors.black,
                                      ),
                                    )
                                  : Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          AntDesign.message1,
                                          color: Colors.black,
                                        ),
                                        SizedBox(
                                          width: 5,
                                        ),
                                        Text(
                                          "Afrolook",
                                          style: TextStyle(
                                              color: Colors.black,
                                              fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    )),
                          ElevatedButton(
                              onPressed: contact_whatsapp
                                  ? () {}
                                  : () {
                                      launchWhatsApp(
                                          "${post.contact_whatsapp}");
                                      setState(() {
                                        contact_whatsapp = false;
                                      });
                                    },
                              child: contact_whatsapp
                                  ? Center(
                                      child: LoadingAnimationWidget.flickr(
                                        size: 30,
                                        leftDotColor: Colors.green,
                                        rightDotColor: Colors.black,
                                      ),
                                    )
                                  : Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Fontisto.whatsapp,
                                          color: Colors.green,
                                        ),
                                        SizedBox(
                                          width: 5,
                                        ),
                                        Text(
                                          "WhatsApp",
                                          style: TextStyle(
                                              color: Colors.green,
                                              fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    )),
                        ],
                      ),
                      SizedBox(
                        height: 10,
                      ),
                      Divider(
                        height: 3,
                      )
                    ],
                  ),
                ),
              );
            })
          : StatefulBuilder(
              builder: (BuildContext context, StateSetter setStateImages) {
              return Padding(
                padding: const EdgeInsets.all(5.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => OtherUserPage(otherUser: post.user!),
                                      ));
                                },
                                child:
                                  CircleAvatar(
                                  
                                  backgroundImage:
                                      NetworkImage('${post.user!.imageUrl!}'),
                                ),
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
                                      titre:
                                          "${formatNumber(post.user!.abonnes!)} abonné(s)",
                                      fontSize: SizeText.homeProfileTextSize,
                                      couleur: ConstColors.textColors,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ],
                                ),
                                Visibility(
                                    visible:authProvider.loginUserData.id!=post.user!.id ,

                                  child: StatefulBuilder(builder: (BuildContext context,
                                      void Function(void Function()) setState) {
                                    return Container(
                                      child: isUserAbonne(
                                              post.user!.userAbonnesIds!,
                                              authProvider.loginUserData.id!)
                                          ? Container()
                                          : TextButton(
                                              onPressed: abonneTap
                                                  ? () {}
                                                  : () async {
                                                      if (!isUserAbonne(
                                                          post.user!
                                                              .userAbonnesIds!,
                                                          authProvider
                                                              .loginUserData
                                                              .id!))
                                                      {
                                                        setState(() {
                                                          abonneTap = true;
                                                        });
                                                        UserAbonnes userAbonne =
                                                            UserAbonnes();
                                                        userAbonne.compteUserId =
                                                            authProvider
                                                                .loginUserData.id;
                                                        userAbonne.abonneUserId =
                                                            post.user!.id;

                                                        userAbonne
                                                            .createdAt = DateTime
                                                                .now()
                                                            .millisecondsSinceEpoch;
                                                        userAbonne
                                                            .updatedAt = DateTime
                                                                .now()
                                                            .millisecondsSinceEpoch;
                                                        await userProvider
                                                            .sendAbonnementRequest(
                                                                userAbonne,
                                                                post.user!,
                                                                context)
                                                            .then(
                                                          (value) async {
                                                            if (value) {
                                                              authProvider
                                                                  .loginUserData
                                                                  .userAbonnes!
                                                                  .add(
                                                                      userAbonne);
                                                              // await userProvider.getUsers(authProvider.loginUserData!.id!);
                                                              await authProvider
                                                                  .getCurrentUser(
                                                                      authProvider
                                                                          .loginUserData!
                                                                          .id!);
                                                              post.user!
                                                                  .userAbonnesIds!
                                                                  .add(authProvider
                                                                      .loginUserData
                                                                      .id!);
                                                              userProvider
                                                                  .updateUser(
                                                                      post.user!);
                                                              if (post.user!
                                                                          .oneIgnalUserid !=
                                                                      null &&
                                                                  post
                                                                          .user!
                                                                          .oneIgnalUserid!
                                                                          .length >
                                                                      5) {
                                                                await authProvider.sendNotification(
                                                                    userIds: [
                                                                      post.user!
                                                                          .oneIgnalUserid!
                                                                    ],
                                                                    smallImage:
                                                                        "${authProvider.loginUserData.imageUrl!}",
                                                                    send_user_id:
                                                                        "${authProvider.loginUserData.id!}",
                                                                    recever_user_id:
                                                                        "${post.user!.id!}",
                                                                    message:
                                                                        "📢 @${authProvider.loginUserData.pseudo!} s'est abonné(e) à votre compte",
                                                                    type_notif:
                                                                        NotificationType
                                                                            .ABONNER
                                                                            .name,
                                                                    post_id:
                                                                        "${post!.id!}",
                                                                    post_type:
                                                                        PostDataType
                                                                            .IMAGE
                                                                            .name,
                                                                    chat_id: '');
                                                                NotificationData
                                                                    notif =
                                                                    NotificationData();
                                                                notif.id = firestore
                                                                    .collection(
                                                                        'Notifications')
                                                                    .doc()
                                                                    .id;
                                                                notif.titre =
                                                                    "Nouveau Abonnement ✅";
                                                                notif.media_url =
                                                                    authProvider
                                                                        .loginUserData
                                                                        .imageUrl;
                                                                notif.type =
                                                                    NotificationType
                                                                        .ABONNER
                                                                        .name;
                                                                notif.description =
                                                                    "@${authProvider.loginUserData.pseudo!} s'est abonné(e) à votre compte";
                                                                notif.users_id_view =
                                                                    [];
                                                                notif.user_id =
                                                                    authProvider
                                                                        .loginUserData
                                                                        .id;
                                                                notif.receiver_id =
                                                                    post.user!
                                                                        .id!;
                                                                notif.post_id =
                                                                    post.id!;
                                                                notif.post_data_type =
                                                                    PostDataType
                                                                        .IMAGE
                                                                        .name!;
                                                                notif.updatedAt =
                                                                    DateTime.now()
                                                                        .microsecondsSinceEpoch;
                                                                notif.createdAt =
                                                                    DateTime.now()
                                                                        .microsecondsSinceEpoch;
                                                                notif.status =
                                                                    PostStatus
                                                                        .VALIDE
                                                                        .name;

                                                                // users.add(pseudo.toJson());

                                                                await firestore
                                                                    .collection(
                                                                        'Notifications')
                                                                    .doc(notif.id)
                                                                    .set(notif
                                                                        .toJson());
                                                              }
                                                              SnackBar snackBar =
                                                                  SnackBar(
                                                                content: Text(
                                                                  'abonné, Bravo ! Vous avez gagné 4 points.',
                                                                  textAlign:
                                                                      TextAlign
                                                                          .center,
                                                                  style: TextStyle(
                                                                      color: Colors
                                                                          .green),
                                                                ),
                                                              );
                                                              ScaffoldMessenger
                                                                      .of(context)
                                                                  .showSnackBar(
                                                                      snackBar);
                                                              setState(() {
                                                                abonneTap = false;
                                                              });
                                                            } else {
                                                              SnackBar snackBar =
                                                                  SnackBar(
                                                                content: Text(
                                                                  'une erreur',
                                                                  textAlign:
                                                                      TextAlign
                                                                          .center,
                                                                  style: TextStyle(
                                                                      color: Colors
                                                                          .red),
                                                                ),
                                                              );
                                                              ScaffoldMessenger
                                                                      .of(context)
                                                                  .showSnackBar(
                                                                      snackBar);
                                                              setState(() {
                                                                abonneTap = false;
                                                              });
                                                            }
                                                          },
                                                        );

                                                        setState(() {
                                                          abonneTap = false;
                                                        });
                                                      }
                                                    },
                                              child: abonneTap
                                                  ? Center(
                                                      child:
                                                          LoadingAnimationWidget
                                                              .flickr(
                                                        size: 20,
                                                        leftDotColor:
                                                            Colors.green,
                                                        rightDotColor:
                                                            Colors.black,
                                                      ),
                                                    )
                                                  : Text(
                                                      "S'abonner",
                                                      style: TextStyle(
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.normal,
                                                          color: Colors.blue),
                                                    )),
                                    );
                                  }),
                                ),
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
                        IconButton(
                            onPressed: () {
                              _showPostMenuModalDialog(post);
                            },
                            icon: Icon(
                              Icons.more_horiz,
                              size: 30,
                              color: ConstColors.blackIconColors,
                            )),
                      ],
                    ),
                    SizedBox(
                      height: 5,
                    ),
                    Visibility(
                      visible: post.dataType != PostDataType.TEXT.name
                          ? true
                          : false,
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: SizedBox(
                          width: width * 0.8,
                          height: 50,
                          child: Container(
                            alignment: Alignment.centerLeft,
                            child: TextCustomerPostDescription(
                              titre: "${post.description}",
                              fontSize: SizeText.homeProfileTextSize,
                              couleur: ConstColors.textColors,
                              fontWeight: FontWeight.normal,
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
                          titre:
                              "${formaterDateTime(DateTime.fromMicrosecondsSinceEpoch(post.createdAt!))}",
                          fontSize: SizeText.homeProfileDateTextSize,
                          couleur: ConstColors.textColors,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Visibility(
                      visible: post.dataType == PostDataType.TEXT.name
                          ? true
                          : false,
                      child: Container(
                        color: _color,
                        child: Align(
                          alignment: Alignment.center,
                          child: SizedBox(
                            width: width * 0.8,
                            height: height * 0.5,
                            child: Container(
                              // height: 200,
                              constraints: BoxConstraints(
                                // minHeight: 100.0, // Set your minimum height
                                maxHeight:
                                    height * 0.6, // Set your maximum height
                              ),
                              alignment: Alignment.centerLeft,
                              child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    "${post.description}",
                                    textAlign: TextAlign
                                        .center, //overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: post.description!.length < 350
                                          ? 25
                                          : 16,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      //fontStyle: FontStyle.italic
                                    ),
                                  )),
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
                      visible: post.dataType != PostDataType.TEXT.name
                          ? true
                          : false,
                      child: GestureDetector(
                        onTap: () {
                          // postProvider.updateVuePost(post, context);

                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => DetailsPost(post: post),
                              ));
                        },
                        child: Container(
                          child: ClipRRect(
                            borderRadius: BorderRadius.all(Radius.circular(5)),
                            child: Container(
                              child: ImageSlideshow(

                                width: w * 0.9,
                                height: h * 0.4,

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
                              autoPlayInterval: 12000,

                              /// Loops back to first slide.
                              isLoop: false,

                              /// The widgets to display in the [ImageSlideshow].
                              /// Add the sample image file into the images folder
                              children: post!.images!.map((e) =>   CachedNetworkImage(

                                fit: BoxFit.cover,
                                imageUrl:
                                '${e}',
                                progressIndicatorBuilder: (context, url,
                                    downloadProgress) =>
                                //  LinearProgressIndicator(),

                                Skeletonizer(
                                    child: SizedBox(
                                        // width: w * 0.9,
                                        // height: h * 0.4,
                                        child: ClipRRect(
                                            borderRadius: BorderRadius.all(
                                                Radius.circular(10)),
                                            child: Image.asset(
                                                'assets/images/404.png')))),
                                errorWidget: (context, url, error) =>
                                    Skeletonizer(
                                        child: Container(
                                            // width: w * 0.9,
                                            // height: h * 0.4,
                                            child: Image.asset(
                                              "assets/images/404.png",
                                              fit: BoxFit.cover,
                                            ))),
                              )).toList(),
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
            }),
    );
  }

  Widget menu(BuildContext context) {
    bool onTap = false;

    return RefreshIndicator(
      onRefresh: () async {
        await authProvider.getCurrentUser(authProvider.loginUserData!.id!);
      },
      child: Drawer(
        width: MediaQuery.of(context).size.width * 0.9,
        child: Column(
          //padding: EdgeInsets.zero,
          children: <Widget>[
            DrawerHeader(
              decoration: BoxDecoration(
                color: ConstColors.menuHeaderColors,
              ),
              child: ListView(
                // mainAxisAlignment: MainAxisAlignment.center,
                // crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      child: Logo(),
                      height: 50,
                      width: 150,
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: CircleAvatar(
                              backgroundImage: NetworkImage(
                                  '${authProvider.loginUserData.imageUrl!}'),
                              onBackgroundImageError: (exception, stackTrace) =>
                                  AssetImage(
                                      "assets/icon/user-removebg-preview.png"),
                            ),
                          ),
                          SizedBox(
                            height: 2,
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                //width: 100,
                                child: TextCustomerUserTitle(
                                  titre:
                                      "@${authProvider.loginUserData.pseudo}",
                                  fontSize: SizeText.homeProfileTextSize,
                                  couleur: ConstColors.textColors,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              TextCustomerUserTitle(
                                titre:
                                    "${formatNumber(authProvider.loginUserData.abonnes!)} abonné(s)",
                                fontSize: SizeText.homeProfileTextSize,
                                couleur: ConstColors.textColors,
                                fontWeight: FontWeight.w400,
                              ),
                            ],
                          ),
                        ],
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Row(
                          children: [
                            TextCustomerUserTitle(
                              titre: "".toUpperCase(),
                              fontSize: SizeText.homeProfileTextSize,
                              couleur: ConstColors.textColors,
                              fontWeight: FontWeight.w400,
                            ),
                            /*
                            IconButton(
                                onPressed: () {},
                                icon: Icon(
                                  Icons.monetization_on,
                                  size: 20,
                                  color: Colors.red,
                                )),

                             */
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  ListTile(
                    trailing:
                        Icon(Icons.arrow_right_outlined, color: Colors.green),
                    leading: Image.asset(
                      'assets/menu/1.png',
                      height: 20,
                      width: 20,
                    ),
                    title: TextCustomerMenu(
                      titre: "Profile",
                      fontSize: SizeText.homeProfileTextSize,
                      couleur: ConstColors.textColors,
                      fontWeight: FontWeight.w600,
                    ),
                    onTap: () {
                      // Add your navigation logic here
                      Navigator.pushNamed(context, '/home_profile_user');
                    },
                  ),
                  ListTile(
                    trailing:
                        Icon(Icons.arrow_right_outlined, color: Colors.green),
                    leading: Image.asset(
                      'assets/menu/3.png',
                      height: 20,
                      width: 20,
                    ),
                    title: TextCustomerMenu(
                      titre: "Amis",
                      fontSize: SizeText.homeProfileTextSize,
                      couleur: ConstColors.textColors,
                      fontWeight: FontWeight.w600,
                    ),
                    onTap: () {
                      // Add your navigation logic here
                      Navigator.pushNamed(context, '/amis');
                    },
                  ),
                  /*
                  ListTile(
                    trailing: Icon(
                      Icons.lock,
                      color: Colors.red,
                      size: 15,
                    ),
                    leading: Image.asset(
                      'assets/menu/2.png',
                      height: 20,
                      width: 20,
                    ),
                    title: TextCustomerMenu(
                      titre: "Postes Entreprises",
                      fontSize: SizeText.homeProfileTextSize,
                      couleur: ConstColors.textColors,
                      fontWeight: FontWeight.w600,
                    ),
                    onTap: () {
                      // Add your navigation logic here
                      Navigator.pop(context);
                    },
                  ),




                   */
                  // ListTile(
                  //   trailing: Icon(Icons.arrow_right_outlined, color: Colors.green),
                  //   leading: Icon(Icons.storefront_outlined, color: Colors.green),
                  //   title: TextCustomerMenu(
                  //     titre: "Afroshop MarketPlace",
                  //     fontSize: SizeText.homeProfileTextSize,
                  //     couleur: ConstColors.textColors,
                  //     fontWeight: FontWeight.w600,
                  //   ),
                  //   onTap: () async {
                  //
                  //
                  //     Navigator.push(context, MaterialPageRoute(builder: (context) => HomeAfroshopPage(title: ''),));
                  //   },
                  // ),

                  ListTile(
                    trailing: TextCustomerMenu(
                      titre: "Discuter",
                      fontSize: SizeText.homeProfileTextSize,
                      couleur: Colors.blue,
                      fontWeight: FontWeight.w600,
                    ),
                    leading: Image.asset(
                      'assets/menu/8.png',
                      height: 20,
                      width: 20,
                    ),
                    title: TextCustomerMenu(
                      titre: "Xilo",
                      fontSize: SizeText.homeProfileTextSize,
                      couleur: ConstColors.textColors,
                      fontWeight: FontWeight.w600,
                    ),
                    subtitle: TextCustomerMenu(
                      titre: "Amis imaginaire",
                      fontSize: 9,
                      couleur: ConstColors.textColors,
                      fontWeight: FontWeight.w600,
                    ),
                    onTap: () async {
                      setState(() {
                        onTap = true;
                      });

                      await authProvider.getAppData().then(
                        (appdata) async {
                          // Navigator.push(context, MaterialPageRoute(builder: (context) => IntroIaCompagnon(instruction:authProvider.appDefaultData.ia_instruction! ,),));

                          await authProvider
                              .getUserIa(authProvider.loginUserData.id!)
                              .then(
                            (value) async {
                              if (value.isNotEmpty) {
                                await getIAChatsData(value.first).then((chat) {
                                  setState(() {
                                    onTap = false;
                                  });
                                  Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => IaChat(
                                          chat: chat,
                                          user: authProvider.loginUserData,
                                          userIACompte: value.first,
                                          instruction:
                                              '${authProvider.appDefaultData.ia_instruction!}',
                                        ),
                                      ));
                                });
                              } else {
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => IntroIaCompagnon(
                                        instruction: authProvider
                                            .appDefaultData.ia_instruction!,
                                      ),
                                    ));
                              }
                            },
                          );
                        },
                      );

                      // Navigator.pushNamed(context, '/intro_ia_compagnon');
                    },
                  ),

                  /*
                  ListTile(
                    trailing: TextCustomerMenu(
                      titre: "Tester",
                      fontSize: SizeText.homeProfileTextSize,
                      couleur: Colors.blue,
                      fontWeight: FontWeight.w600,
                    ),
                    leading: Image.asset(
                      'assets/menu/5.png',
                      height: 20,
                      width: 20,
                    ),
                    title: TextCustomerMenu(
                      titre: "IA Recherche Produits",
                      fontSize: SizeText.homeProfileTextSize,
                      couleur: ConstColors.textColors,
                      fontWeight: FontWeight.w600,
                    ),
                    subtitle: TextCustomerMenu(
                      titre: "10.3 m abonnés",
                      fontSize: 9,
                      couleur: ConstColors.textColors,
                      fontWeight: FontWeight.w600,
                    ),
                    onTap: () {
                      // Add your navigation logic here
                      Navigator.pop(context);
                    },
                  ),

                   */
                  ListTile(
                    trailing:
                        Icon(Icons.arrow_right_outlined, color: Colors.green),
                    leading: Image.asset(
                      'assets/images/trophee.png',
                      height: 20,
                      width: 20,
                    ),
                    title: TextCustomerMenu(
                      titre: "Classement",
                      fontSize: SizeText.homeProfileTextSize,
                      couleur: ConstColors.textColors,
                      fontWeight: FontWeight.w600,
                    ),
                    onTap: () async {
                      // Add your navigation logic here
                      await userProvider.getAllUsers().then(
                        (value) {
                          Navigator.pushNamed(context, '/classemnent');
                        },
                      );
                    },
                  ),
                  ListTile(
                    trailing:
                        Icon(Icons.arrow_right_outlined, color: Colors.green),
                    leading: Image.asset(
                      'assets/menu/6.png',
                      height: 20,
                      width: 20,
                    ),
                    title: TextCustomerMenu(
                      titre: "Gagner points Gratuitement",
                      fontSize: SizeText.homeProfileTextSize,
                      couleur: ConstColors.textColors,
                      fontWeight: FontWeight.w600,
                    ),
                    onTap: () async {
                      // Add your navigation logic here
                      await userProvider.getGratuitInfos().then(
                        (value) {
                          Navigator.pushNamed(context, '/gagner_point_infos');
                        },
                      );
                    },
                  ),
                  ListTile(
                    trailing:
                        Icon(Icons.arrow_right_outlined, color: Colors.green),
                    leading: Image.asset(
                      'assets/menu/7.png',
                      height: 20,
                      width: 20,
                    ),
                    title: TextCustomerMenu(
                      titre: "Afrolook infos",
                      fontSize: SizeText.homeProfileTextSize,
                      couleur: ConstColors.textColors,
                      fontWeight: FontWeight.w600,
                    ),
                    onTap: () async {
                      // Add your navigation logic here
                      await userProvider.getAllInfos().then(
                        (value) {
                          Navigator.pushNamed(context, '/app_info');
                        },
                      );
                    },
                  ),
                  ListTile(
                    trailing:
                        Icon(Icons.arrow_right_outlined, color: Colors.green),
                    leading: Icon(Icons.contact_mail, color: Colors.green),
                    title: TextCustomerMenu(
                      titre: "Nos Contactes",
                      fontSize: SizeText.homeProfileTextSize,
                      couleur: ConstColors.textColors,
                      fontWeight: FontWeight.w600,
                    ),
                    onTap: () async {
                      // Add your navigation logic here
                      await userProvider.getAllInfos().then(
                        (value) {
                          Navigator.pushNamed(context, '/contact');
                        },
                      );
                    },
                  ),
                  ListTile(
                    trailing:
                        Icon(Icons.arrow_right_outlined, color: Colors.green),
                    leading:
                        Icon(MaterialIcons.smartphone, color: Colors.green),
                    title: TextCustomerMenu(
                      titre: "Partager l'application",
                      fontSize: SizeText.homeProfileTextSize,
                      couleur: ConstColors.textColors,
                      fontWeight: FontWeight.w600,
                    ),
                    onTap: () async {
                      // Add your navigation logic here
                      final box = context.findRenderObject() as RenderBox?;

                      await authProvider.getAppData().then(
                        (value) async {
                          await Share.shareUri(
                            Uri.parse(
                                '${authProvider.appDefaultData.app_link}'),
                            sharePositionOrigin:
                                box!.localToGlobal(Offset.zero) & box.size,
                          );

                          //   if (result.status == ShareResultStatus.success) {
                          //     printVm('Thank you for sharing my website!');
                          //   }
                          //   await FlutterShare.share(
                          //       title: 'Partager Afrolook',
                          //       linkUrl: '${authProvider.appDefaultData.app_link}',
                          //       chooserTitle: 'Partager Afrolook'
                          //   );
                        },
                      );
                    },
                  ),

                ],
              ),
            ),
            SizedBox(height: 5,),
            Text('Version: 1.0.8 (8)',style: TextStyle(fontWeight: FontWeight.bold),),
            Container(
                child: Align(
                    alignment: FractionalOffset.bottomCenter,
                    child: Column(
                      children: <Widget>[
                        Divider(),
                        ListTile(
                          leading: Icon(
                            Icons.exit_to_app,
                            color: ConstColors.regIconColors,
                          ),
                          title: TextCustomerMenu(
                            titre: "Déconnecter",
                            fontSize: 15,
                            couleur: ConstColors.regIconColors,
                            fontWeight: FontWeight.w600,
                          ),
                          onTap: () {
                            // Add your navigation logic here
                            authProvider.loginUserData!.isConnected = false;
                            userProvider.changeState(
                                user: authProvider.loginUserData,
                                state: UserState.OFFLINE.name);
                            authProvider.storeToken('').then(
                              (value) {
                                Navigator.pop(context);
                                Navigator.pushReplacementNamed(
                                    context, "/login");
                              },
                            );
                          },
                        ),
                      ],
                    ))),
          ],
        ),
      ),
    );
  }

  Widget widgetSeke(double width, double height) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(3.0),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            SizedBox(
              width: width,
              height: height * 0.79,
              child: ListView.builder(
                controller: _scrollController,
                scrollDirection: Axis.vertical,
                itemCount: 6,
                itemBuilder: (BuildContext context, int index) {
                  if (index == 0) {
                    return Column(
                      children: <Widget>[
                        SizedBox(
                          //width: width,
                          height: height * 0.33,
                          child: Skeletonizer(
                            //enabled: _loading,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: 4,
                              itemBuilder: (context, index) {
                                return Padding(
                                  padding: const EdgeInsets.all(1.0),
                                  child: Container(
                                    width: 300,
                                    child: Card(
                                      color: Colors.white,
                                      child: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Column(
                                          children: [
                                            Container(
                                              child: CircleAvatar(
                                                backgroundImage: AssetImage(
                                                  "assets/icon/user-removebg-preview.png",
                                                ),
                                              ),
                                              height: 100,
                                              width: 100,
                                            ),
                                            SizedBox(
                                              height: 2,
                                            ),
                                            SizedBox(
                                              width: 70,
                                              child: TextCustomerUserTitle(
                                                titre: "jhasgjh",
                                                fontSize: SizeText
                                                    .homeProfileTextSize,
                                                couleur: ConstColors.textColors,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            SizedBox(
                                              height: 2,
                                            ),
                                            TextCustomerUserTitle(
                                              titre: "S'abonner",
                                              fontSize:
                                                  SizeText.homeProfileTextSize,
                                              couleur: Colors.blue,
                                              fontWeight: FontWeight.w600,
                                            )
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        Divider(
                          height: 10,
                        ),
                      ],
                    );
                  }
                  if (index == 3) {
                    return Column(
                      children: <Widget>[
                        SizedBox(
                          //width: width,
                          height: height * 0.33,
                          child: Skeletonizer(
                            //enabled: _loading,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: 4,
                              itemBuilder: (context, index) {
                                return Padding(
                                  padding: const EdgeInsets.all(1.0),
                                  child: Container(
                                    width: 300,
                                    child: Card(
                                      color: Colors.white,
                                      child: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Column(
                                          children: [
                                            Container(
                                              child: CircleAvatar(
                                                backgroundImage: AssetImage(
                                                  "assets/icon/user-removebg-preview.png",
                                                ),
                                              ),
                                              height: 100,
                                              width: 100,
                                            ),
                                            SizedBox(
                                              height: 2,
                                            ),
                                            SizedBox(
                                              width: 70,
                                              child: TextCustomerUserTitle(
                                                titre: "jhasgjh",
                                                fontSize: SizeText
                                                    .homeProfileTextSize,
                                                couleur: ConstColors.textColors,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            SizedBox(
                                              height: 2,
                                            ),
                                            TextCustomerUserTitle(
                                              titre: "S'abonner",
                                              fontSize:
                                                  SizeText.homeProfileTextSize,
                                              couleur: Colors.blue,
                                              fontWeight: FontWeight.w600,
                                            )
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        Divider(
                          height: 10,
                        ),
                      ],
                    );
                  } else {
                    return Padding(
                      padding: const EdgeInsets.only(top: 5.0, bottom: 5),
                      child: homePostUsersSkele(height, width),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Stream<int> getNbrInvitation() async* {
    List<Invitation> invitations = [];
    var invitationsStream = FirebaseFirestore.instance
        .collection('Invitations')
        .where('receiver_id', isEqualTo: authProvider.loginUserData.id!)
        .where('status', isEqualTo: "${InvitationStatus.ENCOURS.name}")
        .snapshots();

    await for (var invitationsSnapshot in invitationsStream) {
      for (var invitationDoc in invitationsSnapshot.docs) {
        //userData=userList.first;

        Invitation invitation;

        invitation = Invitation.fromJson(invitationDoc.data());
        //  invitation.inviteUser=userList.first;
        invitations.add(invitation);

        userProvider.countInvitations = invitations.length;
      }
      yield invitations.length;
    }
  }

  Stream<int> getNbrMessageNonLu() async* {
// Obtenez la liste des utilisateurs
    //List<DocumentSnapshot> users = await usersQuery.sget();
    Chat usersChat = Chat();
    List<Chat> listChats = [];
    int nbr = 0;
    printVm("message lenght");

    // Définissez la requête
    var friendsStream = FirebaseFirestore.instance
        .collection('Messages')
        .where(Filter.or(
          Filter('send_by', isEqualTo: authProvider.loginUserData.id!),
          Filter('receiverBy', isEqualTo: authProvider.loginUserData.id!),
        ))
        .where('message_state', isEqualTo: MessageState.NONLU.name)
        .where('receiverBy', isEqualTo: authProvider.loginUserData.id!)
        //.orderBy('createdAt', descending: false)

        .snapshots();

    List<Message> listmessage = [];

    await for (var friendSnapshot in friendsStream) {
      listmessage = friendSnapshot.docs
          .map((doc) => Message.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
      //  userProvider.chat.messages=listmessage;
      // printVm("message lgt: ${listmessage.length}");

/*
        for(Message msg in listmessage){
          if (msg.receiverBy!=authProvider.loginUserData.id) {
          nbr=nbr+1;
          }

        }

 */
      printVm("message t: ${listmessage.length}");
      // printVm("message lgt: ${nbr}");
      yield listmessage.length;
    }
  }

  Widget ArticleTile(ArticleData article, double w, double h) {
    // printVm('article ${article.titre}');
    return Card(
      child: Container(
        child: Column(
          children: [
            GestureDetector(
              onTap: () async {
                await authProviderShop.getUserById(article.user_id!).then(
                  (value) async {
                    if (value.isNotEmpty) {
                      article.user = value.first;
                      await categorieProduitProvider
                          .getArticleById(article.id!)
                          .then(
                        (value) {
                          if (value.isNotEmpty) {
                            value.first.vues = value.first.vues! + 1;
                            article.vues = value.first.vues! + 1;
                            categorieProduitProvider
                                .updateArticle(value.first, context)
                                .then(
                              (value) {
                                if (value) {}
                              },
                            );
                          }
                        },
                      );
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                ProduitDetail(article: article),
                          ));
                    }
                  },
                );
              },
              child: ClipRRect(
                borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(10), topRight: Radius.circular(5)),
                child: Container(
                  width: w * 0.45,
                  height: h * 0.16,
                  child: CachedNetworkImage(
                    fit: BoxFit.cover,
                    imageUrl: '${article.images!.first}',
                    progressIndicatorBuilder: (context, url,
                            downloadProgress) =>
                        //  LinearProgressIndicator(),

                        Skeletonizer(
                            child: SizedBox(
                                width: w * 0.2,
                                height: h * 0.2,
                                child: ClipRRect(
                                    borderRadius:
                                        BorderRadius.all(Radius.circular(10)),
                                    child: Image.network(
                                        '${article.images!.first}')))),
                    errorWidget: (context, url, error) => Container(
                        width: w * 0.2,
                        height: h * 0.2,
                        child: Image.network(
                          '${article.images!.first}',
                          fit: BoxFit.cover,
                        )),
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 5,
            ),
            Padding(
              padding: const EdgeInsets.only(left: 8.0, right: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "${article!.titre}".toUpperCase(),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
                  ),
                  // Text(article.description),
                  SizedBox(
                    height: 5,
                  ),
                  Container(
                      alignment: Alignment.centerLeft,
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.all(Radius.circular(5)),
                          color: CustomConstants.kPrimaryColor),
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Text(
                          '${article.prix} Fcfa',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 9),
                        ),
                      )),
                ],
              ),
            ),
            /*
            Padding(
              padding: const EdgeInsets.only(left: 8.0,right: 8,top: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,

                children: [
                  LikeButton(
                    isLiked: false,
                    size: 15,
                    circleColor:
                    CircleColor(start: Color(0xff00ddff), end: Color(0xff0099cc)),
                    bubblesColor: BubblesColor(
                      dotPrimaryColor: Color(0xff3b9ade),
                      dotSecondaryColor: Color(0xff027f19),
                    ),
                    countPostion: CountPostion.bottom,
                    likeBuilder: (bool isLiked) {
                      return Icon(
                        FontAwesome.eye,
                        color: isLiked ? Colors.black : Colors.brown,
                        size: 15,
                      );
                    },
                    likeCount:  article.vues,
                    countBuilder: (int? count, bool isLiked, String text) {
                      var color = isLiked ? Colors.black : Colors.black;
                      Widget result;
                      if (count == 0) {
                        result = Text(
                          "0",textAlign: TextAlign.center,
                          style: TextStyle(color: color,fontSize: 8),
                        );
                      } else
                        result = Text(
                          text,
                          style: TextStyle(color: color,fontSize: 8),
                        );
                      return result;
                    },

                  ),
                  LikeButton(
                    isLiked: false,
                    size: 15,
                    circleColor:
                    CircleColor(start: Color(0xff00ddff), end: Color(0xff0099cc)),
                    bubblesColor: BubblesColor(
                      dotPrimaryColor: Color(0xff3b9ade),
                      dotSecondaryColor: Color(0xff027f19),
                    ),
                    countPostion: CountPostion.bottom,
                    likeBuilder: (bool isLiked) {
                      return Icon(
                        FontAwesome.whatsapp,
                        color: isLiked ? Colors.green : Colors.green,
                        size: 15,
                      );
                    },
                    likeCount:   article.contact,
                    countBuilder: (int? count, bool isLiked, String text) {
                      var color = isLiked ? Colors.black : Colors.black;
                      Widget result;
                      if (count == 0) {
                        result = Text(
                          "0",textAlign: TextAlign.center,
                          style: TextStyle(color: color,fontSize: 8),
                        );
                      } else
                        result = Text(
                          text,
                          style: TextStyle(color: color,fontSize: 8),
                        );
                      return result;
                    },

                  ),
                  LikeButton(
                    onTap: (isLiked) async {
                      await    categorieProduitProvider.getArticleById(article.id!).then((value) {
                        if (value.isNotEmpty) {
                          value.first.jaime=value.first.jaime!+1;
                          article.jaime=value.first.jaime!+1;
                          categorieProduitProvider.updateArticle(value.first,context).then((value) {
                            if (value) {


                            }
                          },);

                        }
                      },);

                      return Future.value(true);

                    },
                    isLiked: false,
                    size: 15,
                    circleColor:
                    CircleColor(start: Color(0xff00ddff), end: Color(0xff0099cc)),
                    bubblesColor: BubblesColor(
                      dotPrimaryColor: Color(0xff3b9ade),
                      dotSecondaryColor: Color(0xff027f19),
                    ),
                    countPostion: CountPostion.bottom,
                    likeBuilder: (bool isLiked) {
                      return Icon(
                        FontAwesome.heart,
                        color: isLiked ? Colors.red : Colors.redAccent,
                        size: 15,
                      );
                    },
                    likeCount:   article.jaime,
                    countBuilder: (int? count, bool isLiked, String text) {
                      var color = isLiked ? Colors.black : Colors.black;
                      Widget result;
                      if (count == 0) {
                        result = Text(
                          "0",textAlign: TextAlign.center,
                          style: TextStyle(color: color,fontSize: 8),
                        );
                      } else
                        result = Text(
                          text,
                          style: TextStyle(color: color,fontSize: 8),
                        );
                      return result;
                    },

                  ),

                ],
              ),
            )

             */
          ],
        ),
      ),
    );
  }

  Widget widgetSeke2(double w,h) {
    // printVm('article ${article.titre}');
    return Skeletonizer(
      //enabled: _loading,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 10,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.all(1.0),
            child: Container(
              // width: 300,
              child: Card(
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      Container(
                        child: CircleAvatar(
                          backgroundImage: AssetImage(
                            "assets/icon/user-removebg-preview.png",
                          ),
                        ),
                        width: w*0.45,
                        height: h*0.2,
                      ),
                      SizedBox(
                        height: 2,
                      ),
                      SizedBox(
                        width: 70,
                        child: TextCustomerUserTitle(
                          titre: "jhasgjh",
                          fontSize: SizeText.homeProfileTextSize,
                          couleur: ConstColors.textColors,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(
                        height: 2,
                      ),
                      TextCustomerUserTitle(
                        titre: "S'abonner",
                        fontSize: SizeText.homeProfileTextSize,
                        couleur: Colors.blue,
                        fontWeight: FontWeight.w600,
                      )
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  final ScrollController _scrollController = ScrollController();

  int postLenght = 8;
  int limitePosts = 40;
  int limiteUsers = 100;

  Future<bool> hasShownDialogToday() async {
    printVm("====hasShownDialogToday====");
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    final String lastShownDateKey = 'lastShownDialogDate2';
    DateTime now = DateTime.now();
    String nowDate = DateFormat('dd, MMMM, yyyy').format(now);
    if (prefs.getString(lastShownDateKey) == null &&
        prefs.getString(lastShownDateKey) != "${nowDate}") {
      prefs.setString(lastShownDateKey, nowDate);
      return true;
    } else {
      return false;
    }
  }

  Stream<List<Chat>> getAndUpdateChatsData() async* {
    // Définissez la requête
    var chatsStream = FirebaseFirestore.instance
        .collection('Chats')
        .where(Filter.or(
          Filter('receiver_id', isEqualTo: '${authProvider.loginUserData.id}'),
          Filter('sender_id', isEqualTo: '${authProvider.loginUserData.id}'),
        ))
        .where("type", isEqualTo: ChatType.USER.name)
        .orderBy('updated_at', descending: true)
        .snapshots();

// Obtenez la liste des utilisateurs
    //List<DocumentSnapshot> users = await usersQuery.sget();
    Chat usersChat = Chat();
    List<Chat> listChats = [];

    await for (var chatSnapshot in chatsStream) {
      for (var chatDoc in chatSnapshot.docs) {
        CollectionReference friendCollect =
            await FirebaseFirestore.instance.collection('Users');
        QuerySnapshot querySnapshotUser = await friendCollect
            .where("id",
                isEqualTo:
                    authProvider.loginUserData.id == chatDoc["receiver_id"]
                        ? chatDoc["sender_id"]
                        : chatDoc["receiver_id"]!)
            .get();
        // Afficher la liste
        List<UserData> userList = querySnapshotUser.docs
            .map((doc) => UserData.fromJson(doc.data() as Map<String, dynamic>))
            .toList();
        //userData=userList.first;

        if (userList.isNotEmpty) {
          usersChat = Chat.fromJson(chatDoc.data());
          usersChat.chatFriend = userList.first;
          usersChat.receiver = userList.first;

          if (usersChat.senderId == authProvider.loginUserData.id!) {
            //  widget.chat.receiver_sending=false;

            usersChat.send_sending = IsSendMessage.NOTSENDING.name;
            printVm('dispose update chat sender');

            firestore
                .collection('Chats')
                .doc(usersChat.id)
                .update(usersChat.toJson());
          } else {
            usersChat.receiver_sending = IsSendMessage.NOTSENDING.name;

            //widget.chat.send_sending=false;
            printVm('dispose update chat reicever');

            firestore
                .collection('Chats')
                .doc(usersChat.id)
                .update(usersChat.toJson());
          }

          //listChats.add(usersChat);
        }
      }
      yield listChats;
      listChats = [];
    }
  }

  @override
  void initState() {
    hasShownDialogToday().then(
      (value) async {
        final SharedPreferences prefs = await SharedPreferences.getInstance();

        if (value) {
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Text('Nouvelle offre sur Afrolook'),
                content: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Image.asset(
                          "assets/images/bonus_afrolook.jpg",
                          fit: BoxFit.cover,
                        ),
                        SizedBox(
                          height: 5,
                        ),
                        Icon(FontAwesome.money, size: 50, color: Colors.green),
                        SizedBox(
                          height: 10,
                        ),
                        Text(
                          'Vous avez la possibilité de',
                        ),
                        Text(' gagner 50 PubliCach',
                            style: TextStyle(color: Colors.green)),
                        Text(
                          ' chaque fois qu\'un nouveau s\'inscrit avec votre code de parrainage qui se situe dans votre profil. Vous pouvez vérifier votre solde dans la page monétisation.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                actions: <Widget>[
                  TextButton(
                    child: Text('OK'),
                    onPressed: () {
                      Navigator.of(context).pop();
                      // Update the last shown date
                      prefs.setString(
                          'lastShownDateKey', DateTime.now().toString());
                    },
                  ),
                ],
              );
            },
          );
        }
      },
    );

    authProvider.getToken().then(
      (token) async {
        printVm("token: ${token}");
        postProvider.getPostsVideos().then((value) {

        },);


        if (token == null || token == '') {
          printVm("token: existe pas");
          Navigator.pushNamed(context, '/welcome');
        } else {}
      },
    );

    WidgetsBinding.instance.addObserver(this);

    // TODO: implement initState
    super.initState();
    dejaVuPub = true;

    // authProvider.getCurrentUser(authProvider.loginUserData!.id!);

    //abonneTap =false;
    //userProvider.getUsers(authProvider.loginUserData!.id!);
    SystemChannels.lifecycle.setMessageHandler(
      (message) {
        printVm('stategb:  --- ${message}');

        if (message!.contains('resume')) {
          //online
          printVm('state en ligne:  --- ${message}');
          authProvider.loginUserData!.isConnected = true;
          userProvider.changeState(
              user: authProvider.loginUserData, state: UserState.ONLINE.name);
        } else {
          printVm('state hors ligne :  --- ${message}');
          authProvider.loginUserData!.isConnected = false;
          userProvider.changeState(
              user: authProvider.loginUserData, state: UserState.OFFLINE.name);
          //offline
          getAndUpdateChatsData();
        }
        return Future.value(message);
      },
    );
    // authProvider.getCurrentUser(authProvider.loginUserData!.id!);
  }

  @override
  void dispose() {
    // Unregister your State class as a binding observer
    WidgetsBinding.instance.removeObserver(this);

    super.dispose();
  }

  // listen to the app lifecycle state changes
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.detached:
        _onDetached();
      case AppLifecycleState.resumed:
        _onResumed();
      case AppLifecycleState.inactive:
        _onInactive();
      case AppLifecycleState.hidden:
        _onHidden();
      case AppLifecycleState.paused:
        _onPaused();
    }
  }

  void _onDetached() => printVm('detached');

  void _onResumed() => printVm('resumed');

  void _onInactive() => printVm('inactive');

  void _onHidden() => printVm('hidden');

  void _onPaused() => printVm('paused');

  @override
  Widget build(BuildContext context) {
    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;
    //userProvider.getUsers(authProvider.loginUserData!.id!);
    // if(postProvider.listConstposts.isNotEmpty){
    //   setState(() {
    //   });
    // }

    return RefreshIndicator(
      onRefresh: () async {
        setState(() {
          postProvider.getPostsImages(limitePosts).then(
                (value) {},
              );
          postProvider.getPostsVideos().then((value) {

          },);

        });

        //Restart.restartApp();
        // is_actualised = true;

        //     await userProvider.getAllAnnonces();
        /*
       await postProvider.getPostsImages(limitePosts).then((value) {
          printVm('actualiser');
          setState(() {
            postLenght=8;
            is_actualised = false;

          });


        },);

         */
      },
      child: WillPopScope(
        onWillPop: () async {
          // Cette fonction sera appelée lorsque l'utilisateur appuie sur le bouton "Retour"
          return await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Voulez-vous quitter l\'application ?'),
              content: const Text(
                  'Êtes-vous sûr de vouloir quitter l\'application ? Toutes vos données non enregistrées seront perdues.'),
              actions: <Widget>[
                TextButton(
                  onPressed: () {
                    Navigator.of(context)
                        .pop(false); // Annuler la fermeture de l'application
                  },
                  child: const Text('Annuler'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(true); // Quitter l'application
                  },
                  child: const Text('Quitter'),
                ),
              ],
            ),
          );
        },
        child: Scaffold(
          key: _scaffoldKey,
          backgroundColor: ConstColors.backgroundColor,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            leadingWidth: 150,
            leading: Logo(),

            //backgroundColor: Colors.blue,
            actions: [
              GestureDetector(
                onTap: () {
                  Navigator.pushNamed(context, "/mes_notifications");
                },
                child: StreamBuilder<List<NotificationData>>(
                  stream: authProvider
                      .getListNotificationAuth(authProvider.loginUserData.id!),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Icon(
                        Icons.notifications,
                        color: ConstColors.blackIconColors,
                      );
                    } else if (snapshot.hasError) {
                      return Icon(
                        Icons.notifications,
                        color: ConstColors.blackIconColors,
                      );
                    } else {
                      List<NotificationData> list = snapshot!.data!;

                      return Padding(
                        padding: const EdgeInsets.only(right: 15.0),
                        child: badges.Badge(
                          showBadge: list.length < 1 ? false : true,
                          badgeContent: list.length > 9
                              ? Text(
                                  '9+',
                                  style: TextStyle(
                                      fontSize: 10, color: Colors.white),
                                )
                              : Text(
                                  '${list.length}',
                                  style: TextStyle(
                                      fontSize: 10, color: Colors.white),
                                ),
                          child: Icon(
                            Icons.notifications,
                            color: ConstColors.blackIconColors,
                          ),
                        ),
                      );
                    }
                  },
                ),
              ),
              IconButton(
                  onPressed: () async {
                    // _scrollController.animateTo(
                    //   0.0,
                    //   duration: Duration(milliseconds: 1000),
                    //   curve: Curves.ease,
                    // );
                    setState(() {
                      postProvider
                          .reloadPostsImages(limitePosts, _scrollController)
                          .then(
                            (value) {},
                          );
                      postProvider.getPostsVideos().then((value) {

                      },);

                    });
                  },
                  icon: Icon(FontAwesome.refresh)),
              IconButton(
                  onPressed: () async {
                    _scrollController.animateTo(
                      0.0,
                      duration: Duration(milliseconds: 1000),
                      curve: Curves.ease,
                    );
                    // setState(() {
                    //   postProvider.getHomePostsImages(limitePosts).then((value) {
                    //
                    //   },);
                    // });

                    //   Restart.restartApp();

                    /*
                await userProvider.getAllAnnonces();
                await postProvider.getPostsImages(limitePosts).then((value) {
                  printVm('actualiser');
                  setState(() {
                    postLenght=8;
                    is_actualised = false;

                  });


                },);

                 */
                  },
                  icon: Icon(Icons.home))
            ],
            //title: Text(widget.title),
          ),
          drawer: menu(context),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(3.0),
              child: Consumer<PostProvider>(
                  builder: (context, postListProvider, child) {
                return postListProvider.listConstposts.isEmpty
                    ? Skeletonizer(
                  enabled: true,
                  enableSwitchAnimation: true,
                  child: ListView.builder(
                    itemCount: 10,
                    padding: const EdgeInsets.all(16),
                    itemBuilder: (context, index) {
                      return Card(
                        child: ListTile(
                          title: Text('Item number $index as title'),
                          subtitle: const Text('Subtitle here'),
                          trailing: const Icon(
                            Icons.ac_unit,
                            size: 32,
                          ),
                        ),
                      );
                    },
                  ),
                )

                        : ListView(
                        children: [
                          Stack(
                            children: [
                              // Votre contenu principal ici

                              FutureBuilder<List<Post>>(
                                  // future: postProvider.getPostsImages(limitePosts),
                                  future:
                                      postListProvider.getPostsImagesAlready(),
                                  builder: (BuildContext context,
                                      AsyncSnapshot snapshot) {
                                    if (snapshot.hasData) {
                                      List<Post> listConstposts =
                                          postListProvider.listConstposts;

                                      // listConstposts.insert(0, listConstposts.elementAt(0));

                                      // listConstposts.insert(0, listConstposts.elementAt(0));

                                      return SizedBox(
                                        width: width,
                                        height: height * 0.81,
                                        child: ListView.builder(
                                          controller: _scrollController,
                                          scrollDirection: Axis.vertical,
                                          itemCount: listConstposts.length,
                                          itemBuilder: (BuildContext context,
                                              int index) {
                                            // postListProvider.listConstposts.insert(0, postListProvider.listConstposts.elementAt(index));

                                            if (index == 0) {
                                              return Column(
                                                children: <Widget>[
                                                  Row(
                                                    children: [
                                                      TextButton(
                                                          onPressed: () {},
                                                          child: Text("")),
                                                      TextButton(
                                                          onPressed: () async {
                                                            // Navigator.push(context, MaterialPageRoute(builder: (context) => AddListAmis(),));
                                                            await userProvider
                                                                .getProfileUsers(
                                                                    authProvider
                                                                        .loginUserData!
                                                                        .id!,
                                                                    context,
                                                                    limiteUsers)
                                                                .then(
                                                              (value) {
                                                                Navigator.push(
                                                                    context,
                                                                    MaterialPageRoute(
                                                                      builder:
                                                                          (context) =>
                                                                              UserCards(),
                                                                    ));
                                                              },
                                                            );
                                                          },
                                                          child: Text(
                                                              "Voir autres profiles")),
                                                    ],
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                  ),
                                                  SizedBox(
                                                    width: width,
                                                    height: height*0.35,
                                                    child: FutureBuilder<
                                                        List<UserData>>(
                                                      future: userProvider
                                                          .getProfileUsers(
                                                              authProvider
                                                                  .loginUserData
                                                                  .id!,
                                                              context,
                                                              limiteUsers),
                                                      builder:
                                                          (context, snapshot) {
                                                        if (snapshot
                                                                .connectionState ==
                                                            ConnectionState
                                                                .waiting) {
                                                          return widgetSeke2(width,height);
                                                        } else if (snapshot
                                                            .hasError) {
                                                          return widgetSeke2(width,height);
                                                        } else {
                                                          // Get data from docs and convert map to List
                                                          List<UserData> list =
                                                              snapshot.data!;
                                                          // Utiliser les données de snapshot.data
                                                          return ListView
                                                              .builder(
                                                                  scrollDirection:
                                                                      Axis
                                                                          .horizontal,
                                                                  itemCount:
                                                                      snapshot
                                                                          .data!
                                                                          .length, // Nombre d'éléments dans la liste
                                                                  itemBuilder:
                                                                      (context,
                                                                          index) {
                                                                    //list[index].userAbonnes=[];
                                                                    return homeProfileUsers(
                                                                        list[
                                                                            index],
                                                                        width,
                                                                        height);
                                                                  });
                                                        }
                                                      },
                                                    ),
                                                  ),

                                                  Divider(
                                                    height: 10,
                                                  ),
                                                  Row(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .center,
                                                    children: [
                                                      Expanded(
                                                        child: Padding(
                                                          padding:
                                                              const EdgeInsets
                                                                  .all(2.0),
                                                          child: SizedBox(
                                                            height: 20,
                                                            child: Marquee(
                                                              key: Key("keys"),
                                                              text:
                                                                  "Faites la promotion de vos annonces et publicités ! Contactez-nous pour des offres limitées.",
                                                              style: TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  color: Colors
                                                                      .black),
                                                              scrollAxis: Axis
                                                                  .horizontal,
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                              blankSpace: 20,
                                                              velocity: 100,
                                                              pauseAfterRound:
                                                                  Duration(
                                                                      seconds:
                                                                          1),
                                                              showFadingOnlyWhenScrolling:
                                                                  true,
                                                              fadingEdgeStartFraction:
                                                                  0.1,
                                                              fadingEdgeEndFraction:
                                                                  0.1,
                                                              numberOfRounds:
                                                                  1000,
                                                              startPadding: 10,
                                                              accelerationDuration:
                                                                  Duration(
                                                                      milliseconds:
                                                                          5000),
                                                              accelerationCurve:
                                                                  Curves.linear,
                                                              decelerationDuration:
                                                                  Duration(
                                                                      milliseconds:
                                                                          1000),
                                                              decelerationCurve:
                                                                  Curves
                                                                      .easeOut,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                      TextButton(
                                                          onPressed: () {
                                                            Navigator.pushNamed(
                                                                context,
                                                                '/contact');
                                                          },
                                                          child: Container(
                                                              height: 20,
                                                              decoration: BoxDecoration(
                                                                  color: Colors
                                                                      .green,
                                                                  borderRadius:
                                                                      BorderRadius.all(
                                                                          Radius.circular(
                                                                              2))),
                                                              child: Padding(
                                                                padding:
                                                                    const EdgeInsets
                                                                        .only(
                                                                        left:
                                                                            2.0,
                                                                        right:
                                                                            2,
                                                                        bottom:
                                                                            1),
                                                                child: Text(
                                                                  "Contacter",
                                                                  style: TextStyle(
                                                                      color: Colors
                                                                          .white),
                                                                ),
                                                              )))
                                                    ],
                                                  ),
                                                  // SizedBox(height: 5,),

                                                  Divider(
                                                    height: 10,
                                                  ),

                                                  //           Row(
                                                  //             mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  //             children: [
                                                  //               Align(
                                                  //                 alignment: Alignment.centerLeft,
                                                  //                 child: Padding(
                                                  //                   padding: const EdgeInsets.only(top: 2.0,bottom: 0,left: 8),
                                                  //                   child: Row(
                                                  //                     children: [
                                                  //                       Icon(Icons.storefront,color: Colors.green,),
                                                  //                       SizedBox(width: 2,),
                                                  //                       TextCustomerPostDescription(
                                                  //                         titre:
                                                  //                         "Afroshop Annonces ",
                                                  //                         fontSize: 15,
                                                  //                         couleur: CustomConstants.kPrimaryColor,
                                                  //                         fontWeight: FontWeight.w800,
                                                  //                       ),
                                                  //                     ],
                                                  //                   ),
                                                  //                 ),
                                                  //               ),
                                                  //               TextButton(onPressed: () {
                                                  //                 Navigator.push(context, MaterialPageRoute(builder: (context) => HomeAfroshopPage(title: ''),));
                                                  //
                                                  //
                                                  //               }, child: Text("Afficher plus")),
                                                  //             ],
                                                  //           ),
                                                  //
                                                  //
                                                  //           Padding(
                                                  //             padding: const EdgeInsets.all(4.0),
                                                  //             child: FutureBuilder<List<ArticleData>>(
                                                  //                 future: categorieProduitProvider.getAnnoncesArticles(),
                                                  //                 builder: (BuildContext context, AsyncSnapshot snapshot) {
                                                  //                   if (snapshot.hasData) {
                                                  //                     List<ArticleData> articles=snapshot.data;
                                                  //                     return Column(
                                                  //                       children: [
                                                  //                         Container(
                                                  //                           height: height * 0.22,
                                                  //                           width: width,
                                                  //                           child: FlutterCarousel.builder(
                                                  //                             itemCount: articles.length,
                                                  //                             itemBuilder: (BuildContext context, int index, int pageViewIndex) =>
                                                  //                                 ArticleTile( articles[index],width,height),
                                                  //                             options: CarouselOptions(
                                                  //                               autoPlay: true,
                                                  //                               //controller: buttonCarouselController,
                                                  //                               enlargeCenterPage: true,
                                                  //                               viewportFraction: 0.4,
                                                  //                               aspectRatio: 1.5,
                                                  //                               initialPage: 1,
                                                  //                               reverse: true,
                                                  //                               autoPlayInterval: const Duration(seconds: 2),
                                                  //                               autoPlayAnimationDuration: const Duration(milliseconds: 800),
                                                  //                               autoPlayCurve: Curves.fastOutSlowIn,
                                                  //
                                                  //                             ),
                                                  //                           ),
                                                  //                         ),
                                                  //                         /*
                                                  //                       Container(
                                                  //                         height: height*0.08,
                                                  //                         width: width,
                                                  //                         alignment: Alignment.centerLeft,
                                                  //                         child: ListView.builder(
                                                  //
                                                  // scrollDirection: Axis.horizontal,
                                                  // itemCount: articles.length,
                                                  // itemBuilder:
                                                  //     (BuildContext context, int index) {
                                                  //   return ArticleTile( articles[index],width,height);
                                                  // },
                                                  //                         ),
                                                  //                       ),
                                                  //
                                                  //                        */
                                                  //                       ],
                                                  //                     );
                                                  //                   } else if (snapshot.hasError) {
                                                  //                     return Icon(Icons.error_outline);
                                                  //                   } else {
                                                  //                     return Container(
                                                  //                         width: 30,
                                                  //                         height: 40,
                                                  //
                                                  //                         child: CircularProgressIndicator());
                                                  //                   }
                                                  //                 }),
                                                  //           ),
                                                  //           Divider(height: 10,),
                                                ],
                                              );
                                            }
                                            if (index % 6 == 0) {
                                              // listConstposts.insert(index, listConstposts.elementAt(index));

                                              return Column(
                                                children: <Widget>[
                                                  Row(
                                                    children: [
                                                      TextButton(
                                                          onPressed: () {},
                                                          child: Text("")),
                                                      TextButton(
                                                          onPressed: () async {
                                                            // Navigator.push(context, MaterialPageRoute(builder: (context) => AddListAmis(),));
                                                            await userProvider
                                                                .getProfileUsers(
                                                                    authProvider
                                                                        .loginUserData!
                                                                        .id!,
                                                                    context,
                                                                    limiteUsers)
                                                                .then(
                                                              (value) {
                                                                Navigator.push(
                                                                    context,
                                                                    MaterialPageRoute(
                                                                      builder:
                                                                          (context) =>
                                                                              UserCards(),
                                                                    ));
                                                              },
                                                            );
                                                          },
                                                          child: Text(
                                                              "Voir autres profiles")),
                                                    ],
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                  ),
                                                  SizedBox(
                                                    //width: width,
                                                    height: height * 0.38,
                                                    child: FutureBuilder<
                                                        List<UserData>>(
                                                      future: userProvider
                                                          .getProfileUsers(
                                                              authProvider
                                                                  .loginUserData
                                                                  .id!,
                                                              context,
                                                              limiteUsers),
                                                      builder:
                                                          (context, snapshot) {
                                                        if (snapshot
                                                                .connectionState ==
                                                            ConnectionState
                                                                .waiting) {
                                                          return Skeletonizer(
                                                            //enabled: _loading,
                                                            child: ListView
                                                                .builder(
                                                              scrollDirection:
                                                                  Axis.horizontal,
                                                              itemCount: 10,
                                                              itemBuilder:
                                                                  (context,
                                                                      index) {
                                                                return Padding(
                                                                  padding:
                                                                      const EdgeInsets
                                                                          .all(
                                                                          1.0),
                                                                  child:
                                                                      Container(
                                                                    width: 300,
                                                                    child: Card(
                                                                      color: Colors
                                                                          .white,
                                                                      child:
                                                                          Padding(
                                                                        padding: const EdgeInsets
                                                                            .all(
                                                                            8.0),
                                                                        child:
                                                                            Column(
                                                                          children: [
                                                                            Container(
                                                                              child: CircleAvatar(
                                                                                backgroundImage: AssetImage(
                                                                                  "assets/icon/user-removebg-preview.png",
                                                                                ),
                                                                              ),
                                                                              height: 100,
                                                                              width: 100,
                                                                            ),
                                                                            SizedBox(
                                                                              height: 2,
                                                                            ),
                                                                            SizedBox(
                                                                              width: 70,
                                                                              child: TextCustomerUserTitle(
                                                                                titre: "jhasgjh",
                                                                                fontSize: SizeText.homeProfileTextSize,
                                                                                couleur: ConstColors.textColors,
                                                                                fontWeight: FontWeight.w600,
                                                                              ),
                                                                            ),
                                                                            SizedBox(
                                                                              height: 2,
                                                                            ),
                                                                            TextCustomerUserTitle(
                                                                              titre: "S'abonner",
                                                                              fontSize: SizeText.homeProfileTextSize,
                                                                              couleur: Colors.blue,
                                                                              fontWeight: FontWeight.w600,
                                                                            )
                                                                          ],
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  ),
                                                                );
                                                              },
                                                            ),
                                                          );
                                                        } else if (snapshot
                                                            .hasData) {
                                                          // Get data from docs and convert map to List
                                                          List<UserData> list =
                                                              snapshot.data!;
                                                          // Utiliser les données de snapshot.data
                                                          return ListView
                                                              .builder(
                                                                  scrollDirection:
                                                                      Axis
                                                                          .horizontal,
                                                                  itemCount:
                                                                      snapshot
                                                                          .data!
                                                                          .length, // Nombre d'éléments dans la liste
                                                                  itemBuilder:
                                                                      (context,
                                                                          index) {
                                                                    //list[index].userAbonnes=[];
                                                                    return homeProfileUsers(
                                                                        list[
                                                                            index],
                                                                        width,
                                                                        height);
                                                                  });
                                                        } else {
                                                          return Skeletonizer(
                                                            //enabled: _loading,
                                                            child: ListView
                                                                .builder(
                                                              scrollDirection:
                                                                  Axis.horizontal,
                                                              itemCount: 10,
                                                              itemBuilder:
                                                                  (context,
                                                                      index) {
                                                                return Container(
                                                                  width: 300,
                                                                  child:
                                                                      Padding(
                                                                    padding:
                                                                        const EdgeInsets
                                                                            .all(
                                                                            1.0),
                                                                    child: Card(
                                                                      color: Colors
                                                                          .white,
                                                                      child:
                                                                          Padding(
                                                                        padding: const EdgeInsets
                                                                            .all(
                                                                            8.0),
                                                                        child:
                                                                            Column(
                                                                          children: [
                                                                            Container(
                                                                              child: CircleAvatar(
                                                                                backgroundImage: AssetImage(
                                                                                  "assets/icon/user-removebg-preview.png",
                                                                                ),
                                                                              ),
                                                                              height: 100,
                                                                              width: 100,
                                                                            ),
                                                                            SizedBox(
                                                                              height: 2,
                                                                            ),
                                                                            SizedBox(
                                                                              width: 70,
                                                                              child: TextCustomerUserTitle(
                                                                                titre: "jhasgjh",
                                                                                fontSize: SizeText.homeProfileTextSize,
                                                                                couleur: ConstColors.textColors,
                                                                                fontWeight: FontWeight.w600,
                                                                              ),
                                                                            ),
                                                                            SizedBox(
                                                                              height: 2,
                                                                            ),
                                                                            TextCustomerUserTitle(
                                                                              titre: "S'abonner",
                                                                              fontSize: SizeText.homeProfileTextSize,
                                                                              couleur: Colors.blue,
                                                                              fontWeight: FontWeight.w600,
                                                                            )
                                                                          ],
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  ),
                                                                );
                                                              },
                                                            ),
                                                          );
                                                        }
                                                      },
                                                    ),
                                                  ),
                                                  Divider(
                                                    height: 10,
                                                  ),
                                                  Row(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .center,
                                                    children: [
                                                      Expanded(
                                                        child: Padding(
                                                          padding:
                                                              const EdgeInsets
                                                                  .all(2.0),
                                                          child: SizedBox(
                                                            height: 20,
                                                            child: Marquee(
                                                              key: Key("keys"),
                                                              text:
                                                                  "Faites la promotion de vos annonces et publicités ! Contactez-nous pour des offres limitées.",
                                                              style: TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  color: Colors
                                                                      .black),
                                                              scrollAxis: Axis
                                                                  .horizontal,
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                              blankSpace: 20,
                                                              velocity: 100,
                                                              pauseAfterRound:
                                                                  Duration(
                                                                      seconds:
                                                                          1),
                                                              showFadingOnlyWhenScrolling:
                                                                  true,
                                                              fadingEdgeStartFraction:
                                                                  0.1,
                                                              fadingEdgeEndFraction:
                                                                  0.1,
                                                              numberOfRounds:
                                                                  1000,
                                                              startPadding: 10,
                                                              accelerationDuration:
                                                                  Duration(
                                                                      milliseconds:
                                                                          5000),
                                                              accelerationCurve:
                                                                  Curves.linear,
                                                              decelerationDuration:
                                                                  Duration(
                                                                      milliseconds:
                                                                          1000),
                                                              decelerationCurve:
                                                                  Curves
                                                                      .easeOut,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                      TextButton(
                                                          onPressed: () {
                                                            Navigator.pushNamed(
                                                                context,
                                                                '/contact');
                                                          },
                                                          child: Container(
                                                              height: 20,
                                                              decoration: BoxDecoration(
                                                                  color: Colors
                                                                      .green,
                                                                  borderRadius:
                                                                      BorderRadius.all(
                                                                          Radius.circular(
                                                                              2))),
                                                              child: Padding(
                                                                padding:
                                                                    const EdgeInsets
                                                                        .only(
                                                                        left:
                                                                            2.0,
                                                                        right:
                                                                            2,
                                                                        bottom:
                                                                            1),
                                                                child: Text(
                                                                  "Contacter",
                                                                  style: TextStyle(
                                                                      color: Colors
                                                                          .white),
                                                                ),
                                                              )))
                                                    ],
                                                  ),
                                                  // SizedBox(height: 5,),
                                                  //
                                                  // userProvider.listAnnonces
                                                  //             .length <
                                                  //         0
                                                  //     ? Container()
                                                  //     : Visibility(
                                                  //         visible: userProvider
                                                  //                     .listAnnonces
                                                  //                     .length >
                                                  //                 0
                                                  //             ? true
                                                  //             : false,
                                                  //         child: SizedBox(
                                                  //           // width: width*0.8,
                                                  //           //height: height*0.2,
                                                  //           child: Padding(
                                                  //             padding:
                                                  //                 const EdgeInsets
                                                  //                     .all(2.0),
                                                  //             child:
                                                  //                 FlutterCarousel
                                                  //                     .builder(
                                                  //               itemCount:
                                                  //                   userProvider
                                                  //                       .listAnnonces
                                                  //                       .length,
                                                  //               itemBuilder: (BuildContext
                                                  //                           context,
                                                  //                       int itemIndex,
                                                  //                       int pageViewIndex) =>
                                                  //                   GestureDetector(
                                                  //                 onTap:
                                                  //                     () async {
                                                  //                   Annonce
                                                  //                       annonce =
                                                  //                       userProvider
                                                  //                           .listAnnonces[itemIndex];
                                                  //                   annonce.vues =
                                                  //                       annonce.vues! +
                                                  //                           1;
                                                  //                   await firestore
                                                  //                       .collection(
                                                  //                           'Annonces')
                                                  //                       .doc(annonce!
                                                  //                           .id)
                                                  //                       .update(
                                                  //                           annonce!.toJson());
                                                  //                   _showUserDetailsAnnonceDialog(
                                                  //                       '${userProvider.listAnnonces[itemIndex].media_url!}',
                                                  //                       userProvider
                                                  //                           .listAnnonces[itemIndex]);
                                                  //                 },
                                                  //                 child:
                                                  //                     ClipRRect(
                                                  //                   borderRadius:
                                                  //                       BorderRadius.all(
                                                  //                           Radius.circular(10)),
                                                  //                   child:
                                                  //                       Container(
                                                  //                     width:
                                                  //                         width *
                                                  //                             0.9,
                                                  //                     height:
                                                  //                         height *
                                                  //                             0.5,
                                                  //                     child:
                                                  //                         Stack(
                                                  //                       children: [
                                                  //                         SizedBox(
                                                  //                           width:
                                                  //                               width * 0.9,
                                                  //                           height:
                                                  //                               height * 0.5,
                                                  //                           child:
                                                  //                               CachedNetworkImage(
                                                  //                             fit: BoxFit.cover,
                                                  //                             imageUrl: '${userProvider.listAnnonces[itemIndex].media_url!}',
                                                  //                             progressIndicatorBuilder: (context, url, downloadProgress) =>
                                                  //                                 //  LinearProgressIndicator(),
                                                  //
                                                  //                                 Skeletonizer(child: SizedBox(width: width * 0.9, height: height * 0.5, child: ClipRRect(borderRadius: BorderRadius.all(Radius.circular(10)), child: Image.asset('assets/images/404.png')))),
                                                  //                             errorWidget: (context, url, error) => Container(
                                                  //                                 width: width * 0.9,
                                                  //                                 height: height * 0.5,
                                                  //                                 child: Image.asset(
                                                  //                                   "assets/icon/user-removebg-preview.png",
                                                  //                                   fit: BoxFit.cover,
                                                  //                                 )),
                                                  //                           ),
                                                  //                         ),
                                                  //                         Positioned(
                                                  //                           //width: 100,
                                                  //                           //height: 40,
                                                  //
                                                  //                           child:
                                                  //                               Container(
                                                  //                             decoration: BoxDecoration(
                                                  //                                 //  color: Colors.white,
                                                  //                                 borderRadius: BorderRadius.all(Radius.circular(50))),
                                                  //                             child: Center(
                                                  //                               child: Container(
                                                  //                                 width: 100,
                                                  //                                 decoration: BoxDecoration(color: Colors.green.withOpacity(0.5), borderRadius: BorderRadius.all(Radius.circular(50))),
                                                  //                                 child: Padding(
                                                  //                                   padding: const EdgeInsets.all(8.0),
                                                  //                                   child: Row(
                                                  //                                     mainAxisAlignment: MainAxisAlignment.center,
                                                  //                                     children: [
                                                  //                                       Text(
                                                  //                                         "vues: ",
                                                  //                                         style: TextStyle(fontWeight: FontWeight.w600),
                                                  //                                       ),
                                                  //                                       userProvider.listAnnonces[itemIndex]!.vues! > 999
                                                  //                                           ? Text(
                                                  //                                               "+999",
                                                  //                                               style: TextStyle(fontWeight: FontWeight.w600, color: Colors.red),
                                                  //                                             )
                                                  //                                           : Text(
                                                  //                                               "${userProvider.listAnnonces[itemIndex].vues}",
                                                  //                                               style: TextStyle(fontWeight: FontWeight.w600),
                                                  //                                             ),
                                                  //                                     ],
                                                  //                                   ),
                                                  //                                 ),
                                                  //                               ),
                                                  //                             ),
                                                  //                           ),
                                                  //                         ),
                                                  //                       ],
                                                  //                     ),
                                                  //                   ),
                                                  //                 ),
                                                  //               ),
                                                  //               options:
                                                  //                   CarouselOptions(
                                                  //                 autoPlay:
                                                  //                     true,
                                                  //                 //controller: buttonCarouselController,
                                                  //                 enlargeCenterPage:
                                                  //                     true,
                                                  //                 viewportFraction:
                                                  //                     0.9,
                                                  //                 aspectRatio:
                                                  //                     3.0,
                                                  //                 // initialPage: 1,
                                                  //                 autoPlayInterval:
                                                  //                     const Duration(
                                                  //                         seconds:
                                                  //                             2),
                                                  //                 autoPlayAnimationDuration:
                                                  //                     const Duration(
                                                  //                         milliseconds:
                                                  //                             800),
                                                  //                 autoPlayCurve:
                                                  //                     Curves
                                                  //                         .fastOutSlowIn,
                                                  //               ),
                                                  //             ),
                                                  //           ),
                                                  //         ),
                                                  //       ),
                                                ],
                                              );
                                            }
                                            //     if (index % 8== 0) {
                                            //       return Column(
                                            //         children: <Widget>[
                                            //           Row(
                                            //             mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            //             children: [
                                            //               Align(
                                            //                 alignment: Alignment.centerLeft,
                                            //                 child: Padding(
                                            //                   padding: const EdgeInsets.only(top: 2.0,bottom: 0,left: 8),
                                            //                   child: Row(
                                            //                     children: [
                                            //                       Icon(Icons.storefront,color: Colors.green,),
                                            //                       SizedBox(width: 2,),
                                            //                       TextCustomerPostDescription(
                                            //                         titre:
                                            //                         "Afroshop Annonces ",
                                            //                         fontSize: 15,
                                            //                         couleur: CustomConstants.kPrimaryColor,
                                            //                         fontWeight: FontWeight.w800,
                                            //                       ),
                                            //                     ],
                                            //                   ),
                                            //                 ),
                                            //               ),
                                            //               TextButton(onPressed: () {
                                            //                 Navigator.push(context, MaterialPageRoute(builder: (context) => HomeAfroshopPage(title: ''),));
                                            //
                                            //
                                            //               }, child: Text("Afficher plus")),
                                            //             ],
                                            //           ),
                                            //
                                            //
                                            //           Padding(
                                            //             padding: const EdgeInsets.all(4.0),
                                            //             child: FutureBuilder<List<ArticleData>>(
                                            //                 future: categorieProduitProvider.getAnnoncesArticles(),
                                            //                 builder: (BuildContext context, AsyncSnapshot snapshot) {
                                            //                   if (snapshot.hasData) {
                                            //                     List<ArticleData> articles=snapshot.data;
                                            //                     return Column(
                                            //                       children: [
                                            //                         Container(
                                            //                           height: height * 0.22,
                                            //                           width: width,
                                            //                           child: FlutterCarousel.builder(
                                            //                             itemCount: articles.length,
                                            //                             itemBuilder: (BuildContext context, int index, int pageViewIndex) =>
                                            //                                 ArticleTile( articles[index],width,height),
                                            //                             options: CarouselOptions(
                                            //                               autoPlay: true,
                                            //                               //controller: buttonCarouselController,
                                            //                               enlargeCenterPage: true,
                                            //                               viewportFraction: 0.4,
                                            //                               aspectRatio: 1.5,
                                            //                               initialPage: 1,
                                            //                               reverse: true,
                                            //                               autoPlayInterval: const Duration(seconds: 2),
                                            //                               autoPlayAnimationDuration: const Duration(milliseconds: 800),
                                            //                               autoPlayCurve: Curves.fastOutSlowIn,
                                            //
                                            //                             ),
                                            //                           ),
                                            //                         ),
                                            //                         /*
                                            //                       Container(
                                            //                         height: height*0.08,
                                            //                         width: width,
                                            //                         alignment: Alignment.centerLeft,
                                            //                         child: ListView.builder(
                                            //
                                            // scrollDirection: Axis.horizontal,
                                            // itemCount: articles.length,
                                            // itemBuilder:
                                            //     (BuildContext context, int index) {
                                            //   return ArticleTile( articles[index],width,height);
                                            // },
                                            //                         ),
                                            //                       ),
                                            //
                                            //                        */
                                            //                       ],
                                            //                     );
                                            //                   } else if (snapshot.hasError) {
                                            //                     return Icon(Icons.error_outline);
                                            //                   } else {
                                            //                     return Container(
                                            //                         width: 30,
                                            //                         height: 40,
                                            //
                                            //                         child: CircularProgressIndicator());
                                            //                   }
                                            //                 }),
                                            //           ),
                                            //           Divider(height: 10,),
                                            //         ],
                                            //       );
                                            //
                                            //     }

                                            else {
                                              // listConstposts.insert(0, postListProvider.listConstposts.elementAt(index));

                                              return Padding(
                                                padding: const EdgeInsets.only(
                                                    top: 5.0, bottom: 5),
                                                child: homePostUsers(
                                                    listConstposts![index],
                                                    height,
                                                    width),
                                              );
                                            }
                                          },
                                        ),
                                      );
                                    } else if (snapshot.hasError) {
                                      printVm(
                                          "erreur ${snapshot.error.toString()}");

                                      return Center(child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          Icon(Icons.error_outline),
                                          ElevatedButton(onPressed: () {
                                            setState(() {
                                              postProvider
                                                  .reloadPostsImages(limitePosts, _scrollController)
                                                  .then(
                                                    (value) {},
                                              );
                                              postProvider.getPostsVideos().then((value) {

                                              },);

                                            });
                                          }, child: Text('Actualiser'))
                                        ],
                                      ));
                                    }
                                    if (snapshot.connectionState ==
                                        ConnectionState.waiting) {
                                      return widgetSeke(width, height);
                                    } else {
                                      return widgetSeke(width, height);
                                    }
                                  }),

                              // Le CircularProgressIndicator
                              Visibility(
                                visible: postListProvider.isReload,
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
              }),
            ),
          ),
          bottomNavigationBar: Container(
            height: 50,
            color: Colors.transparent,
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () async {
                      await userProvider
                          .getProfileUsers(authProvider.loginUserData!.id!,
                              context, limiteUsers)
                          .then(
                        (value) {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => UserCards(),
                              ));
                        },
                      );

                      // Navigator.push(context, MaterialPageRoute(builder: (context) => MesInvitationsPage(context: context),));
                    },
                    child: StreamBuilder<int>(
                        stream: getNbrInvitation(),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            printVm("erreur: ${snapshot.error.toString()}");
                            return badges.Badge(
                              badgeContent: Text('1'),
                              showBadge: false,
                              child: Icon(
                                Entypo.message,
                                //AntDesign.message1,
                                size: 30,
                                color: ConstColors.blackIconColors,
                              ),
                            );
                          } else if (snapshot.hasData) {
                            if (snapshot.data! > 0) {
                              return badges.Badge(
                                badgeContent: snapshot.data! > 10
                                    ? Text(
                                        '9+',
                                        style: TextStyle(
                                            fontSize: 10, color: Colors.white),
                                      )
                                    : Text(
                                        '${snapshot.data!}',
                                        style: TextStyle(
                                            fontSize: 10, color: Colors.white),
                                      ),
                                child: Icon(
                                  MaterialCommunityIcons.account_group,
                                  //AntDesign.message1,
                                  color: ConstColors.blackIconColors,
                                ),
                              );
                            } else {
                              return badges.Badge(
                                badgeContent: Text('1'),
                                showBadge: false,
                                child: Icon(
                                  MaterialCommunityIcons.account_group,
                                  //AntDesign.message1,
                                  size: 30,

                                  color: ConstColors.blackIconColors,
                                ),
                              );
                            }
                          } else {
                            printVm("data: ${snapshot.data}");
                            return badges.Badge(
                              badgeContent: Text('1'),
                              showBadge: false,
                              child: Icon(
                                MaterialCommunityIcons.account_group,
                                //AntDesign.message1,
                                size: 30,
                                color: ConstColors.blackIconColors,
                              ),
                            );
                          }
                        }),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.pushNamed(context, '/list_users_chat');
                      //Navigator.pushNamed(context, '/test_chat');
                    },
                    child: StreamBuilder<int>(
                        stream: getNbrMessageNonLu(),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            printVm("erreur: ${snapshot.error.toString()}");
                            return badges.Badge(
                              badgeContent: Text('1'),
                              showBadge: false,
                              child: Icon(
                                Entypo.message,
                                //AntDesign.message1,
                                size: 30,
                                color: ConstColors.blackIconColors,
                              ),
                            );
                          } else if (snapshot.hasData) {
                            if (snapshot.data! > 0) {
                              return badges.Badge(
                                badgeContent: snapshot.data! > 10
                                    ? Text(
                                        '9+',
                                        style: TextStyle(
                                            fontSize: 10, color: Colors.white),
                                      )
                                    : Text(
                                        '${snapshot.data!}',
                                        style: TextStyle(
                                            fontSize: 10, color: Colors.white),
                                      ),
                                child: Icon(
                                  Entypo.message,
                                  //AntDesign.message1,
                                  color: ConstColors.blackIconColors,
                                ),
                              );
                            } else {
                              return badges.Badge(
                                badgeContent: Text('1'),
                                showBadge: false,
                                child: Icon(
                                  Entypo.message,
                                  //AntDesign.message1,
                                  size: 30,

                                  color: ConstColors.blackIconColors,
                                ),
                              );
                            }
                          } else {
                            printVm("data: ${snapshot.data}");
                            return badges.Badge(
                              badgeContent: Text('1'),
                              showBadge: false,
                              child: Icon(
                                Entypo.message,
                                //AntDesign.message1,
                                size: 30,
                                color: ConstColors.blackIconColors,
                              ),
                            );
                          }
                        }),
                  ),
                  GestureDetector(
                      onTap: () {
                        Navigator.pushNamed(context, '/user_posts_form');
                      },
                      child: IconPersonaliser(icone: Icons.add_box, size: 40)),
                  IconButton(
                      onPressed: () {
                        /*
                        postProvider.getPostsVideos().then((value) {
                          if (value.length>0) {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => VideoCards(),));
                          }
                        },);

                         */

                        Navigator.pushNamed(context, '/videos');
                      },
                      icon: Icon(
                        Icons.video_library_rounded,
                        size: 30,
                        color: ConstColors.blackIconColors,
                      )),
                  IconButton(
                      onPressed: () {
                        printVm('tap');
                        _scaffoldKey.currentState!.openDrawer();
                        // Scaffold.of(_scaffoldKey.currentContext!).openDrawer();
                      },
                      icon: Icon(
                        Icons.menu,
                        size: 30,
                        color: ConstColors.blackIconColors,
                      )),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
