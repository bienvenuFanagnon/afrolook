import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:provider/provider.dart';
import 'dart:math';

import 'package:afrotok/pages/user/monetisation.dart';
import 'package:afrotok/pages/userPosts/postColorsWidget.dart';
import 'package:afrotok/pages/userPosts/postWidgets/postCadeau.dart';
import 'package:afrotok/pages/userPosts/postWidgets/postUserWidget.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_slideshow/flutter_image_slideshow.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
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
import '../../../services/linkService.dart';
import '../../home/homeWidget.dart';
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
import '../../user/detailsOtherUser.dart';
// Ajoutez vos autres imports nécessaires ici


// Couleurs de l'application AfroLook
const _afroGreen = Color(0xFF2ECC71);
const _afroDarkGreen = Color(0xFF27AE60);
const _afroYellow = Color(0xFFF1C40F);
const _afroBlack = Color(0xFF2C3E50);
const _afroLightBg = Color(0xFFECF0F1);
class HomePostUsersWidget extends StatefulWidget {
  late Post post;
  late Color? color;
  final double height;
  final double width;
  final bool isDegrade;
  bool isPreview;

  HomePostUsersWidget({
    required this.post,
    this.color,
    this.isDegrade=false,
    required this.height,
    required this.width,
    Key? key, this.isPreview=true,
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


  String colorToHex(Color color) {
    return '#${color.value.toRadixString(16).padLeft(8, '0')}';
  }


  // Couleurs du thème Afrolook
  final Color _afroGreen = Color(0xFF2ECC71);
  final Color _afroYellow = Color(0xFFF1C40F);
  final Color _afroRed = Color(0xFFE74C3C);
  final Color _afroBlack = Color(0xFF2C3E50);
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


  // Fonction pour convertir une chaîne hex en Color
  Color colorFromHex(String? hexString) {
    if (hexString == null) return Colors.transparent;
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
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

  Color mixColors(Color color1, Color color2, double factor) {
    return Color.lerp(color1, color2, factor)!;
  }


  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    final w = MediaQuery.of(context).size.width;

    // Mélange des couleurs pour le dégradé d'arrière-plan
    Color blendedColor = mixColors(
        colorFromHex(widget.post.colorDomine),
        colorFromHex(widget.post.colorSecondaire),
        0.5
    );

    return Container(
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _afroBlack.withOpacity(0.1),
            blurRadius: 6,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DetailsPost(post: widget.post),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // En-tête avec info utilisateur/canal
                _buildPostHeader(context, w, h),
                SizedBox(height: 12),

                // Contenu texte avec limite de caractères
                _buildPostContent(context),

                // Galerie d'images (seulement 1ère image en aperçu)
                if (widget.post.images?.isNotEmpty ?? false)
                  _buildImagePreview(context, h),

                // Actions (likes, commentaires, vues)
                SizedBox(height: 12),
                _buildPostActions(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

// Construction de l'en-tête du post
  Widget _buildPostHeader(BuildContext context, double w, double h) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Avatar avec badge de vérification
        Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _afroYellow, width: 1.5),
              ),
              child: CircleAvatar(
                radius: 20,
                backgroundColor: _afroGreen,
                backgroundImage: _getProfileImage(),
                child:  GestureDetector(
                  onTap: () {
                    if (widget.post.canal == null)
                      _showUserDetailsModalDialog(widget.post.user!, w, h);
                  },
                  child: _getProfileImage() == null
                      ? Icon(Icons.person, color: Colors.white, size: 18)
                      : null,
                ),
              ),
            ),
            if (_isVerified())
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.verified,
                    color: _afroYellow,
                    size: 14,
                  ),
                ),
              ),
          ],
        ),
        SizedBox(width: 10),

        // Informations utilisateur/canal
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _getDisplayName(),
                style: TextStyle(
                  color: _afroBlack,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 2),
              Row(
                children: [
                  Text(
                    _getFollowerCount(),
                    style: TextStyle(
                      color: _afroBlack.withOpacity(0.6),
                      fontSize: 12,
                    ),
                  ),
                  // SizedBox(width: 8),
                  // Text(
                  //   formaterDateTime(DateTime.fromMicrosecondsSinceEpoch(widget.post.createdAt!)),
                  //   style: TextStyle(
                  //     color: _afroBlack.withOpacity(0.6),
                  //     fontSize: 9,
                  //   ),
                  // ),
                ],
              ),
            ],
          ),
        ),

        // Bouton d'options et d'abonnement
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.post.canal == null &&
                !isUserAbonne(widget.post.user!.userAbonnesIds!, authProvider.loginUserData.id!))
              GestureDetector(
                onTap: () {
                  // Action d'abonnement
                  _showUserDetailsModalDialog(widget.post.user!, w, h);
                },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _afroGreen,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Suivre',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            SizedBox(width: 6),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(),
              onPressed: () {
                showPostMenuModalDialog(widget.post!, context);
              },
              icon: Icon(
                Icons.more_vert,
                size: 20,
                color: _afroBlack.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ],
    );
  }

// Construction du contenu texte
  Widget _buildPostContent(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _afroLightBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: HashTagText(
        text: truncateWords(widget.post.description ?? "", 25),
        decoratedStyle: TextStyle(
          fontSize: 14,
          color: _afroDarkGreen,
          fontWeight: FontWeight.w600,
        ),
        basicStyle: TextStyle(
          fontSize: 13,
          color: _afroBlack,
          height: 1.4,
        ),
      ),
    );
  }

// Construction de l'aperçu d'image
  Widget _buildImagePreview(BuildContext context, double h) {
    return Padding(
      padding: EdgeInsets.only(top: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: h * 0.25,
          child: Stack(
            children: [
              ImageSlideshow(
                height: h * 0.25,
                children: [
                  CachedNetworkImage(
                    imageUrl: widget.post.images!.first,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    placeholder: (_, __) => Container(
                      color: _afroYellow.withOpacity(0.1),
                    ),
                    errorWidget: (_, __, ___) => Icon(
                      Icons.error,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),

              // Badge pour indiquer qu'il y a plusieurs images
              if (widget.post.images!.length > 1)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _afroBlack.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '+${widget.post.images!.length - 1}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
  // Partager une publication

// Construction des actions (likes, commentaires, vues)
  Widget _buildPostActions(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildActionButton(
          icon: FontAwesome.heart,
          count: widget.post.loves ?? 0,
          isActive: isIn(widget.post.users_love_id ?? [], authProvider.loginUserData.id!),
          onPressed: () async {
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

          },
        ),
        _buildActionButton(
          icon: FontAwesome.comment,
          count: widget.post.comments ?? 0,
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PostComments(post: widget.post),
            ),
          ),
        ),
        _buildActionButton(
          icon: FontAwesome.eye,
          count: widget.post.vues ?? 0,
          onPressed: () {},
        ),
        Spacer(),
        _buildActionButton(
          icon: FontAwesome.gift,
          count: widget.post.users_cadeau_id!.length ?? 0,
          onPressed: () {},
        ),
        _buildActionButton(
          icon: Icons.share,
          count: widget.post.partage! ?? 0,
          onPressed: () async {
            final AppLinkService _appLinkService = AppLinkService();
            _appLinkService.shareContent(
              type: AppLinkType.post,
              id: widget.post.id!,
              message: " ${widget.post.description}",
              mediaUrl: widget.post.images!.isNotEmpty?"${widget.post.images!}":"",
            );
            // _appLinkService.shareLink(
            //   AppLinkType.post,
            //   widget.post.id!,
            //   message: 'J\'ai trouvé cette publication géniale! 📸 : ${widget.post.description}',
            // );

            await FirebaseFirestore.instance
                .collection('Posts')
                .doc(widget.post.id!)
                .update({
              'partage': FieldValue.increment(1),
            });
          },
        ),
        Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: _afroBlack.withOpacity(0.4),
        ),
      ],
    );
  }

// Construction d'un bouton d'action
  Widget _buildActionButton({
    required IconData icon,
    required int count,
    bool isActive = false,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onPressed,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              Icon(
                icon,
                color: isActive ? _afroGreen : _afroBlack.withOpacity(0.6),
                size: 18,
              ),
              SizedBox(width: 4),
              Text(
                formatNumber(count),
                style: TextStyle(
                  color: isActive ? _afroGreen : _afroBlack.withOpacity(0.6),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

// Méthodes utilitaires
  ImageProvider? _getProfileImage() {
    if (widget.post.canal != null) {
      return widget.post.canal!.urlImage != null
          ? NetworkImage(widget.post.canal!.urlImage!)
          : null;
    } else {
      return widget.post.user?.imageUrl != null
          ?
      NetworkImage(
          widget.post.user!.imageUrl!)
          : null;
    }
  }

  bool _isVerified() {
    if (widget.post.canal != null) {
      return widget.post.canal!.isVerify ?? false;
    } else {
      return widget.post.user?.isVerify ?? false;
    }
  }

  String _getDisplayName() {
    if (widget.post.canal != null) {
      return "#${widget.post.canal!.titre ?? 'canal'}";
    } else {
      return "@${widget.post.user?.pseudo ?? 'Afrolookeur'}";
    }
  }

  String _getFollowerCount() {
    if (widget.post.canal != null) {
      return "${widget.post.canal!.usersSuiviId?.length ?? 0} abonnés";
    } else {
      return "${widget.post.user!.userAbonnesIds?.length ?? 0} abonnés";
    }
  }

// [Conserver les autres méthodes existantes]
}

class _ThoughtBubbleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    final radius = 25.0;
    final bubbleTailWidth = 20.0;
    final bubbleTailHeight = 15.0;

    // Corps principal
    path.addRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height - bubbleTailHeight),
      Radius.circular(radius),
    ));

    // Pointe de la bulle
    path.moveTo(size.width * 0.15, size.height - bubbleTailHeight);
    path.lineTo(size.width * 0.15 - bubbleTailWidth, size.height - bubbleTailHeight);
    path.lineTo(size.width * 0.15, size.height);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
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

