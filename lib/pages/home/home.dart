import 'dart:async';
import 'dart:math';
import 'package:afrotok/pages/home/slive/utils.dart';
import 'package:animated_icon/animated_icon.dart';
import 'package:afrotok/pages/home/postUserWidget.dart';
import 'package:afrotok/pages/home/users_cards/allUsersCard.dart';
import 'package:afrotok/pages/ia/gemini/geminibot.dart';
import 'package:auto_animated/auto_animated.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';
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
import 'package:badges/badges.dart' as badges;
import 'package:flutter/services.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:intl/intl.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:popup_menu_plus/popup_menu_plus.dart';
import 'package:provider/provider.dart';
import 'package:random_color/random_color.dart';
import 'package:share_plus/share_plus.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:upgrader/upgrader.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../constant/custom_theme.dart';
import '../UserServices/ServiceWidget.dart';
import '../UserServices/listUserService.dart';
import '../UserServices/newUserService.dart';
import '../afroshop/marketPlace/acceuil/home_afroshop.dart';
import '../afroshop/marketPlace/component.dart';
import '../afroshop/marketPlace/modalView/bottomSheetModalView.dart';
import '../component/showUserDetails.dart';
import '../../constant/textCustom.dart';
import '../../models/chatmodels/message.dart';
import '../../providers/afroshop/authAfroshopProvider.dart';
import '../../providers/afroshop/categorie_produits_provider.dart';
import '../../providers/authProvider.dart';

import '../component/consoleWidget.dart';
import '../ia/compagnon/introIaCompagnon.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../user/conponent.dart';


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
  late int app_version_code=0;

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
  List<Post> listConstposts=[];
  List<ArticleData> articles=[];
  List<UserServiceData> userServices=[];

  DocumentSnapshot? lastDocument;
  bool isLoading = false;

  Future<void> _launchUrl(Uri url) async {
    if (!await launchUrl(url)) {
      throw Exception('Could not launch $url');
    }
  }

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
  StreamController<List<Post>> _streamController = StreamController<List<Post>>();
  bool _buttonEnabled = true;
  RandomColor _randomColor = RandomColor();

  final ScrollController _scrollController = ScrollController();
  Color _color =Colors.blue;

  int postLenght = 8;
  int limitePosts = 100;
  int limiteUsers = 110;
  bool is_actualised = false;
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
  List<UserData> userList=[];
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
                        ? Text('Supprimer')
                        : Text('Supprimer'),
                  ),
                ),

                // Visibility(
                //   visible: post.user!.id == authProvider.loginUserData.id,
                //   child: ListTile(
                //     onTap: () async {
                //       if (authProvider.loginUserData.role == UserRole.ADM.name) {
                //         post.status = PostStatus.NONVALIDE.name;
                //         await postProvider.updateVuePost(post, context).then(
                //           (value) {
                //             if (value) {
                //               SnackBar snackBar = SnackBar(
                //                 content: Text(
                //                   'Post bloqué !',
                //                   textAlign: TextAlign.center,
                //                   style: TextStyle(color: Colors.green),
                //                 ),
                //               );
                //               ScaffoldMessenger.of(context)
                //                   .showSnackBar(snackBar);
                //             } else {
                //               SnackBar snackBar = SnackBar(
                //                 content: Text(
                //                   'échec !',
                //                   textAlign: TextAlign.center,
                //                   style: TextStyle(color: Colors.red),
                //                 ),
                //               );
                //               ScaffoldMessenger.of(context)
                //                   .showSnackBar(snackBar);
                //             }
                //           },
                //         );
                //       } else if (post.type == PostType.POST.name) {
                //         if (post.user!.id == authProvider.loginUserData.id) {
                //           post.status = PostStatus.SUPPRIMER.name;
                //           await postProvider.updateVuePost(post, context).then(
                //             (value) {
                //               if (value) {
                //                 SnackBar snackBar = SnackBar(
                //                   content: Text(
                //                     'Post supprimé !',
                //                     textAlign: TextAlign.center,
                //                     style: TextStyle(color: Colors.green),
                //                   ),
                //                 );
                //                 ScaffoldMessenger.of(context)
                //                     .showSnackBar(snackBar);
                //               } else {
                //                 SnackBar snackBar = SnackBar(
                //                   content: Text(
                //                     'échec !',
                //                     textAlign: TextAlign.center,
                //                     style: TextStyle(color: Colors.red),
                //                   ),
                //                 );
                //                 ScaffoldMessenger.of(context)
                //                     .showSnackBar(snackBar);
                //               }
                //             },
                //           );
                //         }
                //       }
                //
                //       setState(() {
                //         Navigator.pop(context);
                //       });
                //     },
                //     leading: Icon(
                //       Icons.delete,
                //       color: Colors.red,
                //     ),
                //     title: authProvider.loginUserData.role == UserRole.ADM.name
                //         ? Text('Bloquer')
                //         : Text('Supprimer'),
                //   ),
                // ),
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

  void _showDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Mettez en ligne vos services'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 10,
            children: [
              AnimateIcon(
                key: UniqueKey(),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => UserServiceListPage(),));

                },
                iconType: IconType.continueAnimation,
                height: 70,
                width: 70,
                color: Colors.green,
                animateIcon: AnimateIcons.settings,
              ),

              Text(
                  'Il est désormais temps de mettre en ligne vos services et savoir-faire sur Afrolook afin qu\'une personne proposant un job puisse vous contacter.'),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: Text(
                'Aller à la liste de services',
                style: TextStyle(color: Colors.white),
              ),
              style: TextButton.styleFrom(
                backgroundColor: Colors.green, // Couleur du bouton
              ),
              onPressed: () {
                // Naviguer vers la page de liste de services
                Navigator.pop(context);
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => UserServiceListPage()));
              },
            ),
          ],
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
    late Random random = Random();
    late int     imageNumber = random.nextInt(8) + 1; // Génère un nombre entre 1 et 6

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
              onTap: () async {
                await  authProvider.getUserById(user.id!).then((users) async {
                  if(users.isNotEmpty){
                    showUserDetailsModalDialog(users.first, w, h,context);

                  }
                },);

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
                            height: 110,
                            // width: w,
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
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                              
                                    children: [
                                      Container(
                                        alignment: Alignment.center,
                                        child: TextCustomerPostDescription(
                                          titre: '@${user.pseudo!.startsWith('@') ? user.pseudo!.replaceFirst('@', '') : user.pseudo!}',
                                          fontSize: 17,
                                          couleur: Colors.white,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          Column(
                                            children: [
                                              Container(
                                                alignment: Alignment.center,
                                                child: TextCustomerPostDescription(
                                                  titre: "${user.abonnes} Abonnés  ",
                                                  fontSize: 11,
                                                  couleur: Colors.yellow,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                spacing: 2,
                                                children: [
                                                  Icon(Icons.group,size: 13,color: Colors.blue,),
                                                  Container(
                                                    alignment: Alignment.center,
                                                    child: TextCustomerPostDescription(
                                                      titre: "${user.usersParrainer!.length} parrainages  ",
                                                      fontSize: 11,
                                                      couleur: Colors.yellow,
                                                      fontWeight: FontWeight.w900,
                                                    ),
                                                  ),

                                                ],
                                              ),

                                            ],
                                          ),

                                          countryFlag(user.countryData!['countryCode']??""!, size: 20),

                                        ],
                                      ),

                                    ],
                                  ),
                                  SizedBox(width: 10,),

                              
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Positioned(
                    //   top: 0.0,
                    //   right: 0.0,
                    //   // left: 0.0,
                    //   child: Image.asset("assets/userEticket/2.png",height: 50,width: 50,),
                    // ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }



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
                              TextCustomerUserTitle(
                                titre:
                                "${formatNumber(authProvider.loginUserData!.userlikes!)} like(s)",
                                fontSize: SizeText.homeProfileTextSize,
                                couleur: Colors.green,
                                fontWeight: FontWeight.w700,
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
                  ListTile(
                    trailing: Icon(Icons.arrow_right_outlined, color: Colors.green),
                    leading: Icon(Icons.storefront_outlined, color: Colors.green),
                    title: TextCustomerMenu(
                      titre: "Afroshop MarketPlace",
                      fontSize: SizeText.homeProfileTextSize,
                      couleur: ConstColors.textColors,
                      fontWeight: FontWeight.w600,
                    ),
                    onTap: () async {


                      Navigator.push(context, MaterialPageRoute(builder: (context) => HomeAfroshopPage(title: ''),));
                    },
                  ),

                  ListTile(
                    trailing: Icon(Icons.arrow_right_outlined, color: Colors.green),

                    leading:           AnimateIcon(
                      key: UniqueKey(),
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => UserServiceListPage(),));

                      },
                      iconType: IconType.continueAnimation,
                      height: 30,
                      width: 30,
                      color: Colors.green,
                      animateIcon: AnimateIcons.settings,
                    ),
                    title: TextCustomerMenu(
                      titre: "🛠️Services & Jobs 💼",
                      fontSize: SizeText.homeProfileTextSize,
                      couleur: ConstColors.textColors,
                      fontWeight: FontWeight.w600,
                    ),
                    subtitle: TextCustomerMenu(
                      titre: "Chercher des gens pour bosser",
                      fontSize: 9,
                      couleur: ConstColors.textColors,
                      fontWeight: FontWeight.w600,
                    ),
                    onTap: () async {
                      // setState(() {
                      //   onTap = true;
                      // });

                      Navigator.push(context, MaterialPageRoute(builder: (context) => UserServiceListPage(),));


                      // Navigator.pushNamed(context, '/intro_ia_compagnon');
                    },
                  ),
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
                                  // Navigator.push(context, MaterialPageRoute(builder: (context) => GeminiTextChat(),));
                                  // Navigator.push(context, MaterialPageRoute(builder: (context) => GeminiChat(),));
                                  Navigator.push(context, MaterialPageRoute(builder: (context) => GeminiChatBot(title: 'BOT XILO', instruction: '${authProvider.appDefaultData.ia_instruction!}', userIACompte: value.first,),));

                                  // Navigator.push(context, MaterialPageRoute(builder: (context) => IaChat(
                                  //         chat: chat,
                                  //         user: authProvider.loginUserData,
                                  //         userIACompte: value.first,
                                  //         instruction:
                                  //             '${authProvider.appDefaultData.ia_instruction!}',
                                  //       ),
                                  //     ));
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
                      titre: "TOP 10 Afrolook Stars",
                      fontSize: SizeText.homeProfileTextSize,
                      couleur: ConstColors.textColors,
                      fontWeight: FontWeight.w600,
                    ),
                    onTap: () async {
                      // Add your navigation logic here

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
                      titre: "Challenge",
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
            Text('Version: 1.1.11 (37)',style: TextStyle(fontWeight: FontWeight.bold),),
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
  Future<void> _checkAndShowDialog() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String lastShownDate = prefs.getString('lastShownDate') ?? '';

    String todayDate = DateTime.now().toIso8601String().split('T')[0];

    if (lastShownDate != todayDate) {
      // Show the dialog
      Timer(Duration(seconds: 20), () {
        _showDialog();
      });
      showDialog(
        context: context,
        builder: (context) => Dialog(
          child: ArticleBottomSheet(),
        ),
      );
      // Update the last shown date
      await prefs.setString('lastShownDate', todayDate);
    }
  }

  @override
  void initState() {
    super.initState();

    hasShownDialogToday().then((value) async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      authProvider.getAppData().then((value) {
        // setState(() {});
      });
      categorieProduitProvider.getArticleBooster().then((value) {
        articles = value;
        // setState(() {});
      });

      postProvider.getAllUserServiceHome().then((value) {
        userServices = value;
        userServices.shuffle();
        // setState(() {});
      });

      if (value && mounted) {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('Nouvelle offre sur Afrolook'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Image.asset("assets/images/bonus_afrolook.jpg", fit: BoxFit.cover),
                    SizedBox(height: 5),
                    Icon(FontAwesome.money, size: 50, color: Colors.green),
                    SizedBox(height: 10),
                    Text('Vous avez la possibilité de'),
                    Text('gagner 5 PubliCashs', style: TextStyle(color: Colors.green)),
                    Text(
                      'chaque fois qu\'un nouveau s\'inscrit avec votre code de parrainage...',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: Text('OK'),
                  onPressed: () {
                    Navigator.of(context).pop();
                    prefs.setString('lastShownDateKey', DateTime.now().toString());
                  },
                ),
              ],
            );
          },
        );
      }
      _checkAndShowDialog();
    });

    authProvider.getToken().then((token) async {
      printVm("token: ${token}");
      postProvider.getPostsImages2(limitePosts).listen((data) {
        if (!_streamController.isClosed) {
          _streamController.add(data);
        }
      });

      if (token == null || token == '') {
        printVm("token: existe pas");
        Navigator.pushNamed(context, '/welcome');
      }
    });

    WidgetsBinding.instance.addObserver(this);

    SystemChannels.lifecycle.setMessageHandler((message) {
      printVm('stategb:  --- ${message}');

      if (message!.contains('resume')) {
        printVm('state en ligne:  --- ${message}');
        if (authProvider.loginUserData != null) {
          authProvider.loginUserData!.isConnected = true;
          userProvider.changeState(user: authProvider.loginUserData, state: UserState.ONLINE.name);
        }
      } else {
        printVm('state hors ligne :  --- ${message}');
        if (authProvider.loginUserData != null) {
          authProvider.loginUserData!.isConnected = false;
          userProvider.changeState(user: authProvider.loginUserData, state: UserState.OFFLINE.name);
        }
        getAndUpdateChatsData();
      }
      return Future.value(message);
    });
  }

  @override
  void dispose() {
    _streamController.close();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.detached:
        // _onDetached();
        _onPaused();
        break;
      case AppLifecycleState.resumed:
        _onPaused();
        // _onResumed();
        break;
      case AppLifecycleState.inactive:
        // _onInactive();
        _onPaused();
        break;
      case AppLifecycleState.paused:
        _onPaused();
        break;
      default:
        if (authProvider.loginUserData != null) {
          authProvider.loginUserData!.isConnected = true;
          userProvider.changeState(user: authProvider.loginUserData, state: UserState.ONLINE .name);
        }
        break;
    }
  }


  void _onDetached() {
    // Logique pour l'état detached
    if (authProvider.loginUserData != null) {
      authProvider.loginUserData!.isConnected = false;
      userProvider.changeState(user: authProvider.loginUserData, state: UserState.OFFLINE .name);
    }
  }

  void _onResumed() {
    // Logique pour l'état resumed
    if (authProvider.loginUserData != null) {
      authProvider.loginUserData!.isConnected = true;
      userProvider.changeState(user: authProvider.loginUserData, state: UserState.ONLINE.name);
    }
  }

  void _onInactive() {
    // Logique pour l'état inactive
    if (authProvider.loginUserData != null) {
      authProvider.loginUserData!.isConnected = false;
      userProvider.changeState(user: authProvider.loginUserData, state: UserState.OFFLINE .name);
    }
  }

  void _onPaused() {
    if (authProvider.loginUserData != null) {
      authProvider.loginUserData!.isConnected = false;
      userProvider.changeState(user: authProvider.loginUserData, state: UserState.OFFLINE .name);
    }  }




  int _currentIndex = 0;
  final PageController _pageController = PageController();

  @override
  Widget build(BuildContext context) {
    app_version_code=36;
    _color=  _randomColor.randomColor(
        colorHue: ColorHue.multiple(colorHues: [
          ColorHue.red,
          // ColorHue.blue,
          // ColorHue.green,
          ColorHue.orange,
          ColorHue.yellow,
          ColorHue.purple
        ]));
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
          // postProvider.getPostsImages(limitePosts).then(
          //       (value) {},
          //     );
          // postProvider.getPostsVideos().then((value) {
          //
          // },);

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
              // IconButton(
              //     onPressed: () async {
              //       // _scrollController.animateTo(
              //       //   0.0,
              //       //   duration: Duration(milliseconds: 1000),
              //       //   curve: Curves.ease,
              //       // );
              //       // setState(() {
              //       //   postProvider
              //       //       .reloadPostsImages(limitePosts, _scrollController)
              //       //       .then(
              //       //         (value) {},
              //       //       );
              //       //   postProvider.getPostsVideos().then((value) {
              //       //
              //       //   },);
              //       //
              //       // });
              //     },
              //     icon: Icon(FontAwesome.refresh)),
          AnimateIcon(
            key: UniqueKey(),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => UserServiceListPage(),));

            },
            iconType: IconType.continueAnimation,
            height: 70,
            width: 70,
            color: Colors.green,
            animateIcon: AnimateIcons.settings,
          ),
          AnimateIcon(
            key: UniqueKey(),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => HomeAfroshopPage(title: ''),));

            },
            iconType: IconType.continueAnimation,
            height: 70,
            width: 70,
            color: Colors.green,
            animateIcon: AnimateIcons.paid,
          ),
              GestureDetector(
                onTap: () async {
                  if (_scrollController.hasClients) {

                    _scrollController.animateTo(
                      0.0,
                      duration: Duration(milliseconds: 1000),
                      curve: Curves.ease,
                    );
                  }
                  setState(() {
                    listConstposts.clear();
                    postProvider.getPostsImages2(limitePosts).listen((data) {
                      _streamController.add(data);
                    });
                  });

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
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Image.asset("assets/icon/cocotier-home.png",height: 30,width: 30,),
                  )),
//               IconButton(
//                   onPressed: () async {
//                     if (_scrollController.hasClients) {
//
//                       _scrollController.animateTo(
//                         0.0,
//                         duration: Duration(milliseconds: 1000),
//                         curve: Curves.ease,
//                       );
//                       }
//                     setState(() {
// listConstposts.clear();
// postProvider.getPostsImages2(limitePosts).listen((data) {
//   _streamController.add(data);
// });
//                     });
//
//                     // setState(() {
//                     //   postProvider.getHomePostsImages(limitePosts).then((value) {
//                     //
//                     //   },);
//                     // });
//
//                     //   Restart.restartApp();
//
//                     /*
//                 await userProvider.getAllAnnonces();
//                 await postProvider.getPostsImages(limitePosts).then((value) {
//                   printVm('actualiser');
//                   setState(() {
//                     postLenght=8;
//                     is_actualised = false;
//
//                   });
//
//
//                 },);
//
//                  */
//                   },
//                   icon: Icon(Icons.home))
            ],
            //title: Text(widget.title),
          ),
          drawer: menu(context),
          body: SafeArea(
            child: CustomScrollView(

              controller: _scrollController,
              slivers: <Widget>[
                SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                  sliver: SliverToBoxAdapter(
                    child: Row(

                      children: [
                        app_version_code== authProvider.appDefaultData.app_version_code?  Container(): ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          onPressed: () {
    authProvider.getAppData().then((value) {

      _launchUrl(Uri.parse('${authProvider.appDefaultData.app_link}'));

    });
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [

                              Text('Faire la mise à jour',
                                style: TextStyle(color: Colors.white,fontWeight: FontWeight.bold),),
                            ],
                          ),

                        ),


                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                          onPressed: () {
                            _launchUrl(Uri.parse('https://www.kwendoo.com/cagnottes/soutenir-afrolook'));
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [

                              Text('🎁 Faire un don 🙏',
                                style: TextStyle(color: Colors.white,fontWeight: FontWeight.bold),),
                            ],
                          ),

                        ),

                      ],
                      mainAxisAlignment:
                      MainAxisAlignment
                          .spaceBetween,
                    ),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                  sliver: FutureBuilder<List<UserData>>(
                    future: userProvider.getProfileUsers(
                      authProvider.loginUserData.id!,
                      context,
                      limiteUsers,
                    ),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return SliverToBoxAdapter(
                          child: SizedBox(
                              height: height * 0.35,

                              child: widgetSeke2(width, height)),
                        );
                      } else if (snapshot.hasError) {
                        return SliverToBoxAdapter(
                          child: SizedBox(
                              height: height * 0.35,

                              child: widgetSeke2(width, height)),
                        );
                      } else {
                        List<UserData> list = snapshot.data!;
                        userList=list;
                        userList.shuffle();

                        return SliverToBoxAdapter(
                          child: SizedBox(
                            height: height * 0.35,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: list.length,
                              itemBuilder: (context, index) {
                                return homeProfileUsers(list[index], width, height);
                              },
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ),
                SliverPadding
                  (
                  padding: EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                  sliver: FutureBuilder<List<Challenge>>(
                    future: postProvider.getCurrentChallenges(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return SliverToBoxAdapter(
                          child: Center(child: CircularProgressIndicator()),
                        );
                      } else if (snapshot.hasError) {
                        return SliverToBoxAdapter(
                          child: Center(child: CircularProgressIndicator()),
                        );
                      } else {
                        List<Challenge> list = snapshot.data!;
                        list;
                        // userList.shuffle();
                        if(list.isEmpty){
                          return SizedBox.shrink();
                        }else{
                          return SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'Challenges Disponibles 🔥🎁',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.orange, // Couleur du texte pour attirer l'attention
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Icon(
                                        Icons.local_fire_department, // Icône de feu pour illustrer l'excitation
                                        color: Colors.red, // Couleur du feu
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'Gagnez un Prix 🏆',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green, // Couleur du texte pour un appel à l'action positif
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Icon(
                                        Icons.card_giftcard, // Icône de cadeau pour symboliser la récompense
                                        color: Colors.green, // Couleur du cadeau
                                      ),
                                    ],
                                    mainAxisAlignment: MainAxisAlignment.start,
                                  )
                              ,
                                  SizedBox(
                                    height: height * 0.58,
                                    // width: width * 0.8,
                                    child: ListView.builder(
                                      scrollDirection: Axis.horizontal,
                                      itemCount: list.length,
                                      itemBuilder: (context, index) {
                                        return homeChallenge(
                                          list[index]!,
                                          Colors.brown,
                                          height,
                                          width,
                                          context,
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );

                        }

                      }
                    },
                  ),
                ),
                // SliverPadding(
                //   padding: EdgeInsets.symmetric(horizontal: 1, vertical: 0),
                //   sliver:  Divider(),
                // ),


                SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                  sliver: StreamBuilder<List<Post>>(
                    stream: _streamController.stream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return SliverToBoxAdapter(
                          child: Center(child: CircularProgressIndicator()),
                        );
                      } else if (snapshot.hasError) {
                        return SliverToBoxAdapter(
                          child: Center(child: Icon(Icons.error)),
                        );
                      } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return SliverToBoxAdapter(
                          child: Center(child: Text('Pas de looks')),
                        );
                      }
                      List<Post> listConstposts = snapshot.data!;


                      return LiveSliverList(

                        controller: _scrollController,
                        showItemInterval: Duration(milliseconds: 10),
                        showItemDuration: Duration(milliseconds: 30),
                        itemCount: listConstposts.length,
                        itemBuilder: animationItemBuilder(

                                (index) {
    if (index % 7 == 6) {
      return SizedBox(
        height: height * 0.35,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: userList.length,
          itemBuilder: (context, index) {
            return homeProfileUsers(userList[index], width, height);
          },
        ),
      );
    }
    if (index % 9 == 8) {
      return articles.isEmpty?SizedBox.shrink(): SizedBox(
              height: height * 0.35,
              child: Column(
       children: [
         Padding(
           padding: const EdgeInsets.all(8.0),
           child: Row(
             mainAxisAlignment: MainAxisAlignment.spaceBetween,
             children: [
               Row(
                 children: [
                   Text(
                     'Produits Boostés',
                     style: TextStyle(
                         fontSize: 15,
                         fontWeight: FontWeight.bold,
                         color: Colors.green),
                   ),
                   SizedBox(width: 8),
                   Icon(
                     Icons.local_fire_department,
                     color: Colors.red,
                   ),
                 ],
                 mainAxisAlignment: MainAxisAlignment.start,
               ),
               GestureDetector(
                 onTap: () {
                   Navigator.push(
                     context,
                     MaterialPageRoute(
                       builder: (context) => HomeAfroshopPage(title: ''),
                     ),
                   );
                 },
                 child: Row(
                   children: [
                     Text(
                       'Boutiques',
                       style: TextStyle(
                           fontSize: 15,
                           fontWeight: FontWeight.bold,
                           color: Colors.green),
                     ),
                     SizedBox(width: 8),
                     Icon(
                       Icons.storefront,
                       color: Colors.red,
                     ),
                   ],
                   mainAxisAlignment: MainAxisAlignment.start,
                 ),
               ),
             ],
           ),
         ),
         Container(
           child: CarouselSlider(
             items: articles.map((article) {
               return Builder(
                 builder: (BuildContext context) {
                   return ArticleTileBooster(
                       article: article, w: width, h: height, isOtherPage: true);
                 },
               );
             }).toList(),
             options: CarouselOptions(
               height: 250,
               autoPlay: true,
               enlargeCenterPage: true,
               viewportFraction: 0.6,
             ),
           ),
         ),
       ],
              ),
            );
    }

    if (index % 6 == 5) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      '🛠️Services & Jobs 💼',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.green),
                    ),

                  ],
                  mainAxisAlignment: MainAxisAlignment.start,
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => UserServiceListPage(),
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      Text(
                        'Voir plus 🛠️ 💼',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.green),
                      ),

                    ],
                    mainAxisAlignment: MainAxisAlignment.start,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(
            height: height * 0.3,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: userServices.length,
              itemBuilder: (context, index) {
                return userServiceWidget(userServices[index], width, height,context);
              },
            ),
          ),
        ],
      );
    }


    return homePostUsers(
                                    listConstposts[index],
                                    Colors.brown,
                                    height,
                                    width,
                                    context,
                                  );
                                },
                            padding: EdgeInsets.symmetric(vertical: 8)),
                      );
                    },
                  ),
                ),
              ],
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
