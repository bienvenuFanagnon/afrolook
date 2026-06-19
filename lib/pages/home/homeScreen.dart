import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:afrotok/pages/canaux/listCanal.dart';
import 'package:afrotok/pages/challengeMonth/challenge_month_page.dart';
import 'package:afrotok/pages/chat/chatXilo.dart';
import 'package:afrotok/pages/chronique/mychroniquepage.dart';
import 'package:afrotok/pages/classements/userClassement.dart';

import 'package:afrotok/pages/home/homeLooks.dart';

import 'package:afrotok/pages/home/listTopModal.dart';

import 'package:animated_icon/animated_icon.dart';
import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';
import 'package:afrotok/providers/postProvider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:afrotok/constant/logo.dart';
import 'package:afrotok/constant/sizeText.dart';
import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/providers/userProvider.dart';
import 'package:badges/badges.dart' as badges;
import 'package:flutter/services.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:intl/intl.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:popup_menu_plus/popup_menu_plus.dart';
import 'package:provider/provider.dart';
import 'package:random_color/random_color.dart';
import 'package:share_plus/share_plus.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:upgrader/upgrader.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:workmanager/workmanager.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart' show ShorebirdUpdater;
import '../../constant/custom_theme.dart';
import '../../providers/chroniqueProvider.dart';
import '../../providers/contenuPayantProvider.dart';
import '../../services/daily_modal_service.dart';
import '../../services/inactiveUserReminderHelperService.dart';
import '../../services/navigation_service.dart';
import '../../services/postService/mixed_feed_service.dart';
import '../../services/sessions/session_checker_service.dart';
import '../../services/sessions/session_service.dart';
import '../../services/utils/abonnement_utils.dart';
import '../LiveAgora/livesAgora.dart';
import '../LiveAgora/mesLives.dart';
import '../Marketing/affiliationMarketing.dart';
import '../Marketing/affiliation_announce_modal.dart';
import '../UserServices/listUserService.dart';
import '../UserServices/presence_en_ligne.dart';
import '../afroshop/marketPlace/acceuil/home_afroshop.dart';

import '../challenge/listChallengePost.dart';

import '../challenge/userlistchallenge.dart';
import '../challengeMonth/challenge_announce_modal.dart';
import '../chat/myChat.dart';
import '../chronique/chroniquedetails.dart';
import '../chronique/chroniquehome.dart';
import '../component/showUserDetails.dart';
import '../../constant/textCustom.dart';
import '../../models/chatmodels/message.dart';
import '../../providers/afroshop/authAfroshopProvider.dart';
import '../../providers/afroshop/categorie_produits_provider.dart';
import '../../providers/authProvider.dart';

import '../component/consoleWidget.dart';
import '../contenuPayant/TableauDeBord.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../cryptoMarket/cryptoMarketpage.dart';
import '../dating/dating_entry_page.dart';
import '../dating/dating_notifications_page.dart';
import '../dating/widgets/dating_top_modal.dart';
import '../mes_notifications.dart';
import '../postDetails.dart';
import '../postDetailsVideo.dart';
import '../post_video_format_tel_details.dart';
import '../pronostics/pronostics_feed_page.dart';
import '../splashChargement.dart';
import '../user/amis/addListAmis.dart';
import '../user/amis/ami.dart';
import '../user/amis/pageMesInvitations.dart';
import '../user/inviteAmis.dart';
import '../user/monetisation.dart';
import '../user/remuneration_home_page.dart';
import '../userPosts/favorites_posts.dart';
import '../vibe/vibesPage.dart';
import '../widgetGlobal.dart';
import 'HomePostType.dart';
import 'homeSportPost.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_colors.dart';
import '../../theme/theme_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/sound_provider.dart';
import 'HomeConstPost.dart';
import '../../l10n/app_localizations.dart';

class MyHomePage extends StatefulWidget {

  final String title;
   bool isOpenLink;
   final MixedFeedService? preloadedFeedService; // 🔥 NOUVEAU
  final DestinationData? initialDestination;

  MyHomePage({
     super.key,
     required this.title,
     this.isOpenLink = false,
     this.preloadedFeedService, // 🔥 NOUVEAU
     this.initialDestination, // 🔥 NOUVEAU
   });

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
  int _unreadNotificationsCount = 0;
  String _appVersion = '';
  int? _shorebirdPatch;

  // Liste des onglets avec texte et icônes
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





  late MixedFeedService _mixedFeedService;
  bool _isGlobalContentLoading = false;

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

  void _initializeFeedService() {
    // Utiliser le service préchargé ou en créer un nouveau
    if (widget.preloadedFeedService != null) {
      _mixedFeedService = widget.preloadedFeedService!;
      print('🎯 Service de feed préchargé utilisé: ${_mixedFeedService!.preparedPostsCount} posts prêts');

      // 🔥 CHARGER LE CONTENU GLOBAL DEPUIS LA PAGE
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _mixedFeedService!.loadGlobalContentFromPage();
        print('🌍 Contenu global chargé depuis MyHomePage');
      });
    } else {
      // Créer un nouveau service si pas de service préchargé
      _mixedFeedService = MixedFeedService(
        authProvider: authProvider,
        categorieProvider: categorieProduitProvider,
        postProvider: postProvider,
        chroniqueProvider: Provider.of<ChroniqueProvider>(context, listen: false),
        contentProvider: Provider.of<ContentProvider>(context, listen: false),
      );

      // Préparer les posts et charger le contenu global
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final currentUserId = authProvider.loginUserData.id;
        if (currentUserId != null) {
          // await _mixedFeedService!.preparePostsOnly();
          await _mixedFeedService!.loadGlobalContentFromPage();
          print('🔄 Nouveau service créé: ${_mixedFeedService!.preparedPostsCount} posts prêts');
        }
      });
    }
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

  void _listenUnreadNotifications() {
    String _currentUserId = authProvider.loginUserData!.id!;
    if (_currentUserId == null) {
      print('⚠️ _listenUnreadNotifications: currentUserId is null');
      return;
    }

    final datingTypes = [
      'DATING_LIKE',
      'DATING_MATCH',
      'DATING_SUPER_LIKE',
      'DATING_MESSAGE',
    ];

    print('🔔 Listening for unread dating notifications for user: $_currentUserId');
    print('📋 Types recherchés: $datingTypes');

    firestore
        .collection('Notifications')
        .where('receiver_id', isEqualTo: _currentUserId)
        .where('type', whereIn: datingTypes)
        .where('is_open', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
      print('📬 Snapshot reçu: ${snapshot.docs.length} documents');
      for (var doc in snapshot.docs) {
        print('   - ${doc.id} | type: ${doc['type']} | is_open: ${doc['is_open']}');
      }
      if (mounted) setState(() => _unreadNotificationsCount = snapshot.docs.length);
    }, onError: (e) {
      print('❌ Erreur dans le stream des notifications: $e');
    });
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
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);

    return RefreshIndicator(
      onRefresh: () async {
        await authProvider.getCurrentUser(authProvider.loginUserData!.id!);
      },
      child: Drawer(
        width: MediaQuery.of(context).size.width * 0.9,
        backgroundColor: colors.background,
        child: Column(
          children: <Widget>[
            DrawerHeader(
              decoration: BoxDecoration(
                color: colors.background,
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
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        SizedBox(
                                          child: TextCustomerUserTitle(
                                            titre: "@${authProvider.loginUserData.pseudo}",
                                            fontSize: SizeText.homeProfileTextSize,
                                            couleur: colors.textPrimary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        TextCustomerUserTitle(
                                          titre: "${formatNumber(authProvider.loginUserData.userAbonnesIds!.length!)} ${l10n.profileSubscribers}",
                                          fontSize: SizeText.homeProfileTextSize,
                                          couleur: colors.textPrimary,
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ],
                                    ),
                                    SizedBox(width: 5),
                                    AbonnementUtils.getUserBadge(
                                      abonnement: authProvider.loginUserData!.abonnement,
                                      isVerified: authProvider.loginUserData!.isVerify!,
                                    ),
                                  ],
                                ),

                                /// ✅ Bouton à droite
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(context);

                                    Navigator.pushNamed(context, '/home_profile_user');
                                  },
                                  child: Text(
                                    l10n.btnViewProfile,
                                    style: TextStyle(
                                      color: colors.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            )                          ],
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Row(
                            children: [
                              TextCustomerUserTitle(
                                titre: "".toUpperCase(),
                                fontSize: SizeText.homeProfileTextSize,
                                couleur: colors.textPrimary,
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
                  ListTile(
                    trailing: Icon(Icons.arrow_right_outlined, color: colors.primary),
                    leading: Icon(Fontisto.tinder, size: 30, color: Colors.red), // Icône jaune
                    title: TextCustomerMenu(
                      titre: "Afro Love",
                      fontSize: SizeText.homeProfileTextSize,
                      couleur: colors.textPrimary, // Texte adapté au thème
                      fontWeight: FontWeight.w600,
                    ),
                    onTap: () async {
                      Navigator.pop(context);

                      Navigator.push(context, MaterialPageRoute(
                        builder: (context) => DatingSwipePage(),
                      ));
                    },
                  ),

                  // BASCULE THEME CLAIR / SOMBRE
                  Consumer<ThemeProvider>(
                    builder: (context, themeProvider, _) => ListTile(
                      leading: Icon(
                        colors.isDark ? Icons.dark_mode : Icons.light_mode,
                        color: colors.accent,
                      ),
                      title: TextCustomerMenu(
                        titre: colors.isDark ? l10n.menuDarkMode : l10n.menuLightMode,
                        fontSize: SizeText.homeProfileTextSize,
                        couleur: colors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      trailing: Switch(
                        value: themeProvider.themeMode == ThemeMode.dark,
                        activeColor: colors.primary,
                        onChanged: (value) {
                          themeProvider.setThemeMode(value ? ThemeMode.dark : ThemeMode.light);
                        },
                      ),
                      onTap: () => themeProvider.toggleTheme(),
                    ),
                  ),
                  // SÉLECTEUR DE LANGUE
                  Consumer<LocaleProvider>(
                    builder: (context, localeProvider, _) => ListTile(
                      leading: Icon(Icons.language, color: colors.primary),
                      title: TextCustomerMenu(
                        titre: l10n.menuLanguage,
                        fontSize: SizeText.homeProfileTextSize,
                        couleur: colors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      trailing: GestureDetector(
                        onTap: () => _showLanguagePicker(context, localeProvider),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: colors.surfaceVariant,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: colors.primary, width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                kSupportedLocales[localeProvider.locale.languageCode] ?? '🇫🇷 Français',
                                style: TextStyle(
                                  color: colors.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.expand_more, color: colors.primary, size: 16),
                            ],
                          ),
                        ),
                      ),
                      onTap: () => _showLanguagePicker(context, localeProvider),
                    ),
                  ),
                  // NOUVELLE OPTION: RECHERCHER UN UTILISATEUR
                  ListTile(
                    trailing: Icon(Icons.arrow_right_outlined, color: colors.primary),
                    leading: Icon(Icons.search, color: colors.primary), // Icône jaune
                    title: TextCustomerMenu(
                      titre: l10n.menuSearchUsers,
                      fontSize: SizeText.homeProfileTextSize,
                      couleur: colors.textPrimary, // Texte adapté au thème
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
                    trailing: Icon(Icons.arrow_right_outlined, color: colors.primary),
                    leading: Icon(Icons.supervised_user_circle,size: 30,                      color: colors.primary, // Icône jaune
                    ),
                    title: TextCustomerMenu(
                      titre: l10n.menuProfile,
                      fontSize: SizeText.homeProfileTextSize,
                      couleur: colors.textPrimary, // Texte adapté au thème
                      fontWeight: FontWeight.w600,
                    ),
                    onTap: () {
                      Navigator.pop(context);

                      Navigator.pushNamed(context, '/home_profile_user');
                    },
                  ),
                  ListTile(
                    trailing: Icon(Icons.arrow_right_outlined, color: colors.primary),
                    leading: Icon(Icons.emoji_events, color: colors.primary,size: 30,), // Trophée jaune
                    title: TextCustomerMenu(
                      titre: l10n.menuTopPostsMonth,
                      fontSize: SizeText.homeProfileTextSize,
                      couleur: colors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    onTap: () {
                      Navigator.pop(context); // Ferme le menu
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ChallengeMonthPage(),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    trailing: Icon(Icons.arrow_right_outlined, color: colors.primary),
                    leading: Icon(Icons.group,size: 30,
                      color: colors.primary, // Icône jaune
                    ),
                    title: TextCustomerMenu(
                      titre: l10n.menuFriends,
                      fontSize: SizeText.homeProfileTextSize,
                      couleur: colors.textPrimary, // Texte adapté au thème
                      fontWeight: FontWeight.w600,
                    ),
                    onTap: () {
                      Navigator.pop(context);

                      Navigator.pushNamed(context, '/amis');
                    },
                  ),
                  ListTile(
                    trailing: Icon(Icons.arrow_right_outlined, color: colors.primary),
                    leading: Icon(Icons.monetization_on, color: colors.primary, size: 30,),
                    title: TextCustomerMenu(
                      titre: l10n.profileMenuRemunerationSpace,
                      fontSize: SizeText.homeProfileTextSize,
                      couleur: colors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => RemunerationHomePage(user: authProvider.loginUserData!,)));
                    },
                  ),

                  // if(authProvider.loginUserData.role == UserRole.ADM.name)
                  ListTile(
                    trailing: Icon(Icons.arrow_right_outlined, color: colors.primary),
                    leading: Icon(Icons.connect_without_contact, size: 30, color: colors.primary), // Icône jaune
                    title: TextCustomerMenu(
                      titre: l10n.menuMarketing,
                      fontSize: SizeText.homeProfileTextSize,
                      couleur: colors.textPrimary, // Texte adapté au thème
                      fontWeight: FontWeight.w600,
                    ),
                    onTap: () async {
                      Navigator.pop(context);

                      Navigator.push(context, MaterialPageRoute(
                        builder: (context) => MarketingAffiliationPage(),
                      ));
                    },
                  ),
                  ListTile(
                    trailing: Icon(Icons.arrow_right_outlined, color: colors.primary),
                    leading: Icon(Entypo.trophy, size: 30, color: colors.primary), // Icône jaune
                    title: TextCustomerMenu(
                      titre: l10n.menuTopStars,
                      fontSize: SizeText.homeProfileTextSize,
                      couleur: colors.textPrimary, // Texte adapté au thème
                      fontWeight: FontWeight.w600,
                    ),
                    onTap: () async {
                      Navigator.pop(context);

                      Navigator.push(context, MaterialPageRoute(
                        builder: (context) => UserClassement(),
                      ));
                    },
                  ),
                  ListTile(
                    trailing: Icon(Icons.arrow_right_outlined, color: colors.primary),
                    leading: Icon(MaterialIcons.sports_soccer, size: 30, color: colors.primary), // Icône jaune
                    title: TextCustomerMenu(
                      titre: l10n.menuPronosticsBetting,
                      fontSize: SizeText.homeProfileTextSize,
                      couleur: colors.textPrimary, // Texte adapté au thème
                      fontWeight: FontWeight.w600,
                    ),
                    onTap: () async {
                      Navigator.pop(context);

                      Navigator.push(context, MaterialPageRoute(
                        builder: (context) => PronosticsFeedPage(),
                      ));
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
                  //     couleur: colors.textPrimary, // Texte adapté au thème
                  //     fontWeight: FontWeight.w600,
                  //   ),
                  //   subtitle: TextCustomerMenu(
                  //     titre: "Votre ami(e)",
                  //     fontSize: 9,
                  //     couleur: colors.textPrimary, // Texte adapté au thème
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
                    trailing: Icon(Icons.arrow_right_outlined, color: colors.primary),
                    leading: Icon(Icons.bookmark_outlined, color: colors.primary,size: 30,), // Icône jaune
                    title: TextCustomerMenu(
                      titre: l10n.menuFavorites,
                      fontSize: SizeText.homeProfileTextSize,
                      couleur: colors.textPrimary, // Texte adapté au thème
                      fontWeight: FontWeight.w600,
                    ),
                    onTap: () async {
                      Navigator.push(context, MaterialPageRoute(
                        builder: (context) => FavoritePostsPage(),
                      ));
                    },
                  ),
                  ListTile(
                    trailing: Icon(Icons.arrow_right_outlined, color: colors.primary),
                    leading: AnimateIcon(
                      key: UniqueKey(),
                      onTap: () {
                        Navigator.pop(context);

                        Navigator.push(context, MaterialPageRoute(
                          builder: (context) => UserServiceListPage(),
                        ));
                      },
                      iconType: IconType.continueAnimation,
                      height: 30,
                      width: 30,
                      color: colors.primary, // Icône jaune
                      animateIcon: AnimateIcons.settings,
                    ),
                    title: TextCustomerMenu(
                      titre: l10n.menuServicesJobs,
                      fontSize: SizeText.homeProfileTextSize,
                      couleur: colors.textPrimary, // Texte adapté au thème
                      fontWeight: FontWeight.w600,
                    ),
                    subtitle: TextCustomerMenu(
                      titre: l10n.menuServicesJobsSubtitle,
                      fontSize: 9,
                      couleur: colors.textPrimary, // Texte adapté au thème
                      fontWeight: FontWeight.w600,
                    ),
                    onTap: () async {
                      Navigator.push(context, MaterialPageRoute(
                        builder: (context) => UserServiceListPage(),
                      ));
                    },
                  ),

                  ListTile(
                    trailing: Icon(Icons.arrow_right_outlined, color: colors.primary),
                    leading: Icon(Icons.store_mall_directory, color: colors.primary,size: 35,), // Icône jaune
                    title: TextCustomerMenu(
                      titre: l10n.menuAfroshopMarket,
                      fontSize: SizeText.homeProfileTextSize,
                      couleur: colors.textPrimary, // Texte adapté au thème
                      fontWeight: FontWeight.w600,
                    ),
                    onTap: () async {
                      Navigator.pop(context);

                      Navigator.push(context, MaterialPageRoute(
                        builder: (context) => HomeAfroshopPage(title: ''),
                      ));
                    },
                  ),

                  ListTile(
                    trailing: Icon(
                      Icons.arrow_right_outlined,
                      color: colors.primary,
                    ),
                    leading: Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colors.primary.withOpacity(0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: colors.primary, width: 2),
                      ),
                      child: Icon(
                        AntDesign.linechart, // Icône crypto native Flutter
                        color: colors.primary,
                        size: 18,
                      ),
                    ),
                    title: TextCustomerMenu(
                      titre: l10n.menuAfroCoinMarket,
                      fontSize: SizeText.homeProfileTextSize,
                      couleur: colors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    onTap: () {
                      Navigator.pop(context);

                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => CryptoMarketPage()),
                      );
                    },
                  ),

                  ListTile(
                    trailing: Icon(Icons.live_tv, color: colors.primary),
                    leading: Icon(FontAwesome.tv, size: 30, color: colors.primary), // Icône jaune
                    title: TextCustomerMenu(
                      titre: l10n.menuMyLives,
                      fontSize: SizeText.homeProfileTextSize,
                      couleur: colors.textPrimary, // Texte adapté au thème
                      fontWeight: FontWeight.w600,
                    ),
                    onTap: () async {
                      Navigator.pop(context);

                      Navigator.push(context, MaterialPageRoute(
                        builder: (context) => UserLivesPage(),
                      ));
                    },
                  ),
                  ListTile(
                    trailing: Icon(Icons.arrow_right_outlined, color: colors.primary),
                    leading: Icon(Icons.emoji_events, size: 30, color: colors.primary), // Icône jaune
                    title: TextCustomerMenu(
                      titre: l10n.menuMyChallenges,
                      fontSize: SizeText.homeProfileTextSize,
                      couleur: colors.textPrimary, // Texte adapté au thème
                      fontWeight: FontWeight.w600,
                    ),
                    onTap: () async {
                      Navigator.pop(context);

                      Navigator.push(context, MaterialPageRoute(
                        builder: (context) => UserChallengesPage(),
                      ));
                    },
                  ),
                  ListTile(
                    trailing: Icon(Icons.info, color: colors.primary),
                    leading: Icon(Icons.info,size: 20,
                      color: colors.primary, // Icône jaune
                    ),                    title: TextCustomerMenu(
                      titre: l10n.menuNewsInfo,
                      fontSize: SizeText.homeProfileTextSize,
                      couleur: colors.textPrimary, // Texte adapté au thème
                      fontWeight: FontWeight.w600,
                    ),
                    onTap: () async {
                      Navigator.pop(context);

                      Navigator.pushNamed(context, '/app_info');

                    },
                  ),
                  ListTile(
                    trailing: Icon(Icons.arrow_right_outlined, color: colors.primary),
                    leading: Icon(FontAwesome.forumbee, size: 30, color: colors.primary), // Icône jaune
                    title: TextCustomerMenu(
                      titre: l10n.menuCanaux,
                      fontSize: SizeText.homeProfileTextSize,
                      couleur: colors.textPrimary, // Texte adapté au thème
                      fontWeight: FontWeight.w600,
                    ),
                    onTap: () async {
                      Navigator.push(context, MaterialPageRoute(
                        builder: (context) => CanalListPage(isUserCanals: false),
                      ));
                    },
                  ),


                  ListTile(
                    trailing: Icon(Icons.arrow_right_outlined, color: colors.primary),
                    leading: Icon(Icons.history_toggle_off_sharp, size: 30, color: colors.primary), // Icône jaune
                    title: TextCustomerMenu(
                      titre: l10n.menuMyChroniques,
                      fontSize: SizeText.homeProfileTextSize,
                      couleur: colors.textPrimary, // Texte adapté au thème
                      fontWeight: FontWeight.w900,
                    ),
                    onTap: () async {
                      Navigator.push(context, MaterialPageRoute(
                        builder: (context) => MyChroniquesPage(),
                      ));
                    },
                  ),


// Dans votre menu principal



                  // ListTile(
                  //   trailing: Icon(Icons.arrow_right_outlined, color: colors.primary),
                  //   leading: Image.asset(
                  //     'assets/menu/6.png',
                  //     height: 20,
                  //     width: 20,
                  //     color: colors.primary, // Icône jaune
                  //   ),
                  //   title: TextCustomerMenu(
                  //     titre: "Challenges Disponibles 🔥🎁  Gagnez un Prix 🏆",
                  //     fontSize: SizeText.homeProfileTextSize,
                  //     couleur: colors.textPrimary, // Texte adapté au thème
                  //     fontWeight: FontWeight.w600,
                  //   ),
                  //   onTap: () async {
                  //     Navigator.push(context, MaterialPageRoute(
                  //       builder: (context) => ChallengeListPage(),
                  //     ));
                  //   },
                  // ),

                  // ListTile(
                  //   trailing: Icon(Icons.arrow_right_outlined, color: colors.primary),
                  //   leading: Image.asset(
                  //     'assets/menu/6.png',
                  //     height: 20,
                  //     width: 20,
                  //     color: colors.primary, // Icône jaune
                  //   ),
                  //   title: TextCustomerMenu(
                  //     titre: "Mes Looks Challenges 🔥🎁🏆",
                  //     fontSize: SizeText.homeProfileTextSize,
                  //     couleur: colors.textPrimary, // Texte adapté au thème
                  //     fontWeight: FontWeight.w600,
                  //   ),
                  //   onTap: () async {
                  //     Navigator.push(context, MaterialPageRoute(
                  //       builder: (context) => MesLookChallengeListPage(),
                  //     ));
                  //   },
                  // ),



                  ListTile(
                    trailing: Icon(Icons.arrow_right_outlined, color: colors.primary),
                    leading: Icon(Icons.contact_mail, color: colors.primary), // Icône jaune
                    title: TextCustomerMenu(
                      titre: l10n.menuContacts,
                      fontSize: SizeText.homeProfileTextSize,
                      couleur: colors.textPrimary, // Texte adapté au thème
                      fontWeight: FontWeight.w600,
                    ),
                    onTap: () async {
                      Navigator.pop(context);

                      Navigator.pushNamed(context, '/contact');

                    },
                  ),

                  ListTile(
                    trailing: Icon(Icons.arrow_right_outlined, color: colors.primary),
                    leading: Icon(Icons.smartphone, color: colors.primary), // Icône jaune
                    title: TextCustomerMenu(
                      titre: l10n.menuShareApp,
                      fontSize: SizeText.homeProfileTextSize,
                      couleur: colors.textPrimary, // Texte adapté au thème
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
              _appVersion.isEmpty
                  ? 'Version: ...'
                  : _shorebirdPatch != null
                      ? 'Version: $_appVersion (patch $_shorebirdPatch)'
                      : 'Version: $_appVersion',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: colors.textSecondary,
              ),
            ),

            Container(
              child: Align(
                alignment: FractionalOffset.bottomCenter,
                child: Column(
                  children: <Widget>[
                    Divider(color: colors.primary), // Séparateur vert
                    ListTile(
                      leading: Icon(
                        Icons.exit_to_app,
                        color: colors.primary,
                      ),
                      title: TextCustomerMenu(
                        titre: l10n.menuLogout,
                        fontSize: 15,
                        couleur: colors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      onTap: () async {
                        await authProvider.logout(context);

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
  late final AppLifecycleListener _lifecycleListener;
  final PresenceService _presenceService = PresenceService();

  Future<void> _loadVersionInfo() async {
    final info = await PackageInfo.fromPlatform();
    final patchInfo = await ShorebirdUpdater().readCurrentPatch();
    if (mounted) {
      setState(() {
        _appVersion = info.version;
        _shorebirdPatch = patchInfo?.number;
      });
    }
  }

  @override
  void initState() {
    // _changeColor();
    super.initState();
    // Attendre que le widget soit construit

    // Future.microtask(() {
    //   InactiveUserReminderService.checkAndNotifyInactiveUsers();
    // });

    // 🔥 Lancer la présence automatique dès l'accès à la Home
    _loadVersionInfo();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleInitialDestination();
      // Gestion des notifications à chaud (app déjà ouverte)
      authProvider.loadAdvertisements();

      _listenUnreadNotifications();
      final String? uid = authProvider.loginUserData?.id;
      if (uid != null) {
        _presenceService.startHeartbeat(uid);
      }
    });
    _initializeFeedService();
    // Initialisation du listener de cycle de vie
 userProvider.updateTopUsersPopularity(authProvider.appDefaultData);
    // userProvider.getTopAfrolookeur().then((value) {
    //   // TopFiveModal.showTopFiveModal(context, value.take(5).toList());
    // },);
    //
    // _setUserOnline();
    // _initializeLifecycleListener();
    if(!widget.isOpenLink){
      // TopLiveGridModal.showTopLiveGridModal(context);
      // TopProductsGridModal.showTopProductsGridModal(context);

      // Remplacer l'appel direct par le gestionnaire de modals
      //
      //   WidgetsBinding.instance.addPostFrameCallback((_) {
      //     // Utiliser la version avancée pour plus de contrôle
      //     AdvancedModalManager.showModalsWithSmartDelay(context);
      //   });
      //   ChallengeIntegration.initialize();
      // AdvancedModalManager.showModalsWithSmartDelay(context);

        WidgetsBinding.instance.addPostFrameCallback((_) async {

            if (kIsWeb) {
              showInstallModal(context);
            }
          await authProvider.checkAppVersionAndProceed(context, () {
            // AdvancedModalManager.showModalsWithSmartDelay(context);
            // showRemunerationAnnounceModal(context,authProvider.loginUserData.id!);

            _showDailyModal();

          });
            // Appeler cette fonction quand tu veux afficher le modal

        });


    }
    // userProvider.getAllUsers().then((value) {
    //   // TopFiveModal.showTopFiveModal(context, value.take(5).toList());
    // });


    // _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController = TabController(length: 6, vsync: this);
    // Écouter le changement d'onglet
    _tabController!.addListener(() {
      if (_tabController!.indexIsChanging) return;

      if (_tabController!.index == 1) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                HomeSportPostPage(type: TabBarType.SPORT.name),
          ),
        ).then((_) {
          _tabController!.animateTo(0);
        });
      }
      if (_tabController!.index == 4) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                DashboardContentScreen(),
          ),
        ).then((_) {
          _tabController!.animateTo(0);
        });
      }
      if (_tabController!.index == 2) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                PostDetailsVideoFormatTel(isIn: true,),
            // VibesVideoPage(isIn: true,),
          ),
        ).then((_) {
          _tabController!.animateTo(0);
        });
      }
    });


    WidgetsBinding.instance.addObserver(this);

  }



  void _handleInitialDestination() {
    final dest = widget.initialDestination;
    if (dest == null) return;

    switch (dest.type) {
      case 'post':
        if (dest.post != null) {
          _navigateToPostWidget(dest.post!);
        }
        break;
      case 'chat':
        if (dest.chat != null) {
          _navigateToChatWidget(dest.chat!);
        }
        break;
      case 'chronique':
        if (dest.chroniqueId != null) {
          _navigateToChroniqueDetail(dest.chroniqueId!);
        }
        break;
      case 'chronique_home':
        _navigateToChroniqueHome();
        break;
      case 'invitation':
        _navigateToInvitations();
        break;
      case 'acceptInvitation':
        _navigateToFriends();
        break;
      case 'parrainage':
        _navigateToParrainage();
        break;
      case 'article':
        _navigateToNotifications();
        break;
    // 'home' : ne rien faire
    }
  }

// Implémentations des méthodes de navigation (vous les avez probablement déjà)
  void _navigateToPostWidget(Post post) {
    if (post.dataType == PostDataType.VIDEO.name) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => VideoYoutubePageDetails(initialPost: post)),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => DetailsPost(post: post)),
      );
    }
  }

  void _navigateToChatWidget(Chat chat) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => MyChat(title: 'mon chat', chat: chat)),
    );
  }

  void _navigateToChroniqueDetail(String chroniqueId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ChroniqueDetailPage(initialChroniqueId: chroniqueId)),
    );
  }

  void _navigateToChroniqueHome() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ChroniqueHomePage()),
    );
  }

  void _navigateToInvitations() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => MesInvitationsPage(context: context)),
    );
  }

  void _navigateToFriends() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => Amis()),
    );
  }

  void _navigateToParrainage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => MonetisationPage()),
    );
  }

  void _navigateToNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => MesNotification()),
    );
  }


  Future<void> _showDailyModal() async {
    // Période de priorité : uniquement affiliation + invite_amis jusqu'au 17 juillet 2026
    final priorityEnd = DateTime(2026, 7, 17);
    final inPriorityPeriod = DateTime.now().isBefore(priorityEnd);
    final modalKeys = inPriorityPeriod
        ? ['affiliation_marketing', 'remuneration', 'invite_amis']
        : ['remuneration', 'top_dating', 'challenge_month', 'invite_amis', 'affiliation_marketing'];
    final modalToShow = await DailyModalService.getModalToShowToday(modalKeys);
    if (modalToShow == null) return;

    if (modalToShow == 'invite_amis') {
      showInviteFriendsModal(context, authProvider.loginUserData);
    } else if (modalToShow == 'remuneration') {
      showRemunerationAnnounceModal(context, authProvider.loginUserData.id!);
    } else if (modalToShow == 'top_dating') {
      showTopDatingAnnounceModal(context);
    } else if (modalToShow == 'challenge_month') {
      showChallengeMonthAnnounceModal(context);
    } else if (modalToShow == 'affiliation_marketing') {
      showAffiliationAnnounceModal(context);
    }
    await DailyModalService.markModalShownToday(modalToShow);
  }


  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // 🔥 Très important : Arrêter le timer à la destruction de la page
    _presenceService.stopHeartbeat();
    commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    print('🔄 GESTION ÉTAT APPLICATION NATIVE: $state');

    final String? uid = authProvider.loginUserData?.id;
    if (uid == null) return;

    switch (state) {
      case AppLifecycleState.resumed:
        print('🟢 REPRISE APPLICATION : Relance du Heartbeat');
        _presenceService.startHeartbeat(uid);
        break;

      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        print('🔴 FIN DE SESSION OU ARRIÈRE-PLAN PROLONGÉ : Forcer Offline');
        _presenceService.setForceOffline();
        break;

      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      // Optionnel : On peut couper le timer sans forcer le offline Firestore immédiatement
        _presenceService.stopHeartbeat();
        break;
    }
    }


  int _currentIndex = 0;
  final PageController _pageController = PageController();
  // 🔥 Clé permettant d'appeler les actions (filtre, son, actualiser) de
  // l'onglet "Découvrir" depuis la barre supérieure combinée de homeScreen.
  final GlobalKey<State<HomeConstPostTypePage>> _discoverKey = GlobalKey();
  // 🔥 Clés pour les onglets "Looks" (récents/populaires) — même principe :
  // permettent de déclencher le filtre pays et le rafraîchissement de leur
  // AppBar "Découvrir" (supprimée) depuis la barre supérieure combinée.
  final GlobalKey<State<HomeConstPostPage>> _looksRecentKey = GlobalKey();
  final GlobalKey<State<HomeConstPostPage>> _looksPopularKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    double iconSize = width * 0.065;
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);

    // Icônes réduites et centrées
    const double navIconSize = 24;
    const double actionIconSize = 18;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: colors.background,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(150),
        child: Container(
          color: colors.surface,
          child: SafeArea(
            bottom: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Ligne 1 : "Afrolook" + Actions droite ──
                SizedBox(
                  height: 44,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Menu drawer
                      GestureDetector(
                        onTap: () => _scaffoldKey.currentState!.openDrawer(),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Icon(Icons.menu, color: colors.textPrimary, size: 22),
                        ),
                      ),
                      // Nom de l'application (réduit pour laisser plus de place aux icônes)
                      Text(
                        'Afrolook',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: colors.primary,
                          letterSpacing: 1.0,
                        ),
                      ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.1, end: 0, duration: 400.ms, curve: Curves.easeOut),
                      const Spacer(),
                      // Notifications
                      GestureDetector(
                        onTap: () => Navigator.pushNamed(context, "/mes_notifications"),
                        child: StreamBuilder<List<NotificationData>>(
                          stream: authProvider.getListNotificationAuth(authProvider.loginUserData.id!),
                          builder: (context, snap) {
                            int n = snap.hasData ? snap.data!.length : 0;
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: badges.Badge(
                                showBadge: n > 0,
                                badgeStyle: badges.BadgeStyle(badgeColor: colors.accent),
                                badgeContent: Text(n > 9 ? '9+' : '$n', style: TextStyle(fontSize: 8, color: colors.onAccent)),
                                child: Icon(Icons.notifications_none_rounded, color: colors.textPrimary, size: actionIconSize),
                              ),
                            );
                          },
                        ),
                      ),
                      // Dating / Tinder
                      GestureDetector(
                        onTap: () async {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const DatingSwipePage()));
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const DatingNotificationsPage()));
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: badges.Badge(
                            showBadge: _unreadNotificationsCount > 0,
                            badgeStyle: badges.BadgeStyle(badgeColor: colors.accent),
                            badgeContent: Text(_unreadNotificationsCount > 9 ? '9+' : '$_unreadNotificationsCount', style: TextStyle(fontSize: 8, color: colors.onAccent)),
                            child: Icon(Fontisto.tinder, color: colors.danger, size: actionIconSize),
                          ),
                        ),
                      ),
                      // Filtre (issu de la section "Découvrir")
                      GestureDetector(
                        onTap: _onTopBarFilterTap,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Icon(Icons.filter_alt_outlined, color: colors.primary, size: actionIconSize),
                        ),
                      ),
                      // Son (issu de la section "Découvrir")
                      Consumer<SoundProvider>(
                        builder: (context, soundProvider, _) => GestureDetector(
                          onTap: () => soundProvider.toggleSound(),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Icon(
                              soundProvider.isMuted ? Icons.volume_off : Icons.volume_up,
                              color: colors.primary,
                              size: actionIconSize,
                            ),
                          ),
                        ),
                      ),
                      // Actualiser (issu de la section "Découvrir")
                      GestureDetector(
                        onTap: _onTopBarRefreshTap,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Icon(Icons.refresh, color: colors.primary, size: actionIconSize),
                        ),
                      ),
                      // Toggle langue
                      Consumer<LocaleProvider>(
                        builder: (context, localeProvider, _) => GestureDetector(
                          onTap: () => _showLanguagePicker(context, localeProvider),
                          onLongPress: () => localeProvider.cycleLocale(),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Text(
                              (kSupportedLocales[localeProvider.locale.languageCode] ?? '🇫🇷').substring(0, 2),
                              style: const TextStyle(fontSize: 15),
                            ),
                          ),
                        ),
                      ),
                      // Toggle thème
                      GestureDetector(
                        onTap: () => Provider.of<ThemeProvider>(context, listen: false).toggleTheme(),
                        child: Padding(
                          padding: const EdgeInsets.only(left: 6, right: 10),
                          child: Icon(
                            colors.isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                            color: colors.primary,
                            size: actionIconSize,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // ── Ligne 2 : Navigation principale — toute la largeur ──
                Container(
                  height: 52,
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: colors.border, width: 0.5)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      // Invitations
                      GestureDetector(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MesInvitationsPage(context: context))),
                        child: StreamBuilder<int>(
                          stream: getNbrInvitation(),
                          builder: (context, snap) {
                            int n = snap.hasData ? snap.data! : 0;
                            return _navItemWithLabel(
                              icon: Icons.group_outlined,
                              activeIcon: Icons.group,
                              label: l10n.navInvitations,
                              badge: n,
                              colors: colors,
                              size: navIconSize,
                            );
                          },
                        ),
                      ),
                      // Messages
                      GestureDetector(
                        onTap: () => Navigator.pushNamed(context, '/list_users_chat'),
                        child: StreamBuilder<int>(
                          stream: getNbrMessageNonLu(),
                          builder: (context, snap) {
                            int n = snap.hasData ? snap.data! : 0;
                            return _navItemWithLabel(
                              icon: Icons.chat_bubble_outline,
                              activeIcon: Icons.chat_bubble,
                              label: l10n.navMessages,
                              badge: n,
                              colors: colors,
                              size: navIconSize,
                              activeColor: colors.info,
                            );
                          },
                        ),
                      ),
                      // Créer post — bouton central
                      GestureDetector(
                        onTap: () => authProvider.checkAppVersionAndProceed(context, () async {
                          Navigator.pushNamed(context, '/user_posts_form');
                        }),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [colors.primary, colors.accent],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(color: colors.primary.withOpacity(0.35), blurRadius: 8, spreadRadius: 1),
                                ],
                              ),
                              child: Icon(Icons.add, color: colors.onPrimary, size: navIconSize - 6),
                            ).animate(onPlay: (c) => c.repeat(reverse: true))
                                .scaleXY(begin: 1.0, end: 1.07, duration: 1200.ms, curve: Curves.easeInOut),
                            const SizedBox(height: 2),
                            Text(l10n.navCreate, style: TextStyle(fontSize: 9, color: colors.textSecondary, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                      // Vidéos
                      GestureDetector(
                        onTap: () => Navigator.pushNamed(context, '/videos'),
                        child: _navItemWithLabel(
                          icon: Icons.video_library_outlined,
                          activeIcon: Icons.video_library,
                          label: l10n.navVideos,
                          badge: 0,
                          colors: colors,
                          size: navIconSize,
                        ),
                      ),
                      // Lives
                      GestureDetector(
                        onTap: () => Navigator.pushNamed(context, '/list_live'),
                        child: StreamBuilder<int>(
                          stream: Provider.of<LiveProvider>(context, listen: false).getActiveLivesCountStream(),
                          builder: (context, snap) {
                            int n = snap.hasData ? snap.data! : 0;
                            return _navItemWithLabel(
                              icon: Icons.live_tv_outlined,
                              activeIcon: Icons.live_tv,
                              label: l10n.navLives,
                              badge: n,
                              colors: colors,
                              size: navIconSize,
                              activeColor: colors.danger,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                // ── Ligne 3 : Onglets de filtres ──
                Container(
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: colors.border, width: 0.5)),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    indicatorColor: colors.primary,
                    indicatorWeight: 2.5,
                    labelColor: colors.accent,
                    unselectedLabelColor: colors.textSecondary,
                    labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                    unselectedLabelStyle: const TextStyle(fontSize: 11),
                    tabAlignment: TabAlignment.start,
                    tabs: [
                      Tab(text: l10n.tabHome),
                      Tab(text: l10n.tabSport),
                      Tab(text: l10n.tabVibe),
                      Tab(text: l10n.tabEvents),
                      Tab(text: l10n.tabVip),
                      Tab(text: l10n.tabChallenges),
                      Tab(text: l10n.tabChroniques),
                      Tab(text: l10n.tabPopular),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      drawer: menu(context, width, MediaQuery.of(context).size.height),
      body: TabBarView(

        controller: _tabController,
        children: [
          LooksPage(type: TabBarType.LOOKS.name,sortType: 'recent', feedKey: _looksRecentKey,),
          SizedBox.shrink(), // Widget invisible pour l'onglet Sport
          SizedBox.shrink(), // Widget invisible pour l'onglet Sport

          // LooksPage(type: TabBarType.SPORT.name,sortType: 'popular',),
          // SportPage(type: TabBarType.SPORT.name),
          // HomeConstPostTypePage(type: TabBarType.SPORT.name),
          // HomeSportPostPage(type: TabBarType.SPORT.name),
          HomeConstPostTypePage(key: _discoverKey, type: TabBarType.EVENEMENT.name,sortType: 'recent',),
          SizedBox.shrink(), // Widget invisible pour l'onglet Sport
          ChallengesListPage(),
          ChroniqueHomePage(),
          LooksPage(type: TabBarType.LOOKS.name,sortType: 'popular', feedKey: _looksPopularKey,),

          // _buildDiscoverTab(),




          // LooksPage(type: TabBarType.LOOKS.name),


          // LooksPage(type: TabBarType.LOOKS.name,sortType: 'popular',),


          // VideoFeedTiktokPage(fullPage: false),
          // ActualitePage(type: TabBarType.ACTUALITES.name),
          // SportPage(type: TabBarType.SPORT.name),
          // OffrePage(type: TabBarType.OFFRES.name),
        ],
      ),

      // bottomNavigationBar supprimé — navigation déplacée en haut (style Facebook)
      bottomNavigationBar: SizedBox.shrink(),
      // ancien code conservé en commentaire ci-dessous pour référence
      /*bottomNavigationBar: Container(
        height: 70,
        decoration: BoxDecoration(
          color: colors.surface,
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
                Navigator.push(context, MaterialPageRoute(builder: (_) => MesInvitationsPage(context: context)));
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
                          badgeColor: colors.accent,
                        ),
                        badgeContent: Text(
                          invitationCount > 9 ? '9+' : '$invitationCount',
                          style: TextStyle(fontSize: 9, color: colors.onAccent),
                        ),
                        child: Icon(Icons.group, color: colors.textPrimary, size: 26),
                      ),
                      SizedBox(height: 4),
                      Text('Invitations', style: TextStyle(color: colors.textPrimary, fontSize: 10)),
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
                        badgeStyle: badges.BadgeStyle(badgeColor: colors.accent),
                        badgeContent: Text(
                          messageCount > 9 ? '9+' : '$messageCount',
                          style: TextStyle(fontSize: 9, color: colors.onAccent),
                        ),
                        child: Icon(Icons.chat_bubble_outline, color: colors.info, size: 26),
                      ),
                      SizedBox(height: 4),
                      Text('Messages', style: TextStyle(color: colors.textPrimary, fontSize: 10)),
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
                    colors: [colors.primary, colors.accent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: colors.primary.withOpacity(0.4), blurRadius: 10, spreadRadius: 2, offset: Offset(0, 3)),
                  ],
                ),
                child: Icon(Icons.add, color: colors.onPrimary, size: 30),
              ).animate(onPlay: (controller) => controller.repeat(reverse: true)).scaleXY(
                    begin: 1.0,
                    end: 1.08,
                    duration: 1200.ms,
                    curve: Curves.easeInOut,
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
                    showBadge: false,
                    badgeStyle: badges.BadgeStyle(badgeColor: colors.accent),
                    badgeContent: Text('9+', style: TextStyle(fontSize: 8, color: colors.onAccent)),
                    child: Icon(Icons.video_library, color: colors.textPrimary, size: 26),
                  ),
                  SizedBox(height: 4),
                  Text('Vidéos', style: TextStyle(color: colors.textPrimary, fontSize: 10)),
                ],
              ),
            ),
            // Bouton Menu

            GestureDetector(
              onTap: () {

                Navigator.pushNamed(context, '/list_live');
              },
              child: StreamBuilder<int>(
                stream: Provider.of<LiveProvider>(context, listen: false).getActiveLivesCountStream(),
                builder: (context, snapshot) {
                  int liveCount = snapshot.hasData ? snapshot.data! : 0;
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      badges.Badge(
                        showBadge: liveCount > 0,
                        badgeStyle: badges.BadgeStyle(badgeColor: colors.accent),
                        badgeContent: Text(
                          liveCount > 9 ? '9+' : '$liveCount',
                          style: TextStyle(fontSize: 9, color: colors.onAccent),
                        ),
                        child: Icon(Icons.live_tv, color: Colors.red, size: 26),
                      ),
                      SizedBox(height: 4),
                      Text('Lives', style: TextStyle(color: colors.textPrimary, fontSize: 10)),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),*/
    );
  }

  // 🔥 Renvoie la clé d'état du feed correspondant à l'onglet actuellement
  // affiché (Looks récents / Découvrir / Looks populaires), ou null si
  // l'onglet courant n'a pas de feed avec actions filtre/actualiser.
  GlobalKey? get _activeFeedKey {
    switch (_tabController?.index ?? 0) {
      case 0:
        return _looksRecentKey;
      case 3:
        return _discoverKey;
      case 7:
        return _looksPopularKey;
      default:
        return null;
    }
  }

  // 🔥 Déclenche le filtre pays de l'onglet actif depuis la barre du haut
  void _onTopBarFilterTap() {
    final state = _activeFeedKey?.currentState;
    if (state != null) (state as dynamic).showCountryFilter();
  }

  // 🔥 Déclenche le rafraîchissement de l'onglet actif depuis la barre du haut
  void _showLanguagePicker(BuildContext context, LocaleProvider localeProvider) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    l10n.langChoose,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colors.textPrimary),
                  ),
                ),
                Expanded(
                  child: ListView(
                    shrinkWrap: true,
                    children: kSupportedLocales.entries.map((entry) {
                      final code = entry.key;
                      final label = entry.value;
                      final isSelected = localeProvider.locale.languageCode == code;
                      return ListTile(
                        title: Text(label, style: TextStyle(color: colors.textPrimary)),
                        trailing: isSelected ? Icon(Icons.check, color: colors.primary) : null,
                        onTap: () {
                          localeProvider.setLocale(Locale(code));
                          Navigator.pop(context);
                        },
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _onTopBarRefreshTap() {
    final state = _activeFeedKey?.currentState;
    if (state != null) {
      (state as dynamic).refreshFeed();
    } else {
      _initializeFeedService();
    }
  }

  // ── Widget helper : icône de navigation avec label et badge (barre nav principale) ──
  Widget _navItemWithLabel({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int badge,
    required AppColors colors,
    required double size,
    Color? activeColor,
  }) {
    final color = activeColor ?? colors.textSecondary;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        badges.Badge(
          showBadge: badge > 0,
          badgeStyle: badges.BadgeStyle(badgeColor: colors.accent, padding: const EdgeInsets.all(3)),
          badgeContent: Text(badge > 9 ? '9+' : '$badge', style: TextStyle(fontSize: 8, color: colors.onAccent)),
          child: Icon(badge > 0 ? activeIcon : icon, color: color, size: size),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 9, color: colors.textSecondary, fontWeight: FontWeight.w500),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
