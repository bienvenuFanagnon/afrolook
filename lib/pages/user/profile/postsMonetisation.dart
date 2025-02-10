
import 'package:afrotok/pages/afroshop/marketPlace/acceuil/produit_details.dart';
import 'package:afrotok/pages/user/profile/postMonetiserWidget.dart';
import 'package:afrotok/providers/postProvider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_carousel_widget/flutter_carousel_widget.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:provider/provider.dart';
import 'package:like_button/like_button.dart';
import 'package:share_plus/share_plus.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../../constant/custom_theme.dart';
import '../../../../constant/logo.dart';
import '../../../../models/model_data.dart';
import '../../../../providers/afroshop/authAfroshopProvider.dart';
import '../../../../providers/afroshop/categorie_produits_provider.dart';
import '../../../../providers/authProvider.dart';



class PostsMonetiserPage extends StatefulWidget {
  const PostsMonetiserPage({super.key, required this.title});

  final String title;

  @override
  State<PostsMonetiserPage> createState() => _HomePageState();
}

class _HomePageState extends State<PostsMonetiserPage> {
  late UserShopAuthProvider authShopProvider =
  Provider.of<UserShopAuthProvider>(context, listen: false);
  late UserAuthProvider authProvider =
  Provider.of<UserAuthProvider>(context, listen: false);
  late PostProvider postProvider =
  Provider.of<PostProvider>(context, listen: false);
  late CategorieProduitProvider categorieProduitProvider =
  Provider.of<CategorieProduitProvider>(context, listen: false);
  List<PostMonetiser> postsMonetiser = []; // Liste locale pour stocker les notifications


  final FirebaseFirestore firestore = FirebaseFirestore.instance;




  @override
  void initState() {
    // TODO: implement initState
    super.initState();


  }



  @override
  Widget build(BuildContext context) {
    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;
    postsMonetiser=[];
    return RefreshIndicator(

      onRefresh: ()async {

      },
      child: Scaffold(
        backgroundColor: Colors.white,

        appBar: AppBar(
          title: Text('Posts Monétiser', style: TextStyle(color: Colors.white)),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: IconButton(

                  onPressed: () {
                    setState(() {

                    });

              }, icon: Icon(Icons.refresh,color: Colors.white,)),
            )
          ],
          backgroundColor: Colors.green,
          centerTitle: true,
        ),        // Définir le contenu du Drawer

        body: SingleChildScrollView(
          child: Column(
            //crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[

              SizedBox(
                height: 2,
              ),

              SizedBox(
                height: height * 0.9,
                width: width,
                child: CustomScrollView(
                  slivers: [

                    SliverToBoxAdapter(
                      child: StreamBuilder<List<PostMonetiser>>(
                        stream: postProvider.getListPostsMonetiser(authProvider.loginUserData!.id!),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting && postsMonetiser.isEmpty) {
                            return Center(child: CircularProgressIndicator());
                          }

                          if (snapshot.hasError) {
                            return Center(child: Text("Erreur de chargement", style: TextStyle(color: Colors.red)));
                          }

                          // Mettre à jour la liste locale avec les nouvelles données
                          if (snapshot.hasData) {
                            postsMonetiser = snapshot.data!;
                          }

                          return Container(
                            width: width,
                            height: height * 0.86,
                            child: GridView.builder(
                              itemCount: postsMonetiser.length,
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2, // Nombre de colonnes dans la grille
                                crossAxisSpacing: 10.0, // Espacement horizontal entre les éléments
                                mainAxisSpacing: 10.0, // Espacement vertical entre les éléments
                                childAspectRatio: MediaQuery.of(context).size.width /
                                    (MediaQuery.of(context).size.height / 1.4),
                              ),
                              itemBuilder: (context, index) {
                                PostMonetiser postM = postsMonetiser[index];

                                return Padding(
                                  padding: const EdgeInsets.all(4.0),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.all(Radius.circular(5)),
                                      color: Colors.white,
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(2.0),
                                      child: PostMonetiserWidget(post: postM),
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ),
                    // SliverToBoxAdapter(
                    //   child: StreamBuilder<PostMonetiser>(
                    //     stream:  postProvider.getListPostsMonetiser(authProvider.loginUserData!.id!),
                    //     builder: (context, snapshot) {
                    //       if (snapshot.connectionState == ConnectionState.waiting && postsMonetiser.isEmpty) {
                    //         return Center(child: CircularProgressIndicator());
                    //       }
                    //
                    //       if (snapshot.hasError) {
                    //         return Center(child: Text("Erreur de chargement", style: TextStyle(color: Colors.red)));
                    //       }
                    //
                    //       // Ajouter le nouvel article à la liste locale
                    //       if (snapshot.hasData && !postsMonetiser.contains(snapshot.data!)) {
                    //         postsMonetiser.add(snapshot.data!);
                    //       }
                    //
                    //       return Container(
                    //         width: width,
                    //         height: height * 0.86,
                    //         child: GridView.builder(
                    //           itemCount: postsMonetiser.length,
                    //           gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    //             crossAxisCount: 2, // Nombre de colonnes dans la grille
                    //             crossAxisSpacing: 10.0, // Espacement horizontal entre les éléments
                    //             mainAxisSpacing: 10.0, // Espacement vertical entre les éléments
                    //             childAspectRatio: MediaQuery.of(context).size.width /
                    //                 (MediaQuery.of(context).size.height / 1.4),
                    //           ),
                    //           itemBuilder: (context, index) {
                    //             PostMonetiser postM = postsMonetiser[index];
                    //
                    //             return Padding(
                    //               padding: const EdgeInsets.all(4.0),
                    //               child: Container(
                    //                 decoration: BoxDecoration(
                    //                   borderRadius: BorderRadius.all(Radius.circular(5)),
                    //                   color: Colors.white,
                    //                 ),
                    //                 child: Padding(
                    //                   padding: const EdgeInsets.all(2.0),
                    //                   child: PostMonetiserWidget(post: postM),
                    //                 ),
                    //               ),
                    //             );
                    //           },
                    //         ),
                    //       );
                    //     },
                    //   ),
                    // ),
                  ],
                ),
              )
              // Padding(
              //   padding: const EdgeInsets.all(4.0),
              //   child: FutureBuilder<List<ArticleData>>(
              //       future:is_search?categorieProduitProvider.getSearhArticles("${_controller.text}",item_selected, categorieDataSelected.id!):item_selected==-1?  categorieProduitProvider.getAllArticles():categorieProduitProvider.getArticlesByCategorie(categorieDataSelected!.id!),
              //       builder: (BuildContext context, AsyncSnapshot snapshot) {
              //         if (snapshot.hasData) {
              //           List<ArticleData> articles=snapshot.data;
              //           return SingleChildScrollView(
              //             child: Container(
              //               height: height * 0.7,
              //               width: width,
              //               child: GridView.builder(
              //                 itemCount: articles.length,
              //
              //                 gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              //                   childAspectRatio: MediaQuery.of(context).size.width /
              //                       (MediaQuery.of(context).size.height/1.4 ),
              //                   crossAxisCount: 2, // Nombre de colonnes dans la grille
              //                   crossAxisSpacing:
              //                   10.0, // Espacement horizontal entre les éléments
              //                   mainAxisSpacing:
              //                   10.0, // Espacement vertical entre les éléments
              //                 ),
              //                 itemBuilder: (context, index) {
              //                   return ArticleTile( articles[index],width,height);
              //                 },
              //               ),
              //             ),
              //           );
              //         } else if (snapshot.hasError) {
              //           return Icon(Icons.error_outline);
              //         } else {
              //           return CircularProgressIndicator();
              //         }
              //       }),
              // ),
            ],
          ),
        ),
        // This trailing comma makes auto-formatting nicer for build methods.
      ),
    );
  }
}



