import 'dart:convert';
import 'dart:developer';

import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/pages/admin/annonce.dart';
import 'package:afrotok/pages/auth/authTest/Screens/Login/loginPage.dart';
import 'package:afrotok/pages/auth/authTest/Screens/Login/loginPageUser.dart';
import 'package:afrotok/pages/auth/authTest/Screens/Login/login_screen.dart';
import 'package:afrotok/pages/auth/authTest/Screens/Welcome/welcome_screen.dart';
import 'package:afrotok/pages/auth/authTest/Screens/login.dart';
import 'package:afrotok/pages/bonASavoir.dart';
import 'package:afrotok/pages/chargement.dart';
import 'package:afrotok/pages/chat/myChat.dart';
import 'package:afrotok/pages/classements/userClassement.dart';
import 'package:afrotok/pages/component/consoleWidget.dart';
import 'package:afrotok/pages/contact.dart';
import 'package:afrotok/pages/entreprise/conversation/entrepriseConversation.dart';
import 'package:afrotok/pages/entreprise/conversation/listConversationUser.dart';
import 'package:afrotok/pages/entreprise/produit/ajouterProduit.dart';
import 'package:afrotok/pages/entreprise/produit/ajouterUnPub.dart';
import 'package:afrotok/pages/entreprise/profile/ProfileEntreprise.dart';
import 'package:afrotok/pages/entreprise/profile/newEntreprise.dart';
import 'package:afrotok/pages/home/home.dart';
import 'package:afrotok/pages/home/postView.dart';
import 'package:afrotok/pages/ia/compagnon/iaCompagnon.dart';
import 'package:afrotok/pages/ia/compagnon/introIaCompagnon.dart';
import 'package:afrotok/pages/info.dart';
import 'package:afrotok/pages/infoGagnePoint.dart';
import 'package:afrotok/pages/intro/introduction.dart';
import 'package:afrotok/pages/mes_notifications.dart';
import 'package:afrotok/pages/postComments.dart';
import 'package:afrotok/pages/postDetails.dart';
import 'package:afrotok/pages/socialVideos/afrovideos/afrovideo.dart';
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
import 'package:afrotok/pages/user/retrait.dart';
import 'package:afrotok/pages/userPosts/postPhotoEditor.dart';
import 'package:afrotok/pages/userPosts/userPostForm.dart';
import 'package:afrotok/providers/afroshop/authAfroshopProvider.dart';
import 'package:afrotok/providers/afroshop/categorie_produits_provider.dart';
import 'package:afrotok/providers/authProvider.dart';
import 'package:afrotok/providers/postProvider.dart';
import 'package:afrotok/providers/userProvider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:deeplynks/deeplynks.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:page_transition/page_transition.dart';
import 'package:provider/provider.dart';
import 'package:upgrader/upgrader.dart';

import 'firebase_options.dart';
import 'models/chatmodels/message.dart';
late List<CameraDescription> _cameras;



Future<void> main() async {
  //WidgetsFlutterBinding.ensureInitialized();
  //await TikTokSDK.instance.setup(clientKey: 'aw95aeb86u1rqdhj');
  WidgetsFlutterBinding.ensureInitialized();
  _cameras = await availableCameras();


  await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  // Activate app check after initialization, but before
  // usage of any Firebase services.
  await FirebaseAppCheck.instance
  // Your personal reCaptcha public key goes here:
      .activate(
    androidProvider: AndroidProvider.debug,
    appleProvider: AppleProvider.debug,
    // webProvider: ReCaptchaV3Provider(kWebRecaptchaSiteKey),
  );

  //Remove this method to stop OneSignal Debugging
  OneSignal.Debug.setLogLevel(OSLogLevel.verbose);

  OneSignal.initialize("b1b8e6b8-b9f4-4c48-b5ac-6ccae1423c98");

// The promptForPushNotificationsWithUserResponse function will show the iOS or Android push notification prompt. We recommend removing the following code and instead using an In-App Message to prompt for notification permission
  OneSignal.Notifications.requestPermission(true);
  String _debugLabelString = "";
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/*
  OneSignal.Notifications.addClickListener((event) {
   // print('NOTIFICATION CLICK LISTENER CALLED WITH EVENT: $event');
    _debugLabelString =
    "=======Clicked notification: \n${event.notification.jsonRepresentation().replaceAll("\\n", "\n")}";
    navigatorKey.currentState!.pushNamed('/mes_notifications'); // Assuming your route name is '/specific_page'

    //print("${_debugLabelString}");
    print("data: ${event.notification.jsonRepresentation()}");

    /*
    this.setState(() {
      _debugLabelString =
      "Clicked notification: \n${event.notification.jsonRepresentation().replaceAll("\\n", "\n")}";
    });

     */
  });

 */

 // NotificationService().initNotification();






  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // This widget is the root of your application.
  String _debugLabelString = "";
  final _deeplynks = Deeplynks();

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  Future<List<Post>> getPostsVideosById(String post_id) async {

    List<Post> posts = [];
    //  UserData userData=UserData();

    CollectionReference postCollect = await FirebaseFirestore.instance.collection('Posts');
    QuerySnapshot querySnapshotPost = await postCollect
    // .where("status",isNotEqualTo:'${PostStatus.SIGNALER.name}')
        .where("id",isEqualTo:'${post_id}')
    // .orderBy('created_at', descending: true)
        .get();

    List<Post> postList = querySnapshotPost.docs.map((doc) =>
        Post.fromJson(doc.data() as Map<String, dynamic>)).toList();
    //  UserData userData=UserData();


    for (Post p in postList) {
      //  print("post : ${jsonDecode(post.toString())}");



      //get user
      CollectionReference friendCollect = await FirebaseFirestore.instance.collection('Users');
      QuerySnapshot querySnapshotUser = await friendCollect.where("id",isEqualTo:'${p.user_id}').get();

      List<UserData> userList = querySnapshotUser.docs.map((doc) =>
          UserData.fromJson(doc.data() as Map<String, dynamic>)).toList();

//get entreprise
      if (p.type==PostType.PUB.name) {
        CollectionReference entrepriseCollect = await FirebaseFirestore.instance.collection('Entreprises');
        QuerySnapshot querySnapshotEntreprise = await entrepriseCollect.where("id",isEqualTo:'${p.entreprise_id}').get();

        List<EntrepriseData> entrepriseList = querySnapshotEntreprise.docs.map((doc) =>
            EntrepriseData.fromJson(doc.data() as Map<String, dynamic>)).toList();
        p.entrepriseData=entrepriseList.first;
      }


      p.user=userList.first;

      if (p.status==PostStatus.NONVALIDE.name) {
        // posts.add(p);
      }else if (p.status==PostStatus.SUPPRIMER.name) {
        // posts.add(p);
      }   else{
        posts.add(p);
      }


    }

    posts.shuffle();
    //posts.shuffle();


    return posts;

  }
  Future<List<Post>>
  getPostsImagesById(String post_id) async {


    List<Post> posts = [];

    CollectionReference postCollect = await FirebaseFirestore.instance.collection('Posts');
    QuerySnapshot querySnapshotPost = await postCollect

        .where("id",isEqualTo:'${post_id}')


        .get();

    List<Post> postList = querySnapshotPost.docs.map((doc) =>
        Post.fromJson(doc.data() as Map<String, dynamic>)).toList();
    //  UserData userData=UserData();


    for (Post p in postList) {
      //  print("post : ${jsonDecode(post.toString())}");



      //get user
      CollectionReference friendCollect = await FirebaseFirestore.instance.collection('Users');
      QuerySnapshot querySnapshotUser = await friendCollect.where("id",isEqualTo:'${p.user_id}').get();

      List<UserData> userList = querySnapshotUser.docs.map((doc) =>
          UserData.fromJson(doc.data() as Map<String, dynamic>)).toList();

//get entreprise
      if (p.type==PostType.PUB.name) {
        CollectionReference entrepriseCollect = await FirebaseFirestore.instance.collection('Entreprises');
        QuerySnapshot querySnapshotEntreprise = await entrepriseCollect.where("id",isEqualTo:'${p.entreprise_id}').get();

        List<EntrepriseData> entrepriseList = querySnapshotEntreprise.docs.map((doc) =>
            EntrepriseData.fromJson(doc.data() as Map<String, dynamic>)).toList();
        p.entrepriseData=entrepriseList.first;
      }


      p.user=userList.first;
      if (p.status==PostStatus.NONVALIDE.name) {
        // posts.add(p);
      }else if (p.status==PostStatus.SUPPRIMER.name) {
        // posts.add(p);
      }   else{
        posts.add(p);
      }




    }

    return posts;

  }

  onClickNotification(){
    try{
      OneSignal.Notifications.addClickListener((event) async {
        // print('NOTIFICATION CLICK LISTENER CALLED WITH EVENT: $event');
        // print("data: ${jsonDecode(event.notification.jsonRepresentation().replaceAll("\\n", "\n"))}");
        // print("data: ${jsonEncode(event.notification.additionalData)}");
        print("data: ${event.notification.additionalData}");

        if (event.notification.additionalData!['type_notif']==NotificationType.MESSAGE.name) {


          Chat usersChat=Chat();
          List<Chat> listChats = [];

          CollectionReference chatCollect = await FirebaseFirestore.instance.collection('Chats');
          QuerySnapshot querySnapshotChat = await chatCollect.where("id",isEqualTo:event.notification.additionalData!['chat_id']).get();
          List<Chat> chats = querySnapshotChat.docs.map((doc) =>
              Chat.fromJson(doc.data() as Map<String, dynamic>)).toList();
          //print("chats:  /////////////////////  ${chats.first.toJson()}");
          //  navigatorKey.currentState!.pushNamed('/mes_notifications');

          CollectionReference friendCollect = await FirebaseFirestore.instance.collection('Users');
          QuerySnapshot querySnapshotUser = await friendCollect.where("id",isEqualTo:event.notification.additionalData!["send_user_id"]).get();
          // Afficher la liste
          List<UserData> userList = querySnapshotUser.docs.map((doc) =>
              UserData.fromJson(doc.data() as Map<String, dynamic>)).toList();
          if (chats.isNotEmpty) {
            usersChat=chats.first;


            if (userList.isNotEmpty) {
              // usersChat=Chat.fromJson(chatDoc.data());
              usersChat.chatFriend=userList.first;
              usersChat.receiver=userList.first;

              // listChats.add(usersChat);
            }

            CollectionReference messageCollect = await FirebaseFirestore.instance.collection('Messages');
            QuerySnapshot querySnapshotMessage = await messageCollect.where("chat_id",isEqualTo:event.notification.additionalData!['chat_id']).get();
            // Afficher la liste
            List<Message> messages = querySnapshotMessage.docs.map((doc) =>
                Message.fromJson(doc.data() as Map<String, dynamic>)).toList();
            //snapshot.data![index].messages=messages;
            usersChat.messages=messages;
            navigatorKey.currentState!.pushNamed('/home'); // Assuming your route name is '/specific_page'

            navigatorKey.currentState!.push(MaterialPageRoute(builder: (context) => MyChat(title: 'mon chat', chat: usersChat,),));

          }


        }
        else if (event.notification.additionalData!['type_notif']==NotificationType.INVITATION.name) {
          navigatorKey.currentState!.pushNamed('/home'); // Assuming your route name is '/specific_page'

          navigatorKey.currentState!.push(MaterialPageRoute(builder: (context) => MesInvitationsPage(context: context),)); // Assuming your route name is '/specific_page'


        }
        else if (event.notification.additionalData!['type_notif']==NotificationType.ARTICLE.name) {
          navigatorKey.currentState!.pushNamed('/home'); // Assuming your route name is '/specific_page'

          navigatorKey.currentState!.push(MaterialPageRoute(builder: (context) => MesNotification(),)); // Assuming your route name is '/specific_page'


        }

        else if (event.notification.additionalData!['type_notif']==NotificationType.ACCEPTINVITATION.name) {
          navigatorKey.currentState!.pushNamed('/home'); // Assuming your route name is '/specific_page'

          navigatorKey.currentState!.push(MaterialPageRoute(builder: (context) => Amis(),)); // Assuming your route name is '/specific_page'


        }
        else if (event.notification.additionalData!['type_notif'] == NotificationType.POST.name) {


          switch (event.notification.additionalData!['post_type']) {
            case "VIDEO":
              await getPostsVideosById(event.notification.additionalData!['post_id']!).then((videos_posts) {
                if(videos_posts.isNotEmpty){

                  navigatorKey.currentState!.push(MaterialPageRoute(builder: (context) => OnlyPostVideo(videos: videos_posts,),));

                }
              },);

              break;
            case "IMAGE":
              await getPostsImagesById(event.notification.additionalData!['post_id']!).then((posts) {
                if(posts.isNotEmpty){

                  navigatorKey.currentState!.push(MaterialPageRoute(builder: (context) => DetailsPost(post: posts.first),));

                }

              },);
              break;
            case 'COMMENT':
              getPostsImagesById(event.notification.additionalData!['post_id']!).then((posts) {
                if(posts.isNotEmpty){

                  navigatorKey.currentState!.push(MaterialPageRoute(builder: (context) => PostComments(post:  posts.first),));

                }

              },);
              break;
            default:
            // Handle unknown post type
              navigatorKey.currentState!.pushNamed('/home'); // Assuming your route name is '/specific_page'

              navigatorKey.currentState!.push(MaterialPageRoute(builder: (context) => MesNotification(),)); // Assuming your route name is '/specific_page'

              break;
          }
        }
        else if (event.notification.additionalData!['type_notif'] == NotificationType.PARRAINAGE.name) {

          Navigator.push(context, MaterialPageRoute(builder: (context) => RetraitPage(),));

        }
        else {
          navigatorKey.currentState!.pushNamed('/home'); // Assuming your route name is '/specific_page'

          navigatorKey.currentState!.push(MaterialPageRoute(builder: (context) => MesNotification(),)); // Assuming your route name is '/specific_page'

        }


        /*
      setState(() {
        Navigator.push(context, MaterialPageRoute(builder: (context) => MesNotification(),));

      });

       */
        _debugLabelString =
        "=====Clicked notification: \n${event.notification.jsonRepresentation().replaceAll("\\n", "\n")}";
/*
      authProvider.getToken().then((token) async {
        print("token: ${token}");

        if (token==null||token=='') {
          print("token: existe pas");
          Navigator.pushNamed(context, '/welcome');




        }else{
          print("token: existe");
          //Navigator.pushNamed(context, '/welcome');
          navigatorKey.currentState!.pushNamed('/mes_notifications'); // Assuming your route name is '/specific_page'

        }
      },);

 */

      });

    }catch(e){
      printVm("erreur notification:  $e");
      navigatorKey.currentState!.pushNamed('/home'); // Assuming your route name is '/specific_page'

      navigatorKey.currentState!.push(MaterialPageRoute(builder: (context) => MesInvitationsPage(context: context),)); // Assuming your route name is '/specific_page'

    }

  }

  /// Initialize deeplynks & listen for link data
  Future<void> _init() async {
    final appId = await _deeplynks.init(
      context: context,
      metaData: MetaInfo(
        name: 'Afrolook',
        description:
        'Afrolook votre popularité à la une',
      ),
      androidInfo: AndroidInfo(
        sha256: ['FD:0F:AD:CF:15:14:B1:F6:E7:F9:92:7F:CB:72:18:A1:58:56:0B:6C:20:EC:D8:3D:50:F0:61:DE:38:52:EB:8B'],
        playStoreURL: 'https://play.google.com/store/apps/details?id=com.afrotok.afrotok',
        applicationId: 'com.afrotok.afrotok',
        // applicationId: 'com.example.deeplynks',
      ),
      // iosInfo: IOSInfo(
      //   teamId: '',
      //   appStoreURL: '',
      //   bundleId: 'com.example.deeplynks',
      // ),
    );

    // Use this appId for Android platform setup
    printVm('*************Deeplynks App Id:**********************');
    printVm('Deeplynks App Id: $appId');
    log('Deeplynks App Id: $appId');

    // Listen for link data
    _deeplynks.stream.listen((data) {
      // Handle link data
      printVm('*******************Deeplynks Data:*********************');
      printVm('Deeplynks Data: $data');
      log('Deeplynks Data: $data');
      // Listen for link data
      // Handle link data

      // After using the link data, mark it as completed
      // in case you don't want it again next time
      // _deeplynks.markCompleted();
    });
  }
  String? _linkMessage;
  bool _isCreatingLink = false;

  FirebaseDynamicLinks dynamicLinks = FirebaseDynamicLinks.instance;
  final String _testString =
      'To test: long press link and then copy and click from a non-browser '
      "app. Make sure this isn't being tested on iOS simulator and iOS xcode "
      'is properly setup. Look at firebase_dynamic_links/README.md for more '
      'details.';

  final String DynamicLink = 'https://example/helloworld';
  final String Link = 'https://flutterfiretests.page.link/MEGs';
  /// Create a new deep link

  Future<void> initDynamicLinks() async {
    dynamicLinks.onLink.listen((dynamicLinkData) async {
      // printVm('onLink data: ${jsonEncode(dynamicLinkData}');
      // printVm('onLink path: ${dynamicLinkData.link.path}');
      // printVm('onLink data: ${dynamicLinkData.link.data}');

      // Récupérer l'URL du lien dynamique
      print('onLink path: ${dynamicLinkData.link.path}');
      print('onLink data: ${dynamicLinkData.link.queryParameters}');

      // Extraire les paramètres de l'URL
      // String? userId = dynamicLinkData.link.queryParameters['userId'];
      String? postId = dynamicLinkData.link.queryParameters['postId'];
      String? postType = dynamicLinkData.link.queryParameters['postType'];
      // String? postImage = dynamicLinkData.link.queryParameters['postImage'];

      navigatorKey.currentState!.push(MaterialPageRoute(builder: (context) => SplahsChargement(postId: postId!, postType: postType!,),));



    }).onError((error) {
      printVm('onLink error');
      printVm(error.message);
    });
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    // WidgetsBinding.instance.addPostFrameCallback((_) => _init());
    onClickNotification();
    initDynamicLinks();
  }
  @override
  Widget build(BuildContext context) {
    // _createLink();

    return  MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => UserShopAuthProvider()),
        ChangeNotifierProvider(create: (context) => CategorieProduitProvider()),
        ChangeNotifierProvider(create: (context) => UserAuthProvider()),
        ChangeNotifierProvider(create: (context) => UserProvider()),
        ChangeNotifierProvider(create: (context) => PostProvider()),



      ],

      child: MaterialApp(
          navigatorKey: navigatorKey,
          title: 'Afrotok',
        debugShowCheckedModeBanner: false,
          theme: ThemeData.light().copyWith(
          textTheme: ThemeData.light().textTheme.apply(
            fontFamily: 'Nunito',


          ),
          primaryTextTheme: ThemeData.dark().textTheme.apply(
            fontFamily: 'Nunito',
          ),
          ),
        /*
        theme: ThemeData(
          // This is the theme of your application.

          colorScheme: ColorScheme.fromSeed(seedColor: Colors.white),
          useMaterial3: true,
        ),

         */
// home: UpgradeAlert(
//   upgrader: Upgrader(),
//   child: Scaffold(
//     // body: PickImageExample(),
//     // body: PhotoVideoEditorPage(),
//     // body: UserPostForm(),
//     body: SplahsChargement(),
//   ),
// ),

      initialRoute: '/splahs_chargement',
      //initialRoute: '/introduction',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/home':
            return PageTransition(
                child: MyHomePage(title: ""), type: PageTransitionType.fade);
                // child: PostsPage(), type: PageTransitionType.fade);
            break;
          case '/ia_compagnon':
            return PageTransition(
                child: IaCompagnon(), type: PageTransitionType.fade);
            break;
          case '/intro_ia_compagnon':
            return PageTransition(
                child: IntroIaCompagnon(instruction: '',), type: PageTransitionType.fade);
            break;
          case '/videos':
            return PageTransition(
                // child: MainScreen(), type: PageTransitionType.fade);
                child: AfroVideo(), type: PageTransitionType.fade);
            break;

          case '/home_profile_user':
            return PageTransition(
                child: UserProfil(), type: PageTransitionType.fade);
            break;
          case '/profile_entreprise':
            return PageTransition(
                child: EntrepriseProfil(), type: PageTransitionType.fade);
            break;
          case '/new_entreprise':
            return PageTransition(
                child: NewEntreprise(), type: PageTransitionType.fade);
            break;

          case '/list_users_chat':
            return PageTransition(
                child: ListUserChats(), type: PageTransitionType.fade);
            case '/bon_a_savoir':
            return PageTransition(
                child: BonASavoir(), type: PageTransitionType.fade);
            case '/introduction':
            return PageTransition(
                child: IntroductionPage(), type: PageTransitionType.fade);
            break;


          case '/basic_chat':
            return PageTransition(
                child: WelcomeScreen(), type: PageTransitionType.fade);
            break;
            case '/mes_notifications':
            return PageTransition(
                child: MesNotification(), type: PageTransitionType.fade);
            break;


          case '/user_posts_form':
            return PageTransition(
                child: UserPostForm(), type: PageTransitionType.fade);
            break;
          case '/welcome':
            return PageTransition(
                child: WelcomeScreen(), type: PageTransitionType.fade);
            break;
          case '/amis':
            return PageTransition(
                child: Amis(), type: PageTransitionType.fade);
            break;
          case '/add_list_amis':
            return PageTransition(
                child: AddListAmis(), type: PageTransitionType.fade);
            break;
          case '/stories_form':
            return PageTransition(
                child: StoriesForm(), type: PageTransitionType.fade);
            break;
          case '/add_produit':
            return PageTransition(
                child: AddProduit(), type: PageTransitionType.fade);
            break;
          case '/add_pub':
            return PageTransition(
                child: AddPubForm(), type: PageTransitionType.fade);
            break;
          case '/app_info':
            return PageTransition(
                child: AppInfos(), type: PageTransitionType.fade);
            case '/contact':
            return PageTransition(
                child: ContactPage(), type: PageTransitionType.fade);
            break;
            case '/gagner_point_infos':
            return PageTransition(
                child: GagnerPointInfo(), type: PageTransitionType.fade);
            break;
          case '/new_annonce':
            return PageTransition(
                child: NewAppAnnonce(), type: PageTransitionType.fade);
            break;
          case '/list_conversation_entreprise_user':
            return PageTransition(
                child: ListUsersEntrepriseChats(), type: PageTransitionType.fade);
            break;
          case '/list_conversation_user_entreprise':
            return PageTransition(
                child: ListEntrepriseUserChats(), type: PageTransitionType.fade);
            break;

          case '/profil_detail_user2':
            return PageTransition(
                child: UserProfileDetails(), type: PageTransitionType.fade);
            break;
          case '/profil_detail_user':
            return PageTransition(
                child: ProfilePage(), type: PageTransitionType.fade);
            break;
          case '/classemnent':
            return PageTransition(
                child: UserClassement(), type: PageTransitionType.fade);
            break;
            case '/splahs_chargement':
            return PageTransition(
                child: SplashVideo(), type: PageTransitionType.fade);
            break;
          case '/splahs_chargement2':
            return PageTransition(
                child: SplahsChargement(postId: '', postType: '',), type: PageTransitionType.fade);
            break;
          case '/chargement':
            return PageTransition(
                child: Chargement(), type: PageTransitionType.fade);
            break;
          case '/login':
            return PageTransition(
                child: LoginPageUser(), type: PageTransitionType.fade);
            break;

          default:
            return PageTransition(
                child: LoginPageUser(), type: PageTransitionType.fade);
        }
      }
      ),
    );
  }
}


