import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'dart:math';

import 'package:anim_search_bar/anim_search_bar.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:contained_tab_bar_view_with_custom_page_navigator/contained_tab_bar_view_with_custom_page_navigator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:intl/intl.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:popup_menu/popup_menu.dart';
import 'package:provider/provider.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../../../constant/constColors.dart';
import '../../../../../constant/listItemsCarousel.dart';
import '../../../../../constant/sizeText.dart';
import '../../../../../constant/textCustom.dart';
import '../../../../../models/model_data.dart';
import '../../../../../providers/authProvider.dart';
import '../../../../../providers/postProvider.dart';
import '../../../../../providers/userProvider.dart';
import '../../../../postComments.dart';


class ProfileUserEntrepriseImageTab extends StatefulWidget {
  const ProfileUserEntrepriseImageTab({super.key});

  @override
  State<ProfileUserEntrepriseImageTab> createState() => _ProfileUserEntrepriseImageTabState();
}

class _ProfileUserEntrepriseImageTabState extends State<ProfileUserEntrepriseImageTab> {
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
    int vue=post!.vues!;
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
                          Row(
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: CircleAvatar(
                                  backgroundImage: NetworkImage(
                                      '${post.entrepriseData!.urlImage!}'),
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
                                          titre: "${post.entrepriseData!.titre!}",
                                          fontSize: SizeText.homeProfileTextSize,
                                          couleur: ConstColors.textColors,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      TextCustomerUserTitle(
                                        titre: "${post.entrepriseData!.suivi!} suivi(s)",
                                        fontSize: 10,
                                        couleur: ConstColors.textColors,
                                        fontWeight: FontWeight.w400,
                                      ),

                                    ],
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
                          SizedBox(width: 20,),
                          Icon(Entypo.arrow_long_right,color: Colors.green,),
                          SizedBox(width: 20,),
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
                                    mainAxisAlignment: MainAxisAlignment.start,
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
                                        titre: "${post.user!.abonnes!} abonné(s)",
                                        fontSize: 10,
                                        couleur: ConstColors.textColors,
                                        fontWeight: FontWeight.w400,
                                      ),

                                    ],
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
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        Icon(Entypo.network,size: 15,),
                        SizedBox(width: 10,),
                        TextCustomerUserTitle(
                          titre: "publicité",
                          fontSize: SizeText.homeProfileTextSize,
                          couleur: Colors.green,
                          fontWeight: FontWeight.w400,
                        ),
                      ],
                    ),
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
                  post!.images==null? Container():  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [

                        for(int i=0;i<post!.images!.length;i++)
                          TextButton(onPressed: ()
                          {
                            setStateImages(() {
                              imageIndex=i;
                            });

                          }, child:   Container(
                            width: 100,
                            height: 50,

                            child: ClipRRect(
                              borderRadius: BorderRadius.all(Radius.circular(10)),
                              child: Container(

                                child: CachedNetworkImage(

                                  fit: BoxFit.cover,
                                  imageUrl: '${post!.images![i]}',
                                  progressIndicatorBuilder: (context, url, downloadProgress) =>
                                  //  LinearProgressIndicator(),

                                  Skeletonizer(
                                      child: SizedBox(width: 400,height: 450, child:  ClipRRect(
                                          borderRadius: BorderRadius.all(Radius.circular(10)),child: Image.asset('assets/images/404.png')))),
                                  errorWidget: (context, url, error) =>  Skeletonizer(child: Container(width: 400,height: 450,child: Image.asset("assets/images/404.png",fit: BoxFit.cover,))),
                                ),
                              ),
                            ),
                          ),)
                      ],
                    ),
                  ),
                  Container(
                    width: w,
                    height: h*0.3,

                    child: ClipRRect(
                      borderRadius: BorderRadius.all(Radius.circular(5)),
                      child: Container(

                        child: CachedNetworkImage(
                          fit: BoxFit.cover,
                          imageUrl: '${post!.images==null?'':post!.images![imageIndex]}',
                          progressIndicatorBuilder: (context, url, downloadProgress) =>
                          //  LinearProgressIndicator(),

                          Skeletonizer(
                              child: SizedBox(width: 400,height: 450, child:  ClipRRect(
                                  borderRadius: BorderRadius.all(Radius.circular(10)),child: Image.asset('assets/images/404.png')))),
                          errorWidget: (context, url, error) =>  Skeletonizer(child: Container(width: 400,height: 450,child: Image.asset("assets/images/404.png",fit: BoxFit.cover,))),
                        ),
                      ),
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




                                },
                                child: Container(
                                  //height: 20,
                                  width: 70,
                                  height: 30,
                                  child: Row(
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
                                ),
                              );
                            }
                        ),

                        StatefulBuilder(
                            builder: (BuildContext context, StateSetter setState) {
                              return GestureDetector(
                                onTap: () async {


                                },
                                child: Container(
                                  width: 70,
                                  height: 30,
                                  child: Row(
                                    children: [
                                      Icon(
                                        tapLike?MaterialCommunityIcons.thumb_up:MaterialCommunityIcons.thumb_up_outline,
                                        size: 20,
                                        color: tapLike?Colors.blue:Colors.black,
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.only(left: 1.0,right: 1),
                                        child: TextCustomerPostDescription(
                                          titre: "${like}",
                                          fontSize: SizeText.homeProfileDateTextSize,
                                          couleur: ConstColors.textColors,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }
                        ),

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
                                ),
                              );
                            }
                        ),
                        StatefulBuilder(
                            builder: (BuildContext context, StateSetter setState) {
                              return GestureDetector(
                                onTap: () {


                                },
                                child: Container(
                                  width: 70,
                                  height: 30,
                                  child: Row(
                                    children: [
                                      Icon(
                                        FontAwesome.eye,
                                        size: 20,
                                        color: Colors.black,
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.only(left: 1.0,right: 1),
                                        child: TextCustomerPostDescription(
                                          titre: "${vue}",
                                          fontSize: SizeText.homeProfileDateTextSize,
                                          couleur: ConstColors.textColors,
                                          fontWeight: FontWeight.bold,
                                        ),
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
                  ElevatedButton(onPressed: () {

                  },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(AntDesign.message1,color: Colors.black,),
                          SizedBox(width: 5,),
                          Text("Contacter",style: TextStyle(color: Colors.green),),
                        ],
                      )),


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
            stream: postProvider.getEntreprisePostsImagesByUser(authProvider.loginUserData.id!),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                print("attente");
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
                            child: Padding(
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
                                              backgroundImage: AssetImage('assets/images/9230137.jpg'),
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
                                                    child: Text(
                                                      "Company X",
                                                      style: TextStyle(
                                                        fontSize: SizeText.homeProfileTextSize,
                                                        color: ConstColors.textColors,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                  Text(
                                                    "xxx followers", // Replace with appropriate static value
                                                  ),
                                                ],
                                              ),
                                              // Remove IconButton and related code
                                            ],
                                          ),
                                        ],
                                      ),
                                      // Remove remaining dynamic company data elements
                                    ],
                                  ),
                                  // ... other static content and layout modifications
                                ],
                              ),
                            ),
                          ),
                        )
                    ],
                  ),
                );
              } else if (snapshot.hasError) {
                print("erreur ${snapshot.error}");
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
                                            backgroundImage: AssetImage('assets/images/9230137.jpg'),
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
                                                  child: Text(
                                                    "Company X",
                                                    style: TextStyle(
                                                      fontSize: SizeText.homeProfileTextSize,
                                                      color: ConstColors.textColors,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                                Text(
                                                  "xxx followers", // Replace with appropriate static value
                                                ),
                                              ],
                                            ),
                                            // Remove IconButton and related code
                                          ],
                                        ),
                                      ],
                                    ),
                                    // Remove remaining dynamic company data elements
                                  ],
                                ),
                                // ... other static content and layout modifications
                              ],
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
