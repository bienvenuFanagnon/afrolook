import 'package:afrotok/pages/UserServices/detailsUserService.dart';
import 'package:afrotok/providers/authProvider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:like_button/like_button.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/model_data.dart';
import '../../providers/postProvider.dart';
import '../component/consoleWidget.dart';
import '../component/showUserDetails.dart';
import 'newUserService.dart';

class UserServiceListPage extends StatefulWidget {
  @override
  State<UserServiceListPage> createState() => _UserServiceListPageState();
}

class _UserServiceListPageState extends State<UserServiceListPage> {
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
  Future<void> launchWhatsApp(String phone,UserServiceData data,String urlService) async {
    //  var whatsappURl_android = "whatsapp://send?phone="+whatsapp+"&text=hello";
    // String url = "https://wa.me/?tel:+228$phone&&text=YourTextHere";
    String url = "whatsapp://send?phone=" + phone + "&text="
        + "Bonjour *${data.user!.nom!}*,\n\n"
        + "Je m'appelle *@${authProvider.loginUserData!.pseudo!.toUpperCase()}* et je suis sur Afrolook.\n"
        + "Je vous contacte concernant votre service :\n\n"
        + "*Titre* : *${data.titre!.toUpperCase()}*\n"
        + "*Description* : *${data.description}*\n\n"
        + "Je suis très intéressé(e) par ce que vous proposez et j'aimerais en savoir plus.\n"
        + "Vous pouvez voir le service ici : ${urlService}\n\n"
        + "Merci et à bientôt !";
    // String url = "whatsapp://send?phone="+phone+"&text=Salut *${data.user!.nom!}*,\n*Moi c'est*: *@${authProvider.loginUserData!.pseudo!.toUpperCase()} Sur Afrolook*,\n je vous contact à propos de votre service:\n\n*Titre*:  *${data.titre!.toUpperCase()}*\n *Description*: *${data.description}* \n *Voir le service* ${urlService}";
    if (!await launchUrl(Uri.parse(url))) {
      final snackBar = SnackBar(duration: Duration(seconds: 2),content: Text("Impossible d\'ouvrir WhatsApp",textAlign: TextAlign.center, style: TextStyle(color: Colors.red),));

      // Afficher le SnackBar en bas de la page
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
      throw Exception('Impossible d\'ouvrir WhatsApp');
    }else{
      await    postProvider.getUserServiceById(data.id!).then((value) async {
        if (value.isNotEmpty) {
          data=value.first;
          if(data.contactWhatsapp==null){
            data.contactWhatsapp=1;
          }else{
            if(value.first.contactWhatsapp==null){
              data.contactWhatsapp=1;
            }else{
              data.contactWhatsapp=value.first.contactWhatsapp!+1;

            }

          }
          if(!isIn(data.usersContactId!, authProvider.loginUserData!.id!)){
            data.usersContactId!.add(authProvider.loginUserData!.id!) ;

          }
          postProvider.updateUserService(data,context).then((value) {
            if (value) {

setState(() {

});
            }
          },);
        }
      },);

    }
  }

  // Future<void> launchWhatsApp(String phone,ArticleData articleData,String urlArticle) async {
  //   //  var whatsappURl_android = "whatsapp://send?phone="+whatsapp+"&text=hello";
  //   // String url = "https://wa.me/?tel:+228$phone&&text=YourTextHere";
  //   String url = "whatsapp://send?phone="+phone+"&text=Salut *${articleData.user!.nom!}*,\n*Moi c'est*: *@${authProvider.loginUserData!.pseudo!.toUpperCase()} Sur Afrolook*,\n j'ai vu votre service sur *${"Afroshop".toUpperCase()}*\n à propos de l'article:\n\n*Titre*:  *${articleData.titre!.toUpperCase()}*\n *Prix*: *${articleData.prix}* fcfa\n *Voir l'article* ${urlArticle}";
  //   if (!await launchUrl(Uri.parse(url))) {
  //     final snackBar = SnackBar(duration: Duration(seconds: 2),content: Text("Impossible d\'ouvrir WhatsApp",textAlign: TextAlign.center, style: TextStyle(color: Colors.red),));
  //
  //     // Afficher le SnackBar en bas de la page
  //     ScaffoldMessenger.of(context).showSnackBar(snackBar);
  //     throw Exception('Impossible d\'ouvrir WhatsApp');
  //   }
  // }


  @override
  Widget build(BuildContext context) {

    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Text('Trouver des services 🛠️ ou jobs 💼',style: TextStyle(color: Colors.white,fontSize: 18),),
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
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              icon: Icon(Icons.add_box,size: 30,),
              color: Colors.white,
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => UserServiceForm(),));

                // Action lors du clic sur le bouton
              },
            ),
          ),
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
                    hintText: 'Rechercher un service 🛠️ ou un job 💼',
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
              ),              FutureBuilder<List<UserServiceData>>(
                future:postProvider.getAllUserService(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Center(child: Text('Erreur : ${snapshot.error}'));
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(child: Text('Aucun service trouvé'));
                  } else {
                    final filteredData = snapshot.data!.where((data) {
                      final titleLower = data.titre?.toLowerCase() ?? '';
                      final descriptionLower = data.description?.toLowerCase() ?? '';
                      final searchLower = searchQuery.toLowerCase();
                      return titleLower.contains(searchLower) || descriptionLower.contains(searchLower);
                    }).toList();
                    return SizedBox(
                      height: height*0.8,
                      width: width,
                      child: ListView.builder(
                        itemCount: filteredData!.length,
                        itemBuilder: (context, index) {
                          var data = filteredData![index];
                          return Card(
                            child: ListTile(
                              subtitle: Column(
                                spacing: 5,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  GestureDetector(

                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,

                                      children: [
                                        CircleAvatar(
                                          backgroundImage: NetworkImage(data.user?.imageUrl ?? ''),
                                          radius: 20,
                                        ),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,

                                          children: [
                                            Text('@${data.user?.pseudo ?? 'Pseudo'}',style: TextStyle(fontWeight: FontWeight.w900),),
                                            Text('${data.user?.abonnes ?? '0'} abonné(s)',style: TextStyle(fontSize: 11,color: Colors.green),),
                                          ],
                                        )
                                      ],
                                    ),
                                    onTap: () async {
                                      await  authProvider.getUserById(data.userId!).then((users) async {
                                        if(users.isNotEmpty){
                                          showUserDetailsModalDialog(users.first, width, height,context);

                                        }
                                      },);

                                    },
                                  ),
                                  GestureDetector(
                                    onTap: () async {
                                      await    postProvider.getUserServiceById(data.id!).then((value) async {
                                        if (value.isNotEmpty) {
                                          data=value.first;
                                          data.vues=value.first.vues!+1;
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
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        SizedBox(

                                            child: Image.network(data.imageCourverture ?? '',fit: BoxFit.cover,),
                                          height: height*0.3,
                                          width: width,
                                        ),
                                        Text(data.titre ?? 'Titre',style: TextStyle(fontSize: 18,fontWeight: FontWeight.w900),),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            IconText(icon: Icons.contact_phone, text: data.contact ?? 'Contact'),
                                            Container(

                                              child: TextButton(
                                                onPressed: () async {

                                                  await authProvider.createServiceLink(true,data).then((url) async {

// printVm("data : ${data.toJson()}");

                                                    setState(() {
                                                      launchWhatsApp(data .contact!, data!,url);

                                             

                                                      // post.users_love_id!
                                                      //     .add(authProvider!.loginUserData.id!);
                                                      // love = post.loves!;
                                                      // //loves.add(idUser);
                                                    });
                                                    CollectionReference userCollect =
                                                    FirebaseFirestore.instance
                                                        .collection('Users');
                                                    // Get docs from collection reference
                                                    QuerySnapshot querySnapshotUser =
                                                    await userCollect
                                                        .where("id",
                                                        isEqualTo: data.user!.id!)
                                                        .get();
                                                    // Afficher la liste
                                                    List<UserData> listUsers = querySnapshotUser
                                                        .docs
                                                        .map((doc) => UserData.fromJson(
                                                        doc.data() as Map<String, dynamic>))
                                                        .toList();
                                                    if (listUsers.isNotEmpty) {
                                                      // listUsers.first!.partage =
                                                      //     listUsers.first!.partage! + 1;
                                                      printVm("user trouver");
                                                      if (data.user!.oneIgnalUserid != null &&
                                                          data.user!.oneIgnalUserid!.length > 5) {


                                                        NotificationData notif =
                                                        NotificationData();
                                                        notif.id = firestore
                                                            .collection('Notifications')
                                                            .doc()
                                                            .id;
                                                        notif.titre = " 🛠️Services && Jobs 💼";
                                                        notif.media_url =
                                                            authProvider.loginUserData.imageUrl;
                                                        notif.type = NotificationType.SERVICE.name;
                                                        notif.description =
                                                        "@${authProvider.loginUserData.pseudo!} veut votre service ou jobs 💼";
                                                        notif.users_id_view = [];
                                                        notif.user_id =
                                                            authProvider.loginUserData.id;
                                                        notif.receiver_id = data.user!.id!;
                                                        notif.post_id = data.id!;
                                                        notif.post_data_type =
                                                        PostDataType.IMAGE.name!;

                                                        notif.updatedAt =
                                                            DateTime.now().microsecondsSinceEpoch;
                                                        notif.createdAt =
                                                            DateTime.now().microsecondsSinceEpoch;
                                                        notif.status = PostStatus.VALIDE.name;

                                                        // users.add(pseudo.toJson());

                                                        await firestore
                                                            .collection('Notifications')
                                                            .doc(notif.id)
                                                            .set(notif.toJson());

                                                        await authProvider.sendNotification(
                                                            userIds: [data.user!.oneIgnalUserid!],
                                                            smallImage:
                                                            "${authProvider.loginUserData.imageUrl!}",
                                                            send_user_id:
                                                            "${authProvider.loginUserData.id!}",
                                                            recever_user_id: "${data.user!.id!}",
                                                            message:
                                                            "📢 💼 @${authProvider.loginUserData.pseudo!} est intéressé(e) par votre service 💼",
                                                            type_notif:
                                                            NotificationType.SERVICE.name,
                                                            post_id: "${data!.id!}",
                                                            post_type: PostDataType.IMAGE.name,
                                                            chat_id: '');
                                                      }


                                                    }

                                                  },);





                                                },
                                                child: Center(
                                                      child: Container(
                                                      alignment: Alignment.center,
                                                      decoration: BoxDecoration(
                                                          color: Colors.brown,
                                                          borderRadius: BorderRadius.all(Radius.circular(5))
                                                      ),
                                                      child: Padding(
                                                        padding: const EdgeInsets.only(left: 8.0,right: 8),
                                                        child: Row(
                                                          children: [
                                                            Text('Contacter',style: TextStyle(color: Colors.white),),
                                                            IconButton(
                                                              icon: Icon(FontAwesome.whatsapp,color: Colors.green,size: 30,),
                                                              onPressed: () async {

                                                                // Fonction pour ouvrir WhatsApp
                                                              },
                                                            ),
                                                          ],
                                                        ),
                                                      )),
                                                    ),
                                              ),
                                            ),
                                          ],
                                        ),

                                        Text(
                                          data.description ?? 'Description',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.only(left: 8.0,right: 8,top: 8),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            crossAxisAlignment: CrossAxisAlignment.center,

                                            children: [
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
                                                    FontAwesome.whatsapp,
                                                    color: isLiked ? Colors.green : Colors.green,
                                                    size: 15,
                                                  );
                                                },
                                                likeCount:   data.contactWhatsapp,
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
                                              LikeButton(
                                                onTap: (isLiked) async {
                                                  await    postProvider.getUserServiceById(data.id!).then((value) async {
                                                    if (value.isNotEmpty) {
                                                      data=value.first;
                                                      data.like=value.first.like!+1;

                                                      if(!isIn(data.usersLikeId!, authProvider.loginUserData!.id!)){
                                                        data.usersLikeId!.add(authProvider.loginUserData!.id!) ;

                                                      }
                                                      postProvider.updateUserService(data,context).then((value) {
                                                        if (value) {
setState(() {

});

                                                        }
                                                      },);
                                                    }
                                                  },);

                                                  return Future.value(true);

                                                },
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
                                                    FontAwesome.heart,
                                                    color: isLiked ? Colors.red : Colors.redAccent,
                                                    size: 15,
                                                  );
                                                },
                                                likeCount:   data.like,
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
                                              LikeButton(
                                                onTap: (isLiked) async {



                                                  return Future.value(true);

                                                },
                                                isLiked: false,
                                                size: 15,
                                                circleColor:
                                                CircleColor(start: Color(0xffffc400), end: Color(
                                                    0xffcc7a00)),
                                                bubblesColor: BubblesColor(
                                                  dotPrimaryColor: Color(0xffffc400),
                                                  dotSecondaryColor: Color(0xff07f629),
                                                ),
                                                countPostion: CountPostion.bottom,
                                                likeBuilder: (bool isLiked) {
                                                  return Icon(
                                                    Entypo.share,
                                                    color: isLiked ? Colors.blue : Colors.blueAccent,
                                                    size: 15,
                                                  );
                                                },
                                                likeCount:   data.usersPartageId!.length,
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

                                ],
                              ),
                              onTap: () {
                                // Action lors du clic sur un élément de la liste
                              },
                            ),
                          );
                        },
                      ),
                    );
                  }
                },
              ),
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