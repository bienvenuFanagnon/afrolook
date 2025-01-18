import 'package:afrotok/pages/UserServices/detailsUserService.dart';
import 'package:afrotok/providers/authProvider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:like_button/like_button.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../models/model_data.dart';
import '../../../providers/postProvider.dart';
import '../../home/postUserWidget.dart';



class ChallengeListPage extends StatefulWidget {
  @override
  State<ChallengeListPage> createState() => _ChallengeListPageState();
}

class _ChallengeListPageState extends State<ChallengeListPage> {
  late PostProvider postProvider =
  Provider.of<PostProvider>(context, listen: false);
  late UserAuthProvider authProvider =
  Provider.of<UserAuthProvider>(context, listen: false);
  String searchQuery = '';
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  bool onSaveTap=false;
  bool isIn(List<String> users_id, String userIdToCheck) {
    return users_id.any((item) => item == userIdToCheck);
  }



  @override
  Widget build(BuildContext context) {

    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Text('Challenges Disponibles 🔥🎁  Gagnez un Prix 🏆',style: TextStyle(color: Colors.white,fontSize: 18),),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              icon: Icon(Icons.refresh,size: 30,),
              color: Colors.white,
              onPressed: () {
                setState(() {

                });
                // Action lors du clic sur le bouton
              },
            ),
          ),
          // Padding(
          //   padding: const EdgeInsets.only(right: 8.0),
          //   child: IconButton(
          //     icon: Icon(Icons.add_box,size: 30,),
          //     color: Colors.white,
          //     onPressed: () {
          //       Navigator.push(context, MaterialPageRoute(builder: (context) => UserServiceForm(),));
          //
          //       // Action lors du clic sur le bouton
          //     },
          //   ),
          // ),
        ],
        backgroundColor: Colors.green,
      ),
      body: RefreshIndicator(
        onRefresh: () async{
          setState(() {

          });
        },
        child: SingleChildScrollView(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(10.0),
                child: TextFormField(
                  decoration: InputDecoration(
                    hintText: 'Rechercher un challenges  🔥🎁',
                    hintStyle: TextStyle(color: Colors.black),
                    // border: InputBorder.,
                  ),
                  style: TextStyle(color: Colors.black),
                  onChanged: (query) {
                    setState(() {
                      searchQuery = query;
                    });
                  },
                ),
              ),
              FutureBuilder<List<Challenge>>(
                future: postProvider.getAllChallenges(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Center(child: CircularProgressIndicator());
                  } else {
                    List<Challenge> list = snapshot.data!;
                    list;
                    // userList.shuffle();
                    if(list.isEmpty){
                      return SizedBox.shrink();
                    }else{
                      return Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Challenges Disponibles 🔥🎁',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange, // Couleur du texte pour attirer l'attention
                                  ),
                                ),
                                SizedBox(width: 8),
                                Icon(
                                  Icons.local_fire_department, // Icône de feu pour illustrer l'excitation
                                  color: Colors.red, // Couleur du feu
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Gagnez un Prix 🏆',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green, // Couleur du texte pour un appel à l'action positif
                                  ),
                                ),
                                SizedBox(width: 8),
                                Icon(
                                  Icons.card_giftcard, // Icône de cadeau pour symboliser la récompense
                                  color: Colors.green, // Couleur du cadeau
                                ),
                              ],
                              mainAxisAlignment: MainAxisAlignment.start,
                            )
                            ,
                            SizedBox(
                              height: height * 0.75,
                              // width: width * 0.8,
                              child: ListView.builder(
                                scrollDirection: Axis.vertical,
                                itemCount: list.length,
                                itemBuilder: (context, index) {
                                  return homeChallenge(
                                    list[index]!,
                                    Colors.brown,
                                    height,
                                    width,
                                    context,
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      );

                    }

                  }
                },
              )
            ],
          ),
        ),
      ),
    );
  }
}

class IconText extends StatelessWidget {
  final IconData icon;
  final String text;

  IconText({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16),
        SizedBox(width: 4),
        // Text(text),
      ],
    );
  }
}