import 'dart:math';

import 'package:afrotok/pages/user/monetisation.dart';
import 'package:afrotok/pages/userPosts/postWidgets/postCadeau.dart';
import 'package:afrotok/pages/userPosts/postWidgets/postUserWidget.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_slideshow/flutter_image_slideshow.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:hashtagable_v3/widgets/hashtag_text.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../models/model_data.dart';
import '../../../constant/constColors.dart';
import '../../../constant/sizeText.dart';
import '../../../constant/textCustom.dart';
import '../../../models/model_data.dart';
import '../../postComments.dart';
import '../../../providers/afroshop/categorie_produits_provider.dart';
import '../../../providers/authProvider.dart';
import '../../../providers/postProvider.dart';
import '../../../providers/userProvider.dart';
import '../../canaux/detailsCanal.dart';
import '../../canaux/listCanal.dart';
import '../../component/consoleWidget.dart';
import '../../component/showUserDetails.dart';
import '../../postComments.dart';
import '../../postDetails.dart';
import '../../socialVideos/afrovideos/afrovideo.dart';
// Ajoutez vos autres imports nécessaires ici

class HomePostUsersWidget extends StatefulWidget {
  late Post post;
  late Color? color;
  final double height;
  final double width;

   HomePostUsersWidget({
    required this.post,
     this.color,
    required this.height,
    required this.width,
    Key? key,
  }) : super(key: key);

  @override
  _HomePostUsersWidgetState createState() => _HomePostUsersWidgetState();
}

class _HomePostUsersWidgetState extends State<HomePostUsersWidget>
    with TickerProviderStateMixin {
  late UserAuthProvider authProvider =Provider.of<UserAuthProvider>(context, listen: false);
  late PostProvider postProvider=Provider.of<PostProvider>(context, listen: false);
  late CategorieProduitProvider categorieProduitProvider =Provider.of<CategorieProduitProvider>(context, listen: false);
  late UserProvider userProvider=Provider.of<UserProvider>(context, listen: false);
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  Random random = Random();
  bool abonneTap = false;
  late int like;
  int imageIndex = 0;
  late int love;
  late int vue;
  late int comments;
  late bool tapLove;
  late bool tapLike;
  List<int> likes = [];
  List<int> loves = [];
  int idUser = 7;
  double baseFontSize = 20.0;
  late double fontSize;
  int limitePosts = 30;
  bool _isLoading=false;

  final List<AnimationController> _heartAnimations = [];
  final List<AnimationController> _giftAnimations = [];
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




  @override
  void initState() {
    super.initState();
    initializePostData();
  }

  void initializePostData() {
    like = widget.post!.likes!;
    love = widget.post!.loves!;
    vue = widget.post!.vues!;
    comments = widget.post!.comments!;
    tapLove = isIn(widget.post!.users_love_id!, authProvider.loginUserData.id!);
    tapLike = isIn(widget.post!.users_like_id!, authProvider.loginUserData.id!);

    double scale = widget.post!.description!.length / 1000;
    fontSize = baseFontSize - scale;
    fontSize = fontSize < 15 ? 15 : fontSize;
  }
  String truncateWords(String text, int maxWords) {
    List<String> words = text.split(' ');
    return (words.length > maxWords) ? '${words.sublist(0, maxWords).join(' ')}...' : text;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    postProvider = Provider.of<PostProvider>(context, listen: false);
    categorieProduitProvider = Provider.of<CategorieProduitProvider>(context, listen: false);
    userProvider = Provider.of<UserProvider>(context, listen: false);
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

  Future<void> suivreCanal(Canal canal) async {
    final String userId = authProvider.loginUserData.id!;

    // Vérifier si l'utilisateur suit déjà le canal
    if (canal.usersSuiviId!.contains(userId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Vous suivez déjà ce canal.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.orange),
          ),
        ),
      );
      return;
    }

    // Ajouter l'utilisateur à la liste des abonnés
    canal.usersSuiviId!.add(userId);
    await firestore.collection('Canaux').doc(canal.id).update({
      'usersSuiviId': canal.usersSuiviId,
    });

    // setState(() {
    //   isFollowing = true;
    // });

    // Création de la notification
    NotificationData notif = NotificationData(
      id: firestore.collection('Notifications').doc().id,
      titre: "Canal 📺",
      media_url: authProvider.loginUserData.imageUrl,
      type: NotificationType.ACCEPTINVITATION.name,
      description:
      "@${authProvider.loginUserData.pseudo!} suit votre canal #${canal.titre!} 📺!",
      users_id_view: [],
      user_id: userId,
      receiver_id: canal.userId!,
      post_id: "",
      post_data_type: "",
      updatedAt: DateTime.now().microsecondsSinceEpoch,
      createdAt: DateTime.now().microsecondsSinceEpoch,
      status: PostStatus.VALIDE.name,
    );

    await firestore.collection('Notifications').doc(notif.id).set(notif.toJson());

    // Envoi de la notification
    await authProvider.sendNotification(
      userIds: [canal.user!.oneIgnalUserid!],
      smallImage: canal.urlImage!,
      send_user_id: userId,
      recever_user_id: canal.userId!,
      message:
      "📢📺 @${authProvider.loginUserData.pseudo!} suit votre canal #${canal.titre!} 📺!",
      type_notif: NotificationType.ACCEPTINVITATION.name,
      post_id: "",
      post_type: "",
      chat_id: "",
    );

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

  @override
  Widget build(BuildContext context) {
    double h = MediaQuery.of(context).size.height;
    double w = MediaQuery.of(context).size.width;

    return Padding(
      padding: const EdgeInsets.all(5.0),
      child: Stack(
        children: [
          Column(
            children: [
              widget.post!.canal!=null?Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child:  Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Text("#Afrolook Canal",style: TextStyle(fontSize: 15,fontWeight: FontWeight.w900),),
                  ],
                ),
              ):SizedBox.shrink(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      widget.post!.canal!=null?Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child:  GestureDetector(
                          onTap: () async {
                            // await  authProvider.getUserById(widget.post!.user_id!).then((users) async {
                            //   if(users.isNotEmpty){
                            //     showUserDetailsModalDialog(users.first, w, h,context);
                            //
                            //   }
                            // },);
                            Navigator.push(context, MaterialPageRoute(builder: (context) => CanalListPage(isUserCanals: false,),));
                            Navigator.push(context, MaterialPageRoute(builder: (context) => CanalDetails(canal: widget.post!.canal!),));


                          },
                          child:
                          CircleAvatar(

                            backgroundImage:
                            NetworkImage('${widget.post!.canal!.urlImage!}'),
                          ),
                        ),
                      ): Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child:  GestureDetector(
                          onTap: () async {
                            await  authProvider.getUserById(widget.post!.user_id!).then((users) async {
                              if(users.isNotEmpty){
                                showUserDetailsModalDialog(users.first, w, h,context);

                              }
                            },);

                          },
                          child:
                          CircleAvatar(

                            backgroundImage:
                            NetworkImage('${widget.post!.user!.imageUrl!}'),
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 2,
                      ),

                      Container(
                        child:widget.post!.canal!=null?   Row(
                          spacing: 5,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  //width: 100,
                                  child: TextCustomerUserTitle(
                                    titre: "#${widget.post!.canal!.titre!}",
                                    fontSize: SizeText.homeProfileTextSize,
                                    couleur: ConstColors.textColors,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Row(
                                  children: [
                                    Column(
                                      children: [

                                        TextCustomerUserTitle(
                                          titre:
                                          "${formatNumber(widget.post!.canal!.usersSuiviId!.length)} abonné(s)",
                                          fontSize: SizeText.homeProfileTextSize,
                                          couleur: ConstColors.textColors,
                                          fontWeight: FontWeight.w400,
                                        ),

                                      ],
                                    ),
                                    // countryFlag(widget.post!.user!.countryData!['countryCode']??"Tg"!, size: 15),

                                  ],
                                ),
                              ],
                            ),

                            Visibility(
                              visible: widget.post!.canal!.isVerify!,
                              child: Card(
                                child: const Icon(
                                  Icons.verified,
                                  color: Colors.blue,
                                  size: 20,
                                ),
                              ),
                            ),
                            Container(
                              child: widget.post!.canal!.usersSuiviId!.contains(authProvider.loginUserData.id)
                                  ? null
                                  : TextButton(
                                onPressed: () {
                                  suivreCanal(widget.post!.canal!);
                                },
                                style: ElevatedButton.styleFrom(

                                  backgroundColor: Colors.green, // Background color
                                  // onPrimary: Colors.white, // Text color
                                ),
                                child: Text('Suivre', style: TextStyle(color: Colors.white)),
                              ),
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
                        ): Row(
                          spacing: 5,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  //width: 100,
                                  child: TextCustomerUserTitle(
                                    titre: "@${widget.post!.user!.pseudo!}",
                                    fontSize: SizeText.homeProfileTextSize,
                                    couleur: ConstColors.textColors,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Row(
                                  children: [
                                    Column(
                                      children: [
                                        TextCustomerUserTitle(
                                          titre:
                                          "${formatNumber(widget.post!.user!.userlikes!)} like(s)",
                                          fontSize: SizeText.homeProfileTextSize,
                                          couleur: Colors.green,
                                          fontWeight: FontWeight.w700,
                                        ),

                                        TextCustomerUserTitle(
                                          titre:
                                          "${formatNumber(widget.post!.user!.userAbonnesIds!.length)} abonné(s)",
                                          fontSize: SizeText.homeProfileTextSize,
                                          couleur: ConstColors.textColors,
                                          fontWeight: FontWeight.w400,
                                        ),

                                      ],
                                    ),
                                    // countryFlag(widget.post!.user!.countryData!['countryCode']??"Tg"!, size: 15),

                                  ],
                                ),
                              ],
                            ),

                            Visibility(
                              visible: widget.post!.user!.isVerify!,
                              child: Card(
                                child: const Icon(
                                  Icons.verified,
                                  color: Colors.green,
                                  size: 20,
                                ),
                              ),
                            ),
                            Visibility(
                              visible:authProvider.loginUserData.id!=widget.post!.user!.id ,

                              child: StatefulBuilder(builder: (BuildContext context,
                                  void Function(void Function()) setState) {
                                return Container(
                                  child: isUserAbonne(
                                      widget.post!.user!.userAbonnesIds!,
                                      authProvider.loginUserData.id!)
                                      ? Container()
                                      : TextButton(
                                      onPressed: abonneTap
                                          ? () {}
                                          : () async {
                                        setState(() {
                                          abonneTap=true;
                                        });
                                        await authProvider.abonner(widget.post!.user!,context).then((value) {

                                        },);
                                        setState(() {
                                          abonneTap=false;
                                        });
                                      },
                                      child: abonneTap
                                          ? Center(
                                        child:
                                        LoadingAnimationWidget
                                            .flickr(
                                          size: 20,
                                          leftDotColor:
                                          Colors.green,
                                          rightDotColor:
                                          Colors.black,
                                        ),
                                      )
                                          : Text(
                                        "S'abonner",
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight:
                                            FontWeight.normal,
                                            color: Colors.blue),
                                      )),
                                );
                              }),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 10,),



                    ],
                  ),
                  IconButton(
                      onPressed: () {
                        showPostMenuModalDialog(widget.post!,context);
                      },
                      icon: Icon(
                        Icons.more_horiz,
                        size: 30,
                        color: ConstColors.blackIconColors,
                      )),
                ],
              ),
              Visibility(
                  visible: widget.post!.type==PostType.PUB.name,
                  child: Row(
                    children: [
                      Icon(Icons.public,color: Colors.green,),
                      Text(" Publicité",style: TextStyle(fontSize: 12,fontWeight: FontWeight.w900),),
                    ],
                  )
              ),

              SizedBox(
                height: 5,
              ),
              Visibility(
                visible: widget.post!.dataType != PostDataType.TEXT.name
                    ? true
                    : false,
                child: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    // width:widget.post!.type==PostType.PUB.name?w*0.82: w * 0.8,
                    child: Container(
                      alignment: Alignment.centerLeft,
                      child:SingleChildScrollView(
                        child: Column(
                          children: [
                            Visibility(
                                visible: widget.post!.type==PostType.PUB.name,
                                child: TextButton(onPressed: () async {
                                  if (!await launchUrl(Uri.parse('${widget.post!.urlLink}'))) {
                                    throw Exception('Could not launch ${'${widget.post!.urlLink}'}');
                                  }

                                }, child: Text('${widget.post!.urlLink}',style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green,
                                  fontWeight: FontWeight.normal,
                                  fontFamily: 'Nunito', // Définir la police Nunito
                                ),))),
                            HashTagText(
                              text: truncateWords( widget.post!.description ?? "", 20),
                              decoratedStyle: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,

                                color: Colors.green,
                                fontFamily: 'Nunito', // Définir la police Nunito
                              ),
                              basicStyle: TextStyle(
                                fontSize: 12,
                                color: Colors.black87,
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
                      // TextCustomerPostDescription(
                      //   titre: "${widget.post!.description}",
                      //   fontSize: fontSize,
                      //   couleur: ConstColors.textColors,
                      //   fontWeight: FontWeight.normal,
                      // ),
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: 5,
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextCustomerPostDescription(
                    titre:
                    "${formaterDateTime(DateTime.fromMicrosecondsSinceEpoch(widget.post!.createdAt!))}",
                    fontSize: SizeText.homeProfileDateTextSize,
                    couleur: ConstColors.textColors,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (widget.post!.dataType == PostDataType.TEXT.name)
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DetailsPost( post: widget.post!),
                      ),
                    );
                  },
                  child: Container(
                    color: widget.color,
                    alignment: Alignment.center,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: IntrinsicWidth(
                        child: SizedBox(
                          // height: 200,
                          child: Column(
                            mainAxisSize: MainAxisSize.max, // Ajuste la hauteur au contenu
                            children: [
                              Card(
                                child: Container(

                                  constraints: BoxConstraints(
                                    // maxHeight: 150, // Hauteur maximale
                                  ),
                                  padding: EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black26,
                                        blurRadius: 10,
                                        offset: Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: HashTagText(
                                      text: truncateWords( widget.post!.description ?? "", 25),
                                      decoratedStyle: TextStyle(
                                        fontSize: fontSize,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.green,
                                        fontFamily: 'Nunito',
                                      ),
                                      basicStyle: TextStyle(
                                        fontSize: fontSize,
                                        color: Colors.black87,
                                        fontWeight: FontWeight.normal,
                                        fontFamily: 'Nunito',
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: null,
                                      softWrap: true,
                                    ),
                                  ),
                                ),
                              ),

                              Stack(
                                alignment: Alignment.bottomCenter,
                                children: [
                                  // Ajout d'un espace par défaut pour l'icône et les bulles
                                  SizedBox(height: 10),
                                  Container(
                                    height: 70,
                                  ),
                                  // Petites bulles de pensée
                                  // Positioned(bottom: 70, left: 60, child: CircleAvatar(radius: 15, backgroundColor: Colors.white)),
                                  Positioned(bottom: 50, left: 50, child: CircleAvatar(radius: 10, backgroundColor: Colors.white)),
                                  Positioned(bottom: 40, left: 40, child: CircleAvatar(radius: 5, backgroundColor: Colors.white)),
                                  // Icône de personne qui pense
                                  Positioned(bottom: 0, left: 2, child:
                                  Padding(
                                    padding: const EdgeInsets.only(right: 8.0),
                                    child:widget.post!.canal!=null?GestureDetector(
                                      onTap: () async {
                                        // await  authProvider.getUserById(widget.post!.user_id!).then((users) async {
                                        //   if(users.isNotEmpty){
                                        //     showUserDetailsModalDialog(users.first, w, h,context);
                                        //
                                        //   }
                                        // },);
                                        Navigator.push(context, MaterialPageRoute(builder: (context) => CanalDetails(canal: widget.post!.canal!),));

                                      },
                                      child:
                                      Row(
                                        spacing: 10,
                                        children: [
                                          CircleAvatar(
                                            radius: 20,

                                            backgroundImage:
                                            NetworkImage('${widget.post!.canal!.urlImage!}'),
                                          ),
                                          Container(
                                            padding: EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(20),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black26,
                                                  blurRadius: 10,
                                                  offset: Offset(0, 4),
                                                ),
                                              ],
                                            ),
                                            child: const Text(
                                              "Mes pensées",
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.normal,
                                                color: Colors.black87,
                                                fontFamily: 'Nunito',
                                              ),
                                              textAlign: TextAlign.center,
                                              maxLines: null,
                                              softWrap: true,
                                            ),
                                          )
                                        ],
                                      ),
                                    ):  GestureDetector(
                                      onTap: () async {
                                        await  authProvider.getUserById(widget.post!.user_id!).then((users) async {
                                          if(users.isNotEmpty){
                                            showUserDetailsModalDialog(users.first, w, h,context);

                                          }
                                        },);

                                      },
                                      child:
                                      Row(
                                        spacing: 10,
                                        children: [
                                          CircleAvatar(
                                            radius: 20,

                                            backgroundImage:
                                            NetworkImage('${widget.post!.user!.imageUrl!}'),
                                          ),
                                          Container(
                                            padding: EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(20),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black26,
                                                  blurRadius: 10,
                                                  offset: Offset(0, 4),
                                                ),
                                              ],
                                            ),
                                            child: const Text(
                                              "Mes pensées",
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.normal,
                                                color: Colors.black87,
                                                fontFamily: 'Nunito',
                                              ),
                                              textAlign: TextAlign.center,
                                              maxLines: null,
                                              softWrap: true,
                                            ),
                                          )
                                        ],
                                      ),
                                    ),
                                  ),
                                  ),
                                ],
                              ),
                            ],
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
                visible: widget.post!.dataType != PostDataType.TEXT.name
                    ? true
                    : false,
                child: GestureDetector(
                  onTap: () {
                    // postProvider.updateVuePost(post, context);

                    Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DetailsPost(post: widget.post),
                        ));
                  },
                  child: Container(
                    child: ClipRRect(
                      borderRadius: BorderRadius.all(Radius.circular(5)),
                      child: Container(
                        child: ImageSlideshow(

                          // width: w * 0.9,
                          // height: h * 0.5,

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
                          autoPlayInterval: 12000,

                          /// Loops back to first slide.
                          isLoop: false,

                          /// The widgets to display in the [ImageSlideshow].
                          /// Add the sample image file into the images folder
                          children: widget.post!.images!.map((e) =>   CachedNetworkImage(

                            fit: BoxFit.cover,
                            imageUrl:
                            '${e}',
                            progressIndicatorBuilder: (context, url,
                                downloadProgress) =>
                            //  LinearProgressIndicator(),

                            Skeletonizer(
                                child: SizedBox(
                                  // width: w * 0.9,
                                  // height: h * 0.4,
                                    child: ClipRRect(
                                        borderRadius: BorderRadius.all(
                                            Radius.circular(10)),
                                        child: Image.asset(
                                            'assets/images/404.png')))),
                            errorWidget: (context, url, error) =>
                                Skeletonizer(
                                    child: Container(
                                      // width: w * 0.9,
                                      // height: h * 0.4,
                                        child: Image.asset(
                                          "assets/images/404.png",
                                          fit: BoxFit.cover,
                                        ))),
                          )).toList(),
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
                        StatefulBuilder(builder:
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
                                          titre: "${formatAbonnes(widget.post!.users_republier_id==null?0:widget.post!.users_republier_id!.length!)}",
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
                              postProvider.getPostsImagesById(widget.post.id!).then((value) async {
                                if(value.isNotEmpty){
                                  widget.post=value.first;
                                  await authProvider.getAppData();
                                  showGiftDialog(widget.post,authProvider.loginUserData,authProvider.appDefaultData);

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
                                          titre: "${formatAbonnes(widget.post!.users_cadeau_id==null?0:widget.post!.users_cadeau_id!.length!)}",
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
                                                    value: love/widget.post!.user!.abonnes!+1,
                                                    semanticsLabel: 'Linear progress indicator',
                                                  ),
                                                ),
                                              ),
                                            ),
                                            TextCustomerPostDescription(
                                              titre: "${((love/widget.post!.user!.abonnes!+1)).toStringAsFixed(2)}%",
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
                                      // AnimateIcon(
                                      //   key: UniqueKey(),
                                      //   onTap: () {},
                                      //   iconType: IconType.continueAnimation,
                                      //   height: 20,
                                      //   width: 20,
                                      //   color: Colors.red,
                                      //   animateIcon: AnimateIcons.heart,
                                      // ),

                                      Icon(
                                        isIn(
                                            widget.post!.users_love_id!,
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
                                                    value: love/widget.post!.user!.abonnes!+1,
                                                    semanticsLabel: 'Linear progress indicator',
                                                  ),
                                                ),
                                              ),
                                            ),
                                            TextCustomerPostDescription(
                                              titre: "${((love/widget.post!.user!.abonnes!+1)).toStringAsFixed(2)}%",
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
                                        PostComments(post: widget.post),
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
                                                    value: comments/widget.post!.user!.abonnes!+1,
                                                    semanticsLabel: 'Linear progress indicator',
                                                  ),
                                                ),
                                              ),
                                            ),
                                            TextCustomerPostDescription(
                                              titre: "${(comments/widget.post!.user!.abonnes!+1).toStringAsFixed(2)}%",
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

                                      Icon(
                                        isIn(
                                            widget.post!.users_love_id!,
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
                                          titre: "${formatAbonnes(widget.post!.partage!)}",
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
                                                    value: love/widget.post!.user!.abonnes!+1,
                                                    semanticsLabel: 'Linear progress indicator',
                                                  ),
                                                ),
                                              ),
                                            ),
                                            TextCustomerPostDescription(
                                              titre: "${((love/widget.post!.user!.abonnes!+1)).toStringAsFixed(2)}%",
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
      ),
    );
  }
//
//   // Ajoutez ici les autres méthodes auxiliaires comme isIn, formatNumber, etc.
//   bool isIn(List<String> list, String value) {
//     return list.contains(value);
//   }
//
// // ... Les autres méthodes helper
}


void showInsufficientBalanceDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text(
          "Solde insuffisant",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        content: Text(
          "Votre solde principal est insuffisant pour terminer l'achat. Veuillez recharger votre compte principal.",
          style: TextStyle(color: Colors.black),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text("Fermer", style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => MonetisationPage(),));
            },
            style: TextButton.styleFrom(
              backgroundColor: Colors.yellow,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text("Recharger", style: TextStyle(color: Colors.black)),
          ),
        ],
      );
    },
  );
}
