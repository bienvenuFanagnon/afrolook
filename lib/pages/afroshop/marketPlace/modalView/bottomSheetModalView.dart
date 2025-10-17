import 'package:afrotok/pages/afroshop/marketPlace/component.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:provider/provider.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../../models/model_data.dart';
import '../../../../providers/afroshop/authAfroshopProvider.dart';
import '../../../../providers/afroshop/categorie_produits_provider.dart';
import '../../../../providers/authProvider.dart';
import '../../../../providers/postProvider.dart';
import '../acceuil/home_afroshop.dart';

class ArticleBottomSheet extends StatefulWidget {
  ArticleBottomSheet();

  @override
  State<ArticleBottomSheet> createState() => _ArticleBottomSheetState();
}

class _ArticleBottomSheetState extends State<ArticleBottomSheet> {
  late UserShopAuthProvider authShopProvider =
  Provider.of<UserShopAuthProvider>(context, listen: false);

  late UserAuthProvider authProvider =
  Provider.of<UserAuthProvider>(context, listen: false);

  late PostProvider postProvider =
  Provider.of<PostProvider>(context, listen: false);

  late CategorieProduitProvider categorieProduitProvider =
  Provider.of<CategorieProduitProvider>(context, listen: false);

  @override
  Widget build(BuildContext context) {
    double h = MediaQuery.of(context).size.height;
    double w = MediaQuery.of(context).size.width;
    return FutureBuilder<List<ArticleData>>(
      future: categorieProduitProvider.getArticleBooster(authProvider.loginUserData.countryData?['countryCode'] ?? 'TG'
      ),
      builder: (BuildContext context, AsyncSnapshot snapshot) {
        if (snapshot.hasData) {
          List<ArticleData> articles = snapshot.data;
          if (articles.isEmpty) {
            return SizedBox.shrink(); // Retourne un widget vide si la liste est vide
          }
          return SizedBox(
            height: h * 0.8,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.all(15.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Produits Boostés',
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black),
                              ),
                              SizedBox(width: 8),
                              Icon(
                                Icons.local_fire_department,
                                color: Colors.red,
                              ),
                            ],
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.pop(context); // Ferme la bottom sheet
                            },
                            child: Row(
                              children: [
                                Text(
                                  'Fermer',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red),
                                ),
                                SizedBox(width: 8),
                                Icon(
                                  Icons.close,
                                  color: Colors.red,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Créez votre boutique en ouvrant une entreprise sur AfroLook et publiez vos produits facilement. 🚀',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.left,
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => HomeAfroshopPage(title: ''),
                              ),
                            );
                          },
                          child: Row(
                            children: [
                              Text(
                                'Voir les Boutiques',
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green),
                              ),
                              SizedBox(width: 8),
                              Icon(
                                Icons.storefront,
                                color: Colors.red,
                              ),
                            ],
                            mainAxisAlignment: MainAxisAlignment.start,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: articles.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: ArticleTileSheetBooster(
                          key: ValueKey(articles[index].id), // Clé unique pour chaque élément
                          article: articles[index],
                          w: w,
                          h: h,
                          isOtherPage: true,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        } else if (snapshot.hasError) {
          return Icon(Icons.error_outline);
        } else {
          return SizedBox(
              height: 30,
              width: 30,child: Center(child: CircularProgressIndicator()));
        }
      },
    );
  }
}

