import 'dart:async';
import 'dart:math';

import 'package:afrotok/pages/home/homeWidget.dart';
import 'package:afrotok/pages/socialVideos/afrovideos/afrovideo.dart';
import 'package:afrotok/pages/userPosts/postWidgets/postCadeau.dart';
import 'package:afrotok/pages/userPosts/postWidgets/postMenu.dart';
import 'package:afrotok/pages/postComments.dart';
import 'package:afrotok/pages/userPosts/postWidgets/postWidgetPage.dart';
import 'package:afrotok/providers/postProvider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:afrotok/constant/constColors.dart';
import 'package:afrotok/constant/iconGradient.dart';
import 'package:afrotok/constant/logo.dart';
import 'package:afrotok/constant/sizeText.dart';
import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/providers/userProvider.dart';
import 'package:afrotok/services/api.dart';
import 'package:flutter/material.dart';
import 'package:badges/badges.dart' as badges;
import 'package:flutter/services.dart';
import 'package:flutter_image_slideshow/flutter_image_slideshow.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:hashtagable_v3/widgets/hashtag_text.dart';
import 'package:insta_image_viewer/insta_image_viewer.dart';
import 'package:intl/intl.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:page_transition/page_transition.dart';
import 'package:popup_menu/popup_menu.dart';

import 'package:provider/provider.dart';
import 'package:random_color/random_color.dart';
import 'package:share_plus/share_plus.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:stories_for_flutter/stories_for_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../constant/listItemsCarousel.dart';
import '../../constant/textCustom.dart';
import '../../models/chatmodels/message.dart';
import '../../providers/authProvider.dart';
import 'canaux/detailsCanal.dart';
import 'canaux/listCanal.dart';
import 'chat/entrepriseChat.dart';
import 'component/consoleWidget.dart';

class DetailsPost extends StatefulWidget {
  late  Post post;
   DetailsPost({super.key, required this.post});

  @override
  State<DetailsPost> createState() => _DetailsPostState();
}

class _DetailsPostState extends State<DetailsPost> with TickerProviderStateMixin {

  String token='';
  bool dejaVuPub=true;

  GlobalKey btnKey = GlobalKey();
  GlobalKey btnKey2 = GlobalKey();
  GlobalKey btnKey3 = GlobalKey();
  GlobalKey btnKey4 = GlobalKey();
  final _formKey = GlobalKey<FormState>();
  GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late UserAuthProvider authProvider =
  Provider.of<UserAuthProvider>(context, listen: false);
  late UserProvider userProvider =
  Provider.of<UserProvider>(context, listen: false);
  int imageIndex=0;
  late PostProvider postProvider =
  Provider.of<PostProvider>(context, listen: false);
  bool _isLoading=false;

  bool _buttonEnabled=false;
  bool contact_whatsapp=false;
  bool contact_afrolook=false;


  TextEditingController commentController =TextEditingController();
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

  final FirebaseFirestore firestore = FirebaseFirestore.instance;

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


  RandomColor _randomColor = RandomColor();



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
  bool isMyFriend(List<Friends> userfriendList, String userIdToCheck) {
    return userfriendList.any((userAbonne) => userAbonne.friendId == userIdToCheck);
  }
  bool isInvite(List<Invitation> invitationList, String userIdToCheck) {
    return invitationList.any((inv) => inv.receiverId == userIdToCheck);
  }
  Future<void> suivreCanal(Canal canal) async {
      canal.usersSuiviId!.add(authProvider.loginUserData.id!);
      await firestore.collection('Canaux').doc(canal.id).update({
        'usersSuiviId': canal.usersSuiviId,
      });
      setState(() {
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Vous suivez maintenant ce canal.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.green),
          ),
        ),
      );
    }


  void onShow() {
    printVm('Menu is show');
  }
  final List<AnimationController> _heartAnimations = [];
  final List<AnimationController> _giftAnimations = [];
  final List<AnimationController> _giftReplyAnimations = [];

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
                      widget.post.users_republier_id ??= [];
                      widget.post.users_republier_id?.add(userSendCadeau.id!);
                      double gain=0.0;
                      double deduire=0.0;

//
// // Ajouter le gain au solde cadeau
//                       widget.post.user!.votre_solde_cadeau =
//                           (widget.post.user!.votre_solde_cadeau ?? 0.0) + _selectedPrice;

// Ajouter le reste au solde principal
                      userSendCadeau.votre_solde_principal =
                          userSendCadeau.votre_solde_principal! - 2;
                      appdata.solde_gain=appdata.solde_gain!+2;



                      await  postProvider.updateReplyPost(widget.post, context);
                      await authProvider.updateUser(widget.post!.user!).then((value) async {
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
                          widget.post.users_cadeau_id ??= [];
                          widget.post.users_cadeau_id?.add(userSendCadeau.id!);
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
                          widget.post.user!.votre_solde_cadeau =
                              (widget.post.user!.votre_solde_cadeau ?? 0.0) + _selectedPrice;

// Ajouter le reste au solde principal
                          userSendCadeau.votre_solde_principal =
                              userSendCadeau.votre_solde_principal! - deduire;
                          appdata.solde_gain=appdata.solde_gain!+gain;

                          // widget.post.user!.votre_solde_cadeau = (widget.post.user!.votre_solde_cadeau ?? 0.0) + _selectedPrice;
                          // userSendCadeau.votre_solde_principal = userSendCadeau.votre_solde_principal! - (_selectedPrice);

                          NotificationData notif = NotificationData(
                            id: firestore.collection('Notifications').doc().id,
                            titre: "Nouveau Cadeau 🎁",
                            media_url: imageCadeau,
                            type: NotificationType.POST.name,
                            description: "Vous avez un cadeau ${_selectedPrice} PC ${_selectedGift}",
                            user_id: post.user!.id,
                            receiver_id: widget.post!.user_id!,
                            post_id: widget.post!.id!,
                            post_data_type: PostDataType.IMAGE.name!,
                            createdAt: DateTime.now().microsecondsSinceEpoch,
                            updatedAt: DateTime.now().microsecondsSinceEpoch,
                            status: PostStatus.VALIDE.name,
                          );

                          await firestore.collection('Notifications').doc(notif.id).set(notif.toJson());
                          await authProvider.sendNotification(
                              userIds: [widget.post!.user!.oneIgnalUserid!],
                              smallImage:
                              // "${authProvider.loginUserData.imageUrl!}",
                              "${imageCadeau}",
                              send_user_id:
                              "",
                              // "${authProvider.loginUserData.id!}",
                              recever_user_id: "${widget.post!.user_id!}",
                              message:
                              // "📢 @${authProvider.loginUserData
                              //     .pseudo!} a aimé votre look",
                              "Vous avez un cadeau ${_selectedPrice} PC ${_selectedGift}",
                              type_notif:
                              NotificationType.POST.name,
                              post_id: "${widget.post!.id!}",
                              post_type: PostDataType.IMAGE.name,
                              chat_id: '');


                          await  postProvider.updateVuePost(widget.post, context);
                          await authProvider.updateUser(widget.post!.user!).then((value) async {
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
                                '🎁 Félicitations ! Vous avez envoyé un cadeau ${_selectedGift} à @${widget.post!.user!.pseudo}.',
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
    printVm('homePostUser: ${post.description}');

    Random random = Random();
    bool abonneTap =false;
    int like=post!.likes!;
    int imageIndex=0;
    int love=post!.loves!;
    int vue=post!.vues!;
    int comments=post!.comments!;
    bool tapLove=isIn(post.users_love_id!,authProvider.loginUserData.id!);
    bool tapLike=isIn(post.users_like_id!,authProvider.loginUserData.id!);
    List<int> likes =[];
    List<int> loves =[];



    return Stack(
      children: [
        Container(
          child:
          StatefulBuilder(
              builder: (BuildContext context, StateSetter setStateImages) {
                return Padding(
                  padding: const EdgeInsets.all(5.0),
                  child: Column(
                    children: [
                      post.canal!=null?GestureDetector(
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => CanalListPage(isUserCanals: false,),));
                          Navigator.push(context, MaterialPageRoute(builder: (context) => CanalDetails(canal: post.canal!),));

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
                                        '${post.canal!.urlImage!}'),
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
                                          width: 100,
                                          child: TextCustomerUserTitle(
                                            titre: "#${post.canal!.titre!}",
                                            fontSize: SizeText.homeProfileTextSize,
                                            couleur: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        TextCustomerUserTitle(
                                          titre: "${formatNumber(post.canal!.usersSuiviId!.length)} abonné(s)",
                                          fontSize: SizeText.homeProfileTextSize,
                                          couleur: Colors.white,
                                          fontWeight: FontWeight.w400,
                                        ),
                                        // TextCustomerUserTitle(
                                        //   titre: "${formatNumber(post.user!.userlikes!)} like(s)",
                                        //   fontSize: SizeText.homeProfileTextSize,
                                        //   couleur: Colors.green,
                                        //   fontWeight: FontWeight.w700,
                                        // ),

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
                            Visibility(
                              visible: post.canal!.isVerify!,
                              child: Card(
                                child: const Icon(
                                  Icons.verified,
                                  color: Colors.blue,
                                  size: 20,
                                ),
                              ),
                            ),
                            Container(
                              child: post.canal!.usersSuiviId!.contains(authProvider.loginUserData.id)
                                  ? null
                                  : TextButton(
                                onPressed: () {
                                  suivreCanal(post.canal!);
                                },
                                style: ElevatedButton.styleFrom(

                                  backgroundColor: Colors.green, // Background color
                                  // onPrimary: Colors.white, // Text color
                                ),
                                child: Text('Suivre', style: TextStyle(color: Colors.white)),
                              ),
                            ),
                            ElevatedButton(onPressed: () {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => CanalListPage(isUserCanals: false,),));
                              // Navigator.push(context, MaterialPageRoute(builder: (context) => CanalDetails(canal: post.canal!),));

                            }, child: Text('Voir plus',style: TextStyle(color: Colors.green),))
                            // IconButton(
                            //     onPressed: () {
                            //       _showModalDialog(post);
                            //     },
                            //     icon: Icon(
                            //       Icons.more_horiz,
                            //       size: 30,
                            //       color: ConstColors.blackIconColors,
                            //     )),
                          ],
                        ),
                      ): Row(
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
                                          couleur: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      TextCustomerUserTitle(
                                        titre: "${formatNumber(post.user!.abonnes!)} abonné(s)",
                                        fontSize: SizeText.homeProfileTextSize,
                                        couleur: Colors.white,
                                        fontWeight: FontWeight.w400,
                                      ),
                                      TextCustomerUserTitle(
                                        titre: "${formatNumber(post.user!.userlikes!)} like(s)",
                                        fontSize: SizeText.homeProfileTextSize,
                                        couleur: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),

                                    ],
                                  ),

                                ],
                              ),

                            ],
                          ),
                          // IconButton(
                          //     onPressed: () {
                          //       _showModalDialog(post);
                          //     },
                          //     icon: Icon(
                          //       Icons.more_horiz,
                          //       size: 30,
                          //       color: ConstColors.blackIconColors,
                          //     )),
                        ],
                      ),
                      Visibility(
                          visible: post.type==PostType.PUB.name,
                          child: Row(
                            children: [
                              Icon(Icons.public,color: Colors.green,),
                              Text("Publicité",style: TextStyle(fontSize: 12,fontWeight: FontWeight.w900),),
                            ],
                          )
                      ),

                      SizedBox(
                        height: 5,
                      ),
                      Visibility(
                        visible: post.dataType!=PostDataType.TEXT.name?true:false,
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: SizedBox(
                            width: width*0.8,
                            // height: 50,
                            child: Container(
                              alignment: Alignment.centerLeft,
                              child: Column(
                                children: [
                                  Visibility(
                                      visible: post.type==PostType.PUB.name,
                                      child: TextButton(onPressed: () async {
                                        if (!await launchUrl(Uri.parse('${post.urlLink}'))) {
                                          throw Exception('Could not launch ${'${post.urlLink}'}');
                                        }

                                      }, child: Text('${post.urlLink}',style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.green,
                                        fontWeight: FontWeight.normal,
                                        fontFamily: 'Nunito', // Définir la police Nunito
                                      ),))),
              post.isPostLink=="OUI"?  Linkify(
                onOpen: (link) async {
                if (!await launchUrl(Uri.parse(link.url))) {
                throw Exception('Could not launch ${link.url}');
                }
                },
                text: "${post.description}",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,

                  color: Colors.white,
                  fontFamily: 'Nunito', // Définir la police Nunito
                ),
                linkStyle: TextStyle(color: Colors.blue.shade300,
                  shadows: [
                    Shadow(
                      color: Colors.black.withOpacity(0.5), // Couleur de l'ombre
                      offset: Offset(1, 1), // Décalage de l'ombre (horizontal, vertical)
                      blurRadius: 2, // Flou de l'ombre
                    ),
                  ],
                ),
                ):
                                  HashTagText(
                                    text: "${post.description}",
                                    decoratedStyle: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,

                                      color: Colors.black,
                                      fontFamily: 'Nunito', // Définir la police Nunito
                                    ),
                                    basicStyle: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white,
                                      fontWeight: FontWeight.normal,
                                      fontFamily: 'Nunito', // Définir la police Nunito
                                    ),
                                    textAlign: TextAlign.left, // Centrage du texte
                                    maxLines: null, // Permet d'afficher le texte sur plusieurs lignes si nécessaire
                                    softWrap: true, // Assure que le texte se découpe sur plusieurs lignes si nécessaire
                                    // overflow: TextOverflow.ellipsis, // Ajoute une ellipse si le texte dépasse
                                    onTap: (text) {
                                      print(text);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 5,
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: TextCustomerPostDescription(
                                titre:
                                "${formaterDateTime(DateTime.fromMicrosecondsSinceEpoch(post!.createdAt!))}",
                                fontSize: SizeText.homeProfileDateTextSize,
                                couleur: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Card(

                                child: Padding(
                                  padding: const EdgeInsets.all(5.0),
                                  child: TextCustomerPostDescription(
                                    titre:
                                    "Vues ${post!.vues}",
                                    fontSize: SizeText.homeProfileDateTextSize,
                                    couleur: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                color: Colors.black12,
                              ),
                            ),
                          ),

                        ],
                      ),

                      // Padding(
                      //   padding: const EdgeInsets.only(bottom: 8.0),
                      //   child: Align(
                      //     alignment: Alignment.centerLeft,
                      //     child: TextCustomerPostDescription(
                      //       titre: "${formaterDateTime(DateTime.fromMicrosecondsSinceEpoch(post.createdAt!))}",
                      //       fontSize: SizeText.homeProfileDateTextSize,
                      //       couleur: Colors.white,
                      //       fontWeight: FontWeight.bold,
                      //     ),
                      //   ),
                      // ),
                      Visibility(
                        visible: post.dataType==PostDataType.TEXT.name?true:false,

                        child: Container(
                          color: Colors.brown,
                          child: Align(
                            alignment: Alignment.center,
                            child: SizedBox(
                              width: width*0.8,
                              // height: 50,
                              child: Container(
                                // height: 200,
                                constraints: BoxConstraints(
                                  // minHeight: 100.0, // Set your minimum height
                                  // maxHeight: height*0.6, // Set your maximum height
                                ),                          alignment: Alignment.center,
                                child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child:HashTagText(
                                      text: "${post.description}",
                                      decoratedStyle: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,

                                        color: Colors.green,
                                        fontFamily: 'Nunito', // Définir la police Nunito
                                      ),
                                      basicStyle: TextStyle(
                                        fontSize: 15,
                                        color: Colors.white,
                                        fontWeight: FontWeight.normal,
                                        fontFamily: 'Nunito', // Définir la police Nunito
                                      ),
                                      textAlign: TextAlign.center, // Centrage du texte
                                      maxLines: null, // Permet d'afficher le texte sur plusieurs lignes si nécessaire
                                      softWrap: true, // Assure que le texte se découpe sur plusieurs lignes si nécessaire
                                      // overflow: TextOverflow.ellipsis, // Ajoute une ellipse si le texte dépasse
                                      onTap: (text) {
                                        print(text);
                                      },
                                    ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 5,
                      ),


                      Visibility(
                        visible: post.dataType!=PostDataType.TEXT.name?true:false,

                        child: GestureDetector(
                          onTap: () {
                           // Navigator.push(context, MaterialPageRoute(builder: (context) => DetailsPost(post: post),));
                          },

                          child: Container(
                            //width: w*0.9,
                            //height: h*0.5,

                            child: ClipRRect(
                              borderRadius: BorderRadius.all(Radius.circular(5)),
                              child: Container(


                                child: ImageSlideshow(

                                  width: w,
                                  height: h*0.5,

                                  /// The page to show when first creating the [ImageSlideshow].
                                  initialPage: 0,


                                  /// The color to paint the indicator.
                                  indicatorColor: Colors.green,

                                  /// The color to paint behind th indicator.
                                  indicatorBackgroundColor: Colors.grey,

                                  /// Called whenever the page in the center of the viewport changes.
                                  onPageChanged: (value) {
                                    print('Page changed: $value');
                                  },

                                  /// Auto scroll interval.
                                  /// Do not auto scroll with null or 0.
                                  // autoPlayInterval: 9000,


                                  /// Loops back to first slide.
                                  isLoop: true,

                                  /// The widgets to display in the [ImageSlideshow].
                                  /// Add the sample image file into the images folder
                                  children: post!.images!.map((e) =>     InstaImageViewer(
                                    child:CachedNetworkImage(

                                      fit: BoxFit.contain,

                                      imageUrl: '$e',
                                      progressIndicatorBuilder: (context, url, downloadProgress) =>
                                      //  LinearProgressIndicator(),

                                      Skeletonizer(
                                          child: SizedBox(

                                              width: w * 0.9,
                                              height: h * 0.4,
                                              child:  ClipRRect(
                                                  borderRadius: BorderRadius.all(Radius.circular(10)),child: Image.asset('assets/images/404.png')))),
                                      errorWidget: (context, url, error) =>  Skeletonizer(child: Container(
                                          width: w * 0.9,
                                          height: h * 0.4,
                                          child: Image.asset("assets/images/404.png",fit: BoxFit.cover,))),
                                    ),
                                  ),).toList(),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),



                      SizedBox(
                        height: 10,
                      ),
                      Container(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              // crossAxisAlignment: CrossAxisAlignment.center,
                              // mainAxisSize: MainAxisSize.max,
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    // color: Colors.white,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.3), // Couleur de l'ombre
                                        spreadRadius: 2, // Étendue de l'ombre
                                        blurRadius: 30,  // Flou de l'ombre
                                        offset: Offset(4, 4), // Décalage en x et y
                                      ),
                                    ],
                                    borderRadius: BorderRadius.circular(10), // Facultatif : coins arrondis
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(5.0),
                                    child: StatefulBuilder(builder:
                                        (BuildContext context, StateSetter setState) {
                                      return GestureDetector(
                                        onTap: () {
                                          // _sendGift('🎁');
                                          postProvider.getPostsImagesById(widget.post.id!).then((value) async {
                                            if(value.isNotEmpty){
                                              widget.post=value.first;
                                              await authProvider.getAppData();
                                              showRepublishDialog(widget.post,authProvider.loginUserData,authProvider.appDefaultData,context);

                                            }
                                          },);


                                        },

                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Feather.repeat,
                                              size: 28,
                                              color: Colors.white,
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                  left: 1.0, right: 1),
                                              child: TextCustomerPostDescription(
                                                titre: "${formatAbonnes(widget.post!.users_republier_id==null?0:widget.post!.users_republier_id!.length!)}",
                                                fontSize: 14,
                                                couleur: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                  ),
                                )
                                ,


                                Container(
                                  decoration: BoxDecoration(
                                    // color: Colors.white,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.3), // Couleur de l'ombre
                                        spreadRadius: 2, // Étendue de l'ombre
                                        blurRadius: 30,  // Flou de l'ombre
                                        offset: Offset(4, 4), // Décalage en x et y
                                      ),
                                    ],
                                    borderRadius: BorderRadius.circular(10), // Facultatif : coins arrondis
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(5.0),
                                    child:  StatefulBuilder(builder:
                                        (BuildContext context, StateSetter setState) {
                                      return GestureDetector(
                                        onTap: () async {
                                          postProvider.getPostsImagesById(widget.post.id!).then((value) async {
                                            if(value.isNotEmpty){
                                              widget.post=value.first;
                                              await authProvider.getAppData();
                                              showGiftDialog(widget.post,authProvider.loginUserData,authProvider.appDefaultData);

                                            }
                                          },);

                                        },
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          mainAxisAlignment: MainAxisAlignment.center,
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

                                            Text('🎁',style: TextStyle(fontSize: 28),),
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                  left: 1.0, right: 1),
                                              child: TextCustomerPostDescription(
                                                titre: "${formatAbonnes(widget.post!.users_cadeau_id==null?0:widget.post!.users_cadeau_id!.length!)}",
                                                fontSize: 14,
                                                couleur: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                  ),
                                )
                                ,

                                Container(
                                  decoration: BoxDecoration(
                                    // color: Colors.white,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.3), // Couleur de l'ombre
                                        spreadRadius: 2, // Étendue de l'ombre
                                        blurRadius: 30,  // Flou de l'ombre
                                        offset: Offset(4, 4), // Décalage en x et y
                                      ),
                                    ],
                                    borderRadius: BorderRadius.circular(10), // Facultatif : coins arrondis
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(5.0),
                                    child: StatefulBuilder(builder:
                                        (BuildContext context, StateSetter setState) {
                                      return GestureDetector(
                                        onTap: () async {
                                          _sendLike();
                                          postProvider.getPostsImagesById(widget.post!.id!).then((value) async {
                                            if(value.isNotEmpty){
                                              widget.post!=value.first;
                                              if (!isIn(widget.post!.users_love_id!,
                                                  authProvider.loginUserData.id!)) {
                                                setState(() {
                                                  widget.post!.loves = widget.post!.loves! + 1;

                                                  widget.post!.users_love_id!
                                                      .add(authProvider!.loginUserData.id!);
                                                  love = widget.post!.loves!;
                                                  //loves.add(idUser);
                                                });
                                                printVm("share post");
                                                printVm("like poste monetisation 1 .....");
                                                postProvider.interactWithPostAndIncrementSolde(widget.post!.id!, authProvider.loginUserData.id!, "like",widget.post!.user_id!);

                                                CollectionReference userCollect =
                                                FirebaseFirestore.instance
                                                    .collection('Users');
                                                // Get docs from collection reference
                                                QuerySnapshot querySnapshotUser =
                                                    await userCollect
                                                    .where("id",
                                                    isEqualTo: widget.post!.user_id!)
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
                                                  if (widget.post!.user!.oneIgnalUserid != null &&
                                                      widget.post!.user!.oneIgnalUserid!.length > 5) {


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
                                                    notif.receiver_id = widget.post!.user_id!;
                                                    notif.post_id = widget.post!.id!;
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
                                                    await authProvider.sendNotification(
                                                        userIds: [widget.post!.user!.oneIgnalUserid!],
                                                        smallImage:
                                                        "${authProvider.loginUserData.imageUrl!}",
                                                        send_user_id:
                                                        "${authProvider.loginUserData.id!}",
                                                        recever_user_id: "${widget.post!.user_id!}",
                                                        message:
                                                        "📢 @${authProvider.loginUserData.pseudo!} a aimé votre look",
                                                        type_notif:
                                                        NotificationType.POST.name,
                                                        post_id: "${widget.post!.id!}",
                                                        post_type: PostDataType.IMAGE.name,
                                                        chat_id: '');
                                                  }
                                                  // postProvider.updateVuePost(post, context);

                                                  //userProvider.updateUser(listUsers.first);
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
                                                      widget.post, listUsers.first, context);
                                                  await authProvider.getAppData();
                                                  authProvider.appDefaultData.nbr_loves =
                                                      authProvider.appDefaultData.nbr_loves! +
                                                          2;
                                                  authProvider.updateAppData(
                                                      authProvider.appDefaultData);
                                                } else {
                                                  widget.post!.user!.jaimes = widget.post!.user!.jaimes! + 1;
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
                                                      widget.post, widget.post!.user!, context);
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
                                            }
                                          },);

                                          // setState(() {
                                          // });
                                        },
                                        child: Center(
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.center,
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [

                                              Icon(
                                                isIn(
                                                    widget.post!.users_love_id!,
                                                    authProvider
                                                        .loginUserData.id!)
                                                    ? Ionicons.heart
                                                    : Ionicons.heart,
                                                color: isIn(
                                                    widget.post!.users_love_id!,
                                                    authProvider
                                                        .loginUserData.id!)
                                                    ? Colors.red:Colors.white,
                                                size: 28,
                                                // color: ConstColors.likeColors,
                                              ),
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                    left: 1.0, right: 1),
                                                child: TextCustomerPostDescription(
                                                  titre: "${formatAbonnes(love)}",
                                                  fontSize: 14,
                                                  couleur: Colors.white,

                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }),
                                  ),
                                )

                                ,

                                Container(
                                  decoration: BoxDecoration(
                                    // color: Colors.white,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.3), // Couleur de l'ombre
                                        spreadRadius: 2, // Étendue de l'ombre
                                        blurRadius: 30,  // Flou de l'ombre
                                        offset: Offset(4, 4), // Décalage en x et y
                                      ),
                                    ],
                                    borderRadius: BorderRadius.circular(10), // Facultatif : coins arrondis
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(5.0),
                                    child:  StatefulBuilder(builder:
                                        (BuildContext context, StateSetter setState) {
                                      return GestureDetector(
                                        onTap: () {
                                          Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    PostComments(post: widget.post),
                                              ));

                                          //sheetComments(height*0.7,width,post);
                                        },
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              FontAwesome.comments,
                                              size: 28,
                                              color: Colors.white,
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                  left: 1.0, right: 1),
                                              child: TextCustomerPostDescription(
                                                titre: "${formatAbonnes(comments)}",
                                                fontSize: 14,
                                                couleur: Colors.white,

                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                  ),
                                ),


                                Container(
                                  decoration: BoxDecoration(
                                    // color: Colors.white,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.3), // Couleur de l'ombre
                                        spreadRadius: 2, // Étendue de l'ombre
                                        blurRadius: 30,  // Flou de l'ombre
                                        offset: Offset(4, 4), // Décalage en x et y
                                      ),
                                    ],
                                    borderRadius: BorderRadius.circular(10), // Facultatif : coins arrondis
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(5.0),
                                    child:  StatefulBuilder(builder:
                                        (BuildContext context, StateSetter setState) {
                                      return GestureDetector(
                                        onTap: () async {
                                          printVm("share post");
                                          printVm("like poste monetisation 1 .....");
                                          postProvider.interactWithPostAndIncrementSolde(widget.post!.id!, authProvider.loginUserData.id!, "share",widget.post!.user_id!);

                                          // await authProvider.createLink(post).then((value) {
                                          final box = context.findRenderObject() as RenderBox?;

                                          await authProvider.createLink(true,widget.post).then((url) async {
                                            await Share.shareUri(
                                              Uri.parse(
                                                  '${url}'),
                                              sharePositionOrigin:
                                              box!.localToGlobal(Offset.zero) & box.size,
                                            );


                                            setState(() {
                                              widget.post!.partage = widget.post!.partage! + 1;

                                              // widget.post!.users_love_id!
                                              //     .add(authProvider!.loginUserData.id!);
                                              // love = widget.post!.loves!;
                                              // //loves.add(idUser);
                                            });
                                            CollectionReference userCollect =
                                            FirebaseFirestore.instance
                                                .collection('Users');
                                            // Get docs from collection reference
                                            QuerySnapshot querySnapshotUser =
                                            await userCollect
                                                .where("id",
                                                isEqualTo: widget.post!.user_id!)
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
                                              if (widget.post!.user!.oneIgnalUserid != null &&
                                                  widget.post!.user!.oneIgnalUserid!.length > 5) {


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
                                                notif.receiver_id = widget.post!.user_id!;
                                                notif.post_id = widget.post!.id!;
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
                                                await authProvider.sendNotification(
                                                    userIds: [widget.post!.user!.oneIgnalUserid!],
                                                    smallImage:
                                                    "${authProvider.loginUserData.imageUrl!}",
                                                    send_user_id:
                                                    "${authProvider.loginUserData.id!}",
                                                    recever_user_id: "${widget.post!.user_id!}",
                                                    message:
                                                    "📢 @${authProvider.loginUserData.pseudo!} a partagé votre look",
                                                    type_notif:
                                                    NotificationType.POST.name,
                                                    post_id: "${widget.post!.id!}",
                                                    post_type: PostDataType.IMAGE.name,
                                                    chat_id: '');
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
                                                  widget.post, listUsers.first, context);
                                              // await authProvider.getAppData();
                                              // authProvider.appDefaultData.nbr_loves =
                                              //     authProvider.appDefaultData.nbr_loves! +
                                              //         2;
                                              // authProvider.updateAppData(
                                              //     authProvider.appDefaultData);


                                              tapLove = true;
                                            }

                                          },);
                                        },
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          mainAxisAlignment: MainAxisAlignment.center,
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

                                            Icon(
                                              isIn(
                                                  widget.post!.users_partage_id!,
                                                  authProvider
                                                      .loginUserData.id!)
                                                  ? Icons.share
                                                  : Icons.share,
                                              color: isIn(
                                                  widget.post!.users_partage_id!,
                                                  authProvider
                                                      .loginUserData.id!)
                                                  ?Colors.red: Colors.white,
                                              size: 28,
                                              // color: ConstColors.likeColors,
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                  left: 1.0, right: 1),
                                              child: TextCustomerPostDescription(
                                                titre: "${formatAbonnes(widget.post!.partage!)}",
                                                fontSize: 14,
                                                couleur: Colors.white,

                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                  ),
                                )


                              ],
                            ),
                          ),
                        ),
                      ),


                      SizedBox(
                        height: 10,
                      ),


                    ],
                  ),
                );
              }
          ),
        ),

        Positioned.fill(
          child: Center(
            child: Stack(
              children: [
                ..._heartAnimations.map((controller) => HeartAnimation(controller: controller)),
                ..._giftAnimations.map((controller) => GiftAnimation(controller: controller)),
                ..._giftReplyAnimations.map((controller) => GiftReplyAnimation(controller: controller)),
              ],
            ),
          ),
        ),
      ],
    );
  }
  Color mixColors(Color color1, Color color2, double factor) {
    return Color.lerp(color1, color2, factor)!;
  }
  Color colorFromHex(String? hexString) {
    if (hexString == null) return Colors.transparent;
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

@override
  void initState() {
    // TODO: implement initState
    super.initState();
    if (widget.post?.id != null) {
      postProvider.getPostsImagesById(widget.post!.id!).then((value) {
        if (value.isNotEmpty) {
          final updatedPost = value.first;
          if (authProvider.loginUserData.role ==
              UserRole.ADM.name){
            if (updatedPost.vues != null) {
              updatedPost.vues = (updatedPost.vues ?? 0) + genererNombreAleatoire();
            }
          }
          if (updatedPost.vues != null) {
            updatedPost.vues = (updatedPost.vues ?? 0) + 1;
          }

          if (updatedPost.user != null) {
            postProvider.updatePost(updatedPost, updatedPost.user!, context);
          }
        }
      });
    }

}

  @override
  void dispose() {
    for (var controller in _heartAnimations) {
      controller.dispose();
    }
    for (var controller in _giftAnimations) {
      controller.dispose();
    }
    for (var controller in _giftReplyAnimations) {
      controller.dispose();
    }
    super.dispose();
  }




  @override
  Widget build(BuildContext context) {
    Color blendedColor = mixColors(colorFromHex( widget.post.colorDomine), colorFromHex( widget.post.colorSecondaire), 0.5);

    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;
    return  Scaffold(

        appBar: AppBar(
          actions: [
           Padding(
             padding: const EdgeInsets.only(right: 8.0),
             child: Logo(),
           ),

          ],
        ),

        body: SingleChildScrollView(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  // Colors.green, // Vert pur en bas
                  // Colors.green.withOpacity(0.5), // Vert plus clair au milieu
                  // Colors.green.withOpacity(0.1),
                  widget.post.colorDomine==null?HSLColor.fromColor( Colors.green.shade300).withLightness(0.4).toColor(): HSLColor.fromColor(blendedColor).withLightness(0.4).toColor(),
                  widget.post.colorDomine==null?HSLColor.fromColor( Colors.green.shade300).withLightness(0.6).toColor():  HSLColor.fromColor(blendedColor).withLightness(0.6).toColor(), // Plus foncé

                  // widget.post.colorSecondaire==null?Colors.green: colorFromHex(widget.post.colorSecondaire),
                  //
                  // widget.post.colorDomine==null?Colors.black38: colorFromHex( widget.post.colorDomine),
                ],
                stops: [0.2, 0.8],
              ),
            ),

            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
              children: <Widget>[
                homePostUsers(widget.post, height, width),
              ]
                    ),
            ),
          ),
        ),
    );
  }
}
