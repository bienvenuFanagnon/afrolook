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
import 'package:afrotok/pages/home/topFiveModal.dart';
import 'package:afrotok/pages/home/unitePage.dart';
import 'package:afrotok/pages/story/afroStory/repository.dart';
import 'package:afrotok/pages/story/afroStory/storie/mesChronique.dart';
import 'package:afrotok/pages/story/afroStory/storie/storyFormChoise.dart';
import 'package:afrotok/pages/tiktokProjet/tiktokPages.dart';
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
import '../LiveAgora/mesLives.dart';
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
import '../contenuPayant/TableauDeBord.dart';
import '../ia/compagnon/introIaCompagnon.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../user/amis/addListAmis.dart';
import '../user/amis/pageMesInvitations.dart';
import '../userPosts/challenge/lookChallenge/mesLookChallenge.dart';

const Color primaryGreen = Color(0xFF25D366);
const Color accentYellow = Color(0xFFFFD700);
const Color darkBackground = Color(0xFF121212);
const Color textColor = Colors.white;

class MyHomePage extends StatefulWidget {
   MyHomePage({super.key, required this.title,this.isOpenLink=false});

  final String title;
   bool isOpenLink;


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
    Tab(text: 'Accueil'),
    Tab(text: 'Vidéos'),
    Tab(text: 'Looks'),
    // Tab(text: 'TikTok'),
    Tab(text: 'Actualités'),
    Tab(text: 'Sports'),
    // Tab(text: 'Offres'),
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






  final FirebaseFirestore firestore = FirebaseFirestore.instance;
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






  Widget menu(BuildContext context, double w, h) {
    bool onTap = false;

    return RefreshIndicator(
      onRefresh: () async {
        await authProvider.getCurrentUser(authProvider.loginUserData!.id!);
      },
      child: Drawer(
        width: MediaQuery.of(context).size.width * 0.9,
        backgroundColor: Colors.black, // Fond noir
        child: Column(
          children: <Widget>[
            DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.black, // Fond noir pour l'en-tête
              ),
              child: ListView(
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
                      showUserDetailsModalDialog(authProvider.loginUserData, w, h, context);
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
                            SizedBox(height: 2),
                            Row(
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      child: TextCustomerUserTitle(
                                        titre: "@${authProvider.loginUserData.pseudo}",
                                        fontSize: SizeText.homeProfileTextSize,
                                        couleur: Colors.white, // Texte blanc
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    TextCustomerUserTitle(
                                      titre: "${formatNumber(authProvider.loginUserData.userAbonnesIds!.length!)} abonné(s)",
                                      fontSize: SizeText.homeProfileTextSize,
                                      couleur: Colors.white, // Texte blanc
                                      fontWeight: FontWeight.w400,
                                    ),
                                    TextCustomerUserTitle(
                                      titre: "${formatNumber(authProvider.loginUserData!.userlikes!)} like(s)",
                                      fontSize: SizeText.homeProfileTextSize,
                                      couleur: Colors.green,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ],
                                ),
                                SizedBox(width: 5),
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
                                couleur: Colors.white, // Texte blanc
                                fontWeight: FontWeight.w400,
                              ),
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
                  // NOUVELLE OPTION: RECHERCHER UN UTILISATEUR
                  ListTile(
                    trailing: Icon(Icons.arrow_right_outlined, color: Colors.green),
                    leading: Icon(Icons.search, color: Colors.yellow), // Icône jaune
                    title: TextCustomerMenu(
                      titre: "Rechercher un utilisateur",
                      fontSize: SizeText.homeProfileTextSize,
                      couleur: Colors.white, // Texte blanc
                      fontWeight: FontWeight.w600,
                    ),
                    onTap: () {
                      Navigator.pop(context); // Fermer le menu
                      Navigator.push(context, MaterialPageRoute(
                        builder: (context) => AddListAmis(), // Page de recherche
                      ));
                    },
                  ),

                  ListTile(
                    trailing: Icon(Icons.arrow_right_outlined, color: Colors.green),
                    leading: Image.asset(
                      'assets/menu/1.png',
                      height: 20,
                      width: 20,
                      color: Colors.yellow, // Icône jaune
                    ),
                    title: TextCustomerMenu(
                      titre: "Profile",
                      fontSize: SizeText.homeProfileTextSize,
                      couleur: Colors.white, // Texte blanc
                      fontWeight: FontWeight.w600,
                    ),
                    onTap: () {
                      Navigator.pushNamed(context, '/home_profile_user');
                    },
                  ),

                  ListTile(
                    trailing: Icon(Icons.arrow_right_outlined, color: Colors.green),
                    leading: Image.asset(
                      'assets/menu/3.png',
                      height: 20,
                      width: 20,
                      color: Colors.yellow, // Icône jaune
                    ),
                    title: TextCustomerMenu(
                      titre: "Amis",
                      fontSize: SizeText.homeProfileTextSize,
                      couleur: Colors.white, // Texte blanc
                      fontWeight: FontWeight.w600,
                    ),
                    onTap: () {
                      Navigator.pushNamed(context, '/amis');
                    },
                  ),

                  // ListTile(
                  //   trailing: TextCustomerMenu(
                  //     titre: "Discuter",
                  //     fontSize: SizeText.homeProfileTextSize,
                  //     couleur: Colors.blue,
                  //     fontWeight: FontWeight.w600,
                  //   ),
                  //   leading: CircleAvatar(
                  //     radius: 15,
                  //     backgroundColor: Colors.yellow, // Fond jaune
                  //     child: Image.asset(
                  //       'assets/icon/X.png',
                  //       color: Colors.black, // Icône noire
                  //     ),
                  //   ),
                  //   title: TextCustomerMenu(
                  //     titre: "Xilo",
                  //     fontSize: SizeText.homeProfileTextSize,
                  //     couleur: Colors.white, // Texte blanc
                  //     fontWeight: FontWeight.w600,
                  //   ),
                  //   subtitle: TextCustomerMenu(
                  //     titre: "Votre ami(e)",
                  //     fontSize: 9,
                  //     couleur: Colors.white, // Texte blanc
                  //     fontWeight: FontWeight.w600,
                  //   ),
                  //   onTap: () async {
                  //     setState(() {
                  //       onTap = true;
                  //     });
                  //
                  //     await authProvider.getAppData().then(
                  //           (appdata) async {
                  //         await authProvider
                  //             .getUserIa(authProvider.loginUserData.id!)
                  //             .then(
                  //               (value) async {
                  //             if (value.isNotEmpty) {
                  //               await getIAChatsData(value.first).then((chat) {
                  //                 setState(() {
                  //                   onTap = false;
                  //                 });
                  //                 Navigator.push(context, MaterialPageRoute(
                  //                   builder: (context) => IaChat(
                  //                     chat: chat,
                  //                     user: authProvider.loginUserData,
                  //                     userIACompte: value.first,
                  //                     instruction: '${authProvider.appDefaultData.ia_instruction!}',
                  //                     appDefaultData: authProvider.appDefaultData,
                  //                   ),
                  //                 ));
                  //               });
                  //             } else {
                  //               Navigator.push(
                  //                   context,
                  //                   MaterialPageRoute(
                  //                     builder: (context) => IntroIaCompagnon(
                  //                       instruction: authProvider.appDefaultData.ia_instruction!,
                  //                     ),
                  //                   ));
                  //             }
                  //           },
                  //         );
                  //       },
                  //     );
                  //   },
                  // ),

                  ListTile(
                    trailing: Icon(Icons.live_tv, color: Colors.red),
                    leading: Icon(FontAwesome.tv, size: 30, color: Colors.yellow), // Icône jaune
                    title: TextCustomerMenu(
                      titre: "Mes lives",
                      fontSize: SizeText.homeProfileTextSize,
                      couleur: Colors.white, // Texte blanc
                      fontWeight: FontWeight.w600,
                    ),
                    onTap: () async {
                      Navigator.push(context, MaterialPageRoute(
                        builder: (context) => UserLivesPage(),
                      ));
                    },
                  ),
                  ListTile(
                    trailing: Icon(Icons.arrow_right_outlined, color: Colors.green),
                    leading: Icon(FontAwesome.forumbee, size: 30, color: Colors.yellow), // Icône jaune
                    title: TextCustomerMenu(
                      titre: "Canaux",
                      fontSize: SizeText.homeProfileTextSize,
                      couleur: Colors.white, // Texte blanc
                      fontWeight: FontWeight.w600,
                    ),
                    onTap: () async {
                      Navigator.push(context, MaterialPageRoute(
                        builder: (context) => CanalListPage(isUserCanals: false),
                      ));
                    },
                  ),

                  ListTile(
                    trailing: Icon(Icons.arrow_right_outlined, color: Colors.green),
                    leading: Image.asset(
                      'assets/images/trophee.png',
                      height: 20,
                      width: 20,
                      color: Colors.yellow, // Icône jaune
                    ),
                    title: TextCustomerMenu(
                      titre: "TOP 10 Afrolook Stars",
                      fontSize: SizeText.homeProfileTextSize,
                      couleur: Colors.white, // Texte blanc
                      fontWeight: FontWeight.w600,
                    ),
                    onTap: () async {
                      await userProvider.getAllUsers().then(
                            (value) {
                          Navigator.push(context, MaterialPageRoute(
                            builder: (context) => UserClassement(),
                          ));
                        },
                      );
                    },
                  ),

                  ListTile(
                    trailing: Icon(Icons.arrow_right_outlined, color: Colors.green),
                    leading: Icon(Icons.history_toggle_off_sharp, size: 30, color: Colors.yellow), // Icône jaune
                    title: TextCustomerMenu(
                      titre: "Mes chroniques",
                      fontSize: SizeText.homeProfileTextSize + 3,
                      couleur: Colors.white, // Texte blanc
                      fontWeight: FontWeight.w900,
                    ),
                    onTap: () async {
                      Navigator.push(context, MaterialPageRoute(
                        builder: (context) => MyStoriesPage(
                            stories: authProvider.loginUserData.stories!,
                            user: authProvider.loginUserData
                        ),
                      ));
                    },
                  ),

                  ListTile(
                    trailing: Icon(Icons.arrow_right_outlined, color: Colors.green),
                    leading: Icon(Icons.storefront_outlined, color: Colors.yellow), // Icône jaune
                    title: TextCustomerMenu(
                      titre: "Afroshop MarketPlace",
                      fontSize: SizeText.homeProfileTextSize,
                      couleur: Colors.white, // Texte blanc
                      fontWeight: FontWeight.w600,
                    ),
                    onTap: () async {
                      Navigator.push(context, MaterialPageRoute(
                        builder: (context) => HomeAfroshopPage(title: ''),
                      ));
                    },
                  ),

                  ListTile(
                    trailing: Icon(Icons.arrow_right_outlined, color: Colors.green),
                    leading: AnimateIcon(
                      key: UniqueKey(),
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(
                          builder: (context) => UserServiceListPage(),
                        ));
                      },
                      iconType: IconType.continueAnimation,
                      height: 30,
                      width: 30,
                      color: Colors.yellow, // Icône jaune
                      animateIcon: AnimateIcons.settings,
                    ),
                    title: TextCustomerMenu(
                      titre: "🛠️Services & Jobs 💼",
                      fontSize: SizeText.homeProfileTextSize,
                      couleur: Colors.white, // Texte blanc
                      fontWeight: FontWeight.w600,
                    ),
                    subtitle: TextCustomerMenu(
                      titre: "Chercher des gens pour bosser",
                      fontSize: 9,
                      couleur: Colors.white, // Texte blanc
                      fontWeight: FontWeight.w600,
                    ),
                    onTap: () async {
                      Navigator.push(context, MaterialPageRoute(
                        builder: (context) => UserServiceListPage(),
                      ));
                    },
                  ),

                  // ListTile(
                  //   trailing: Icon(Icons.arrow_right_outlined, color: Colors.green),
                  //   leading: Image.asset(
                  //     'assets/menu/6.png',
                  //     height: 20,
                  //     width: 20,
                  //     color: Colors.yellow, // Icône jaune
                  //   ),
                  //   title: TextCustomerMenu(
                  //     titre: "Challenges Disponibles 🔥🎁  Gagnez un Prix 🏆",
                  //     fontSize: SizeText.homeProfileTextSize,
                  //     couleur: Colors.white, // Texte blanc
                  //     fontWeight: FontWeight.w600,
                  //   ),
                  //   onTap: () async {
                  //     Navigator.push(context, MaterialPageRoute(
                  //       builder: (context) => ChallengeListPage(),
                  //     ));
                  //   },
                  // ),
                  //
                  // ListTile(
                  //   trailing: Icon(Icons.arrow_right_outlined, color: Colors.green),
                  //   leading: Image.asset(
                  //     'assets/menu/6.png',
                  //     height: 20,
                  //     width: 20,
                  //     color: Colors.yellow, // Icône jaune
                  //   ),
                  //   title: TextCustomerMenu(
                  //     titre: "Mes Looks Challenges 🔥🎁🏆",
                  //     fontSize: SizeText.homeProfileTextSize,
                  //     couleur: Colors.white, // Texte blanc
                  //     fontWeight: FontWeight.w600,
                  //   ),
                  //   onTap: () async {
                  //     Navigator.push(context, MaterialPageRoute(
                  //       builder: (context) => MesLookChallengeListPage(),
                  //     ));
                  //   },
                  // ),

                  ListTile(
                    trailing: Icon(Icons.arrow_right_outlined, color: Colors.green),
                    leading: Image.asset(
                      'assets/menu/7.png',
                      height: 20,
                      width: 20,
                      color: Colors.yellow, // Icône jaune
                    ),
                    title: TextCustomerMenu(
                      titre: "Afrolook infos",
                      fontSize: SizeText.homeProfileTextSize,
                      couleur: Colors.white, // Texte blanc
                      fontWeight: FontWeight.w600,
                    ),
                    onTap: () async {
                      await userProvider.getAllInfos().then(
                            (value) {
                          Navigator.pushNamed(context, '/app_info');
                        },
                      );
                    },
                  ),

                  ListTile(
                    trailing: Icon(Icons.arrow_right_outlined, color: Colors.green),
                    leading: Icon(Icons.contact_mail, color: Colors.yellow), // Icône jaune
                    title: TextCustomerMenu(
                      titre: "Nos Contactes",
                      fontSize: SizeText.homeProfileTextSize,
                      couleur: Colors.white, // Texte blanc
                      fontWeight: FontWeight.w600,
                    ),
                    onTap: () async {
                      await userProvider.getAllInfos().then(
                            (value) {
                          Navigator.pushNamed(context, '/contact');
                        },
                      );
                    },
                  ),

                  ListTile(
                    trailing: Icon(Icons.arrow_right_outlined, color: Colors.green),
                    leading: Icon(Icons.smartphone, color: Colors.yellow), // Icône jaune
                    title: TextCustomerMenu(
                      titre: "Partager l'application",
                      fontSize: SizeText.homeProfileTextSize,
                      couleur: Colors.white, // Texte blanc
                      fontWeight: FontWeight.w600,
                    ),
                    onTap: () async {
                      final box = context.findRenderObject() as RenderBox?;

                      await authProvider.getAppData().then(
                            (value) async {
                          await Share.shareUri(
                            Uri.parse('${authProvider.appDefaultData.app_link}'),
                            sharePositionOrigin: box!.localToGlobal(Offset.zero) & box.size,
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),

            SizedBox(height: 5),
            Text(
              'Version: 1.1.32 (${authProvider.appDefaultData.app_version_code!})',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white, // Texte blanc
              ),
            ),

            Container(
              child: Align(
                alignment: FractionalOffset.bottomCenter,
                child: Column(
                  children: <Widget>[
                    Divider(color: Colors.green), // Séparateur vert
                    ListTile(
                      leading: Icon(
                        Icons.exit_to_app,
                        color: Colors.yellow, // Icône jaune
                      ),
                      title: TextCustomerMenu(
                        titre: "Déconnecter",
                        fontSize: 15,
                        couleur: Colors.yellow, // Texte jaune
                        fontWeight: FontWeight.w600,
                      ),
                      onTap: () {
                        authProvider.loginUserData!.isConnected = false;
                        userProvider.changeState(
                            user: authProvider.loginUserData,
                            state: UserState.OFFLINE.name
                        );
                        authProvider.storeToken('').then(
                              (value) {
                            Navigator.pop(context);
                            Navigator.pushReplacementNamed(context, "/login");
                          },
                        );
                      },
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
    if(!widget.isOpenLink){
      TopLiveGridModal.showTopLiveGridModal(context);

    }
    userProvider.getAllUsers().then((value) {
      // TopFiveModal.showTopFiveModal(context, value.take(5).toList());
    });


    _tabController = TabController(length: _tabs.length, vsync: this);

    authProvider.checkAppVersionAndProceed(context, () {
    });
    // hasShownDialogToday().then((value) async {
    //   final SharedPreferences prefs = await SharedPreferences.getInstance();
    //   authProvider.getAppData().then((value) {
    //     // setState(() {});
    //   });
    //   categorieProduitProvider.getArticleBooster().then((value) {
    //     articles = value;
    //     // setState(() {});
    //   });
    //
    //   postProvider.getAllUserServiceHome().then((value) {
    //     userServices = value;
    //     userServices.shuffle();
    //     // setState(() {});
    //   });
    //   postProvider.getCanauxHome().then((value) {
    //     canaux = value;
    //     canaux.shuffle();
    //     // setState(() {});
    //   });
    //
    //   if (value && mounted) {
    //
    //   }
    //   _checkAndShowDialog();
    // });
    //
    // authProvider.getToken().then((token) async {
    //   printVm("token: ${token}");
    //   // postProvider.getPostsImages2(limitePosts).listen((data) {
    //   //   if (!_streamController.isClosed) {
    //   //     _streamController.add(data);
    //   //   }
    //   // });
    //
    //   if (token == null || token == '') {
    //     printVm("token: existe pas");
    //     Navigator.pushNamed(context, '/welcome');
    //   }
    // });

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


  void _onPaused() {
    if (authProvider.loginUserData != null) {
      authProvider.loginUserData!.isConnected = false;
      userProvider.changeState(user: authProvider.loginUserData, state: UserState.OFFLINE .name);
    }  }




  int _currentIndex = 0;
  final PageController _pageController = PageController();

  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    double iconSize = width * 0.065;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: darkBackground, // Fond noir uniforme
      appBar: AppBar(
        backgroundColor: darkBackground,
        automaticallyImplyLeading: false,
        titleSpacing: 10,

        title: Row(
          children: [
            GestureDetector(
              onTap: () {
                _scaffoldKey.currentState!.openDrawer();
              },
              child: Container(
                padding: EdgeInsets.all(6),
                decoration: BoxDecoration(
                  // color: primaryGreen,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.menu, color: Colors.white, size: 24),
              ),
            ),
            SizedBox(width: 10),
            Text(
              'Afrolook',
              style: TextStyle(
                fontSize: iconSize * 0.8,
                fontWeight: FontWeight.w900,
                color: primaryGreen,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        actions: [
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, "/mes_notifications"),
            child: StreamBuilder<List<NotificationData>>(
              stream: authProvider.getListNotificationAuth(authProvider.loginUserData.id!),
              builder: (context, snapshot) {
                int notificationCount = snapshot.hasData ? snapshot.data!.length : 0;
                return badges.Badge(
                  showBadge: notificationCount > 0,
                  badgeStyle: badges.BadgeStyle(badgeColor: accentYellow),
                  badgeContent: Text(
                    notificationCount > 9 ? '9+' : '$notificationCount',
                    style: TextStyle(fontSize: 10, color: darkBackground),
                  ),
                  child: Icon(Icons.notifications_none_rounded, color: textColor, size: iconSize),
                );
              },
            ),
          ),
          // SizedBox(width: 10),
          // GestureDetector(
          //   onTap: _showChatXiloDialog,
          //   child: Container(
          //     width: 34,
          //     height: 34,
          //     decoration: BoxDecoration(color: primaryGreen, shape: BoxShape.circle),
          //     child: Center(
          //       child: Text('X', style: TextStyle(color: darkBackground, fontWeight: FontWeight.bold, fontSize: 16)),
          //     ),
          //   ),
          // ),
          SizedBox(width: 20),
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => UserServiceListPage())),
            child: Icon(Icons.settings_outlined, color: textColor, size: iconSize),
          ),
          SizedBox(width: 10),
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => HomeAfroshopPage(title: ''))),
            child: Icon(Icons.storefront, color: textColor, size: iconSize),
          ),
          SizedBox(width: 10),
          GestureDetector(
            onTap: () {
              if (_scrollController.hasClients) {
                _scrollController.animateTo(0.0, duration: Duration(milliseconds: 1000), curve: Curves.ease);
              }
              setState(() {
                listConstposts.clear();
              });
            },
            child: Icon(Icons.refresh_rounded, color: textColor, size: iconSize),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(48),
          child: Container(
            color: darkBackground,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              indicatorColor: primaryGreen,
              labelColor: accentYellow,
              unselectedLabelColor: Colors.grey[400],
              tabs: [
                Tab(text: '🏠 Accueil'),
                Tab(text: '🎥 Vidéos virales'),
                Tab(text: '🌟 Looks'),
                // Tab(text: '🎵 TikTok'),
                Tab(text: '🔥 Populaires'),
                Tab(text: '🕒 Récents'),
                // Tab(text: '💼 Offres'),
              ],

            ),
          ),
        ),
      ),
      drawer: menu(context, width, MediaQuery.of(context).size.height),
      body: TabBarView(
        controller: _tabController,
        children: [
          UnifiedHomePage(),
          DashboardContentScreen(),
          LooksPage(type: TabBarType.LOOKS.name),
          LooksPage(type: TabBarType.LOOKS.name,sortType: 'popular',),
          LooksPage(type: TabBarType.LOOKS.name,sortType: 'recent',),

          // VideoFeedTiktokPage(fullPage: false),
          // ActualitePage(type: TabBarType.ACTUALITES.name),
          // SportPage(type: TabBarType.SPORT.name),
          // OffrePage(type: TabBarType.OFFRES.name),
        ],
      ),

      bottomNavigationBar: Container(
        height: 70,
        decoration: BoxDecoration(
          color: darkBackground,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 15,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            // Bouton Communauté
            GestureDetector(
              onTap: () async {
                // Navigator.push(context, MaterialPageRoute(builder: (_) => UserCards()));
                Navigator.push(context, MaterialPageRoute(builder: (_) => MesInvitationsPage(context: context)));

                // authProvider.checkAppVersionAndProceed(context, () async {
                //   await userProvider
                //       .getProfileUsers(authProvider.loginUserData!.id!, context, limiteUsers)
                //       .then((value) {
                //     Navigator.push(context, MaterialPageRoute(builder: (_) => UserCards()));
                //   });
                // });

              },
              child: StreamBuilder<int>(
                stream: getNbrInvitation(),
                builder: (context, snapshot) {
                  int invitationCount = snapshot.hasData ? snapshot.data! : 0;
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      badges.Badge(
                        showBadge: invitationCount > 0,
                        badgeStyle: badges.BadgeStyle(
                          badgeColor: accentYellow,
                        ),
                        badgeContent: Text(
                          invitationCount > 9 ? '9+' : '$invitationCount',
                          style: TextStyle(fontSize: 9, color: darkBackground),
                        ),
                        child: Icon(Icons.group, color: textColor, size: 26),
                      ),
                      SizedBox(height: 4),
                      Text('Invitations', style: TextStyle(color: textColor, fontSize: 10)),
                    ],
                  );
                },
              ),
            ),
            // Bouton Messages
            GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/list_users_chat'),
              child: StreamBuilder<int>(
                stream: getNbrMessageNonLu(),
                builder: (context, snapshot) {
                  int messageCount = snapshot.hasData ? snapshot.data! : 0;
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      badges.Badge(
                        showBadge: messageCount > 0,
                        badgeStyle: badges.BadgeStyle(badgeColor: accentYellow),
                        badgeContent: Text(
                          messageCount > 9 ? '9+' : '$messageCount',
                          style: TextStyle(fontSize: 9, color: darkBackground),
                        ),
                        child: Icon(Icons.chat_bubble_outline, color: textColor, size: 26),
                      ),
                      SizedBox(height: 4),
                      Text('Messages', style: TextStyle(color: textColor, fontSize: 10)),
                    ],
                  );
                },
              ),
            ),
            // Bouton Créer central
            GestureDetector(
              onTap: () {

                authProvider.checkAppVersionAndProceed(context, () async {
               Navigator.pushNamed(context, '/user_posts_form');

                });
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primaryGreen, accentYellow],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: primaryGreen.withOpacity(0.4), blurRadius: 10, spreadRadius: 2, offset: Offset(0, 3)),
                  ],
                ),
                child: Icon(Icons.add, color: darkBackground, size: 30),
              ),
            ),
            // Bouton Vidéos
            GestureDetector(
              onTap: () {
                Navigator.pushNamed(context, '/videos');
                // Navigator.pushNamed(context, '/list_live');

                // authProvider.checkAppVersionAndProceed(context, () async {
                //   Navigator.pushNamed(context, '/videos');
                //
                // });
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  badges.Badge(
                    showBadge: true,
                    badgeStyle: badges.BadgeStyle(badgeColor: accentYellow),
                    badgeContent: Text('9+', style: TextStyle(fontSize: 8, color: darkBackground)),
                    child: Icon(Icons.video_library, color: textColor, size: 26),
                  ),
                  SizedBox(height: 4),
                  Text('Vidéos', style: TextStyle(color: textColor, fontSize: 10)),
                ],
              ),
            ),
            // Bouton Menu
            GestureDetector(
              onTap: () {
                Navigator.pushNamed(context, '/list_live');

                // authProvider.checkAppVersionAndProceed(context, () async {
                //   _scaffoldKey.currentState!.openDrawer();
                //
                // });
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  badges.Badge(
                    showBadge: true,
                    badgeStyle: badges.BadgeStyle(badgeColor: accentYellow),
                    badgeContent: Text('5+', style: TextStyle(fontSize: 8, color: darkBackground)),
                    child: Icon(Icons.live_tv, color: Colors.red, size: 26),
                  ),
                  SizedBox(height: 4),
                  Text('Lives', style: TextStyle(color: textColor, fontSize: 10)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

}
