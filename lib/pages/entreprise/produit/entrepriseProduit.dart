import 'package:anim_search_bar/anim_search_bar.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:contained_tab_bar_view_with_custom_page_navigator/contained_tab_bar_view_with_custom_page_navigator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:like_button/like_button.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../constant/buttons.dart';
import '../../../constant/constColors.dart';
import '../../../constant/custom_theme.dart';
import '../../../constant/iconGradient.dart';
import '../../../constant/listItemsCarousel.dart';
import '../../../constant/logo.dart';
import '../../../constant/sizeText.dart';
import '../../../constant/textCustom.dart';
import '../../../models/model_data.dart';
import '../../../providers/afroshop/authAfroshopProvider.dart';
import '../../../providers/afroshop/categorie_produits_provider.dart';
import '../../../providers/authProvider.dart';
import '../../../providers/postProvider.dart';
import '../../afroshop/marketPlace/acceuil/produit_details.dart';
import '../../component/consoleWidget.dart';


class EntrepriseProduitView extends StatefulWidget {
  @override
  State<EntrepriseProduitView> createState() => _EntreprisePublicationViewState();
}

class _EntreprisePublicationViewState extends State<EntrepriseProduitView> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController textController = TextEditingController();

  GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  late UserShopAuthProvider authShopProvider =
  Provider.of<UserShopAuthProvider>(context, listen: false);
  late UserAuthProvider authProvider =
  Provider.of<UserAuthProvider>(context, listen: false);
  late PostProvider postProvider =
  Provider.of<PostProvider>(context, listen: false);
  late CategorieProduitProvider categorieProduitProvider =
  Provider.of<CategorieProduitProvider>(context, listen: false);

  int item_selected = -1;
  late Categorie categorieDataSelected=Categorie();
  bool is_selected = true;
  bool is_search=false;
  bool _isLoading=false;
  // final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  Widget CategoryItem(
      {required Categorie category, required int is_selected}) {
    return SizedBox(
      //height: 20,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
            borderRadius: BorderRadius.all(Radius.circular(5)),
            color: item_selected == is_selected
                ? CustomConstants.kPrimaryColor
                : Colors.black38),
        margin: EdgeInsets.all(2.0),
        //  width: 120,
        //height: 10,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            "${category.nom}",
            style: TextStyle(
                fontSize: 12.0,
                fontWeight: FontWeight.bold,
                color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget ArticleTile(ArticleData article,double w,double h) {
    print('article ${article.titre}');
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

                    await    categorieProduitProvider.getArticleById(article.id!).then((value) async {
                      if (value.isNotEmpty) {
                        value.first.vues=value.first.vues!+1;
                        article.vues=value.first.vues!+1;
                        categorieProduitProvider.updateArticle(value.first,context).then((value) {
                          if (value) {


                          }
                        },);
                        await    authProvider.getUserById(article.user_id!).then((users) async {
                          if(users.isNotEmpty){
                            article.user=users.first;
                            await    postProvider.getEntreprise(article.user_id!).then((entreprises) {
                              if(entreprises.isNotEmpty){
                                entreprises.first.suivi=entreprises.first.usersSuiviId!.length;
                                setState(() {
                                  _isLoading=false;
                                });
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          ProduitDetail(article: article, entrepriseData: entreprises.first,),
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
                      width: w*0.5,
                      height: h*0.22,
                      child: CachedNetworkImage(
                        fit: BoxFit.cover,

                        imageUrl: '${article.images!.first}',
                        progressIndicatorBuilder: (context, url, downloadProgress) =>
                        //  LinearProgressIndicator(),

                        Skeletonizer(
                            child: SizedBox(    width: w*0.2,
                                height: h*0.2, child:  ClipRRect(
                                    borderRadius: BorderRadius.all(Radius.circular(10)),child: Image.network('${article.images!.first}')))),
                        errorWidget: (context, url, error) =>  Container(    width: w*0.2,
                            height: h*0.2,child: Image.network('${article.images!.first}',fit: BoxFit.cover,)),
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

                      Text("${article!.titre}",overflow: TextOverflow.ellipsis,style: TextStyle(fontSize: 11,fontWeight: FontWeight.w500),),
                      // Text(article.description),
                      SizedBox(height: 5,),
                      Container(
                          alignment: Alignment.centerLeft,
                          decoration: BoxDecoration(
                              borderRadius: BorderRadius.all(Radius.circular(5)),
                              color:  CustomConstants.kPrimaryColor
                          ),
                          child: Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: Text('Prix: ${article.prix} Fcfa',style: TextStyle(color: Colors.white,fontWeight: FontWeight.w600,fontSize: 12),),
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
                        likeCount:  article.vues,
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
                        likeCount:   article.contact,
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
                          await    categorieProduitProvider.getArticleById(article.id!).then((value) {
                            if (value.isNotEmpty) {
                              value.first.jaime=value.first.jaime!+1;
                              article.jaime=value.first.jaime!+1;
                              categorieProduitProvider.updateArticle(value.first,context).then((value) {
                                if (value) {


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
                        likeCount:   article.jaime,
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

                          await authProvider.createArticleLink(true,article).then((url) async {
                            final box = context.findRenderObject() as RenderBox?;

                            await Share.shareUri(
                              Uri.parse(
                                  '${url}'),
                              sharePositionOrigin:
                              box!.localToGlobal(Offset.zero) & box.size,
                            );

                            // printVm("article : ${article.toJson()}");
                            setState(() {
                              article.partage = article.partage! + 1;
                              // post.users_love_id!
                              //     .add(authProvider!.loginUserData.id!);
                              // love = post.loves!;
                              // //loves.add(idUser);
                            });

                            await    categorieProduitProvider.getArticleById(article.id!).then((value) {
                              if (value.isNotEmpty) {
                                value.first.partage=value.first.partage!+1;
                                // article.partage=value.first.partage!+1;
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
                                isEqualTo: article.user!.id!)
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
                              if (article.user!.oneIgnalUserid != null &&
                                  article.user!.oneIgnalUserid!.length > 5) {
                                await authProvider.sendNotification(
                                    userIds: [article.user!.oneIgnalUserid!],
                                    smallImage:
                                    "${authProvider.loginUserData.imageUrl!}",
                                    send_user_id:
                                    "${authProvider.loginUserData.id!}",
                                    recever_user_id: "${article.user!.id!}",
                                    message:
                                    "📢 🛒 @${authProvider.loginUserData.pseudo!} a partagé votre produit 🛒",
                                    type_notif:
                                    NotificationType.ARTICLE.name,
                                    post_id: "${article!.id!}",
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
                                "@${authProvider.loginUserData.pseudo!} a partagé votre produit 🛒";
                                notif.users_id_view = [];
                                notif.user_id =
                                    authProvider.loginUserData.id;
                                notif.receiver_id = article.user!.id!;
                                notif.post_id = article.id!;
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
                              //     article, context);
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
                        likeCount:   article.partage,
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

  @override
  Widget build(BuildContext context) {
    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;
    return  SingleChildScrollView(
      child: Column(
        //crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Container(
            // height: 40,
            // width: width*0.8,
            alignment: Alignment.center,
            color: Colors.black12,

            child:GestureDetector(
              onTap: () {
                setState(() {
                  is_search=true;
                });
              },
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10.0),
                child:is_search?Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Form(
                    key: _formKey,
                    child: TextFormField(
                      controller: _controller,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return "Veuillez entrer un nom de l'article";
                        }
                        return null;
                      },
                      decoration: InputDecoration(
                        hintText: 'Entrer le nom article',
                        prefixIcon: IconButton(
                          onPressed: () {
                            if (_formKey.currentState!.validate()) {
                              // Lancer la recherche avec le nom d'utilisateur saisi
                              print('Recherche de l\'utilisateur ${_controller.text}');
                              setState(() {
                                is_search=false;
                                item_selected-1;

                              });
                            }
                          },
                          icon: const Icon(Icons.arrow_back_outlined),
                        ),
                        suffixIcon: IconButton(
                          onPressed: () {
                            if (_formKey.currentState!.validate()) {
                              // Lancer la recherche avec le nom d'utilisateur saisi
                              print('Recherche de l\'utilisateur ${_controller.text}');
                              setState(() {

                              });
                            }
                          },
                          icon: const Icon(Icons.search),
                        ),
                      ),
                    ),
                  ),
                ): Container(
                  alignment: Alignment.center,
                  height: 40,
                  width: width * 0.8,
                  decoration: BoxDecoration(
                      color: CustomConstants.kPrimaryColor,
                      borderRadius: BorderRadius.all(Radius.circular(200))),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search,
                        color: Colors.white,
                      ),
                      SizedBox(
                        width: 10,
                      ),
                      Text(
                        "Rechercher un article",
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            height: 10,
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Container(
              height: height * 0.05,
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        is_selected = true;
                        item_selected = -1;
                        //  articles.shuffle();
                      });
                    },
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.all(Radius.circular(5)),
                          color: is_selected
                              ? CustomConstants.kPrimaryColor
                              : Colors.black38),
                      margin: EdgeInsets.all(2.0),
                      //  width: 120,
                      //height: 10,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          "Tous",
                          style: TextStyle(
                              fontSize: 12.0,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 5,
                  ),
                  Expanded(
                    child: FutureBuilder<List<Categorie>>(
                        future: categorieProduitProvider.getCategories(),
                        builder:
                            (BuildContext context, AsyncSnapshot snapshot) {
                          if (snapshot.hasData) {
                            return ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: snapshot.data.length,
                              itemBuilder: (context, index) {
                                return SizedBox(
                                  // height: 50,
                                    child: GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            categorieDataSelected=snapshot.data[index];
                                            is_selected = false;

                                            item_selected = index;
                                            //  articles.shuffle();
                                          });
                                        },
                                        child: CategoryItem(
                                            category: snapshot.data[index],
                                            is_selected: index)));
                              },
                            );
                          } else if (snapshot.hasError) {
                            return Icon(Icons.error_outline);
                          } else {
                            return Container(
                                height: 20,
                                width: 20,
                                alignment: Alignment.center,
                                child: CircularProgressIndicator());
                          }
                        }),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            height: 2,
          ),

          Padding(
            padding: const EdgeInsets.all(4.0),
            child: FutureBuilder<List<ArticleData>>(
                future:is_search?categorieProduitProvider.getSearhArticlesByEntreprise("${_controller.text}",item_selected, categorieDataSelected.id!,authProvider.loginUserData.id!):item_selected==-1?  categorieProduitProvider.getAllArticles():categorieProduitProvider.getArticlesByCategorie(categorieDataSelected!.id!),
                builder: (BuildContext context, AsyncSnapshot snapshot) {
                  if (snapshot.hasData) {
                    List<ArticleData> articles=snapshot.data;
                    return SingleChildScrollView(
                      child: Container(
                        height: height * 0.7,
                        width: width,
                        child: GridView.builder(
                          itemCount: articles.length,

                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            childAspectRatio: MediaQuery.of(context).size.width /
                                (MediaQuery.of(context).size.height/1.4 ),
                            crossAxisCount: 2, // Nombre de colonnes dans la grille
                            crossAxisSpacing:
                            10.0, // Espacement horizontal entre les éléments
                            mainAxisSpacing:
                            10.0, // Espacement vertical entre les éléments
                          ),
                          itemBuilder: (context, index) {
                            return ArticleTile( articles[index],width,height);
                          },
                        ),
                      ),
                    );
                  } else if (snapshot.hasError) {
                    return Icon(Icons.error_outline);
                  } else {
                    return CircularProgressIndicator();
                  }
                }),
          ),
        ],
      ),
    );
  }
}