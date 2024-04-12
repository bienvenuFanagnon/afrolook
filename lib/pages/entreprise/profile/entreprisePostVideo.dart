import 'package:afrotok/pages/socialVideos/videoPlayer.dart';
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
import '../../postComments.dart';

class ProfileEntreprisePostVideoTab extends StatefulWidget {
  const ProfileEntreprisePostVideoTab({super.key});

  @override
  State<ProfileEntreprisePostVideoTab> createState() =>
      _ProfileEntreprisePostVideoTabState();
}

class _ProfileEntreprisePostVideoTabState
    extends State<ProfileEntreprisePostVideoTab> {
  final _formKey = GlobalKey<FormState>();

  GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  late UserAuthProvider authProvider =
      Provider.of<UserAuthProvider>(context, listen: false);

  late UserProvider userProvider =
      Provider.of<UserProvider>(context, listen: false);

  late PostProvider postProvider =
      Provider.of<PostProvider>(context, listen: false);

  TextEditingController commentController = TextEditingController();
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
    return userAbonnesList
        .any((userAbonne) => userAbonne.abonneUserId == userIdToCheck);
  }

  bool isIn(List<String> users_id, String userIdToCheck) {
    return users_id.any((item) => item == userIdToCheck);
  }

  bool isMyFriend(List<Friends> userfriendList, String userIdToCheck) {
    return userfriendList
        .any((userAbonne) => userAbonne.friendId == userIdToCheck);
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
                  leading: Icon(
                    Icons.flag,
                    color: Colors.blueGrey,
                  ),
                  title: Text(
                    'Signaler',
                  ),
                ),
                ListTile(
                  onTap: () {
                    Navigator.pop(context);
                  },
                  leading: Icon(
                    Icons.edit,
                    color: Colors.blue,
                  ),
                  title: Text('Modifier'),
                ),
                ListTile(
                  onTap: () {
                    Navigator.pop(context);
                  },
                  leading: Icon(
                    Icons.delete,
                    color: Colors.red,
                  ),
                  title: Text('Supprimer'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget homeProfileUsers(UserData user) {
    //authProvider.getCurrentUser(authProvider.loginUserData!.id!);
    //  print("invitation : ${authProvider.loginUserData.mesInvitationsEnvoyer!.length}");

    bool abonneTap = false;
    bool inviteTap = false;
    bool dejaInviter = false;

    return Padding(
      padding: const EdgeInsets.all(1.0),
      child: Card(
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(4.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.all(Radius.circular(10)),
                child: Container(
                  width: 120,
                  height: 100,
                  child: CachedNetworkImage(
                    fit: BoxFit.cover,
                    imageUrl: '${user.imageUrl!}',
                    progressIndicatorBuilder: (context, url,
                            downloadProgress) =>
                        //  LinearProgressIndicator(),

                        Skeletonizer(
                            child: SizedBox(
                                width: 120,
                                height: 100,
                                child: ClipRRect(
                                    borderRadius:
                                        BorderRadius.all(Radius.circular(10)),
                                    child:
                                        Image.asset('assets/images/404.png')))),
                    errorWidget: (context, url, error) => Container(
                        width: 120,
                        height: 100,
                        child: Image.asset(
                          "assets/icon/user-removebg-preview.png",
                          fit: BoxFit.cover,
                        )),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 2.0, bottom: 2),
                child: SizedBox(
                  //width: 70,
                  child: Container(
                    alignment: Alignment.center,
                    child: TextCustomerPostDescription(
                      titre: "@${user.pseudo}",
                      fontSize: SizeText.homeProfileTextSize,
                      couleur: ConstColors.textColors,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              StatefulBuilder(builder: (BuildContext context,
                  void Function(void Function()) setState) {
                return Container(
                  child: isMyFriend(
                          authProvider.loginUserData.friends!, user.id!)
                      ? ElevatedButton(
                          onPressed: () {},
                          child: Container(
                            child: TextCustomerUserTitle(
                              titre: "discuter",
                              fontSize: SizeText.homeProfileTextSize,
                              couleur: Colors.blue,
                              fontWeight: FontWeight.w600,
                            ),
                          ))
                      : !isInvite(
                              authProvider.loginUserData.mesInvitationsEnvoyer!,
                              user.id!)
                          ? Padding(
                              padding:
                                  const EdgeInsets.only(top: 8.0, bottom: 8),
                              child: Container(
                                width: 120,
                                height: 30,
                                child: ElevatedButton(
                                  onPressed: inviteTap
                                      ? () {}
                                      : () async {
                                          if (!isInvite(
                                              authProvider.loginUserData
                                                  .mesInvitationsEnvoyer!,
                                              user.id!)) {
                                            setState(() {
                                              inviteTap = true;
                                            });
                                            Invitation invitation =
                                                Invitation();
                                            invitation.senderId =
                                                authProvider.loginUserData.id;
                                            invitation.receiverId = user.id;
                                            invitation.status =
                                                InvitationStatus.ENCOURS.name;
                                            invitation.createdAt =
                                                DateTime.now()
                                                    .millisecondsSinceEpoch;
                                            invitation.updatedAt =
                                                DateTime.now()
                                                    .millisecondsSinceEpoch;

                                            // invitation.inviteUser=authProvider.loginUserData!;
                                            await userProvider
                                                .sendInvitation(invitation,context)
                                                .then(
                                              (value) async {
                                                if (value) {
                                                  // await userProvider.getUsers(authProvider.loginUserData!.id!);
                                                  authProvider.loginUserData
                                                      .mesInvitationsEnvoyer!
                                                      .add(invitation);
                                                  await authProvider
                                                      .getCurrentUser(
                                                          authProvider
                                                              .loginUserData!
                                                              .id!);
                                                  SnackBar snackBar = SnackBar(
                                                    content: Text(
                                                      'invitation envoyée',
                                                      textAlign:
                                                          TextAlign.center,
                                                      style: TextStyle(
                                                          color: Colors.green),
                                                    ),
                                                  );
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(snackBar);
                                                } else {
                                                  SnackBar snackBar = SnackBar(
                                                    content: Text(
                                                      'une erreur',
                                                      textAlign:
                                                          TextAlign.center,
                                                      style: TextStyle(
                                                          color: Colors.red),
                                                    ),
                                                  );
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(snackBar);
                                                }
                                              },
                                            );

                                            setState(() {
                                              inviteTap = false;
                                            });
                                          }
                                        },
                                  child: inviteTap
                                      ? Center(
                                          child: LoadingAnimationWidget.flickr(
                                            size: 20,
                                            leftDotColor: Colors.green,
                                            rightDotColor: Colors.black,
                                          ),
                                        )
                                      : TextCustomerUserTitle(
                                          titre: "inviter",
                                          fontSize:
                                              SizeText.homeProfileTextSize,
                                          couleur: Colors.blue,
                                          fontWeight: FontWeight.w600,
                                        ),
                                ),
                              ),
                            )
                          : Padding(
                              padding:
                                  const EdgeInsets.only(top: 8.0, bottom: 8),
                              child: Container(
                                width: 120,
                                height: 30,
                                child: ElevatedButton(
                                  onPressed: () {},
                                  child: TextCustomerUserTitle(
                                    titre: "déjà invité",
                                    fontSize: SizeText.homeProfileTextSize,
                                    couleur: Colors.green,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                );
              }),
              StatefulBuilder(builder: (BuildContext context,
                  void Function(void Function()) setState) {
                return Container(
                  child: isUserAbonne(
                          authProvider.loginUserData.userAbonnes!, user.id!)
                      ? Container(
                          width: 120,
                          height: 30,
                          child: ElevatedButton(
                            onPressed: () {},
                            child: TextCustomerUserTitle(
                              titre: "abonné",
                              fontSize: SizeText.homeProfileTextSize,
                              couleur: Colors.green,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      : Container(
                          width: 120,
                          height: 30,
                          child: ElevatedButton(
                            onPressed: abonneTap
                                ? () {}
                                : () async {
                                    if (!isUserAbonne(
                                        authProvider.loginUserData.userAbonnes!,
                                        user!.id!)) {
                                      setState(() {
                                        abonneTap = true;
                                      });
                                      UserAbonnes userAbonne = UserAbonnes();
                                      userAbonne.compteUserId =
                                          authProvider.loginUserData.id;
                                      userAbonne.abonneUserId = user!.id;

                                      userAbonne.createdAt =
                                          DateTime.now().millisecondsSinceEpoch;
                                      userAbonne.updatedAt =
                                          DateTime.now().millisecondsSinceEpoch;
                                      await userProvider
                                          .sendAbonnementRequest(
                                              userAbonne, user,context)
                                          .then(
                                        (value) async {
                                          if (value) {
                                            // await userProvider.getUsers(authProvider.loginUserData!.id!);
                                            authProvider
                                                .loginUserData.userAbonnes!
                                                .add(userAbonne);
                                            await authProvider.getCurrentUser(
                                                authProvider
                                                    .loginUserData!.id!);
                                            SnackBar snackBar = SnackBar(
                                              content: Text(
                                                'abonné',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                    color: Colors.green),
                                              ),
                                            );
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(snackBar);
                                            setState(() {
                                              abonneTap = false;
                                            });
                                          } else {
                                            SnackBar snackBar = SnackBar(
                                              content: Text(
                                                'une erreur',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                    color: Colors.red),
                                              ),
                                            );
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(snackBar);
                                            setState(() {
                                              abonneTap = false;
                                            });
                                          }
                                        },
                                      );

                                      setState(() {
                                        abonneTap = false;
                                      });
                                    }
                                  },
                            child: abonneTap
                                ? Center(
                                    child: LoadingAnimationWidget.flickr(
                                      size: 20,
                                      leftDotColor: Colors.green,
                                      rightDotColor: Colors.black,
                                    ),
                                  )
                                : TextCustomerUserTitle(
                                    titre: "S'abonner",
                                    fontSize: SizeText.homeProfileTextSize,
                                    couleur: Colors.red,
                                    fontWeight: FontWeight.w600,
                                  ),
                          ),
                        ),
                );
              })
            ],
          ),
        ),
      ),
    );
  }





  Widget homePostUsers(Post post, double height, double width) {
    double h = MediaQuery.of(context).size.height;
    double w = MediaQuery.of(context).size.width;

    Random random = Random();
    bool abonneTap = false;
    int like = post!.likes!;
    int imageIndex = 0;
    int love = post!.loves!;
    int comments = post!.comments!;
    bool tapLove = isIn(post.users_love_id!, authProvider.loginUserData.id!);
    bool tapLike = isIn(post.users_like_id!, authProvider.loginUserData.id!);
    List<int> likes = [];
    List<int> loves = [];
    int idUser = 7;
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
                      Row(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: CircleAvatar(
                              backgroundImage: NetworkImage(
                                  '${post.entrepriseData==null?'':post.entrepriseData!.urlImage!}'),
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
                                      titre: "#${post.entrepriseData==null?'':post.entrepriseData!.titre!}",
                                      fontSize: SizeText.homeProfileTextSize,
                                      couleur: ConstColors.textColors,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  TextCustomerUserTitle(
                                    titre: "${post.entrepriseData==null?'':post.entrepriseData!.suivi!} suivi(s)",
                                    fontSize: 10,
                                    couleur: ConstColors.textColors,
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
                      SizedBox(width: 20,),
                      Icon(Entypo.arrow_long_right,color: Colors.green,),
                      SizedBox(width: 20,),
                      Row(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: CircleAvatar(
                              backgroundImage: NetworkImage(
                                  '${post.user!.imageUrl!}'),
                              onBackgroundImageError: (exception, stackTrace) => AssetImage('assets/images/404.png'),

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
                                      titre: "@${post.user!.pseudo!}",
                                      fontSize: SizeText.homeProfileTextSize,
                                      couleur: ConstColors.textColors,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  TextCustomerUserTitle(
                                    titre: "${post.user!.abonnes!} abonné(s)",
                                    fontSize: 10,
                                    couleur: ConstColors.textColors,
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
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    Icon(Entypo.network,size: 15,),
                    SizedBox(width: 10,),
                    TextCustomerUserTitle(
                      titre: "publicité",
                      fontSize: SizeText.homeProfileTextSize,
                      couleur: Colors.green,
                      fontWeight: FontWeight.w400,
                    ),
                  ],
                ),
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
                      titre: "${post.description}",
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
                  titre:
                      "${formaterDateTime(DateTime.fromMicrosecondsSinceEpoch(post.createdAt!))}",
                  fontSize: SizeText.homeProfileDateTextSize,
                  couleur: ConstColors.textColors,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(
                height: 5,
              ),
              post!.images == null
                  ? Container()
                  : Container(
                      width: w,
                      height: h * 0.3,
                      child: ClipRRect(
                        borderRadius: BorderRadius.all(Radius.circular(5)),
                        child: VideoPlayerWidget(
                            videoUrl:
                                '${post!.url_media == null ? '' : post!.url_media}'),
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
                    StatefulBuilder(
                        builder: (BuildContext context, StateSetter setState) {
                      return GestureDetector(
                        onTap: () async {
                          if (!isIn(post.users_love_id!,
                              authProvider.loginUserData.id!)) {

                          }
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
                                    tapLove
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
                                      titre: "${love}",
                                      fontSize:
                                          SizeText.homeProfileDateTextSize,
                                      couleur: ConstColors.textColors,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                      left: 1.0, right: 1),
                                  child: SizedBox(
                                    height: 2,
                                    width: 5,
                                    child: LinearProgressIndicator(
                                      color: Colors.red,
                                      value: love / 505,
                                      semanticsLabel:
                                          'Linear progress indicator',
                                    ),
                                  ),
                                ),
                              ),
                              TextCustomerPostDescription(
                                titre:
                                    "${(love / 505 * 100).toStringAsFixed(2)}%",
                                fontSize: SizeText.homeProfileDateTextSize,
                                couleur: ConstColors.textColors,
                                fontWeight: FontWeight.bold,
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    StatefulBuilder(
                        builder: (BuildContext context, StateSetter setState) {
                      return GestureDetector(
                        onTap: () {
                          if (!isIn(post.users_like_id!,
                              authProvider.loginUserData.id!)) {

                          }
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
                                    tapLike
                                        ? MaterialCommunityIcons.thumb_up
                                        : MaterialCommunityIcons
                                            .thumb_up_outline,
                                    size: 20,
                                    color: tapLike ? Colors.blue : Colors.black,
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(
                                        left: 1.0, right: 1),
                                    child: TextCustomerPostDescription(
                                      titre: "${like}",
                                      fontSize:
                                          SizeText.homeProfileDateTextSize,
                                      couleur: ConstColors.textColors,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                      left: 1.0, right: 1),
                                  child: SizedBox(
                                    height: 2,
                                    // width: width*0.75,
                                    child: LinearProgressIndicator(
                                      color: Colors.blue,
                                      value: like / 505,
                                      semanticsLabel:
                                          'Linear progress indicator',
                                    ),
                                  ),
                                ),
                              ),
                              TextCustomerPostDescription(
                                titre:
                                    "${(like / 505 * 100).toStringAsFixed(2)}%",
                                fontSize: SizeText.homeProfileDateTextSize,
                                couleur: ConstColors.textColors,
                                fontWeight: FontWeight.bold,
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    StatefulBuilder(
                        builder: (BuildContext context, StateSetter setState) {
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => PostComments(post: post),));

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
                                      titre: "${comments}",
                                      fontSize:
                                          SizeText.homeProfileDateTextSize,
                                      couleur: ConstColors.textColors,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                      left: 1.0, right: 1),
                                  child: SizedBox(
                                    height: 2,
                                    //width: width*0.75,
                                    child: LinearProgressIndicator(
                                      color: Colors.blueGrey,
                                      value: comments / 505,
                                      semanticsLabel:
                                          'Linear progress indicator',
                                    ),
                                  ),
                                ),
                              ),
                              TextCustomerPostDescription(
                                titre:
                                    "${(comments / 505 * 100).toStringAsFixed(2)}%",
                                fontSize: SizeText.homeProfileDateTextSize,
                                couleur: ConstColors.textColors,
                                fontWeight: FontWeight.bold,
                              ),
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
      }),
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
        child: Padding(
          padding: const EdgeInsets.only(left: 8.0, right: 8, top: 2),
          child: StreamBuilder<List<Post>>(
            stream: postProvider
                .getPubVideosByEntreprise(userProvider.entrepriseData.id!),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                print("attente");
                return SizedBox(
                  //height: height,
                  width: width,
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      for (Post p in postProvider.listConstposts)
                        Skeletonizer(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 5.0, bottom: 5),
                            child: homePostUsers(p, height, width),
                          ),
                        )
                    ],
                  ),
                );
              } else if (snapshot.hasError) {
                print("erreur ${snapshot.error}");
                return Skeletonizer(
                  //enabled: _loading,
                  child: SizedBox(
                    width: width,
                    height: height * 0.4,
                    child: ListView.builder(
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
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                  right: 8.0),
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
                                                      child:
                                                          TextCustomerUserTitle(
                                                        titre: "pseudo",
                                                        fontSize: SizeText
                                                            .homeProfileTextSize,
                                                        couleur: ConstColors
                                                            .textColors,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                    TextCustomerUserTitle(
                                                      titre: " abonné(s)",
                                                      fontSize: SizeText
                                                          .homeProfileTextSize,
                                                      couleur: ConstColors
                                                          .textColors,
                                                      fontWeight:
                                                          FontWeight.w400,
                                                    ),
                                                  ],
                                                ),
                                                TextButton(
                                                    onPressed: () {},
                                                    child: Text(
                                                      "S'abonner",
                                                      style: TextStyle(
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.normal,
                                                          color: Colors.blue),
                                                    )),
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
                                              color:
                                                  ConstColors.blackIconColors,
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
                                            titre: "...Afficher plus",
                                            fontSize:
                                                SizeText.homeProfileTextSize,
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
                                        fontSize:
                                            SizeText.homeProfileDateTextSize,
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
                                            borderRadius: BorderRadius.all(
                                                Radius.circular(10)),
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
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
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
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.center,
                                                // mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Icon(
                                                        Icons
                                                            .heart_broken_outlined,
                                                        color: Colors.red,
                                                        size: 20,
                                                        // color: ConstColors.likeColors,
                                                      ),
                                                      Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .only(
                                                                left: 1.0,
                                                                right: 1),
                                                        child:
                                                            TextCustomerPostDescription(
                                                          titre: "20",
                                                          fontSize: SizeText
                                                              .homeProfileDateTextSize,
                                                          couleur: ConstColors
                                                              .textColors,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  Expanded(
                                                    child: Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                              left: 1.0,
                                                              right: 1),
                                                      child: SizedBox(
                                                        height: 2,
                                                        width: 10,
                                                        child:
                                                            LinearProgressIndicator(
                                                          color: Colors.red,
                                                          value: 10 / 505,
                                                          semanticsLabel:
                                                              'Linear progress indicator',
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  TextCustomerPostDescription(
                                                    titre:
                                                        "${(20 / 505 * 100).toStringAsFixed(2)}%",
                                                    fontSize: SizeText
                                                        .homeProfileDateTextSize,
                                                    couleur:
                                                        ConstColors.textColors,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          GestureDetector(
                                            onTap: () {},
                                            child: Container(
                                              width: 110,
                                              height: 30,
                                              child: Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.center,
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
                                                        padding:
                                                            const EdgeInsets
                                                                .only(
                                                                left: 1.0,
                                                                right: 1),
                                                        child:
                                                            TextCustomerPostDescription(
                                                          titre: "20",
                                                          fontSize: SizeText
                                                              .homeProfileDateTextSize,
                                                          couleur: ConstColors
                                                              .textColors,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  Expanded(
                                                    child: Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                              left: 1.0,
                                                              right: 1),
                                                      child: SizedBox(
                                                        height: 2,
                                                        // width: width*0.75,
                                                        child:
                                                            LinearProgressIndicator(
                                                          color: Colors.blue,
                                                          value: 10 / 505,
                                                          semanticsLabel:
                                                              'Linear progress indicator',
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  TextCustomerPostDescription(
                                                    titre:
                                                        "${(10 / 505 * 100).toStringAsFixed(2)}%",
                                                    fontSize: SizeText
                                                        .homeProfileDateTextSize,
                                                    couleur:
                                                        ConstColors.textColors,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          GestureDetector(
                                            onTap: () {},
                                            child: Container(
                                              width: 110,
                                              height: 30,
                                              child: Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.center,
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
                                                        padding:
                                                            const EdgeInsets
                                                                .only(
                                                                left: 1.0,
                                                                right: 1),
                                                        child:
                                                            TextCustomerPostDescription(
                                                          titre: "20",
                                                          fontSize: SizeText
                                                              .homeProfileDateTextSize,
                                                          couleur: ConstColors
                                                              .textColors,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  Expanded(
                                                    child: Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                              left: 1.0,
                                                              right: 1),
                                                      child: SizedBox(
                                                        height: 2,
                                                        //width: width*0.75,
                                                        child:
                                                            LinearProgressIndicator(
                                                          color:
                                                              Colors.blueGrey,
                                                          value: 20 / 505,
                                                          semanticsLabel:
                                                              'Linear progress indicator',
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  TextCustomerPostDescription(
                                                    titre:
                                                        "${(20 / 505 * 100).toStringAsFixed(2)}%",
                                                    fontSize: SizeText
                                                        .homeProfileDateTextSize,
                                                    couleur:
                                                        ConstColors.textColors,
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
                return Column(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    for (Post p in snapshot.data!)
                      Padding(
                        padding: const EdgeInsets.only(top: 5.0, bottom: 5),
                        child: homePostUsers(p, height, width),
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
