
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:like_button/like_button.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../constant/custom_theme.dart';
import '../../../models/model_data.dart';
import '../../../providers/afroshop/authAfroshopProvider.dart';
import '../../../providers/afroshop/categorie_produits_provider.dart';
import '../../../providers/authProvider.dart';
import '../../../providers/postProvider.dart';
import '../../component/consoleWidget.dart';
import '../../user/conponent.dart';
import 'acceuil/home_afroshop.dart';
import 'acceuil/produit_details.dart';


class ArticleTile extends StatefulWidget {
  final ArticleData article;

  final double w;

  final double h;
   ArticleTile({super.key, required this.article, required this.w, required this.h});

  @override
  State<ArticleTile> createState() => _ArticleTileState();
}

class _ArticleTileState extends State<ArticleTile> {


  late UserShopAuthProvider authShopProvider =
  Provider.of<UserShopAuthProvider>(context, listen: false);

  late UserAuthProvider authProvider =
  Provider.of<UserAuthProvider>(context, listen: false);

  late PostProvider postProvider =
  Provider.of<PostProvider>(context, listen: false);

  late CategorieProduitProvider categorieProduitProvider =
  Provider.of<CategorieProduitProvider>(context, listen: false);
  bool _isLoading=false;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Container(
        child: Stack(
          children: [
            Column(

              children: [
                GestureDetector(
                  onTap: () async {
                    setState(() {
                      _isLoading=true;
                    });

                    await    categorieProduitProvider.getArticleById(widget.article.id!).then((value) async {
                      if (value.isNotEmpty) {
                        value.first.vues=value.first.vues!+1;
                        widget.article.vues=value.first.vues!+1;
                        categorieProduitProvider.updateArticle(value.first,context).then((value) {
                          if (value) {


                          }
                        },);
                        await    authProvider.getUserById(widget.article.user_id!).then((users) async {
                          if(users.isNotEmpty){
                            widget.article.user=users.first;
                            await    postProvider.getEntreprise(widget.article.user_id!).then((entreprises) {
                              if(entreprises.isNotEmpty){
                                entreprises.first.suivi=entreprises.first.usersSuiviId!.length;
                                setState(() {
                                  _isLoading=false;
                                });
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          ProduitDetail(article: widget.article, entrepriseData: entreprises.first,),
                                    ));
                              }
                            },);
                          }
                        },);
                      }
                    },);


                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.only(topLeft: Radius.circular(10),topRight: Radius.circular(5)),
                    child: Container(
                      width: widget. w*0.5,
                      height: widget.h*0.22,
                      child: CachedNetworkImage(
                        fit: BoxFit.cover,

                        imageUrl: '${widget.article.images!.first}',
                        progressIndicatorBuilder: (context, url, downloadProgress) =>
                        //  LinearProgressIndicator(),

                        Skeletonizer(
                            child: SizedBox(    width: widget.w*0.2,
                                height: widget.h*0.2, child:  ClipRRect(
                                    borderRadius: BorderRadius.all(Radius.circular(10)),child: Image.network('${widget.article.images!.first}')))),
                        errorWidget: (context, url, error) =>  Container(    width: widget.w*0.2,
                            height: widget.h*0.2,child: Image.network('${widget.article.images!.first}',fit: BoxFit.cover,)),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 10,),

                Padding(
                  padding: const EdgeInsets.only(left: 8.0,right: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      Text("${widget.article!.titre}",overflow: TextOverflow.ellipsis,style: TextStyle(fontSize: 11,fontWeight: FontWeight.w500),),
                      // Text(widget.article.description),
                      SizedBox(height: 5,),
                      Container(
                          alignment: Alignment.centerLeft,
                          decoration: BoxDecoration(
                              borderRadius: BorderRadius.all(Radius.circular(5)),
                              color:  CustomConstants.kPrimaryColor
                          ),
                          child: Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: Row(
                              spacing: 5,
                              children: [
                                Text('Prix: ${widget.article.prix} Fcfa',style: TextStyle(color: Colors.white,fontWeight: FontWeight.w600,fontSize: 12),),
                                Padding(
                                  padding: const EdgeInsets.all(2.0),
                                  child: countryFlag(widget.article.countryData==null?'TG':widget.article.countryData!['countryCode']??"TG"!, size: 20),
                                ),
                              ],
                            ),
                          )),
                    ],
                  ),
                ),


                Padding(
                  padding: const EdgeInsets.only(left: 8.0,right: 8,top: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,

                    children: [
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
                            FontAwesome.eye,
                            color: isLiked ? Colors.black : Colors.brown,
                            size: 15,
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
                        likeCount:   widget.article.contact,
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
                                  "${widget.article.images!.first}";
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

                            // printVm("widget.article : ${widget.article.toJson()}");
                            setState(() {
                              widget.article.partage = widget.article.partage! + 1;
                              // post.users_love_id!
                              //     .add(authProvider!.loginUserData.id!);
                              // love = post.loves!;
                              // //loves.add(idUser);
                            });

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
                                "${widget.article.images!.first}"
                            ;
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
                              // categorieProduitProvider.updateArticle(
                              //     widget.article, context);
                              // await authProvider.getAppData();
                              // authProvider.appDefaultData.nbr_loves =
                              //     authProvider.appDefaultData.nbr_loves! +
                              //         2;
                              // authProvider.updateAppData(
                              //     authProvider.appDefaultData);


                            }

                          },);


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
                )


              ],
            ),
            if (_isLoading)
              ModalBarrier(
                color: Colors.black.withOpacity(0.5),
                dismissible: false,
              ),
            if (_isLoading)
              Center(
                child: CircularProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }
}


class ArticleTileBooster extends StatefulWidget {
  final ArticleData article;
  final double w;
  final double h;
  final bool isOtherPage;

  ArticleTileBooster({required this.article, required this.w, required this.h, required this.isOtherPage});

  @override
  _ArticleTileBoosterState createState() => _ArticleTileBoosterState();
}

class _ArticleTileBoosterState extends State<ArticleTileBooster> {
  bool _isLoading = false;
  late UserShopAuthProvider authShopProvider =
  Provider.of<UserShopAuthProvider>(context, listen: false);

  late UserAuthProvider authProvider =
  Provider.of<UserAuthProvider>(context, listen: false);

  late PostProvider postProvider =
  Provider.of<PostProvider>(context, listen: false);

  late CategorieProduitProvider categorieProduitProvider =
  Provider.of<CategorieProduitProvider>(context, listen: false);
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Container(
        color: Colors.lightGreen.shade300,
        child: Stack(
          children: [
            GestureDetector(
              onTap: () async {
                setState(() {
                  _isLoading = true;
                });

                await categorieProduitProvider.getArticleById(widget.article.id!).then((value) async {
                  if (value.isNotEmpty) {
                    value.first.vues = value.first.vues! + 1;
                    widget.article.vues = value.first.vues! + 1;
                    categorieProduitProvider.updateArticle(value.first, context).then((value) {
                      if (value) {
                        // Additional logic here
                      }
                    });
                    await authProvider.getUserById(widget.article.user_id!).then((users) async {
                      if (users.isNotEmpty) {
                        widget.article.user = users.first;
                        await postProvider.getEntreprise(widget.article.user_id!).then((entreprises) {
                          if (entreprises.isNotEmpty) {
                            entreprises.first.suivi = entreprises.first.usersSuiviId!.length;
                            setState(() {
                              _isLoading = false;
                            });
                            if(widget.isOtherPage){
                              Navigator.push(context, MaterialPageRoute(builder: (context) => HomeAfroshopPage(title: ''),));

                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ProduitDetail(article: widget.article, entrepriseData: entreprises.first),
                                ),
                              );
                            }else{
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ProduitDetail(article: widget.article, entrepriseData: entreprises.first),
                                ),
                              );
                            }

                          }
                        });
                      }
                    });
                  }
                });
              },
              child: ClipRRect(
                borderRadius: BorderRadius.only(topLeft: Radius.circular(10), topRight: Radius.circular(5)),
                child: Container(
                  width: widget.w * 0.6,
                  child: CachedNetworkImage(
                    fit: BoxFit.cover,
                    imageUrl: '${widget.article.images!.first}',
                    progressIndicatorBuilder: (context, url, downloadProgress) => Skeletonizer(
                      child: SizedBox(
                        child: ClipRRect(
                          borderRadius: BorderRadius.all(Radius.circular(10)),
                          child: Image.network('${widget.article.images!.first}'),
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      child: Image.network('${widget.article.images!.first}', fit: BoxFit.cover),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                color: Colors.red.withOpacity(0.7),
                padding: EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Prix: ${widget.article.prix} Fcfa',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                    countryFlag(widget.article.countryData==null?"TG":widget.article.countryData!['countryCode']??"TG"!, size: 20),

                    Text(
                      'Vues: ${widget.article.vues}',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                color: Colors.black.withOpacity(0.7),
                child: Icon(
                  Fontisto.fire,
                  color: Colors.red,
                  size: 30,
                ),
              ),
            ),
            if (_isLoading)
              ModalBarrier(
                color: Colors.black.withOpacity(0.5),
                dismissible: false,
              ),
            if (_isLoading)
              Center(
                child: CircularProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }
}


class ArticleTileSheetBooster extends StatefulWidget {
  final ArticleData article;
  final double w;
  final double h;
  final bool isOtherPage;

  ArticleTileSheetBooster({
    required this.article,
    required this.w,
    required this.h,
    required this.isOtherPage,
    Key? key,
  }) : super(key: key);

  @override
  _ArticleTileSheetBoosterState createState() => _ArticleTileSheetBoosterState();
}

class _ArticleTileSheetBoosterState extends State<ArticleTileSheetBooster> {
  bool _isLoading = false;
  late UserShopAuthProvider authShopProvider =
  Provider.of<UserShopAuthProvider>(context, listen: false);

  late UserAuthProvider authProvider =
  Provider.of<UserAuthProvider>(context, listen: false);

  late PostProvider postProvider =
  Provider.of<PostProvider>(context, listen: false);

  late CategorieProduitProvider categorieProduitProvider =
  Provider.of<CategorieProduitProvider>(context, listen: false);
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SizedBox(
        width: widget.w * 0.6,
        height: widget.h * 0.44,
        child: Container(
          child: Stack(
            children: [
              GestureDetector(
                onTap: () async {
                  setState(() {
                    _isLoading = true;
                  });

                  await categorieProduitProvider
                      .getArticleById(widget.article.id!)
                      .then((value) async {
                    if (value.isNotEmpty) {
                      value.first.vues = value.first.vues! + 1;
                      widget.article.vues = value.first.vues! + 1;
                      categorieProduitProvider
                          .updateArticle(value.first, context)
                          .then((value) {
                        if (value) {
                          // Additional logic here
                        }
                      });
                      await authProvider
                          .getUserById(widget.article.user_id!)
                          .then((users) async {
                        if (users.isNotEmpty) {
                          widget.article.user = users.first;
                          await postProvider
                              .getEntreprise(widget.article.user_id!)
                              .then((entreprises) {
                            if (entreprises.isNotEmpty) {
                              entreprises.first.suivi =
                                  entreprises.first.usersSuiviId!.length;
                              setState(() {
                                _isLoading = false;
                              });
                              if (widget.isOtherPage) {
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          HomeAfroshopPage(title: ''),
                                    ));

                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ProduitDetail(
                                        article: widget.article,
                                        entrepriseData: entreprises.first),
                                  ),
                                );
                              } else {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ProduitDetail(
                                        article: widget.article,
                                        entrepriseData: entreprises.first),
                                  ),
                                );
                              }
                            }
                          });
                        }
                      });
                    }
                  });
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(10), topRight: Radius.circular(5)),
                  child: Container(
                    child: CachedNetworkImage(
                      fit: BoxFit.cover,
                      imageUrl: '${widget.article.images!.first}',
                      progressIndicatorBuilder:
                          (context, url, downloadProgress) => Skeletonizer(
                        child: SizedBox(
                          child: ClipRRect(
                            borderRadius: BorderRadius.all(Radius.circular(10)),
                            child: Image.network('${widget.article.images!.first}'),
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        child: Image.network('${widget.article.images!.first}',
                            fit: BoxFit.cover),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  color: Colors.red.withOpacity(0.7),
                  padding: EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Prix: ${widget.article.prix} Fcfa',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 12),
                      ),
                      Text(
                        'Vues: ${widget.article.vues}',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  color: Colors.black.withOpacity(0.7),
                  child: Icon(
                    Fontisto.fire,
                    color: Colors.red,
                    size: 30,
                  ),
                ),
              ),
              if (_isLoading)
                ModalBarrier(
                  color: Colors.black.withOpacity(0.5),
                  dismissible: false,
                ),
              if (_isLoading)
                Center(
                  child: CircularProgressIndicator(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}



