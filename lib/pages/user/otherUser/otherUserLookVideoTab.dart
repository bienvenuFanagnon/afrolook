import 'package:flutter/material.dart';

import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';

import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:intl/intl.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:popup_menu/popup_menu.dart';
import 'package:provider/provider.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../../constant/constColors.dart';
import '../../../../constant/listItemsCarousel.dart';
import '../../../../constant/sizeText.dart';
import '../../../../constant/textCustom.dart';
import '../../../../models/model_data.dart';
import '../../../../providers/authProvider.dart';
import '../../../../providers/postProvider.dart';
import '../../../../providers/userProvider.dart';
import '../../component/consoleWidget.dart';
import '../../postComments.dart';
import '../../socialVideos/afrovideos/SimpleVideoView.dart';


class OtherUserLookVideoTab extends StatefulWidget {
  final UserData otherUser;

  const OtherUserLookVideoTab({super.key, required this.otherUser});

  @override
  State<OtherUserLookVideoTab> createState() => _OtherUserLookVideoTabState();
}

class _OtherUserLookVideoTabState extends State<OtherUserLookVideoTab> {
  final _formKey = GlobalKey<FormState>();

  GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  late UserAuthProvider authProvider =
  Provider.of<UserAuthProvider>(context, listen: false);

  late UserProvider userProvider =
  Provider.of<UserProvider>(context, listen: false);

  late PostProvider postProvider =
  Provider.of<PostProvider>(context, listen: false);

  TextEditingController commentController =TextEditingController();
  String formaterDateTime2(DateTime dateTime) {
    DateTime now = DateTime.now();

    if (dateTime.year == now.year &&
        dateTime.month == now.month &&
        dateTime.day == now.day) {
      // Si la date est aujourd'hui, afficher seulement l'heure et la minute
      return DateFormat.Hm().format(dateTime);
    } else {
      // Sinon, afficher la date complète
      return DateFormat.yMd().add_Hms().format(dateTime);
    }
  }

  String formaterDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays < 1) {
      // Si c'est le même jour
      if (difference.inHours < 1) {
        // Si moins d'une heure
        if (difference.inMinutes < 1) {
          return "publié il y a quelques secondes";
        } else {
          return "publié il y a ${difference.inMinutes} minutes";
        }
      } else {
        return "publié il y a ${difference.inHours} heures";
      }
    } else if (difference.inDays < 7) {
      // Si la semaine n'est pas passée
      return "publié ${difference.inDays} jours plus tôt";
    } else {
      // Si le jour est passé
      return "publié depuis ${DateFormat('dd MMMM yyyy').format(dateTime)}";
    }
  }
  PopupMenu? postmenu;


  bool isUserAbonne(List<UserAbonnes> userAbonnesList, String userIdToCheck) {
    return userAbonnesList.any((userAbonne) => userAbonne.abonneUserId == userIdToCheck);
  }

  bool isIn(List<String> users_id, String userIdToCheck) {
    return users_id.any((item) => item == userIdToCheck);
  }

  bool isMyFriend(List<Friends> userfriendList, String userIdToCheck) {
    return userfriendList.any((userAbonne) => userAbonne.friendId == userIdToCheck);
  }
  bool isInvite(List<Invitation> invitationList, String userIdToCheck) {
    return invitationList.any((inv) => inv.receiverId == userIdToCheck);
  }

  void _showModalDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Menu d\'options'),
          content: SingleChildScrollView(
            child: Column(
              children: <Widget>[
                ListTile(
                  onTap: () {
                    Navigator.pop(context);
                  },
                  leading: Icon(Icons.flag,color: Colors.blueGrey,),
                  title: Text('Signaler',),
                ),
                ListTile(
                  onTap: () {
                    Navigator.pop(context);
                  },
                  leading: Icon(Icons.edit,color: Colors.blue,),
                  title: Text('Modifier'),
                ),
                ListTile(
                  onTap: () {
                    Navigator.pop(context);
                  },
                  leading: Icon(Icons.delete,color: Colors.red,),
                  title: Text('Supprimer'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String formatNumber(int number) {
    if (number < 1000) {
      return number.toString();
    } else if (number < 1000000) {
      return "${number / 1000} k";
    } else if (number < 1000000000) {
      return "${number / 1000000} m";
    } else {
      return "${number / 1000000000} b";
    }
  }



  Widget homePostUsers(Post post,double height, double width) {
    double h = MediaQuery.of(context).size.height;
    double w = MediaQuery.of(context).size.width;

    Random random = Random();
    bool abonneTap =false;
    int like=post!.likes!;
    int imageIndex=0;
    int love=post!.loves!;
    int comments=post!.comments!;
    bool tapLove=isIn(post.users_love_id!,authProvider.loginUserData.id!);
    bool tapLike=isIn(post.users_like_id!,authProvider.loginUserData.id!);
    List<int> likes =[];
    List<int> loves =[];
    int idUser=7;
    return Container(
      child: StatefulBuilder(
          builder: (BuildContext context, StateSetter setStateImages) {
            return Padding(
              padding: const EdgeInsets.all(5.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: CircleAvatar(
                              backgroundImage: NetworkImage(
                                  '${post.user!.imageUrl!}'),
                            ),
                          ),
                          SizedBox(
                            height: 2,
                          ),
                          Row(
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,

                                children: [
                                  SizedBox(
                                    //width: 100,
                                    child: TextCustomerUserTitle(
                                      titre: "@${post.user!.pseudo!}",
                                      fontSize: SizeText.homeProfileTextSize,
                                      couleur: ConstColors.textColors,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  TextCustomerUserTitle(
                                    titre: "${formatNumber(post.user!.abonnes!)} abonné(s)",
                                    fontSize: SizeText.homeProfileTextSize,
                                    couleur: ConstColors.textColors,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ],
                              ),
                              StatefulBuilder(

                                  builder: (BuildContext context, void Function(void Function()) setState) {
                                    return Container(
                                      child: isUserAbonne(authProvider.loginUserData.userAbonnes!, post.user!.id!)?Container(): TextButton(

                                          onPressed:abonneTap?
                                              ()  { }:
                                              ()async{
                                            if (!isUserAbonne(authProvider.loginUserData.userAbonnes!, post.user!.id!)) {
                                              setState(() {
                                                abonneTap=true;
                                              });
                                              UserAbonnes userAbonne = UserAbonnes();
                                              userAbonne.compteUserId=authProvider.loginUserData.id;
                                              userAbonne.abonneUserId=post.user!.id;

                                              userAbonne.createdAt  = DateTime.now().millisecondsSinceEpoch;
                                              userAbonne.updatedAt  = DateTime.now().millisecondsSinceEpoch;
                                              await  userProvider.sendAbonnementRequest(userAbonne,post.user!,context).then((value) async {
                                                if (value) {
                                                  authProvider.loginUserData.userAbonnes!.add(userAbonne);
                                                  // await userProvider.getUsers(authProvider.loginUserData!.id!);
                                                  await authProvider.getCurrentUser(authProvider.loginUserData!.id!);
                                                  SnackBar snackBar = SnackBar(
                                                    content: Text('abonné',textAlign: TextAlign.center,style: TextStyle(color: Colors.green),),
                                                  );
                                                  ScaffoldMessenger.of(context).showSnackBar(snackBar);
                                                  setState(() {
                                                    abonneTap=false;
                                                  });
                                                }  else{
                                                  SnackBar snackBar = SnackBar(
                                                    content: Text('une erreur',textAlign: TextAlign.center,style: TextStyle(color: Colors.red),),
                                                  );
                                                  ScaffoldMessenger.of(context).showSnackBar(snackBar);
                                                  setState(() {
                                                    abonneTap=false;
                                                  });
                                                }
                                              },);


                                              setState(() {
                                                abonneTap=false;
                                              });
                                            }

                                          },
                                          child:abonneTap? Center(
                                            child: LoadingAnimationWidget.flickr(
                                              size: 20,
                                              leftDotColor: Colors.green,
                                              rightDotColor: Colors.black,
                                            ),
                                          ): Text("S'abonner",style: TextStyle(fontSize: 12,fontWeight:FontWeight.normal,color: Colors.blue),)
                                      ),
                                    );
                                  }
                              ),
                              /*
                            IconButton(
                                onPressed: () {},
                                icon: Icon(
                                  Icons.add_circle_outlined,
                                  size: 20,
                                  color: ConstColors.regIconColors,
                                )),

                             */
                            ],
                          ),
                        ],
                      ),
                      IconButton(
                          onPressed: _showModalDialog,
                          icon: Icon(
                            Icons.more_horiz,
                            size: 30,
                            color: ConstColors.blackIconColors,
                          )),
                    ],
                  ),
                  SizedBox(
                    height: 5,
                  ),
                  Align(
                    alignment: Alignment.topLeft,
                    child: SizedBox(
                      width: 300,
                      //height: 50,
                      child: Container(
                        alignment: Alignment.centerLeft,
                        child: TextCustomerPostDescription(
                          titre:
                          "${post.description}",
                          fontSize: SizeText.homeProfileTextSize,
                          couleur: ConstColors.textColors,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 5,
                  ),
                  Align(
                    alignment: Alignment.topLeft,
                    child: TextCustomerPostDescription(
                      titre: "${formaterDateTime(DateTime.fromMicrosecondsSinceEpoch(post.createdAt!))}",
                      fontSize: SizeText.homeProfileDateTextSize,
                      couleur: ConstColors.textColors,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(
                    height: 5,
                  ),
                  post!.images==null? Container():

                  Container(
                    width: w,
                    height: h*0.3,

                    child: ClipRRect(
                      borderRadius: BorderRadius.all(Radius.circular(5)),
                      child: SimpleVideoPlayerWidget(videoUrl: '${post!.url_media==null?'':post!.url_media}'),
                    ),
                  ),



                  SizedBox(
                    height: 10,
                  ),
                  Container(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        StatefulBuilder(
                            builder: (BuildContext context, StateSetter setState) {
                              return GestureDetector(
                                onTap: () {
                                  if (!isIn(post.users_love_id!,authProvider.loginUserData.id!)) {

                                  }


                                },
                                child: Container(
                                  //height: 20,
                                  width: 70,
                                  height: 30,
                                  child: Row(

                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    // mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            tapLove?Ionicons.heart:Ionicons.md_heart_outline,color: Colors.red,
                                            size: 20,
                                            // color: ConstColors.likeColors,
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.only(left: 1.0,right: 1),
                                            child: TextCustomerPostDescription(
                                              titre: "${love}",
                                              fontSize: SizeText.homeProfileDateTextSize,
                                              couleur: ConstColors.textColors,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.only(left: 1.0,right: 1),
                                          child: SizedBox(
                                            height: 2,
                                            width: 5,
                                            child: LinearProgressIndicator(
                                              color: Colors.red,
                                              value: love/505,
                                              semanticsLabel: 'Linear progress indicator',
                                            ),
                                          ),
                                        ),
                                      ),
                                      TextCustomerPostDescription(
                                        titre: "${(love/505*100).toStringAsFixed(2)}%",
                                        fontSize: SizeText.homeProfileDateTextSize,
                                        couleur: ConstColors.textColors,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }
                        ),

                        // StatefulBuilder(
                        //     builder: (BuildContext context, StateSetter setState) {
                        //       return GestureDetector(
                        //         onTap: () {
                        //           if (!isIn(post.users_like_id!,authProvider.loginUserData.id!)) {
                        //
                        //           }
                        //
                        //
                        //         },
                        //         child: Container(
                        //           width: 70,
                        //           height: 30,
                        //           child: Row(
                        //
                        //             crossAxisAlignment: CrossAxisAlignment.center,
                        //             // mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        //             children: [
                        //               Row(
                        //                 children: [
                        //                   Icon(
                        //                     tapLike?MaterialCommunityIcons.thumb_up:MaterialCommunityIcons.thumb_up_outline,
                        //                     size: 20,
                        //                     color: tapLike?Colors.blue:Colors.black,
                        //                   ),
                        //                   Padding(
                        //                     padding: const EdgeInsets.only(left: 1.0,right: 1),
                        //                     child: TextCustomerPostDescription(
                        //                       titre: "${like}",
                        //                       fontSize: SizeText.homeProfileDateTextSize,
                        //                       couleur: ConstColors.textColors,
                        //                       fontWeight: FontWeight.bold,
                        //                     ),
                        //                   ),
                        //                 ],
                        //               ),
                        //               Expanded(
                        //                 child: Padding(
                        //                   padding: const EdgeInsets.only(left: 1.0,right: 1),
                        //                   child: SizedBox(
                        //                     height: 2,
                        //                     // width: width*0.75,
                        //                     child: LinearProgressIndicator(
                        //                       color: Colors.blue,
                        //                       value: like/post.user!.abonnes!+1,
                        //                       semanticsLabel: 'Linear progress indicator',
                        //                     ),
                        //                   ),
                        //                 ),
                        //               ),
                        //               TextCustomerPostDescription(
                        //                 titre: "${(like/post.user!.abonnes!*100+1).toStringAsFixed(2)}%",
                        //                 fontSize: SizeText.homeProfileDateTextSize,
                        //                 couleur: ConstColors.textColors,
                        //                 fontWeight: FontWeight.bold,
                        //               ),
                        //             ],
                        //           ),
                        //         ),
                        //       );
                        //     }
                        // ),

                        StatefulBuilder(
                            builder: (BuildContext context, StateSetter setState) {
                              return   GestureDetector(
                                onTap: () {
                                  Navigator.push(context, MaterialPageRoute(builder: (context) => PostComments(post: post),));

                                },
                                child: Container(
                                  width: 70,
                                  height: 30,
                                  child: Row(

                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    // mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            FontAwesome.comments,
                                            size: 20,
                                            color: Colors.green,
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.only(left: 1.0,right: 1),
                                            child: TextCustomerPostDescription(
                                              titre: "${comments}",
                                              fontSize: SizeText.homeProfileDateTextSize,
                                              couleur: ConstColors.textColors,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.only(left: 1.0,right: 1),
                                          child: SizedBox(
                                            height: 2,
                                            //width: width*0.75,
                                            child: LinearProgressIndicator(
                                              color: Colors.blueGrey,
                                              value: comments/505,
                                              semanticsLabel: 'Linear progress indicator',
                                            ),
                                          ),
                                        ),
                                      ),
                                      TextCustomerPostDescription(
                                        titre: "${(comments/505*100).toStringAsFixed(2)}%",
                                        fontSize: SizeText.homeProfileDateTextSize,
                                        couleur: ConstColors.textColors,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }
                        ),





                      ],
                    ),
                  ),


                  SizedBox(
                    height: 10,
                  ),
                  Divider(
                    height: 3,
                  )

                ],
              ),
            );
          }
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child:  Padding(
          padding: const EdgeInsets.only(left: 8.0,right: 8,top: 2),
          child: StreamBuilder<List<Post>>(
            stream: postProvider.getPostsVideoByUser(widget.otherUser.id!),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                printVm("attente");
                return SizedBox(
                  //height: height,
                  width: width,
                  child: Column(

                    mainAxisSize: MainAxisSize.max,
                    children: [
                      for(Post p in postProvider.listConstposts)
                        Skeletonizer(

                          child: Padding(
                            padding: const EdgeInsets.only(top: 5.0,bottom: 5),
                            child: homePostUsers(p,height, width),
                          ),
                        )
                    ],
                  ),
                );
              } else if (snapshot.hasError) {
                printVm("erreur ${snapshot.error}");
                return
                  Skeletonizer(

                    //enabled: _loading,
                    child: SizedBox(
                      width: width,
                      height: height*0.4,
                      child: ListView.builder
                        (
                        scrollDirection: Axis.vertical,
                        itemCount: 5,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.all(1.0),
                            child: Container(
                              width: 300,
                              child: Card(
                                color: Colors.white,
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Column(
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              Padding(
                                                padding: const EdgeInsets.only(right: 8.0),
                                                child: CircleAvatar(
                                                  backgroundImage: AssetImage(
                                                      'assets/images/404.png'),
                                                ),
                                              ),
                                              SizedBox(
                                                height: 2,
                                              ),
                                              Row(
                                                children: [
                                                  Column(
                                                    children: [
                                                      SizedBox(
                                                        //width: 100,
                                                        child: TextCustomerUserTitle(
                                                          titre: "pseudo",
                                                          fontSize: SizeText.homeProfileTextSize,
                                                          couleur: ConstColors.textColors,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                      TextCustomerUserTitle(
                                                        titre: " abonné(s)",
                                                        fontSize: SizeText.homeProfileTextSize,
                                                        couleur: ConstColors.textColors,
                                                        fontWeight: FontWeight.w400,
                                                      ),
                                                    ],
                                                  ),
                                                  TextButton(onPressed: () {  },
                                                      child: Text("S'abonner",style: TextStyle(fontSize: 12,fontWeight:FontWeight.normal,color: Colors.blue),)
                                                  ),
                                                  /*
                                                          IconButton(
                                                              onPressed: () {},
                                                              icon: Icon(
                                                                Icons.add_circle_outlined,
                                                                size: 20,
                                                                color: ConstColors.regIconColors,
                                                              )),

                                                           */
                                                ],
                                              ),
                                            ],
                                          ),
                                          IconButton(
                                              onPressed: () {},
                                              icon: Icon(
                                                Icons.more_horiz,
                                                size: 30,
                                                color: ConstColors.blackIconColors,
                                              )),
                                        ],
                                      ),
                                      SizedBox(
                                        height: 5,
                                      ),
                                      Align(
                                        alignment: Alignment.topLeft,
                                        child: SizedBox(
                                          width: 300,
                                          //height: 50,
                                          child: Container(
                                            alignment: Alignment.centerLeft,
                                            child: TextCustomerPostDescription(
                                              titre:
                                              "...Afficher plus",
                                              fontSize: SizeText.homeProfileTextSize,
                                              couleur: ConstColors.textColors,
                                              fontWeight: FontWeight.normal,
                                            ),
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        height: 5,
                                      ),
                                      Align(
                                        alignment: Alignment.topLeft,
                                        child: TextCustomerPostDescription(
                                          titre: "11/12/2023",
                                          fontSize: SizeText.homeProfileDateTextSize,
                                          couleur: ConstColors.textColors,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      SizedBox(
                                        height: 2,
                                      ),
                                      ListItemSlider(
                                        sliders: [
                                          ClipRRect(
                                              borderRadius: BorderRadius.all(Radius.circular(10)),
                                              child: Image.asset(
                                                "assets/images/404.png",
                                                fit: BoxFit.cover,
                                                height: 300,
                                              )),

                                        ],
                                      ),
                                      SizedBox(
                                        height: 5,
                                      ),
                                      Container(
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          mainAxisSize: MainAxisSize.max,
                                          children: [
                                            GestureDetector(
                                              onTap: () {
                                                setState(() {
                                                  //loves.add(idUser);
                                                });

                                              },
                                              child: Container(
                                                //height: 20,
                                                width: 110,
                                                height: 30,
                                                child: Row(

                                                  crossAxisAlignment: CrossAxisAlignment.center,
                                                  // mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Icon(
                                                          Icons.heart_broken_outlined,color: Colors.red,
                                                          size: 20,
                                                          // color: ConstColors.likeColors,
                                                        ),
                                                        Padding(
                                                          padding: const EdgeInsets.only(left: 1.0,right: 1),
                                                          child: TextCustomerPostDescription(
                                                            titre: "20",
                                                            fontSize: SizeText.homeProfileDateTextSize,
                                                            couleur: ConstColors.textColors,
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    Expanded(
                                                      child: Padding(
                                                        padding: const EdgeInsets.only(left: 1.0,right: 1),
                                                        child: SizedBox(
                                                          height: 2,
                                                          width: 10,
                                                          child: LinearProgressIndicator(
                                                            color: Colors.red,
                                                            value: 10/505,
                                                            semanticsLabel: 'Linear progress indicator',
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    TextCustomerPostDescription(
                                                      titre: "${(20/505*100).toStringAsFixed(2)}%",
                                                      fontSize: SizeText.homeProfileDateTextSize,
                                                      couleur: ConstColors.textColors,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),

                                            GestureDetector(
                                              onTap: () {


                                              },
                                              child: Container(
                                                width: 110,
                                                height: 30,
                                                child: Row(

                                                  crossAxisAlignment: CrossAxisAlignment.center,
                                                  // mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Icon(
                                                          Icons.thumb_up,
                                                          size: 20,
                                                          // color: ConstColors.likeColors,
                                                        ),
                                                        Padding(
                                                          padding: const EdgeInsets.only(left: 1.0,right: 1),
                                                          child: TextCustomerPostDescription(
                                                            titre: "20",
                                                            fontSize: SizeText.homeProfileDateTextSize,
                                                            couleur: ConstColors.textColors,
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    Expanded(
                                                      child: Padding(
                                                        padding: const EdgeInsets.only(left: 1.0,right: 1),
                                                        child: SizedBox(
                                                          height: 2,
                                                          // width: width*0.75,
                                                          child: LinearProgressIndicator(
                                                            color: Colors.blue,
                                                            value: 10/505,
                                                            semanticsLabel: 'Linear progress indicator',
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    TextCustomerPostDescription(
                                                      titre: "${(10/505*100).toStringAsFixed(2)}%",
                                                      fontSize: SizeText.homeProfileDateTextSize,
                                                      couleur: ConstColors.textColors,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),

                                            GestureDetector(
                                              onTap: () {


                                              },
                                              child: Container(
                                                width: 110,
                                                height: 30,
                                                child: Row(

                                                  crossAxisAlignment: CrossAxisAlignment.center,
                                                  // mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Icon(
                                                          Icons.comment,
                                                          size: 20,
                                                          // color: ConstColors.likeColors,
                                                        ),
                                                        Padding(
                                                          padding: const EdgeInsets.only(left: 1.0,right: 1),
                                                          child: TextCustomerPostDescription(
                                                            titre: "20",
                                                            fontSize: SizeText.homeProfileDateTextSize,
                                                            couleur: ConstColors.textColors,
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    Expanded(
                                                      child: Padding(
                                                        padding: const EdgeInsets.only(left: 1.0,right: 1),
                                                        child: SizedBox(
                                                          height: 2,
                                                          //width: width*0.75,
                                                          child: LinearProgressIndicator(
                                                            color: Colors.blueGrey,
                                                            value: 20/505,
                                                            semanticsLabel: 'Linear progress indicator',
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    TextCustomerPostDescription(
                                                      titre: "${(20/505*100).toStringAsFixed(2)}%",
                                                      fontSize: SizeText.homeProfileDateTextSize,
                                                      couleur: ConstColors.textColors,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),



                                          ],
                                        ),
                                      ),


                                      SizedBox(
                                        height: 2,
                                      ),

                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  );
              } else {

                return  Column(

                  mainAxisSize: MainAxisSize.max,
                  children: [
                    for(Post p in snapshot.data!)
                      Padding(
                        padding: const EdgeInsets.only(top: 5.0,bottom: 5),
                        child: homePostUsers(p,height, width),
                      )
                  ],
                );
              }
            },
          ),
        ),
      ),
    );
  }
}