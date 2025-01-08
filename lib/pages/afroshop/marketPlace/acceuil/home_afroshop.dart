
import 'package:afrotok/pages/afroshop/marketPlace/acceuil/produit_details.dart';
import 'package:afrotok/providers/postProvider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:provider/provider.dart';
import 'package:like_button/like_button.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../../constant/custom_theme.dart';
import '../../../../constant/logo.dart';
import '../../../../models/model_data.dart';
import '../../../../providers/afroshop/authAfroshopProvider.dart';
import '../../../../providers/afroshop/categorie_produits_provider.dart';
import '../../../../providers/authProvider.dart';
import '../new/add_annonce_step_1.dart';


class HomeAfroshopPage extends StatefulWidget {
  const HomeAfroshopPage({super.key, required this.title});

  final String title;

  @override
  State<HomeAfroshopPage> createState() => _HomePageState();
}

class _HomePageState extends State<HomeAfroshopPage> {
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

  void _showBottomSheetCompterNonValide(double width) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          width: width,
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  "Compte entreprise requis",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 10),
                Text(
                  "Pour mettre en ligne un produit, vous devez avoir un compte entreprise. Veuillez créer un compte entreprise depuis votre profil ou cliquer sur le bouton ci-dessous.",
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () {
                    // Navigator.pop(context);
                    Navigator.pushNamed(context, '/home_profile_user');
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.business, color: Colors.white),
                      SizedBox(width: 5),
                      const Text('Créer un compte entreprise', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }



  Widget ArticleTile(ArticleData article,double w,double h) {
    print('article ${article.titre}');
    return Card(
      child: Container(
        child: Column(

          children: [
            GestureDetector(
              onTap: () async {
                // await  authProvider.getAfroshopUserById(article.user_id!).then(
                //   (value) async {
                //     if (value.isNotEmpty) {
                //       article.user=value.first;
                //   await    categorieProduitProvider.getArticleById(article.id!).then((value) async {
                //         if (value.isNotEmpty) {
                //           value.first.vues=value.first.vues!+1;
                //           article.vues=value.first.vues!+1;
                //         await  categorieProduitProvider.updateArticle(value.first,context).then((value) {
                //             if (value) {
                //
                //               Navigator.push(
                //                   context,
                //                   MaterialPageRoute(
                //                     builder: (context) =>
                //                         ProduitDetail(article: article),
                //                   ));
                //
                //             }
                //           },);
                //
                //         }
                //       },);
                //     }
                //   },
                // );

                await    categorieProduitProvider.getArticleById(article.id!).then((value) async {
                  if (value.isNotEmpty) {
                    value.first.vues=value.first.vues!+1;
                    article.vues=value.first.vues!+1;
                      categorieProduitProvider.updateArticle(value.first,context).then((value) {
                      if (value) {


                      }
                    },);
                    await    authProvider.getUserById(article.user_id!).then((users) {
                      if(users.isNotEmpty){
                        article.user=users.first;
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  ProduitDetail(article: article),
                            ));
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

                ],
              ),
            )


          ],
        ),
      ),
    );
  }
  bool is_search=false;
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    is_selected = true;
    item_selected = -1;

  }

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

  @override
  Widget build(BuildContext context) {
    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;

    return RefreshIndicator(

      onRefresh: ()async {

      },
      child: Scaffold(
        backgroundColor: Colors.white,

        appBar: AppBar(
          backgroundColor: Colors.black12,
          centerTitle: true,
          title: Container(
            // color: Colors.black12,
            height: 100,
            width: 100,
            alignment: Alignment.center,
            child: Image.asset(
              "assets/icons/afroshop_logo-removebg-preview.png",
              fit: BoxFit.cover,
            ),
          ),
          actions: [

            // Logo(),
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: TextButton(
                onPressed: () {
                  if (categorieProduitProvider.listCategorie.isNotEmpty) {
                    // if (authProvider.loginData.phone == null) {
                    //   _showBottomSheetCompterNonValide(width);
                    // }
                    // else{
                    //   Navigator.push(
                    //       context,
                    //       MaterialPageRoute(
                    //         builder: (context) => AddAnnonceStep1(),
                    //       ));
                    // }
                    postProvider.getEntreprise(authProvider.loginUserData.id!).then((value) {
                      if(value.isNotEmpty){
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AddAnnonceStep1(entrepriseData: value.first,),
                            ));
                      }else{
                        _showBottomSheetCompterNonValide(width);
                      }
                    });

                  }


                },
                child: Row(
                  spacing: 5,
                  children: [
                    Text("Publier",style: TextStyle(fontWeight: FontWeight.w600,color: CustomConstants.kPrimaryColor),),
                    Icon(Icons.add_circle_outline_outlined,color: CustomConstants.kPrimaryColor,),                  ],
                ),
              ),
            )

          ],
        ),
        // Définir le contenu du Drawer

        body: SingleChildScrollView(
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
                    future:is_search?categorieProduitProvider.getSearhArticles("${_controller.text}",item_selected, categorieDataSelected.id!):item_selected==-1?  categorieProduitProvider.getAllArticles():categorieProduitProvider.getArticlesByCategorie(categorieDataSelected!.id!),
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
        ),
        // This trailing comma makes auto-formatting nicer for build methods.
      ),
    );
  }
}



