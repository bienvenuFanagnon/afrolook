import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/pages/contenuPayant/content_detail_page.dart';
import 'package:afrotok/pages/LiveAgora/create_live_page.dart';
import 'package:afrotok/pages/LiveAgora/live_list_page.dart';
import 'package:afrotok/pages/LiveAgora/livesAgora.dart';
import 'package:afrotok/pages/UserServices/deviceService.dart';
import 'package:afrotok/pages/admin/annonce.dart';
import 'package:afrotok/pages/auth/authTest/Screens/Login/loginPageUser.dart';
import 'package:afrotok/pages/auth/authTest/Screens/Welcome/welcome_screen.dart';
import 'package:afrotok/pages/bonASavoir.dart';
import 'package:afrotok/pages/chargement.dart';
import 'package:afrotok/pages/chat/myChat.dart';
import 'package:afrotok/pages/chronique/chroniquedetails.dart';
import 'package:afrotok/pages/chronique/chroniquehome.dart';
import 'package:afrotok/pages/classements/userClassement.dart';
import 'package:afrotok/pages/component/consoleWidget.dart';
import 'package:afrotok/pages/contact.dart';
import 'package:afrotok/pages/dating/buy_coins_page.dart';
import 'package:afrotok/pages/dating/coin_transactions_page.dart';
import 'package:afrotok/pages/dating/creator_profile_page.dart';
import 'package:afrotok/pages/dating/creator_subscription_page.dart';
import 'package:afrotok/pages/dating/dating_connections_page.dart';
import 'package:afrotok/pages/dating/dating_conversations_page.dart';
import 'package:afrotok/pages/dating/dating_entry_page.dart';
import 'package:afrotok/pages/dating/dating_likes_list_page.dart';
import 'package:afrotok/pages/dating/dating_notifications_page.dart';
import 'package:afrotok/pages/dating/dating_profile_setup_page.dart';
import 'package:afrotok/pages/dating/dating_profiles_list_page.dart';
import 'package:afrotok/pages/dating/dating_super_likes_list_page.dart';

import 'package:afrotok/pages/entreprise/profile/ProfileEntreprise.dart';
import 'package:afrotok/pages/entreprise/profile/newEntreprise.dart';
import 'package:afrotok/pages/home/HomeConstPost.dart';
import 'package:afrotok/pages/home/homeScreen.dart';

import 'package:afrotok/pages/info.dart';
import 'package:afrotok/pages/infoGagnePoint.dart';
import 'package:afrotok/pages/intro/introduction.dart';
import 'package:afrotok/pages/mes_notifications.dart';
import 'package:afrotok/pages/postDetails.dart';
import 'package:afrotok/pages/postDetailsVideo.dart';


import 'package:afrotok/pages/splashChargement.dart';
import 'package:afrotok/pages/splashVideo.dart';

import 'package:afrotok/pages/user/amis/addListAmis.dart';
import 'package:afrotok/pages/user/amis/ami.dart';
import 'package:afrotok/pages/user/amis/pageMesInvitations.dart';
import 'package:afrotok/pages/user/conversation/listUserConv.dart';
import 'package:afrotok/pages/user/profile/profile.dart';
import 'package:afrotok/pages/user/profile/profileDetail/page/profile_page.dart';
import 'package:afrotok/pages/user/profile/userProfileDetails.dart';
import 'package:afrotok/pages/user/monetisation.dart';
import 'package:afrotok/pages/user/userAbonnementPage.dart';
import 'package:afrotok/pages/userPosts/userPostForm.dart';
import 'package:afrotok/providers/afroshop/authAfroshopProvider.dart';
import 'package:afrotok/providers/afroshop/categorie_produits_provider.dart';
import 'package:afrotok/providers/authProvider.dart';
import 'package:afrotok/providers/chroniqueProvider.dart';
import 'package:afrotok/providers/coin_gift_provider.dart';
import 'package:afrotok/providers/contenuPayantProvider.dart';
import 'package:afrotok/providers/crypto_admin_provider.dart';
import 'package:afrotok/providers/crypto_market_provider.dart';
import 'package:afrotok/providers/crypto_portfolio_controller.dart';
import 'package:afrotok/providers/dating/coin_provider.dart';
import 'package:afrotok/providers/dating/creator_provider.dart';
import 'package:afrotok/providers/dating/dating_provider.dart';
import 'package:afrotok/providers/feed_provider.dart';
import 'package:afrotok/providers/gold_groups_provider.dart';
import 'package:afrotok/providers/mixed_feed_service_provider.dart';
import 'package:afrotok/providers/postProvider.dart';
import 'package:afrotok/providers/profilLikeProvider.dart';
import 'package:afrotok/providers/pronostic_provider.dart';
import 'package:afrotok/providers/recent_posts_provider.dart';
import 'package:afrotok/providers/sound_provider.dart';
import 'package:afrotok/providers/userProvider.dart';
import 'package:afrotok/services/ad_service.dart';
import 'package:afrotok/services/challengeMonh/challenge_month_service.dart';
import 'package:afrotok/services/linkService.dart';
import 'package:afrotok/services/nav_cache_service.dart';

import 'package:afrotok/services/workManagerService.dart';
import 'package:app_links/app_links.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:page_transition/page_transition.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'firebase_options.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'theme/app_theme.dart';
import 'theme/theme_provider.dart';
import 'providers/locale_provider.dart';
import 'l10n/app_localizations.dart';
import 'models/chatmodels/message.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:workmanager/workmanager.dart';

late List<CameraDescription> _cameras;
bool _shouldRestart = false;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialisation AdMob
  // if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
  //   AdService.setMode(false);
  //   await AdService.init();
  // }

  // Initialisation caméras
  try {
    _cameras = await availableCameras();
  } catch (e) {
    printVm("Erreur initialisation caméra : $e");
    _cameras = [];
  }

  // Initialisation Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await DeviceInfoService.initializeDeviceId();

  // OneSignal
  if (!kIsWeb) {
    OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
    OneSignal.initialize("b1b8e6b8-b9f4-4c48-b5ac-6ccae1423c98");
    OneSignal.Notifications.requestPermission(true);
  }

  initLocalNotifications();

  // Workmanager
  if (!kIsWeb) {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: false,
    );
    if (kReleaseMode) {
      // PRODUCTION : tâche périodique toutes les 15 min
      await Workmanager().registerPeriodicTask(
        afrolookTask,
        afrolookTask,
        frequency: const Duration(minutes: 15),
        initialDelay: const Duration(seconds: 10),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      );
    } else {
      // DEBUG : exécution immédiate à chaque lancement pour tester
      await Workmanager().registerOneOffTask(
        '${afrolookTask}_debug',
        afrolookTask,
        initialDelay: Duration.zero,
      );
      debugPrint('🔧 WorkManager DEBUG : one-off task lancée');
    }
  }

  // FlutterDownloader
  if (!kIsWeb) {
    await FlutterDownloader.initialize(
      debug: !kReleaseMode,
      ignoreSsl: !kReleaseMode,
    );
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _initNotificationListeners();
    _initDeepLinks();
  }

  void _initNotificationListeners() {
    if (kIsWeb) return;

    // Listener pour les clics de notification (stocke dans cache et redémarre)
    OneSignal.Notifications.addClickListener((event) async {
      printVm("📱 [NOTIFICATION] Clic détecté");

      await Future.delayed(const Duration(milliseconds: 300));

      final additionalData = event.notification.additionalData;
      if (additionalData == null) return;

      final typeNotif = additionalData['type_notif'] as String?;
      final postType = additionalData['post_type'] as String? ?? '';
      final postId = additionalData['post_id'] as String?;
      final chatId = additionalData['chat_id'] as String?;
      final sendUserId = additionalData['send_user_id'] as String?;

      // Stocker dans le cache selon le type
      if (postType == 'CHRONIQUE' ||
          typeNotif == 'CHRONIQUE' ||
          (typeNotif == 'LIKE' && postType == 'CHRONIQUE') ||
          (typeNotif == 'COMMENT' && postType == 'CHRONIQUE') ||
          (typeNotif == 'COMMENT_LIKE')) {

        if (postId != null && postId.isNotEmpty) {
          await NavigationCacheService().storeChroniqueNavigation(postId);
        } else {
          await NavigationCacheService().storePendingNavigation({'type': 'chronique_home'});
        }
      }
      else if (typeNotif == NotificationType.MESSAGE.name) {
        if (chatId != null && sendUserId != null) {
          await NavigationCacheService().storeMessageNavigation(chatId, sendUserId);
        }
      }
      else if (typeNotif == NotificationType.INVITATION.name) {
        await NavigationCacheService().storeInvitationNavigation();
      }
      else if (typeNotif == NotificationType.ACCEPTINVITATION.name) {
        await NavigationCacheService().storeAcceptInvitationNavigation();
      }
      else if (typeNotif == NotificationType.PARRAINAGE.name) {
        await NavigationCacheService().storeParrainageNavigation();
      }
      else if (typeNotif == NotificationType.ARTICLE.name) {
        await NavigationCacheService().storeArticleNavigation();
      }
      else if (typeNotif == NotificationType.POST.name || typeNotif == NotificationType.FAVORITE.name) {
        if (postId != null && postId.isNotEmpty) {
          await NavigationCacheService().storePostNavigation(postId, postType);
        }
      }

      printVm("💾 [NOTIFICATION] Données stockées dans le cache");

      // Redémarrer l'application
      _navigateToSplashAndClearStack();
    });
  }

  // Anti-doublon : évite de traiter deux fois le même lien (getInitialLink + uriLinkStream)
  String? _lastHandledLinkKey;

  Future<void> _processDeepLink(Uri uri) async {
    String? type;
    String? id;
    String? affiliateId;

    if (uri.scheme == 'afrolook') {
      // Custom scheme : afrolook://{type}/{id}?ref=...
      // Sur Android/iOS, uri.host = type, uri.pathSegments[0] = id
      type = uri.host.toLowerCase();
      id = uri.pathSegments.isNotEmpty ? uri.pathSegments[0].split('?')[0].split('#')[0] : null;
      affiliateId = uri.queryParameters['ref'];
    } else if (uri.host == 'afrolookmedia.com' &&
        uri.pathSegments.length >= 3 &&
        uri.pathSegments[0] == 'share') {
      // HTTPS App Link : https://afrolookmedia.com/share/{type}/{id}?ref=...
      type = uri.pathSegments[1].toLowerCase();
      id = uri.pathSegments[2].split('?')[0].split('#')[0];
      affiliateId = uri.queryParameters['ref'];
    }

    if (type == null || id == null || id.isEmpty) return;

    // Anti-doublon
    final dedupeKey = '$type/$id';
    if (_lastHandledLinkKey == dedupeKey) return;
    _lastHandledLinkKey = dedupeKey;

    printVm("🔗 [DEEPLINK] type=$type, id=$id, ref=$affiliateId");

    switch (type) {
      case 'contenu':
      case 'contentpaie':
        // Sauvegarder le ref affilié dans SharedPreferences pour que ContentDetailPage le lise
        if (affiliateId != null && affiliateId.isNotEmpty) {
          final prefs = await SharedPreferences.getInstance();
          final key = 'affiliate_ref_$id';
          await prefs.setString(key, affiliateId);
          await prefs.setInt('${key}_ts', DateTime.now().millisecondsSinceEpoch);
        }
        await NavigationCacheService().storeContenuNavigation(id, affiliateId: affiliateId);
        break;
      case 'creator':
        await NavigationCacheService().storeCreatorNavigation(id);
        break;
      case 'chronique':
        await NavigationCacheService().storeChroniqueNavigation(id);
        break;
      case 'group':
        await NavigationCacheService().storeGroupNavigation(id);
        break;
      case 'article':
        await NavigationCacheService().storeArticleNavigation();
        break;
      case 'video':
        await NavigationCacheService().storePostNavigation(id, 'VIDEO');
        break;
      case 'post':
      default:
        await NavigationCacheService().storePostNavigation(id, 'IMAGE');
        break;
    }

    _navigateToSplashAndClearStack();
  }

  void _initDeepLinks() {
    // Cold start : lien qui a ouvert l'app
    AppLinks().getInitialLink().then((uri) async {
      if (uri == null) return;
      printVm("🔗 [DEEPLINK] Initial: $uri");
      await _processDeepLink(uri);
    });

    // App déjà ouverte (foreground / background)
    AppLinks().uriLinkStream.listen((Uri? uri) async {
      if (uri == null) return;
      printVm("🔗 [DEEPLINK] Stream: $uri");
      await _processDeepLink(uri);
    });
  }
  final NavigationCacheService _cacheService = NavigationCacheService();

  // Nouvelle méthode : redirige vers SplashChargement sans fermer l'app
  void _navigateToSplashAndClearStack() {
    final context = _cacheService.navigatorKey.currentContext;
    if (context != null) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const SplashChargement()),
            (route) => false,
      );
    } else {
      // Fallback : attendre que le context soit disponible
      Future.delayed(const Duration(milliseconds: 150), () {
        final ctx = _cacheService.navigatorKey.currentContext;
        if (ctx != null) {
          Navigator.of(ctx).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const SplashChargement()),
                (route) => false,
          );
        } else {
          // Dernier recours (très rare) : on recharge l'app
          if (!kIsWeb) SystemNavigator.pop();
        }
      });
    }
  }
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // ... tous tes providers
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
        ChangeNotifierProvider(create: (context) => LocaleProvider()),
        ChangeNotifierProvider(create: (context) => UserShopAuthProvider()),
        ChangeNotifierProvider(create: (context) => CategorieProduitProvider()),
        ChangeNotifierProvider(create: (context) => UserAuthProvider()),
        ChangeNotifierProvider(create: (context) => UserProvider()),
        ChangeNotifierProvider(create: (context) => PostProvider()),
        ChangeNotifierProvider(create: (context) => ChroniqueProvider()),
        ChangeNotifierProvider(create: (_) => LiveProvider()),
        ChangeNotifierProvider(create: (_) => ProfileLikeProvider()),
        ChangeNotifierProvider(create: (_) => CryptoMarketProvider()),
        ChangeNotifierProvider(create: (_) => CryptoAdminProvider()),
        ChangeNotifierProvider(create: (_) => CryptoPortfolioProvider()),
        ChangeNotifierProvider(create: (_) => MixedFeedServiceProvider()),
        ChangeNotifierProvider(create: (_) => FeedProvider()),
        ChangeNotifierProvider(create: (_) => GoldGroupsProvider()),
        ChangeNotifierProvider(create: (_) => PronosticProvider()),
        ChangeNotifierProvider(create: (_) => SoundProvider()),
        ChangeNotifierProxyProvider<UserAuthProvider, CoinGiftUserProvider>(
          create: (context) => CoinGiftUserProvider(
            authProvider: context.read<UserAuthProvider>(),
          ),
          update: (context, authProvider, previous) =>
              CoinGiftUserProvider(authProvider: authProvider),
        ),
        ChangeNotifierProxyProvider<UserAuthProvider, ContentProvider>(
          create: (context) => ContentProvider(authProvider: context.read<UserAuthProvider>()),
          update: (context, authProvider, previous) => ContentProvider(authProvider: authProvider),
        ),
        ChangeNotifierProvider(
          create: (context) => RecentPostsProvider(),
          child: HomeConstPostPage(type: TabBarType.LOOKS.name,),
        ),
        ChangeNotifierProxyProvider<UserAuthProvider, DatingProvider>(
          create: (context) => DatingProvider(authProvider: context.read<UserAuthProvider>()),
          update: (context, authProvider, previous) =>
              DatingProvider(authProvider: authProvider),
        ),
        ChangeNotifierProxyProvider<UserAuthProvider, CreatorProvider>(
          create: (context) => CreatorProvider(authProvider: context.read<UserAuthProvider>()),
          update: (context, authProvider, previous) =>
              CreatorProvider(authProvider: authProvider),
        ),
        ChangeNotifierProxyProvider<UserAuthProvider, CoinProvider>(
          create: (context) => CoinProvider(authProvider: context.read<UserAuthProvider>()),
          update: (context, authProvider, previous) =>
              CoinProvider(authProvider: authProvider),
        ),
      ],
      child: Consumer2<ThemeProvider, LocaleProvider>(
        builder: (context, themeProvider, localeProvider, _) => MaterialApp(
        navigatorKey: NavigationCacheService().navigatorKey,
        navigatorObservers: [datingRouteObserver],
        title: 'Afrolook',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeProvider.themeMode,
        locale: localeProvider.locale,
        supportedLocales: kSupportedLocales.keys.map((c) => Locale(c)).toList(),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const SplashChargement(),
        onGenerateRoute: (settings) {
          switch (settings.name) {
            case '/home':
              return PageTransition(child: MyHomePage(title: ""), type: PageTransitionType.fade);
            case '/videos':
              return PageTransition(child: HomeConstPostPage(type: '', isVideoPage: true), type: PageTransitionType.fade);
            case '/home_profile_user':
              return PageTransition(child: UserProfil(), type: PageTransitionType.fade);
            case '/profile_entreprise':
              return PageTransition(child: EntrepriseProfil(), type: PageTransitionType.fade);
            case '/new_entreprise':
              return PageTransition(child: NewEntreprise(), type: PageTransitionType.fade);
            case '/bon_a_savoir':
              return PageTransition(child: BonASavoir(), type: PageTransitionType.fade);
            case '/introduction':
              return PageTransition(child: IntroductionPage(), type: PageTransitionType.fade);
            case '/basic_chat':
              return PageTransition(child: const WelcomeScreen(), type: PageTransitionType.fade);
            case '/list_users_chat':
              return PageTransition(child: const ListUserChatsOptimized(), type: PageTransitionType.fade);
            case '/mes_notifications':
              return PageTransition(child: MesNotification(), type: PageTransitionType.fade);
            case '/user_posts_form':
              return PageTransition(child: UserPostForm(), type: PageTransitionType.fade);
            case '/welcome':
              return PageTransition(child: WelcomeScreen(), type: PageTransitionType.fade);
            case '/amis':
              return PageTransition(child: Amis(), type: PageTransitionType.fade);
            case '/add_list_amis':
              return PageTransition(child: AddListAmis(), type: PageTransitionType.fade);
            case '/create_live':
              return PageTransition(child: CreateLivePage(), type: PageTransitionType.fade);
            case '/list_live':
              return PageTransition(child: LiveListPage(), type: PageTransitionType.fade);
            case '/app_info':
              return PageTransition(child: AppInfos(), type: PageTransitionType.fade);
            case '/contact':
              return PageTransition(child: ContactPage(), type: PageTransitionType.fade);
            case '/gagner_point_infos':
              return PageTransition(child: GagnerPointInfo(), type: PageTransitionType.fade);
            case '/new_annonce':
              return PageTransition(child: NewAppAnnonce(), type: PageTransitionType.fade);
            case '/profil_detail_user2':
              return PageTransition(child: UserProfileDetails(), type: PageTransitionType.fade);
            case '/profil_detail_user':
              return PageTransition(child: ProfilePage(), type: PageTransitionType.fade);
            case '/classemnent':
              return PageTransition(child: UserClassement(), type: PageTransitionType.fade);
            case '/dating':
              return PageTransition(child: DatingSwipePage(), type: PageTransitionType.fade);
            case '/dating/list':
              return PageTransition(child: DatingProfilesListPage(), type: PageTransitionType.fade);
            case '/dating/profile-setup':
              return PageTransition(child: DatingProfileSetupPage(profile: null), type: PageTransitionType.fade);
            case '/creator/profile':
              final args = settings.arguments as Map<String, dynamic>;
              return PageTransition(child: CreatorProfilePage(userId: args['userId']), type: PageTransitionType.fade);
            case '/dating/connections':
              return PageTransition(child: DatingConnectionsPage(), type: PageTransitionType.fade);
            case '/dating/conversations':
              return PageTransition(child: DatingConversationsPage(), type: PageTransitionType.fade);
            case '/creator/subscription':
              final args = settings.arguments as Map<String, dynamic>;
              return PageTransition(child: CreatorSubscriptionPage(
                creatorId: args['creatorId'],
                creatorName: args['creatorName'],
              ), type: PageTransitionType.fade);
            case '/coins/buy':
              return PageTransition(child: BuyCoinsPage(), type: PageTransitionType.fade);
            case '/coins/transactions':
              return PageTransition(child: CoinTransactionsPage(), type: PageTransitionType.fade);
            case '/dating/likes-list':
              return PageTransition(child: DatingLikesListPage(), type: PageTransitionType.fade);
            case '/dating/super-likes':
              return PageTransition(child: DatingSuperLikesPage(), type: PageTransitionType.fade);
            case '/dating/notifications':
              return PageTransition(child: DatingNotificationsPage(), type: PageTransitionType.fade);
            case '/abonnement':
              return PageTransition(child: AbonnementScreen(), type: PageTransitionType.fade);
            default:
              return PageTransition(
                child: const SplashChargement(),
                type: PageTransitionType.fade,
              );
          }
        },
        ),
      ),
    );
  }
}

// late List<CameraDescription> _cameras;
// Future<void> main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//
//   // Initialiser AdMob seulement sur mobile
//   if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
//     // await MobileAds.instance.initialize();
//     AdService.setMode(false); // À changer en false avant publication
//
//     await AdService.init();    // Configurer votre appareil comme appareil de test
//     // Remplacer par l'ID obtenu dans les logs
//     // await MobileAds.instance.updateRequestConfiguration(
//     //   RequestConfiguration(
//     //     testDeviceIds: ['011935FC78A51EF87681BE382AACD2B4','84A5B8717F83446C0B570C4358962A6A'], // Votre ID de test
//     //   ),);
//
//
//     // Mode TEST (true) / PRODUCTION (false)
//   }
//   // EMPECHE LE CRASH : On essaie de charger les caméras, mais on n'arrête pas l'app si ça échoue
//   try {
//     _cameras = await availableCameras();
//   } catch (e) {
//     printVm("Erreur initialisation caméra : $e");
//     _cameras = []; // On initialise avec une liste vide pour éviter l'erreur 'late initialization'
//   }
//
//   await Firebase.initializeApp(
//     options: DefaultFirebaseOptions.currentPlatform,
//   );
//
//   // App Check - Attention: le mode debug peut parfois bloquer sur Chrome Web
//   // await FirebaseAppCheck.instance.activate(
//   //   webProvider: ReCaptchaV3Provider('ton-site-key'), // Optionnel pour le web
//   //   androidProvider: AndroidProvider.debug,
//   //   appleProvider: AppleProvider.debug,
//   // );
//
//
//   // Date debut challenge
//   // final service = ChallengeMonthService();
//   // await service.setChallengeStartDate(DateTime(2026, 4, 1));
//   // Le reste de ton code...
//   FirebaseAuth.instance.authStateChanges().listen((User? user) {
//     if (user == null) {
//       printVm('Utilisateur non connecté');
//     } else {
//       printVm('Utilisateur connecté: ${user.uid}');
//     }
//   });
//
//   await DeviceInfoService.initializeDeviceId();
//
//   // OneSignal ne fonctionne pas toujours bien sur le Web, on l'isole
//   if (!kIsWeb) {
//     OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
//     OneSignal.initialize("b1b8e6b8-b9f4-4c48-b5ac-6ccae1423c98");
//     OneSignal.Notifications.requestPermission(true);
//   }
//
//   initLocalNotifications();
//
//   // Workmanager n'est PAS supporté sur le Web
//   if (!kIsWeb) {
//     await Workmanager().initialize(callbackDispatcher);
//     Workmanager().registerPeriodicTask(
//       afrolookTask,
//       afrolookTask,
//       frequency: const Duration(hours: 5),
//       initialDelay: const Duration(seconds: 10),
//       existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
//     );
//   }
//
//   // FlutterDownloader n'est PAS supporté sur le Web
//   if (!kIsWeb) {
//     await FlutterDownloader.initialize(
//       debug: !kReleaseMode,
//       ignoreSsl: !kReleaseMode,
//     );
//   }
//
//   runApp(const MyApp());
// }
//
// class MyApp extends StatefulWidget {
//   const MyApp({super.key});
//
//   @override
//   State<MyApp> createState() => _MyAppState();
// }
//
// class _MyAppState extends State<MyApp> {
//   final AppLinkService _appLinkService = AppLinkService();
//   final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
//   StreamSubscription<Uri>? _linkSubscription;
//
//   Future<List<Post>> getPostsVideosById(String post_id) async {
//     List<Post> posts = [];
//     CollectionReference postCollect = await FirebaseFirestore.instance.collection('Posts');
//     QuerySnapshot querySnapshotPost = await postCollect
//         .where("id", isEqualTo: '${post_id}')
//         .get();
//
//     List<Post> postList = querySnapshotPost.docs.map((doc) =>
//         Post.fromJson(doc.data() as Map<String, dynamic>)).toList();
//
//     return postList;
//   }
//   FirebaseDynamicLinks dynamicLinks = FirebaseDynamicLinks.instance;
//   Future<List<Post>> getPostsImagesById(String post_id) async {
//     List<Post> posts = [];
//     CollectionReference postCollect = await FirebaseFirestore.instance.collection('Posts');
//     QuerySnapshot querySnapshotPost = await postCollect
//         .where("id", isEqualTo: '${post_id}')
//         .get();
//
//     List<Post> postList = querySnapshotPost.docs.map((doc) =>
//         Post.fromJson(doc.data() as Map<String, dynamic>)).toList();
//
//     return postList;
//   }
//
//   void onClickNotification() {
//     try {
//       OneSignal.Notifications.addClickListener((event) async {
//         printVm("notif additionalData: ${event.notification.additionalData}");
//
//         // Petit délai pour laisser l'app s'initialiser
//         await Future.delayed(const Duration(milliseconds: 300));
//
//         final additionalData = event.notification.additionalData;
//         if (additionalData == null) return;
//
//         final typeNotif = additionalData['type_notif'] as String?;
//         final postType = additionalData['post_type'] as String? ?? '';
//         final postId = additionalData['post_id'] as String?;
//         final chatId = additionalData['chat_id'] as String?;
//         final sendUserId = additionalData['send_user_id'] as String?;
//
//         // ==================== CHRONIQUES ====================
//         if (postType == 'CHRONIQUE' ||
//             typeNotif == 'CHRONIQUE' ||
//             typeNotif == 'LIKE' && postType == 'CHRONIQUE' ||
//             typeNotif == 'COMMENT' && postType == 'CHRONIQUE' ||
//             typeNotif == 'COMMENT_LIKE') {
//
//           if (postId != null && postId.isNotEmpty) {
//             navigatorKey.currentState?.push(
//               MaterialPageRoute(
//                 builder: (context) => ChroniqueDetailPage(
//                   initialChroniqueId: postId,
//                 ),
//               ),
//             );
//           } else {
//             navigatorKey.currentState?.push(
//               MaterialPageRoute(builder: (context) => const ChroniqueHomePage()),
//             );
//           }
//           return;
//         }
//
//         // ==================== MESSAGE ====================
//         if (typeNotif == NotificationType.MESSAGE.name) {
//           try {
//             if (chatId == null || sendUserId == null) return;
//
//             final chatDoc = await FirebaseFirestore.instance
//                 .collection('Chats')
//                 .doc(chatId)
//                 .get();
//
//             if (!chatDoc.exists) return;
//
//             final chat = Chat.fromJson(chatDoc.data() as Map<String, dynamic>);
//
//             final userDoc = await FirebaseFirestore.instance
//                 .collection('Users')
//                 .doc(sendUserId)
//                 .get();
//
//             if (userDoc.exists) {
//               chat.chatFriend = UserData.fromJson(userDoc.data() as Map<String, dynamic>);
//               chat.receiver = chat.chatFriend;
//             }
//
//             final messagesSnapshot = await FirebaseFirestore.instance
//                 .collection('Messages')
//                 .where('chat_id', isEqualTo: chatId)
//                 .orderBy('createdAt', descending: true)
//                 .limit(50)
//                 .get();
//
//             chat.messages = messagesSnapshot.docs
//                 .map((doc) => Message.fromJson(doc.data() as Map<String, dynamic>))
//                 .toList();
//
//             navigatorKey.currentState?.push(
//               MaterialPageRoute(
//                 builder: (context) => MyChat(title: 'mon chat', chat: chat),
//               ),
//             );
//           } catch (e) {
//             printVm("Erreur message: $e");
//             navigatorKey.currentState?.push(
//               MaterialPageRoute(builder: (context) => MyHomePage(title: "")),
//             );
//           }
//           return;
//         }
//
//         // ==================== INVITATION ====================
//         if (typeNotif == NotificationType.INVITATION.name) {
//           navigatorKey.currentState?.push(
//             MaterialPageRoute(
//               builder: (context) => MesInvitationsPage(context: navigatorKey.currentContext!),
//             ),
//           );
//           return;
//         }
//
//         // ==================== ARTICLE ====================
//         if (typeNotif == NotificationType.ARTICLE.name) {
//           navigatorKey.currentState?.push(
//             MaterialPageRoute(builder: (context) => MesNotification()),
//           );
//           return;
//         }
//
//         // ==================== ACCEPTATION INVITATION ====================
//         if (typeNotif == NotificationType.ACCEPTINVITATION.name) {
//           navigatorKey.currentState?.push(
//             MaterialPageRoute(builder: (context) => Amis()),
//           );
//           return;
//         }
//
//         // ==================== POST (VIDEO / IMAGE) ====================
//         if (typeNotif == NotificationType.POST.name) {
//           if (postId != null && postId.isNotEmpty) {
//             navigatorKey.currentState?.push(
//               MaterialPageRoute(
//                 builder: (context) => SplashChargement(
//                   postId: postId,
//                   postType: postType,
//                 ),
//               ),
//             );
//           } else {
//             navigatorKey.currentState?.push(
//               MaterialPageRoute(builder: (context) => MyHomePage(title: "")),
//             );
//           }
//           return;
//         }
//
//         // ==================== PARRAINAGE ====================
//         if (typeNotif == NotificationType.PARRAINAGE.name) {
//           navigatorKey.currentState?.push(
//             MaterialPageRoute(builder: (context) => MonetisationPage()),
//           );
//           return;
//         }
//
//         // ==================== FAVORI ====================
//         if (typeNotif == NotificationType.FAVORITE.name) {
//           if (postId != null && postId.isNotEmpty) {
//             navigatorKey.currentState?.push(
//               MaterialPageRoute(
//                 builder: (context) => SplashChargement(
//                   postId: postId,
//                   postType: postType,
//                 ),
//               ),
//             );
//           } else {
//             navigatorKey.currentState?.push(
//               MaterialPageRoute(builder: (context) => MyHomePage(title: "")),
//             );
//           }
//           return;
//         }
//
//         // ==================== DEFAULT ====================
//         navigatorKey.currentState?.push(
//           MaterialPageRoute(builder: (context) => MyHomePage(title: "")),
//         );
//         navigatorKey.currentState?.push(
//           MaterialPageRoute(builder: (context) => MesNotification()),
//         );
//       });
//     } catch (e) {
//       printVm("erreur notification:  $e");
//       navigatorKey.currentState?.pushAndRemoveUntil(
//         MaterialPageRoute(builder: (context) => MyHomePage(title: "")),
//             (route) => false,
//       );
//     }
//   }
//   Future<void> initDeepLinks() async {
//     printVm("Lien deeplink cliqiable");
//     _linkSubscription = AppLinks().uriLinkStream.listen((Uri? uri) {
//       if (uri != null) {
//         final segments = uri.pathSegments;
//         // if (segments.length >= 3 && segments[0] == 'share') {
//         //   final typeStr = segments[1];
//         //   final id = segments[2];
//         //   printVm("Type1: $typeStr");
//         //   printVm("ID: $id");
//         //   _appLinkService.handleNavigation(navigatorKey.currentContext!, id, typeStr);
//         // }
//         if (segments.length >= 3 && segments[0] == 'share') {
//           // Nettoie l'ID en enlevant tout ce qui vient après ? ou #
//           String rawId = segments[2];
//
//           // Supprime les paramètres de requête (tout ce qui suit ? ou #)
//           final cleanId = rawId.split('?')[0].split('#')[0];
//
//           final typeStr = segments[1];
//           final id = cleanId; // Utilise l'ID nettoyé
//
//           printVm("Type1: $typeStr");
//           printVm("ID original: $rawId");
//           printVm("ID nettoyé: $id");
//
//           _appLinkService.handleNavigation(navigatorKey.currentContext!, id, typeStr);
//         }
//       }
//     }, onError: (err) {
//       printVm("Erreur de lien: $err");
//     });
//   }
//   final DynamicLinkService _dynamicLinkService = DynamicLinkService();
//   @override
//   void initState() {
//     super.initState();
//     // migratePostsCountries();
//     onClickNotification();
//     // CryptoInitializer.initializeCryptos();
//     // Initialiser les deep links
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       // MigrationAncienPostService.migrateOldPostsToCountrySystem();
//       // MigrationAncienPostService.migrateOldPostsSimple();
//       initDeepLinks();
//
//     });
//   }
//
//   @override
//   void dispose() {
//     _appLinkService.dispose();
//     _linkSubscription?.cancel();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return MultiProvider(
//       providers: [
//         ChangeNotifierProvider(create: (context) => UserShopAuthProvider()),
//         ChangeNotifierProvider(create: (context) => CategorieProduitProvider()),
//         ChangeNotifierProvider(create: (context) => UserAuthProvider()),
//         ChangeNotifierProvider(create: (context) => UserProvider()),
//         ChangeNotifierProvider(create: (context) => PostProvider()),
//         ChangeNotifierProvider(create: (context) => ChroniqueProvider()),
//         ChangeNotifierProvider(create: (_) => LiveProvider()),
//         ChangeNotifierProvider(create: (_) => ProfileLikeProvider()),
//         ChangeNotifierProvider(create: (_) => CryptoMarketProvider()),
//         ChangeNotifierProvider(create: (_) => CryptoAdminProvider()),
//         ChangeNotifierProvider(create: (_) => CryptoPortfolioProvider()),
//         ChangeNotifierProvider(create: (_) => MixedFeedServiceProvider()),
//         ChangeNotifierProvider(create: (_) => PronosticProvider()),
// // Dans main.dart, modifier l'initialisation de CoinGiftUserProvider
//         ChangeNotifierProxyProvider<UserAuthProvider, CoinGiftUserProvider>(
//           create: (context) => CoinGiftUserProvider(
//             authProvider: context.read<UserAuthProvider>(),
//           ),
//           update: (context, authProvider, previous) =>
//               CoinGiftUserProvider(authProvider: authProvider),
//         ),        // ChangeNotifierProvider(create: (_) => ChallengeProvider()),
//         ChangeNotifierProxyProvider<UserAuthProvider, ContentProvider>(
//           create: (context) => ContentProvider(authProvider: context.read<UserAuthProvider>()),
//           update: (context, authProvider, previous) => ContentProvider(authProvider: authProvider),
//
//         ),
//
//         ChangeNotifierProvider(
//           create: (context) => RecentPostsProvider(),
//           child: HomeConstPostPage(type: TabBarType.LOOKS.name,),
//         ),
//
//         // NOUVEAUX PROVIDERS
//         ChangeNotifierProxyProvider<UserAuthProvider, DatingProvider>(
//           create: (context) => DatingProvider(authProvider: context.read<UserAuthProvider>()),
//           update: (context, authProvider, previous) =>
//               DatingProvider(authProvider: authProvider),
//         ),
//         ChangeNotifierProxyProvider<UserAuthProvider, CreatorProvider>(
//           create: (context) => CreatorProvider(authProvider: context.read<UserAuthProvider>()),
//           update: (context, authProvider, previous) =>
//               CreatorProvider(authProvider: authProvider),
//         ),
//         ChangeNotifierProxyProvider<UserAuthProvider, CoinProvider>(
//           create: (context) => CoinProvider(authProvider: context.read<UserAuthProvider>()),
//           update: (context, authProvider, previous) =>
//               CoinProvider(authProvider: authProvider),
//         ),
//       ],
//       child: MaterialApp(
//           navigatorKey: navigatorKey,
//           title: 'Afrolook',
//           debugShowCheckedModeBanner: false,
//           theme: ThemeData.light().copyWith(
//             textTheme: ThemeData.light().textTheme.apply(
//               fontFamily: 'Nunito',
//             ),
//             primaryTextTheme: ThemeData.dark().textTheme.apply(
//               fontFamily: 'Nunito',
//             ),
//           ),
//           // DIRECTEMENT vers SplahsChargement optimisé - plus besoin de gestion d'état complexe
//           home: const SplashChargement(postId: '', postType: ''),
//           onGenerateRoute: (settings) {
//             switch (settings.name) {
//               case '/home':
//                 return PageTransition(child: MyHomePage(title: ""), type: PageTransitionType.fade);
//               case '/videos':
//                 // return PageTransition(child: VideoTikTokPage(), type: PageTransitionType.fade);
//                 // return PageTransition(child: AfroVideoThreads(), type: PageTransitionType.fade);
//                 return PageTransition(child: HomeConstPostPage(type: '',isVideoPage: true,), type: PageTransitionType.fade);
//               case '/home_profile_user':
//                 return PageTransition(child: UserProfil(), type: PageTransitionType.fade);
//               case '/profile_entreprise':
//                 return PageTransition(child: EntrepriseProfil(), type: PageTransitionType.fade);
//               case '/new_entreprise':
//                 return PageTransition(child: NewEntreprise(), type: PageTransitionType.fade);
//               case '/bon_a_savoir':
//                 return PageTransition(child: BonASavoir(), type: PageTransitionType.fade);
//               case '/introduction':
//                 return PageTransition(child: IntroductionPage(), type: PageTransitionType.fade);
//               case '/basic_chat':
//                 return PageTransition(child: const WelcomeScreen(), type: PageTransitionType.fade);
//                 case '/list_users_chat':
//                 return PageTransition(child: const ListUserChatsOptimized(), type: PageTransitionType.fade);
//               case '/mes_notifications':
//                 return PageTransition(child: MesNotification(), type: PageTransitionType.fade);
//               case '/user_posts_form':
//                 return PageTransition(child: UserPostForm(), type: PageTransitionType.fade);
//               case '/welcome':
//                 return PageTransition(child: WelcomeScreen(), type: PageTransitionType.fade);
//               case '/amis':
//                 return PageTransition(child: Amis(), type: PageTransitionType.fade);
//               case '/add_list_amis':
//                 return PageTransition(child: AddListAmis(), type: PageTransitionType.fade);
//
//               case '/create_live':
//                 return PageTransition(child: CreateLivePage(), type: PageTransitionType.fade);
//               case '/list_live':
//                 return PageTransition(child: LiveListPage(), type: PageTransitionType.fade);
//               case '/app_info':
//                 return PageTransition(child: AppInfos(), type: PageTransitionType.fade);
//               case '/contact':
//                 return PageTransition(child: ContactPage(), type: PageTransitionType.fade);
//               case '/gagner_point_infos':
//                 return PageTransition(child: GagnerPointInfo(), type: PageTransitionType.fade);
//               case '/new_annonce':
//                 return PageTransition(child: NewAppAnnonce(), type: PageTransitionType.fade);
//
//               case '/profil_detail_user2':
//                 return PageTransition(child: UserProfileDetails(), type: PageTransitionType.fade);
//               case '/profil_detail_user':
//                 return PageTransition(child: ProfilePage(), type: PageTransitionType.fade);
//               case '/classemnent':
//                 return PageTransition(child: UserClassement(), type: PageTransitionType.fade);
//               case '/splahs_chargement2':
//                 return PageTransition(child: SplashVideo(), type: PageTransitionType.fade);
//               case '/splahs_chargement':
//                 return PageTransition(
//                     child: const SplashChargement(postId: '', postType: ''),
//                     type: PageTransitionType.fade
//                 );
//               case '/chargement':
//                 return PageTransition(child: Chargement(), type: PageTransitionType.fade);
//               case '/login':
//                 return PageTransition(child: LoginPageUser(), type: PageTransitionType.fade);
//
//
//             // NOUVELLES ROUTES
//               case '/dating':
//                 return PageTransition(child: DatingSwipePage(), type: PageTransitionType.fade);
//               case '/dating/list':
//                 return PageTransition(child: DatingProfilesListPage(), type: PageTransitionType.fade);
//               case '/dating/profile-setup':
//                 return PageTransition(child: DatingProfileSetupPage(profile: null), type: PageTransitionType.fade);
//               case '/creator/profile':
//                 final args = settings.arguments as Map<String, dynamic>;
//                 return PageTransition(child: CreatorProfilePage(userId: args['userId']), type: PageTransitionType.fade);
//               case '/dating/connections':
//                 return PageTransition(child: DatingConnectionsPage(), type: PageTransitionType.fade);
//               case '/dating/conversations':
//                 return PageTransition(child: DatingConversationsPage(), type: PageTransitionType.fade);
//
//               case '/creator/subscription':
//                 final args = settings.arguments as Map<String, dynamic>;
//                 return PageTransition(child: CreatorSubscriptionPage(
//                   creatorId: args['creatorId'],
//                   creatorName: args['creatorName'],
//                 ), type: PageTransitionType.fade);
//               case '/coins/buy':
//                 return PageTransition(child: BuyCoinsPage(), type: PageTransitionType.fade);
//               case '/coins/transactions':
//                 return PageTransition(child: CoinTransactionsPage(), type: PageTransitionType.fade);
//               case '/dating/likes-list':
//                 return PageTransition(
//                   child: DatingLikesListPage(),
//                   type: PageTransitionType.fade,
//                 );
//               case '/dating/super-likes':
//                 return PageTransition(
//                   child: DatingSuperLikesPage(),
//                   type: PageTransitionType.fade,
//                 );
//               case '/dating/notifications':
//                 return PageTransition(
//                   child: DatingNotificationsPage(),
//                   type: PageTransitionType.fade,
//                 );
//               default:
//                 return PageTransition(
//                     child: const SplashChargement(postId: '', postType: ''),
//                     type: PageTransitionType.fade
//                 );
//             }
//           }
//       ),
//     );
//   }
// }

