

import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/providers/postProvider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:provider/provider.dart';

import '../../../constant/buttons.dart';
import '../../../constant/constColors.dart';
import '../../../constant/sizeText.dart';
import '../../../constant/textCustom.dart';
import '../../../providers/authProvider.dart';

Widget entrepriseHeader(EntrepriseData entreprise){
  return Padding(
    padding: const EdgeInsets.only(bottom: 8.0),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 15.0),
              child: CircleAvatar(
                radius: 30,
                backgroundImage: NetworkImage(
                    '${entreprise.urlImage}'),
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
                        titre: "#${entreprise.titre}",
                        fontSize: SizeText.homeProfileTextSize,
                        couleur: ConstColors.textColors,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextCustomerUserTitle(
                      titre: "${entreprise.suivi} suivi(e)s",
                      fontSize: SizeText.homeProfileTextSize,
                      couleur: ConstColors.textColors,
                      fontWeight: FontWeight.w400,
                    ),
                  ],
                ),

              ],
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(right: 12.0),
          child: Column(
            children: [
              SizedBox(
                //width: 100,
                child: TextCustomerUserTitle(
                  titre: "PubliCash",
                  fontSize: SizeText.homeProfileTextSize,
                  couleur: ConstColors.textColors,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextCustomerUserTitle(
                titre: "${entreprise.publicash!.toStringAsFixed(2)}",
                fontSize: SizeText.homeProfileTextSize,
                couleur: ConstColors.textColors,
                fontWeight: FontWeight.w400,
              ),
              SizedBox(height: 5,),
              GestureDetector(
                  onTap: () {
                    // Navigator.push(context, MaterialPageRoute(builder: (context) => DepotPage(),));
                  },
                  child: AchatPubliCachButton()),

            ],
          ),
        ),
      ],
    ),
  );

}

Widget entrepriseSimpleHeader(EntrepriseData entreprise,BuildContext context){
  bool isUserAbonne(List<String> userAbonnesList, String userIdToCheck) {
    return userAbonnesList.any((userAbonneId) => userAbonneId == userIdToCheck);
  }
  late UserAuthProvider authProvider =
  Provider.of<UserAuthProvider>(context, listen: false);
  late PostProvider postProvider =
  Provider.of<PostProvider>(context, listen: false);
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  bool abonneTap = false;
  return Padding(
    padding: const EdgeInsets.only(bottom: 8.0),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 15.0),
              child: CircleAvatar(
                radius: 30,
                backgroundImage: NetworkImage(
                    '${entreprise.urlImage}'),
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
                        titre: "#${entreprise.titre}",
                        fontSize: SizeText.homeProfileTextSize,
                        couleur: ConstColors.textColors,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextCustomerUserTitle(
                      titre: "${entreprise.suivi} suivi(e)s",
                      fontSize: SizeText.homeProfileTextSize,
                      couleur: ConstColors.textColors,
                      fontWeight: FontWeight.w400,
                    ),
                  ],
                ),

              ],
            ),
          ],
        ),


        StatefulBuilder(builder: (BuildContext context,
              void Function(void Function()) setState) {
            return Visibility(
            visible:!isUserAbonne(
            entreprise.usersSuiviId!,
            authProvider.loginUserData.id!),

              child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green, // Couleur de fond du bouton
                  ),
                  onPressed: abonneTap
                      ? () {}
                      : () async {
                    if (!isUserAbonne(
                        entreprise.usersSuiviId!,
                        authProvider
                            .loginUserData
                            .id!))
                    {
                      setState(() {
                        abonneTap = true;
                      });
                      await    postProvider.getEntreprise(entreprise.userId!).then((entreprises) {
                        if(entreprises.isNotEmpty){
                          entreprises.first.usersSuiviId!.add(authProvider.loginUserData!.id!);
                          entreprises.first.suivi=entreprises.first.usersSuiviId!.length;
                          entreprise.usersSuiviId!.add(authProvider.loginUserData!.id!);
                          setState(() {
                            // abonneTap = true;
                          });
                          // entreprise=entreprises.first;
                          authProvider.updateEntreprise(entreprises.first);
                        }
                      },);



                      if (entreprise .user!
                          .oneIgnalUserid !=
                          null &&
                          entreprise
                              .user!
                              .oneIgnalUserid!
                              .length >
                              5) {
                        await authProvider.sendNotification(
                            userIds: [
                              entreprise.user!
                                  .oneIgnalUserid!
                            ],
                            smallImage:
                            "${authProvider.loginUserData.imageUrl!}",
                            send_user_id:
                            "${authProvider.loginUserData.id!}",
                            recever_user_id:
                            "${entreprise.user!.id!}",
                            message:
                            "🔔👀 @${authProvider.loginUserData.pseudo!} suit 👀 votre entreprise 🏢",
                            type_notif:
                            NotificationType
                                .ABONNER
                                .name,
                            post_id:
                            "",
                            post_type:
                            PostDataType
                                .IMAGE
                                .name,
                            chat_id: '');
                        NotificationData
                        notif =
                        NotificationData();
                        notif.id = firestore
                            .collection(
                            'Notifications')
                            .doc()
                            .id;
                        notif.titre =
                        "Nouveau Abonnement ✅";
                        notif.media_url =
                            authProvider
                                .loginUserData
                                .imageUrl;
                        notif.type =
                            NotificationType
                                .ABONNER
                                .name;
                        notif.description =
                        "🔔👀 @${authProvider.loginUserData.pseudo!} suit 👀 votre entreprise 🏢";
                        notif.users_id_view =
                        [];
                        notif.user_id =
                            authProvider
                                .loginUserData
                                .id;
                        notif.receiver_id =
                        entreprise.user!
                            .id!;
                        notif.post_id =
                        entreprise.id!;
                        notif.post_data_type =
                        PostDataType
                            .IMAGE
                            .name!;
                        notif.updatedAt =
                            DateTime.now()
                                .microsecondsSinceEpoch;
                        notif.createdAt =
                            DateTime.now()
                                .microsecondsSinceEpoch;
                        notif.status =
                            PostStatus
                                .VALIDE
                                .name;

                        // users.add(pseudo.toJson());

                        await firestore
                            .collection(
                            'Notifications')
                            .doc(notif.id)
                            .set(notif
                            .toJson());
                      }
                      SnackBar snackBar =
                      SnackBar(
                        content: Text(
                          'suivi, Bravo ! Vous avez gagné 2 points.',
                          textAlign:
                          TextAlign
                              .center,
                          style: TextStyle(
                              color: Colors
                                  .green),
                        ),
                      );
                      ScaffoldMessenger
                          .of(context)
                          .showSnackBar(
                          snackBar);
                      setState(() {
                        abonneTap = false;
                      });
                    } else {
                      SnackBar snackBar =
                      SnackBar(
                        content: Text(
                          'une erreur',
                          textAlign:
                          TextAlign
                              .center,
                          style: TextStyle(
                              color: Colors
                                  .red),
                        ),
                      );
                      ScaffoldMessenger
                          .of(context)
                          .showSnackBar(
                          snackBar);
                      setState(() {
                        abonneTap = false;
                      });

                      // setState(() {
                      //   abonneTap = false;
                      // });
                    }
                  },
                  child: abonneTap
                      ? Center(
                    child:
                    LoadingAnimationWidget
                        .flickr(
                      size: 20,
                      leftDotColor:
                      Colors.green,
                      rightDotColor:
                      Colors.black,
                    ),
                  )
                      : Text(
                    "Suivre",
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                        FontWeight.w900,
                        color: Colors.white),
                  )),
            );
          }),
      ],
    ),
  );

}