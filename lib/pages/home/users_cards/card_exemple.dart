import 'package:afrotok/models/model_data.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:like_button/like_button.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:provider/provider.dart';
import 'package:rate_in_stars/rate_in_stars.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../constant/sizeText.dart';
import '../../../constant/textCustom.dart';
import '../../../providers/authProvider.dart';
import '../../../providers/postProvider.dart';
import '../../../providers/userProvider.dart';
import 'cardModel.dart';

class ExampleCard extends StatefulWidget {
  final UserData candidate;

  const ExampleCard(
      this.candidate, {
        super.key,
      });

  @override
  State<ExampleCard> createState() => _ExampleCardState();
}

class _ExampleCardState extends State<ExampleCard> {
  bool isUserAbonne(List<UserAbonnes> userAbonnesList, String userIdToCheck) {
    return userAbonnesList.any((userAbonne) => userAbonne.abonneUserId == userIdToCheck);
  }
  bool abonneTap =false;
  bool inviteTap =false;
  bool dejaInviter =false;

  late UserAuthProvider authProvider =
  Provider.of<UserAuthProvider>(context, listen: false);
  late UserProvider userProvider =
  Provider.of<UserProvider>(context, listen: false);
  final List<String> noms = ['Alice', 'Bob', 'Charlie'];
  late PostProvider postProvider =
  Provider.of<PostProvider>(context, listen: false);
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
  bool isIn(List<String> users_id, String userIdToCheck) {
    return users_id.any((item) => item == userIdToCheck);
  }
  bool isMyFriend(List<Friends> userfriendList, String userIdToCheck) {
    return userfriendList.any((userAbonne) => userAbonne.friendId == userIdToCheck);
  }
  bool isInvite(List<Invitation> invitationList, String userIdToCheck) {
    return invitationList.any((inv) => inv.receiverId == userIdToCheck);
  }
  @override
  Widget build(BuildContext context) {
    double h = MediaQuery.of(context).size.height;
    double w = MediaQuery.of(context).size.width;
    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.all(Radius.circular(10)),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 3,
            blurRadius: 7,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: const [Color(0xFF0BA4E0), Color(0xFFA9E4BD)],
                ),
              ),
              child: Container(
                width: w*0.9,
                height: h*0.7,
                child: CachedNetworkImage(
                  fit: BoxFit.cover,

                  imageUrl: '${widget.candidate.imageUrl!}',
                  progressIndicatorBuilder: (context, url, downloadProgress) =>
                  //  LinearProgressIndicator(),

                  Skeletonizer(
                      child: SizedBox(width: 120,height: 100, child:  ClipRRect(
                          borderRadius: BorderRadius.all(Radius.circular(10)),child: Image.asset('assets/images/404.png')))),
                  errorWidget: (context, url, error) =>  Container(width: 120,height: 100,child: Image.asset("assets/icon/user-removebg-preview.png",fit: BoxFit.cover,)),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "@${widget.candidate.pseudo}",                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  "${widget.candidate.abonnes} abonné(s)",
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Column(
                      children: [
                        StatefulBuilder(

                            builder: (BuildContext context, void Function(void Function()) setState) {

                              return Container(
                                width: w*0.45,
                                height: 50,
                                child:  isMyFriend(authProvider.loginUserData.friends!, widget.candidate.id!)?
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0,bottom:8 ),
                                  child: ElevatedButton(

                                      onPressed: (){}, child:  Container(child: TextCustomerUserTitle(
                                    titre: "envoyer un message",
                                    fontSize: SizeText.homeProfileTextSize,
                                    couleur: Colors.blue,
                                    fontWeight: FontWeight.w600,
                                  ),)),
                                )
                                    :!isInvite(authProvider.loginUserData.mesInvitationsEnvoyer!, widget.candidate.id!)?
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0,bottom:8 ),
                                  child: Container(
                                    //width: 120,
                                    //height: 30,
                                    child: ElevatedButton(
                                      onPressed:inviteTap?
                                          ()  { }:
                                          ()async{
                                        if (!isInvite(authProvider.loginUserData.mesInvitationsEnvoyer!, widget.candidate.id!)) {
                                          setState(() {
                                            inviteTap=true;
                                          });
                                          Invitation invitation = Invitation();
                                          invitation.senderId=authProvider.loginUserData.id;
                                          invitation.receiverId=widget.candidate.id;
                                          invitation.status=InvitationStatus.ENCOURS.name;
                                          invitation.createdAt  = DateTime.now().millisecondsSinceEpoch;
                                          invitation.updatedAt  = DateTime.now().millisecondsSinceEpoch;

                                          // invitation.inviteUser=authProvider.loginUserData!;
                                          await  userProvider.sendInvitation(invitation,context).then((value) async {
                                            if (value) {

                                              // await userProvider.getUsers(authProvider.loginUserData!.id!);
                                              authProvider.loginUserData.mesInvitationsEnvoyer!.add(invitation);
                                              await authProvider.getCurrentUser(authProvider.loginUserData!.id!);
                                              SnackBar snackBar = SnackBar(
                                                content: Text('invitation envoyée',textAlign: TextAlign.center,style: TextStyle(color: Colors.green),),
                                              );
                                              ScaffoldMessenger.of(context).showSnackBar(snackBar);

                                            }  else{
                                              SnackBar snackBar = SnackBar(
                                                content: Text('une erreur',textAlign: TextAlign.center,style: TextStyle(color: Colors.red),),
                                              );
                                              ScaffoldMessenger.of(context).showSnackBar(snackBar);

                                            }
                                          },);


                                          setState(() {
                                            inviteTap=false;
                                          });
                                        }
                                      },
                                      child:inviteTap? Center(
                                        child: LoadingAnimationWidget.flickr(
                                          size: 20,
                                          leftDotColor: Colors.green,
                                          rightDotColor: Colors.black,
                                        ),
                                      ): TextCustomerUserTitle(
                                        titre: "envoyer une invitation",
                                        fontSize: SizeText.homeProfileTextSize,
                                        couleur: Colors.blue,
                                        fontWeight: FontWeight.w600,
                                      ),),
                                  ),
                                ):Padding(
                                  padding: const EdgeInsets.only(top: 8.0,bottom:8 ),
                                  child: Container(
                                    //width: 120,
                                    // height: 30,
                                    child: ElevatedButton(
                                      onPressed:
                                          ()  { },
                                      child:TextCustomerUserTitle(
                                        titre: "invitation déjà envoyée",
                                        fontSize: SizeText.homeProfileTextSize,
                                        couleur: Colors.black38,
                                        fontWeight: FontWeight.w600,
                                      ),),
                                  ),
                                ),
                              );
                            }
                        ),
                        StatefulBuilder(

                            builder: (BuildContext context, void Function(void Function()) setState) {
                              return Container(
                                child:    isUserAbonne(authProvider.loginUserData.userAbonnes!, widget.candidate.id!)?
                                Container(
                                  width: w*0.45,
                                  height: 35,
                                  child: ElevatedButton(
                                    onPressed:
                                        ()  { },
                                    child: TextCustomerUserTitle(
                                      titre: "vous êtes déjà abonné",
                                      fontSize: SizeText.homeProfileTextSize,
                                      couleur: Colors.green,
                                      fontWeight: FontWeight.w600,
                                    ),),
                                ):Container(
                                  width: w*0.45,
                                  height: 35,

                                  child: ElevatedButton(
                                    onPressed:abonneTap?
                                        ()  { }:
                                        ()async{
                                      if (!isUserAbonne(authProvider.loginUserData.userAbonnes!, widget.candidate!.id!)) {
                                        setState(() {
                                          abonneTap=true;
                                        });
                                        UserAbonnes userAbonne = UserAbonnes();
                                        userAbonne.compteUserId=authProvider.loginUserData.id;
                                        userAbonne.abonneUserId=widget.candidate!.id;

                                        userAbonne.createdAt  = DateTime.now().millisecondsSinceEpoch;
                                        userAbonne.updatedAt  = DateTime.now().millisecondsSinceEpoch;
                                        await  userProvider.sendAbonnementRequest(userAbonne,widget.candidate,context).then((value) async {
                                          if (value) {

                                            // await userProvider.getUsers(authProvider.loginUserData!.id!);
                                            authProvider.loginUserData.userAbonnes!.add(userAbonne);
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
                                    ): TextCustomerUserTitle(
                                      titre: "abonnez vous",
                                      fontSize: SizeText.homeProfileTextSize,
                                      couleur: Colors.red,
                                      fontWeight: FontWeight.w600,
                                    ),),
                                ),
                              );
                            }
                        )

                      ],
                    ),

                    Padding(
                      padding: const EdgeInsets.only(left: 4.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [

                          RatingStars(
                            rating: 5*widget.candidate.popularite!,
                            editable: true,
                            iconSize: 25,
                            color: Colors.green,
                          ),
                          LikeButton(

                            isLiked: false,
                            size: 35,
                            circleColor:
                            CircleColor(start: Color(0xff00ddff), end: Color(0xff0099cc)),
                            bubblesColor: BubblesColor(
                              dotPrimaryColor: Color(0xff3b9ade),
                              dotSecondaryColor: Color(0xff027f19),
                            ),
                            countPostion: CountPostion.bottom,
                            likeBuilder: (bool isLiked) {
                              return Icon(
                                !isLiked ?AntDesign.like1:AntDesign.like1,
                                color: !isLiked ? Colors.black38 : Colors.blue,
                                size: 35,
                              );
                            },
                            // likeCount: 30,
                            countBuilder: (int? count, bool isLiked, String text) {
                              var color = isLiked ? Colors.black : Colors.black;
                              Widget result;
                              if (count == 0) {
                                result = Text(
                                  "0",textAlign: TextAlign.center,
                                  style: TextStyle(color: color),
                                );
                              } else
                                result = Text(
                                  text,
                                  style: TextStyle(color: color),
                                );
                              return result;
                            },

                          ),



                        ],
                      ),
                    )
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}