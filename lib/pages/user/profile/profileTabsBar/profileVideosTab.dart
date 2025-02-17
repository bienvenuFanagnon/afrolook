import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'dart:math';

import 'package:anim_search_bar/anim_search_bar.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:contained_tab_bar_view_with_custom_page_navigator/contained_tab_bar_view_with_custom_page_navigator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:intl/intl.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:popup_menu/popup_menu.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../../constant/constColors.dart';
import '../../../../constant/iconGradient.dart';
import '../../../../constant/listItemsCarousel.dart';
import '../../../../constant/sizeText.dart';
import '../../../../constant/textCustom.dart';
import '../../../../models/model_data.dart';
import '../../../../providers/authProvider.dart';
import '../../../../providers/postProvider.dart';
import '../../../../providers/userProvider.dart';
import '../../../component/consoleWidget.dart';
import '../../../postComments.dart';
import '../../../socialVideos/afrovideos/SimpleVideoView.dart';
import '../../../userPosts/postWidgets/postCadeau.dart';
import '../../../userPosts/postWidgets/postUserWidget.dart';
import '../../../userPosts/postWidgets/postWidgetPage.dart';

class ProfileVideoTab extends StatefulWidget {
  const ProfileVideoTab({super.key});

  @override
  State<ProfileVideoTab> createState() => _ProfileVideoTabState();
}

class _ProfileVideoTabState extends State<ProfileVideoTab> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  late UserAuthProvider authProvider =
  Provider.of<UserAuthProvider>(context, listen: false);

  late UserProvider userProvider =
  Provider.of<UserProvider>(context, listen: false);

  late PostProvider postProvider =
  Provider.of<PostProvider>(context, listen: false);

  TextEditingController commentController =TextEditingController();
  String formaterDateTime2(DateTime dateTime) {
    DateTime now = DateTime.now();

    if (dateTime.year == now.year &&
        dateTime.month == now.month &&
        dateTime.day == now.day) {
      // Si la date est aujourd'hui, afficher seulement l'heure et la minute
      return DateFormat.Hm().format(dateTime);
    } else {
      // Sinon, afficher la date complète
      return DateFormat.yMd().add_Hms().format(dateTime);
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
  PopupMenu? postmenu;


  bool isUserAbonne(List<UserAbonnes> userAbonnesList, String userIdToCheck) {
    return userAbonnesList.any((userAbonne) => userAbonne.abonneUserId == userIdToCheck);
  }

  bool isIn(List<String> users_id, String userIdToCheck) {
    return users_id.any((item) => item == userIdToCheck);
  }

  bool isMyFriend(List<Friends> userfriendList, String userIdToCheck) {
    return userfriendList.any((userAbonne) => userAbonne.friendId == userIdToCheck);
  }
  bool isInvite(List<Invitation> invitationList, String userIdToCheck) {
    return invitationList.any((inv) => inv.receiverId == userIdToCheck);
  }

  void _showModalDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Menu d\'options'),
          content: SingleChildScrollView(
            child: Column(
              children: <Widget>[
                ListTile(
                  onTap: () {
                    Navigator.pop(context);
                  },
                  leading: Icon(Icons.flag,color: Colors.blueGrey,),
                  title: Text('Signaler',),
                ),
                ListTile(
                  onTap: () {
                    Navigator.pop(context);
                  },
                  leading: Icon(Icons.edit,color: Colors.blue,),
                  title: Text('Modifier'),
                ),
                ListTile(
                  onTap: () {
                    Navigator.pop(context);
                  },
                  leading: Icon(Icons.delete,color: Colors.red,),
                  title: Text('Supprimer'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String formatNumber(int number) {
    if (number < 1000) {
      return number.toString();
    } else if (number < 1000000) {
      return "${number / 1000} k";
    } else if (number < 1000000000) {
      return "${number / 1000000} m";
    } else {
      return "${number / 1000000000} b";
    }
  }
  final FirebaseFirestore firestore = FirebaseFirestore.instance;


  final List<AnimationController> _heartAnimations = [];
  final List<AnimationController> _giftAnimations = [];
  final List<AnimationController> _giftReplyAnimations = [];
bool _isLoading=false;
  final String imageCadeau='https://th.bing.com/th/id/R.07b0fcbd29597e76b66b50f7ba74bc65?rik=vHxQSLwSFG2gAw&riu=http%3a%2f%2fwww.conseilsdefamille.com%2fwp-content%2fuploads%2f2013%2f03%2fCadeau-Fotolia_27171652CMYK_WB.jpg&ehk=vzUbV07%2fUgXnc1LdlIVCaD36qZGAxa7V8JtbqOFfoqY%3d&risl=&pid=ImgRaw&r=0';


  int idUser=7;
  // Color _color = _randomColor.randomColor(
  //     colorHue: ColorHue.multiple(colorHues: [ColorHue.red, ColorHue.blue,ColorHue.green, ColorHue.orange,ColorHue.yellow, ColorHue.purple])
  // );

  int limitePosts=30;
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
  Widget homePostUsers(Post post,double height, double width) {
    double h = MediaQuery.of(context).size.height;
    double w = MediaQuery.of(context).size.width;

    Random random = Random();
    bool abonneTap =false;
    int like=post!.likes!;
    int imageIndex=0;
    int love=post!.loves!;
    int comments=post!.comments!;
    bool tapLove=isIn(post.users_love_id!,authProvider.loginUserData.id!);
    bool tapLike=isIn(post.users_like_id!,authProvider.loginUserData.id!);
    List<int> likes =[];
    List<int> loves =[];
    int idUser=7;
    return Container(
      child: StatefulBuilder(
          builder: (BuildContext context, StateSetter setStateImages) {
            return Padding(
              padding: const EdgeInsets.all(5.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: CircleAvatar(
                              backgroundImage: NetworkImage(
                                  '${post.user!.imageUrl!}'),
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
                                      titre: "@${post.user!.pseudo!}",
                                      fontSize: SizeText.homeProfileTextSize,
                                      couleur: ConstColors.textColors,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  TextCustomerUserTitle(
                                    titre: "${formatNumber(post.user!.abonnes!)} abonné(s)",
                                    fontSize: SizeText.homeProfileTextSize,
                                    couleur: ConstColors.textColors,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ],
                              ),
                              StatefulBuilder(

                                  builder: (BuildContext context, void Function(void Function()) setState) {
                                    return Container(
                                      child: isUserAbonne(authProvider.loginUserData.userAbonnes!, post.user!.id!)?Container(): TextButton(

                                          onPressed:abonneTap?
                                              ()  { }:
                                              ()async{
                                            if (!isUserAbonne(authProvider.loginUserData.userAbonnes!, post.user!.id!)) {
                                              setState(() {
                                                abonneTap=true;
                                              });
                                              UserAbonnes userAbonne = UserAbonnes();
                                              userAbonne.compteUserId=authProvider.loginUserData.id;
                                              userAbonne.abonneUserId=post.user!.id;

                                              userAbonne.createdAt  = DateTime.now().millisecondsSinceEpoch;
                                              userAbonne.updatedAt  = DateTime.now().millisecondsSinceEpoch;
                                              await  userProvider.sendAbonnementRequest(userAbonne,post.user!,context).then((value) async {
                                                if (value) {
                                                  authProvider.loginUserData.userAbonnes!.add(userAbonne);
                                                  // await userProvider.getUsers(authProvider.loginUserData!.id!);
                                                  await authProvider.getCurrentUser(authProvider.loginUserData!.id!);
                                                  SnackBar snackBar = SnackBar(
                                                    content: Text('abonné',textAlign: TextAlign.center,style: TextStyle(color: Colors.green),),
                                                  );
                                                  ScaffoldMessenger.of(context).showSnackBar(snackBar);
                                                  setState(() {
                                                    abonneTap=false;
                                                  });
                                                }  else{
                                                  SnackBar snackBar = SnackBar(
                                                    content: Text('une erreur',textAlign: TextAlign.center,style: TextStyle(color: Colors.red),),
                                                  );
                                                  ScaffoldMessenger.of(context).showSnackBar(snackBar);
                                                  setState(() {
                                                    abonneTap=false;
                                                  });
                                                }
                                              },);


                                              setState(() {
                                                abonneTap=false;
                                              });
                                            }

                                          },
                                          child:abonneTap? Center(
                                            child: LoadingAnimationWidget.flickr(
                                              size: 20,
                                              leftDotColor: Colors.green,
                                              rightDotColor: Colors.black,
                                            ),
                                          ): Text("S'abonner",style: TextStyle(fontSize: 12,fontWeight:FontWeight.normal,color: Colors.blue),)
                                      ),
                                    );
                                  }
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
                      IconButton(
                          onPressed: _showModalDialog,
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
                  Align(
                    alignment: Alignment.topLeft,
                    child: SizedBox(
                      width: 300,
                      //height: 50,
                      child: Container(
                        alignment: Alignment.centerLeft,
                        child: TextCustomerPostDescription(
                          titre:
                          "${post.description}",
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
                      titre: "${formaterDateTime(DateTime.fromMicrosecondsSinceEpoch(post.createdAt!))}",
                      fontSize: SizeText.homeProfileDateTextSize,
                      couleur: ConstColors.textColors,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(
                    height: 5,
                  ),
                  post!.images==null? Container():

                  Container(
                    width: w,
                    height: h*0.3,

                    child: ClipRRect(
                      borderRadius: BorderRadius.all(Radius.circular(5)),
                      child: SimpleVideoPlayerWidget(videoUrl: '${post!.url_media==null?'':post!.url_media}'),
                    ),
                  ),



                  SizedBox(
                    height: 10,
                  ),
                  Container(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisSize: MainAxisSize.max,
                      children: [

                        StatefulBuilder(builder:
                            (BuildContext context, StateSetter setState) {
                          return GestureDetector(
                            onTap: () {
                              // _sendGift('🎁');
                              postProvider.getPostsImagesById(post.id!).then((value) async {
                                if(value.isNotEmpty){
                                  post=value.first;
                                  await authProvider.getAppData();
                                  showRepublishDialog(post,authProvider.loginUserData,authProvider.appDefaultData,context);

                                }
                              },);


                            },

                            child: Container(
                              width: 70,
                              height: 30,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                // mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Feather.repeat,
                                        size: 20,
                                        color: Colors.blue,
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.only(
                                            left: 1.0, right: 1),
                                        child: TextCustomerPostDescription(
                                          titre: "${formatAbonnes(post!.users_republier_id==null?0:post!.users_republier_id!.length!)}",
                                          fontSize: SizeText
                                              .homeProfileDateTextSize,
                                          couleur: ConstColors.textColors,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                        StatefulBuilder(builder:
                            (BuildContext context, StateSetter setState) {
                          return GestureDetector(
                            onTap: () async {
                              postProvider.getPostsImagesById(post.id!).then((value) async {
                                if(value.isNotEmpty){
                                  post=value.first;
                                  await authProvider.getAppData();
                                  showGiftDialog(post,authProvider.loginUserData,authProvider.appDefaultData);

                                }
                              },);

                            },
                            child: Container(
                              //height: 20,
                              width: 70,
                              height: 30,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                // mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      // AnimateIcon(
                                      //
                                      //   key: UniqueKey(),
                                      //   onTap: () {},
                                      //   iconType: IconType.continueAnimation,
                                      //   height: 20,
                                      //   width: 20,
                                      //   color: Colors.red,
                                      //   animateIcon: AnimateIcons.share,
                                      //
                                      // ),

                                      Text('🎁',style: TextStyle(fontSize: 20),),
                                      Padding(
                                        padding: const EdgeInsets.only(
                                            left: 1.0, right: 1),
                                        child: TextCustomerPostDescription(
                                          titre: "${formatAbonnes(post!.users_cadeau_id==null?0:post!.users_cadeau_id!.length!)}",
                                          fontSize: SizeText
                                              .homeProfileDateTextSize,
                                          couleur: ConstColors.textColors,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  /*
                                            Expanded(
                                              child: Padding(
                                                padding: const EdgeInsets.only(left: 1.0,right: 1),
                                                child: SizedBox(
                                                  height: 2,
                                                  width: 5,
                                                  child: LinearProgressIndicator(
                                                    color: Colors.red,
                                                    value: love/post!.user!.abonnes!+1,
                                                    semanticsLabel: 'Linear progress indicator',
                                                  ),
                                                ),
                                              ),
                                            ),
                                            TextCustomerPostDescription(
                                              titre: "${((love/post!.user!.abonnes!+1)).toStringAsFixed(2)}%",
                                              fontSize: SizeText.homeProfileDateTextSize,
                                              couleur: ConstColors.textColors,
                                              fontWeight: FontWeight.bold,
                                            ),

                                             */
                                ],
                              ),
                            ),
                          );
                        }),

                        StatefulBuilder(builder:
                            (BuildContext context, StateSetter setState) {
                          return GestureDetector(
                            onTap: () async {
                              _sendLike();
                              if (!isIn(post.users_love_id!,
                                  authProvider.loginUserData.id!)) {
                                setState(() {
                                  post.loves = post.loves! + 1;

                                  post.users_love_id!
                                      .add(authProvider!.loginUserData.id!);
                                  love = post.loves!;
                                  //loves.add(idUser);
                                });
                                CollectionReference userCollect =
                                FirebaseFirestore.instance
                                    .collection('Users');
                                // Get docs from collection reference
                                QuerySnapshot querySnapshotUser =
                                await userCollect
                                    .where("id",
                                    isEqualTo: post.user!.id!)
                                    .get();
                                // Afficher la liste
                                List<UserData> listUsers = querySnapshotUser
                                    .docs
                                    .map((doc) => UserData.fromJson(
                                    doc.data() as Map<String, dynamic>))
                                    .toList();
                                if (listUsers.isNotEmpty) {
                                  listUsers.first!.jaimes =
                                      listUsers.first!.jaimes! + 1;
                                  printVm("user trouver");
                                  if (post.user!.oneIgnalUserid != null &&
                                      post.user!.oneIgnalUserid!.length > 5) {
                                    await authProvider.sendNotification(
                                        userIds: [post.user!.oneIgnalUserid!],
                                        smallImage:
                                        "${authProvider.loginUserData.imageUrl!}",
                                        send_user_id:
                                        "${authProvider.loginUserData.id!}",
                                        recever_user_id: "${post.user!.id!}",
                                        message:
                                        "📢 @${authProvider.loginUserData.pseudo!} a aimé votre look",
                                        type_notif:
                                        NotificationType.POST.name,
                                        post_id: "${post!.id!}",
                                        post_type: PostDataType.IMAGE.name,
                                        chat_id: '');

                                    NotificationData notif =
                                    NotificationData();
                                    notif.id = firestore
                                        .collection('Notifications')
                                        .doc()
                                        .id;
                                    notif.titre = "Nouveau j'aime ❤️";
                                    notif.media_url =
                                        authProvider.loginUserData.imageUrl;
                                    notif.type = NotificationType.POST.name;
                                    notif.description =
                                    "@${authProvider.loginUserData.pseudo!} a aimé votre look";
                                    notif.users_id_view = [];
                                    notif.user_id =
                                        authProvider.loginUserData.id;
                                    notif.receiver_id = post.user!.id!;
                                    notif.post_id = post.id!;
                                    notif.post_data_type =
                                    PostDataType.IMAGE.name!;

                                    notif.updatedAt =
                                        DateTime.now().microsecondsSinceEpoch;
                                    notif.createdAt =
                                        DateTime.now().microsecondsSinceEpoch;
                                    notif.status = PostStatus.VALIDE.name;

                                    // users.add(pseudo.toJson());

                                    await firestore
                                        .collection('Notifications')
                                        .doc(notif.id)
                                        .set(notif.toJson());
                                  }
                                  // postProvider.updateVuePost(post, context);

                                  //userProvider.updateUser(listUsers.first);
                                  postProvider.interactWithPostAndIncrementSolde(post.id!,authProvider.loginUserData.id!, "like",post.user_id!);

                                  SnackBar snackBar = SnackBar(
                                    content: Text(
                                      '+2 points.  Voir le classement',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: Colors.green),
                                    ),
                                  );
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(snackBar);
                                  postProvider.updatePost(
                                      post, listUsers.first, context);
                                  await authProvider.getAppData();
                                  authProvider.appDefaultData.nbr_loves =
                                      authProvider.appDefaultData.nbr_loves! +
                                          2;
                                  authProvider.updateAppData(
                                      authProvider.appDefaultData);
                                } else {
                                  post.user!.jaimes = post.user!.jaimes! + 1;
                                  SnackBar snackBar = SnackBar(
                                    content: Text(
                                      '+2 points.  Voir le classement',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: Colors.green),
                                    ),
                                  );
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(snackBar);
                                  postProvider.updatePost(
                                      post, post.user!, context);
                                  await authProvider.getAppData();
                                  authProvider.appDefaultData.nbr_loves =
                                      authProvider.appDefaultData.nbr_loves! +
                                          2;
                                  authProvider.updateAppData(
                                      authProvider.appDefaultData);
                                }

                                tapLove = true;
                              }
                              printVm("jaime");
                              // setState(() {
                              // });
                            },
                            child: Container(
                              //height: 20,
                              width: 70,
                              height: 30,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                // mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        isIn(
                                            post.users_love_id!,
                                            authProvider
                                                .loginUserData.id!)
                                            ? Ionicons.heart
                                            : Ionicons.md_heart_outline,
                                        color: Colors.red,
                                        size: 20,
                                        // color: ConstColors.likeColors,
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.only(
                                            left: 1.0, right: 1),
                                        child: TextCustomerPostDescription(
                                          titre: "${formatAbonnes(love)}",
                                          fontSize: SizeText
                                              .homeProfileDateTextSize,
                                          couleur: ConstColors.textColors,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  /*
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.only(left: 1.0,right: 1),
                                        child: SizedBox(
                                          height: 2,
                                          width: 5,
                                          child: LinearProgressIndicator(
                                            color: Colors.red,
                                            value: love/post.user!.abonnes!+1,
                                            semanticsLabel: 'Linear progress indicator',
                                          ),
                                        ),
                                      ),
                                    ),
                                    TextCustomerPostDescription(
                                      titre: "${((love/post.user!.abonnes!+1)).toStringAsFixed(2)}%",
                                      fontSize: SizeText.homeProfileDateTextSize,
                                      couleur: ConstColors.textColors,
                                      fontWeight: FontWeight.bold,
                                    ),

                                     */
                                ],
                              ),
                            ),
                          );
                        }),
                        StatefulBuilder(builder:
                            (BuildContext context, StateSetter setState) {
                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        PostComments(post: post),
                                  ));

                              //sheetComments(height*0.7,width,post);
                            },
                            child: Container(
                              width: 70,
                              height: 30,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                // mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        FontAwesome.comments,
                                        size: 20,
                                        color: Colors.green,
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.only(
                                            left: 1.0, right: 1),
                                        child: TextCustomerPostDescription(
                                          titre: "${formatAbonnes(comments)}",
                                          fontSize: SizeText
                                              .homeProfileDateTextSize,
                                          couleur: ConstColors.textColors,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  /*
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.only(left: 1.0,right: 1),
                                        child: SizedBox(
                                          height: 2,
                                          //width: width*0.75,
                                          child: LinearProgressIndicator(
                                            color: Colors.blueGrey,
                                            value: comments/post.user!.abonnes!+1,
                                            semanticsLabel: 'Linear progress indicator',
                                          ),
                                        ),
                                      ),
                                    ),
                                    TextCustomerPostDescription(
                                      titre: "${(comments/post.user!.abonnes!+1).toStringAsFixed(2)}%",
                                      fontSize: SizeText.homeProfileDateTextSize,
                                      couleur: ConstColors.textColors,
                                      fontWeight: FontWeight.bold,
                                    ),

                                     */
                                ],
                              ),
                            ),
                          );
                        }),

                        StatefulBuilder(builder:
                            (BuildContext context, StateSetter setState) {
                          return GestureDetector(
                            onTap: () async {
                              printVm("share post");
                              printVm("like poste monetisation 1 .....");
                              postProvider.interactWithPostAndIncrementSolde(post.id!, authProvider.loginUserData.id!, "share",post.user_id!);

                              // await authProvider.createLink(post).then((value) {
                              final box = context.findRenderObject() as RenderBox?;

                              await authProvider.createLink(true,post).then((url) async {
                                await Share.shareUri(
                                  Uri.parse(
                                      '${url}'),
                                  sharePositionOrigin:
                                  box!.localToGlobal(Offset.zero) & box.size,
                                );


                                setState(() {
                                  post.partage = post.partage! + 1;

                                  // post.users_love_id!
                                  //     .add(authProvider!.loginUserData.id!);
                                  // love = post.loves!;
                                  // //loves.add(idUser);
                                });

                                CollectionReference userCollect =
                                FirebaseFirestore.instance
                                    .collection('Users');
                                // Get docs from collection reference
                                QuerySnapshot querySnapshotUser =
                                await userCollect
                                    .where("id",
                                    isEqualTo: post.user!.id!)
                                    .get();
                                // Afficher la liste
                                List<UserData> listUsers = querySnapshotUser
                                    .docs
                                    .map((doc) => UserData.fromJson(
                                    doc.data() as Map<String, dynamic>))
                                    .toList();
                                if (listUsers.isNotEmpty) {
                                  listUsers.first!.partage =
                                      listUsers.first!.partage! + 1;
                                  printVm("user trouver");
                                  if (post.user!.oneIgnalUserid != null &&
                                      post.user!.oneIgnalUserid!.length > 5) {
                                    await authProvider.sendNotification(
                                        userIds: [post.user!.oneIgnalUserid!],
                                        smallImage:
                                        "${authProvider.loginUserData.imageUrl!}",
                                        send_user_id:
                                        "${authProvider.loginUserData.id!}",
                                        recever_user_id: "${post.user!.id!}",
                                        message:
                                        "📢 @${authProvider.loginUserData.pseudo!} a partagé votre look",
                                        type_notif:
                                        NotificationType.POST.name,
                                        post_id: "${post!.id!}",
                                        post_type: PostDataType.IMAGE.name,
                                        chat_id: '');

                                    NotificationData notif =
                                    NotificationData();
                                    notif.id = firestore
                                        .collection('Notifications')
                                        .doc()
                                        .id;
                                    notif.titre = "Nouveau partage 📲";
                                    notif.media_url =
                                        authProvider.loginUserData.imageUrl;
                                    notif.type = NotificationType.POST.name;
                                    notif.description =
                                    "@${authProvider.loginUserData.pseudo!} a partagé votre look";
                                    notif.users_id_view = [];
                                    notif.user_id =
                                        authProvider.loginUserData.id;
                                    notif.receiver_id = post.user!.id!;
                                    notif.post_id = post.id!;
                                    notif.post_data_type =
                                    PostDataType.IMAGE.name!;

                                    notif.updatedAt =
                                        DateTime.now().microsecondsSinceEpoch;
                                    notif.createdAt =
                                        DateTime.now().microsecondsSinceEpoch;
                                    notif.status = PostStatus.VALIDE.name;

                                    // users.add(pseudo.toJson());

                                    await firestore
                                        .collection('Notifications')
                                        .doc(notif.id)
                                        .set(notif.toJson());
                                  }
                                  // postProvider.updateVuePost(post, context);

                                  //userProvider.updateUser(listUsers.first);
                                  // SnackBar snackBar = SnackBar(
                                  //   content: Text(
                                  //     '+2 points.  Voir le classement',
                                  //     textAlign: TextAlign.center,
                                  //     style: TextStyle(color: Colors.green),
                                  //   ),
                                  // );
                                  // ScaffoldMessenger.of(context)
                                  //     .showSnackBar(snackBar);

                                  postProvider.updatePost(
                                      post, listUsers.first, context);
                                  // await authProvider.getAppData();
                                  // authProvider.appDefaultData.nbr_loves =
                                  //     authProvider.appDefaultData.nbr_loves! +
                                  //         2;
                                  // authProvider.updateAppData(
                                  //     authProvider.appDefaultData);


                                  tapLove = true;
                                }

                              },);
                              // if (!isIn(post.users_love_id!,
                              //     authProvider.loginUserData.id!)) {
                              //   setState(() {
                              //     post.loves = post.loves! + 1;
                              //
                              //     post.users_love_id!
                              //         .add(authProvider!.loginUserData.id!);
                              //     love = post.loves!;
                              //     //loves.add(idUser);
                              //   });
                              //   CollectionReference userCollect =
                              //   FirebaseFirestore.instance
                              //       .collection('Users');
                              //   // Get docs from collection reference
                              //   QuerySnapshot querySnapshotUser =
                              //   await userCollect
                              //       .where("id",
                              //       isEqualTo: post.user!.id!)
                              //       .get();
                              //   // Afficher la liste
                              //   List<UserData> listUsers = querySnapshotUser
                              //       .docs
                              //       .map((doc) => UserData.fromJson(
                              //       doc.data() as Map<String, dynamic>))
                              //       .toList();
                              //   if (listUsers.isNotEmpty) {
                              //     listUsers.first!.jaimes =
                              //         listUsers.first!.jaimes! + 1;
                              //     printVm("user trouver");
                              //     if (post.user!.oneIgnalUserid != null &&
                              //         post.user!.oneIgnalUserid!.length > 5) {
                              //       await authProvider.sendNotification(
                              //           userIds: [post.user!.oneIgnalUserid!],
                              //           smallImage:
                              //           "${authProvider.loginUserData.imageUrl!}",
                              //           send_user_id:
                              //           "${authProvider.loginUserData.id!}",
                              //           recever_user_id: "${post.user!.id!}",
                              //           message:
                              //           "📢 @${authProvider.loginUserData.pseudo!} a aimé votre look",
                              //           type_notif:
                              //           NotificationType.POST.name,
                              //           post_id: "${post!.id!}",
                              //           post_type: PostDataType.IMAGE.name,
                              //           chat_id: '');
                              //
                              //       NotificationData notif =
                              //       NotificationData();
                              //       notif.id = firestore
                              //           .collection('Notifications')
                              //           .doc()
                              //           .id;
                              //       notif.titre = "Nouveau j'aime ❤️";
                              //       notif.media_url =
                              //           authProvider.loginUserData.imageUrl;
                              //       notif.type = NotificationType.POST.name;
                              //       notif.description =
                              //       "@${authProvider.loginUserData.pseudo!} a aimé votre look";
                              //       notif.users_id_view = [];
                              //       notif.user_id =
                              //           authProvider.loginUserData.id;
                              //       notif.receiver_id = post.user!.id!;
                              //       notif.post_id = post.id!;
                              //       notif.post_data_type =
                              //       PostDataType.IMAGE.name!;
                              //
                              //       notif.updatedAt =
                              //           DateTime.now().microsecondsSinceEpoch;
                              //       notif.createdAt =
                              //           DateTime.now().microsecondsSinceEpoch;
                              //       notif.status = PostStatus.VALIDE.name;
                              //
                              //       // users.add(pseudo.toJson());
                              //
                              //       await firestore
                              //           .collection('Notifications')
                              //           .doc(notif.id)
                              //           .set(notif.toJson());
                              //     }
                              //     // postProvider.updateVuePost(post, context);
                              //
                              //     //userProvider.updateUser(listUsers.first);
                              //     SnackBar snackBar = SnackBar(
                              //       content: Text(
                              //         '+2 points.  Voir le classement',
                              //         textAlign: TextAlign.center,
                              //         style: TextStyle(color: Colors.green),
                              //       ),
                              //     );
                              //     ScaffoldMessenger.of(context)
                              //         .showSnackBar(snackBar);
                              //     postProvider.updatePost(
                              //         post, listUsers.first, context);
                              //     await authProvider.getAppData();
                              //     authProvider.appDefaultData.nbr_loves =
                              //         authProvider.appDefaultData.nbr_loves! +
                              //             2;
                              //     authProvider.updateAppData(
                              //         authProvider.appDefaultData);
                              //   } else {
                              //     post.user!.jaimes = post.user!.jaimes! + 1;
                              //     SnackBar snackBar = SnackBar(
                              //       content: Text(
                              //         '+2 points.  Voir le classement',
                              //         textAlign: TextAlign.center,
                              //         style: TextStyle(color: Colors.green),
                              //       ),
                              //     );
                              //     ScaffoldMessenger.of(context)
                              //         .showSnackBar(snackBar);
                              //     postProvider.updatePost(
                              //         post, post.user!, context);
                              //     await authProvider.getAppData();
                              //     authProvider.appDefaultData.nbr_loves =
                              //         authProvider.appDefaultData.nbr_loves! +
                              //             2;
                              //     authProvider.updateAppData(
                              //         authProvider.appDefaultData);
                              //   }
                              //
                              //   tapLove = true;
                              // }
                              // printVm("jaime");
                              // // setState(() {
                              // // });
                            },
                            child: Container(
                              //height: 20,
                              width: 70,
                              height: 30,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                // mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        isIn(
                                            post.users_love_id!,
                                            authProvider
                                                .loginUserData.id!)
                                            ? Icons.share
                                            : Icons.share,
                                        color: Colors.red,
                                        size: 20,
                                        // color: ConstColors.likeColors,
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.only(
                                            left: 1.0, right: 1),
                                        child: TextCustomerPostDescription(
                                          titre: "${formatAbonnes(post.partage!)}",
                                          fontSize: SizeText
                                              .homeProfileDateTextSize,
                                          couleur: ConstColors.textColors,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  /*
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.only(left: 1.0,right: 1),
                                        child: SizedBox(
                                          height: 2,
                                          width: 5,
                                          child: LinearProgressIndicator(
                                            color: Colors.red,
                                            value: love/post.user!.abonnes!+1,
                                            semanticsLabel: 'Linear progress indicator',
                                          ),
                                        ),
                                      ),
                                    ),
                                    TextCustomerPostDescription(
                                      titre: "${((love/post.user!.abonnes!+1)).toStringAsFixed(2)}%",
                                      fontSize: SizeText.homeProfileDateTextSize,
                                      couleur: ConstColors.textColors,
                                      fontWeight: FontWeight.bold,
                                    ),

                                     */
                                ],
                              ),
                            ),
                          );
                        }),





                      ],
                    ),
                  ),


                  SizedBox(
                    height: 10,
                  ),
                  Divider(
                    height: 3,
                  )

                ],
              ),
            );
          }
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child:  Padding(
          padding: const EdgeInsets.only(left: 8.0,right: 8,top: 2),
          child: StreamBuilder<List<Post>>(
            stream: postProvider.getPostsVideoByUser(authProvider.loginUserData.id!),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                printVm("attente");
                return SizedBox(
                  //height: height,
                  width: width,
                  child: Column(

                    mainAxisSize: MainAxisSize.max,
                    children: [
                      for(Post p in postProvider.listConstposts)
                        Skeletonizer(

                          child: Padding(
                            padding: const EdgeInsets.only(top: 5.0,bottom: 5),
                            child: homePostUsers(p,height, width),
                          ),
                        )
                    ],
                  ),
                );
              } else if (snapshot.hasError) {
                printVm("erreur ${snapshot.error}");
                return
                  Skeletonizer(

                    //enabled: _loading,
                    child: SizedBox(
                      width: width,
                      height: height*0.4,
                      child: ListView.builder
                        (
                        scrollDirection: Axis.vertical,
                        itemCount: 5,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.all(1.0),
                            child: Container(
                              width: 300,
                              child: Card(
                                color: Colors.white,
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Column(
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              Padding(
                                                padding: const EdgeInsets.only(right: 8.0),
                                                child: CircleAvatar(
                                                  backgroundImage: AssetImage(
                                                      'assets/images/404.png'),
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
                                                          titre: "pseudo",
                                                          fontSize: SizeText.homeProfileTextSize,
                                                          couleur: ConstColors.textColors,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                      TextCustomerUserTitle(
                                                        titre: " abonné(s)",
                                                        fontSize: SizeText.homeProfileTextSize,
                                                        couleur: ConstColors.textColors,
                                                        fontWeight: FontWeight.w400,
                                                      ),
                                                    ],
                                                  ),
                                                  TextButton(onPressed: () {  },
                                                      child: Text("S'abonner",style: TextStyle(fontSize: 12,fontWeight:FontWeight.normal,color: Colors.blue),)
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
                                          IconButton(
                                              onPressed: () {},
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
                                      Align(
                                        alignment: Alignment.topLeft,
                                        child: SizedBox(
                                          width: 300,
                                          //height: 50,
                                          child: Container(
                                            alignment: Alignment.centerLeft,
                                            child: TextCustomerPostDescription(
                                              titre:
                                              "...Afficher plus",
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
                                          titre: "11/12/2023",
                                          fontSize: SizeText.homeProfileDateTextSize,
                                          couleur: ConstColors.textColors,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      SizedBox(
                                        height: 2,
                                      ),
                                      ListItemSlider(
                                        sliders: [
                                          ClipRRect(
                                              borderRadius: BorderRadius.all(Radius.circular(10)),
                                              child: Image.asset(
                                                "assets/images/404.png",
                                                fit: BoxFit.cover,
                                                height: 300,
                                              )),

                                        ],
                                      ),
                                      SizedBox(
                                        height: 5,
                                      ),
                                      Container(
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          mainAxisSize: MainAxisSize.max,
                                          children: [
                                            GestureDetector(
                                              onTap: () {
                                                setState(() {
                                                  //loves.add(idUser);
                                                });

                                              },
                                              child: Container(
                                                //height: 20,
                                                width: 110,
                                                height: 30,
                                                child: Row(

                                                  crossAxisAlignment: CrossAxisAlignment.center,
                                                  // mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Icon(
                                                          Icons.heart_broken_outlined,color: Colors.red,
                                                          size: 20,
                                                          // color: ConstColors.likeColors,
                                                        ),
                                                        Padding(
                                                          padding: const EdgeInsets.only(left: 1.0,right: 1),
                                                          child: TextCustomerPostDescription(
                                                            titre: "20",
                                                            fontSize: SizeText.homeProfileDateTextSize,
                                                            couleur: ConstColors.textColors,
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    Expanded(
                                                      child: Padding(
                                                        padding: const EdgeInsets.only(left: 1.0,right: 1),
                                                        child: SizedBox(
                                                          height: 2,
                                                          width: 10,
                                                          child: LinearProgressIndicator(
                                                            color: Colors.red,
                                                            value: 10/505,
                                                            semanticsLabel: 'Linear progress indicator',
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    TextCustomerPostDescription(
                                                      titre: "${(20/505*100).toStringAsFixed(2)}%",
                                                      fontSize: SizeText.homeProfileDateTextSize,
                                                      couleur: ConstColors.textColors,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),

                                            GestureDetector(
                                              onTap: () {


                                              },
                                              child: Container(
                                                width: 110,
                                                height: 30,
                                                child: Row(

                                                  crossAxisAlignment: CrossAxisAlignment.center,
                                                  // mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Icon(
                                                          Icons.thumb_up,
                                                          size: 20,
                                                          // color: ConstColors.likeColors,
                                                        ),
                                                        Padding(
                                                          padding: const EdgeInsets.only(left: 1.0,right: 1),
                                                          child: TextCustomerPostDescription(
                                                            titre: "20",
                                                            fontSize: SizeText.homeProfileDateTextSize,
                                                            couleur: ConstColors.textColors,
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    Expanded(
                                                      child: Padding(
                                                        padding: const EdgeInsets.only(left: 1.0,right: 1),
                                                        child: SizedBox(
                                                          height: 2,
                                                          // width: width*0.75,
                                                          child: LinearProgressIndicator(
                                                            color: Colors.blue,
                                                            value: 10/505,
                                                            semanticsLabel: 'Linear progress indicator',
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    TextCustomerPostDescription(
                                                      titre: "${(10/505*100).toStringAsFixed(2)}%",
                                                      fontSize: SizeText.homeProfileDateTextSize,
                                                      couleur: ConstColors.textColors,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),

                                            GestureDetector(
                                              onTap: () {


                                              },
                                              child: Container(
                                                width: 110,
                                                height: 30,
                                                child: Row(

                                                  crossAxisAlignment: CrossAxisAlignment.center,
                                                  // mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Icon(
                                                          Icons.comment,
                                                          size: 20,
                                                          // color: ConstColors.likeColors,
                                                        ),
                                                        Padding(
                                                          padding: const EdgeInsets.only(left: 1.0,right: 1),
                                                          child: TextCustomerPostDescription(
                                                            titre: "20",
                                                            fontSize: SizeText.homeProfileDateTextSize,
                                                            couleur: ConstColors.textColors,
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    Expanded(
                                                      child: Padding(
                                                        padding: const EdgeInsets.only(left: 1.0,right: 1),
                                                        child: SizedBox(
                                                          height: 2,
                                                          //width: width*0.75,
                                                          child: LinearProgressIndicator(
                                                            color: Colors.blueGrey,
                                                            value: 20/505,
                                                            semanticsLabel: 'Linear progress indicator',
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    TextCustomerPostDescription(
                                                      titre: "${(20/505*100).toStringAsFixed(2)}%",
                                                      fontSize: SizeText.homeProfileDateTextSize,
                                                      couleur: ConstColors.textColors,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),



                                          ],
                                        ),
                                      ),


                                      SizedBox(
                                        height: 2,
                                      ),

                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  );
              } else {

                return  Column(

                  mainAxisSize: MainAxisSize.max,
                  children: [
                    for(Post p in snapshot.data!)
                      Padding(
                        padding: const EdgeInsets.only(top: 5.0,bottom: 5),
                        child: homePostUsers(p,height, width),
                      )
                  ],
                );
              }
            },
          ),
        ),
      ),
    );
  }
}
