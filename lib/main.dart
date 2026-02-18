import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:afrotok/models/model_data.dart';
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
import 'package:afrotok/pages/classements/userClassement.dart';
import 'package:afrotok/pages/component/consoleWidget.dart';
import 'package:afrotok/pages/contact.dart';
import 'package:afrotok/pages/entreprise/conversation/entrepriseConversation.dart';
import 'package:afrotok/pages/entreprise/produit/ajouterProduit.dart';
import 'package:afrotok/pages/entreprise/produit/ajouterUnPub.dart';
import 'package:afrotok/pages/entreprise/profile/ProfileEntreprise.dart';
import 'package:afrotok/pages/entreprise/profile/newEntreprise.dart';
import 'package:afrotok/pages/home/HomeConstPost.dart';
import 'package:afrotok/pages/home/homeLooks.dart';
import 'package:afrotok/pages/home/homeScreen.dart';

import 'package:afrotok/pages/info.dart';
import 'package:afrotok/pages/infoGagnePoint.dart';
import 'package:afrotok/pages/intro/introduction.dart';
import 'package:afrotok/pages/mes_notifications.dart';
import 'package:afrotok/pages/postComments.dart';
import 'package:afrotok/pages/postDetails.dart';
import 'package:afrotok/pages/postDetailsVideoListe.dart';
import 'package:afrotok/pages/socialVideos/thread/afrolookVideoOriginal.dart';

import 'package:afrotok/pages/socialVideos/thread/afrolookVideoThread.dart';
import 'package:afrotok/pages/socialVideos/video_details.dart';
import 'package:afrotok/pages/splashChargement.dart';
import 'package:afrotok/pages/splashVideo.dart';

import 'package:afrotok/pages/story/storieForm.dart';
import 'package:afrotok/pages/user/amis/addListAmis.dart';
import 'package:afrotok/pages/user/amis/ami.dart';
import 'package:afrotok/pages/user/amis/pageMesInvitations.dart';
import 'package:afrotok/pages/user/conversation/listEntrepriseConv.dart';
import 'package:afrotok/pages/user/conversation/listUserConv.dart';
import 'package:afrotok/pages/user/profile/profile.dart';
import 'package:afrotok/pages/user/profile/profileDetail/page/profile_page.dart';
import 'package:afrotok/pages/user/profile/userProfileDetails.dart';
import 'package:afrotok/pages/user/monetisation.dart';
import 'package:afrotok/pages/userPosts/postPhotoEditor.dart';
import 'package:afrotok/pages/userPosts/userPostForm.dart';
import 'package:afrotok/providers/afroshop/authAfroshopProvider.dart';
import 'package:afrotok/providers/afroshop/categorie_produits_provider.dart';
import 'package:afrotok/providers/authProvider.dart';
import 'package:afrotok/providers/chroniqueProvider.dart';
// import 'package:afrotok/providers/challenge_provider.dart';
import 'package:afrotok/providers/contenuPayantProvider.dart';
import 'package:afrotok/providers/crypto_admin_provider.dart';
import 'package:afrotok/providers/crypto_initializer.dart';
import 'package:afrotok/providers/crypto_market_provider.dart';
import 'package:afrotok/providers/crypto_portfolio_controller.dart';
import 'package:afrotok/providers/mixed_feed_service_provider.dart';
import 'package:afrotok/providers/postProvider.dart';
import 'package:afrotok/providers/profilLikeProvider.dart';
import 'package:afrotok/providers/recent_posts_provider.dart';
import 'package:afrotok/providers/userProvider.dart';
import 'package:afrotok/services/LocalNotifications.dart';
import 'package:afrotok/services/linkService.dart';
import 'package:afrotok/services/postPrepareService.dart';
import 'package:afrotok/services/postService/cachvideoService.dart';
import 'package:afrotok/services/serviceMigrationAncienPost.dart';
import 'package:afrotok/services/workManagerService.dart';
import 'package:app_links/app_links.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:deeplynks/deeplynks.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:page_transition/page_transition.dart';
import 'package:provider/provider.dart';
import 'package:upgrader/upgrader.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'firebase_options.dart';
import 'models/chatmodels/message.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:workmanager/workmanager.dart';
// Import du service App Links

late List<CameraDescription> _cameras;
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // EMPECHE LE CRASH : On essaie de charger les caméras, mais on n'arrête pas l'app si ça échoue
  try {
    _cameras = await availableCameras();
  } catch (e) {
    print("Erreur initialisation caméra : $e");
    _cameras = []; // On initialise avec une liste vide pour éviter l'erreur 'late initialization'
  }

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // App Check - Attention: le mode debug peut parfois bloquer sur Chrome Web
  // await FirebaseAppCheck.instance.activate(
  //   webProvider: ReCaptchaV3Provider('ton-site-key'), // Optionnel pour le web
  //   androidProvider: AndroidProvider.debug,
  //   appleProvider: AppleProvider.debug,
  // );

  // Le reste de ton code...
  FirebaseAuth.instance.authStateChanges().listen((User? user) {
    if (user == null) {
      print('Utilisateur non connecté');
    } else {
      print('Utilisateur connecté: ${user.uid}');
    }
  });

  await DeviceInfoService.initializeDeviceId();

  // OneSignal ne fonctionne pas toujours bien sur le Web, on l'isole
  if (!kIsWeb) {
    OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
    OneSignal.initialize("b1b8e6b8-b9f4-4c48-b5ac-6ccae1423c98");
    OneSignal.Notifications.requestPermission(true);
  }

  initLocalNotifications();

  // Workmanager n'est PAS supporté sur le Web
  if (!kIsWeb) {
    await Workmanager().initialize(callbackDispatcher);
    Workmanager().registerPeriodicTask(
      afrolookTask,
      afrolookTask,
      frequency: const Duration(hours: 5),
      initialDelay: const Duration(seconds: 10),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
  }

  // FlutterDownloader n'est PAS supporté sur le Web
  if (!kIsWeb) {
    await FlutterDownloader.initialize(
      debug: !kReleaseMode,
      ignoreSsl: !kReleaseMode,
    );
  }

  runApp(const MyApp());
}
// Future<void> main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   _cameras = await availableCameras();
//
//   await Firebase.initializeApp(
//     options: DefaultFirebaseOptions.currentPlatform,
//   );
//
//   // Activate app check after initialization, but before
//   // usage of any Firebase services.
//   await FirebaseAppCheck.instance.activate(
//     androidProvider: AndroidProvider.debug,
//     appleProvider: AppleProvider.debug,
//   );
//
//   // Vérifier l'état d'authentification au démarrage
//   FirebaseAuth.instance.authStateChanges().listen((User? user) {
//     if (user == null) {
//       print('Utilisateur non connecté');
//     } else {
//       print('Utilisateur connecté: ${user.uid}');
//     }
//   });
//   // Initialiser l'ID d'appareil au démarrage
//   await DeviceInfoService.initializeDeviceId();
//   //Remove this method to stop OneSignal Debugging
//   OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
//   OneSignal.initialize("b1b8e6b8-b9f4-4c48-b5ac-6ccae1423c98");
//   OneSignal.Notifications.requestPermission(true);
//   initLocalNotifications();
//   await Workmanager().initialize(
//     callbackDispatcher,
//   );
//
//   // processNotificationTask("challengeCheckTask", firstLaunch: true);
//    sendTestAfrolookNotification();
//    // initializeCanalFields();
//   //
//   // Workmanager().registerOneOffTask(
//   //   afrolookTestTask,
//   //   afrolookTestTask,
//   //   initialDelay: Duration(seconds: 2),
//   // );
//   Workmanager().registerPeriodicTask(
//     afrolookTask,
//     afrolookTask,
//     frequency: const Duration(hours: 5),
//     // frequency: const Duration(minutes: 15),
//     initialDelay: const Duration(seconds: 10),
//     existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
//   );
//
//   if (kReleaseMode) {
//     await FlutterDownloader.initialize(
//       debug: false,
//       ignoreSsl: false,
//     );      } else {
//     await FlutterDownloader.initialize(
//       debug: true,
//       ignoreSsl: true,
//     );      }
//   runApp(const MyApp());
// }

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final AppLinkService _appLinkService = AppLinkService();
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<Uri>? _linkSubscription;

  Future<List<Post>> getPostsVideosById(String post_id) async {
    List<Post> posts = [];
    CollectionReference postCollect = await FirebaseFirestore.instance.collection('Posts');
    QuerySnapshot querySnapshotPost = await postCollect
        .where("id", isEqualTo: '${post_id}')
        .get();

    List<Post> postList = querySnapshotPost.docs.map((doc) =>
        Post.fromJson(doc.data() as Map<String, dynamic>)).toList();

    return postList;
  }
  FirebaseDynamicLinks dynamicLinks = FirebaseDynamicLinks.instance;
  Future<List<Post>> getPostsImagesById(String post_id) async {
    List<Post> posts = [];
    CollectionReference postCollect = await FirebaseFirestore.instance.collection('Posts');
    QuerySnapshot querySnapshotPost = await postCollect
        .where("id", isEqualTo: '${post_id}')
        .get();

    List<Post> postList = querySnapshotPost.docs.map((doc) =>
        Post.fromJson(doc.data() as Map<String, dynamic>)).toList();

    return postList;
  }

  void onClickNotification() {
    try {
      OneSignal.Notifications.addClickListener((event) async {
        print("notif additionalData: ${event.notification.additionalData}");

        if (event.notification.additionalData!['type_notif'] == NotificationType.MESSAGE.name) {
          Chat usersChat = Chat();
          List<Chat> listChats = [];

          CollectionReference chatCollect = await FirebaseFirestore.instance.collection('Chats');
          QuerySnapshot querySnapshotChat = await chatCollect.where("id", isEqualTo: event.notification.additionalData!['chat_id']).get();
          List<Chat> chats = querySnapshotChat.docs.map((doc) =>
              Chat.fromJson(doc.data() as Map<String, dynamic>)).toList();

          CollectionReference friendCollect = await FirebaseFirestore.instance.collection('Users');
          QuerySnapshot querySnapshotUser = await friendCollect.where("id", isEqualTo: event.notification.additionalData!["send_user_id"]).get();
          List<UserData> userList = querySnapshotUser.docs.map((doc) =>
              UserData.fromJson(doc.data() as Map<String, dynamic>)).toList();

          if (chats.isNotEmpty) {
            usersChat = chats.first;
            if (userList.isNotEmpty) {
              usersChat.chatFriend = userList.first;
              usersChat.receiver = userList.first;
            }

            CollectionReference messageCollect = await FirebaseFirestore.instance.collection('Messages');
            QuerySnapshot querySnapshotMessage = await messageCollect.where("chat_id", isEqualTo: event.notification.additionalData!['chat_id']).get();
            List<Message> messages = querySnapshotMessage.docs.map((doc) =>
                Message.fromJson(doc.data() as Map<String, dynamic>)).toList();
            usersChat.messages = messages;

            navigatorKey.currentState!.push(MaterialPageRoute(builder: (context) => MyChat(title: 'mon chat', chat: usersChat,),));
          }
        }
        else if (event.notification.additionalData!['type_notif'] == NotificationType.INVITATION.name) {
          navigatorKey.currentState!.push(MaterialPageRoute(builder: (context) => MesInvitationsPage(context: context),));
        }
        else if (event.notification.additionalData!['type_notif'] == NotificationType.ARTICLE.name) {
          navigatorKey.currentState!.push(MaterialPageRoute(builder: (context) => MesNotification(),));
        }
        else if (event.notification.additionalData!['type_notif'] == NotificationType.ACCEPTINVITATION.name) {
          navigatorKey.currentState!.push(MaterialPageRoute(builder: (context) => Amis(),));
        }
        else if (event.notification.additionalData!['type_notif'] == NotificationType.POST.name) {
          await getPostsImagesById(event.notification.additionalData!['post_id']!).then((posts) {
            if (posts.isNotEmpty) {
              if(posts.first.dataType == PostDataType.VIDEO.name){
                navigatorKey.currentState!.push(MaterialPageRoute(builder: (context) => VideoTikTokPageDetails(initialPost: posts.first),));
              }else{
                navigatorKey.currentState!.push(MaterialPageRoute(builder: (context) => DetailsPost(post: posts.first),));
              }
            }
          },);
          // switch (event.notification.additionalData!['post_type']) {
          //   case "IMAGE":
          //     await getPostsImagesById(event.notification.additionalData!['post_id']!).then((posts) {
          //       if (posts.isNotEmpty) {
          //         if(posts.first.dataType ==PostDataType.VIDEO.name){
          //           navigatorKey.currentState!.push(MaterialPageRoute(builder: (context) => VideoTikTokPageDetails(initialPost: posts.first),));
          //         }else{
          //           navigatorKey.currentState!.push(MaterialPageRoute(builder: (context) => DetailsPost(post: posts.first),));
          //         }
          //       }
          //     },);
          //     break;
          //   case 'COMMENT':
          //     getPostsImagesById(event.notification.additionalData!['post_id']!).then((posts) {
          //       if (posts.isNotEmpty) {
          //         navigatorKey.currentState!.push(MaterialPageRoute(builder: (context) => PostComments(post: posts.first),));
          //       }
          //     },);
          //     break;
          //   default:
          //     await getPostsImagesById(event.notification.additionalData!['post_id']!).then((posts) {
          //       if (posts.isNotEmpty) {
          //         if(posts.first.dataType ==PostDataType.VIDEO.name){
          //           navigatorKey.currentState!.push(MaterialPageRoute(builder: (context) => VideoTikTokPageDetails(initialPost: posts.first),));
          //         }else{
          //           navigatorKey.currentState!.push(MaterialPageRoute(builder: (context) => DetailsPost(post: posts.first),));
          //         }
          //       }
          //     },);
          //     break;
          // }
        }
        else if (event.notification.additionalData!['type_notif'] == NotificationType.PARRAINAGE.name) {
          Navigator.push(context, MaterialPageRoute(builder: (context) => MonetisationPage(),));
        }
        else {
          navigatorKey.currentState!.pushNamed('/home');
          navigatorKey.currentState!.push(MaterialPageRoute(builder: (context) => MesNotification(),));
        }
      });
    } catch (e) {
      printVm("erreur notification:  $e");
      navigatorKey.currentState!.pushNamed('/home');
      navigatorKey.currentState!.push(MaterialPageRoute(builder: (context) => MesInvitationsPage(context: context),));
    }
  }

  Future<void> initDeepLinks() async {
    _linkSubscription = AppLinks().uriLinkStream.listen((Uri? uri) {
      if (uri != null) {
        final segments = uri.pathSegments;
        if (segments.length >= 3 && segments[0] == 'share') {
          final typeStr = segments[1];
          final id = segments[2];
          print("Type1: $typeStr");
          print("ID: $id");
          _appLinkService.handleNavigation(navigatorKey.currentContext!, id, typeStr);
        }
      }
    }, onError: (err) {
      print("Erreur de lien: $err");
    });
  }
  final DynamicLinkService _dynamicLinkService = DynamicLinkService();
  @override
  void initState() {
    super.initState();
    onClickNotification();
    // CryptoInitializer.initializeCryptos();
    // Initialiser les deep links
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // MigrationAncienPostService.migrateOldPostsToCountrySystem();
      // MigrationAncienPostService.migrateOldPostsSimple();
      initDeepLinks();

    });
  }

  @override
  void dispose() {
    _appLinkService.dispose();
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
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
        // ChangeNotifierProvider(create: (_) => ChallengeProvider()),
        ChangeNotifierProxyProvider<UserAuthProvider, ContentProvider>(
          create: (context) => ContentProvider(authProvider: context.read<UserAuthProvider>()),
          update: (context, authProvider, previous) => ContentProvider(authProvider: authProvider),

        ),

        ChangeNotifierProvider(
          create: (context) => RecentPostsProvider(),
          child: HomeConstPostPage(type: TabBarType.LOOKS.name,),
        )
      ],
      child: MaterialApp(
          navigatorKey: navigatorKey,
          title: 'Afrolook',
          debugShowCheckedModeBanner: false,
          theme: ThemeData.light().copyWith(
            textTheme: ThemeData.light().textTheme.apply(
              fontFamily: 'Nunito',
            ),
            primaryTextTheme: ThemeData.dark().textTheme.apply(
              fontFamily: 'Nunito',
            ),
          ),
          // DIRECTEMENT vers SplahsChargement optimisé - plus besoin de gestion d'état complexe
          home: const SplahsChargement(postId: '', postType: ''),
          onGenerateRoute: (settings) {
            switch (settings.name) {
              case '/home':
                return PageTransition(child: MyHomePage(title: ""), type: PageTransitionType.fade);
              case '/videos':
                // return PageTransition(child: VideoTikTokPage(), type: PageTransitionType.fade);
                return PageTransition(child: AfroVideoThreads(), type: PageTransitionType.fade);
              case '/home_profile_user':
                return PageTransition(child: UserProfil(), type: PageTransitionType.fade);
              case '/profile_entreprise':
                return PageTransition(child: EntrepriseProfil(), type: PageTransitionType.fade);
              case '/new_entreprise':
                return PageTransition(child: NewEntreprise(), type: PageTransitionType.fade);
              case '/list_users_chat':
                return PageTransition(child: ListUserChatsOptimized(), type: PageTransitionType.fade);
              case '/bon_a_savoir':
                return PageTransition(child: BonASavoir(), type: PageTransitionType.fade);
              case '/introduction':
                return PageTransition(child: IntroductionPage(), type: PageTransitionType.fade);
              case '/basic_chat':
                return PageTransition(child: const WelcomeScreen(), type: PageTransitionType.fade);
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
              case '/stories_form':
                return PageTransition(child: StoriesForm(), type: PageTransitionType.fade);
              case '/add_produit':
                return PageTransition(child: AddProduit(), type: PageTransitionType.fade);
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
              case '/list_conversation_entreprise_user':
                return PageTransition(child: ListUsersEntrepriseChats(), type: PageTransitionType.fade);
              case '/list_conversation_user_entreprise':
                return PageTransition(child: ListEntrepriseUserChats(), type: PageTransitionType.fade);
              case '/profil_detail_user2':
                return PageTransition(child: UserProfileDetails(), type: PageTransitionType.fade);
              case '/profil_detail_user':
                return PageTransition(child: ProfilePage(), type: PageTransitionType.fade);
              case '/classemnent':
                return PageTransition(child: UserClassement(), type: PageTransitionType.fade);
              case '/splahs_chargement2':
                return PageTransition(child: SplashVideo(), type: PageTransitionType.fade);
              case '/splahs_chargement':
                return PageTransition(
                    child: const SplahsChargement(postId: '', postType: ''),
                    type: PageTransitionType.fade
                );
              case '/chargement':
                return PageTransition(child: Chargement(), type: PageTransitionType.fade);
              case '/login':
                return PageTransition(child: LoginPageUser(), type: PageTransitionType.fade);
              default:
                return PageTransition(
                    child: const SplahsChargement(postId: '', postType: ''),
                    type: PageTransitionType.fade
                );
            }
          }
      ),
    );
  }
}
