import 'dart:async';

import 'package:afrotok/pages/socialVideos/afrovideos/videoWidget.dart';
import 'package:animated_icon/animated_icon.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:intl/intl.dart';
import 'package:like_button/like_button.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:page_transition/page_transition.dart';
import 'package:provider/provider.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../constant/logo.dart';
import '../../../constant/sizeText.dart';
import '../../../constant/textCustom.dart';
import '../../../models/chatmodels/message.dart';
import '../../../models/model_data.dart';
import '../../../providers/afroshop/authAfroshopProvider.dart';
import '../../../providers/afroshop/categorie_produits_provider.dart';
import '../../../providers/authProvider.dart';
import '../../../providers/postProvider.dart';
import '../../../providers/userProvider.dart';
import '../../UserServices/listUserService.dart';
import '../../afroshop/marketPlace/acceuil/home_afroshop.dart';
import '../../afroshop/marketPlace/component.dart';
import '../../afroshop/marketPlace/modalView/ArticleBottomSheet.dart';
import '../../chat/chatXilo.dart';
import '../../chat/entrepriseChat.dart';
import '../../component/consoleWidget.dart';
import '../../postComments.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../user/detailsOtherUser.dart';
import '../../userPosts/postWidgets/postCadeau.dart';
import '../../userPosts/postWidgets/postWidgetPage.dart';
import 'SimpleVideoView.dart';

class AfroVideo extends StatefulWidget {
  const AfroVideo({super.key});

  @override
  State<AfroVideo> createState() => _AfroVideoState();
}

class _AfroVideoState extends State<AfroVideo> with WidgetsBindingObserver, TickerProviderStateMixin {

  bool abonneTap=false;

  String formatAbonnes(int nbAbonnes) {
    if (nbAbonnes >= 1000) {
      double nombre = nbAbonnes / 1000;
      return nombre.toStringAsFixed(1) + 'k';
    } else {
      return nbAbonnes.toString();
    }
  }
  // bool isUserAbonne(List<UserAbonnes> userAbonnesList, String userIdToCheck) {
  //   return userAbonnesList.any((userAbonne) => userAbonne.abonneUserId == userIdToCheck);
  // }

  late UserAuthProvider authProvider =
  Provider.of<UserAuthProvider>(context, listen: false);
  late PostProvider postProvider =
  Provider.of<PostProvider>(context, listen: false);
  late UserProvider userProvider =
  Provider.of<UserProvider>(context, listen: false);

  late UserShopAuthProvider authProviderShop =
  Provider.of<UserShopAuthProvider>(context, listen: false);
  late CategorieProduitProvider categorieProduitProvider =
  Provider.of<CategorieProduitProvider>(context, listen: false);
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  Future<void> launchWhatsApp(String phone) async {
    //  var whatsappURl_android = "whatsapp://send?phone="+whatsapp+"&text=hello";
    // String url = "https://wa.me/?tel:+228$phone&&text=YourTextHere";
    String url = "whatsapp://send?phone="+phone+"";
    if (!await launchUrl(Uri.parse(url))) {
      final snackBar = SnackBar(duration: Duration(seconds: 2),content: Text("Impossible d\'ouvrir WhatsApp",textAlign: TextAlign.center, style: TextStyle(color: Colors.red),));

      // Afficher le SnackBar en bas de la page
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
      throw Exception('Impossible d\'ouvrir WhatsApp');
    }
  }
  bool isLoading = false;

  bool _isLoading = false;
  final List<AnimationController> _heartAnimations = [];
  final List<AnimationController> _giftAnimations = [];

  StreamController<List<Post>> _streamController = StreamController<List<Post>>();

  int limitePosts = 40;

  List<Post> listConstposts=[];

  void _showUserDetailsModalDialog(UserData user, double w, double h) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(

          content: DetailsOtherUser(
            user: user,
            w: w,
            h: h,
          ),
        );
      },
    );
  }


  void _showPostMenuModalDialog(Post post,BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        late UserAuthProvider authProvider =
        Provider.of<UserAuthProvider>(context, listen: false);
        late PostProvider postProvider =
        Provider.of<PostProvider>(context, listen: false);
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
                      // setState(() {});
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
                      Navigator.pop(context);

                      //
                      // setState(() {
                      //   Navigator.pop(context);
                      // });
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


  bool isUserAbonne(List<String> userAbonnesList, String userIdToCheck) {
    return userAbonnesList.any((userAbonneId) => userAbonneId == userIdToCheck);
  }

  bool isIn(List<String> users_id, String userIdToCheck) {
    return users_id.any((item) => item == userIdToCheck);
  }

  Future<Chat> getChatsEntrepriseData(UserData amigo,Post post,EntrepriseData entreprise) async {

    // Définissez la requête
    var friendsStream = FirebaseFirestore.instance.collection('Chats').where( Filter.or(
      Filter('docId', isEqualTo:  '${post.id}${authProvider.loginUserData!.id}'),
      Filter('docId', isEqualTo:  '${authProvider.loginUserData!.id}${post.id}'),

    )).snapshots();

// Obtenez la liste des utilisateurs
    //List<DocumentSnapshot> users = await usersQuery.sget();
    Chat usersChat=Chat();

    if (await friendsStream.isEmpty) {
      printVm("pas de chat ");
      String chatId = FirebaseFirestore.instance
          .collection('Chats')
          .doc()
          .id;
      Chat chat = Chat(
        docId:'${post.id}${authProvider.loginUserData!.id}',
        id: chatId,
        senderId: '${authProvider.loginUserData!.id}',
        receiverId: '${amigo.id}',
        lastMessage: 'hi',
        post_id: post.id,
        entreprise_id: post.entreprise_id,
        type: ChatType.ENTREPRISE.name,
        createdAt: DateTime.now().millisecondsSinceEpoch, // Get current time in milliseconds
        updatedAt: DateTime.now().millisecondsSinceEpoch,
        // Optional: You can initialize sender and receiver with UserData objects, and messages with a list of Message objects
      );
      await FirebaseFirestore.instance.collection('Chats').doc(chatId).set(chat.toJson());
      usersChat=chat;

    }  else{
      printVm("le chat existe  ");
      // printVm("stream :${friendsStream}");
      usersChat= await friendsStream.first.then((value) async {
        // printVm("stream value l :${value.docs.length}");
        if (value.docs.length<=0) {
          printVm("pas de chat ");
          String chatId = FirebaseFirestore.instance
              .collection('Chats')
              .doc()
              .id;
          Chat chat = Chat(
            docId:'${post.id}${authProvider.loginUserData!.id}',
            id: chatId,
            senderId: '${authProvider.loginUserData!.id}',
            receiverId: '${amigo.id}',
            lastMessage: 'hi',
            entreprise_id: post.entreprise_id,
            post_id: post.id,
            type: ChatType.ENTREPRISE.name,
            createdAt: DateTime.now().millisecondsSinceEpoch, // Get current time in milliseconds
            updatedAt: DateTime.now().millisecondsSinceEpoch,
            // Optional: You can initialize sender and receiver with UserData objects, and messages with a list of Message objects
          );
          await FirebaseFirestore.instance.collection('Chats').doc(chatId).set(chat.toJson());
          usersChat=chat;
          return chat;
        }  else{
          return  Chat.fromJson(value.docs.first.data());
        }

      });
      CollectionReference messageCollect = await FirebaseFirestore.instance.collection('Messages');
      QuerySnapshot querySnapshotMessage = await messageCollect.where("chat_id",isEqualTo:usersChat.id!).get();
      // Afficher la liste
      List<Message> messageList = querySnapshotMessage.docs.map((doc) =>
          Message.fromJson(doc.data() as Map<String, dynamic>)).toList();


      if (messageList.isEmpty) {
        usersChat.messages=[];
        userProvider.chat=usersChat;
        printVm("messages vide ");
      }else{
        printVm("have messages");
        usersChat.messages=messageList;
        userProvider.chat=usersChat;
      }

      /////////////ami//////////
      CollectionReference friendCollect = await FirebaseFirestore.instance.collection('Users');
      QuerySnapshot querySnapshotUserSender = await friendCollect.where("id",isEqualTo:authProvider.loginUserData.id==amigo.id!?'${amigo.id}':'${authProvider.loginUserData!.id}').get();
      // Afficher la liste
      QuerySnapshot querySnapshotUserReceiver= await friendCollect.where("id",isEqualTo:authProvider.loginUserData.id==amigo.id?'${authProvider.loginUserData!.id}':'${amigo.id}').get();


      List<UserData> receiverUserList = querySnapshotUserReceiver.docs.map((doc) =>
          UserData.fromJson(doc.data() as Map<String, dynamic>)).toList();
      usersChat.receiver=receiverUserList.first;

      List<UserData> senderUserList = querySnapshotUserSender.docs.map((doc) =>
          UserData.fromJson(doc.data() as Map<String, dynamic>)).toList();
      usersChat.sender=senderUserList.first;

      /////////////entreprise//////////
      CollectionReference entrepriseCollect = await FirebaseFirestore.instance.collection('Entreprises');
      QuerySnapshot querySnapshotentreprise = await entrepriseCollect.where("id",isEqualTo:'${post.entreprise_id}').get();
      List<EntrepriseData> entrepriseList = querySnapshotentreprise.docs.map((doc) =>
          EntrepriseData.fromJson(doc.data() as Map<String, dynamic>)).toList();
      usersChat.entreprise=entrepriseList.first;



    }

    return usersChat;
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

  Future<void> _checkAndShowDialog() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String lastShownDate = prefs.getString('lastShownDateVideo') ?? '';

    String todayDate = DateTime.now().toIso8601String().split('T')[0];
    _showChatXiloDialog();
    if (lastShownDate != todayDate) {
      _showChatXiloDialog();

      // Show the dialog
      Timer(Duration(seconds: 20), () {
        _showServiceDialog();
      });
      // showDialog(
      //   context: context,
      //   builder: (context) => Dialog(
      //     child: ArticleBottomSheet(),
      //   ),
      // );
      // Update the last shown date
      await prefs.setString('lastShownDateVideo', todayDate);
    }
  }

  bool _showHeart = false;
  bool _showGift = false;


  void _sendLike() {
    final controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1000),
    );
    setState(() {
      _heartAnimations.add(controller);
    });
    controller.forward().then((_) {
      setState(() {
        _heartAnimations.remove(controller);
      });
    });
  }
  void _sendReplyGift(String gift) {
    final controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1500),
    );
    setState(() {
      _giftReplyAnimations.add(controller);
    });
    controller.forward().then((_) {
      setState(() {
        _giftReplyAnimations.remove(controller);
      });
    });
  }

  void _sendGift(String gift) {
    final controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1500),
    );
    setState(() {
      _giftAnimations.add(controller);
    });
    controller.forward().then((_) {
      setState(() {
        _giftAnimations.remove(controller);
      });
    });
  }

  final List<AnimationController> _giftReplyAnimations = [];

  final String imageCadeau='https://th.bing.com/th/id/R.07b0fcbd29597e76b66b50f7ba74bc65?rik=vHxQSLwSFG2gAw&riu=http%3a%2f%2fwww.conseilsdefamille.com%2fwp-content%2fuploads%2f2013%2f03%2fCadeau-Fotolia_27171652CMYK_WB.jpg&ehk=vzUbV07%2fUgXnc1LdlIVCaD36qZGAxa7V8JtbqOFfoqY%3d&risl=&pid=ImgRaw&r=0';


  void showRepublishDialog(Post post, UserData userSendCadeau,AppDefaultData appdata ,BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: Colors.white,
          title: Text(
            "✨ Republier ce post",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "🔝 Cette action mettra votre post en première position des actualités du jour.\n\n"
                    "💰 1 PC sera retiré de votre compte principal.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black, fontSize: 16),
              ),
              SizedBox(height: 10),
              Text("⚡ Plus de visibilité, plus d’interactions !", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(backgroundColor: Colors.brown),
              child: Text("❌ Fermer", style: TextStyle(color: Colors.white)),
            ),
            TextButton(
              onPressed: () async {
                try {
                  CollectionReference userCollect = FirebaseFirestore.instance.collection('Users');
                  QuerySnapshot querySnapshotUser = await userCollect.where("id", isEqualTo: userSendCadeau.id!).get();

                  List<UserData> listUsers = querySnapshotUser.docs.map(
                        (doc) => UserData.fromJson(doc.data() as Map<String, dynamic>),
                  ).toList();

                  if (listUsers.isNotEmpty) {
                    userSendCadeau = listUsers.first;
                    printVm("envoyer cadeau");
                    printVm("userSendCadeau.votre_solde_principal : ${userSendCadeau.votre_solde_principal}");
                    userSendCadeau.votre_solde_principal ??= 0.0;
                    appdata.solde_gain ??= 0.0;

                    if (userSendCadeau.votre_solde_principal! >= 2) {
                      post.users_republier_id ??= [];
                      post.users_republier_id?.add(userSendCadeau.id!);
                      double gain=0.0;
                      double deduire=0.0;

//
// // Ajouter le gain au solde cadeau
//                       post.user!.votre_solde_cadeau =
//                           (post.user!.votre_solde_cadeau ?? 0.0) + _selectedPrice;

// Ajouter le reste au solde principal
                      userSendCadeau.votre_solde_principal =
                          userSendCadeau.votre_solde_principal! - 2;
                      appdata.solde_gain=appdata.solde_gain!+2;



                      await  postProvider.updateReplyPost(post, context);
                      await authProvider.updateUser(post!.user!).then((value) async {
                        await  authProvider.updateUser(userSendCadeau);
                        await  authProvider.updateAppData(appdata);

                      },);
                      printVm('update send user');
                      printVm('update send user votre_solde_principal : ${userSendCadeau.votre_solde_principal}');
                      setState(() => _isLoading = false);
                      Navigator.of(context).pop();
                      _sendReplyGift('🔝');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: Colors.green,
                          content: Text(
                            '🔝 Félicitations ! Vous avez reposter ce look ',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      );
                    } else {
                      setState(() => _isLoading = false);
                      showInsufficientBalanceDialog(context);
                    }
                  }
                } catch (e) {
                  setState(() => _isLoading = false);
                  print("Erreur : $e");
                }
              },

              style: TextButton.styleFrom(backgroundColor: Colors.green),
              child: Text("🚀 Republier", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }


  void showGiftDialog(Post post, UserData userSendCadeau,AppDefaultData appdata) {
    showDialog(
      context: context,
      barrierDismissible: false, // Empêche la fermeture
      builder: (BuildContext context) {
        String _selectedGift = '';
        double _selectedPrice = 0.0;

        return StatefulBuilder(
          builder: (context, setState) {
            return Stack(
              children: [
                GiftDialog(
                  isLoading: _isLoading,
                  onGiftSelected: (String gift, int price) async {
                    setState(() {
                      _isLoading = true;
                      _selectedPrice=price.toDouble();
                      _selectedGift=gift;
                    },);

                    try {
                      CollectionReference userCollect = FirebaseFirestore.instance.collection('Users');
                      QuerySnapshot querySnapshotUser = await userCollect.where("id", isEqualTo: userSendCadeau.id!).get();

                      List<UserData> listUsers = querySnapshotUser.docs.map(
                            (doc) => UserData.fromJson(doc.data() as Map<String, dynamic>),
                      ).toList();

                      if (listUsers.isNotEmpty) {
                        userSendCadeau = listUsers.first;
                        printVm("envoyer cadeau");
                        printVm("userSendCadeau.votre_solde_principal : ${userSendCadeau.votre_solde_principal}");
                        printVm("_selectedPrice : ${_selectedPrice}");
                        userSendCadeau.votre_solde_principal ??= 0.0;
                        appdata.solde_gain ??= 0.0;

                        if (userSendCadeau.votre_solde_principal! >= _selectedPrice) {
                          post.users_cadeau_id ??= [];
                          post.users_cadeau_id?.add(userSendCadeau.id!);
                          double gain=0.0;
                          double deduire=0.0;

                          if (_selectedPrice <= 2) {
                            gain = 1;
                            // reste = _selectedPrice - gain;
                          } else {
                            gain = _selectedPrice * 0.25;
                            // reste = _selectedPrice - gain;
                          }
                          deduire=_selectedPrice+gain;

// Ajouter le gain au solde cadeau
                          post.user!.votre_solde_cadeau =
                              (post.user!.votre_solde_cadeau ?? 0.0) + _selectedPrice;

// Ajouter le reste au solde principal
                          userSendCadeau.votre_solde_principal =
                              userSendCadeau.votre_solde_principal! - deduire;
                          appdata.solde_gain=appdata.solde_gain!+gain;

                          // post.user!.votre_solde_cadeau = (post.user!.votre_solde_cadeau ?? 0.0) + _selectedPrice;
                          // userSendCadeau.votre_solde_principal = userSendCadeau.votre_solde_principal! - (_selectedPrice);

                          NotificationData notif = NotificationData(
                            id: firestore.collection('Notifications').doc().id,
                            titre: "Nouveau Cadeau 🎁",
                            media_url: imageCadeau,
                            type: NotificationType.POST.name,
                            description: "Vous avez un cadeau ${_selectedPrice} PC ${_selectedGift}",
                            user_id: post.user!.id,
                            receiver_id: post!.user_id!,
                            post_id: post!.id!,
                            post_data_type: PostDataType.IMAGE.name!,
                            createdAt: DateTime.now().microsecondsSinceEpoch,
                            updatedAt: DateTime.now().microsecondsSinceEpoch,
                            status: PostStatus.VALIDE.name,
                          );

                          await firestore.collection('Notifications').doc(notif.id).set(notif.toJson());
                          await authProvider.sendNotification(
                              userIds: [post!.user!.oneIgnalUserid!],
                              smallImage:
                              // "${authProvider.loginUserData.imageUrl!}",
                              "${imageCadeau}",
                              send_user_id:
                              "",
                              // "${authProvider.loginUserData.id!}",
                              recever_user_id: "${post!.user_id!}",
                              message:
                              // "📢 @${authProvider.loginUserData
                              //     .pseudo!} a aimé votre look",
                              "Vous avez un cadeau ${_selectedPrice} PC ${_selectedGift}",
                              type_notif:
                              NotificationType.POST.name,
                              post_id: "${post!.id!}",
                              post_type: PostDataType.IMAGE.name,
                              chat_id: '');


                          await  postProvider.updateVuePost(post, context);
                          await authProvider.updateUser(post!.user!).then((value) async {
                            await  authProvider.updateUser(userSendCadeau);
                            await  authProvider.updateAppData(appdata);

                          },);
                          printVm('update send user');
                          printVm('update send user votre_solde_principal : ${userSendCadeau.votre_solde_principal}');
                          setState(() => _isLoading = false);
                          Navigator.of(context).pop();

                          _sendGift("🎁");
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: Colors.green,
                              content: Text(
                                '🎁 Félicitations ! Vous avez envoyé un cadeau ${_selectedGift} à @${post!.user!.pseudo}.',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          );
                        } else {
                          setState(() => _isLoading = false);
                          showInsufficientBalanceDialog(context);
                        }
                      }
                    } catch (e) {
                      setState(() => _isLoading = false);
                      print("Erreur : $e");
                    }
                  },
                ),
                if (_isLoading)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black54,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }



  @override
  void initState() {
    // TODO: implement initState
    hasShownDialogToday().then(
          (value) async {
            _checkAndShowDialog();
      },
    );
    postProvider.getPostsVideos(limitePosts).listen((data) {
      _streamController.add(data);
    });
    super.initState();
  }

  @override
  void dispose() {
    // TODO: implement dispose
    _streamController.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double h = MediaQuery.of(context).size.height;
    double w = MediaQuery.of(context).size.width;
    return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          iconTheme: IconThemeData(color: Colors.green),
          backgroundColor: Colors.transparent,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Logo(),
            )
          ],
        ),
        body: RefreshIndicator(
          onRefresh: ()async {
            listConstposts.clear();
          // await  postProvider.getPostsImages2(limitePosts).listen((data) {
          //     _streamController.add(data);
          //   });
          },
          child: Center(
            child: StreamBuilder<List<Post>>(
              // stream: postProvider.getPostsImages2(limitePosts,),
              stream: _streamController.stream,

              // initialData: postProvider.listConstposts,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  printVm('Error: ${snapshot.error}');
                  return Center(child: Icon(Icons.error));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(child: Text('No posts found'));
                }
                // Mettre à jour seulement si de nouvelles données arrivent
                if (!isLoading && snapshot.data != listConstposts) {

                  listConstposts = snapshot.data!;

                }

                listConstposts = snapshot.data!;

                return Expanded(
                  child: Consumer<PostProvider>(
                    builder: (context, postListProvider, child) {
                      var datas= listConstposts;
                      return datas.isEmpty
                          ? Center(child: SizedBox(
                          height: 20,
                          width: 20,

                          child: CircularProgressIndicator()))
                          : PageView.builder(
                          scrollDirection: Axis.vertical,
                          itemCount: datas.length,

                          itemBuilder: (context, index) {
                            if (index % 8 == 7) {
                              return FutureBuilder<List<ArticleData>>(
                                future: categorieProduitProvider.getArticleBooster(authProvider.loginUserData.countryData?['countryCode'] ?? 'TG'),
                                builder: (BuildContext context, AsyncSnapshot snapshot) {
                                  if (snapshot.hasData) {
                                    List<ArticleData> articles = snapshot.data;
                                    if (articles.isEmpty) {
                                      return SizedBox.shrink(); // Retourne un widget vide si la liste est vide
                                    }
                                    return SizedBox(
                                      height: h * 0.35,
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
                                                          fontSize: 12,
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
                                                            fontSize: 18,
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
                                                        article: article, w: w, h: h, isOtherPage: true);
                                                  },
                                                );
                                              }).toList(),
                                              options: CarouselOptions(
                                                height: h*0.4,
                                                autoPlay: true,
                                                enlargeCenterPage: true,
                                                viewportFraction: 0.6,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  } else if (snapshot.hasError) {
                                    return Icon(Icons.error_outline);
                                  } else {
                                    return Center(
                                      child: SizedBox(
                                        height: 30,
                                          width: 30,

                                          child: CircularProgressIndicator()),
                                    );
                                  }
                                },
                              );
                            }


                            return   Container(
                              color: Colors.black,
                              //  height: MediaQuery.of(context).size.height,
                              child: Stack(
                                children: [
                                  SamplePlayer(post: datas[index]!),
                                  // VideoWidget(post: datas[index]!),

                                  // Expanded(
                                  //
                                  //   child: SimpleVideoPlayerWidget(videoUrl: datas[index].url_media!)),
                                  // Container(
                                  //   padding: const EdgeInsets.all(10.0),
                                  //   decoration: BoxDecoration(
                                  //     gradient: LinearGradient(
                                  //       colors: [
                                  //         Colors.black,
                                  //         Colors.transparent,
                                  //         Colors.transparent,
                                  //         Colors.black.withOpacity(0.15)
                                  //       ],
                                  //       begin: Alignment.topCenter,
                                  //       end: Alignment.bottomCenter,
                                  //       stops: const [0, 0, 0.6, 1],
                                  //     ),
                                  //   ),
                                  // ),
                                  Positioned(

                                    left: 12.0,
                                    bottom: 20.0,
                                    child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: SafeArea(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              datas[index].type==PostType.PUB.name?
                                              Column(

                                                children: [
                                                  Padding(
                                                    padding: const EdgeInsets.only(bottom: 4.0),
                                                    child: Row(
                                                      children: [
                                                        Icon(Entypo.network,size: 15,color: Colors.green,),
                                                        SizedBox(width: 10,),
                                                        TextCustomerUserTitle(
                                                          titre: "publicité",
                                                          fontSize: SizeText.homeProfileTextSize,
                                                          couleur: Colors.white,
                                                          fontWeight: FontWeight.w400,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  Row(
                                                    children: [
                                                      TextButton(

                                                        onPressed: () {
                                                          _showUserDetailsModalDialog(datas[index].user!, w, h);
                                                        },
                                                        child: Row(
                                                          children: [
                                                            Padding(
                                                              padding: const EdgeInsets.only(right: 8.0),
                                                              child: CircleAvatar(
                                                                radius: 12,
                                                                backgroundImage: NetworkImage(
                                                                    '${ datas[index].entrepriseData!.urlImage!}'),
                                                              ),
                                                            ),
                                                            SizedBox(
                                                              height: 2,
                                                            ),
                                                            Row(
                                                              children: [
                                                                Column(
                                                                  children: [
                                                                    SizedBox(
                                                                      //width: 100,
                                                                      child: TextCustomerUserTitle(
                                                                        titre: "${ datas[index].entrepriseData!.titre!}",
                                                                        fontSize: 10,
                                                                        couleur: Colors.white,
                                                                        fontWeight: FontWeight.bold,

                                                                      ),
                                                                    ),
                                                                    TextCustomerUserTitle(
                                                                      titre: "${datas[index].entrepriseData!.suivi!} suivi(s)",
                                                                      fontSize: 10,
                                                                      couleur: Colors.white,
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
                                                      ),

                                                      SizedBox(width: 10,),
                                                      Icon(Entypo.arrow_long_right,color: Colors.green,size: 12,),
                                                      SizedBox(width: 10,),
                                                      Row(
                                                        children: [
                                                          Padding(
                                                            padding: const EdgeInsets.only(right: 8.0),
                                                            child: CircleAvatar(
                                                              radius: 12,
                                                              backgroundImage: NetworkImage(
                                                                  '${ datas[index].user!.imageUrl!}'),
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
                                                                      titre: "@${ datas[index].user!.pseudo!}",
                                                                      fontSize: 10,
                                                                      couleur: Colors.white,
                                                                      fontWeight: FontWeight.bold,
                                                                    ),
                                                                  ),
                                                                  TextCustomerUserTitle(
                                                                    titre: "${ datas[index].user!.abonnes!} abonné(s)",
                                                                    fontSize: 10,
                                                                    couleur: Colors.white,
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
                                                  SizedBox(height: 5,),
                                                  Row(
                                                    children: [
                                                      Container(
                                                        //width: 50,
                                                        height: 30,
                                                        margin: EdgeInsets.zero,
                                                        decoration: BoxDecoration(
                                                            color: Colors.blue,
                                                            borderRadius: BorderRadius.all(Radius.circular(20))),

                                                        child: Padding(
                                                          padding: const EdgeInsets.only(left: 3.0,right: 3),
                                                          child: TextButton(onPressed: () {
                                                            printVm('contact tap');
                                                            getChatsEntrepriseData( datas[index].user!, datas[index], datas[index].entrepriseData!).then((chat) async {
                                                              userProvider.chat.messages=chat.messages;

                                                              //_chewieController.pause();
                                                              // videoPlayerController.pause();


                                                              Navigator.push(context, PageTransition(type: PageTransitionType.fade, child: EntrepriseMyChat(title: 'mon chat', chat: chat, post: datas[index], isEntreprise: false,)));





                                                            },);

                                                          },
                                                              child: Row(
                                                                mainAxisAlignment: MainAxisAlignment.center,
                                                                crossAxisAlignment: CrossAxisAlignment.center,
                                                                children: [
                                                                  Icon(AntDesign.message1,color: Colors.white,size: 12,),
                                                                  SizedBox(width: 5,),
                                                                  Text("Afrolook",style: TextStyle(color: Colors.white,fontSize: 12,fontWeight: FontWeight.w600),),
                                                                ],
                                                              )),
                                                        ),

                                                      ),
                                                      SizedBox(width: 10,),
                                                      Container(
                                                        //width: 50,
                                                        height: 30,
                                                        margin: EdgeInsets.zero,
                                                        decoration: BoxDecoration(
                                                            color: Colors.white,
                                                            borderRadius: BorderRadius.all(Radius.circular(20))),

                                                        child: Padding(
                                                          padding: const EdgeInsets.only(left: 3.0,right: 3),
                                                          child: TextButton(onPressed: () {
                                                            launchWhatsApp("${datas[index].contact_whatsapp}");


                                                          },
                                                              child: Row(
                                                                mainAxisAlignment: MainAxisAlignment.center,
                                                                crossAxisAlignment: CrossAxisAlignment.center,
                                                                children: [
                                                                  Icon(Fontisto.whatsapp,color: Colors.green,size: 12,),
                                                                  SizedBox(width: 5,),
                                                                  Text("WhatsApp",style: TextStyle(color: Colors.green,fontSize: 12,fontWeight: FontWeight.w600),),
                                                                ],
                                                              )),
                                                        ),

                                                      ),

                                                    ],
                                                  )

                                                ],
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                              ): TextButton(
                                                onPressed: () {

                                                    _showUserDetailsModalDialog(datas[index].user!, w, h);

                                                },
                                                child: Row(
                                                  children: [
                                                    Container(
                                                      height: 30.0,
                                                      width: 30.0,
                                                      decoration: BoxDecoration(
                                                          border:
                                                          Border.all(width: 1.0, color: Colors.white),
                                                          shape: BoxShape.circle,
                                                          image: DecorationImage(
                                                              image: NetworkImage( datas[index].user!.imageUrl!),
                                                              fit: BoxFit.cover)),
                                                    ),
                                                    const SizedBox(
                                                      width: 5.0,
                                                    ),
                                                    Text(
                                                      "@${datas[index].user!.pseudo!}",
                                                      style: const TextStyle(
                                                        fontSize: 12.0, color: Colors.white,),
                                                    ),
                                                    const SizedBox(
                                                      width: 5.0,
                                                    )
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(
                                                height: 12.0,
                                              ),
                                              Container(
                                                width: 300,
                                                height: 40,
                                                child: Text(
                                                  datas[index].description!,
                                                  style: const TextStyle(color: Colors.white,fontSize: 10),
                                                ),
                                              )
                                            ],
                                          )),
                                    ),
                                  ),
                                  Positioned(
                                      right: 10.0,
                                      bottom: 50.0,
                                      child: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(0.1), // Shadow color
                                                spreadRadius: 2, // Spread of the shadow
                                                blurRadius: 5, // Blur effect to soften the shadow
                                                offset: Offset(0, 4), // Shadow position (x, y)
                                              ),
                                            ],
                                          ),
                                          child: Column(
                                            spacing: 5,
                                            children: [
                                              const SizedBox(
                                                height: 20.0,
                                              ),

                                              LikeButton(

                                                onTap: (bool isLiked) async {
                                                  // _triggerAnimation('like');
                                                  _sendLike();
                                                  if (!isIn( datas[index].users_love_id!,authProvider.loginUserData.id!)) {
                                                    printVm('tap');
                                                    setState(()  {
                                                      datas[index].loves=datas[index]!.loves!+1;


                                                      datas[index]!.users_love_id!.add(authProvider!.loginUserData.id!);

                                                      printVm('update');
                                                      //loves.add(idUser);
                                                    });
                                                    CollectionReference userCollect =
                                                    FirebaseFirestore.instance.collection('Users');
                                                    // Get docs from collection reference
                                                    QuerySnapshot querySnapshotUser = await userCollect.where("id",isEqualTo: datas[index].user!.id!).get();
                                                    // Afficher la liste
                                                    List<UserData>  listUsers = querySnapshotUser.docs.map((doc) =>
                                                        UserData.fromJson(doc.data() as Map<String, dynamic>)).toList();
                                                    if (listUsers.isNotEmpty) {
                                                      listUsers.first!.jaimes=listUsers.first!.jaimes!+1;
                                                      postProvider.updatePost(datas[index], listUsers.first!!,context);
                                                      await authProvider.getAppData();
                                                      authProvider.appDefaultData.nbr_loves=authProvider.appDefaultData.nbr_loves!+1;
                                                      authProvider.updateAppData(authProvider.appDefaultData);


                                                    }else{
                                                      datas[index].user!.jaimes=datas[index].user!.jaimes!+1;
                                                      postProvider.updatePost( datas[index],datas[index].user!,context);
                                                      await authProvider.getAppData();
                                                      authProvider.appDefaultData.nbr_loves=authProvider.appDefaultData.nbr_loves!+1;
                                                      authProvider.updateAppData(authProvider.appDefaultData);

                                                    }
                                                    await authProvider.sendNotification(
                                                        userIds: [datas[index].user!.oneIgnalUserid!],
                                                        smallImage: "${authProvider.loginUserData.imageUrl!}",
                                                        send_user_id: "${authProvider.loginUserData.id!}",
                                                        recever_user_id: "${datas[index].user!.id!}",
                                                        message: "📢 @${authProvider.loginUserData.pseudo!} a aimé ❤️ votre look video",
                                                        type_notif: NotificationType.POST.name,
                                                        post_id: "${datas[index]!.id!}",
                                                        post_type: PostDataType.VIDEO.name, chat_id: ''
                                                    );

                                                    NotificationData notif=NotificationData();
                                                    notif.id=firestore
                                                        .collection('Notifications')
                                                        .doc()
                                                        .id;
                                                    notif.titre="Nouveau j'aime ❤️";
                                                    notif.media_url=authProvider.loginUserData.imageUrl;
                                                    notif.type=NotificationType.POST.name;
                                                    notif.description="@${authProvider.loginUserData.pseudo!} a aimé votre look video";
                                                    notif.users_id_view=[];
                                                    notif.user_id=authProvider.loginUserData.id;
                                                    notif.receiver_id="${datas[index].user!.id!}";
                                                    notif.post_id=datas[index].id!;
                                                    notif.post_data_type=PostDataType.VIDEO.name!;
                                                    notif.updatedAt =
                                                        DateTime.now().microsecondsSinceEpoch;
                                                    notif.createdAt =
                                                        DateTime.now().microsecondsSinceEpoch;
                                                    notif.status = PostStatus.VALIDE.name;

                                                    // users.add(pseudo.toJson());

                                                    await firestore.collection('Notifications').doc(notif.id).set(notif.toJson());
                                                    postProvider.interactWithPostAndIncrementSolde(datas[index].id!, authProvider.loginUserData.id!, "like",datas[index].user_id!);

                                                  }

                                                  return Future.value(!isLiked);
                                                },
                                                isLiked: isIn(datas[index]!.users_love_id!,authProvider.loginUserData.id!),

                                                size: 30,
                                                circleColor:
                                                CircleColor(start: Color(0xff00ddff), end: Color(0xff0099cc)),
                                                bubblesColor: BubblesColor(
                                                  dotPrimaryColor: Color(0xff3b9ade),
                                                  dotSecondaryColor: Color(0xffe33232),
                                                ),
                                                countPostion: CountPostion.bottom,
                                                likeBuilder: (bool isLiked) {
                                                  return Icon(
                                                    Entypo.heart,
                                                    color: isLiked ? Colors.red : Colors.white,
                                                    size: 30,
                                                  );
                                                },
                                                likeCount:  datas[index]!.users_love_id!.length!,
                                                countBuilder: (int? count, bool isLiked, String text) {
                                                  var color = isLiked ? Colors.white : Colors.white;
                                                  Widget result;
                                                  if (count == 0) {
                                                    result = Text(
                                                      "0",textAlign: TextAlign.center,
                                                      style: TextStyle(color: color),

                                                    );
                                                  } else
                                                    result = Text(
                                                      text,
                                                      style: TextStyle(color: color),
                                                    );
                                                  return result;
                                                },

                                              ),

                                              LikeButton(
                                                onTap: (bool isLiked) {

                                                  //  _chewieController.pause();
                                                  //  videoPlayerController.pause();


                                                  Navigator.push(context, MaterialPageRoute(builder: (context) => PostComments(post:  datas[index]!),));


                                                  return Future.value(!isLiked);
                                                },

                                                isLiked: false,
                                                size: 30,
                                                circleColor:
                                                CircleColor(start: Color(0xff00ddff), end: Color(0xff0099cc)),
                                                bubblesColor: BubblesColor(
                                                  dotPrimaryColor: Color(0xff3b9ade),
                                                  dotSecondaryColor: Color(0xff027f19),
                                                ),
                                                countPostion: CountPostion.bottom,
                                                likeBuilder: (bool isLiked) {
                                                  return Icon(
                                                    FontAwesome.commenting,
                                                    color: isLiked ? Colors.white : Colors.white,
                                                    size: 30,
                                                  );
                                                },
                                                likeCount: datas[index]!.comments!,
                                                countBuilder: (int? count, bool isLiked, String text) {
                                                  var color = isLiked ? Colors.white : Colors.white;
                                                  Widget result;
                                                  if (count == 0) {
                                                    result = Text(
                                                      "0",textAlign: TextAlign.center,
                                                      style: TextStyle(color: color),
                                                    );
                                                  } else
                                                    result = Text(
                                                      text,
                                                      style: TextStyle(color: color),
                                                    );
                                                  return result;
                                                },

                                              ),
                                              //vues
                                              // LikeButton(
                                              //   isLiked: false,
                                              //   size: 35,
                                              //   circleColor:
                                              //   CircleColor(start: Color(0xff00ddff), end: Color(0xff0099cc)),
                                              //   bubblesColor: BubblesColor(
                                              //     dotPrimaryColor: Color(0xff3b9ade),
                                              //     dotSecondaryColor: Color(0xff027f19),
                                              //   ),
                                              //   countPostion: CountPostion.bottom,
                                              //   likeBuilder: (bool isLiked) {
                                              //     return Icon(
                                              //       FontAwesome.eye,
                                              //       color: isLiked ? Colors.white : Colors.white,
                                              //       size: 35,
                                              //     );
                                              //   },
                                              //   likeCount:  datas[index].vues!,
                                              //   countBuilder: (int? count, bool isLiked, String text) {
                                              //     var color = isLiked ? Colors.white : Colors.white;
                                              //     Widget result;
                                              //     if (count == 0) {
                                              //       result = Text(
                                              //         "0",textAlign: TextAlign.center,
                                              //         style: TextStyle(color: color,fontSize: 8),
                                              //       );
                                              //     } else
                                              //       result = Text(
                                              //         text,
                                              //         style: TextStyle(color: color,fontSize: 8),
                                              //       );
                                              //     return result;
                                              //   },
                                              //
                                              // ),
                                              LikeButton(
                                                onTap: (bool isLiked) {

                                                  //  _chewieController.pause();
                                                  //  videoPlayerController.pause();



                                                  postProvider.getPostsImagesById(datas[index]!.id!).then((value) async {
                                                    if(value.isNotEmpty){
                                                      datas[index]!=value.first;
                                                      await authProvider.getAppData();
                                                      showGiftDialog(datas[index]!,authProvider.loginUserData,authProvider.appDefaultData);

                                                    }
                                                  },);


                                                  return Future.value(!isLiked);
                                                },
                                                isLiked: false,
                                                size: 35,
                                                circleColor:
                                                CircleColor(start: Color(0xff00ddff), end: Color(0xff0099cc)),
                                                bubblesColor: BubblesColor(
                                                  dotPrimaryColor: Color(0xff3b9ade),
                                                  dotSecondaryColor: Color(0xff027f19),
                                                ),
                                                countPostion: CountPostion.bottom,
                                                likeBuilder: (bool isLiked) {
                                                  return Text('🎁',style: TextStyle(fontSize: 30),);
                                                },
                                                likeCount:  datas[index].users_cadeau_id!=null?datas[index].users_cadeau_id!.length:0,
                                                countBuilder: (int? count, bool isLiked, String text) {
                                                  var color = isLiked ? Colors.white : Colors.white;
                                                  Widget result;
                                                  if (count == 0) {
                                                    result = Text(
                                                      "0",textAlign: TextAlign.center,
                                                       style: TextStyle(color: color),
                                                    );
                                                  } else
                                                    result = Text(
                                                      text,
                                                       style: TextStyle(color: color),
                                                    );
                                                  return result;
                                                },

                                              ),
                                              LikeButton(
                                                onTap: (bool isLiked) {

                                                  //  _chewieController.pause();
                                                  //  videoPlayerController.pause();



                                                  postProvider.getPostsImagesById(datas[index]!.id!).then((value) async {
                                                    if(value.isNotEmpty){
                                                      datas[index]!=value.first;
                                                      await authProvider.getAppData();
                                                      showRepublishDialog(datas[index]!,authProvider.loginUserData,authProvider.appDefaultData,context);

                                                    }
                                                  },);


                                                  return Future.value(!isLiked);
                                                },
                                                isLiked: false,
                                                size: 30,
                                                circleColor:
                                                CircleColor(start: Color(0xff00ddff), end: Color(0xff0099cc)),
                                                bubblesColor: BubblesColor(
                                                  dotPrimaryColor: Color(0xff3b9ade),
                                                  dotSecondaryColor: Color(0xff027f19),
                                                ),
                                                countPostion: CountPostion.bottom,
                                                likeBuilder: (bool isLiked) {
                                                  return Icon(
                                                    Feather.repeat,
                                                    color: isLiked ? Colors.blue : Colors.blue,
                                                    size: 30,
                                                  );
                                                },
                                                likeCount:  datas[index].users_republier_id!=null?datas[index].users_republier_id!.length:0,
                                                countBuilder: (int? count, bool isLiked, String text) {
                                                  var color = isLiked ? Colors.white : Colors.white;
                                                  Widget result;
                                                  if (count == 0) {
                                                    result = Text(
                                                      "0",textAlign: TextAlign.center,
                                                      style: TextStyle(color: color),

                                                    );
                                                  } else
                                                    result = Text(
                                                      text,
                                                      style: TextStyle(color: color),

                                                    );
                                                  return result;
                                                },

                                              ),



                                              IconButton(
                                                  onPressed: () {
                                                    // _showModalDialog(datas[index]);
                                                    _showPostMenuModalDialog(datas[index],context);
                                                  },
                                                  icon: Icon(
                                                    Icons.more_horiz,
                                                    size: 35,
                                                    color: Colors.white,
                                                  )),

                                            ],
                                          ),
                                        ),
                                      )),
                                  // Animations des likes
                                  ..._heartAnimations.map((controller) => HeartAnimation(controller: controller)),

                                  // Animations des cadeaux
                                  ..._giftAnimations.map((controller) => GiftAnimation(controller: controller)),
                                  ..._giftReplyAnimations.map((controller) => GiftReplyAnimation(controller: controller)),
                                ],
                              ),
                            );
                          });

                    },
                  ),
                );
              },
            ),
          ),
        )
    );

  }
}



class HeartAnimation extends StatelessWidget {
  final AnimationController controller;

  const HeartAnimation({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Center(
          child: Opacity(
            opacity: 1 - controller.value,
            child: Transform.scale(
              scale: 1 + controller.value * 2,
              child: Icon(
                Icons.favorite,
                color: Colors.red,
                size: 100,
              ),
            ),
          ),
        );
      },
    );
  }
}

class GiftAnimation extends StatelessWidget {
  final AnimationController controller;

  const GiftAnimation({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Center(
          child: Opacity(
            opacity: 1 - controller.value,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Transform.scale(
                  scale: 1 + controller.value,
                  child: Text(
                    '🎁',
                    style: TextStyle(fontSize: 80),
                  ),
                ),
                // Text(
                //   'User a envoyé un cadeau!',
                //   style: TextStyle(
                //     color: Colors.white,
                //     fontSize: 20,
                //     shadows: [
                //       Shadow(
                //         color: Colors.black,
                //         blurRadius: 10,
                //         offset: Offset(2, 2),
                //       ),
                //     ],
                //   ),
                // ),
              ],
            ),
          ),
        );
      },
    );
  }
}
class GiftReplyAnimation extends StatelessWidget {
  final AnimationController controller;

  const GiftReplyAnimation({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Center(
          child: Opacity(
            opacity: 1 - controller.value,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Transform.scale(
                  scale: 1 + controller.value,
                  child: Text(
                    '🔝',
                    style: TextStyle(fontSize: 80),
                  ),
                ),
                // Text(
                //   'User a envoyé un cadeau!',
                //   style: TextStyle(
                //     color: Colors.white,
                //     fontSize: 20,
                //     shadows: [
                //       Shadow(
                //         color: Colors.black,
                //         blurRadius: 10,
                //         offset: Offset(2, 2),
                //       ),
                //     ],
                //   ),
                // ),
              ],
            ),
          ),
        );
      },
    );
  }
}
