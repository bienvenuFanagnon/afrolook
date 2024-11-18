import 'package:afrotok/models/model_data.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:flutter_carousel_widget/flutter_carousel_widget.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:marquee/marquee.dart';
import 'package:provider/provider.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../constant/constColors.dart';
import '../../../constant/textCustom.dart';
import '../../../providers/authProvider.dart';
import '../../../providers/postProvider.dart';
import '../../../providers/userProvider.dart';
import '../../user/amis/pageMesInvitations.dart';
import 'cardModel.dart';
import 'card_exemple.dart';

import 'package:badges/badges.dart' as badges;


class UserCards extends StatefulWidget {
  const UserCards({
    super.key,
  });

  @override
  State<UserCards> createState() => _ExamplePageState();
}

class _ExamplePageState extends State<UserCards> {
  final CardSwiperController controller = CardSwiperController();
  late UserAuthProvider authProvider =
  Provider.of<UserAuthProvider>(context, listen: false);
  late UserProvider userProvider =
  Provider.of<UserProvider>(context, listen: false);
  final List<String> noms = ['Alice', 'Bob', 'Charlie'];
  late PostProvider postProvider =
  Provider.of<PostProvider>(context, listen: false);
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  late  List<ExampleCard>   cards = [];
  Stream<int> getNbrInvitation() async* {
    List<Invitation> invitations = [];
    var invitationsStream =FirebaseFirestore.instance.collection('Invitations')
        .where('receiver_id', isEqualTo: authProvider.loginUserData.id!)
        .where('status', isEqualTo: "${InvitationStatus.ENCOURS.name}")
        .snapshots();




    await for (var invitationsSnapshot in invitationsStream) {

      for (var invitationDoc in invitationsSnapshot.docs) {


        //userData=userList.first;

        Invitation invitation;

        invitation=Invitation.fromJson(invitationDoc.data());
        //  invitation.inviteUser=userList.first;
        invitations.add(invitation);


        userProvider.countInvitations=invitations.length;

      }
      yield invitations.length;
    }
  }

  @override
  void initState() {
    // TODO: implement initState
    cards =  userProvider.listUsers.map(ExampleCard.new).toList();
    super.initState();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: Colors.white12,
      appBar: AppBar(
        title: Text("Profiles"),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child:                 GestureDetector(
              onTap: () {




                Navigator.push(context, MaterialPageRoute(builder: (context) => MesInvitationsPage(context: context),));

              },
              child: Row(
                children: [
                  Text("Voir les invitations"),
                  SizedBox(width: 5,),
                  StreamBuilder<int>(
                      stream: getNbrInvitation(),
                      builder: (context, snapshot){
                        if(snapshot.hasError){
                          print("erreur: ${snapshot.error.toString()}");
                          return badges.Badge(
                            badgeContent: Text('1'),
                            showBadge: false,
                            child: Icon(
                              Entypo.message,
                              //AntDesign.message1,
                              size: 30,
                              color: ConstColors.blackIconColors,
                            ),
                          );
                        }else
                        if(snapshot.hasData){


                          if(snapshot.data!>0){
                            return badges.Badge(


                              badgeContent: snapshot.data!>10?Text('9+',style: TextStyle(fontSize:10,color: Colors.white ),):Text('${snapshot.data!}',style: TextStyle(fontSize:10,color: Colors.white ),),
                              child: Icon(
                                MaterialCommunityIcons.account_group,
                                //AntDesign.message1,
                                color: ConstColors.blackIconColors,

                              ),
                            );
                          }else{

                            return badges.Badge(
                              badgeContent: Text('1'),
                              showBadge: false,
                              child: Icon(
                                MaterialCommunityIcons.account_group,
                                //AntDesign.message1,
                                size: 30,

                                color: ConstColors.blackIconColors,
                              ),
                            );
                          }


                        }else{
                          print("data: ${snapshot.data}");
                          return badges.Badge(
                            badgeContent: Text('1'),
                            showBadge: false,
                            child: Icon(
                              MaterialCommunityIcons.account_group,
                              //AntDesign.message1,
                              size: 30,
                              color: ConstColors.blackIconColors,
                            ),
                          );
                        }


                      }
                  ),
                ],
              ),
            ),

          ),

        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Align(
            //   alignment: Alignment.centerLeft,
            //   child: Padding(
            //     padding: const EdgeInsets.only(top: 2.0,bottom: 0,left: 8),
            //     child: TextCustomerPostDescription(
            //       titre:
            //       "Flash Annonces ",
            //       fontSize: 15,
            //       couleur: Colors.green,
            //       fontWeight: FontWeight.w800,
            //     ),
            //   ),
            // ),
            // // SizedBox(height: 5,),
            // Row(
            //   crossAxisAlignment: CrossAxisAlignment.center,
            //   children: [
            //     Expanded(
            //       child: Padding(
            //         padding: const EdgeInsets.all(2.0),
            //         child: SizedBox(
            //           height: 20,
            //           child: Marquee(
            //             key: Key("keys"),
            //             text: "Pour tous vos besoins d'annonces publicitaires, veuillez nous contacter !",
            //             style: TextStyle(fontWeight: FontWeight.bold,color: Colors.white),
            //             scrollAxis: Axis.horizontal,
            //             crossAxisAlignment: CrossAxisAlignment.start,
            //             blankSpace: 20,
            //             velocity: 100,
            //             pauseAfterRound: Duration(seconds: 1),
            //             showFadingOnlyWhenScrolling: true,
            //             fadingEdgeStartFraction: 0.1,
            //             fadingEdgeEndFraction: 0.1,
            //             numberOfRounds: 1000,
            //
            //             startPadding: 10,
            //             accelerationDuration: Duration(milliseconds: 5000),
            //             accelerationCurve: Curves.linear,
            //             decelerationDuration: Duration(milliseconds: 1000),
            //             decelerationCurve: Curves.easeOut,
            //
            //           ),
            //         ),
            //       ),
            //     ),
            //     TextButton(onPressed: () {
            //       Navigator.pushNamed(context, '/contact');
            //
            //     }, child:      Container(
            //         height: 20,
            //         decoration: BoxDecoration(
            //             color: Colors.green,
            //             borderRadius: BorderRadius.all(Radius.circular(2))
            //         ),
            //         child: Padding(
            //           padding: const EdgeInsets.only(left: 2.0,right: 2,bottom: 1),
            //           child: Text("Contacter",style: TextStyle(color: Colors.white),),
            //         )))
            //   ],
            // ),
            // SizedBox(
            //   // width: width*0.8,
            //   //height: height*0.2,
            //   child: Padding(
            //     padding: const EdgeInsets.all(2.0),
            //     child: FlutterCarousel.builder(
            //       itemCount: userProvider.listAnnonces.length,
            //       itemBuilder: (BuildContext context, int itemIndex, int pageViewIndex) =>
            //           GestureDetector(
            //             onTap: () async {
            //               Annonce annonce=userProvider.listAnnonces[itemIndex];
            //               annonce.vues=annonce.vues!+1;
            //               await firestore.collection('Annonces').doc( annonce!.id).update( annonce!.toJson());
            //               _showUserDetailsAnnonceDialog('${userProvider.listAnnonces[itemIndex].media_url!}');
            //             },                        child: ClipRRect(
            //               borderRadius: BorderRadius.all(Radius.circular(10)),
            //               child: Container(
            //                 width: width*0.9,
            //                 height: height*0.2,
            //                 child: CachedNetworkImage(
            //                   fit: BoxFit.cover,
            //
            //                   imageUrl: '${userProvider.listAnnonces[itemIndex].media_url!}',
            //                   progressIndicatorBuilder: (context, url, downloadProgress) =>
            //                   //  LinearProgressIndicator(),
            //
            //                   Skeletonizer(
            //                       child: SizedBox(width: 120,height: 100, child:  ClipRRect(
            //                           borderRadius: BorderRadius.all(Radius.circular(10)),child: Image.asset('assets/images/404.png')))),
            //                   errorWidget: (context, url, error) =>  Container(width: 120,height: 100,child: Image.asset("assets/icon/user-removebg-preview.png",fit: BoxFit.cover,)),
            //                 ),
            //               ),
            //             ),
            //           ),
            //       options: CarouselOptions(
            //         autoPlay: true,
            //         //controller: buttonCarouselController,
            //         enlargeCenterPage: true,
            //         viewportFraction: 0.9,
            //         aspectRatio: 3.0,
            //         initialPage: 1,
            //         autoPlayInterval: const Duration(seconds: 2),
            //         autoPlayAnimationDuration: const Duration(milliseconds: 800),
            //         autoPlayCurve: Curves.fastOutSlowIn,
            //
            //       ),
            //     ),
            //   ),
            // ),
            //
            //
            // Divider(height: 10,),
            Flexible(
              child: cards.isEmpty?Container(): CardSwiper(
                controller: controller,
                cardsCount: cards.length,
                onSwipe: _onSwipe,
                onUndo: _onUndo,
                numberOfCardsDisplayed: 3,
                backCardOffset: const Offset(40, 40),
                padding: const EdgeInsets.all(24.0),
                cardBuilder: (
                    context,
                    index,
                    horizontalThresholdPercentage,
                    verticalThresholdPercentage,
                    ) =>
                cards[index],
              ),
            ),
            /*
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  FloatingActionButton(
                    onPressed: controller.undo,
                    child: const Icon(Icons.rotate_left),
                  ),
                  FloatingActionButton(
                    onPressed: () => controller.swipe(CardSwiperDirection.left),
                    child: const Icon(Icons.keyboard_arrow_left),
                  ),
                  FloatingActionButton(
                    onPressed: () =>
                        controller.swipe(CardSwiperDirection.right),
                    child: const Icon(Icons.keyboard_arrow_right),
                  ),
                  FloatingActionButton(
                    onPressed: () => controller.swipe(CardSwiperDirection.top),
                    child: const Icon(Icons.keyboard_arrow_up),
                  ),
                  FloatingActionButton(
                    onPressed: () =>
                        controller.swipe(CardSwiperDirection.bottom),
                    child: const Icon(Icons.keyboard_arrow_down),
                  ),
                ],
              ),
            ),

             */
            SizedBox(height: 20,)
          ],
        ),
      ),
    );
  }

  bool _onSwipe(
      int previousIndex,
      int? currentIndex,
      CardSwiperDirection direction,
      ) {
    debugPrint(
      'The card $previousIndex was swiped to the ${direction.name}. Now the card $currentIndex is on top',
    );
    return true;
  }

  bool _onUndo(
      int? previousIndex,
      int currentIndex,
      CardSwiperDirection direction,
      ) {
    debugPrint(
      'The card $currentIndex was undod from the ${direction.name}',
    );
    return true;
  }
}