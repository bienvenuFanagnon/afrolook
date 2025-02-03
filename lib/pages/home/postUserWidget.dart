



import 'dart:math';

import 'package:afrotok/pages/canaux/listCanal.dart';
import 'package:afrotok/pages/userPosts/challenge/challengeDetails.dart';
import 'package:afrotok/pages/userPosts/textBullePensee.dart';
import 'package:afrotok/providers/postProvider.dart';
import 'package:animated_icon/animated_icon.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:country_flags/country_flags.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_slideshow/flutter_image_slideshow.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:hashtagable_v3/widgets/hashtag_text.dart';
import 'package:insta_image_viewer/insta_image_viewer.dart';
import 'package:intl/intl.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../constant/constColors.dart';
import '../../constant/sizeText.dart';
import '../../constant/textCustom.dart';
import '../../models/model_data.dart';
import '../../providers/afroshop/authAfroshopProvider.dart';
import '../../providers/afroshop/categorie_produits_provider.dart';
import '../../providers/authProvider.dart';
import '../../providers/userProvider.dart';
import '../canaux/detailsCanal.dart';
import '../component/consoleWidget.dart';
import '../component/showUserDetails.dart';
import '../postComments.dart';
import '../postDetails.dart';
import '../user/conponent.dart';
import '../user/otherUser/otherUser.dart';
String formatNumber(int number) {
  if (number >= 1000) {
    double nombre = number / 1000;
    return nombre.toStringAsFixed(1) + 'k';
  } else {
    return number.toString();
  }
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

bool isMyFriend(List<String> userfriendList, String userIdToCheck) {
  return userfriendList.any((userfriendId) => userfriendId == userIdToCheck);
}
Widget homePostUsers(Post post,Color color, double height, double width,BuildContext context) {
  double h = MediaQuery.of(context).size.height;
  double w = MediaQuery.of(context).size.width;
  late UserAuthProvider authProvider =
  Provider.of<UserAuthProvider>(context, listen: false);

  late PostProvider postProvider =
  Provider.of<PostProvider>(context, listen: false);
  late CategorieProduitProvider categorieProduitProvider =
  Provider.of<CategorieProduitProvider>(context, listen: false);
  late UserProvider userProvider =
  Provider.of<UserProvider>(context, listen: false);
  final FirebaseFirestore firestore = FirebaseFirestore.instance;




  Random random = Random();
  bool abonneTap = false;
  int like = post!.likes!;
  int imageIndex = 0;
  int love = post!.loves!;
  int vue = post!.vues!;
  int comments = post!.comments!;
  bool tapLove = isIn(post.users_love_id!, authProvider.loginUserData.id!);
  bool tapLike = isIn(post.users_like_id!, authProvider.loginUserData.id!);
  List<int> likes = [];
  List<int> loves = [];
  int idUser = 7;
  // Calculer la taille du texte en fonction de la longueur de la description
  double baseFontSize = 20.0;
  double scale = post.description!.length / 1000;  // Ajustez ce facteur selon vos besoins
  double fontSize = baseFontSize - scale;

  // Limiter la taille de la police à une valeur minimale
  fontSize = fontSize < 15 ? 15 : fontSize;
  int limitePosts = 30;
  printVm("post.user!.role :${post.type} ${post.user!.role}");

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



  return Container(
    child: StatefulBuilder(
        builder: (BuildContext context, StateSetter setStateImages) {
          return Padding(
            padding: const EdgeInsets.all(5.0),
            child: Column(
              children: [
                post.canal!=null?Padding(
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
                        post.canal!=null?Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child:  GestureDetector(
                            onTap: () async {
                              // await  authProvider.getUserById(post.user_id!).then((users) async {
                              //   if(users.isNotEmpty){
                              //     showUserDetailsModalDialog(users.first, w, h,context);
                              //
                              //   }
                              // },);
                              Navigator.push(context, MaterialPageRoute(builder: (context) => CanalListPage(isUserCanals: false,),));
                              Navigator.push(context, MaterialPageRoute(builder: (context) => CanalDetails(canal: post.canal!),));


                            },
                            child:
                            CircleAvatar(

                              backgroundImage:
                              NetworkImage('${post.canal!.urlImage!}'),
                            ),
                          ),
                        ): Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child:  GestureDetector(
                            onTap: () async {
                              await  authProvider.getUserById(post.user_id!).then((users) async {
                                if(users.isNotEmpty){
                                  showUserDetailsModalDialog(users.first, w, h,context);

                                }
                              },);

                            },
                            child:
                            CircleAvatar(

                              backgroundImage:
                              NetworkImage('${post.user!.imageUrl!}'),
                            ),
                          ),
                        ),
                        SizedBox(
                          height: 2,
                        ),

                        Container(
                          child:post.canal!=null?   Row(
                            spacing: 5,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    //width: 100,
                                    child: TextCustomerUserTitle(
                                      titre: "#${post.canal!.titre!}",
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
                                            "${formatNumber(post.canal!.usersSuiviId!.length)} abonné(s)",
                                            fontSize: SizeText.homeProfileTextSize,
                                            couleur: ConstColors.textColors,
                                            fontWeight: FontWeight.w400,
                                          ),

                                        ],
                                      ),
                                      // countryFlag(post.user!.countryData!['countryCode']??"Tg"!, size: 15),

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
                                      titre: "@${post.user!.pseudo!}",
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
                                            "${formatNumber(post.user!.userlikes!)} like(s)",
                                            fontSize: SizeText.homeProfileTextSize,
                                            couleur: Colors.green,
                                            fontWeight: FontWeight.w700,
                                          ),

                                          TextCustomerUserTitle(
                                            titre:
                                            "${formatNumber(post.user!.userAbonnesIds!.length)} abonné(s)",
                                            fontSize: SizeText.homeProfileTextSize,
                                            couleur: ConstColors.textColors,
                                            fontWeight: FontWeight.w400,
                                          ),

                                        ],
                                      ),
                                      // countryFlag(post.user!.countryData!['countryCode']??"Tg"!, size: 15),

                                    ],
                                  ),
                                ],
                              ),

                               Visibility(
                                 visible: post.user!.isVerify!,
                                 child: Card(
                                   child: const Icon(
                                    Icons.verified,
                                    color: Colors.green,
                                    size: 20,
                                                               ),
                                 ),
                               ),
                              Visibility(
                                visible:authProvider.loginUserData.id!=post.user!.id ,

                                child: StatefulBuilder(builder: (BuildContext context,
                                    void Function(void Function()) setState) {
                                  return Container(
                                    child: isUserAbonne(
                                        post.user!.userAbonnesIds!,
                                        authProvider.loginUserData.id!)
                                        ? Container()
                                        : TextButton(
                                        onPressed: abonneTap
                                            ? () {}
                                            : () async {
                                          setState(() {
                                            abonneTap=true;
                                          });
                                          await authProvider.abonner(post.user!,context).then((value) {

                                          },);
                                          setState(() {
                                            abonneTap=false;
                                          });
                                          //
                                          // if (!isUserAbonne(
                                          //     post.user!
                                          //         .userAbonnesIds!,
                                          //     authProvider
                                          //         .loginUserData
                                          //         .id!))
                                          // {
                                          //   setState(() {
                                          //     abonneTap = true;
                                          //   });
                                          //   UserAbonnes userAbonne =
                                          //   UserAbonnes();
                                          //   userAbonne.compteUserId =
                                          //       authProvider
                                          //           .loginUserData.id;
                                          //   userAbonne.abonneUserId =
                                          //       post.user!.id;
                                          //
                                          //   userAbonne
                                          //       .createdAt = DateTime
                                          //       .now()
                                          //       .millisecondsSinceEpoch;
                                          //   userAbonne
                                          //       .updatedAt = DateTime
                                          //       .now()
                                          //       .millisecondsSinceEpoch;
                                          //   await userProvider
                                          //       .sendAbonnementRequest(
                                          //       userAbonne,
                                          //       post.user!,
                                          //       context)
                                          //       .then(
                                          //         (value) async {
                                          //       if (value) {
                                          //         authProvider
                                          //             .loginUserData
                                          //             .userAbonnes!
                                          //             .add(
                                          //             userAbonne);
                                          //         // await userProvider.getUsers(authProvider.loginUserData!.id!);
                                          //         await authProvider
                                          //             .getCurrentUser(
                                          //             authProvider
                                          //                 .loginUserData!
                                          //                 .id!);
                                          //         await  authProvider.getUserById(post.user_id!).then((users) async {
                                          //           if(users.isNotEmpty){
                                          //             // users.first.abonnes=users.first.abonnes!+1;
                                          //             users.first.userAbonnesIds!.add(authProvider.loginUserData.id!);
                                          //             // post.user!.userAbonnesIds!.add(authProvider.loginUserData.id!);
                                          //
                                          //             post.user!= users.first;
                                          //
                                          //             post.user!.abonnes=post.user!.userAbonnesIds!.length;
                                          //             // post.user!= users.first;
                                          //
                                          //             await userProvider.updateUser(post.user!);
                                          //             // setState(() {
                                          //             //   abonneTap=false;
                                          //             //
                                          //             // });
                                          //           }
                                          //         },);
                                          //
                                          //         // post.user!
                                          //         //     .abonnes= post.user!
                                          //         //     .abonnes!+1;
                                          //         // post.user!
                                          //         //     .userAbonnesIds!
                                          //         //     .add(authProvider
                                          //         //     .loginUserData
                                          //         //     .id!);
                                          //         // userProvider
                                          //         //     .updateUser(
                                          //         //     post.user!);
                                          //         if (post.user!
                                          //             .oneIgnalUserid !=
                                          //             null &&
                                          //             post
                                          //                 .user!
                                          //                 .oneIgnalUserid!
                                          //                 .length >
                                          //                 5) {
                                          //           await authProvider.sendNotification(
                                          //               userIds: [
                                          //                 post.user!
                                          //                     .oneIgnalUserid!
                                          //               ],
                                          //               smallImage:
                                          //               "${authProvider.loginUserData.imageUrl!}",
                                          //               send_user_id:
                                          //               "${authProvider.loginUserData.id!}",
                                          //               recever_user_id:
                                          //               "${post.user_id!}",
                                          //               message:
                                          //               "📢 @${authProvider.loginUserData.pseudo!} s'est abonné(e) à votre compte",
                                          //               type_notif:
                                          //               NotificationType
                                          //                   .ABONNER
                                          //                   .name,
                                          //               post_id:
                                          //               "${post!.id!}",
                                          //               post_type:
                                          //               PostDataType
                                          //                   .IMAGE
                                          //                   .name,
                                          //               chat_id: '');
                                          //           NotificationData
                                          //           notif =
                                          //           NotificationData();
                                          //           notif.id = firestore
                                          //               .collection(
                                          //               'Notifications')
                                          //               .doc()
                                          //               .id;
                                          //           notif.titre =
                                          //           "Nouveau Abonnement ✅";
                                          //           notif.media_url =
                                          //               authProvider
                                          //                   .loginUserData
                                          //                   .imageUrl;
                                          //           notif.type =
                                          //               NotificationType
                                          //                   .ABONNER
                                          //                   .name;
                                          //           notif.description =
                                          //           "@${authProvider.loginUserData.pseudo!} s'est abonné(e) à votre compte";
                                          //           notif.users_id_view =
                                          //           [];
                                          //           notif.user_id =
                                          //               authProvider
                                          //                   .loginUserData
                                          //                   .id;
                                          //           notif.receiver_id =
                                          //           post.user!
                                          //               .id!;
                                          //           notif.post_id =
                                          //           post.id!;
                                          //           notif.post_data_type =
                                          //           PostDataType
                                          //               .IMAGE
                                          //               .name!;
                                          //           notif.updatedAt =
                                          //               DateTime.now()
                                          //                   .microsecondsSinceEpoch;
                                          //           notif.createdAt =
                                          //               DateTime.now()
                                          //                   .microsecondsSinceEpoch;
                                          //           notif.status =
                                          //               PostStatus
                                          //                   .VALIDE
                                          //                   .name;
                                          //
                                          //           // users.add(pseudo.toJson());
                                          //
                                          //           await firestore
                                          //               .collection(
                                          //               'Notifications')
                                          //               .doc(notif.id)
                                          //               .set(notif
                                          //               .toJson());
                                          //         }
                                          //         SnackBar snackBar =
                                          //         SnackBar(
                                          //           content: Text(
                                          //             'abonné, Bravo ! Vous avez gagné 4 points.',
                                          //             textAlign:
                                          //             TextAlign
                                          //                 .center,
                                          //             style: TextStyle(
                                          //                 color: Colors
                                          //                     .green),
                                          //           ),
                                          //         );
                                          //         ScaffoldMessenger
                                          //             .of(context)
                                          //             .showSnackBar(
                                          //             snackBar);
                                          //         setState(() {
                                          //           abonneTap = false;
                                          //         });
                                          //       } else {
                                          //         SnackBar snackBar =
                                          //         SnackBar(
                                          //           content: Text(
                                          //             'une erreur',
                                          //             textAlign:
                                          //             TextAlign
                                          //                 .center,
                                          //             style: TextStyle(
                                          //                 color: Colors
                                          //                     .red),
                                          //           ),
                                          //         );
                                          //         ScaffoldMessenger
                                          //             .of(context)
                                          //             .showSnackBar(
                                          //             snackBar);
                                          //         setState(() {
                                          //           abonneTap = false;
                                          //         });
                                          //       }
                                          //     },
                                          //   );
                                          //
                                          //   setState(() {
                                          //     abonneTap = false;
                                          //   });
                                          // }
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
                        ),
                        SizedBox(width: 10,),



                      ],
                    ),
                    IconButton(
                        onPressed: () {
                          _showPostMenuModalDialog(post,context);
                        },
                        icon: Icon(
                          Icons.more_horiz,
                          size: 30,
                          color: ConstColors.blackIconColors,
                        )),
                  ],
                ),
                Visibility(
                    visible: post.type==PostType.PUB.name,
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
                  visible: post.dataType != PostDataType.TEXT.name
                      ? true
                      : false,
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: SizedBox(
                      width:post.type==PostType.PUB.name?width*0.82: width * 0.8,
                      child: Container(
                          alignment: Alignment.centerLeft,
                          child:SizedBox(
                            height:post.type==PostType.PUB.name?70: 60,

                            child: SingleChildScrollView(
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
                                  HashTagText(
                                    text: "${post.description}",
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
                          ),
                        // TextCustomerPostDescription(
                        //   titre: "${post.description}",
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
                      "${formaterDateTime(DateTime.fromMicrosecondsSinceEpoch(post.createdAt!))}",
                      fontSize: SizeText.homeProfileDateTextSize,
                      couleur: ConstColors.textColors,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              if (post.dataType == PostDataType.TEXT.name)
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DetailsPost(post: post),
                ),
              );
            },
            child: Container(
              color: color,
              alignment: Alignment.center,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: IntrinsicWidth(
                  child: Column(
                    mainAxisSize: MainAxisSize.min, // Ajuste la hauteur au contenu
                    children: [
                      Stack(
                        alignment: Alignment.bottomCenter,
                        children: [
                          // Ajout d'un espace par défaut pour l'icône et les bulles
                          SizedBox(
                            height: 180, // Assure un minimum d'espace
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Grande bulle de pensée
                                Card(
                                  child: Container(
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
                                    child: HashTagText(
                                      text: post.description ?? "",
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
                                SizedBox(height: 10), // Espace pour éviter que l'icône touche la bulle
                              ],
                            ),
                          ),
                          // Petites bulles de pensée
                          // Positioned(bottom: 70, left: 60, child: CircleAvatar(radius: 15, backgroundColor: Colors.white)),
                          Positioned(bottom: 50, left: 50, child: CircleAvatar(radius: 10, backgroundColor: Colors.white)),
                          Positioned(bottom: 40, left: 40, child: CircleAvatar(radius: 5, backgroundColor: Colors.white)),
                          // Icône de personne qui pense
                          Positioned(bottom: 0, left: 2, child:
                          Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child:post.canal!=null?GestureDetector(
                              onTap: () async {
                                // await  authProvider.getUserById(post.user_id!).then((users) async {
                                //   if(users.isNotEmpty){
                                //     showUserDetailsModalDialog(users.first, w, h,context);
                                //
                                //   }
                                // },);
                                Navigator.push(context, MaterialPageRoute(builder: (context) => CanalDetails(canal: post.canal!),));

                              },
                              child:
                              Row(
                                spacing: 10,
                                children: [
                                  CircleAvatar(
                                    radius: 20,

                                    backgroundImage:
                                    NetworkImage('${post.canal!.urlImage!}'),
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
                                await  authProvider.getUserById(post.user_id!).then((users) async {
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
                                    NetworkImage('${post.user!.imageUrl!}'),
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

          SizedBox(
                  height: 5,
                ),


                Visibility(
                  visible: post.dataType != PostDataType.TEXT.name
                      ? true
                      : false,
                  child: GestureDetector(
                    onTap: () {
                      // postProvider.updateVuePost(post, context);

                      Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DetailsPost(post: post),
                          ));
                    },
                    child: Container(
                      child: ClipRRect(
                        borderRadius: BorderRadius.all(Radius.circular(5)),
                        child: Container(
                          child: ImageSlideshow(

                            width: w * 0.9,
                            height: h * 0.5,

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
                            children: post!.images!.map((e) =>   CachedNetworkImage(

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
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      StatefulBuilder(builder:
                          (BuildContext context, StateSetter setState) {
                        return GestureDetector(
                          onTap: () async {
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
                                  isEqualTo: post.user_id!)
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
                                  notif.receiver_id = post.user_id!;
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
                                  await authProvider.sendNotification(
                                      userIds: [post.user!.oneIgnalUserid!],
                                      smallImage:
                                      "${authProvider.loginUserData.imageUrl!}",
                                      send_user_id:
                                      "${authProvider.loginUserData.id!}",
                                      recever_user_id: "${post.user_id!}",
                                      message:
                                      "📢 @${authProvider.loginUserData.pseudo!} a aimé votre look",
                                      type_notif:
                                      NotificationType.POST.name,
                                      post_id: "${post!.id!}",
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
                      // StatefulBuilder(builder:
                      //     (BuildContext context, StateSetter setState) {
                      //   return GestureDetector(
                      //     onTap: () async {
                      //       if (!isIn(post.users_like_id!,
                      //           authProvider.loginUserData.id!)) {
                      //         setState(() {
                      //           post.likes = post.likes! + 1;
                      //
                      //           like = post.likes!;
                      //           post.users_like_id!
                      //               .add(authProvider!.loginUserData.id!);
                      //
                      //           //loves.add(idUser);
                      //         });
                      //         CollectionReference userCollect =
                      //             FirebaseFirestore.instance
                      //                 .collection('Users');
                      //         // Get docs from collection reference
                      //         QuerySnapshot querySnapshotUser =
                      //             await userCollect
                      //                 .where("id",
                      //                     isEqualTo: post.user_id!)
                      //                 .get();
                      //         // Afficher la liste
                      //         List<UserData> listUsers = querySnapshotUser
                      //             .docs
                      //             .map((doc) => UserData.fromJson(
                      //                 doc.data() as Map<String, dynamic>))
                      //             .toList();
                      //
                      //         if (post.user!.oneIgnalUserid != null &&
                      //             post.user!.oneIgnalUserid!.length > 5) {
                      //           await authProvider.sendNotification(
                      //               userIds: [post.user!.oneIgnalUserid!],
                      //               smallImage:
                      //                   "${authProvider.loginUserData.imageUrl!}",
                      //               send_user_id:
                      //                   "${authProvider.loginUserData.id!}",
                      //               recever_user_id: "${post.user_id!}",
                      //               message:
                      //                   "📢 @${authProvider.loginUserData.pseudo!} a liké votre look",
                      //               type_notif: NotificationType.POST.name,
                      //               post_id: "${post!.id!}",
                      //               post_type: PostDataType.IMAGE.name,
                      //               chat_id: '');
                      //
                      //           NotificationData notif = NotificationData();
                      //           notif.id = firestore
                      //               .collection('Notifications')
                      //               .doc()
                      //               .id;
                      //           notif.titre = "Nouveau like 👍🏾";
                      //           notif.media_url =
                      //               authProvider.loginUserData.imageUrl;
                      //           notif.type = NotificationType.POST.name;
                      //           notif.description =
                      //               "@${authProvider.loginUserData.pseudo!} a liké votre look";
                      //           notif.users_id_view = [];
                      //           notif.user_id =
                      //               authProvider.loginUserData.id;
                      //           notif.receiver_id = post.user_id!;
                      //           notif.post_id = post.id!;
                      //           notif.post_data_type =
                      //               PostDataType.IMAGE.name!;
                      //
                      //           notif.updatedAt =
                      //               DateTime.now().microsecondsSinceEpoch;
                      //           notif.createdAt =
                      //               DateTime.now().microsecondsSinceEpoch;
                      //           notif.status = PostStatus.VALIDE.name;
                      //
                      //           // users.add(pseudo.toJson());
                      //
                      //           await firestore
                      //               .collection('Notifications')
                      //               .doc(notif.id)
                      //               .set(notif.toJson());
                      //         }
                      //         if (listUsers.isNotEmpty) {
                      //           SnackBar snackBar = SnackBar(
                      //             content: Text(
                      //               '+1 point.  Voir le classement',
                      //               textAlign: TextAlign.center,
                      //               style: TextStyle(color: Colors.green),
                      //             ),
                      //           );
                      //           ScaffoldMessenger.of(context)
                      //               .showSnackBar(snackBar);
                      //           listUsers.first!.likes =
                      //               listUsers.first!.likes! + 1;
                      //           printVm("user trouver");
                      //
                      //           //userProvider.updateUser(listUsers.first);
                      //           postProvider.updatePost(
                      //               post, listUsers.first, context);
                      //           await authProvider.getAppData();
                      //           authProvider.appDefaultData.nbr_likes =
                      //               authProvider.appDefaultData.nbr_likes! +
                      //                   1;
                      //           authProvider.updateAppData(
                      //               authProvider.appDefaultData);
                      //         } else {
                      //           SnackBar snackBar = SnackBar(
                      //             content: Text(
                      //               '+1 point.  Voir le classement',
                      //               textAlign: TextAlign.center,
                      //               style: TextStyle(color: Colors.green),
                      //             ),
                      //           );
                      //           ScaffoldMessenger.of(context)
                      //               .showSnackBar(snackBar);
                      //           post.user!.likes = post.user!.likes! + 1;
                      //           postProvider.updatePost(
                      //               post, post.user!, context);
                      //           await authProvider.getAppData();
                      //           authProvider.appDefaultData.nbr_likes =
                      //               authProvider.appDefaultData.nbr_likes! +
                      //                   1;
                      //           authProvider.updateAppData(
                      //               authProvider.appDefaultData);
                      //         }
                      //       }
                      //
                      //       setState(() {
                      //         //loves.add(idUser);
                      //       });
                      //     },
                      //     child: Container(
                      //       width: 70,
                      //       height: 30,
                      //       child: Row(
                      //         crossAxisAlignment: CrossAxisAlignment.center,
                      //         // mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      //         children: [
                      //           Row(
                      //             children: [
                      //               Icon(
                      //                 isIn(
                      //                         post.users_like_id!,
                      //                         authProvider
                      //                             .loginUserData.id!)
                      //                     ? MaterialCommunityIcons.thumb_up
                      //                     : MaterialCommunityIcons
                      //                         .thumb_up_outline,
                      //                 size: 20,
                      //                 color: isIn(
                      //                         post.users_like_id!,
                      //                         authProvider
                      //                             .loginUserData.id!)
                      //                     ? Colors.blue
                      //                     : Colors.black,
                      //               ),
                      //               Padding(
                      //                 padding: const EdgeInsets.only(
                      //                     left: 1.0, right: 1),
                      //                 child: TextCustomerPostDescription(
                      //                   titre: "${formatAbonnes(like)}",
                      //                   fontSize: SizeText
                      //                       .homeProfileDateTextSize,
                      //                   couleur: ConstColors.textColors,
                      //                   fontWeight: FontWeight.bold,
                      //                 ),
                      //               ),
                      //             ],
                      //           ),
                      //           /*
                      //           Expanded(
                      //             child: Padding(
                      //               padding: const EdgeInsets.only(left: 1.0,right: 1),
                      //               child: SizedBox(
                      //                 height: 2,
                      //                 // width: width*0.75,
                      //                 child: LinearProgressIndicator(
                      //                   color: Colors.blue,
                      //                   value: like/post.user!.abonnes!+1,
                      //                   semanticsLabel: 'Linear progress indicator',
                      //                 ),
                      //               ),
                      //             ),
                      //           ),
                      //           TextCustomerPostDescription(
                      //             titre: "${(like/post.user!.abonnes!+1).toStringAsFixed(2)}%",
                      //             fontSize: SizeText.homeProfileDateTextSize,
                      //             couleur: ConstColors.textColors,
                      //             fontWeight: FontWeight.bold,
                      //           ),
                      //
                      //            */
                      //         ],
                      //       ),
                      //     ),
                      //   );
                      // }),
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
                                  isEqualTo: post.user_id!)
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
                                  notif.receiver_id = post.user_id!;
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
                                  await authProvider.sendNotification(
                                      userIds: [post.user!.oneIgnalUserid!],
                                      smallImage:
                                      "${authProvider.loginUserData.imageUrl!}",
                                      send_user_id:
                                      "${authProvider.loginUserData.id!}",
                                      recever_user_id: "${post.user_id!}",
                                      message:
                                      "📢 @${authProvider.loginUserData.pseudo!} a partagé votre look",
                                      type_notif:
                                      NotificationType.POST.name,
                                      post_id: "${post!.id!}",
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
        }),
  );
}




Widget homeChallengePostUsers(Challenge challenge,Post post,Color color, double height, double width,BuildContext context) {
  double h = MediaQuery.of(context).size.height;
  double w = MediaQuery.of(context).size.width;
  late UserAuthProvider authProvider =
  Provider.of<UserAuthProvider>(context, listen: false);

  late PostProvider postProvider =
  Provider.of<PostProvider>(context, listen: false);
  late CategorieProduitProvider categorieProduitProvider =
  Provider.of<CategorieProduitProvider>(context, listen: false);
  late UserProvider userProvider =
  Provider.of<UserProvider>(context, listen: false);
  final FirebaseFirestore firestore = FirebaseFirestore.instance;


 newLookChallenge() async {

   String challengeId = FirebaseFirestore.instance.collection('LookChallenges').doc().id;

   // Créer un objet Challenge
   LookChallenge lookchallenge = LookChallenge()
     ..id = challengeId  // Ajoutez un titre au challenge
     ..user_id = authProvider.loginUserData.id!
     ..challenge_id = challenge.id!
     ..postChallengeId = post.id!
     ..jaime = 0
     ..partage = 0
     ..vues = 0
     ..usersPartagesIds = []
     ..usersLovesIds = []
     ..usersVuesIds = []
     ..statut = StatutData.ATTENTE.name
     ..createdAt = DateTime.now().millisecondsSinceEpoch
     ..updatedAt = DateTime.now().millisecondsSinceEpoch;


   await FirebaseFirestore.instance.collection('LookChallenges').doc(challengeId).set(lookchallenge.toJson());

   await postProvider.getChallengeById(challenge!.id!).then((value) async {
     if(value.isNotEmpty){
       challenge=value.first;
       if(!challenge.postsIds!.any((element) => element==post.id!,)){
         challenge.postsIds!.add(post.id!);
         challenge.usersChallengersIds=  challenge.usersChallengersIds==null?[]:challenge.usersChallengersIds!;
         {
           if(!challenge.usersChallengersIds!.any((element) => element==authProvider.loginUserData.id!,)){
             challenge.usersChallengersIds!.add(authProvider.loginUserData.id!);
           }
           await postProvider.updateChallenge(challenge);

           showDialog(
             context: context,
             builder: (context2) => AlertDialog(
               title: Text('Félicitations 🎉'),
               content: Text(
                   '✨ Félicitations ! Vous venez de soumettre votre look pour participer à ce challenge. 🎯 Retrouvez vos challenges dans le menu "Mes challenges" 🏆 et partagez le lien de vos challenges 🌍 pour obtenir plus de j\'aime ❤️, commentaires 💬 et partages 🔄 ! Ces interactions calculeront la popularité de votre look challenge. ⭐ Bonne chance et que le meilleur gagne ! 🍀🏅'),
               actions: [
                 TextButton(
                   onPressed: () => Navigator.of(context2).pop(),
                   child: Text('OK 👍'),
                 ),
               ],
             ),
           );


         }



       }

     }
   },);


     // Navigator.of(context1).pop(); // Fermer le dialog

 }

  Random random = Random();
  bool isLoading = false;

  int like = post!.likes!;
  int imageIndex = 0;
  int love = post!.loves!;
  int vue = post!.vues!;
  int comments = post!.comments!;
  bool tapLove = isIn(post.users_love_id!, authProvider.loginUserData.id!);
  bool tapLike = isIn(post.users_like_id!, authProvider.loginUserData.id!);
  List<int> likes = [];
  List<int> loves = [];
  int idUser = 7;
  // Calculer la taille du texte en fonction de la longueur de la description
  double baseFontSize = 20.0;
  double scale = post.description!.length / 1000;  // Ajustez ce facteur selon vos besoins
  double fontSize = baseFontSize - scale;

  // Limiter la taille de la police à une valeur minimale
  fontSize = fontSize < 15 ? 15 : fontSize;
  int limitePosts = 30;
  printVm("post.user!.role :${post.type} ${post.user!.role}");



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
                          child:  GestureDetector(
                            onTap: () async {
                              await  authProvider.getUserById(post.user_id!).then((users) async {
                                if(users.isNotEmpty){
                                  showUserDetailsModalDialog(users.first, w, h,context);

                                }
                              },);

                            },
                            child:
                            CircleAvatar(

                              backgroundImage:
                              NetworkImage('${post.user!.imageUrl!}'),
                            ),
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
                                Row(
                                  children: [
                                    Column(
                                      children: [
                                        TextCustomerUserTitle(
                                          titre:
                                          "${formatNumber(post.user!.userlikes!)} like(s)",
                                          fontSize: SizeText.homeProfileTextSize,
                                          couleur: Colors.green,
                                          fontWeight: FontWeight.w700,
                                        ),

                                        TextCustomerUserTitle(
                                          titre:
                                          "${formatNumber(post.user!.userAbonnesIds!.length)} abonné(s)",
                                          fontSize: SizeText.homeProfileTextSize,
                                          couleur: ConstColors.textColors,
                                          fontWeight: FontWeight.w400,
                                        ),

                                      ],
                                    ),
                                    // countryFlag(post.user!.countryData!['countryCode']??"Tg"!, size: 15),

                                  ],
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
                        SizedBox(width: 10,),



                      ],
                    ),

                        ElevatedButton(
                            onPressed: () async {



                              await postProvider.getChallengeById(challenge!.id!).then((value) {
                                if(value.isNotEmpty){
                                  challenge=value.first;
                                  // Logique à exécuter lorsque l'utilisateur appuie sur le bouton

                                  if(!isIn(challenge.postsIds==null?[]:challenge.postsIds!, post.id!)){

                                      if(!isIn(challenge.usersChallengersIds==null?[]:challenge.usersChallengersIds!, authProvider.loginUserData.id!)){
                                        showDialog(
                                          context: context,
                                          builder: (BuildContext context1) {

                                            return AlertDialog(
                                              title: Text("Confirmer votre choix"),
                                              content: Text("Voulez-vous utiliser ce look pour le challenge ?"),
                                              actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.of(context1).pop(); // Fermer le dialog
                          },
                          child: Text("Non"),
                        ),
                       ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green, // Couleur verte
                            foregroundColor: Colors.white, // Texte blanc
                          ),
                          onPressed: () async {
                            setStateImages((){
                              isLoading=true;
                            });
                             newLookChallenge().then((value) {

                            },);

                            setStateImages((){
                              isLoading=false;
                              Navigator.of(context1).pop(); // Fermer le dialog

                            });
                            // Ajouter ici l'action à exécuter pour confirmer
                          },
                          child: Text("Oui"),
                        ),
                                              ],
                                            );
                                          },
                                        );
                                      }else{
                                        showDialog(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: Text('Challenge 🔥🎁'),
                                            content: Text(

                                            "Vous participez déjà à ce challenge avec un autre look. Il est possible de soumettre uniquement un seul look par challenge."                ),
                                            actions: [
                                              TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text('OK'),
                                              ),
                                            ],
                                          ),
                                        );
                                      }
                                    // checkChallengeStatus(context,widget.challenge,);

                                  }else{
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: Text('Challenge 🔥🎁'),
                                          content: Text('Ce look fait déjà partie du challenge. Vous ne pouvez soumettre qu\'un seul look par challenge.'),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.of(context).pop(),
                                            child: Text('OK'),
                                          ),
                                        ],
                                      ),
                                    );                                            }



                                }
                              },);


                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor:isIn(challenge.postsIds==null?[]:challenge.postsIds!, authProvider.loginUserData.id!)?Colors.red.shade100: Colors.green, // Couleur de fond verte
                              // onPrimary: Colors.white, // Couleur du texte (blanc)
                              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15), // Padding pour le bouton
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10), // Coins arrondis
                              ),
                            ),
                            child:Text(
                              'Choisir votre look', // Texte du bouton
                              style: TextStyle(
                                fontSize: 12, //
                                color: Colors.white,// Taille du texte
                                fontWeight: FontWeight.bold, // Texte en gras
                              ),
                            )
                        ),


                    // IconButton(
                    //     onPressed: () {
                    //       _showPostMenuModalDialog(post,context);
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
                        Text(" Publicité",style: TextStyle(fontSize: 12,fontWeight: FontWeight.w900),),
                      ],
                    )
                ),

                SizedBox(
                  height: 5,
                ),
                Visibility(
                  visible: post.dataType != PostDataType.TEXT.name
                      ? true
                      : false,
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: SizedBox(
                      width:post.type==PostType.PUB.name?width*0.82: width * 0.8,
                      child: Container(
                        alignment: Alignment.centerLeft,
                        child:SizedBox(
                          height:post.type==PostType.PUB.name?70: 60,

                          child: SingleChildScrollView(
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
                                HashTagText(
                                  text: "${post.description}",
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
                        ),
                        // TextCustomerPostDescription(
                        //   titre: "${post.description}",
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
                      "${formaterDateTime(DateTime.fromMicrosecondsSinceEpoch(post.createdAt!))}",
                      fontSize: SizeText.homeProfileDateTextSize,
                      couleur: ConstColors.textColors,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Visibility(
                  visible: post.dataType == PostDataType.TEXT.name
                      ? true
                      : false,
                  child: GestureDetector(
                    onTap: () {
                      // postProvider.updateVuePost(post, context);

                      Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DetailsPost(post: post),
                          ));
                    },
                    child: Container(
                      color: color,
                      child: Align(
                        alignment: Alignment.center,
                        child: SizedBox(
                          width: width * 0.8,
                          height: height * 0.5,
                          child: Container(
                            // height: 200,
                            constraints: BoxConstraints(
                              // minHeight: 100.0, // Set your minimum height
                              maxHeight:
                              height * 0.6, // Set your maximum height
                            ),
                            alignment: Alignment.center,
                            child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Center(
                                  child: HashTagText(
                                    text: "${post.description}",
                                    decoratedStyle: TextStyle(
                                      fontSize: fontSize,

                                      fontWeight: FontWeight.w600,

                                      color: Colors.green,
                                      fontFamily: 'Nunito', // Définir la police Nunito
                                    ),
                                    basicStyle: TextStyle(
                                      fontSize: fontSize,
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
                                )),
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
                  visible: post.dataType != PostDataType.TEXT.name
                      ? true
                      : false,
                  child: Stack(
                    children: [
                      GestureDetector(
                        onTap: () {
                          // postProvider.updateVuePost(post, context);

                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => DetailsPost(post: post),
                              ));
                        },
                        child: Container(
                          child: ClipRRect(
                            borderRadius: BorderRadius.all(Radius.circular(5)),
                            child: Container(
                              child: ImageSlideshow(

                                width: w * 0.9,
                                height: h * 0.5,

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
                                children: post!.images!.map((e) =>   CachedNetworkImage(

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

                      if (isLoading)
                        Container(
                          width: w * 0.9,
                          height: h * 0.5,
                          color: Colors.black.withOpacity(0.5),
                          child: Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                        ),
                    ],
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
                          onTap: () async {
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
                                  isEqualTo: post.user_id!)
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
                                  notif.receiver_id = post.user_id!;
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
                                  await authProvider.sendNotification(
                                      userIds: [post.user!.oneIgnalUserid!],
                                      smallImage:
                                      "${authProvider.loginUserData.imageUrl!}",
                                      send_user_id:
                                      "${authProvider.loginUserData.id!}",
                                      recever_user_id: "${post.user_id!}",
                                      message:
                                      "📢 @${authProvider.loginUserData.pseudo!} a aimé votre look",
                                      type_notif:
                                      NotificationType.POST.name,
                                      post_id: "${post!.id!}",
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
                      // StatefulBuilder(builder:
                      //     (BuildContext context, StateSetter setState) {
                      //   return GestureDetector(
                      //     onTap: () async {
                      //       if (!isIn(post.users_like_id!,
                      //           authProvider.loginUserData.id!)) {
                      //         setState(() {
                      //           post.likes = post.likes! + 1;
                      //
                      //           like = post.likes!;
                      //           post.users_like_id!
                      //               .add(authProvider!.loginUserData.id!);
                      //
                      //           //loves.add(idUser);
                      //         });
                      //         CollectionReference userCollect =
                      //             FirebaseFirestore.instance
                      //                 .collection('Users');
                      //         // Get docs from collection reference
                      //         QuerySnapshot querySnapshotUser =
                      //             await userCollect
                      //                 .where("id",
                      //                     isEqualTo: post.user_id!)
                      //                 .get();
                      //         // Afficher la liste
                      //         List<UserData> listUsers = querySnapshotUser
                      //             .docs
                      //             .map((doc) => UserData.fromJson(
                      //                 doc.data() as Map<String, dynamic>))
                      //             .toList();
                      //
                      //         if (post.user!.oneIgnalUserid != null &&
                      //             post.user!.oneIgnalUserid!.length > 5) {
                      //           await authProvider.sendNotification(
                      //               userIds: [post.user!.oneIgnalUserid!],
                      //               smallImage:
                      //                   "${authProvider.loginUserData.imageUrl!}",
                      //               send_user_id:
                      //                   "${authProvider.loginUserData.id!}",
                      //               recever_user_id: "${post.user_id!}",
                      //               message:
                      //                   "📢 @${authProvider.loginUserData.pseudo!} a liké votre look",
                      //               type_notif: NotificationType.POST.name,
                      //               post_id: "${post!.id!}",
                      //               post_type: PostDataType.IMAGE.name,
                      //               chat_id: '');
                      //
                      //           NotificationData notif = NotificationData();
                      //           notif.id = firestore
                      //               .collection('Notifications')
                      //               .doc()
                      //               .id;
                      //           notif.titre = "Nouveau like 👍🏾";
                      //           notif.media_url =
                      //               authProvider.loginUserData.imageUrl;
                      //           notif.type = NotificationType.POST.name;
                      //           notif.description =
                      //               "@${authProvider.loginUserData.pseudo!} a liké votre look";
                      //           notif.users_id_view = [];
                      //           notif.user_id =
                      //               authProvider.loginUserData.id;
                      //           notif.receiver_id = post.user_id!;
                      //           notif.post_id = post.id!;
                      //           notif.post_data_type =
                      //               PostDataType.IMAGE.name!;
                      //
                      //           notif.updatedAt =
                      //               DateTime.now().microsecondsSinceEpoch;
                      //           notif.createdAt =
                      //               DateTime.now().microsecondsSinceEpoch;
                      //           notif.status = PostStatus.VALIDE.name;
                      //
                      //           // users.add(pseudo.toJson());
                      //
                      //           await firestore
                      //               .collection('Notifications')
                      //               .doc(notif.id)
                      //               .set(notif.toJson());
                      //         }
                      //         if (listUsers.isNotEmpty) {
                      //           SnackBar snackBar = SnackBar(
                      //             content: Text(
                      //               '+1 point.  Voir le classement',
                      //               textAlign: TextAlign.center,
                      //               style: TextStyle(color: Colors.green),
                      //             ),
                      //           );
                      //           ScaffoldMessenger.of(context)
                      //               .showSnackBar(snackBar);
                      //           listUsers.first!.likes =
                      //               listUsers.first!.likes! + 1;
                      //           printVm("user trouver");
                      //
                      //           //userProvider.updateUser(listUsers.first);
                      //           postProvider.updatePost(
                      //               post, listUsers.first, context);
                      //           await authProvider.getAppData();
                      //           authProvider.appDefaultData.nbr_likes =
                      //               authProvider.appDefaultData.nbr_likes! +
                      //                   1;
                      //           authProvider.updateAppData(
                      //               authProvider.appDefaultData);
                      //         } else {
                      //           SnackBar snackBar = SnackBar(
                      //             content: Text(
                      //               '+1 point.  Voir le classement',
                      //               textAlign: TextAlign.center,
                      //               style: TextStyle(color: Colors.green),
                      //             ),
                      //           );
                      //           ScaffoldMessenger.of(context)
                      //               .showSnackBar(snackBar);
                      //           post.user!.likes = post.user!.likes! + 1;
                      //           postProvider.updatePost(
                      //               post, post.user!, context);
                      //           await authProvider.getAppData();
                      //           authProvider.appDefaultData.nbr_likes =
                      //               authProvider.appDefaultData.nbr_likes! +
                      //                   1;
                      //           authProvider.updateAppData(
                      //               authProvider.appDefaultData);
                      //         }
                      //       }
                      //
                      //       setState(() {
                      //         //loves.add(idUser);
                      //       });
                      //     },
                      //     child: Container(
                      //       width: 70,
                      //       height: 30,
                      //       child: Row(
                      //         crossAxisAlignment: CrossAxisAlignment.center,
                      //         // mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      //         children: [
                      //           Row(
                      //             children: [
                      //               Icon(
                      //                 isIn(
                      //                         post.users_like_id!,
                      //                         authProvider
                      //                             .loginUserData.id!)
                      //                     ? MaterialCommunityIcons.thumb_up
                      //                     : MaterialCommunityIcons
                      //                         .thumb_up_outline,
                      //                 size: 20,
                      //                 color: isIn(
                      //                         post.users_like_id!,
                      //                         authProvider
                      //                             .loginUserData.id!)
                      //                     ? Colors.blue
                      //                     : Colors.black,
                      //               ),
                      //               Padding(
                      //                 padding: const EdgeInsets.only(
                      //                     left: 1.0, right: 1),
                      //                 child: TextCustomerPostDescription(
                      //                   titre: "${formatAbonnes(like)}",
                      //                   fontSize: SizeText
                      //                       .homeProfileDateTextSize,
                      //                   couleur: ConstColors.textColors,
                      //                   fontWeight: FontWeight.bold,
                      //                 ),
                      //               ),
                      //             ],
                      //           ),
                      //           /*
                      //           Expanded(
                      //             child: Padding(
                      //               padding: const EdgeInsets.only(left: 1.0,right: 1),
                      //               child: SizedBox(
                      //                 height: 2,
                      //                 // width: width*0.75,
                      //                 child: LinearProgressIndicator(
                      //                   color: Colors.blue,
                      //                   value: like/post.user!.abonnes!+1,
                      //                   semanticsLabel: 'Linear progress indicator',
                      //                 ),
                      //               ),
                      //             ),
                      //           ),
                      //           TextCustomerPostDescription(
                      //             titre: "${(like/post.user!.abonnes!+1).toStringAsFixed(2)}%",
                      //             fontSize: SizeText.homeProfileDateTextSize,
                      //             couleur: ConstColors.textColors,
                      //             fontWeight: FontWeight.bold,
                      //           ),
                      //
                      //            */
                      //         ],
                      //       ),
                      //     ),
                      //   );
                      // }),
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
                                  isEqualTo: post.user_id!)
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
                                  notif.receiver_id = post.user_id!;
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
                                  await authProvider.sendNotification(
                                      userIds: [post.user!.oneIgnalUserid!],
                                      smallImage:
                                      "${authProvider.loginUserData.imageUrl!}",
                                      send_user_id:
                                      "${authProvider.loginUserData.id!}",
                                      recever_user_id: "${post.user_id!}",
                                      message:
                                      "📢 @${authProvider.loginUserData.pseudo!} a partagé votre look",
                                      type_notif:
                                      NotificationType.POST.name,
                                      post_id: "${post!.id!}",
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
        }),
  );
}


Color _getBackgroundColor(String status) {
  switch (status) {
    case "ATTENTE":
      return Colors.orange.shade100;
    case "ENCOURS":
      return Colors.green.shade100;
    case "TERMINER":
      return Colors.grey.shade300;
    default:
      return Colors.grey.shade200;
  }
}

Color _getTextColor(String status) {
  switch (status) {
    case "ATTENTE":
      return Colors.orange;
    case "ENCOURS":
      return Colors.green;
    case "TERMINER":
      return Colors.black87;
    default:
      return Colors.black54;
  }
}

String _getStatusText(String status) {
  switch (status) {
    case "ATTENTE":
      return "En attente...";
    case "ENCOURS":
      return "En live";
    case "TERMINER":
      return "Terminé";
    default:
      return "Inconnu";
  }
}

Widget homeChallenge(Challenge challenge,Color color, double height, double width,BuildContext context) {
  double h = MediaQuery.of(context).size.height;
  double w = MediaQuery.of(context).size.width;
  late UserAuthProvider authProvider =
  Provider.of<UserAuthProvider>(context, listen: false);

  late PostProvider postProvider =
  Provider.of<PostProvider>(context, listen: false);
  late CategorieProduitProvider categorieProduitProvider =
  Provider.of<CategorieProduitProvider>(context, listen: false);
  late UserProvider userProvider =
  Provider.of<UserProvider>(context, listen: false);
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  Post post=challenge!.postChallenge!;


  Random random = Random();
  bool abonneTap = false;
  int like = post!.likes!;
  int imageIndex = 0;
  int love = post!.loves!;
  int vue = post!.vues!;
  int comments = post!.comments!;
  bool tapLove = isIn(post.users_love_id!, authProvider.loginUserData.id!);
  bool tapLike = isIn(post.users_like_id!, authProvider.loginUserData.id!);
  List<int> likes = [];
  List<int> loves = [];
  int idUser = 7;
  // Calculer la taille du texte en fonction de la longueur de la description
  double baseFontSize = 20.0;
  double scale = post.description!.length / 1000;  // Ajustez ce facteur selon vos besoins
  double fontSize = baseFontSize - scale;

  // Limiter la taille de la police à une valeur minimale
  fontSize = fontSize < 15 ? 15 : fontSize;
  int limitePosts = 30;


  return Container(
    child: StatefulBuilder(
        builder: (BuildContext context, StateSetter setStateImages) {
          return Padding(
            padding: const EdgeInsets.all(5.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Row(
                //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                //   children: [
                //     Row(
                //       children: [
                //         Padding(
                //           padding: const EdgeInsets.only(right: 8.0),
                //           child:  GestureDetector(
                //             onTap: () async {
                //               await  authProvider.getUserById(post.user_id!).then((users) async {
                //                 if(users.isNotEmpty){
                //                   showUserDetailsModalDialog(users.first, w, h,context);
                //
                //                 }
                //               },);
                //
                //             },
                //             child:
                //             CircleAvatar(
                //
                //               backgroundImage:
                //               NetworkImage('${post.user!.imageUrl!}'),
                //             ),
                //           ),
                //         ),
                //         SizedBox(
                //           height: 2,
                //         ),
                //         Row(
                //           children: [
                //             Column(
                //               crossAxisAlignment: CrossAxisAlignment.start,
                //               children: [
                //                 SizedBox(
                //                   //width: 100,
                //                   child: TextCustomerUserTitle(
                //                     titre: "@${post.user!.pseudo!}",
                //                     fontSize: SizeText.homeProfileTextSize,
                //                     couleur: ConstColors.textColors,
                //                     fontWeight: FontWeight.bold,
                //                   ),
                //                 ),
                //                 Row(
                //                   children: [
                //                     Column(
                //                       children: [
                //                         TextCustomerUserTitle(
                //                           titre:
                //                           "${formatNumber(post.user!.userlikes!)} like(s)",
                //                           fontSize: SizeText.homeProfileTextSize,
                //                           couleur: Colors.green,
                //                           fontWeight: FontWeight.w700,
                //                         ),
                //
                //                         TextCustomerUserTitle(
                //                           titre:
                //                           "${formatNumber(post.user!.abonnes!)} abonné(s)",
                //                           fontSize: SizeText.homeProfileTextSize,
                //                           couleur: ConstColors.textColors,
                //                           fontWeight: FontWeight.w400,
                //                         ),
                //
                //                       ],
                //                     ),
                //                     // countryFlag(post.user!.countryData!['countryCode']??"Tg"!, size: 15),
                //
                //                   ],
                //                 ),
                //               ],
                //             ),
                //             Visibility(
                //               visible:authProvider.loginUserData.id!=post.user!.id ,
                //
                //               child: StatefulBuilder(builder: (BuildContext context,
                //                   void Function(void Function()) setState) {
                //                 return Container(
                //                   child: isUserAbonne(
                //                       post.user!.userAbonnesIds!,
                //                       authProvider.loginUserData.id!)
                //                       ? Container()
                //                       : TextButton(
                //                       onPressed: abonneTap
                //                           ? () {}
                //                           : () async {
                //                         setState(() {
                //                           abonneTap=true;
                //                         });
                //                         await authProvider.abonner(post.user!,context).then((value) {
                //
                //                         },);
                //                         setState(() {
                //                           abonneTap=false;
                //                         });
                //                         //
                //                         // if (!isUserAbonne(
                //                         //     post.user!
                //                         //         .userAbonnesIds!,
                //                         //     authProvider
                //                         //         .loginUserData
                //                         //         .id!))
                //                         // {
                //                         //   setState(() {
                //                         //     abonneTap = true;
                //                         //   });
                //                         //   UserAbonnes userAbonne =
                //                         //   UserAbonnes();
                //                         //   userAbonne.compteUserId =
                //                         //       authProvider
                //                         //           .loginUserData.id;
                //                         //   userAbonne.abonneUserId =
                //                         //       post.user!.id;
                //                         //
                //                         //   userAbonne
                //                         //       .createdAt = DateTime
                //                         //       .now()
                //                         //       .millisecondsSinceEpoch;
                //                         //   userAbonne
                //                         //       .updatedAt = DateTime
                //                         //       .now()
                //                         //       .millisecondsSinceEpoch;
                //                         //   await userProvider
                //                         //       .sendAbonnementRequest(
                //                         //       userAbonne,
                //                         //       post.user!,
                //                         //       context)
                //                         //       .then(
                //                         //         (value) async {
                //                         //       if (value) {
                //                         //         authProvider
                //                         //             .loginUserData
                //                         //             .userAbonnes!
                //                         //             .add(
                //                         //             userAbonne);
                //                         //         // await userProvider.getUsers(authProvider.loginUserData!.id!);
                //                         //         await authProvider
                //                         //             .getCurrentUser(
                //                         //             authProvider
                //                         //                 .loginUserData!
                //                         //                 .id!);
                //                         //         await  authProvider.getUserById(post.user_id!).then((users) async {
                //                         //           if(users.isNotEmpty){
                //                         //             // users.first.abonnes=users.first.abonnes!+1;
                //                         //             users.first.userAbonnesIds!.add(authProvider.loginUserData.id!);
                //                         //             // post.user!.userAbonnesIds!.add(authProvider.loginUserData.id!);
                //                         //
                //                         //             post.user!= users.first;
                //                         //
                //                         //             post.user!.abonnes=post.user!.userAbonnesIds!.length;
                //                         //             // post.user!= users.first;
                //                         //
                //                         //             await userProvider.updateUser(post.user!);
                //                         //             // setState(() {
                //                         //             //   abonneTap=false;
                //                         //             //
                //                         //             // });
                //                         //           }
                //                         //         },);
                //                         //
                //                         //         // post.user!
                //                         //         //     .abonnes= post.user!
                //                         //         //     .abonnes!+1;
                //                         //         // post.user!
                //                         //         //     .userAbonnesIds!
                //                         //         //     .add(authProvider
                //                         //         //     .loginUserData
                //                         //         //     .id!);
                //                         //         // userProvider
                //                         //         //     .updateUser(
                //                         //         //     post.user!);
                //                         //         if (post.user!
                //                         //             .oneIgnalUserid !=
                //                         //             null &&
                //                         //             post
                //                         //                 .user!
                //                         //                 .oneIgnalUserid!
                //                         //                 .length >
                //                         //                 5) {
                //                         //           await authProvider.sendNotification(
                //                         //               userIds: [
                //                         //                 post.user!
                //                         //                     .oneIgnalUserid!
                //                         //               ],
                //                         //               smallImage:
                //                         //               "${authProvider.loginUserData.imageUrl!}",
                //                         //               send_user_id:
                //                         //               "${authProvider.loginUserData.id!}",
                //                         //               recever_user_id:
                //                         //               "${post.user_id!}",
                //                         //               message:
                //                         //               "📢 @${authProvider.loginUserData.pseudo!} s'est abonné(e) à votre compte",
                //                         //               type_notif:
                //                         //               NotificationType
                //                         //                   .ABONNER
                //                         //                   .name,
                //                         //               post_id:
                //                         //               "${post!.id!}",
                //                         //               post_type:
                //                         //               PostDataType
                //                         //                   .IMAGE
                //                         //                   .name,
                //                         //               chat_id: '');
                //                         //           NotificationData
                //                         //           notif =
                //                         //           NotificationData();
                //                         //           notif.id = firestore
                //                         //               .collection(
                //                         //               'Notifications')
                //                         //               .doc()
                //                         //               .id;
                //                         //           notif.titre =
                //                         //           "Nouveau Abonnement ✅";
                //                         //           notif.media_url =
                //                         //               authProvider
                //                         //                   .loginUserData
                //                         //                   .imageUrl;
                //                         //           notif.type =
                //                         //               NotificationType
                //                         //                   .ABONNER
                //                         //                   .name;
                //                         //           notif.description =
                //                         //           "@${authProvider.loginUserData.pseudo!} s'est abonné(e) à votre compte";
                //                         //           notif.users_id_view =
                //                         //           [];
                //                         //           notif.user_id =
                //                         //               authProvider
                //                         //                   .loginUserData
                //                         //                   .id;
                //                         //           notif.receiver_id =
                //                         //           post.user!
                //                         //               .id!;
                //                         //           notif.post_id =
                //                         //           post.id!;
                //                         //           notif.post_data_type =
                //                         //           PostDataType
                //                         //               .IMAGE
                //                         //               .name!;
                //                         //           notif.updatedAt =
                //                         //               DateTime.now()
                //                         //                   .microsecondsSinceEpoch;
                //                         //           notif.createdAt =
                //                         //               DateTime.now()
                //                         //                   .microsecondsSinceEpoch;
                //                         //           notif.status =
                //                         //               PostStatus
                //                         //                   .VALIDE
                //                         //                   .name;
                //                         //
                //                         //           // users.add(pseudo.toJson());
                //                         //
                //                         //           await firestore
                //                         //               .collection(
                //                         //               'Notifications')
                //                         //               .doc(notif.id)
                //                         //               .set(notif
                //                         //               .toJson());
                //                         //         }
                //                         //         SnackBar snackBar =
                //                         //         SnackBar(
                //                         //           content: Text(
                //                         //             'abonné, Bravo ! Vous avez gagné 4 points.',
                //                         //             textAlign:
                //                         //             TextAlign
                //                         //                 .center,
                //                         //             style: TextStyle(
                //                         //                 color: Colors
                //                         //                     .green),
                //                         //           ),
                //                         //         );
                //                         //         ScaffoldMessenger
                //                         //             .of(context)
                //                         //             .showSnackBar(
                //                         //             snackBar);
                //                         //         setState(() {
                //                         //           abonneTap = false;
                //                         //         });
                //                         //       } else {
                //                         //         SnackBar snackBar =
                //                         //         SnackBar(
                //                         //           content: Text(
                //                         //             'une erreur',
                //                         //             textAlign:
                //                         //             TextAlign
                //                         //                 .center,
                //                         //             style: TextStyle(
                //                         //                 color: Colors
                //                         //                     .red),
                //                         //           ),
                //                         //         );
                //                         //         ScaffoldMessenger
                //                         //             .of(context)
                //                         //             .showSnackBar(
                //                         //             snackBar);
                //                         //         setState(() {
                //                         //           abonneTap = false;
                //                         //         });
                //                         //       }
                //                         //     },
                //                         //   );
                //                         //
                //                         //   setState(() {
                //                         //     abonneTap = false;
                //                         //   });
                //                         // }
                //                       },
                //                       child: abonneTap
                //                           ? Center(
                //                         child:
                //                         LoadingAnimationWidget
                //                             .flickr(
                //                           size: 20,
                //                           leftDotColor:
                //                           Colors.green,
                //                           rightDotColor:
                //                           Colors.black,
                //                         ),
                //                       )
                //                           : Text(
                //                         "S'abonner",
                //                         style: TextStyle(
                //                             fontSize: 12,
                //                             fontWeight:
                //                             FontWeight.normal,
                //                             color: Colors.blue),
                //                       )),
                //                 );
                //               }),
                //             ),
                //             /*
                //             IconButton(
                //                 onPressed: () {},
                //                 icon: Icon(
                //                   Icons.add_circle_outlined,
                //                   size: 20,
                //                   color: ConstColors.regIconColors,
                //                 )),
                //
                //              */
                //           ],
                //         ),
                //         SizedBox(width: 10,),
                //
                //
                //
                //       ],
                //     ),
                //     IconButton(
                //         onPressed: () {
                //           _showPostMenuModalDialog(post,context);
                //         },
                //         icon: Icon(
                //           Icons.more_horiz,
                //           size: 30,
                //           color: ConstColors.blackIconColors,
                //         )),
                //   ],
                // ),
                Visibility(
                    visible: post.type==PostType.PUB.name,
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
                // Padding(
                //   padding: const EdgeInsets.all(4.0),
                //   child: HashTagText(
                //     text: "${post.description}",
                //     decoratedStyle: TextStyle(
                //       fontSize: 13,
                //       fontWeight: FontWeight.w600,
                //
                //       color: Colors.green,
                //       fontFamily: 'Nunito', // Définir la police Nunito
                //     ),
                //     basicStyle: TextStyle(
                //       fontSize: 12,
                //       color: Colors.black87,
                //       fontWeight: FontWeight.normal,
                //       fontFamily: 'Nunito', // Définir la police Nunito
                //     ),
                //     textAlign: TextAlign.left, // Centrage du texte
                //     maxLines: null, // Permet d'afficher le texte sur plusieurs lignes si nécessaire
                //     softWrap: true, // Assure que le texte se découpe sur plusieurs lignes si nécessaire
                //     // overflow: TextOverflow.ellipsis, // Ajoute une ellipse si le texte dépasse
                //     onTap: (text) {
                //       print(text);
                //     },
                //   ),
                // ),
                SizedBox(
                  height: 50,
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: HashTagText(
                      text: "${challenge.postChallenge!.description}",
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
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: TextCustomerPostDescription(
                      titre:
                      "${formaterDateTime(DateTime.fromMicrosecondsSinceEpoch(post.createdAt!))}",
                      fontSize: SizeText.homeProfileDateTextSize,
                      couleur: ConstColors.textColors,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Visibility(
                  visible: post.dataType == PostDataType.TEXT.name
                      ? true
                      : false,
                  child: GestureDetector(
                    onTap: () {
                      // postProvider.updateVuePost(post, context);

                      Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DetailsPost(post: post),
                          ));
                    },
                    child: Container(
                      color: color,
                      child: Align(
                        alignment: Alignment.center,
                        child: SizedBox(
                          // width: width * 0.8,
                          // height: height * 0.5,
                          child: Container(
                            // height: 200,
                            // constraints: BoxConstraints(
                            //   // minHeight: 100.0, // Set your minimum height
                            //   maxHeight:
                            //   height * 0.6, // Set your maximum height
                            // ),
                            alignment: Alignment.centerLeft,
                            child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Center(
                                  child: HashTagText(
                                    text: "${post.description}",
                                    decoratedStyle: TextStyle(
                                      fontSize: fontSize,

                                      fontWeight: FontWeight.w600,

                                      color: Colors.green,
                                      fontFamily: 'Nunito', // Définir la police Nunito
                                    ),
                                    basicStyle: TextStyle(
                                      fontSize: fontSize,
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
                                )),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  height: 5,
                ),



            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Visibility(
                  visible: post.dataType != PostDataType.TEXT.name
                      ? true
                      : false,
                  child: GestureDetector(
                    onTap: () {
                      // postProvider.updateVuePost(post, context);
                      postProvider.getChallengeById(challenge.id!).then(
                        (value) {
                          if(value.isNotEmpty){
                            post=value.first.postChallenge!;
                            post.vues = post.vues! + 1;

                            vue = post.vues!;
                            postProvider.updateVuePost(post, context);

                            // setStateImages(() {
                            //
                            // });
                          }
                        },
                      );




                      Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChallengeDetails(challenge: challenge),
                          ));
                    },
                    child: Container(
                      child: ClipRRect(
                        borderRadius: BorderRadius.all(Radius.circular(5)),
                        child: Container(
                          child: ImageSlideshow(

                            width: w * 0.9,
                            height: h * 0.3,

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
                            children: post!.images!.map((e) =>   CachedNetworkImage(

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
                Text(
                  'Prix à gagner: ${challenge.prix} FCFA', // Texte du bouton
                  style: TextStyle(
                    fontSize: 15, //
                    color: Colors.green,// Taille du texte
                    fontWeight: FontWeight.w900, // Texte en gras
                  ),
                ),
                SizedBox(
                  height: 10,
                ),
                Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _getBackgroundColor(challenge.statut!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (challenge.statut == StatutData.ENCOURS.name) ...[
                              const Icon(Icons.circle, color: Colors.green, size: 10),
                              const SizedBox(width: 6),
                            ],
                            Text(
                              _getStatusText(challenge.statut!),
                              style: TextStyle(
                                color: _getTextColor(challenge.statut!),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),  ),
                    ),

                    Center(
                      child: ElevatedButton(
                        onPressed: () {


                          postProvider.getChallengeById(challenge.id!).then(
                                (value) {
                              if(value.isNotEmpty){
                                post=value.first.postChallenge!;
                                post.vues = post.vues! + 1;

                                vue = post.vues!;
                                setStateImages(() {
                                  postProvider.updateVuePost(post, context);

                                });
                              }
                            },
                          );
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChallengeDetails(challenge: challenge),
                              ));
                          // Logique à exécuter lorsque l'utilisateur appuie sur le bouton
                          print("L'utilisateur a décidé de participer !");
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green, // Couleur de fond verte
                          // onPrimary: Colors.white, // Couleur du texte (blanc)
                          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15), // Padding pour le bouton
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10), // Coins arrondis
                          ),
                        ),
                        child: Text(
                          'Participer au challenge', // Texte du bouton
                          style: TextStyle(
                            fontSize: 12, //
                            color: Colors.white,// Taille du texte
                            fontWeight: FontWeight.bold, // Texte en gras
                          ),
                        ),
                      ),
                    ),
                  ],
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
                          onTap: () async {
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
                                  isEqualTo: post.user_id!)
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


                                  NotificationData notif =
                                  NotificationData();
                                  notif.id = firestore
                                      .collection('Notifications')
                                      .doc()
                                      .id;
                                  notif.titre = "Nouveau j'aime ❤️";
                                  notif.media_url =
                                      authProvider.loginUserData.imageUrl;
                                  notif.type = NotificationType.CHALLENGE.name;
                                  notif.description =
                                  "@${authProvider.loginUserData.pseudo!} a aimé votre Challenges 🔥🎁";
                                  notif.users_id_view = [];
                                  notif.user_id =
                                      authProvider.loginUserData.id;
                                  notif.receiver_id = post.user_id!;
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
                                  await authProvider.sendNotification(
                                      userIds: [post.user!.oneIgnalUserid!],
                                      smallImage:
                                      "${authProvider.loginUserData.imageUrl!}",
                                      send_user_id:
                                      "${authProvider.loginUserData.id!}",
                                      recever_user_id: "${post.user_id!}",
                                      message:
                                      "📢 @${authProvider.loginUserData.pseudo!} a aimé votre Challenges 🔥🎁",
                                      type_notif:
                                      NotificationType.CHALLENGE.name,
                                      post_id: "${post!.id!}",
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
                          onTap: () async {
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
                                      isIn(
                                              post.users_like_id!,
                                              authProvider
                                                  .loginUserData.id!)
                                          ? MaterialCommunityIcons.eye
                                          : MaterialCommunityIcons
                                              .eye,
                                      size: 20,
                                      color: isIn(
                                              post.users_like_id!,
                                              authProvider
                                                  .loginUserData.id!)
                                          ? Colors.blue
                                          : Colors.black,
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(
                                          left: 1.0, right: 1),
                                      child: TextCustomerPostDescription(
                                        titre: "${formatAbonnes(vue)}",
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
                                      // width: width*0.75,
                                      child: LinearProgressIndicator(
                                        color: Colors.blue,
                                        value: like/post.user!.abonnes!+1,
                                        semanticsLabel: 'Linear progress indicator',
                                      ),
                                    ),
                                  ),
                                ),
                                TextCustomerPostDescription(
                                  titre: "${(like/post.user!.abonnes!+1).toStringAsFixed(2)}%",
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
                                  isEqualTo: post.user_id!)
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
                                  notif.receiver_id = post.user_id!;
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
                                  await authProvider.sendNotification(
                                      userIds: [post.user!.oneIgnalUserid!],
                                      smallImage:
                                      "${authProvider.loginUserData.imageUrl!}",
                                      send_user_id:
                                      "${authProvider.loginUserData.id!}",
                                      recever_user_id: "${post.user_id!}",
                                      message:
                                      "📢 @${authProvider.loginUserData.pseudo!} a partagé votre look",
                                      type_notif:
                                      NotificationType.POST.name,
                                      post_id: "${post!.id!}",
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
              ],
            ),

                // Divider(
                //   height: 3,
                // )
              ],
            ),
          );
        }),
  );
}

Widget lookChallengeWidget(LookChallenge lookchallenge,Color color, double height, double width,BuildContext context) {
  double h = MediaQuery.of(context).size.height;
  double w = MediaQuery.of(context).size.width;
  late UserAuthProvider authProvider =
  Provider.of<UserAuthProvider>(context, listen: false);

  late PostProvider postProvider =
  Provider.of<PostProvider>(context, listen: false);
  late CategorieProduitProvider categorieProduitProvider =
  Provider.of<CategorieProduitProvider>(context, listen: false);
  late UserProvider userProvider =
  Provider.of<UserProvider>(context, listen: false);
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  Post post=lookchallenge!.post!;


  Random random = Random();
  bool abonneTap = false;
  int like = post!.likes!;
  int imageIndex = 0;
  int love = lookchallenge!.jaime!;
  int vue = lookchallenge!.vues!;
  int comments = post!.comments!;
  bool tapLove = isIn(post.users_love_id!, authProvider.loginUserData.id!);
  bool tapLike = isIn(post.users_like_id!, authProvider.loginUserData.id!);
  List<int> likes = [];
  List<int> loves = [];
  int idUser = 7;
  // Calculer la taille du texte en fonction de la longueur de la description
  double baseFontSize = 20.0;
  double scale = post.description!.length / 1000;  // Ajustez ce facteur selon vos besoins
  double fontSize = baseFontSize - scale;

  // Limiter la taille de la police à une valeur minimale
  fontSize = fontSize < 15 ? 15 : fontSize;
  int limitePosts = 30;


  return Container(
    child: StatefulBuilder(
        builder: (BuildContext context, StateSetter setStateImages) {
          return Padding(
            padding: const EdgeInsets.all(5.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Row(
                //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                //   children: [
                //     Row(
                //       children: [
                //         Padding(
                //           padding: const EdgeInsets.only(right: 8.0),
                //           child:  GestureDetector(
                //             onTap: () async {
                //               await  authProvider.getUserById(post.user_id!).then((users) async {
                //                 if(users.isNotEmpty){
                //                   showUserDetailsModalDialog(users.first, w, h,context);
                //
                //                 }
                //               },);
                //
                //             },
                //             child:
                //             CircleAvatar(
                //
                //               backgroundImage:
                //               NetworkImage('${post.user!.imageUrl!}'),
                //             ),
                //           ),
                //         ),
                //         SizedBox(
                //           height: 2,
                //         ),
                //         Row(
                //           children: [
                //             Column(
                //               crossAxisAlignment: CrossAxisAlignment.start,
                //               children: [
                //                 SizedBox(
                //                   //width: 100,
                //                   child: TextCustomerUserTitle(
                //                     titre: "@${post.user!.pseudo!}",
                //                     fontSize: SizeText.homeProfileTextSize,
                //                     couleur: ConstColors.textColors,
                //                     fontWeight: FontWeight.bold,
                //                   ),
                //                 ),
                //                 Row(
                //                   children: [
                //                     Column(
                //                       children: [
                //                         TextCustomerUserTitle(
                //                           titre:
                //                           "${formatNumber(post.user!.userlikes!)} like(s)",
                //                           fontSize: SizeText.homeProfileTextSize,
                //                           couleur: Colors.green,
                //                           fontWeight: FontWeight.w700,
                //                         ),
                //
                //                         TextCustomerUserTitle(
                //                           titre:
                //                           "${formatNumber(post.user!.abonnes!)} abonné(s)",
                //                           fontSize: SizeText.homeProfileTextSize,
                //                           couleur: ConstColors.textColors,
                //                           fontWeight: FontWeight.w400,
                //                         ),
                //
                //                       ],
                //                     ),
                //                     // countryFlag(post.user!.countryData!['countryCode']??"Tg"!, size: 15),
                //
                //                   ],
                //                 ),
                //               ],
                //             ),
                //             Visibility(
                //               visible:authProvider.loginUserData.id!=post.user!.id ,
                //
                //               child: StatefulBuilder(builder: (BuildContext context,
                //                   void Function(void Function()) setState) {
                //                 return Container(
                //                   child: isUserAbonne(
                //                       post.user!.userAbonnesIds!,
                //                       authProvider.loginUserData.id!)
                //                       ? Container()
                //                       : TextButton(
                //                       onPressed: abonneTap
                //                           ? () {}
                //                           : () async {
                //                         setState(() {
                //                           abonneTap=true;
                //                         });
                //                         await authProvider.abonner(post.user!,context).then((value) {
                //
                //                         },);
                //                         setState(() {
                //                           abonneTap=false;
                //                         });
                //                         //
                //                         // if (!isUserAbonne(
                //                         //     post.user!
                //                         //         .userAbonnesIds!,
                //                         //     authProvider
                //                         //         .loginUserData
                //                         //         .id!))
                //                         // {
                //                         //   setState(() {
                //                         //     abonneTap = true;
                //                         //   });
                //                         //   UserAbonnes userAbonne =
                //                         //   UserAbonnes();
                //                         //   userAbonne.compteUserId =
                //                         //       authProvider
                //                         //           .loginUserData.id;
                //                         //   userAbonne.abonneUserId =
                //                         //       post.user!.id;
                //                         //
                //                         //   userAbonne
                //                         //       .createdAt = DateTime
                //                         //       .now()
                //                         //       .millisecondsSinceEpoch;
                //                         //   userAbonne
                //                         //       .updatedAt = DateTime
                //                         //       .now()
                //                         //       .millisecondsSinceEpoch;
                //                         //   await userProvider
                //                         //       .sendAbonnementRequest(
                //                         //       userAbonne,
                //                         //       post.user!,
                //                         //       context)
                //                         //       .then(
                //                         //         (value) async {
                //                         //       if (value) {
                //                         //         authProvider
                //                         //             .loginUserData
                //                         //             .userAbonnes!
                //                         //             .add(
                //                         //             userAbonne);
                //                         //         // await userProvider.getUsers(authProvider.loginUserData!.id!);
                //                         //         await authProvider
                //                         //             .getCurrentUser(
                //                         //             authProvider
                //                         //                 .loginUserData!
                //                         //                 .id!);
                //                         //         await  authProvider.getUserById(post.user_id!).then((users) async {
                //                         //           if(users.isNotEmpty){
                //                         //             // users.first.abonnes=users.first.abonnes!+1;
                //                         //             users.first.userAbonnesIds!.add(authProvider.loginUserData.id!);
                //                         //             // post.user!.userAbonnesIds!.add(authProvider.loginUserData.id!);
                //                         //
                //                         //             post.user!= users.first;
                //                         //
                //                         //             post.user!.abonnes=post.user!.userAbonnesIds!.length;
                //                         //             // post.user!= users.first;
                //                         //
                //                         //             await userProvider.updateUser(post.user!);
                //                         //             // setState(() {
                //                         //             //   abonneTap=false;
                //                         //             //
                //                         //             // });
                //                         //           }
                //                         //         },);
                //                         //
                //                         //         // post.user!
                //                         //         //     .abonnes= post.user!
                //                         //         //     .abonnes!+1;
                //                         //         // post.user!
                //                         //         //     .userAbonnesIds!
                //                         //         //     .add(authProvider
                //                         //         //     .loginUserData
                //                         //         //     .id!);
                //                         //         // userProvider
                //                         //         //     .updateUser(
                //                         //         //     post.user!);
                //                         //         if (post.user!
                //                         //             .oneIgnalUserid !=
                //                         //             null &&
                //                         //             post
                //                         //                 .user!
                //                         //                 .oneIgnalUserid!
                //                         //                 .length >
                //                         //                 5) {
                //                         //           await authProvider.sendNotification(
                //                         //               userIds: [
                //                         //                 post.user!
                //                         //                     .oneIgnalUserid!
                //                         //               ],
                //                         //               smallImage:
                //                         //               "${authProvider.loginUserData.imageUrl!}",
                //                         //               send_user_id:
                //                         //               "${authProvider.loginUserData.id!}",
                //                         //               recever_user_id:
                //                         //               "${post.user_id!}",
                //                         //               message:
                //                         //               "📢 @${authProvider.loginUserData.pseudo!} s'est abonné(e) à votre compte",
                //                         //               type_notif:
                //                         //               NotificationType
                //                         //                   .ABONNER
                //                         //                   .name,
                //                         //               post_id:
                //                         //               "${post!.id!}",
                //                         //               post_type:
                //                         //               PostDataType
                //                         //                   .IMAGE
                //                         //                   .name,
                //                         //               chat_id: '');
                //                         //           NotificationData
                //                         //           notif =
                //                         //           NotificationData();
                //                         //           notif.id = firestore
                //                         //               .collection(
                //                         //               'Notifications')
                //                         //               .doc()
                //                         //               .id;
                //                         //           notif.titre =
                //                         //           "Nouveau Abonnement ✅";
                //                         //           notif.media_url =
                //                         //               authProvider
                //                         //                   .loginUserData
                //                         //                   .imageUrl;
                //                         //           notif.type =
                //                         //               NotificationType
                //                         //                   .ABONNER
                //                         //                   .name;
                //                         //           notif.description =
                //                         //           "@${authProvider.loginUserData.pseudo!} s'est abonné(e) à votre compte";
                //                         //           notif.users_id_view =
                //                         //           [];
                //                         //           notif.user_id =
                //                         //               authProvider
                //                         //                   .loginUserData
                //                         //                   .id;
                //                         //           notif.receiver_id =
                //                         //           post.user!
                //                         //               .id!;
                //                         //           notif.post_id =
                //                         //           post.id!;
                //                         //           notif.post_data_type =
                //                         //           PostDataType
                //                         //               .IMAGE
                //                         //               .name!;
                //                         //           notif.updatedAt =
                //                         //               DateTime.now()
                //                         //                   .microsecondsSinceEpoch;
                //                         //           notif.createdAt =
                //                         //               DateTime.now()
                //                         //                   .microsecondsSinceEpoch;
                //                         //           notif.status =
                //                         //               PostStatus
                //                         //                   .VALIDE
                //                         //                   .name;
                //                         //
                //                         //           // users.add(pseudo.toJson());
                //                         //
                //                         //           await firestore
                //                         //               .collection(
                //                         //               'Notifications')
                //                         //               .doc(notif.id)
                //                         //               .set(notif
                //                         //               .toJson());
                //                         //         }
                //                         //         SnackBar snackBar =
                //                         //         SnackBar(
                //                         //           content: Text(
                //                         //             'abonné, Bravo ! Vous avez gagné 4 points.',
                //                         //             textAlign:
                //                         //             TextAlign
                //                         //                 .center,
                //                         //             style: TextStyle(
                //                         //                 color: Colors
                //                         //                     .green),
                //                         //           ),
                //                         //         );
                //                         //         ScaffoldMessenger
                //                         //             .of(context)
                //                         //             .showSnackBar(
                //                         //             snackBar);
                //                         //         setState(() {
                //                         //           abonneTap = false;
                //                         //         });
                //                         //       } else {
                //                         //         SnackBar snackBar =
                //                         //         SnackBar(
                //                         //           content: Text(
                //                         //             'une erreur',
                //                         //             textAlign:
                //                         //             TextAlign
                //                         //                 .center,
                //                         //             style: TextStyle(
                //                         //                 color: Colors
                //                         //                     .red),
                //                         //           ),
                //                         //         );
                //                         //         ScaffoldMessenger
                //                         //             .of(context)
                //                         //             .showSnackBar(
                //                         //             snackBar);
                //                         //         setState(() {
                //                         //           abonneTap = false;
                //                         //         });
                //                         //       }
                //                         //     },
                //                         //   );
                //                         //
                //                         //   setState(() {
                //                         //     abonneTap = false;
                //                         //   });
                //                         // }
                //                       },
                //                       child: abonneTap
                //                           ? Center(
                //                         child:
                //                         LoadingAnimationWidget
                //                             .flickr(
                //                           size: 20,
                //                           leftDotColor:
                //                           Colors.green,
                //                           rightDotColor:
                //                           Colors.black,
                //                         ),
                //                       )
                //                           : Text(
                //                         "S'abonner",
                //                         style: TextStyle(
                //                             fontSize: 12,
                //                             fontWeight:
                //                             FontWeight.normal,
                //                             color: Colors.blue),
                //                       )),
                //                 );
                //               }),
                //             ),
                //             /*
                //             IconButton(
                //                 onPressed: () {},
                //                 icon: Icon(
                //                   Icons.add_circle_outlined,
                //                   size: 20,
                //                   color: ConstColors.regIconColors,
                //                 )),
                //
                //              */
                //           ],
                //         ),
                //         SizedBox(width: 10,),
                //
                //
                //
                //       ],
                //     ),
                //     IconButton(
                //         onPressed: () {
                //           _showPostMenuModalDialog(post,context);
                //         },
                //         icon: Icon(
                //           Icons.more_horiz,
                //           size: 30,
                //           color: ConstColors.blackIconColors,
                //         )),
                //   ],
                // ),
                Visibility(
                    visible: post.type==PostType.PUB.name,
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
                // Padding(
                //   padding: const EdgeInsets.all(4.0),
                //   child: HashTagText(
                //     text: "${post.description}",
                //     decoratedStyle: TextStyle(
                //       fontSize: 13,
                //       fontWeight: FontWeight.w600,
                //
                //       color: Colors.green,
                //       fontFamily: 'Nunito', // Définir la police Nunito
                //     ),
                //     basicStyle: TextStyle(
                //       fontSize: 12,
                //       color: Colors.black87,
                //       fontWeight: FontWeight.normal,
                //       fontFamily: 'Nunito', // Définir la police Nunito
                //     ),
                //     textAlign: TextAlign.left, // Centrage du texte
                //     maxLines: null, // Permet d'afficher le texte sur plusieurs lignes si nécessaire
                //     softWrap: true, // Assure que le texte se découpe sur plusieurs lignes si nécessaire
                //     // overflow: TextOverflow.ellipsis, // Ajoute une ellipse si le texte dépasse
                //     onTap: (text) {
                //       print(text);
                //     },
                //   ),
                // ),
                SizedBox(
                  height: 50,
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: SizedBox(
                      height: 2,
                      child: HashTagText(
                        text: "${lookchallenge.post!.description}",
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
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: TextCustomerPostDescription(
                      titre:
                      "${formaterDateTime(DateTime.fromMicrosecondsSinceEpoch(post.createdAt!))}",
                      fontSize: SizeText.homeProfileDateTextSize,
                      couleur: ConstColors.textColors,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Visibility(
                  visible: post.dataType == PostDataType.TEXT.name
                      ? true
                      : false,
                  child: GestureDetector(
                    onTap: () {
                      // postProvider.updateVuePost(post, context);

                      // Navigator.push(
                      //     context,
                      //     MaterialPageRoute(
                      //       builder: (context) => DetailsPost(post: post),
                      //     ));
                    },
                    child: Container(
                      color: color,
                      child: Align(
                        alignment: Alignment.center,
                        child: SizedBox(
                          // width: width * 0.8,
                          // height: height * 0.5,
                          child: Container(
                            // height: 200,
                            // constraints: BoxConstraints(
                            //   // minHeight: 100.0, // Set your minimum height
                            //   maxHeight:
                            //   height * 0.6, // Set your maximum height
                            // ),
                            alignment: Alignment.centerLeft,
                            child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Center(
                                  child: HashTagText(
                                    text: "${post.description}",
                                    decoratedStyle: TextStyle(
                                      fontSize: fontSize,

                                      fontWeight: FontWeight.w600,

                                      color: Colors.green,
                                      fontFamily: 'Nunito', // Définir la police Nunito
                                    ),
                                    basicStyle: TextStyle(
                                      fontSize: fontSize,
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
                                )),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  height: 5,
                ),



                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Visibility(
                      visible: post.dataType != PostDataType.TEXT.name
                          ? true
                          : false,
                      child: GestureDetector(
                        onTap: () {
                          // postProvider.updateVuePost(post, context);






                        },
                        child: Container(
                          child: ClipRRect(
                            borderRadius: BorderRadius.all(Radius.circular(5)),
                            child: Container(
                                child: InstaImageViewer(
                                  child:CachedNetworkImage(

                                    fit: BoxFit.contain,

                                    imageUrl: '${post.images!.first}',
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
                                )
                            ),
                          ),
                        ),
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
                              onTap: () async {
                                if (!isIn(lookchallenge.usersLovesIds!,
                                    authProvider.loginUserData.id!)) {
                                  setState(() {

                                    postProvider.getLookChallengeById(lookchallenge.id!).then(
                                          (value) {
                                        if(value.isNotEmpty){
                                          lookchallenge=value.first!;
                                          lookchallenge.jaime = lookchallenge.jaime! + 1;
                                          lookchallenge.usersLovesIds!.add(authProvider.loginUserData.id!);

                                          love = lookchallenge.jaime!;
                                          postProvider.updateLookChallenge(lookchallenge);

                                          // setStateImages(() {
                                          //
                                          // });
                                        }
                                      },
                                    );
                                    // post.loves = post.loves! + 1;
                                    //
                                    // post.users_love_id!
                                    //     .add(authProvider!.loginUserData.id!);
                                    // love = post.loves!;
                                    //loves.add(idUser);
                                  });
                                  CollectionReference userCollect =
                                  FirebaseFirestore.instance
                                      .collection('Users');
                                  // Get docs from collection reference
                                  QuerySnapshot querySnapshotUser =
                                  await userCollect
                                      .where("id",
                                      isEqualTo: post.user_id!)
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


                                      NotificationData notif =
                                      NotificationData();
                                      notif.id = firestore
                                          .collection('Notifications')
                                          .doc()
                                          .id;
                                      notif.titre = "❤️ Challenges 🔥🎁 j'aime ❤️";
                                      notif.media_url =
                                          authProvider.loginUserData.imageUrl;
                                      notif.type = NotificationType.CHALLENGE.name;
                                      notif.description =
                                      "@${authProvider.loginUserData.pseudo!} a aimé votre Look Challenges 🔥🎁";
                                      notif.users_id_view = [];
                                      notif.user_id =
                                          authProvider.loginUserData.id;
                                      notif.receiver_id = post.user_id!;
                                      notif.post_id = lookchallenge.id!;
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
                                          userIds: [post.user!.oneIgnalUserid!],
                                          smallImage:
                                          "${authProvider.loginUserData.imageUrl!}",
                                          send_user_id:
                                          "${authProvider.loginUserData.id!}",
                                          recever_user_id: "${post.user_id!}",
                                          message:
                                          "📢 @${authProvider.loginUserData.pseudo!} a aimé votre Look Challenges 🔥🎁",
                                          type_notif:
                                          NotificationType.CHALLENGE.name,
                                          post_id: "${lookchallenge!.id!}",
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
                                              lookchallenge.usersLovesIds!,
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
                          // StatefulBuilder(builder:
                          //     (BuildContext context, StateSetter setState) {
                          //   return GestureDetector(
                          //     onTap: () async {
                          //     },
                          //     child: Container(
                          //       width: 70,
                          //       height: 30,
                          //       child: Row(
                          //         crossAxisAlignment: CrossAxisAlignment.center,
                          //         // mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          //         children: [
                          //           Row(
                          //             children: [
                          //               Icon(
                          //                 isIn(
                          //                     post.users_like_id!,
                          //                     authProvider
                          //                         .loginUserData.id!)
                          //                     ? MaterialCommunityIcons.eye
                          //                     : MaterialCommunityIcons
                          //                     .eye,
                          //                 size: 20,
                          //                 color: isIn(
                          //                     post.users_like_id!,
                          //                     authProvider
                          //                         .loginUserData.id!)
                          //                     ? Colors.blue
                          //                     : Colors.black,
                          //               ),
                          //               Padding(
                          //                 padding: const EdgeInsets.only(
                          //                     left: 1.0, right: 1),
                          //                 child: TextCustomerPostDescription(
                          //                   titre: "${formatAbonnes(vue)}",
                          //                   fontSize: SizeText
                          //                       .homeProfileDateTextSize,
                          //                   couleur: ConstColors.textColors,
                          //                   fontWeight: FontWeight.bold,
                          //                 ),
                          //               ),
                          //             ],
                          //           ),
                          //           /*
                          //       Expanded(
                          //         child: Padding(
                          //           padding: const EdgeInsets.only(left: 1.0,right: 1),
                          //           child: SizedBox(
                          //             height: 2,
                          //             // width: width*0.75,
                          //             child: LinearProgressIndicator(
                          //               color: Colors.blue,
                          //               value: like/post.user!.abonnes!+1,
                          //               semanticsLabel: 'Linear progress indicator',
                          //             ),
                          //           ),
                          //         ),
                          //       ),
                          //       TextCustomerPostDescription(
                          //         titre: "${(like/post.user!.abonnes!+1).toStringAsFixed(2)}%",
                          //         fontSize: SizeText.homeProfileDateTextSize,
                          //         couleur: ConstColors.textColors,
                          //         fontWeight: FontWeight.bold,
                          //       ),
                          //
                          //        */
                          //         ],
                          //       ),
                          //     ),
                          //   );
                          // }),
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
                                // await authProvider.createLink(post).then((value) {
                                final box = context.findRenderObject() as RenderBox?;

                                await authProvider.createChallengeLink(true,lookchallenge).then((url) async {
                                  await Share.shareUri(
                                    Uri.parse(
                                        '${url}'),
                                    sharePositionOrigin:
                                    box!.localToGlobal(Offset.zero) & box.size,
                                  );

                                  // if (!isIn(lookchallenge.usersPartagesIds!,
                                  //     authProvider.loginUserData.id!)) {
                                    setState(() {
                                      // post.partage = post.partage! + 1;
                                      postProvider.getLookChallengeById(lookchallenge.id!).then(
                                            (value) {
                                          if(value.isNotEmpty){
                                            lookchallenge=value.first!;
                                            lookchallenge.partage = lookchallenge.partage! + 1;
                                            lookchallenge.usersPartagesIds!.add(authProvider.loginUserData.id!);

                                            // lookchallenge.partage!;
                                            postProvider.updateLookChallenge(lookchallenge);

                                            // setStateImages(() {
                                            //
                                            // });
                                          }
                                        },
                                      );
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
                                        isEqualTo: post.user_id!)
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
                                      // if (post.user!.oneIgnalUserid != null &&
                                      //     post.user!.oneIgnalUserid!.length > 5) {


                                        NotificationData notif =
                                        NotificationData();
                                        notif.id = firestore
                                            .collection('Notifications')
                                            .doc()
                                            .id;
                                        notif.titre = "Challenges 🔥🎁 partage 📲";
                                        notif.media_url =
                                            authProvider.loginUserData.imageUrl;
                                        notif.type = NotificationType.POST.name;
                                        notif.description =
                                        "@${authProvider.loginUserData.pseudo!} a partagé votre look Challenges 🔥🎁";
                                        notif.users_id_view = [];
                                        notif.user_id =
                                            authProvider.loginUserData.id;
                                        notif.receiver_id = post.user_id!;
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
                                        await authProvider.sendNotification(
                                            userIds: [post.user!.oneIgnalUserid!],
                                            smallImage:
                                            "${authProvider.loginUserData.imageUrl!}",
                                            send_user_id:
                                            "${authProvider.loginUserData.id!}",
                                            recever_user_id: "${post.user_id!}",
                                            message:
                                            "📢 @${authProvider.loginUserData.pseudo!} a partagé votre look Challenges 🔥🎁",
                                            type_notif:
                                            NotificationType.CHALLENGE.name,
                                            post_id: "${lookchallenge!.id!}",
                                            post_type: PostDataType.IMAGE.name,
                                            chat_id: '');

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
                                 // }




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
                                              lookchallenge.usersPartagesIds!,
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
                                            titre: "${formatAbonnes(lookchallenge.partage!)}",
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
                  ],
                ),

                // Divider(
                //   height: 3,
                // )
              ],
            ),
          );
        }),
  );
}