import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../models/model_data.dart';
import '../../../../providers/afroshop/authAfroshopProvider.dart';
import '../../../../providers/afroshop/categorie_produits_provider.dart';
import '../../../../providers/authProvider.dart';
import '../../../../providers/postProvider.dart';
import '../component.dart';

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
              // mainAxisSize: MainAxisSize.,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Produits Boostés',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.green),
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
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: articles.length,
                    itemBuilder: (context, index) {
                      return ArticleTileSheetBooster(
                        key: ValueKey(articles[index].id), // Clé unique pour chaque élément
                        article: articles[index],
                        w: w,
                        h: h,
                        isOtherPage: true,
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
          return CircularProgressIndicator();
        }
      },
    );
  }
}