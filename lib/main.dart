import 'package:afrotok/pages/admin/annonce.dart';
import 'package:afrotok/pages/auth/authTest/Screens/Login/loginPage.dart';
import 'package:afrotok/pages/auth/authTest/Screens/Login/loginPageUser.dart';
import 'package:afrotok/pages/auth/authTest/Screens/Login/login_screen.dart';
import 'package:afrotok/pages/auth/authTest/Screens/Welcome/welcome_screen.dart';
import 'package:afrotok/pages/auth/authTest/Screens/login.dart';
import 'package:afrotok/pages/bonASavoir.dart';
import 'package:afrotok/pages/chargement.dart';
import 'package:afrotok/pages/classements/userClassement.dart';
import 'package:afrotok/pages/contact.dart';
import 'package:afrotok/pages/entreprise/conversation/entrepriseConversation.dart';
import 'package:afrotok/pages/entreprise/conversation/listConversationUser.dart';
import 'package:afrotok/pages/entreprise/produit/ajouterProduit.dart';
import 'package:afrotok/pages/entreprise/produit/ajouterUnPub.dart';
import 'package:afrotok/pages/entreprise/profile/ProfileEntreprise.dart';
import 'package:afrotok/pages/entreprise/profile/newEntreprise.dart';
import 'package:afrotok/pages/home/home.dart';
import 'package:afrotok/pages/ia/compagnon/iaCompagnon.dart';
import 'package:afrotok/pages/ia/compagnon/introIaCompagnon.dart';
import 'package:afrotok/pages/info.dart';
import 'package:afrotok/pages/infoGagnePoint.dart';
import 'package:afrotok/pages/intro/introduction.dart';
import 'package:afrotok/pages/mes_notifications.dart';
import 'package:afrotok/pages/socialVideos/main_screen/main_screen.dart';
import 'package:afrotok/pages/splashChargement.dart';

import 'package:afrotok/pages/story/storieForm.dart';
import 'package:afrotok/pages/user/amis/addListAmis.dart';
import 'package:afrotok/pages/user/amis/ami.dart';
import 'package:afrotok/pages/user/conversation/listEntrepriseConv.dart';
import 'package:afrotok/pages/user/conversation/listUserConv.dart';
import 'package:afrotok/pages/user/profile/profile.dart';
import 'package:afrotok/pages/user/profile/profileDetail/page/profile_page.dart';
import 'package:afrotok/pages/user/profile/userProfileDetails.dart';
import 'package:afrotok/pages/userPosts/userPostForm.dart';
import 'package:afrotok/providers/afroshop/authAfroshopProvider.dart';
import 'package:afrotok/providers/afroshop/categorie_produits_provider.dart';
import 'package:afrotok/providers/authProvider.dart';
import 'package:afrotok/providers/postProvider.dart';
import 'package:afrotok/providers/userProvider.dart';
import 'package:afrotok/services/notification_service.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:page_transition/page_transition.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';



Future<void> main() async {
  //WidgetsFlutterBinding.ensureInitialized();
  //await TikTokSDK.instance.setup(clientKey: 'aw95aeb86u1rqdhj');
  WidgetsFlutterBinding.ensureInitialized();

    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

  //Remove this method to stop OneSignal Debugging
  OneSignal.Debug.setLogLevel(OSLogLevel.verbose);

  OneSignal.initialize("b1b8e6b8-b9f4-4c48-b5ac-6ccae1423c98");

// The promptForPushNotificationsWithUserResponse function will show the iOS or Android push notification prompt. We recommend removing the following code and instead using an In-App Message to prompt for notification permission
  OneSignal.Notifications.requestPermission(true);
 // NotificationService().initNotification();




  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});


  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return  MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => UserShopAuthProvider()),
        ChangeNotifierProvider(create: (context) => CategorieProduitProvider()),
        ChangeNotifierProvider(create: (context) => UserAuthProvider()),
        ChangeNotifierProvider(create: (context) => UserProvider()),
        ChangeNotifierProvider(create: (context) => PostProvider()),



      ],

      child: MaterialApp(
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

      initialRoute: '/splahs_chargement',
      //initialRoute: '/introduction',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/home':
            return PageTransition(
                child: MyHomePage(title: ""), type: PageTransitionType.fade);
            break;
          case '/ia_compagnon':
            return PageTransition(
                child: IaCompagnon(), type: PageTransitionType.fade);
            break;
          case '/intro_ia_compagnon':
            return PageTransition(
                child: IntroIaCompagnon(), type: PageTransitionType.fade);
            break;
          case '/videos':
            return PageTransition(
                child: MainScreen(), type: PageTransitionType.fade);
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
                child: SplahsChargement(), type: PageTransitionType.fade);
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


