import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/pages/UserServices/detailsUserService.dart';
import 'package:afrotok/providers/authProvider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:like_button/like_button.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../providers/postProvider.dart';
import '../../../home/postUserWidget.dart';




class LookChallengeListPage extends StatefulWidget {
   final Challenge challenge;
   LookChallengeListPage({super.key, required this.challenge});
  @override
  State<LookChallengeListPage> createState() => _LookChallengeListPageState();
}

class _LookChallengeListPageState extends State<LookChallengeListPage> {
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
        title: Text('Look Challenges En cours 🔥🎁  Gagnez un Prix 🏆',style: TextStyle(color: Colors.white,fontSize: 18),),
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
                    hintText: 'Rechercher un look challenges  🔥🎁',
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
              FutureBuilder<List<LookChallenge>>(
                future: postProvider.getAllLookChallengesByChallenge(widget.challenge.id!),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Center(child: CircularProgressIndicator());
                  } else {
                    List<LookChallenge> list = snapshot.data!;
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
                            Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: Row(

                                children: [
                                  Text(
                                    'Les Look Challenges En Cours 🔥🎁🏆',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange, // Couleur du texte pour attirer l'attention
                                    ),
                                  ),

                                  Icon(
                                    Icons.card_giftcard, // Icône de cadeau pour symboliser la récompense
                                    color: Colors.green, // Couleur du cadeau
                                  ),
                                ],
                                mainAxisAlignment: MainAxisAlignment.start,
                              ),
                            ),
                            SizedBox(
                              height: height * 0.8,
                              child: ListView.builder(
                                scrollDirection: Axis.vertical,
                                itemCount: list.length,
                                itemBuilder: (context, index) {
                                  LookChallenge lookchallenge = list[index]!;
                                  // postProvider.getLookChallengeById(lookchallenge.id!).then(
                                  //       (value) {
                                  //     if (value.isNotEmpty) {
                                  //       lookchallenge = value.first!;
                                  //       lookchallenge.vues = lookchallenge.vues! + 1;
                                  //       postProvider.updateLookChallenge(lookchallenge);
                                  //     }
                                  //   },
                                  // );

                                  // Déterminer l'icône du trophée en fonction du rang
                                  Widget? trophy;
                                  if (index == 0) {
                                    trophy = Icon(Icons.emoji_events, color: Color(0xFFFFD700), size: 30); // Or
                                  } else if (index == 1) {
                                    trophy = Icon(Icons.emoji_events, color: Color.fromRGBO(192, 192, 192, 1), size: 30); // Argent
                                  } else if (index == 2) {
                                    trophy = Icon(Icons.emoji_events, color:  Color(0xFFCD7F32), size: 30); // Bronze
                                  }

                                  return Column(
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              // Widget pour afficher le rang
                                              CircleAvatar(
                                                backgroundColor: Colors.grey.shade300,
                                                child: Text(
                                                  (index + 1).toString(),
                                                  style: TextStyle(fontWeight: FontWeight.w900,),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              if (trophy != null) trophy, // Afficher le trophée si applicable
                                            ],
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.only(right: 8.0),
                                            child: Text(
                                              'Popularité : ${list[index]!.popularite!.toStringAsFixed(1)}%',
                                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                            ),
                                          )
                                        ],
                                      ),
                                      lookChallengeWidget(
                                        list[index]!,
                                        Colors.brown,
                                        height,
                                        width,
                                        context,
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),

                            // SizedBox(
                            //   height: height * 0.75,
                            //   // width: width * 0.8,
                            //   child: ListView.builder(
                            //     scrollDirection: Axis.vertical,
                            //     itemCount: list.length,
                            //     itemBuilder: (context, index) {
                            //       LookChallenge lookchallenge=list[index]!;
                            //       postProvider.getLookChallengeById(lookchallenge.id!).then(
                            //             (value) {
                            //           if(value.isNotEmpty){
                            //             lookchallenge=value.first!;
                            //             lookchallenge.vues  = lookchallenge.vues! + 1;
                            //
                            //             // vue = lookchallenge.vues!;
                            //             postProvider.updateLookChallenge(lookchallenge, context);
                            //
                            //             // setStateImages(() {
                            //             //
                            //             // });
                            //           }
                            //         },
                            //       );
                            //       return Column(
                            //         children: [
                            //
                            //           lookChallengeWidget(
                            //             list[index]!,
                            //             Colors.brown,
                            //             height,
                            //             width,
                            //             context,
                            //           ),
                            //         ],
                            //       );
                            //     },
                            //   ),
                            // ),
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