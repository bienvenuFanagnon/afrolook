import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/pages/afroshop/marketPlace/acceuil/home_afroshop.dart';
import 'package:afrotok/pages/auth/authTest/constants.dart';
import 'package:afrotok/pages/postComments.dart';
import 'package:afrotok/pages/postDetails.dart';
import 'package:afrotok/pages/socialVideos/video_details.dart';
import 'package:afrotok/pages/user/amis/mesAmis.dart';
import 'package:afrotok/pages/user/amis/pageMesInvitations.dart';
import 'package:afrotok/pages/user/retrait.dart';
import 'package:afrotok/pages/userPosts/challenge/listChallenge.dart';
import 'package:afrotok/providers/afroshop/categorie_produits_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/authProvider.dart';
import '../providers/postProvider.dart';
import '../providers/userProvider.dart';
import 'UserServices/detailsUserService.dart';
import 'UserServices/listUserService.dart';
import 'afroshop/marketPlace/acceuil/produit_details.dart';
import 'component/consoleWidget.dart';
import 'component/showUserDetails.dart';

class MesNotification extends StatefulWidget {
  const MesNotification({super.key});

  @override
  State<MesNotification> createState() => _MesNotificationState();
}

class _MesNotificationState extends State<MesNotification> {
  bool onTap=false;

  late UserAuthProvider authProvider =
  Provider.of<UserAuthProvider>(context, listen: false);
  late UserProvider userProvider =
  Provider.of<UserProvider>(context, listen: false);
  final List<String> noms = ['Alice', 'Bob', 'Charlie'];
  late PostProvider postProvider =
  Provider.of<PostProvider>(context, listen: false);
  late CategorieProduitProvider categorieProduitProvider =
  Provider.of<CategorieProduitProvider>(context, listen: false);
  TextEditingController commentController =TextEditingController();
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
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


  Future<void> handleNotification(NotificationData notification) async {

    if(onTap==false){
      setState(() {
        onTap=true;
      });
      if (notification.type == NotificationType.POST.name) {


        switch (notification.post_data_type) {
          case "VIDEO":
            postProvider.getPostsVideosById(notification.post_id!).then((videos_posts) {
              if(videos_posts.isNotEmpty){

                printVm("video detail ======== : ${videos_posts.first.toJson()}");

                setState(() {
                  onTap=false;
                });


                Navigator.push(context, MaterialPageRoute(builder: (context) => OnlyPostVideo(videos: videos_posts,),));

              }
            },);

            break;
          case "IMAGE":
            postProvider.getPostsImagesById(notification.post_id!).then((posts) {
              if(posts.isNotEmpty){
                setState(() {
                  onTap=false;
                });
                Navigator.push(context, MaterialPageRoute(builder: (context) => DetailsPost(post: posts.first),));

              }

            },);
            break;
          case 'COMMENT':
            postProvider.getPostsImagesById(notification.post_id!).then((posts) {
              if(posts.isNotEmpty){
                setState(() {
                  onTap=false;
                });
                Navigator.push(context, MaterialPageRoute(builder: (context) => PostComments(post:  posts.first),));

              }

            },);
            break;
          default:
          // Handle unknown post type
            break;
        }
      }
      else if (notification.type == NotificationType.INVITATION.name) {
        setState(() {
          onTap=false;
        });
        Navigator.push(context, MaterialPageRoute(builder: (context) => MesInvitationsPage(context: context),));

      }
      else if (notification.type == NotificationType.ARTICLE.name) {

        await    postProvider.getArticleById(notification.post_id!).then((value) async {
          if (value.isNotEmpty) {
            value.first.vues=value.first.vues!+1;
            // article.vues=value.first.vues!+1;
            categorieProduitProvider.updateArticle(value.first,context).then((value) {
              if (value) {


              }
            },);
            await    authProvider.getUserById(value.first.user_id!).then((users) async {
              if(users.isNotEmpty){
                value.first.user=users.first;
                await    postProvider.getEntreprise(value.first.user_id!).then((entreprises) {
                  if(entreprises.isNotEmpty){
                    entreprises.first.suivi=entreprises.first.usersSuiviId!.length;
                    // setState(() {
                    //   _isLoading=false;
                    // });
                    setState(() {
                      onTap=false;
                    });
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              HomeAfroshopPage(title: ""),
                        ));
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              ProduitDetail(article: value.first, entrepriseData: entreprises.first,),
                        ));
                  }
                },);
              }
            },);
          }
        },);

      }
      else if (notification.type == NotificationType.SERVICE.name) {

        await    postProvider.getUserServiceById(notification.post_id!).then((value) async {
          if (value.isNotEmpty) {
            UserServiceData  data=value.first;
            data.vues=value.first.vues!+1;

            Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      UserServiceListPage(),
                ));
            Navigator.push(context, MaterialPageRoute(builder: (context) => DetailUserServicePage(data: data),));

            if(!isIn(data.usersViewId!, authProvider.loginUserData!.id!)){
              data.usersViewId!.add(authProvider.loginUserData!.id!) ;

            }
            postProvider.updateUserService(data,context).then((value) {
              if (value) {


              }
            },);
          }
        },);

      }

      else if (notification.type == NotificationType.CHALLENGE.name) {

        Navigator.push(context, MaterialPageRoute(builder: (context) => ChallengeListPage(),));

      }

      else if (notification.type == NotificationType.ACCEPTINVITATION.name) {
        setState(() {
          onTap=false;
        });
        Navigator.push(context, MaterialPageRoute(builder: (context) => MesAmis(context: context),));

      }
      else if (notification.type == NotificationType.PARRAINAGE.name) {
        setState(() {
          onTap=false;
        });
        Navigator.push(context, MaterialPageRoute(builder: (context) => RetraitPage(),));

      }else{
        Navigator.pop(context);

      }

    }



  }

  List<NotificationData> notifications = []; // Liste locale pour stocker les notifications

  bool isIn(List<String> users_id, String userIdToCheck) {
    return users_id.any((item) => item == userIdToCheck);
  }
  @override
  Widget build(BuildContext context) {
    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;
    return Scaffold(
        appBar: AppBar(
          title: Text('Notifications'),
        ),
        body: SingleChildScrollView(
          child: Center(
            child: Stack(
              children: [
            Positioned(

                    top: 0,
                    bottom: 0,
                    left: 0,
                    right: 0,

                    child: Visibility(
                      visible: onTap?true:false,
                      child: Container(
                          width: width,
                          height: height,
                      color: Colors.transparent.withOpacity(0.2),

                      alignment: Alignment.center,
                      child: Container(
                          height: 30,
                          width: 30,

                          child: CircularProgressIndicator(backgroundColor: kPrimaryColor,))),
                    )),
                Container(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: StreamBuilder<NotificationData>(
                      stream: postProvider.getListNotification(authProvider.loginUserData.id!),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting && notifications.isEmpty) {
                          return Center(child: CircularProgressIndicator());
                        }

                        if (snapshot.hasError) {
                          return Center(child: Text("Erreur de chargement", style: TextStyle(color: Colors.red)));
                        }

                        // Ajouter la nouvelle notification à la liste locale
                        if (snapshot.hasData && !notifications.contains(snapshot.data!)) {
                          // setState(() {
                            notifications.add(snapshot.data!);
                          // });
                        }

                        return Container(
                          width: width,
                          height: height * 0.86,
                          child: ListView.builder(
                            itemCount: notifications.length,
                            itemBuilder: (context, index) {
                              NotificationData notif = notifications[index];

                              if (!isIn(notif.users_id_view!, authProvider.loginUserData.id!)) {
                                notif.users_id_view!.add(authProvider.loginUserData.id!);
                                firestore.collection('Notifications').doc(notif.id).update(notif.toJson());
                              }

                              return Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.all(Radius.circular(5)),
                                    color: notif.is_open! ? Colors.black12 : Colors.green.shade100,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(2.0),
                                    child: ListTile(
                                      title: Text('${notif.titre}', style: TextStyle(color: Colors.blue)),
                                      subtitle: GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            notif.is_open = true;
                                          });
                                          authProvider.updateNotif(notif);
                                          handleNotification(notif);
                                        },
                                        child: Text('${notif.description}'),
                                      ),
                                      leading: Container(
                                        height: 40,
                                        width: 40,
                                        decoration: BoxDecoration(borderRadius: BorderRadius.all(Radius.circular(10))),
                                        child: GestureDetector(
                                          onTap: () {
                                            showUserDetailsModalDialog(notif.userData!, width, height, context);
                                          },
                                          child: Stack(
                                            children: [
                                              CircleAvatar(
                                                radius: 20,

                                                backgroundImage:
                                                NetworkImage('${notif.media_url}'),
                                              ),
                                              Positioned(
                                                bottom: 0, right: -5,
                                                child: Visibility(
                                                  visible: notif.userData!.isVerify!,
                                                  child: Card(
                                                    child: const Icon(
                                                      Icons.verified,
                                                      color: Colors.green,
                                                      size: 20,
                                                    ),
                                                  ),
                                                ),
                                              ),

                                            ],
                                          ),
                                        ),
                                      ),
                                      trailing: Text(
                                        "${formaterDateTime(DateTime.fromMicrosecondsSinceEpoch(notif.createdAt!))}",
                                        style: TextStyle(fontSize: 8, color: Colors.black87),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),
                )              ],
            ),
          ),
        ));
  }
}
