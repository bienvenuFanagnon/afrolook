import 'dart:async';
import 'dart:math';
import 'package:afrotok/pages/canaux/listCanal.dart';
import 'package:afrotok/pages/chat/chatXilo.dart';
import 'package:afrotok/pages/chat/deepseek.dart';
import 'package:afrotok/pages/classements/userClassement.dart';
import 'package:afrotok/pages/home/homeActu.dart';
import 'package:afrotok/pages/home/homeEvent.dart';
import 'package:afrotok/pages/home/homeLooks.dart';
import 'package:afrotok/pages/home/homeOffre.dart';
import 'package:afrotok/pages/home/homeSport.dart';
import 'package:afrotok/pages/home/slive/utils.dart';
import 'package:afrotok/pages/story/afroStory/repository.dart';
import 'package:afrotok/pages/story/afroStory/storie/mesChronique.dart';
import 'package:afrotok/pages/story/afroStory/storie/storyFormChoise.dart';
import 'package:afrotok/pages/userPosts/challenge/listChallenge.dart';
import 'package:animated_icon/animated_icon.dart';
import 'package:afrotok/pages/home/users_cards/allUsersCard.dart';
import 'package:auto_animated/auto_animated.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:afrotok/providers/postProvider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:afrotok/constant/constColors.dart';
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
import '../chat/ia_Chat.dart';
import '../component/showUserDetails.dart';
import '../../constant/textCustom.dart';
import '../../models/chatmodels/message.dart';
import '../../providers/afroshop/authAfroshopProvider.dart';
import '../../providers/afroshop/categorie_produits_provider.dart';
import '../../providers/authProvider.dart';

import '../component/consoleWidget.dart';
import '../ia/compagnon/introIaCompagnon.dart';

import 'package:shared_preferences/shared_preferences.dart';
import '../ia/gemini/geminibot.dart';
import '../story/afroStory/storie/storyView.dart';
import '../user/conponent.dart';
import '../userPosts/challenge/lookChallenge/mesLookChallenge.dart';
import '../userPosts/postWidgets/postUserWidget.dart';
import '../userPosts/postWidgets/postWidgetPage.dart';
import 'homeGamer.dart';


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
  double homeIconSize = 20;
  // late int app_version_code=0;

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
  List<Canal> canaux=[];
  Color _color =Colors.blue;
  TabController? _tabController;

  // Liste des onglets avec texte et icônes
  final List<Tab> _tabs = [
    Tab(text: 'Looks', icon: Icon(Icons.style)),
    Tab(text: 'Actu', icon: Icon(Icons.article)), // Abrégé pour "Actualités"
    Tab(text: 'Sport', icon: Icon(Icons.sports)),
    Tab(text: 'Évén.', icon: Icon(Icons.event)), // Abrégé pour "Événement"
    Tab(text: 'Offres', icon: Icon(Icons.local_offer)),
    Tab(text: 'Gamer', icon: Icon(Icons.gamepad)),
  ];
  DocumentSnapshot? lastDocument;
  bool isLoading = false;
  void _changeColor() {
    final List<Color> colors = [
      Colors.blue,
      Colors.green,
      Colors.brown,
      Colors.blueAccent,
      Colors.red,
      Colors.yellow,
    ];
    final random = Random();
    _color = colors[random.nextInt(colors.length)];
  }
  Future<void> _launchUrl(Uri url) async {
    if (!await launchUrl(url)) {
      throw Exception('Could not launch $url');
    }
  }



  Future<void> checkAppVersionAndProceed(BuildContext context, Function onSuccess) async {
    await authProvider.getAppData().then((appdata) async {
      print("code app data *** : ${authProvider.appDefaultData.app_version_code}");
      if (!authProvider.appDefaultData.googleVerification!) {
        if (authProvider.app_version_code == authProvider.appDefaultData.app_version_code) {
          onSuccess();
        } else {
          showModalBottomSheet(
            context: context,
            builder: (BuildContext context) {
              return Container(
                height: 300,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(Icons.info, color: Colors.red),
                        Text(
                          'Nouvelle mise à jour disponible!',
                          style: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 10.0),
                        Text(
                          'Une nouvelle version de l\'application est disponible. Veuillez télécharger la mise à jour pour profiter des dernières fonctionnalités et améliorations.',
                          style: TextStyle(fontSize: 16.0),
                        ),
                        SizedBox(height: 20.0),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                          onPressed: () {
                            _launchUrl(Uri.parse('${authProvider.appDefaultData.app_link}'));
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Ionicons.ios_logo_google_playstore, color: Colors.white),
                              SizedBox(width: 5),
                              Text(
                                'Télécharger sur le play store',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        }

      }else{
        onSuccess();

      }

    });
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

  int postLenght = 8;
  int limitePosts = 100;
  int limiteUsers = 200;
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



  void _showServiceDialog() {
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
  void _showChatXiloDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return ChatXiloPage(
          userName: authProvider.loginUserData.pseudo!,
          userGender: authProvider.loginUserData.genre!,
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







  Widget menu(BuildContext context,double w,h) {
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
                  GestureDetector(
                    onTap: () {
                      showUserDetailsModalDialog(authProvider.loginUserData, w, h,context);

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
                                    '${authProvider.loginUserData.imageUrl!}'),
                                onBackgroundImageError: (exception, stackTrace) =>
                                    AssetImage(
                                        "assets/icon/user-removebg-preview.png"),
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
                                        titre:
                                        "@${authProvider.loginUserData.pseudo}",
                                        fontSize: SizeText.homeProfileTextSize,
                                        couleur: ConstColors.textColors,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    TextCustomerUserTitle(
                                      titre:
                                      "${formatNumber(authProvider.loginUserData.userAbonnesIds!.length!)} abonné(s)",
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
                                SizedBox(width: 5,),
                                Visibility(
                                  visible: authProvider.loginUserData!.isVerify!,
                                  child: const Icon(
                                    Icons.verified,
                                    color: Colors.green,
                                    size: 20,
                                  ),
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
                  ListTile(
                    trailing: TextCustomerMenu(
                      titre: "Discuter",
                      fontSize: SizeText.homeProfileTextSize,
                      couleur: Colors.blue,
                      fontWeight: FontWeight.w600,
                    ),
                    leading: CircleAvatar(
                      radius: 15, // Taille de l'avatar
                      backgroundImage: AssetImage('assets/icon/X.png'),
                    ),
                    title: TextCustomerMenu(
                      titre: "Xilo",
                      fontSize: SizeText.homeProfileTextSize,
                      couleur: ConstColors.textColors,
                      fontWeight: FontWeight.w600,
                    ),
                    subtitle: TextCustomerMenu(
                      titre: "Votre ami(e)",
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
                                  // Navigator.push(context, MaterialPageRoute(builder: (context) => DeepSeepChat(instruction: '${authProvider.appDefaultData.ia_instruction!}'),));
                                  // Navigator.push(context, MaterialPageRoute(builder: (context) => GeminiChatBot(title: 'BOT XILO', instruction: '${authProvider.appDefaultData.ia_instruction!}', userIACompte: value.first, apiKey:'${authProvider.appDefaultData.geminiapiKey!}' ,),));

                                  Navigator.push(context, MaterialPageRoute(builder: (context) => IaChat(
                                    chat: chat,
                                    user: authProvider.loginUserData,
                                    userIACompte: value.first,
                                    instruction:
                                    '${authProvider.appDefaultData.ia_instruction!}', appDefaultData: authProvider.appDefaultData,
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
                    trailing:
                    Icon(Icons.arrow_right_outlined, color: Colors.green),
                    leading: Icon(FontAwesome.forumbee,size: 30,color: Colors.green,),
                    title: TextCustomerMenu(
                      titre: "Canaux",
                      fontSize: SizeText.homeProfileTextSize,
                      couleur: ConstColors.textColors,
                      fontWeight: FontWeight.w600,
                    ),
                    onTap: () async {
                      // Add your navigation logic here
                      Navigator.push(context, MaterialPageRoute(builder: (context) => CanalListPage(isUserCanals: false),));


                    },
                  ),
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

                      await userProvider.getAllUsers().then(
                            (value) {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => UserClassement(),));
                        },
                      );

                    },
                  ),
                  ListTile(
                    trailing:
                    Icon(Icons.arrow_right_outlined, color: Colors.green,),
                    leading: Icon(Icons.history_toggle_off_sharp,size: 30,),
                    title: TextCustomerMenu(
                      titre: "Mes chroniques",
                      fontSize: SizeText.homeProfileTextSize+3,
                      couleur: ConstColors.textColors,
                      fontWeight: FontWeight.w900,
                    ),
                    onTap: () async {
                      // Add your navigation logic here

                      Navigator.push(context, MaterialPageRoute(builder: (context) => MyStoriesPage(stories: authProvider.loginUserData.stories!, user: authProvider.loginUserData),));


                    },
                  ),
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
                    trailing:
                    Icon(Icons.arrow_right_outlined, color: Colors.green),
                    leading: Image.asset(
                      'assets/menu/6.png',
                      height: 20,
                      width: 20,
                    ),
                    title: TextCustomerMenu(
                      titre: "Challenges Disponibles 🔥🎁  Gagnez un Prix 🏆",
                      fontSize: SizeText.homeProfileTextSize,
                      couleur: ConstColors.textColors,
                      fontWeight: FontWeight.w600,
                    ),
                    onTap: () async {
                      // Add your navigation logic here
                      Navigator.push(context, MaterialPageRoute(builder: (context) => ChallengeListPage(),));

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
                      titre: "Mes Looks Challenges 🔥🎁🏆",
                      fontSize: SizeText.homeProfileTextSize,
                      couleur: ConstColors.textColors,
                      fontWeight: FontWeight.w600,
                    ),
                    onTap: () async {
                      // Add your navigation logic here
                      Navigator.push(context, MaterialPageRoute(builder: (context) => MesLookChallengeListPage(),));

                    },
                  ),
                  // ListTile(
                  //   trailing:
                  //       Icon(Icons.arrow_right_outlined, color: Colors.green),
                  //   leading: Image.asset(
                  //     'assets/menu/6.png',
                  //     height: 20,
                  //     width: 20,
                  //   ),
                  //   title: TextCustomerMenu(
                  //     titre: "Gagner points Gratuitement",
                  //     fontSize: SizeText.homeProfileTextSize,
                  //     couleur: ConstColors.textColors,
                  //     fontWeight: FontWeight.w600,
                  //   ),
                  //   onTap: () async {
                  //     // Add your navigation logic here
                  //     await userProvider.getGratuitInfos().then(
                  //       (value) {
                  //         Navigator.pushNamed(context, '/gagner_point_infos');
                  //       },
                  //     );
                  //   },
                  // ),
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
            Text('Version: 1.1.32 (${authProvider.appDefaultData.app_version_code!})',style: TextStyle(fontWeight: FontWeight.bold),),
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
    // _showChatXiloDialog();

    if (lastShownDate != todayDate) {

      // _showChatXiloDialog();
      // Show the dialog
      // Timer(Duration(seconds: 20), () {
      //   _showServiceDialog();
      // });
      // showDialog(
      //   context: context,
      //   builder: (context) => Dialog(
      //     child: ArticleBottomSheet(),
      //   ),
      // );
      // Update the last shown date
      await prefs.setString('lastShownDate', todayDate);
    }
  }

  List<Post> listVideos=[];

  @override
  void initState() {
    // _changeColor();
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);

    checkAppVersionAndProceed(context, () {
    });
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
      postProvider.getCanauxHome().then((value) {
        canaux = value;
        canaux.shuffle();
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
      // postProvider.getPostsImages2(limitePosts).listen((data) {
      //   if (!_streamController.isClosed) {
      //     _streamController.add(data);
      //   }
      // });

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
    // postProvider.getPostsVideos3(limitePosts).then((value) {
    //   postProvider.listvideos=value;
    //   printVm('listVideos *****************************: ${postProvider.listvideos.length}');
    // },);
  }

  @override
  void dispose() {
    _tabController?.dispose();

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
    _changeColor();

    // _color=  _randomColor.randomColor(
    //     colorHue: ColorHue.multiple(colorHues: [
    //       ColorHue.red,
    //       // ColorHue.blue,
    //       // ColorHue.green,
    //       ColorHue.orange,
    //       ColorHue.yellow,
    //       ColorHue.purple
    //     ]));
    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;
    homeIconSize=width*0.065;

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
            backgroundColor: Colors.lightGreen.shade300,
            automaticallyImplyLeading: false,

            titleSpacing: 10,
            title: Text(
              // 'Afro Chronique',
              'Afrolook',
              style: TextStyle(
                fontSize: homeIconSize*0.7,
                fontWeight: FontWeight.w900,
                color: Colors.green,
                letterSpacing: 1.5,
              ),
            ),

            //backgroundColor: Colors.blue,
            actions: [

              GestureDetector(
                onTap: () async {
                  checkAppVersionAndProceed(context, () {
                    Navigator.pushNamed(context, "/mes_notifications");
                  });

                },
                child: StreamBuilder<List<NotificationData>>(
                  stream: authProvider
                      .getListNotificationAuth(authProvider.loginUserData.id!),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Image.asset("assets/icons/icons8-bell-188.png",width: homeIconSize,height: homeIconSize,);
                    } else if (snapshot.hasError) {
                      return Image.asset("assets/icons/icons8-bell-188.png",width: homeIconSize,height: homeIconSize,);
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
                          child: Image.asset("assets/icons/icons8-bell-188.png",width: homeIconSize,height: homeIconSize,)
                          ,
                        ),
                      );
                    }
                  },
                ),
              ),
              SizedBox(width: 10,),

              GestureDetector(
                onTap: () async {
                  _showChatXiloDialog();

                },
                child: CircleAvatar(
                  radius: 15, // Taille de l'avatar
                  backgroundImage: AssetImage('assets/icon/X.png'),
                ),
              ),
              SizedBox(width: 10,),
              AnimateIcon(
                key: UniqueKey(),
                onTap: () async {
                  checkAppVersionAndProceed(context, () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => UserServiceListPage(),));
                  });


                },
                iconType: IconType.continueAnimation,
                height: homeIconSize,
                width: homeIconSize,
                color: Colors.green,
                animateIcon: AnimateIcons.settings,
              ),
              SizedBox(width: 10,),

              AnimateIcon(
                key: UniqueKey(),
                onTap: () async {
                  checkAppVersionAndProceed(context, () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => HomeAfroshopPage(title: ''),));
                  });

                },
                iconType: IconType.continueAnimation,
                height: homeIconSize,
                width: homeIconSize,
                color: Colors.green,
                animateIcon: AnimateIcons.paid,
              ),
              SizedBox(width: 10,),

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
                      // postProvider.getPostsImages2(limitePosts).listen((data) {
                      //   _streamController.add(data);
                      // });
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
            ],
            bottom: TabBar(
              controller: _tabController,
              tabs: _tabs,
              labelColor: Color(0xFFE4A918), // Couleur du texte de l'onglet sélectionné
              // unselectedLabelColor: Colors.white, // Couleur du texte des onglets non sélectionnés
              unselectedLabelColor: Colors.green, // Couleur du texte des onglets non sélectionnés
              // unselectedLabelColor: Color(0xFFE4A918), // Couleur du texte des onglets non sélectionnés
              indicatorColor: Color(0xFFE4A918), // Couleur de l'indicateur de l'onglet sélectionné
            ),
            //title: Text(widget.title),
          ),
          drawer: menu(context,width,height),
          body: SafeArea(
            child: Container(

              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.lightGreen.shade200, // Noir plus dominant mais atténué
                    Colors.lightGreen.shade200, // Noir plus dominant mais atténué
                  ],
                ),
              ),
              child:TabBarView(
                controller: _tabController,
                children: [
                  Center(child: LooksPage(title: '')),
                  // Contenu de chaque onglet
                  Center(child: ActualitePage(title: '')),
                  Center(child: SportPage(title: '')),
                  Center(child: EventPage(title: '')),
                  Center(child: OffrePage(title: '')),
                  Center(child: GamerPage(title: '')),
                ],
              ),
            ),
          ),
          bottomNavigationBar: Container(
            height: 50,
            color:  Colors.lightGreen.shade300,
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
                                child: Image.asset("assets/icons/group3d.png",width: homeIconSize+18,height: homeIconSize+18,)
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
                                  child: Image.asset("assets/icons/group3d.png",width: homeIconSize+18,height: homeIconSize+18,)
                              );
                            } else {
                              return badges.Badge(
                                  badgeContent: Text('1'),
                                  showBadge: false,
                                  child: Image.asset("assets/icons/group3d.png",width: homeIconSize+18,height: homeIconSize+18,)
                              );
                            }
                          } else {
                            printVm("data: ${snapshot.data}");
                            return badges.Badge(
                                badgeContent: Text('1'),
                                showBadge: false,
                                child: Image.asset("assets/icons/group3d.png",width: homeIconSize+18,height: homeIconSize+18,)
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
                              child: Image.asset("assets/icons/chat3d.png",width: homeIconSize+15,height: homeIconSize+15,),
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
                                child: Image.asset("assets/icons/chat3d.png",width: homeIconSize+15,height: homeIconSize+15,),
                              );
                            } else {
                              return badges.Badge(
                                badgeContent: Text('1'),
                                showBadge: false,
                                child: Image.asset("assets/icons/chat3d.png",width: homeIconSize+15,height: homeIconSize+15,),
                              );
                            }
                          } else {
                            printVm("data: ${snapshot.data}");
                            return badges.Badge(
                              badgeContent: Text('1'),
                              showBadge: false,
                              child: Image.asset("assets/icons/chat3d.png",width: homeIconSize+15,height: homeIconSize+15,),
                            );
                          }
                        }),
                  ),
                  GestureDetector(
                      onTap: () {
                        checkAppVersionAndProceed(context, () {
                          Navigator.pushNamed(context, '/user_posts_form');
                        });

                      },
                      child: Image.asset('assets/icons/icons8-plus-188.png',width: homeIconSize+10,height: homeIconSize+10,)),
                  GestureDetector(
                    onTap: () {
                      Navigator.pushNamed(context, '/videos');

                    },
                    child:                       badges.Badge(

                        badgeContent:
                        Text(
                          '9+',
                          style: TextStyle(
                              fontSize: 9, color: Colors.white),
                        ),
                        child: Image.asset("assets/icons/video3d.png",width: homeIconSize+15,height: homeIconSize+15,)
                    ),),
                  GestureDetector(
                      onTap: () {
                        checkAppVersionAndProceed(context, () {
                          _scaffoldKey.currentState!.openDrawer();
                        });
                      },
                      child: Image.asset('assets/icons/menu3d.png',width: homeIconSize+15,height: homeIconSize+15,)),

                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
