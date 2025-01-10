import 'package:flutter/material.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:like_button/like_button.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/model_data.dart';
import '../../providers/authProvider.dart';
import '../../providers/postProvider.dart';

class DetailUserServicePage extends StatefulWidget {
   UserServiceData data;

  DetailUserServicePage({required this.data});

  @override
  _DetailUserServicePageState createState() => _DetailUserServicePageState();
}

class _DetailUserServicePageState extends State<DetailUserServicePage> {
  late PostProvider postProvider =
  Provider.of<PostProvider>(context, listen: false);
  late UserAuthProvider authProvider =
  Provider.of<UserAuthProvider>(context, listen: false);
  bool isIn(List<String> users_id, String userIdToCheck) {
    return users_id.any((item) => item == userIdToCheck);
  }

  Future<void> launchWhatsApp(String phone,UserServiceData articleData) async {
    //  var whatsappURl_android = "whatsapp://send?phone="+whatsapp+"&text=hello";
    // String url = "https://wa.me/?tel:+228$phone&&text=YourTextHere";
    String url = "whatsapp://send?phone="+phone+"&text=Salut *${articleData.user!.nom!}*,\n*Moi c'est*: *@${authProvider.loginUserData!.pseudo!.toUpperCase()} Sur Afrolook*,\n je vous contact à propos de votre service:\n\n*Titre*:  *${articleData.titre!.toUpperCase()}*\n *Description*: *${articleData.description}*";
    if (!await launchUrl(Uri.parse(url))) {
      final snackBar = SnackBar(duration: Duration(seconds: 2),content: Text("Impossible d\'ouvrir WhatsApp",textAlign: TextAlign.center, style: TextStyle(color: Colors.red),));

      // Afficher le SnackBar en bas de la page
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
      throw Exception('Impossible d\'ouvrir WhatsApp');
    }
  }


  @override
  Widget build(BuildContext context) {
    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.data.titre ?? 'Titre'),
      ),
      body: SingleChildScrollView(
        child: Card(
          child: ListTile(
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  // mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      backgroundImage: NetworkImage(widget.data.user!.imageUrl ?? ''),
                      radius: 30,
                    ),
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,

                      crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            '@${widget.data.user!.pseudo ?? 'Pseudo'}',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                          Text(
                            '${widget.data.user!.abonnes ?? '0'} abonné(s)',
                            style: TextStyle(fontSize: 11, color: Colors.green),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: SizedBox(
                    // height: height * 0.25,
                    // width: width,
                    child: Image.network(
                      widget.data.imageCourverture ?? '',
                      // fit: BoxFit.cover,
                      // height: height * 0.25,
                      // width: w
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 8.0, right: 8, top: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      LikeButton(
                        isLiked: false,
                        size: 15,
                        circleColor: CircleColor(
                          start: Color(0xff00ddff),
                          end: Color(0xff0099cc),
                        ),
                        bubblesColor: BubblesColor(
                          dotPrimaryColor: Color(0xff3b9ade),
                          dotSecondaryColor: Color(0xff027f19),
                        ),
                        countPostion: CountPostion.bottom,
                        likeBuilder: (bool isLiked) {
                          return Icon(
                            FontAwesome.eye,
                            color: isLiked ? Colors.black : Colors.brown,
                            size: 15,
                          );
                        },
                        likeCount: widget.data.vues,
                        countBuilder: (int? count, bool isLiked, String text) {
                          var color = isLiked ? Colors.black : Colors.black;
                          Widget result;
                          if (count == 0) {
                            result = Text(
                              "0",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: color, fontSize: 8),
                            );
                          } else {
                            result = Text(
                              text,
                              style: TextStyle(color: color, fontSize: 8),
                            );
                          }
                          return result;
                        },
                      ),
                      LikeButton(
                        isLiked: false,
                        size: 15,
                        circleColor:
                        CircleColor(start: Color(0xff00ddff), end: Color(0xff0099cc)),
                        bubblesColor: BubblesColor(
                          dotPrimaryColor: Color(0xff3b9ade),
                          dotSecondaryColor: Color(0xff027f19),
                        ),
                        countPostion: CountPostion.bottom,
                        likeBuilder: (bool isLiked) {
                          return Icon(
                            FontAwesome.whatsapp,
                            color: isLiked ? Colors.green : Colors.green,
                            size: 15,
                          );
                        },
                        likeCount:    widget.data.usersContactId!.length,
                        countBuilder: (int? count, bool isLiked, String text) {
                          var color = isLiked ? Colors.black : Colors.black;
                          Widget result;
                          if (count == 0) {
                            result = Text(
                              "0",textAlign: TextAlign.center,
                              style: TextStyle(color: color,fontSize: 8),
                            );
                          } else
                            result = Text(
                              text,
                              style: TextStyle(color: color,fontSize: 8),
                            );
                          return result;
                        },

                      ),
                      LikeButton(
                        onTap: (isLiked) async {
                          await    postProvider.getUserServiceById( widget.data.id!).then((value) async {
                            if (value.isNotEmpty) {
                              widget.data=value.first;
                              widget.data.like=value.first.like!+1;

                              if(!isIn( widget.data.usersViewId!, authProvider.loginUserData!.id!)){
                                widget.data.usersLikeId!.add(authProvider.loginUserData!.id!) ;

                              }
                              postProvider.updateUserService( widget.data,context).then((value) {
                                if (value) {


                                }
                              },);
                            }
                          },);
                          // await    categorieProduitProvider.getArticleById(widget.article.id!).then((value) {
                          //   if (value.isNotEmpty) {
                          //     value.first.jaime=value.first.jaime!+1;
                          //     widget.article.jaime=value.first.jaime!+1;
                          //     categorieProduitProvider.updateArticle(value.first,context).then((value) async {
                          //       if (value) {
                          //         await authProvider.sendNotification(
                          //             userIds: [widget.article.user!.oneIgnalUserid!],
                          //             smallImage:
                          //             "${widget.article.images!.first}",
                          //             send_user_id:
                          //             "${authProvider.loginUserData.id!}",
                          //             recever_user_id: "${widget.article.user!.id!}",
                          //             message:
                          //             "📢 🛒 Un afrolookeur aime ❤️ votre produit 🛒",
                          //             type_notif:
                          //             NotificationType.ARTICLE.name,
                          //             post_id: "${widget.article!.id!}",
                          //             post_type: PostDataType.IMAGE.name,
                          //             chat_id: '');
                          //
                          //         NotificationData notif =
                          //         NotificationData();
                          //         notif.id = firestore
                          //             .collection('Notifications')
                          //             .doc()
                          //             .id;
                          //         notif.titre = " 🛒Boutique 🛒";
                          //         notif.media_url =
                          //         "${widget.article.images!.first}";
                          //         notif.type = NotificationType.ARTICLE.name;
                          //         notif.description =
                          //         "Un afrolookeur aime ❤️ votre produit 🛒";
                          //         notif.users_id_view = [];
                          //         notif.user_id =
                          //             authProvider.loginUserData.id;
                          //         notif.receiver_id = widget.article.user!.id!;
                          //         notif.post_id = widget.article.id!;
                          //         notif.post_data_type =
                          //         PostDataType.IMAGE.name!;
                          //
                          //         notif.updatedAt =
                          //             DateTime.now().microsecondsSinceEpoch;
                          //         notif.createdAt =
                          //             DateTime.now().microsecondsSinceEpoch;
                          //         notif.status = PostStatus.VALIDE.name;
                          //
                          //         // users.add(pseudo.toJson());
                          //
                          //         await firestore
                          //             .collection('Notifications')
                          //             .doc(notif.id)
                          //             .set(notif.toJson());
                          //
                          //       }
                          //     },);
                          //
                          //   }
                          // },);

                          return Future.value(true);

                        },
                        isLiked: false,
                        size: 15,
                        circleColor:
                        CircleColor(start: Color(0xff00ddff), end: Color(0xff0099cc)),
                        bubblesColor: BubblesColor(
                          dotPrimaryColor: Color(0xff3b9ade),
                          dotSecondaryColor: Color(0xff027f19),
                        ),
                        countPostion: CountPostion.bottom,
                        likeBuilder: (bool isLiked) {
                          return Icon(
                            FontAwesome.heart,
                            color: isLiked ? Colors.red : Colors.redAccent,
                            size: 15,
                          );
                        },
                        likeCount:    widget.data.like,
                        countBuilder: (int? count, bool isLiked, String text) {
                          var color = isLiked ? Colors.black : Colors.black;
                          Widget result;
                          if (count == 0) {
                            result = Text(
                              "0",textAlign: TextAlign.center,
                              style: TextStyle(color: color,fontSize: 8),
                            );
                          } else
                            result = Text(
                              text,
                              style: TextStyle(color: color,fontSize: 8),
                            );
                          return result;
                        },

                      ),
                      LikeButton(
                        onTap: (isLiked) async {

                          // await authProvider.createArticleLink(true,widget.article).then((url) async {
                          //   final box = context.findRenderObject() as RenderBox?;
                          //
                          //   await Share.shareUri(
                          //     Uri.parse(
                          //         '${url}'),
                          //     sharePositionOrigin:
                          //     box!.localToGlobal(Offset.zero) & box.size,
                          //   );
                          //
                          //   // printVm("widget.article : ${widget.article.toJson()}");
                          //   setState(() {
                          //     widget.article.partage = widget.article.partage! + 1;
                          //     // post.users_love_id!
                          //     //     .add(authProvider!.loginUserData.id!);
                          //     // love = post.loves!;
                          //     // //loves.add(idUser);
                          //   });
                          //
                          //   await    categorieProduitProvider.getArticleById(widget.article.id!).then((value) {
                          //     if (value.isNotEmpty) {
                          //       value.first.partage=value.first.partage!+1;
                          //       // widget.article.partage=value.first.partage!+1;
                          //       categorieProduitProvider.updateArticle(value.first,context).then((value) {
                          //         if (value) {
                          //           setState(() {
                          //
                          //           });
                          //
                          //         }
                          //       },);
                          //
                          //     }
                          //   },);
                          //
                          //   CollectionReference userCollect =
                          //   FirebaseFirestore.instance
                          //       .collection('Users');
                          //   // Get docs from collection reference
                          //   QuerySnapshot querySnapshotUser =
                          //   await userCollect
                          //       .where("id",
                          //       isEqualTo: widget.article.user!.id!)
                          //       .get();
                          //   // Afficher la liste
                          //   List<UserData> listUsers = querySnapshotUser
                          //       .docs
                          //       .map((doc) => UserData.fromJson(
                          //       doc.data() as Map<String, dynamic>))
                          //       .toList();
                          //   if (listUsers.isNotEmpty) {
                          //     // listUsers.first!.partage =
                          //     //     listUsers.first!.partage! + 1;
                          //     printVm("user trouver");
                          //     if (widget.article.user!.oneIgnalUserid != null &&
                          //         widget.article.user!.oneIgnalUserid!.length > 5) {
                          //       await authProvider.sendNotification(
                          //           userIds: [widget.article.user!.oneIgnalUserid!],
                          //           smallImage:
                          //           "${widget.article.images!.first}",
                          //           send_user_id:
                          //           "${authProvider.loginUserData.id!}",
                          //           recever_user_id: "${widget.article.user!.id!}",
                          //           message:
                          //           "📢 🛒 Un afrolookeur a partagé votre produit 🛒",
                          //           type_notif:
                          //           NotificationType.ARTICLE.name,
                          //           post_id: "${widget.article!.id!}",
                          //           post_type: PostDataType.IMAGE.name,
                          //           chat_id: '');
                          //
                          //       NotificationData notif =
                          //       NotificationData();
                          //       notif.id = firestore
                          //           .collection('Notifications')
                          //           .doc()
                          //           .id;
                          //       notif.titre = " 🛒Boutique 🛒";
                          //       notif.media_url =
                          //       "${widget.article.images!.first}"
                          //       ;
                          //       notif.type = NotificationType.ARTICLE.name;
                          //       notif.description =
                          //       "Un afrolookeur a partagé votre produit 🛒";
                          //       notif.users_id_view = [];
                          //       notif.user_id =
                          //           authProvider.loginUserData.id;
                          //       notif.receiver_id = widget.article.user!.id!;
                          //       notif.post_id = widget.article.id!;
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
                          //     // SnackBar snackBar = SnackBar(
                          //     //   content: Text(
                          //     //     '+2 points.  Voir le classement',
                          //     //     textAlign: TextAlign.center,
                          //     //     style: TextStyle(color: Colors.green),
                          //     //   ),
                          //     // );
                          //     // ScaffoldMessenger.of(context)
                          //     //     .showSnackBar(snackBar);
                          //     // categorieProduitProvider.updateArticle(
                          //     //     widget.article, context);
                          //     // await authProvider.getAppData();
                          //     // authProvider.appDefaultData.nbr_loves =
                          //     //     authProvider.appDefaultData.nbr_loves! +
                          //     //         2;
                          //     // authProvider.updateAppData(
                          //     //     authProvider.appDefaultData);
                          //
                          //
                          //   }
                          //
                          // },);


                          return Future.value(true);

                        },
                        isLiked: false,
                        size: 15,
                        circleColor:
                        CircleColor(start: Color(0xffffc400), end: Color(
                            0xffcc7a00)),
                        bubblesColor: BubblesColor(
                          dotPrimaryColor: Color(0xffffc400),
                          dotSecondaryColor: Color(0xff07f629),
                        ),
                        countPostion: CountPostion.bottom,
                        likeBuilder: (bool isLiked) {
                          return Icon(
                            Entypo.share,
                            color: isLiked ? Colors.blue : Colors.blueAccent,
                            size: 15,
                          );
                        },
                        likeCount:    widget.data.usersPartageId!.length,
                        countBuilder: (int? count, bool isLiked, String text) {
                          var color = isLiked ? Colors.black : Colors.black;
                          Widget result;
                          if (count == 0) {
                            result = Text(
                              "0",textAlign: TextAlign.center,
                              style: TextStyle(color: color,fontSize: 8),
                            );
                          } else
                            result = Text(
                              text,
                              style: TextStyle(color: color,fontSize: 8),
                            );
                          return result;
                        },

                      ),
                    ],
                  ),
                ),

                Text(widget.data.titre ?? 'Titre',style: TextStyle(fontSize: 18,fontWeight: FontWeight.w900),),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconText(icon: Icons.contact_phone, text: widget.data.contact ?? 'Contact'),
                    Container(

                      child: TextButton(
                        onPressed: () async {

                          launchWhatsApp(widget.data .contact!, widget.data!);



                        },
                        child: Center(
                          child: Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                  color: Colors.brown,
                                  borderRadius: BorderRadius.all(Radius.circular(5))
                              ),
                              child: Padding(
                                padding: const EdgeInsets.only(left: 8.0,right: 8),
                                child: Row(
                                  children: [
                                    Text('Contacter',style: TextStyle(color: Colors.white),),
                                    IconButton(
                                      icon: Icon(FontAwesome.whatsapp,color: Colors.green,size: 30,),
                                      onPressed: () async {

                                        // Fonction pour ouvrir WhatsApp
                                      },
                                    ),
                                  ],
                                ),
                              )),
                        ),
                      ),
                    ),
                  ],
                ),

                Text(
                  widget.data.description ?? 'Description',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            onTap: () {
              // Action lors du clic sur un élément de la liste
            },
          ),
        ),
      ),
    );
  }
}

class IconText extends StatelessWidget {
  final IconData icon;
  final String text;

  IconText({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16),
        SizedBox(width: 4),
        Text(text),
      ],
    );
  }
}