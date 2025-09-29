


import 'package:afrotok/models/model_data.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:like_button/like_button.dart';
import 'package:provider/provider.dart';

import '../../providers/authProvider.dart';
import '../../providers/postProvider.dart';
import '../canaux/detailsCanal.dart';
import '../canaux/listCanal.dart';
import 'detailsUserService.dart';
import 'listUserService.dart';
bool isIn(List<String> users_id, String userIdToCheck) {
  return users_id.any((item) => item == userIdToCheck);
}
Widget userServiceWidget(UserServiceData data,double height,width,BuildContext context){
  late PostProvider postProvider =
  Provider.of<PostProvider>(context, listen: false);
  late UserAuthProvider authProvider =
  Provider.of<UserAuthProvider>(context, listen: false);
  String searchQuery = '';
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  return GestureDetector(
    onTap: () async {
      await    postProvider.getUserServiceById(data.id!).then((value) async {
        if (value.isNotEmpty) {
          data=value.first;
          data.vues=value.first.vues!+1;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => UserServiceListPage(),
            ),
          );
          Navigator.push(context, MaterialPageRoute(builder: (context) => DetailUserServicePage(data: data),));

          if(!isIn(data.usersViewId!, authProvider.loginUserData!.id!)){
            data.usersViewId!.add(authProvider.loginUserData!.id!) ;

          }
          postProvider.updateUserService(data,context).then((value) {
            if (value) {


            }
          },);
        }
      },);

    },
    child: SizedBox(
      // height: height*0.3,
      width: width*0.2,
      child: Card(
        child: Container(
          decoration: BoxDecoration(
              // borderRadius: BorderRadius.all(Radius.circular(200)),
              color: Colors.green.shade200

          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: height*0.44,
                width: width*0.2,

                child: Image.network(data.imageCourverture ?? '',fit: BoxFit.cover,),

              ),
              Padding(
                padding: const EdgeInsets.all(2.0),
                child: Column(

                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    Text(
                      data.titre ?? 'Titre',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
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
                          FontAwesome.eye,
                          color: isLiked ? Colors.black : Colors.brown,
                          size: 15,
                        );
                      },
                      likeCount:  data.vues,
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
            ],
          ),
        ),
      ),
    ),
  );
}

Widget channelWidget(Canal data, double height, double width, BuildContext context) {
  final afroGreen = Color(0xFF2ECC71);
  final afroYellow = Color(0xFFF1C40F);
  final afroBlack = Color(0xFF000000); // Noir pour le fond

  return GestureDetector(
    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CanalDetails(canal: data))),
    child: Container(
      width: width,
      height: height,
      margin: EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: afroBlack.withOpacity(0.8), // Fond noir semi-transparent
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: afroGreen.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: afroGreen.withOpacity(0.2),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Image ronde + vérification
            Stack(
              alignment: Alignment.center,
              children: [
                // Image ronde avec bordure verte
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: afroGreen, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: afroGreen.withOpacity(0.3),
                        blurRadius: 5,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: data.urlImage ?? '',
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        color: afroBlack,
                        child: Icon(Icons.group, color: afroGreen, size: 20),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: afroBlack,
                        child: Icon(Icons.group, color: afroGreen, size: 20),
                      ),
                    ),
                  ),
                ),
                // Badge vérification jaune
                if(data.isVerify ?? false)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: afroBlack,
                        shape: BoxShape.circle,
                        border: Border.all(color: afroYellow, width: 1),
                      ),
                      child: Icon(Icons.verified, color: afroYellow, size: 14),
                    ),
                  ),
              ],
            ),

            SizedBox(height: 6),

            // Titre en blanc
            Text(
              '#${data.titre ?? 'Sans titre'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.white, // Texte blanc
              ),
            ),

            SizedBox(height: 2),

            // Nombre d'abonnés en vert clair
            Text(
              '${data.usersSuiviId?.length ?? 0} abonnés',
              style: TextStyle(
                fontSize: 9,
                color: afroGreen.withOpacity(0.8), // Vert clair
              ),
            ),

            SizedBox(height: 4),

            // Bouton suivre vert
            Container(
              height: 20,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: afroGreen,
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                  minimumSize: Size(0, 0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CanalDetails(canal: data))),
                child: Text(
                  'Suivre',
                  style: TextStyle(
                    color: afroBlack, // Texte noir sur fond vert
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}