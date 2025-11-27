import 'package:flutter/material.dart';

import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/pages/afroshop/marketPlace/component.dart';
import 'package:afrotok/pages/canaux/listCanal.dart';
import 'package:afrotok/pages/afroshop/marketPlace/acceuil/home_afroshop.dart';

import '../../../UserServices/ServiceWidget.dart';
import '../../../auth/authTest/Screens/Login/loginPageUser.dart';

class SpecialSectionsComponent {
  static Widget buildBoosterSection({
    required List<ArticleData> articles,
    required BuildContext context,
    required double width,
    required double height,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      height: height * 0.32,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Produits boostés 🔥",
                  style: TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const HomeAfroshopPage(title: ''))),
                  child: Row(
                    children: [
                      Text('Boutiques', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: primaryGreen)),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward, color: primaryGreen, size: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 8),
              itemCount: articles.length,
              itemBuilder: (context, index) {
                return Container(
                  width: width * 0.4,
                  margin: EdgeInsets.symmetric(horizontal: 4),
                  child: ProductWidget(
                    article: articles[index],
                    width: width * 0.28,
                    height: height * 0.2,
                    isOtherPage: false,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static Widget buildCanalSection({
    required List<Canal> canaux,
    required BuildContext context,
    required double width,
    required double height,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      height: height * 0.23,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Canaux à suivre 📺",
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => CanalListPage(isUserCanals: false))),
                  child: Row(
                    children: [
                      Text('Voir plus', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: primaryGreen)),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward, color: primaryGreen, size: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 8),
              itemCount: canaux.length,
              itemBuilder: (context, index) {
                return Container(
                  width: width * 0.3,
                  margin: EdgeInsets.symmetric(horizontal: 4),
                  child: channelWidget(
                    canaux[index],
                    height * 0.28,
                    width * 0.28,
                    context,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}