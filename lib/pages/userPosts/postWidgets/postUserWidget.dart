



import 'dart:math';

import 'package:afrotok/pages/canaux/listCanal.dart';
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

import '../../../constant/constColors.dart';
import '../../../constant/sizeText.dart';
import '../../../constant/textCustom.dart';
import '../../../models/model_data.dart';
import '../../../providers/afroshop/authAfroshopProvider.dart';
import '../../../providers/afroshop/categorie_produits_provider.dart';
import '../../../providers/authProvider.dart';
import '../../../providers/userProvider.dart';
import '../../canaux/detailsCanal.dart';
import '../../component/consoleWidget.dart';
import '../../component/showUserDetails.dart';
import '../../postComments.dart';
import '../../postDetails.dart';
import '../../socialVideos/afrolive/afrolookLive.dart';
import '../../user/conponent.dart';
import '../../user/otherUser/otherUser.dart';
String formatNumber(int number) {
  if (number >= 1000) {
    double nombre = number / 1000;
    return nombre.toStringAsFixed(1) + 'k';
  } else {
    return number.toString();
  }
}

Future<void> deletePost(Post post, BuildContext context) async {
  late UserAuthProvider authProvider =
  Provider.of<UserAuthProvider>(context, listen: false);
  late PostProvider postProvider =
  Provider.of<PostProvider>(context, listen: false);
  try {
    // Vérifie les droits
    final canDelete = authProvider.loginUserData.role == UserRole.ADM.name ||
        (post.type == PostType.POST.name &&
            post.user?.id == authProvider.loginUserData.id);

    if (!canDelete) return;

    // Supprime le document dans Firestore
    await FirebaseFirestore.instance
        .collection('Posts')
        .doc(post.id)
        .delete();

    // SnackBar de succès
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Post supprimé !',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.green),
        ),
      ),
    );
  } catch (e) {
    // SnackBar d'erreur
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Échec de la suppression !',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.red),
        ),
      ),
    );
    print('Erreur suppression post: $e');
  }
}

void showPostMenuModalDialog(Post post,BuildContext context) {
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
                visible: post.user_id != authProvider.loginUserData.id,
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
                visible: post.user!.id == authProvider.loginUserData.id ||authProvider.loginUserData.role == UserRole.ADM.name?true:false ,
                child: ListTile(
                  onTap: () async {
                    if (authProvider.loginUserData.role == UserRole.ADM.name) {
                      await deletePost(post, context);
                    }
                    else if (post.type == PostType.POST.name) {
                      if (post.user!.id == authProvider.loginUserData.id) {
                        post.status = PostStatus.SUPPRIMER.name;
                        await deletePost(post, context);

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

bool isUserAbonne2(List<String> userAbonnesList, String userIdToCheck) {
  return userAbonnesList.any((userAbonneId) => userAbonneId == userIdToCheck);
}

bool isUserAbonne(List<String> abonnesIds, String userId) {
  return abonnesIds.contains(userId);
}

bool isIn(List<String> users_id, String userIdToCheck) {
  return users_id.any((item) => item == userIdToCheck);
}

bool isMyFriend(List<String> userfriendList, String userIdToCheck) {
  return userfriendList.any((userfriendId) => userfriendId == userIdToCheck);
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





String truncateWords(String text, int maxWords) {
  // Supprime les espaces en trop et remplace \n, \r, \t par un seul espace
  String cleanedText = text.replaceAll(RegExp(r'\s+'), ' ').trim();

  // Découpe le texte en mots
  List<String> words = cleanedText.split(' ');

  // Tronque si nécessaire
  return (words.length > maxWords)
      ? '${words.sublist(0, maxWords).join(' ')}...'
      : cleanedText;
}