import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/pages/afroshop/marketPlace/acceuil/home_afroshop.dart';
import 'package:afrotok/pages/auth/authTest/constants.dart';
import 'package:afrotok/pages/postComments.dart';
import 'package:afrotok/pages/postDetails.dart';
import 'package:afrotok/pages/socialVideos/video_details.dart';
import 'package:afrotok/pages/user/amis/mesAmis.dart';
import 'package:afrotok/pages/user/amis/pageMesInvitations.dart';
import 'package:afrotok/pages/user/retrait.dart';
import 'package:afrotok/providers/afroshop/categorie_produits_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/authProvider.dart';
import '../providers/postProvider.dart';
import '../providers/userProvider.dart';
import 'afroshop/marketPlace/acceuil/produit_details.dart';
import 'component/consoleWidget.dart';

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
                    child: StreamBuilder<List<NotificationData>>(

                      stream: postProvider.getListNotificatio(authProvider.loginUserData.id!),
                      builder: (context, snapshot) {

                        if (snapshot.connectionState == ConnectionState.waiting) {

                          return
                            Center(child: Container(width:50 , height:50,child: CircularProgressIndicator()));
                        }else if (snapshot.hasError) {
                          return
                            Center(child: Container(width:50 , height:50,child: CircularProgressIndicator()));
                        }else{
                          return Container(
                            width: width,
                            height: height*0.86,
                            child: ListView.builder(
                              //reverse: true,

                                itemCount: snapshot!.data!.length, // Nombre d'éléments dans la liste
                                itemBuilder: (context, index) {
                                  List<NotificationData> list=snapshot!.data!;

                                  if (!isIn(list[index].users_id_view!,authProvider.loginUserData.id!)) {
                                   // list.remove(n);
                                    list[index].users_id_view!.add(authProvider.loginUserData.id!);
                                     firestore.collection('Notifications').doc( list[index]!.id).update( list[index]!.toJson());

                                  }

                                  return GestureDetector(
                                    onTap: () {
                                      list[index].is_open=true;
                                      printVm("notif data : ${list[index].toJson()}");
                                      authProvider.updateNotif(list[index]);
                                      // if(list[index].type==NotificationType.ABONNER.name)
                                      handleNotification(list[index]);

                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(4.0),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.all(Radius.circular(5)),
                                          color:list[index].is_open!? Colors.black12:Colors.green.shade100,

                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(2.0),
                                          child: ListTile(


                                            title: Text('${list[index].titre}',style: TextStyle(color: Colors.blue),),
                                            subtitle: Text('${list[index].description}'),
                                            leading:Container(
                                                height: 40,
                                                width: 40,
                                                decoration: BoxDecoration(borderRadius: BorderRadius.all(Radius.circular((10)))),
                                                child: Image.network('${list[index].media_url}',fit: BoxFit.cover,)),
                                            /*
                                      leading: Icon(
                                        Icons.notifications,
                                        color:isIn(list[index].users_id_view!,authProvider.loginUserData.id!)? Colors.black87:Colors.red,
                                      ),

                                           */
                                            trailing: Text("${formaterDateTime(DateTime.fromMicrosecondsSinceEpoch(list[index].createdAt!))}",style: TextStyle(fontSize: 8,color: Colors.black87),),),
                                        ),
                                      ),
                                    ),
                                  );

                                }),
                          );

                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ));
  }
}
