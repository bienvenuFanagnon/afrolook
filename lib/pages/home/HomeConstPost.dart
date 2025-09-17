import 'dart:async';
import 'dart:math';
import 'package:afrotok/pages/canaux/listCanal.dart';
import 'package:afrotok/pages/chat/chatXilo.dart';
import 'package:afrotok/pages/chat/deepseek.dart';
import 'package:afrotok/pages/classements/userClassement.dart';
import 'package:afrotok/pages/home/slive/utils.dart';
import 'package:afrotok/pages/home/storyCustom/StoryCustom.dart';
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
import '../auth/authTest/Screens/Welcome/welcome_screen.dart';
import '../chat/ia_Chat.dart';
import '../component/showUserDetails.dart';
import '../../constant/textCustom.dart';
import '../../models/chatmodels/message.dart';
import '../../providers/afroshop/authAfroshopProvider.dart';
import '../../providers/afroshop/categorie_produits_provider.dart';
import '../../providers/authProvider.dart';
import 'package:shimmer/shimmer.dart';
import '../component/consoleWidget.dart';
import '../ia/compagnon/introIaCompagnon.dart';

import 'package:shared_preferences/shared_preferences.dart';
import '../ia/gemini/geminibot.dart';
import '../story/afroStory/storie/storyView.dart';
import '../user/conponent.dart';
import '../userPosts/challenge/lookChallenge/mesLookChallenge.dart';
import '../userPosts/postWidgets/postUserWidget.dart';
import '../userPosts/postWidgets/postWidgetPage.dart';

const Color primaryGreen = Color(0xFF25D366);
const Color darkBackground = Color(0xFF121212);
const Color lightBackground = Color(0xFF1E1E1E);
const Color textColor = Colors.white;
class HomeConstPostPage extends StatefulWidget {
  const HomeConstPostPage({super.key, required this.type});

  final String type;

  @override
  State<HomeConstPostPage> createState() => _HomeConstPostPageState();
}

class _HomeConstPostPageState extends State<HomeConstPostPage>
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



  Widget homeProfileUsers(UserData user, double w, double h) {
    // Liste des IDs d'abonnés du profil
    List<String> userAbonnesIds = user.userAbonnesIds ?? [];

    // Vérifier si l'utilisateur connecté est déjà abonné
    bool alreadySubscribed = userAbonnesIds.contains(authProvider.loginUserData.id);

    return Container(
      width: w * 0.4,
      margin: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: darkBackground.withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () async {
              await authProvider.getUserById(user.id!).then((users) async {
                if (users.isNotEmpty) {
                  showUserDetailsModalDialog(users.first, w, h, context);
                }
              });
            },
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                // Image de profil
                Container(
                  width: w * 0.4,
                  height: h * 0.22,
                  child: ClipRRect(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                    child: CachedNetworkImage(
                      fit: BoxFit.cover,
                      imageUrl: user.imageUrl ?? '',
                      progressIndicatorBuilder: (context, url, downloadProgress) =>
                          Container(
                            color: Colors.grey[800],
                            child: Center(
                              child: CircularProgressIndicator(
                                value: downloadProgress.progress,
                                color: primaryGreen,
                              ),
                            ),
                          ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[800],
                        child: Icon(Icons.person, color: Colors.grey[400], size: 40),
                      ),
                    ),
                  ),
                ),

                // Overlay avec informations
                Container(
                  width: w * 0.4,
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.black87, Colors.transparent],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Pseudo et vérification
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '@${user.pseudo!.startsWith('@') ? user.pseudo!.substring(1) : user.pseudo!}',
                              style: TextStyle(
                                color: textColor,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          if (user.isVerify!) Icon(Icons.verified, color: primaryGreen, size: 14),
                        ],
                      ),
                      SizedBox(height: 4),

                      // Statistiques
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Abonnés
                          Row(
                            children: [
                              Icon(Icons.group, size: 10, color: accentYellow),
                              SizedBox(width: 2),
                              Text(
                                '${user.abonnes}',
                                style: TextStyle(
                                  color: accentYellow,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),

                          // Parrainages
                          Row(
                            children: [
                              Icon(Icons.people_outline, size: 10, color: Colors.blue),
                              SizedBox(width: 2),
                              Text(
                                '${user.usersParrainer?.length ?? 0}',
                                style: TextStyle(
                                  color: Colors.blue,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),

                          // Drapeau pays
                          countryFlag(user.countryData?['countryCode'] ?? "", size: 16),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Bouton d'action (s'abonner) uniquement si non abonné
          if (!alreadySubscribed)
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: ElevatedButton(
                onPressed: () async {
                  await authProvider.getUserById(user.id!).then((users) async {
                    if (users.isNotEmpty) {
                      showUserDetailsModalDialog(users.first, w, h, context);
                    }
                  });                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryGreen,
                  foregroundColor: darkBackground,
                  padding: EdgeInsets.symmetric(vertical: 4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'S\'abonner',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
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

  List<Post> listVideos=[];
  late Future<List<UserData>> _futureUsers;

  @override
  void initState() {
    // _changeColor();
    super.initState();
    _futureUsers = userProvider.getProfileUsers(
      authProvider.loginUserData.id!,
      context,
      limiteUsers,
    );
    hasShownDialogToday().then((value) async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      // authProvider.getAppData().then((value) {
      //   // setState(() {});
      // });
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

      // if (value && mounted) {
      //   showDialog(
      //     context: context,
      //     builder: (BuildContext context) {
      //       return AlertDialog(
      //         title: Text('Nouvelle offre sur Afrolook'),
      //         content: SingleChildScrollView(
      //           child: Column(
      //             mainAxisSize: MainAxisSize.max,
      //             children: [
      //               Image.asset("assets/images/bonus_afrolook.jpg", fit: BoxFit.cover),
      //               SizedBox(height: 5),
      //               Icon(FontAwesome.money, size: 50, color: Colors.green),
      //               SizedBox(height: 10),
      //               Text('Vous avez la possibilité de'),
      //               Text('gagner 5 PubliCashs', style: TextStyle(color: Colors.green)),
      //               Text(
      //                 'chaque fois qu\'un nouveau s\'inscrit avec votre code de parrainage...',
      //                 textAlign: TextAlign.center,
      //               ),
      //             ],
      //           ),
      //         ),
      //         actions: [
      //           TextButton(
      //             child: Text('OK'),
      //             onPressed: () {
      //               Navigator.of(context).pop();
      //               prefs.setString('lastShownDateKey', DateTime.now().toString());
      //             },
      //           ),
      //         ],
      //       );
      //     },
      //   );
      // }
      // _checkAndShowDialog();
    });

    authProvider.getToken().then((token) async {
      printVm("token: ${token}");
      postProvider.getPostsImages2(limitePosts,widget.type).listen((data) {
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
    // postProvider.getPostsVideos3(limitePosts).then((value) {
    //   postProvider.listvideos=value;
    //   printVm('listVideos *****************************: ${postProvider.listvideos.length}');
    // },);
  }

  @override
  void dispose() {
    _streamController.close();
    _cachedUsersWithStories = []; // Nettoyer le cache

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
    _changeColor();

    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;
    homeIconSize = width * 0.065;

    return RefreshIndicator(
      onRefresh: () async {
        setState(() {});
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: darkBackground, // Utilisation de votre couleur de fond
        body: SafeArea(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  darkBackground.withOpacity(0.95),
                  darkBackground,
                ],
              ),
            ),
            child: CustomScrollView(
              slivers: [


                // Section des chroniques
                SliverToBoxAdapter(
                  child: _buildChroniquesSection(context),
                ),

                // Section des profils utilisateurs
                SliverToBoxAdapter(
                  child: _buildProfilesSection(),
                ),

                // Section des posts
                SliverToBoxAdapter(
                  child: _buildPostsSection(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
// Votre fonction _buildChroniquesSection existante
// 1. Créez une variable d'instance pour stocker les données
  List<UserData> _cachedUsersWithStories = [];

// 2. Modifiez votre méthode _buildChroniquesSection
  Widget _buildChroniquesSection(BuildContext context) {
    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;

    // Utilisez un FutureBuilder avec un mécanisme de cache
    return FutureBuilder<List<UserData>>(
      future: _cachedUsersWithStories.isEmpty
          ? authProvider.getUsersStorie(authProvider.loginUserData.id!, limiteUsers)
          : Future.value(_cachedUsersWithStories),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && _cachedUsersWithStories.isEmpty) {
          return SizedBox(height: height * 0.35, child: _buildShimmerEffect(width, height));
        } else if (snapshot.hasError) {
          return SizedBox(height: height * 0.35, child: _buildErrorWidget());
        } else {
          // Cache les données une fois qu'elles sont chargées
          if (snapshot.hasData && snapshot.data!.isNotEmpty && _cachedUsersWithStories.isEmpty) {
            _cachedUsersWithStories = snapshot.data!;
          }

          final list = _cachedUsersWithStories.isNotEmpty
              ? _cachedUsersWithStories
              : snapshot.data ?? [];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 16.0, top: 16, bottom: 8),
                child: Text(
                  'Chroniques',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ),
              SizedBox(
                height: height * 0.25,
                child: Row(
                  children: [
                    // Bouton pour ajouter une chronique
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: GestureDetector(
                        onTap: () => checkAppVersionAndProceed(context, () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => StoryChoicePage()),
                          );
                        }),
                        child: Container(
                          width: width * 0.2,
                          height: height * 0.25,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(15),
                            gradient: LinearGradient(
                              colors: [primaryGreen, accentYellow],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add, size: 30, color: darkBackground),
                              SizedBox(height: 8),
                              Text(
                                'Ajouter',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: darkBackground,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Liste des chroniques
                    Expanded(
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: list.length,
                        itemBuilder: (context, index) {
                          final user = list[index];
                          final stories = authProvider.getStoriesWithTimeAgo(user.stories ?? []);

                          return stories.isNotEmpty
                              ? Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Container(
                              width: width * 0.3,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(
                                  color: primaryGreen,
                                  width: 2,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(13),
                                child: StoryPreviewCustom(
                                  user: user,
                                  h: height * 0.25,
                                  w: width * 0.3,
                                ),
                              ),
                            ),
                          )
                              : const SizedBox.shrink();
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }
      },
    );
  }

// 3. Ajoutez une méthode pour gérer les erreurs
  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: Colors.red, size: 50),
          SizedBox(height: 10),
          Text('Erreur de chargement des chroniques'),
          SizedBox(height: 10),
          ElevatedButton(
            onPressed: () {
              _cachedUsersWithStories = []; // Réinitialiser le cache
              // Forcer le rebuild si vous utilisez setState
            },
            child: Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  Widget _buildProfilesSection() {
    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;

    return FutureBuilder<List<UserData>>(
      future: _futureUsers, // 👈 ne recrée pas le future à chaque build
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting || snapshot.hasError) {
          return SizedBox(
            height: height * 0.35,
            child: _buildShimmerEffect(width, height),
          );
        } else {
          List<UserData> list = snapshot.data!..shuffle();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 16.0, top: 16, bottom: 8),
                child: Text(
                  'Profils à découvrir',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ),
              SizedBox(
                height: height * 0.35,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: list.length,
                  itemBuilder: (context, index) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    width: width * 0.4,
                    decoration: BoxDecoration(
                      color: darkBackground.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: primaryGreen.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: homeProfileUsers(list[index], width, height),
                  ),
                ),
              ),
            ],
          );
        }
      },
    );
  }


  Widget _buildProfilesSection2() {
    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;

    return FutureBuilder<List<UserData>>(
      future: userProvider.getProfileUsers(authProvider.loginUserData.id!, context, limiteUsers),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting || snapshot.hasError) {
          return SizedBox(height: height * 0.35, child: _buildShimmerEffect(width, height));
        } else {
          List<UserData> list = snapshot.data!..shuffle();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 16.0, top: 16, bottom: 8),
                child: Text(
                  'Profils à découvrir',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ),
              SizedBox(
                height: height * 0.35,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: list.length,
                  itemBuilder: (context, index) => Container(
                    margin: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    width: width * 0.4,
                    decoration: BoxDecoration(
                      color: darkBackground.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: primaryGreen.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: homeProfileUsers(list[index], width, height),
                  ),
                ),
              ),
            ],
          );
        }
      },
    );
  }

  Widget _buildShimmerEffect(double width, double height) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[800]!,
      highlightColor: Colors.grey[600]!,
      child: Container(
        width: width,
        height: height,
        color: Colors.grey[800],
      ),
    );
  }


  Widget _buildPostsSection(BuildContext context) {
    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;

    return StreamBuilder<List<Post>>(
      stream: _streamController.stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildPostsShimmerEffect(width, height);
        } else if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error, color: Colors.red, size: 40),
                SizedBox(height: 10),
                Text(
                  'Erreur de chargement',
                  style: TextStyle(color: textColor),
                ),
              ],
            ),
          );
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.photo_library, color: Colors.grey, size: 40),
                SizedBox(height: 10),
                Text(
                  'Aucun look disponible',
                  style: TextStyle(color: Colors.grey),
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    // Action pour créer le premier post
                    authProvider.checkAppVersionAndProceed(context, () {
                      Navigator.pushNamed(context, '/user_posts_form');
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
                    foregroundColor: darkBackground,
                  ),
                  child: Text('Créer le premier look'),
                ),
              ],
            ),
          );
        }

        List<Post> posts = snapshot.data!;
        List<Widget> postWidgets = [];

        // Construire la liste des posts avec les boosters et canaux intégrés
        for (int i = 0; i < posts.length; i++) {
          // Ajouter un booster tous les 9 posts
          if (i % 9 == 8 && articles.isNotEmpty) {
            postWidgets.add(_buildBoosterPage(context));
          }

          // Ajouter un canal tous les 7 posts
          if (i % 7 == 6 && canaux.isNotEmpty) {
            postWidgets.add(_buildCanalPage(context));
          }

          // Ajouter le post normal
          postWidgets.add(
            Container(
              margin: EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: darkBackground.withOpacity(0.7),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: HomePostUsersWidget(
                post: posts[i],
                color: _color,
                height: height * 0.6, // Ajuster selon besoin
                width: width,
                isDegrade: true,
              ),
            ),
          );
        }

        return SingleChildScrollView(
          child: Column(
            children: [
              // En-tête de section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Derniers Looks',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.filter_list, color: primaryGreen),
                      onPressed: () {
                        // Action de filtrage
                      },
                    ),
                  ],
                ),
              ),

              // Liste des posts
              Column(children: postWidgets),

              // Indicateur de fin
              Container(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  'Vous avez vu tous les looks',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

// Effet de chargement type Shimmer
  Widget _buildPostsShimmerEffect(double width, double height) {
    return Column(
      children: List.generate(3, (index) =>
          Container(
            margin: EdgeInsets.only(bottom: 16),
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: darkBackground.withOpacity(0.7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Shimmer.fromColors(
              baseColor: Colors.grey[800]!,
              highlightColor: Colors.grey[600]!,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // En-tête du post
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.grey[700],
                        radius: 20,
                      ),
                      SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: width * 0.4,
                            height: 14,
                            color: Colors.grey[700],
                          ),
                          SizedBox(height: 6),
                          Container(
                            width: width * 0.3,
                            height: 12,
                            color: Colors.grey[700],
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 16),

                  // Contenu du post
                  Container(
                    width: double.infinity,
                    height: height * 0.3,
                    color: Colors.grey[700],
                  ),
                  SizedBox(height: 16),

                  // Actions du post
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: List.generate(3, (i) =>
                        Container(
                          width: width * 0.2,
                          height: 14,
                          color: Colors.grey[700],
                        ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ),
    );
  }
  Widget _buildBoosterPage(BuildContext context) {
    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;
    return Container(
      // color:  Colors.lightGreen.shade200, // Noir plus dominant mais attén,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text('Produits Boostés', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(width: 8),
                    const Icon(Icons.local_fire_department, color: Colors.red),
                  ],
                ),
                GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const HomeAfroshopPage(title: ''))),
                  child: Row(
                    children: [
                      Text('Boutiques', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                      const SizedBox(width: 8),
                      const Icon(Icons.storefront, color: Colors.red),
                    ],
                  ),
                ),
              ],
            ),
          ),
          CarouselSlider(
            items: articles.map((article) => Builder(
              builder: (context) => ArticleTileBooster(
                article: article,
                w: width,
                h: height,
                isOtherPage: true,
              ),
            )).toList(),
            options: CarouselOptions(
              height: height * 0.3,
              autoPlay: true,
              enlargeCenterPage: true,
              viewportFraction: 0.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCanalPage(BuildContext context) {
    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;
    return Container(
      // color:  Colors.lightGreen.shade200, // Noir plus dominant mais attén,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('📺 Afrolook Canal', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.green)),
                GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) =>  CanalListPage(isUserCanals: false))),
                  child: Text('Voir plus 📺', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.green)),
                ),
              ],
            ),
          ),
          SizedBox(
            height: height * 0.34,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: canaux.length,
              itemBuilder: (context, index) => channelWidget(canaux[index], width, height, context),
            ),
          ),
        ],
      ),
    );
  }
}



