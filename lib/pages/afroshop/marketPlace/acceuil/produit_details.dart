import 'dart:io';
import 'dart:math';


import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:like_button/like_button.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'package:insta_image_viewer/insta_image_viewer.dart';

import '../../../../constant/custom_theme.dart';
import '../../../../models/model_data.dart';
import '../../../../providers/afroshop/authAfroshopProvider.dart';
import '../../../../providers/afroshop/categorie_produits_provider.dart';
import '../../../../providers/authProvider.dart';
import '../../../component/consoleWidget.dart';
import '../../../entreprise/produit/component.dart';

class ProduitDetail extends StatefulWidget {
  final ArticleData article;
  final EntrepriseData entrepriseData;
  const ProduitDetail({super.key, required this.article, required this.entrepriseData});

  @override
  State<ProduitDetail> createState() => _ProduitDetailState();
}

class _ProduitDetailState extends State<ProduitDetail> {

  late UserAuthProvider authshopProvider =
  Provider.of<UserAuthProvider>(context, listen: false);
  String _chars = 'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890';
  int _length = 100; // Remplacez par la longueur souhaitée
  bool onSaveTap=false;
  bool onSupTap=false;

  late CategorieProduitProvider categorieProduitProvider =
  Provider.of<CategorieProduitProvider>(context, listen: false);
  late UserAuthProvider authProvider =
  Provider.of<UserAuthProvider>(context, listen: false);
  late UserShopAuthProvider authShopProvider =
  Provider.of<UserShopAuthProvider>(context, listen: false);


  final FirebaseFirestore firestore = FirebaseFirestore.instance;




  String getRandomString() {
    final _rnd = Random();
    return String.fromCharCodes(Iterable.generate(_length, (_) => _chars.codeUnitAt(_rnd.nextInt(_chars.length))));
  }



  Future<void> launchWhatsApp(String phone,ArticleData articleData,String urlArticle) async {
    //  var whatsappURl_android = "whatsapp://send?phone="+whatsapp+"&text=hello";
    // String url = "https://wa.me/?tel:+228$phone&&text=YourTextHere";
    String url = "whatsapp://send?phone="+phone+"&text=Salut *${articleData.user!.nom!}*,\n*Moi c'est*: *@${authProvider.loginUserData!.pseudo!.toUpperCase()} Sur Afrolook*,\n j'ai vu votre produit sur *${"Afroshop".toUpperCase()}*\n à propos de l'article:\n\n*Titre*:  *${articleData.titre!.toUpperCase()}*\n *Prix*: *${articleData.prix}* fcfa\n *Voir l'article* ${urlArticle}";
    if (!await launchUrl(Uri.parse(url))) {
      final snackBar = SnackBar(duration: Duration(seconds: 2),content: Text("Impossible d\'ouvrir WhatsApp",textAlign: TextAlign.center, style: TextStyle(color: Colors.red),));

      // Afficher le SnackBar en bas de la page
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
      throw Exception('Impossible d\'ouvrir WhatsApp');
    }
  }

  int imageIndex=0;
  @override
  Widget build(BuildContext context) {
    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;
    double iconSize = 20;
    return Scaffold(
        appBar: AppBar(
          title: Text('Details'),
          actions: [
            Container(
              // color: Colors.black12,
              height: 150,
              width: 150,
              alignment: Alignment.center,
              child: Image.asset(
                "assets/icons/afroshop_logo-removebg-preview.png",
                fit: BoxFit.cover,
              ),
            ),
          ],
        ),
        body: SingleChildScrollView(

          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
            children: <Widget>[
              SizedBox(height: 20,),
              ClipRRect(
                borderRadius: BorderRadius.all(Radius.circular(10)),
                child: Column(
                  children: [
                    entrepriseSimpleHeader(widget.entrepriseData,context),

                    Stack(
                      children: [
                        SizedBox(

                          child: InstaImageViewer(
                            child: Image(
                              image: Image.network('${widget.article.images![imageIndex]}')
                                  .image,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 0,
                          right: 0,

                          child:onSupTap?Container(
                              height: 20,
                              width: 20,

                              child: CircularProgressIndicator()):
                          Visibility(
                            visible:authProvider.loginUserData.id==widget.article.user_id||authProvider.loginUserData.role==UserRole.ADM.name?true:false,

                            child: IconButton(onPressed: () async {
                              widget.article.disponible=false;
                              setState(() {
                                onSupTap=true;
                              });
                              await categorieProduitProvider.updateArticle(widget.article, context).then(
                                    (value) {
                                  if (value) {

                                    ScaffoldMessenger.of(context).showSnackBar(

                                      SnackBar(
                                        backgroundColor: Colors.green,
                                        content: Text('L\'article a été supprimé avec succès'),
                                      ),
                                    );
                                    setState(() {
                                      onSupTap=false;
                                    });
                                    Navigator.pop(context);
                                  }  else{
                                    setState(() {
                                      onSupTap=false;
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(

                                      SnackBar(
                                        backgroundColor: Colors.red,
                                        content: Text('Erreur de suppression'),
                                      ),
                                    );
                                  }
                                },
                              );

                            }, icon: Icon(Icons.delete,color: Colors.red,size: 40,)),
                          ),
                        )
                      ],
                    ),

                    // SizedBox(
                    //
                    //   child: InstaImageViewer(
                    //     child: Image(
                    //       image: Image.network('${widget.article.images![imageIndex]}')
                    //           .image,
                    //     ),
                    //   ),
                    // ),

                    /*
                    Container(
                      //width: width,
                      //height: height*0.55,
                      child: CachedNetworkImage(
                        fit: BoxFit.cover,

                        imageUrl: '${widget.article.images![imageIndex]}',
                        progressIndicatorBuilder: (context, url, downloadProgress) =>
                        //  LinearProgressIndicator(),

                        Skeletonizer(
                            child: SizedBox(     width: width,
                                height: height*0.5, child:  ClipRRect(
                                    borderRadius: BorderRadius.all(Radius.circular(10)),child: Image.network('${widget.article.images![imageIndex]}')))),
                        errorWidget: (context, url, error) =>  Container(    width: width,
                          height: height*0.5,child: Image.network('${widget.article.images![imageIndex]}',fit: BoxFit.cover,)),
                      ),
                    ),

                     */
                  ],
                ),
              ),
              SizedBox(height: 10,),
              Container(
                alignment: Alignment.center,
                width: width,
                height: 60,
                child: ListView.builder(

                  scrollDirection: Axis.horizontal,
                itemCount: widget.article.images!.length,
                itemBuilder: (BuildContext context, int index) {
                  return    GestureDetector(
                    onTap: () {
                      setState(() {
                        imageIndex=index;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(2.0),
                      child: Container(

                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.all(Radius.circular(10)),
                          border: Border.all(color: CustomConstants.kPrimaryColor)
                        ),

                        width: 110,
                        height: 60,
                        child: Image.network(
                          widget.article.images![index],

                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  );
                },
                          ),
              ),
              // SizedBox(height: 20,),
              Divider(height: 20,indent: 20,endIndent: 20,),

              Padding(
                padding: const EdgeInsets.only(left: 2.0,right: 2,top: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.center,

                  children: [
                    LikeButton(
                      isLiked: false,
                      size: iconSize,
                      circleColor:
                      CircleColor(start: Color(0xff00ddff), end: Color(0xff0099cc)),
                      bubblesColor: BubblesColor(
                        dotPrimaryColor: Color(0xff3b9ade),
                        dotSecondaryColor: Color(0xff027f19),
                      ),
                      countPostion: CountPostion.bottom,
                      likeBuilder: (bool isLiked) {
                        return Icon(
                          FontAwesome.eye,
                          color: isLiked ? Colors.black : Colors.brown,
                          size: iconSize,
                        );
                      },
                      likeCount:  widget.article.vues,
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
                      isLiked: false,
                      size: iconSize,
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
                          size: iconSize,
                        );
                      },
                      likeCount:  widget.article.contact,
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
                        await    categorieProduitProvider.getArticleById(widget.article.id!).then((value) {
                          if (value.isNotEmpty) {
                            value.first.jaime=value.first.jaime!+1;
                            widget.article.jaime=value.first.jaime!+1;
                            categorieProduitProvider.updateArticle(value.first,context).then((value) async {
                              if (value) {
                                await authProvider.sendNotification(
                                    userIds: [widget.article.user!.oneIgnalUserid!],
                                    smallImage:
                                    "${widget.article.images!.first}",
                                    send_user_id:
                                    "${authProvider.loginUserData.id!}",
                                    recever_user_id: "${widget.article.user!.id!}",
                                    message:
                                    "📢 🛒 Un afrolookeur aime ❤️ votre produit 🛒",
                                    type_notif:
                                    NotificationType.ARTICLE.name,
                                    post_id: "${widget.article!.id!}",
                                    post_type: PostDataType.IMAGE.name,
                                    chat_id: '');

                                NotificationData notif =
                                NotificationData();
                                notif.id = firestore
                                    .collection('Notifications')
                                    .doc()
                                    .id;
                                notif.titre = " 🛒Boutique 🛒";
                                notif.media_url =
                                    authProvider.loginUserData.imageUrl;
                                notif.type = NotificationType.ARTICLE.name;
                                notif.description =
                                "Un afrolookeur aime ❤️ votre produit 🛒";
                                notif.users_id_view = [];
                                notif.user_id =
                                    authProvider.loginUserData.id;
                                notif.receiver_id = widget.article.user!.id!;
                                notif.post_id = widget.article.id!;
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
                            },);

                          }
                        },);

                        return Future.value(true);

                      },
                      isLiked: false,
                      size: iconSize,
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
                          size: iconSize,
                        );
                      },
                      likeCount:   widget.article.jaime,
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

                        await authProvider.createArticleLink(true,widget.article).then((url) async {
                          final box = context.findRenderObject() as RenderBox?;

                          await Share.shareUri(
                            Uri.parse(
                                '${url}'),
                            sharePositionOrigin:
                            box!.localToGlobal(Offset.zero) & box.size,
                          );

                          // printVm("article : ${article.toJson()}");
                          setState(() {
                           widget.article.partage = widget.article.partage! + 1;
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
                              isEqualTo: widget.article.user!.id!)
                              .get();
                          // Afficher la liste
                          List<UserData> listUsers = querySnapshotUser
                              .docs
                              .map((doc) => UserData.fromJson(
                              doc.data() as Map<String, dynamic>))
                              .toList();
                          if (listUsers.isNotEmpty) {
                            // listUsers.first!.partage =
                            //     listUsers.first!.partage! + 1;
                            printVm("user trouver");
                            if (widget.article.user!.oneIgnalUserid != null &&
                                widget.article.user!.oneIgnalUserid!.length > 5) {
                              await authProvider.sendNotification(
                                  userIds: [widget.article.user!.oneIgnalUserid!],
                                  smallImage:
                                  "${widget.article.images!.first}",
                                  // "${authProvider.loginUserData.imageUrl!}",
                                  send_user_id:
                                  "${authProvider.loginUserData.id!}",
                                  recever_user_id: "${widget.article.user!.id!}",
                                  message:
                                  "📢 🛒 Un afrolookeur a partagé votre produit 🛒",
                                  type_notif:
                                  NotificationType.ARTICLE.name,
                                  post_id: "${widget.article!.id!}",
                                  post_type: PostDataType.IMAGE.name,
                                  chat_id: '');

                              NotificationData notif =
                              NotificationData();
                              notif.id = firestore
                                  .collection('Notifications')
                                  .doc()
                                  .id;
                              notif.titre = " 🛒Boutique 🛒";
                              notif.media_url =
                              "${widget.article.images!.first}";
                              notif.type = NotificationType.ARTICLE.name;
                              notif.description =
                              "Un afrolookeur a partagé votre produit 🛒";
                              notif.users_id_view = [];
                              notif.user_id =
                                  authProvider.loginUserData.id;
                              notif.receiver_id = widget.article.user!.id!;
                              notif.post_id = widget.article.id!;
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
                            categorieProduitProvider.updateArticle(
                                widget.article, context);
                            // await authProvider.getAppData();
                            // authProvider.appDefaultData.nbr_loves =
                            //     authProvider.appDefaultData.nbr_loves! +
                            //         2;
                            // authProvider.updateAppData(
                            //     authProvider.appDefaultData);


                          }
                          await    categorieProduitProvider.getArticleById(widget.article.id!).then((value) {
                            if (value.isNotEmpty) {
                              value.first.partage=value.first.partage!+1;
                              // widget.article.partage=value.first.partage!+1;
                              categorieProduitProvider.updateArticle(value.first,context).then((value) {
                                if (value) {
                                  setState(() {

                                  });

                                }
                              },);

                            }
                          },);

                        },);


                        return Future.value(true);

                      },
                      isLiked: false,
                      size: iconSize,
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
                          size: iconSize,
                        );
                      },
                      likeCount:   widget.article.partage,
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
              Divider(height: 20,indent: 20,endIndent: 20,),

              Padding(
                padding: const EdgeInsets.only(bottom: 8.0,top: 8),
                child: Text("${widget.article.titre}",overflow: TextOverflow.ellipsis,style: TextStyle(fontWeight: FontWeight.w600,fontSize: 15),),
              ),
              // Text(article.description),
              Container(

                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.all(Radius.circular(5)),
                      color:  CustomConstants.kPrimaryColor
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text('Prix: ${widget.article.prix} Fcfa',style: TextStyle(color: Colors.white,fontWeight: FontWeight.w600),),
                  )),
               SizedBox(height: 20,),
               Text("${widget.article.description}"),

              SizedBox(height: height*0.1,),

            ]
      ),
          ),
        ),


      bottomSheet:     Container(
        height: 80,
        width: width,

        child: TextButton(
          onPressed: () async {
            await authProvider.createArticleLink(true,widget.article).then((url) async {

// printVm("widget.article : ${widget.article.toJson()}");

              setState(() {
                widget.article.contact = widget.article.contact! + 1;
                launchWhatsApp(widget.article.phone!, widget!.article!,url);

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
                  isEqualTo: widget.article.user!.id!)
                  .get();
              // Afficher la liste
              List<UserData> listUsers = querySnapshotUser
                  .docs
                  .map((doc) => UserData.fromJson(
                  doc.data() as Map<String, dynamic>))
                  .toList();
              if (listUsers.isNotEmpty) {
                // listUsers.first!.partage =
                //     listUsers.first!.partage! + 1;
                printVm("user trouver");
                if (widget.article.user!.oneIgnalUserid != null &&
                    widget.article.user!.oneIgnalUserid!.length > 5) {
                  await authProvider.sendNotification(
                      userIds: [widget.article.user!.oneIgnalUserid!],
                      smallImage:
                      "${authProvider.loginUserData.imageUrl!}",
                      send_user_id:
                      "${authProvider.loginUserData.id!}",
                      recever_user_id: "${widget.article.user!.id!}",
                      message:
                      "📢 🛒 @${authProvider.loginUserData.pseudo!} veut votre produit 🛒",
                      type_notif:
                      NotificationType.ARTICLE.name,
                      post_id: "${widget.article!.id!}",
                      post_type: PostDataType.IMAGE.name,
                      chat_id: '');

                  NotificationData notif =
                  NotificationData();
                  notif.id = firestore
                      .collection('Notifications')
                      .doc()
                      .id;
                  notif.titre = " 🛒Boutique 🛒";
                  notif.media_url =
                      authProvider.loginUserData.imageUrl;
                  notif.type = NotificationType.ARTICLE.name;
                  notif.description =
                  "@${authProvider.loginUserData.pseudo!} veut votre produit 🛒";
                  notif.users_id_view = [];
                  notif.user_id =
                      authProvider.loginUserData.id;
                  notif.receiver_id = widget.article.user!.id!;
                  notif.post_id = widget.article.id!;
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
                categorieProduitProvider.updateArticle(
                    widget.article, context);
                // await authProvider.getAppData();
                // authProvider.appDefaultData.nbr_loves =
                //     authProvider.appDefaultData.nbr_loves! +
                //         2;
                // authProvider.updateAppData(
                //     authProvider.appDefaultData);


              }

            },);



          },
          child:onSaveTap?Container(
              height: 20,
              width: 20,

              child: CircularProgressIndicator()): Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: Colors.brown,
                  borderRadius: BorderRadius.all(Radius.circular(5))
              ),
              height: 40,
              width: width*0.8,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text('Contacter le vendeur',style: TextStyle(color: Colors.white),),
                  IconButton(
                    icon: Icon(FontAwesome.whatsapp,color: Colors.green,size: 30,),
                    onPressed: () async {

                      // Fonction pour ouvrir WhatsApp
                    },
                  ),
                ],
              )),
        ),
      ),
    );



  }

}
