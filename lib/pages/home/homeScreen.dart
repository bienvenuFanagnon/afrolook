import 'package:afrotok/utils/responsive_sheet.dart';
import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:afrotok/services/linkService.dart';
import 'package:afrotok/services/nav_cache_service.dart';
import '../user/otherUser/otherUser.dart';
import 'package:afrotok/pages/canaux/listCanal.dart';
import 'package:afrotok/pages/canaux/detailsCanal.dart';
import 'package:afrotok/pages/challengeMonth/challenge_month_page.dart';
import 'package:afrotok/pages/weekly_top/weekly_top_posts_page.dart';
import 'package:afrotok/pages/weekly_top/weekly_top_commentators_page.dart';
import 'package:afrotok/pages/regles_confidentialite_page.dart';
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
import '../../widgets/user_badge_widget.dart';
import '../../widgets/notification_toast_widget.dart';
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

import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../contenuPayant/content_detail_page.dart';
import '../contenuPayant/profileScreenContent.dart';
import '../cryptoMarket/cryptoMarketpage.dart';
import '../dating/dating_entry_page.dart';
import '../dating/dating_notifications_page.dart';
import '../dating/widgets/dating_top_modal.dart';
import '../mes_notifications.dart';
import '../postDetails.dart';
import '../postDetailsVideo.dart';
import '../post_video_format_tel_details.dart';
import '../feed/unified_feed_page.dart';
import '../../services/feed/feed_repository.dart' show FeedType;
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
import '../../providers/gold_groups_provider.dart';
import 'HomeConstPost.dart';
import '../../l10n/app_localizations.dart';
import '../../services/migrations/unread_reset_migration.dart';
import '../../layout/responsive_layout.dart';
import '../LiveAgora/live_list_page.dart';
import '../LiveAgora/livePage.dart';
import '../user/conversation/listUserConv.dart';

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
  DateTime? _lastToastTime;
  List<NotificationData> _latestUnreadNotifs = [];
  String _appVersion = '';
  int? _shorebirdPatch;
  Widget? _desktopSection;
  String? _desktopSectionTitle;
  StreamSubscription<Map<String, dynamic>>? _liveNavSub;

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
  void _setDesktopSection(Widget widget, String title) {
    setState(() {
      _desktopSection = widget;
      _desktopSectionTitle = title;
    });
  }

  void _clearDesktopSection() {
    setState(() {
      _desktopSection = null;
      _desktopSectionTitle = null;
    });
  }

  void _onScroll() => _showNotificationToastIfNeeded();

  Future<void> _launchUrl(Uri url) async {
    if (!await launchUrl(url)) {
      throw Exception('Could not launch $url');
    }
  }





  late MixedFeedService _mixedFeedService;
  bool _isGlobalContentLoading = false;
  late AnimationController _headerCtrl;
  double _scrollAccum = 0;

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
      printVm('🎯 Service de feed préchargé utilisé: ${_mixedFeedService!.preparedPostsCount} posts prêts');

      // 🔥 CHARGER LE CONTENU GLOBAL DEPUIS LA PAGE
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _mixedFeedService!.loadGlobalContentFromPage();
        printVm('🌍 Contenu global chargé depuis MyHomePage');
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
          printVm('🔄 Nouveau service créé: ${_mixedFeedService!.preparedPostsCount} posts prêts');
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
    final currentUserId = authProvider.loginUserData?.id;
    if (currentUserId == null) return;

    firestore
        .collection('Notifications')
        .where('receiver_id', isEqualTo: currentUserId)
        .where('is_open', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      final count = snapshot.docs.length;
      final latest = snapshot.docs.take(2).map((d) {
        final data = Map<String, dynamic>.from(d.data());
        data['id'] = d.id;
        return NotificationData.fromJson(data);
      }).toList();
      setState(() {
        _unreadNotificationsCount = count;
        _latestUnreadNotifs = latest;
      });
      if (count > 0 && _lastToastTime == null) {
        _showNotificationToastIfNeeded();
      }
    }, onError: (e) {
      printVm('❌ Erreur dans le stream des notifications: $e');
    });
  }

  void _showNotificationToastIfNeeded() {
    final now = DateTime.now();
    if (_lastToastTime != null &&
        now.difference(_lastToastTime!) < const Duration(minutes: 5)) return;
    if (_unreadNotificationsCount <= 0) return;
    _lastToastTime = now;
    NotificationToast.show(
      context: context,
      count: _unreadNotificationsCount,
      latestNotifs: _latestUnreadNotifs,
      onTap: () => Navigator.pushNamed(context, '/mes_notifications'),
    );
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
                                onBackgroundImageError: (_, __) {},
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
                                        ),],
                                    ),
                                    SizedBox(width: 5),
                                    UserBadgeWidget(user: authProvider.loginUserData, size: 15),
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
                  // ── Mon Profil (épinglé, toujours visible) ─────────────────
                  ListTile(
                    trailing: Icon(Icons.arrow_right_outlined, color: colors.primary),
                    leading: Icon(Icons.supervised_user_circle, size: 30, color: colors.primary),
                    title: TextCustomerMenu(
                      titre: l10n.menuProfile,
                      fontSize: SizeText.homeProfileTextSize,
                      couleur: colors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/home_profile_user');
                    },
                  ),
                  const Divider(height: 1),

                  // ── GROUPE 1 : Applications ────────────────────────────────
                  ExpansionTile(
                    initiallyExpanded: true,
                    leading: Icon(Icons.apps_rounded, color: colors.primary),
                    title: TextCustomerMenu(
                      titre: 'Applications',
                      fontSize: SizeText.homeProfileTextSize,
                      couleur: colors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                    iconColor: colors.primary,
                    collapsedIconColor: colors.textSecondary,
                    children: [
                      // Afro Love
                      ListTile(
                        contentPadding: const EdgeInsets.only(left: 32, right: 16),
                        leading: Icon(Fontisto.tinder, size: 24, color: Colors.red),
                        title: TextCustomerMenu(
                          titre: 'Afro Love',
                          fontSize: SizeText.homeProfileTextSize,
                          couleur: colors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(context, MaterialPageRoute(
                            builder: (context) => DatingSwipePage(),
                          ));
                        },
                      ),
                      // AfroShop Market — mis en avant
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: colors.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: colors.primary.withOpacity(0.4)),
                        ),
                        child: ListTile(
                          leading: Icon(Icons.store_mall_directory, size: 28, color: colors.primary),
                          title: TextCustomerMenu(
                            titre: l10n.menuAfroshopMarket,
                            fontSize: SizeText.homeProfileTextSize,
                            couleur: colors.primary,
                            fontWeight: FontWeight.w800,
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0A500),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'VIDÉOS',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(context, MaterialPageRoute(
                              builder: (context) => HomeAfroshopPage(title: ''),
                            ));
                          },
                        ),
                      ),
                      // Services & Jobs
                      ListTile(
                        contentPadding: const EdgeInsets.only(left: 32, right: 16),
                        leading: AnimateIcon(
                          key: UniqueKey(),
                          onTap: () {},
                          iconType: IconType.continueAnimation,
                          height: 24,
                          width: 24,
                          color: colors.primary,
                          animateIcon: AnimateIcons.settings,
                        ),
                        title: TextCustomerMenu(
                          titre: l10n.menuServicesJobs,
                          fontSize: SizeText.homeProfileTextSize,
                          couleur: colors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(
                            builder: (context) => UserServiceListPage(),
                          ));
                        },
                      ),
                      // Pronostics
                      ListTile(
                        contentPadding: const EdgeInsets.only(left: 32, right: 16),
                        leading: Icon(MaterialIcons.sports_soccer, size: 24, color: colors.primary),
                        title: TextCustomerMenu(
                          titre: l10n.menuPronosticsBetting,
                          fontSize: SizeText.homeProfileTextSize,
                          couleur: colors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(context, MaterialPageRoute(
                            builder: (context) => PronosticsFeedPage(),
                          ));
                        },
                      ),
                    ],
                  ),

                  // ── GROUPE 2 : Communauté ──────────────────────────────────
                  ExpansionTile(
                    leading: Icon(Icons.group, color: colors.primary),
                    title: TextCustomerMenu(
                      titre: 'Communauté',
                      fontSize: SizeText.homeProfileTextSize,
                      couleur: colors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                    iconColor: colors.primary,
                    collapsedIconColor: colors.textSecondary,
                    children: [
                      // Amis
                      ListTile(
                        contentPadding: const EdgeInsets.only(left: 32, right: 16),
                        leading: Icon(Icons.group, size: 24, color: colors.primary),
                        title: TextCustomerMenu(
                          titre: l10n.menuFriends,
                          fontSize: SizeText.homeProfileTextSize,
                          couleur: colors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, '/amis');
                        },
                      ),
                      // Canaux
                      ListTile(
                        contentPadding: const EdgeInsets.only(left: 32, right: 16),
                        leading: Icon(FontAwesome.forumbee, size: 24, color: colors.primary),
                        title: TextCustomerMenu(
                          titre: l10n.menuCanaux,
                          fontSize: SizeText.homeProfileTextSize,
                          couleur: colors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(
                            builder: (context) => CanalListPage(isUserCanals: false),
                          ));
                        },
                      ),
                      // Rechercher
                      ListTile(
                        contentPadding: const EdgeInsets.only(left: 32, right: 16),
                        leading: Icon(Icons.search, size: 24, color: colors.primary),
                        title: TextCustomerMenu(
                          titre: l10n.menuSearchUsers,
                          fontSize: SizeText.homeProfileTextSize,
                          couleur: colors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(context, MaterialPageRoute(
                            builder: (context) => AddListAmis(),
                          ));
                        },
                      ),
                      // Top Stars
                      ListTile(
                        contentPadding: const EdgeInsets.only(left: 32, right: 16),
                        leading: Icon(Entypo.trophy, size: 24, color: colors.primary),
                        title: TextCustomerMenu(
                          titre: l10n.menuTopStars,
                          fontSize: SizeText.homeProfileTextSize,
                          couleur: colors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(context, MaterialPageRoute(
                            builder: (context) => UserClassement(),
                          ));
                        },
                      ),
                      // Top Posts du mois
                      ListTile(
                        contentPadding: const EdgeInsets.only(left: 32, right: 16),
                        leading: Icon(Icons.emoji_events, size: 24, color: colors.primary),
                        title: TextCustomerMenu(
                          titre: l10n.menuTopPostsMonth,
                          fontSize: SizeText.homeProfileTextSize,
                          couleur: colors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(context, MaterialPageRoute(
                            builder: (context) => const ChallengeMonthPage(),
                          ));
                        },
                      ),
                      // Top Posts de la semaine
                      ListTile(
                        contentPadding: const EdgeInsets.only(left: 32, right: 16),
                        leading: Icon(Icons.trending_up, size: 24, color: const Color(0xFFFFD700)),
                        title: TextCustomerMenu(
                          titre: 'Top Posts de la semaine',
                          fontSize: SizeText.homeProfileTextSize,
                          couleur: colors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(context, MaterialPageRoute(
                            builder: (context) => const WeeklyTopPostsPage(),
                          ));
                        },
                      ),
                      // Top Commentateurs de la semaine
                      ListTile(
                        contentPadding: const EdgeInsets.only(left: 32, right: 16),
                        leading: const Text('💬', style: TextStyle(fontSize: 20)),
                        title: TextCustomerMenu(
                          titre: 'Top Commentateurs de la semaine',
                          fontSize: SizeText.homeProfileTextSize,
                          couleur: colors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(context, MaterialPageRoute(
                            builder: (context) => const WeeklyTopCommentatorsPage(),
                          ));
                        },
                      ),
                    ],
                  ),

                  // ── GROUPE 3 : Mes contenus ────────────────────────────────
                  ExpansionTile(
                    leading: Icon(Icons.person_outline, color: colors.primary),
                    title: TextCustomerMenu(
                      titre: 'Mes contenus',
                      fontSize: SizeText.homeProfileTextSize,
                      couleur: colors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                    iconColor: colors.primary,
                    collapsedIconColor: colors.textSecondary,
                    children: [
                      // Mes Lives
                      ListTile(
                        contentPadding: const EdgeInsets.only(left: 32, right: 16),
                        leading: Icon(FontAwesome.tv, size: 24, color: colors.primary),
                        title: TextCustomerMenu(
                          titre: l10n.menuMyLives,
                          fontSize: SizeText.homeProfileTextSize,
                          couleur: colors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(context, MaterialPageRoute(
                            builder: (context) => UserLivesPage(),
                          ));
                        },
                      ),
                      // Mes Challenges
                      ListTile(
                        contentPadding: const EdgeInsets.only(left: 32, right: 16),
                        leading: Icon(Icons.emoji_events, size: 24, color: colors.primary),
                        title: TextCustomerMenu(
                          titre: l10n.menuMyChallenges,
                          fontSize: SizeText.homeProfileTextSize,
                          couleur: colors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(context, MaterialPageRoute(
                            builder: (context) => UserChallengesPage(),
                          ));
                        },
                      ),
                      // Mes Chroniques
                      ListTile(
                        contentPadding: const EdgeInsets.only(left: 32, right: 16),
                        leading: Icon(Icons.history_toggle_off_sharp, size: 24, color: colors.primary),
                        title: TextCustomerMenu(
                          titre: l10n.menuMyChroniques,
                          fontSize: SizeText.homeProfileTextSize,
                          couleur: colors.textPrimary,
                          fontWeight: FontWeight.w900,
                        ),
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(
                            builder: (context) => MyChroniquesPage(),
                          ));
                        },
                      ),
                      // Favoris
                      ListTile(
                        contentPadding: const EdgeInsets.only(left: 32, right: 16),
                        leading: Icon(Icons.bookmark_outlined, size: 24, color: colors.primary),
                        title: TextCustomerMenu(
                          titre: l10n.menuFavorites,
                          fontSize: SizeText.homeProfileTextSize,
                          couleur: colors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(
                            builder: (context) => FavoritePostsPage(),
                          ));
                        },
                      ),
                    ],
                  ),

                  // ── GROUPE 4 : Business & Revenus ──────────────────────────
                  ExpansionTile(
                    leading: Icon(Icons.monetization_on, color: colors.primary),
                    title: TextCustomerMenu(
                      titre: 'Business & Revenus',
                      fontSize: SizeText.homeProfileTextSize,
                      couleur: colors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                    iconColor: colors.primary,
                    collapsedIconColor: colors.textSecondary,
                    children: [
                      // Rémunération
                      ListTile(
                        contentPadding: const EdgeInsets.only(left: 32, right: 16),
                        leading: Icon(Icons.monetization_on, size: 24, color: colors.primary),
                        title: TextCustomerMenu(
                          titre: l10n.profileMenuRemunerationSpace,
                          fontSize: SizeText.homeProfileTextSize,
                          couleur: colors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(
                            builder: (context) => RemunerationHomePage(user: authProvider.loginUserData!),
                          ));
                        },
                      ),
                      // Marketing
                      ListTile(
                        contentPadding: const EdgeInsets.only(left: 32, right: 16),
                        leading: Icon(Icons.connect_without_contact, size: 24, color: colors.primary),
                        title: TextCustomerMenu(
                          titre: l10n.menuMarketing,
                          fontSize: SizeText.homeProfileTextSize,
                          couleur: colors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(context, MaterialPageRoute(
                            builder: (context) => MarketingAffiliationPage(),
                          ));
                        },
                      ),
                      // Contenu Business
                      ListTile(
                        contentPadding: const EdgeInsets.only(left: 32, right: 16),
                        leading: Icon(Icons.play_lesson_outlined, size: 24, color: const Color(0xFFFFD400)),
                        title: TextCustomerMenu(
                          titre: 'Contenu Business',
                          fontSize: SizeText.homeProfileTextSize,
                          couleur: colors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(context, MaterialPageRoute(
                            builder: (_) => DashboardContentScreen(),
                          ));
                        },
                      ),
                    ],
                  ),

                  // ── GROUPE 5 : Paramètres ──────────────────────────────────
                  ExpansionTile(
                    leading: Icon(Icons.settings_outlined, color: colors.primary),
                    title: TextCustomerMenu(
                      titre: 'Paramètres',
                      fontSize: SizeText.homeProfileTextSize,
                      couleur: colors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                    iconColor: colors.primary,
                    collapsedIconColor: colors.textSecondary,
                    children: [
                      // Thème
                      Consumer<ThemeProvider>(
                        builder: (context, themeProvider, _) => ListTile(
                          contentPadding: const EdgeInsets.only(left: 32, right: 16),
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
                      // Langue
                      Consumer<LocaleProvider>(
                        builder: (context, localeProvider, _) => ListTile(
                          contentPadding: const EdgeInsets.only(left: 32, right: 16),
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
                      // Infos & MàJ
                      ListTile(
                        contentPadding: const EdgeInsets.only(left: 32, right: 16),
                        leading: Icon(Icons.info, size: 24, color: colors.primary),
                        title: TextCustomerMenu(
                          titre: l10n.menuNewsInfo,
                          fontSize: SizeText.homeProfileTextSize,
                          couleur: colors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, '/app_info');
                        },
                      ),
                      // Règles & Confidentialité
                      ListTile(
                        contentPadding: const EdgeInsets.only(left: 32, right: 16),
                        leading: Icon(Icons.gavel, size: 24, color: colors.primary),
                        title: TextCustomerMenu(
                          titre: 'Règles & Confidentialité',
                          fontSize: SizeText.homeProfileTextSize,
                          couleur: colors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(context, MaterialPageRoute(
                            builder: (_) => const ReglesConfidentialitePage(),
                          ));
                        },
                      ),
                      // Vider le cache des posts
                      ListTile(
                        contentPadding: const EdgeInsets.only(left: 32, right: 16),
                        leading: Icon(Icons.cleaning_services_outlined, size: 24, color: colors.primary),
                        title: TextCustomerMenu(
                          titre: 'Vider le cache des posts',
                          fontSize: SizeText.homeProfileTextSize,
                          couleur: colors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                        onTap: () => _clearCacheAndRefresh(context),
                      ),
                      // Contacts
                      ListTile(
                        contentPadding: const EdgeInsets.only(left: 32, right: 16),
                        leading: Icon(Icons.contact_mail, size: 24, color: colors.primary),
                        title: TextCustomerMenu(
                          titre: l10n.menuContacts,
                          fontSize: SizeText.homeProfileTextSize,
                          couleur: colors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, '/contact');
                        },
                      ),
                      // Partager l'app
                      ListTile(
                        contentPadding: const EdgeInsets.only(left: 32, right: 16),
                        leading: Icon(Icons.smartphone, size: 24, color: colors.primary),
                        title: TextCustomerMenu(
                          titre: l10n.menuShareApp,
                          fontSize: SizeText.homeProfileTextSize,
                          couleur: colors.textPrimary,
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

  Stream<int> getNbrMessageNonLu() {
    final userId = authProvider.loginUserData.id!;
    final ctrl = StreamController<int>();
    int directCount = 0;
    int groupCount = 0;

    final directSub = FirebaseFirestore.instance
        .collection('Messages')
        .where('receiverBy', isEqualTo: userId)
        .where('message_state', isEqualTo: MessageState.NONLU.name)
        .snapshots()
        .listen((snap) {
      directCount = snap.docs.length;
      printVm("messages directs non lus: $directCount");
      if (!ctrl.isClosed) ctrl.add(directCount + groupCount);
    });

    final groupSub = FirebaseFirestore.instance
        .collection('GroupChats')
        .where('member_ids', arrayContains: userId)
        .snapshots()
        .listen((snap) {
      groupCount = 0;
      for (final doc in snap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final unreadCounts = data['unread_counts'] as Map<String, dynamic>? ?? {};
        groupCount += (unreadCounts[userId] as int?) ?? 0;
      }
      printVm("messages groupes non lus: $groupCount");
      if (!ctrl.isClosed) ctrl.add(directCount + groupCount);
    });

    ctrl.onCancel = () {
      directSub.cancel();
      groupSub.cancel();
    };

    return ctrl.stream;
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

  /// Met à jour silencieusement le pays de l'utilisateur via GPS, une fois par mois.
  Future<void> _checkAndUpdateCountryMonthly() async {
    if (kIsWeb) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastUpdateMs = prefs.getInt('countryLastUpdatedMs');
      final now = DateTime.now().millisecondsSinceEpoch;
      const thirtyDaysMs = 30 * 24 * 60 * 60 * 1000;

      if (lastUpdateMs != null && (now - lastUpdateMs) < thirtyDaysMs) return;

      // Ne pas demander la permission ici — seulement si déjà accordée
      final status = await Permission.location.status;
      if (!status.isGranted) return;

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 8),
      );

      final placemarks =
          await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isEmpty) return;

      final pm = placemarks.first;
      final newCode = pm.isoCountryCode ?? '';
      if (newCode.isEmpty) return;

      final existing =
          Map<String, String>.from(authProvider.loginUserData.countryData ?? {});
      authProvider.loginUserData.countryData = {
        ...existing,
        'countryCode': newCode,
        'country': pm.country ?? existing['country'] ?? '',
        'state': pm.administrativeArea ?? existing['state'] ?? '',
        'city': pm.locality ?? existing['city'] ?? '',
      };

      await authProvider.updateUserCountryCode(authProvider.loginUserData);
      await prefs.setInt('countryLastUpdatedMs', now);
      printVm('🌍 Pays mis à jour automatiquement: $newCode');
    } catch (e) {
      printVm('⚠️ Mise à jour pays mensuelle échouée: $e');
    }
  }

  @override
  void initState() {
    // _changeColor();
    super.initState();
    _headerCtrl = AnimationController(
      vsync: this,
      value: 1.0,
      duration: const Duration(milliseconds: 300),
      reverseDuration: const Duration(milliseconds: 200),
    );
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

      // Mise à jour silencieuse du pays en arrière-plan (max 1x/mois)
      _checkAndUpdateCountryMonthly();

      // Préchargement des groupes Gold/officiels pour la liste des groupes
      context.read<GoldGroupsProvider>().load();
    });
    _initializeFeedService();
    _scrollController.addListener(_onScroll);

    // Écouter les navigations en direct (app déjà ouverte, tap notif WorkManager)
    _liveNavSub = NavigationCacheService().liveNavigationStream.listen(_handleLiveNavigation);

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
          // Onboarding centres d'intérêt pour les utilisateurs qui n'en ont pas
          if (context.mounted) {
            showInterestsOnboardingModal(context);
          }
            // Appeler cette fonction quand tu veux afficher le modal

        });


    }
    // userProvider.getAllUsers().then((value) {
    //   // TopFiveModal.showTopFiveModal(context, value.take(5).toList());
    // });


    // _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController = TabController(length: 7, vsync: this);
    // Écouter le changement d'onglet
    _tabController!.addListener(() {
      if (_tabController!.indexIsChanging) return;

      // index 1 → Sport (push + retour à 0)
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
      // index 3 → VIP (push + retour à 0)
      if (_tabController!.index == 3) {
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
    });


    WidgetsBinding.instance.addObserver(this);

  }



  // Réagit aux navigations émises en direct par WorkManager (app déjà ouverte)
  void _handleLiveNavigation(Map<String, dynamic> data) {
    if (!mounted) return;
    final type = data['type'] as String?;
    switch (type) {
      case 'creator':
        final userId = data['userId'] as String?;
        if (userId != null && userId.isNotEmpty) {
          FirebaseFirestore.instance.collection('Users').doc(userId).get().then((doc) {
            if (!mounted || !doc.exists) return;
            final user = UserData.fromJson(doc.data()!);
            Navigator.push(context, MaterialPageRoute(builder: (_) => OtherUserPage(otherUser: user)));
          });
        }
        break;
      case 'canal':
        final canalId = data['canalId'] as String?;
        if (canalId != null && canalId.isNotEmpty) {
          FirebaseFirestore.instance.collection('Canaux').doc(canalId).get().then((doc) {
            if (!mounted || !doc.exists) return;
            final canal = Canal.fromJson({...doc.data()!, 'id': doc.id});
            Navigator.push(context, MaterialPageRoute(builder: (_) => CanalDetails(canal: canal)));
          });
        }
        break;
    }
  }

  void _handleInitialDestination() {
    final dest = widget.initialDestination;
    if (dest == null) return;

    switch (dest.type) {
      case 'post':
        if (dest.post != null) {
          // Stack : home → notifications → post (retour = liste des notifs)
          _navigateViaNotifications(() => _navigateToPostWidget(dest.post!));
        }
        break;
      case 'chat':
        if (dest.chat != null) {
          _navigateToChatWidget(dest.chat!);
        }
        break;
      case 'chronique':
        if (dest.chroniqueId != null) {
          _navigateViaNotifications(() => _navigateToChroniqueDetail(dest.chroniqueId!));
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
      case 'group':
        if (dest.joinCode != null) {
          AppLinkService().navigateToGroup(context, dest.joinCode!);
        }
        break;
      case 'contenu':
        if (dest.content != null) {
          _navigateViaNotifications(() => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ContentDetailPage(content: dest.content!)),
          ));
        }
        break;
      case 'creator':
        if (dest.creatorId != null) {
          _navigateViaNotifications(() {
            FirebaseFirestore.instance.collection('Users').doc(dest.creatorId).get().then((doc) {
              if (!mounted || !doc.exists) return;
              final user = UserData.fromJson(doc.data()!);
              Navigator.push(context, MaterialPageRoute(builder: (_) => OtherUserPage(otherUser: user)));
            });
          });
        }
        break;
      case 'canal':
        if (dest.canal != null) {
          _navigateViaNotifications(() => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => CanalDetails(canal: dest.canal!)),
          ));
        }
        break;
      case 'live':
        _navigateToLive(dest.liveId);
        break;
    // 'home' : ne rien faire
    }
  }

// Implémentations des méthodes de navigation (vous les avez probablement déjà)
  void _navigateToPostWidget(Post post) {
    if (AppLayout.isDesktop(context)) {
      if (post.dataType == PostDataType.VIDEO.name) {
        _setDesktopSection(
          Navigator(
            onGenerateRoute: (_) => MaterialPageRoute(
              builder: (_) => PostDetailsVideoFormatTel(initialPost: post, isIn: false),
            ),
          ),
          'Vidéo',
        );
      } else {
        _setDesktopSection(
          Navigator(
            onGenerateRoute: (_) => MaterialPageRoute(
              builder: (_) => DetailsPost(post: post),
            ),
          ),
          post.description ?? 'Post',
        );
      }
      return;
    }
    if (post.dataType == PostDataType.VIDEO.name) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => PostDetailsVideoFormatTel(initialPost: post, isIn: false)),
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

  Future<void> _navigateToLive(String? liveId) async {
    if (liveId == null || liveId.isEmpty) {
      Navigator.pushNamed(context, '/list_live');
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('lives')
          .doc(liveId)
          .get();
      if (!mounted) return;
      if (!doc.exists) {
        Navigator.pushNamed(context, '/list_live');
        return;
      }
      final live = PostLive.fromMap(doc.data()!);
      if (live.isLive) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LivePage(
              liveId: live.liveId!,
              isHost: false,
              hostName: live.hostName ?? '',
              hostImage: live.hostImage ?? '',
              isInvited: false,
              postLive: live,
            ),
          ),
        );
      } else {
        // Live terminé → liste des lives
        Navigator.pushNamed(context, '/list_live');
      }
    } catch (_) {
      if (mounted) Navigator.pushNamed(context, '/list_live');
    }
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

  /// Pousse la page notifications dans la stack, puis appelle [then] sur le
  /// prochain frame pour empiler la destination finale au-dessus.
  /// Stack résultante : home → notifications → destination.
  void _navigateViaNotifications(VoidCallback then) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MesNotification()),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) then();
    });
  }

  void _navigateToNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => MesNotification()),
    );
  }


  Future<void> _showDailyModal() async {
    // Premier lancement sur HomeScreen → on laisse l'utilisateur découvrir l'app
    // librement. Les modals rotatifs ne démarrent qu'à partir de la 2e visite.
    if (await DailyModalService.isFirstHomeVisit()) return;

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
    _liveNavSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _headerCtrl.dispose();
    // 🔥 Très important : Arrêter le timer à la destruction de la page
    _presenceService.stopHeartbeat();
    commentController.dispose();
    _scrollController.removeListener(_onScroll);
    NotificationToast.dismiss();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    printVm('🔄 GESTION ÉTAT APPLICATION NATIVE: $state');

    final String? uid = authProvider.loginUserData?.id;
    if (uid == null) return;

    switch (state) {
      case AppLifecycleState.resumed:
        printVm('🟢 REPRISE APPLICATION : Relance du Heartbeat');
        _presenceService.startHeartbeat(uid);
        break;

      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        printVm('🔴 FIN DE SESSION OU ARRIÈRE-PLAN PROLONGÉ : Forcer Offline');
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
  final GlobalKey<State<HomeConstPostPage>> _recentFeedKey = GlobalKey();
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

    // ── Layout Wide (Tablette / Desktop ≥ 576 px) ────────────────────────
    if (AppLayout.isWide(context)) {
      return _buildWideScaffold(context, colors, l10n, width, navIconSize, actionIconSize);
    }
    // ── Layout Mobile (< 576 px) ─────────────────────────────────────────

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: colors.background,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(44),
        child: Container(
          color: colors.surface,
          child: SafeArea(
            bottom: false,
            child: SizedBox(
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
                  GestureDetector(
                    onTap: _onLogoTap,
                    child: Text(
                      'Afrolook',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: colors.primary,
                        letterSpacing: 1.0,
                      ),
                    ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.1, end: 0, duration: 400.ms, curve: Curves.easeOut),
                  ),
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
                  GestureDetector(
                    onTap: _onTopBarFilterTap,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(Icons.filter_alt_outlined, color: colors.primary, size: actionIconSize),
                    ),
                  ),
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
                  GestureDetector(
                    onTap: _onTopBarRefreshTap,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(Icons.refresh, color: colors.primary, size: actionIconSize),
                    ),
                  ),
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
          ),
        ),
      ),
      drawer: menu(context, width, MediaQuery.of(context).size.height),
      body: Column(
        children: [
          // ── Lignes 2 & 3 : glissement fluide au scroll ──
          AnimatedBuilder(
            animation: _headerCtrl,
            builder: (context, child) => ClipRect(
              child: Align(
                alignment: Alignment.topCenter,
                heightFactor: _headerCtrl.value,
                child: child,
              ),
            ),
            child: Container(
              color: colors.surface,
              child: Column(
                children: [
                  // ── Ligne 2 : Navigation principale ──
                  Container(
                    height: 52,
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: colors.border, width: 0.5)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
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
                        GestureDetector(
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DashboardContentScreen())),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.business_center_outlined, color: const Color(0xFFFFD400), size: navIconSize),
                              const SizedBox(height: 2),
                              Text('Business', style: TextStyle(fontSize: 9, color: colors.textSecondary, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
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
                        GestureDetector(
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const DatingSwipePage()));
                          },
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              badges.Badge(
                                showBadge: _unreadNotificationsCount > 0,
                                badgeStyle: badges.BadgeStyle(
                                  badgeColor: colors.accent,
                                  padding: const EdgeInsets.all(3),
                                ),
                                badgeContent: Text(
                                  _unreadNotificationsCount > 9 ? '9+' : '$_unreadNotificationsCount',
                                  style: TextStyle(fontSize: 8, color: colors.onAccent),
                                ),
                                child: Icon(Fontisto.tinder, color: Colors.red, size: navIconSize),
                              ),
                              const SizedBox(height: 2),
                              Text('Afrolove', style: TextStyle(fontSize: 9, color: colors.textSecondary, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
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
          // ── Feed ──
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification is ScrollUpdateNotification) {
                  // Ignorer les scrolls programmatiques (chargement de posts,
                  // prépend de contenu, layout) — dragDetails est null dans ce cas
                  if (notification.dragDetails == null) return false;

                  final delta = notification.scrollDelta ?? 0;
                  final pixels = notification.metrics.pixels;

                  // Toujours montrer en haut de la liste
                  if (pixels <= 0) {
                    _scrollAccum = 0;
                    if (_headerCtrl.value < 1.0) _headerCtrl.forward();
                    return false;
                  }

                  // Accumuler dans la direction courante, réinitialiser si changement
                  if (delta > 0) {
                    _scrollAccum = _scrollAccum > 0 ? _scrollAccum + delta : delta;
                  } else if (delta < 0) {
                    _scrollAccum = _scrollAccum < 0 ? _scrollAccum + delta : delta;
                  }

                  // Cacher après 25px de scroll bas continu
                  if (_scrollAccum > 25) {
                    _scrollAccum = 0;
                    if (_headerCtrl.value > 0.0) _headerCtrl.reverse();
                  // Montrer après 60px de scroll haut continu
                  } else if (_scrollAccum < -60) {
                    _scrollAccum = 0;
                    if (_headerCtrl.value < 1.0) _headerCtrl.forward();
                  }
                }
                return false;
              },
              child: TabBarView(
                controller: _tabController,
                children: _tabViewChildren,
              ),
            ),
          ),
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
      case 2:
        return _discoverKey;
      case 6:
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
    showResponsiveBottomSheet(
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

  Future<void> _clearCacheAndRefresh(BuildContext drawerCtx) async {
    Navigator.pop(drawerCtx);
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('feed_cache_')).toList();
    for (final k in keys) {
      await prefs.remove(k);
    }
    // Relance le feed depuis le réseau
    final state = _activeFeedKey?.currentState;
    if (state != null) {
      (state as dynamic).refreshFeed();
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cache vidé — rechargement des posts en cours…'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  void _onLogoTap() {
    final state = _activeFeedKey?.currentState;
    if (state != null) {
      (state as dynamic).scrollToTop();
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

  // ===========================================================================
  // RESPONSIVE — WIDE LAYOUT (Tablet ≥ 576px / Desktop > 992px)
  // ===========================================================================

  /// Enfants du TabBarView — partagés par le layout mobile et wide.
  List<Widget> get _tabViewChildren => [
    LooksPage(type: TabBarType.LOOKS.name, feedKey: _looksRecentKey),
    const SizedBox.shrink(), // Sport → push
    HomeConstPostTypePage(key: _discoverKey, type: TabBarType.EVENEMENT.name, sortType: 'recent'),
    const SizedBox.shrink(), // VIP → push
    ChallengesListPage(),
    ChroniqueHomePage(),
    LooksPage(type: TabBarType.LOOKS.name, sortType: 'popular', feedKey: _looksPopularKey),
  ];

  /// Scaffold principal pour tablette et desktop.
  Widget _buildWideScaffold(
    BuildContext context,
    AppColors colors,
    AppLocalizations l10n,
    double width,
    double navIconSize,
    double actionIconSize,
  ) {
    final isDesktop = AppLayout.isDesktop(context);
    final sidebarW = isDesktop ? AppLayout.sidebarWidth : AppLayout.sidebarNarrowWidth;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: colors.background,
      body: SafeArea(
        child: Row(
          children: [
            // ── Sidebar gauche ──────────────────────────────────────────
            SizedBox(
              width: sidebarW,
              child: _buildDesktopSidebar(context, colors, l10n, isDesktop),
            ),
            // ── Zone principale (TopBar + Tabs + Feed) ──────────────────
            Expanded(
              child: Column(
                children: [
                  _buildDesktopTopBar(context, colors, l10n, actionIconSize),
                  if (_desktopSection == null) _buildDesktopTabBar(colors, l10n),
                  Expanded(
                    child: _desktopSection != null
                        ? _buildDesktopSectionView(colors)
                        : TabBarView(
                            controller: _tabController,
                            children: _tabViewChildren,
                          ),
                  ),
                ],
              ),
            ),
            // ── Panneau droit (desktop uniquement) ──────────────────────
            if (isDesktop) _buildDesktopRightPanel(context, colors),
          ],
        ),
      ),
    );
  }

  /// Affiche une section inline (back + titre + contenu) dans la colonne centrale.
  Widget _buildDesktopSectionView(AppColors colors) {
    return Column(
      children: [
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: colors.border, width: 0.5)),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _clearDesktopSection,
                color: colors.textPrimary,
              ),
              const SizedBox(width: 4),
              Text(
                _desktopSectionTitle ?? '',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        Expanded(child: _desktopSection!),
      ],
    );
  }

  /// Sidebar gauche : logo, profil, navigation, bouton créer.
  Widget _buildDesktopSidebar(
    BuildContext context,
    AppColors colors,
    AppLocalizations l10n,
    bool wide,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(right: BorderSide(color: colors.border, width: 0.5)),
      ),
      child: Column(
        children: [
          // Logo
          Container(
            height: AppLayout.topBarHeight,
            alignment: wide ? Alignment.centerLeft : Alignment.center,
            padding: EdgeInsets.symmetric(horizontal: wide ? 14 : 0),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: colors.border, width: 0.5)),
            ),
            child: Text(
              wide ? 'Afrolook' : 'A',
              style: TextStyle(
                fontSize: wide ? 18 : 16,
                fontWeight: FontWeight.w900,
                color: colors.primary,
                letterSpacing: 0.5,
              ),
            ),
          ),
          // Profil (desktop large uniquement)
          if (wide)
            InkWell(
              onTap: () => Navigator.pushNamed(context, '/home_profile_user'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundImage: NetworkImage(authProvider.loginUserData.imageUrl ?? ''),
                      onBackgroundImageError: (_, __) {},
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '@${authProvider.loginUserData.pseudo ?? ''}',
                            style: TextStyle(fontSize: 12, color: colors.textPrimary, fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Voir mon profil',
                            style: TextStyle(fontSize: 10, color: colors.primary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (wide) Divider(color: colors.border, height: 1),
          // Navigation
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  _sidebarItem(
                    context: context,
                    icon: Icons.home_outlined,
                    label: l10n.tabHome,
                    onTap: () {},
                    wide: wide,
                    colors: colors,
                    isActive: true,
                  ),
                  // Invitations
                  StreamBuilder<int>(
                    stream: getNbrInvitation(),
                    builder: (context, snap) => _sidebarItem(
                      context: context,
                      icon: Icons.group_outlined,
                      label: l10n.navInvitations,
                      onTap: () => _setDesktopSection(MesInvitationsPage(context: context), l10n.navInvitations),
                      wide: wide,
                      colors: colors,
                      badge: snap.data ?? 0,
                    ),
                  ),
                  // Messages
                  StreamBuilder<int>(
                    stream: getNbrMessageNonLu(),
                    builder: (context, snap) => _sidebarItem(
                      context: context,
                      icon: Icons.chat_bubble_outline,
                      label: l10n.navMessages,
                      onTap: () => _setDesktopSection(const ListUserChatsOptimized(), l10n.navMessages),
                      wide: wide,
                      colors: colors,
                      badge: snap.data ?? 0,
                      iconColor: colors.info,
                    ),
                  ),
                  // Business
                  _sidebarItem(
                    context: context,
                    icon: Icons.business_center_outlined,
                    label: 'Business',
                    onTap: () => _setDesktopSection(DashboardContentScreen(), 'Business'),
                    wide: wide,
                    colors: colors,
                    iconColor: const Color(0xFFFFD400),
                  ),
                  // Vidéos
                  _sidebarItem(
                    context: context,
                    icon: Icons.video_library_outlined,
                    label: l10n.navVideos,
                    onTap: () => Navigator.pushNamed(context, '/videos'),
                    wide: wide,
                    colors: colors,
                  ),
                  // Afrolove
                  _sidebarItem(
                    context: context,
                    icon: Fontisto.tinder,
                    label: 'Afrolove',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DatingSwipePage())),
                    wide: wide,
                    colors: colors,
                    iconColor: Colors.red,
                    badge: _unreadNotificationsCount,
                  ),
                  // Lives
                  StreamBuilder<int>(
                    stream: Provider.of<LiveProvider>(context, listen: false).getActiveLivesCountStream(),
                    builder: (context, snap) => _sidebarItem(
                      context: context,
                      icon: Icons.live_tv_outlined,
                      label: l10n.navLives,
                      onTap: () => _setDesktopSection(LiveListPage(), l10n.navLives),
                      wide: wide,
                      colors: colors,
                      badge: snap.data ?? 0,
                      iconColor: colors.danger,
                    ),
                  ),
                  if (wide) ...[
                    Divider(color: colors.border, height: 16),
                    _sidebarItem(
                      context: context,
                      icon: Icons.settings_outlined,
                      label: 'Paramètres',
                      onTap: () => _scaffoldKey.currentState?.openDrawer(),
                      wide: wide,
                      colors: colors,
                    ),
                  ],
                ],
              ),
            ),
          ),
          // Bouton Créer
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: wide ? 14 : 8,
              vertical: 12,
            ),
            child: GestureDetector(
              onTap: () => authProvider.checkAppVersionAndProceed(context, () async {
                Navigator.pushNamed(context, '/user_posts_form');
              }),
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [colors.primary, colors.accent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: colors.primary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3)),
                  ],
                ),
                child: Center(
                  child: wide
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add, color: colors.onPrimary, size: 18),
                            const SizedBox(width: 6),
                            Text(l10n.navCreate, style: TextStyle(color: colors.onPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        )
                      : Icon(Icons.add, color: colors.onPrimary, size: 22),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Item de navigation pour la sidebar wide/narrow.
  Widget _sidebarItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool wide,
    required AppColors colors,
    Color? iconColor,
    int badge = 0,
    bool isActive = false,
  }) {
    final color = isActive ? colors.primary : (iconColor ?? colors.textPrimary);
    final Widget iconWidget = badges.Badge(
      showBadge: badge > 0,
      badgeStyle: badges.BadgeStyle(badgeColor: colors.accent, padding: const EdgeInsets.all(3)),
      badgeContent: Text(badge > 9 ? '9+' : '$badge', style: TextStyle(fontSize: 7, color: colors.onAccent)),
      child: Icon(icon, color: color, size: 22),
    );
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: wide ? 8 : 4, vertical: 2),
        padding: wide
            ? const EdgeInsets.symmetric(horizontal: 10, vertical: 10)
            : const EdgeInsets.symmetric(vertical: 10),
        decoration: isActive
            ? BoxDecoration(
                color: colors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              )
            : null,
        child: wide
            ? Row(children: [
                iconWidget,
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      color: isActive ? colors.primary : colors.textPrimary,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ])
            : Center(child: iconWidget),
      ),
    );
  }

  /// TopBar horizontale pour desktop/tablette (remplace les lignes 1+2 de l'AppBar mobile).
  Widget _buildDesktopTopBar(
    BuildContext context,
    AppColors colors,
    AppLocalizations l10n,
    double actionIconSize,
  ) {
    return Container(
      height: AppLayout.topBarHeight,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.border, width: 0.5)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Barre de recherche
          Expanded(
            child: Container(
              height: 36,
              constraints: const BoxConstraints(maxWidth: 400),
              decoration: BoxDecoration(
                color: colors.background,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: colors.border),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  Icon(Icons.search, color: colors.textSecondary, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Rechercher sur Afrolook…',
                    style: TextStyle(color: colors.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Actions
          StreamBuilder<List<NotificationData>>(
            stream: authProvider.getListNotificationAuth(authProvider.loginUserData.id!),
            builder: (context, snap) {
              int n = snap.hasData ? snap.data!.length : 0;
              return GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/mes_notifications'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: badges.Badge(
                    showBadge: n > 0,
                    badgeStyle: badges.BadgeStyle(badgeColor: colors.accent),
                    badgeContent: Text(n > 9 ? '9+' : '$n', style: TextStyle(fontSize: 8, color: colors.onAccent)),
                    child: Icon(Icons.notifications_none_rounded, color: colors.textPrimary, size: actionIconSize + 2),
                  ),
                ),
              );
            },
          ),
          GestureDetector(
            onTap: _onTopBarFilterTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Icon(Icons.filter_alt_outlined, color: colors.primary, size: actionIconSize + 2),
            ),
          ),
          Consumer<SoundProvider>(
            builder: (_, sp, __) => GestureDetector(
              onTap: sp.toggleSound,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Icon(sp.isMuted ? Icons.volume_off : Icons.volume_up, color: colors.primary, size: actionIconSize + 2),
              ),
            ),
          ),
          GestureDetector(
            onTap: _onTopBarRefreshTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Icon(Icons.refresh, color: colors.primary, size: actionIconSize + 2),
            ),
          ),
          Consumer<LocaleProvider>(
            builder: (_, lp, __) => GestureDetector(
              onTap: () => _showLanguagePicker(context, lp),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  (kSupportedLocales[lp.locale.languageCode] ?? '🇫🇷').substring(0, 2),
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: () => Provider.of<ThemeProvider>(context, listen: false).toggleTheme(),
            child: Padding(
              padding: const EdgeInsets.only(left: 6, right: 4),
              child: Icon(
                colors.isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                color: colors.primary,
                size: actionIconSize + 2,
              ),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/home_profile_user'),
            child: CircleAvatar(
              radius: 16,
              backgroundImage: NetworkImage(authProvider.loginUserData.imageUrl ?? ''),
              onBackgroundImageError: (_, __) {},
            ),
          ),
        ],
      ),
    );
  }

  /// Barre d'onglets (ligne 3 du mobile, identique sur wide).
  Widget _buildDesktopTabBar(AppColors colors, AppLocalizations l10n) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.border, width: 0.5)),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        indicatorColor: colors.primary,
        indicatorWeight: 2.5,
        labelColor: colors.accent,
        unselectedLabelColor: colors.textSecondary,
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 12),
        tabAlignment: TabAlignment.start,
        tabs: [
          Tab(text: l10n.tabHome),
          Tab(text: l10n.tabSport),
          Tab(text: l10n.tabEvents),
          Tab(text: l10n.tabVip),
          Tab(text: l10n.tabChallenges),
          Tab(text: l10n.tabChroniques),
          Tab(text: l10n.tabPopular),
        ],
      ),
    );
  }

  /// Panneau droit persistant (desktop > 992px) — suggestions, tendances.
  /// Panneau droit — miroir du menu() drawer, adapté en liste scrollable.
  Widget _buildDesktopRightPanel(BuildContext context, AppColors colors) {
    final l10n = AppLocalizations.of(context);
    return Container(
      width: AppLayout.rightPanelWidth,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(left: BorderSide(color: colors.border, width: 0.5)),
      ),
      child: Column(
        children: [
          // ── En-tête profil ──────────────────────────────────────────
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/home_profile_user'),
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              decoration: BoxDecoration(
                color: colors.background,
                border: Border(bottom: BorderSide(color: colors.border, width: 0.5)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundImage: NetworkImage(authProvider.loginUserData.imageUrl ?? ''),
                    onBackgroundImageError: (_, __) {},
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                '@${authProvider.loginUserData.pseudo ?? ''}',
                                style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            UserBadgeWidget(user: authProvider.loginUserData, size: 13),
                          ],
                        ),
                        Text(
                          authProvider.loginUserData.userPays?.name ?? '',
                          style: TextStyle(color: colors.textSecondary, fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: colors.textSecondary, size: 16),
                ],
              ),
            ),
          ),

          // ── Liste menu scrollable ───────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 6),
              children: [

                // ── Réseaux sociaux ──────────────────────────────────
                _rpSection(colors, 'Réseaux'),
                _rpItem(context, colors, icon: Fontisto.tinder, iconColor: Colors.red,     label: 'Afro Love',            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DatingSwipePage()))),
                _rpItem(context, colors, icon: Icons.group,                                label: l10n.menuFriends,        onTap: () => _setDesktopSection(Amis(), l10n.menuFriends)),
                _rpItem(context, colors, icon: Icons.search,                               label: l10n.menuSearchUsers,    onTap: () => _setDesktopSection(AddListAmis(), l10n.menuSearchUsers)),
                _rpItem(context, colors, icon: Icons.notifications_none_rounded,           label: 'Notifications',         onTap: () => _setDesktopSection(MesNotification(), 'Notifications')),
                _rpItem(context, colors, icon: Icons.chat_bubble_outline,                  label: l10n.navMessages,        onTap: () => _setDesktopSection(const ListUserChatsOptimized(), l10n.navMessages)),

                // ── Mon contenu ──────────────────────────────────────
                _rpSection(colors, 'Mon contenu'),
                _rpItem(context, colors, icon: Icons.supervised_user_circle,               label: l10n.menuProfile,        onTap: () => Navigator.pushNamed(context, '/home_profile_user')),
                _rpItem(context, colors, icon: Icons.bookmark_outlined,                    label: l10n.menuFavorites,       onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FavoritePostsPage()))),
                _rpItem(context, colors, icon: Icons.history_toggle_off_sharp,             label: l10n.menuMyChroniques,    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MyChroniquesPage()))),
                _rpItem(context, colors, icon: Icons.emoji_events,                         label: l10n.menuMyChallenges,    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => UserChallengesPage()))),
                _rpItem(context, colors, icon: FontAwesome.tv,                             label: l10n.menuMyLives,         onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => UserLivesPage()))),

                // ── Business & Monétisation ──────────────────────────
                _rpSection(colors, 'Business'),
                _rpItem(context, colors, icon: Icons.play_lesson_outlined, iconColor: const Color(0xFFFFD400), label: 'Contenu Business', onTap: () => _setDesktopSection(DashboardContentScreen(), 'Business')),
                _rpItem(context, colors, icon: Icons.monetization_on,                      label: l10n.profileMenuRemunerationSpace, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RemunerationHomePage(user: authProvider.loginUserData)))),
                _rpItem(context, colors, icon: Icons.connect_without_contact,              label: l10n.menuMarketing,       onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MarketingAffiliationPage()))),
                _rpItem(context, colors, icon: AntDesign.linechart,                        label: l10n.menuAfroCoinMarket,  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CryptoMarketPage()))),

                // ── Découverte ───────────────────────────────────────
                _rpSection(colors, 'Découverte'),
                _rpItem(context, colors, icon: Entypo.trophy,                              label: l10n.menuTopStars,        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UserClassement()))),
                _rpItem(context, colors, icon: Icons.emoji_events,                         label: l10n.menuTopPostsMonth,   onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChallengeMonthPage()))),
                _rpItem(context, colors, icon: MaterialIcons.sports_soccer,                label: l10n.menuPronosticsBetting, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PronosticsFeedPage()))),
                _rpItem(context, colors, icon: FontAwesome.forumbee,                       label: l10n.menuCanaux,          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CanalListPage(isUserCanals: false)))),
                _rpItem(context, colors, icon: Icons.store_mall_directory,                 label: l10n.menuAfroshopMarket,  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HomeAfroshopPage(title: '')))),
                _rpItem(context, colors, icon: Icons.settings_outlined,                    label: l10n.menuServicesJobs,    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => UserServiceListPage()))),

                // ── Paramètres & Divers ──────────────────────────────
                _rpSection(colors, 'Paramètres'),
                // Thème
                Consumer<ThemeProvider>(
                  builder: (_, tp, __) => _rpItemWidget(
                    context: context,
                    colors: colors,
                    icon: colors.isDark ? Icons.dark_mode : Icons.light_mode,
                    label: colors.isDark ? l10n.menuDarkMode : l10n.menuLightMode,
                    onTap: tp.toggleTheme,
                    trailing: Switch(
                      value: tp.themeMode == ThemeMode.dark,
                      activeColor: colors.primary,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onChanged: (_) => tp.toggleTheme(),
                    ),
                  ),
                ),
                // Langue
                Consumer<LocaleProvider>(
                  builder: (_, lp, __) => _rpItemWidget(
                    context: context,
                    colors: colors,
                    icon: Icons.language,
                    label: l10n.menuLanguage,
                    onTap: () => _showLanguagePicker(context, lp),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: colors.surfaceVariant,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colors.primary),
                      ),
                      child: Text(
                        kSupportedLocales[lp.locale.languageCode] ?? '🇫🇷',
                        style: TextStyle(fontSize: 11, color: colors.primary, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
                _rpItem(context, colors, icon: Icons.info_outline,                         label: l10n.menuNewsInfo,        onTap: () => Navigator.pushNamed(context, '/app_info')),
                _rpItem(context, colors, icon: Icons.contact_mail,                         label: l10n.menuContacts,        onTap: () => Navigator.pushNamed(context, '/contact')),
                _rpItem(context, colors, icon: Icons.smartphone,                           label: l10n.menuShareApp,        onTap: () async {
                  await authProvider.getAppData();
                  Share.shareUri(Uri.parse('${authProvider.appDefaultData.app_link}'));
                }),

                const SizedBox(height: 8),
                Divider(color: colors.border),

                // ── Déconnexion ──────────────────────────────────────
                _rpItem(context, colors,
                  icon: Icons.exit_to_app,
                  iconColor: colors.danger,
                  label: l10n.menuLogout,
                  labelColor: colors.danger,
                  onTap: () => authProvider.logout(context),
                ),

                // ── Version ─────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 16),
                  child: Text(
                    'v$_appVersion${_shorebirdPatch != null ? ' · patch $_shorebirdPatch' : ''}',
                    style: TextStyle(color: colors.textSecondary, fontSize: 10),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Section header dans le panneau droit.
  Widget _rpSection(AppColors colors, String title) => Padding(
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
    child: Text(title, style: TextStyle(color: colors.textSecondary, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
  );

  /// Item simple (icône + label + flèche) dans le panneau droit.
  Widget _rpItem(
    BuildContext context,
    AppColors colors, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? iconColor,
    Color? labelColor,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Row(
          children: [
            Icon(icon, size: 20, color: iconColor ?? colors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontSize: 13, color: labelColor ?? colors.textPrimary, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.chevron_right, size: 14, color: colors.textSecondary),
          ],
        ),
      ),
    );
  }

  /// Item avec widget trailing personnalisé (switch, badge...).
  Widget _rpItemWidget({
    required BuildContext context,
    required AppColors colors,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Widget trailing,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        child: Row(
          children: [
            Icon(icon, size: 20, color: colors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label, style: TextStyle(fontSize: 13, color: colors.textPrimary, fontWeight: FontWeight.w500)),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}
