


import 'package:afrotok/models/model_data.dart';
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
              borderRadius: BorderRadius.all(Radius.circular(200))
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
  return GestureDetector(
    onTap: () {
      Navigator.push(context, MaterialPageRoute(builder: (context) => CanalListPage(isUserCanals: false,),));
      Navigator.push(context, MaterialPageRoute(builder: (context) => CanalDetails(canal: data!),));

      // Action à effectuer lors du clic sur le widget
    },
    child: SizedBox(
      width: width * 0.2,
      child: Card(
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: height * 0.44,
                width: width * 0.2,
                child: Image.network(data.urlImage ?? '', fit: BoxFit.cover),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '#${data.titre ?? 'Titre'}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
                    ),
                    Text(
                      '${data.usersSuiviId!.length ?? 0} abonnés',
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                    Row(
                      spacing: 10,
                      children: [
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor:Colors.blue
                          ),
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => CanalListPage(isUserCanals: false,),));
                            Navigator.push(context, MaterialPageRoute(builder: (context) => CanalDetails(canal: data!),));

                            // Action à effectuer lors du clic sur le bouton "Suivre"
                          },
                          child: Text('Suivre',style: TextStyle(color: Colors.white),),
                        ),
                        Visibility(
                          visible: data!.isVerify!,
                          child: Card(
                            child: const Icon(
                              Icons.verified,
                              color: Colors.blue,
                              size: 20,
                            ),
                          ),
                        ),

                      ],
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