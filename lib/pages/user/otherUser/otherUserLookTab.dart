import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_image_slideshow/flutter_image_slideshow.dart';

import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:hashtagable_v3/widgets/hashtag_text.dart';
import 'package:intl/intl.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:popup_menu/popup_menu.dart';
import 'package:provider/provider.dart';
import 'package:random_color/random_color.dart';
import 'package:share_plus/share_plus.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../../constant/constColors.dart';
import '../../../../constant/iconGradient.dart';
import '../../../../constant/listItemsCarousel.dart';
import '../../../../constant/sizeText.dart';
import '../../../../constant/textCustom.dart';
import '../../../../models/model_data.dart';
import '../../../../providers/authProvider.dart';
import '../../../../providers/postProvider.dart';
import '../../../../providers/userProvider.dart';
import '../../component/consoleWidget.dart';
import '../../postComments.dart';
import '../../postDetails.dart';
import '../../userPosts/postWidgets/postWidgetPage.dart';

class OtherUserLookTab extends StatefulWidget {
  final UserData otherUser;
  const OtherUserLookTab({super.key, required this.otherUser});

  @override
  State<OtherUserLookTab> createState() => _OtherUserLookTabState();
}

class _OtherUserLookTabState extends State<OtherUserLookTab> {
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

  bool isUserAbonne(List<String> userAbonnesList, String userIdToCheck) {
    return userAbonnesList.any((userAbonneId) => userAbonneId == userIdToCheck);
  }

  bool isIn(List<String> users_id, String userIdToCheck) {
    return users_id.any((item) => item == userIdToCheck);
  }

  bool isMyFriend(List<String> userfriendList, String userIdToCheck) {
    return userfriendList.any((userfriendId) => userfriendId == userIdToCheck);
  }

  bool isInvite(List<Invitation> invitationList, String userIdToCheck) {
    return invitationList.any((inv) => inv.receiverId == userIdToCheck);
  }

  void _showPostMenuModalDialog(Post post) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Menu'),
          content: SingleChildScrollView(
            child: Column(
              children: <Widget>[
                Visibility(
                  visible: post.user!.id != authProvider.loginUserData.id,
                  child: ListTile(
                    onTap: () async {
                      post.status = PostStatus.SIGNALER.name;
                      await postProvider.updateVuePost(post, context).then(
                            (value) {
                          if (value) {
                            SnackBar snackBar = SnackBar(
                              content: Text(
                                'Post signalé !',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.green),
                              ),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(snackBar);
                          } else {
                            SnackBar snackBar = SnackBar(
                              content: Text(
                                'échec !',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.red),
                              ),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(snackBar);
                          }
                          Navigator.pop(context);
                        },
                      );
                      setState(() {});
                    },
                    leading: Icon(
                      Icons.flag,
                      color: Colors.blueGrey,
                    ),
                    title: Text(
                      'Signaler',
                    ),
                  ),
                ),
                /*
                ListTile(
                  onTap: () {
                    Navigator.pop(context);
                  },
                  leading: Icon(Icons.edit,color: Colors.blue,),
                  title: Text('Modifier'),
                ),

                 */
                Visibility(
                  visible: post.user!.id == authProvider.loginUserData.id,
                  child: ListTile(
                    onTap: () async {
                      if (authProvider.loginUserData.role == UserRole.ADM.name) {
                        post.status = PostStatus.NONVALIDE.name;
                        await postProvider.updateVuePost(post, context).then(
                              (value) {
                            if (value) {
                              SnackBar snackBar = SnackBar(
                                content: Text(
                                  'Post bloqué !',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.green),
                                ),
                              );
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(snackBar);
                            } else {
                              SnackBar snackBar = SnackBar(
                                content: Text(
                                  'échec !',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.red),
                                ),
                              );
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(snackBar);
                            }
                          },
                        );
                      } else if (post.type == PostType.POST.name) {
                        if (post.user!.id == authProvider.loginUserData.id) {
                          post.status = PostStatus.SUPPRIMER.name;
                          await postProvider.updateVuePost(post, context).then(
                                (value) {
                              if (value) {
                                SnackBar snackBar = SnackBar(
                                  content: Text(
                                    'Post supprimé !',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.green),
                                  ),
                                );
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(snackBar);
                              } else {
                                SnackBar snackBar = SnackBar(
                                  content: Text(
                                    'échec !',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.red),
                                  ),
                                );
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(snackBar);
                              }
                            },
                          );
                        }
                      }

                      setState(() {
                        Navigator.pop(context);
                      });
                    },
                    leading: Icon(
                      Icons.delete,
                      color: Colors.red,
                    ),
                    title: authProvider.loginUserData.role == UserRole.ADM.name
                        ? Text('Bloquer')
                        : Text('Supprimer'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  String formatAbonnes(int nbAbonnes) {
    if (nbAbonnes >= 1000) {
      double nombre = nbAbonnes / 1000;
      return nombre.toStringAsFixed(1) + 'k';
    } else {
      return nbAbonnes.toString();
    }
  }

  RandomColor _randomColor = RandomColor();

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

  Widget homePostUsers2(Post post, double height, double width) {
    double h = MediaQuery.of(context).size.height;
    double w = MediaQuery.of(context).size.width;

    Random random = Random();
    bool abonneTap = false;
    int like = post!.likes!;
    int imageIndex = 0;
    int love = post!.loves!;
    int vue = post!.vues!;
    int comments = post!.comments!;
    bool tapLove = isIn(post.users_love_id!, authProvider.loginUserData.id!);
    bool tapLike = isIn(post.users_like_id!, authProvider.loginUserData.id!);
    List<int> likes = [];
    List<int> loves = [];
    int idUser = 7;
    Color _color = _randomColor.randomColor(
        colorHue: ColorHue.multiple(colorHues: [
          ColorHue.red,
          ColorHue.blue,
          ColorHue.green,
          ColorHue.orange,
          ColorHue.yellow,
          ColorHue.purple
        ]));

    int limitePosts = 30;



    return Container(
      child:  StatefulBuilder(
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
                            child: GestureDetector(
                              onTap: () {
                                // Navigator.push(
                                //     context,
                                //     MaterialPageRoute(
                                //       builder: (context) => OtherUserPage(otherUser: post.user!),
                                //     ));
                              },
                              child: CircleAvatar(

                                backgroundImage:
                                NetworkImage('${post.user!.imageUrl!}'),
                              ),
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
                                    titre:
                                    "${formatNumber(post.user!.abonnes!)} abonné(s)",
                                    fontSize: SizeText.homeProfileTextSize,
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
                      IconButton(
                          onPressed: () {
                            _showPostMenuModalDialog(post);
                          },
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
                  Visibility(
                    visible: post.dataType != PostDataType.TEXT.name
                        ? true
                        : false,
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: SizedBox(
                        width: width * 0.8,
                        height: 50,
                        child: Container(
                          alignment: Alignment.centerLeft,
                          child: TextCustomerPostDescription(
                            titre: "${post.description}",
                            fontSize: SizeText.homeProfileTextSize,
                            couleur: ConstColors.textColors,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 5,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: TextCustomerPostDescription(
                        titre:
                        "${formaterDateTime(DateTime.fromMicrosecondsSinceEpoch(post.createdAt!))}",
                        fontSize: SizeText.homeProfileDateTextSize,
                        couleur: ConstColors.textColors,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Visibility(
                    visible: post.dataType == PostDataType.TEXT.name
                        ? true
                        : false,
                    child: Container(
                      color: _color,
                      child: Align(
                        alignment: Alignment.center,
                        child: SizedBox(
                          width: width * 0.8,
                          height: height * 0.5,
                          child: Container(
                            // height: 200,
                            constraints: BoxConstraints(
                              // minHeight: 100.0, // Set your minimum height
                              maxHeight:
                              height * 0.6, // Set your maximum height
                            ),
                            alignment: Alignment.centerLeft,
                            child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  "${post.description}",
                                  textAlign: TextAlign
                                      .center, //overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: post.description!.length < 350
                                        ? 25
                                        : 16,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    //fontStyle: FontStyle.italic
                                  ),
                                )),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 5,
                  ),
                  /*
                Visibility(
                  visible: post.dataType!=PostDataType.TEXT.name?true:false,

                  child: Container(

                    child:    post!.images==null? Container():  Padding(
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
                  ),
                ),

                 */

                  Visibility(
                    visible: post.dataType != PostDataType.TEXT.name
                        ? true
                        : false,
                    child: GestureDetector(
                      onTap: () {
                        postProvider.updateVuePost(post, context);

                        Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DetailsPost(post: post),
                            ));
                      },
                      child: Container(
                        child: ClipRRect(
                          borderRadius: BorderRadius.all(Radius.circular(5)),
                          child: Container(
                            child: CachedNetworkImage(
                              width: w * 0.9,
                              height: h * 0.4,
                              fit: BoxFit.cover,
                              imageUrl:
                              '${post!.images == null ? '' : post!.images!.isEmpty ? '' : post!.images![imageIndex]}',
                              progressIndicatorBuilder: (context, url,
                                  downloadProgress) =>
                              //  LinearProgressIndicator(),

                              Skeletonizer(
                                  child: SizedBox(
                                      width: 400,
                                      height: 450,
                                      child: ClipRRect(
                                          borderRadius: BorderRadius.all(
                                              Radius.circular(10)),
                                          child: Image.asset(
                                              'assets/images/404.png')))),
                              errorWidget: (context, url, error) =>
                                  Skeletonizer(
                                      child: Container(
                                          width: 400,
                                          height: 450,
                                          child: Image.asset(
                                            "assets/images/404.png",
                                            fit: BoxFit.cover,
                                          ))),
                            ),
                          ),
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
                        StatefulBuilder(builder:
                            (BuildContext context, StateSetter setState) {
                          return GestureDetector(
                            onTap: () async {
                              if (!isIn(post.users_love_id!,
                                  authProvider.loginUserData.id!)) {
                                setState(() {
                                  post.loves = post.loves! + 1;

                                  post.users_love_id!
                                      .add(authProvider!.loginUserData.id!);
                                  love = post.loves!;
                                  //loves.add(idUser);
                                });
                                CollectionReference userCollect =
                                FirebaseFirestore.instance
                                    .collection('Users');
                                // Get docs from collection reference
                                QuerySnapshot querySnapshotUser =
                                await userCollect
                                    .where("id",
                                    isEqualTo: post.user!.id!)
                                    .get();
                                // Afficher la liste
                                List<UserData> listUsers = querySnapshotUser
                                    .docs
                                    .map((doc) => UserData.fromJson(
                                    doc.data() as Map<String, dynamic>))
                                    .toList();
                                if (listUsers.isNotEmpty) {
                                  listUsers.first!.jaimes =
                                      listUsers.first!.jaimes! + 1;
                                  printVm("user trouver");
                                  if (post.user!.oneIgnalUserid != null &&
                                      post.user!.oneIgnalUserid!.length > 5) {
                                    await authProvider.sendNotification(
                                        userIds: [post.user!.oneIgnalUserid!],
                                        smallImage:
                                        "${authProvider.loginUserData.imageUrl!}",
                                        send_user_id:
                                        "${authProvider.loginUserData.id!}",
                                        recever_user_id: "${post.user!.id!}",
                                        message:
                                        "📢 @${authProvider.loginUserData.pseudo!} a aimé votre look",
                                        type_notif:
                                        NotificationType.POST.name,
                                        post_id: "${post!.id!}",
                                        post_type: PostDataType.IMAGE.name,
                                        chat_id: '');

                                    NotificationData notif =
                                    NotificationData();
                                    notif.id = firestore
                                        .collection('Notifications')
                                        .doc()
                                        .id;
                                    notif.titre = "Nouveau j'aime ❤️";
                                    notif.media_url =
                                        authProvider.loginUserData.imageUrl;
                                    notif.type = NotificationType.POST.name;
                                    notif.description =
                                    "@${authProvider.loginUserData.pseudo!} a aimé votre look";
                                    notif.users_id_view = [];
                                    notif.user_id =
                                        authProvider.loginUserData.id;
                                    notif.receiver_id = post.user!.id!;
                                    notif.post_id = post.id!;
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
                                  }

                                  //userProvider.updateUser(listUsers.first);
                                  SnackBar snackBar = SnackBar(
                                    content: Text(
                                      '+2 points.  Voir le classement',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: Colors.green),
                                    ),
                                  );
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(snackBar);
                                  postProvider.updatePost(
                                      post, listUsers.first, context);
                                  await authProvider.getAppData();
                                  authProvider.appDefaultData.nbr_loves =
                                      authProvider.appDefaultData.nbr_loves! +
                                          2;
                                  authProvider.updateAppData(
                                      authProvider.appDefaultData);
                                } else {
                                  post.user!.jaimes = post.user!.jaimes! + 1;
                                  SnackBar snackBar = SnackBar(
                                    content: Text(
                                      '+2 points.  Voir le classement',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: Colors.green),
                                    ),
                                  );
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(snackBar);
                                  postProvider.updatePost(
                                      post, post.user!, context);
                                  await authProvider.getAppData();
                                  authProvider.appDefaultData.nbr_loves =
                                      authProvider.appDefaultData.nbr_loves! +
                                          2;
                                  authProvider.updateAppData(
                                      authProvider.appDefaultData);
                                }

                                tapLove = true;
                              }
                              printVm("jaime");
                              // setState(() {
                              // });
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
                                        isIn(
                                            post.users_love_id!,
                                            authProvider
                                                .loginUserData.id!)
                                            ? Ionicons.heart
                                            : Ionicons.md_heart_outline,
                                        color: Colors.red,
                                        size: 20,
                                        // color: ConstColors.likeColors,
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.only(
                                            left: 1.0, right: 1),
                                        child: TextCustomerPostDescription(
                                          titre: "${formatAbonnes(love)}",
                                          fontSize: SizeText
                                              .homeProfileDateTextSize,
                                          couleur: ConstColors.textColors,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  /*
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.only(left: 1.0,right: 1),
                                        child: SizedBox(
                                          height: 2,
                                          width: 5,
                                          child: LinearProgressIndicator(
                                            color: Colors.red,
                                            value: love/post.user!.abonnes!+1,
                                            semanticsLabel: 'Linear progress indicator',
                                          ),
                                        ),
                                      ),
                                    ),
                                    TextCustomerPostDescription(
                                      titre: "${((love/post.user!.abonnes!+1)).toStringAsFixed(2)}%",
                                      fontSize: SizeText.homeProfileDateTextSize,
                                      couleur: ConstColors.textColors,
                                      fontWeight: FontWeight.bold,
                                    ),

                                     */
                                ],
                              ),
                            ),
                          );
                        }),
                        StatefulBuilder(builder:
                            (BuildContext context, StateSetter setState) {
                          return GestureDetector(
                            onTap: () async {
                              if (!isIn(post.users_like_id!,
                                  authProvider.loginUserData.id!)) {
                                setState(() {
                                  post.likes = post.likes! + 1;

                                  like = post.likes!;
                                  post.users_like_id!
                                      .add(authProvider!.loginUserData.id!);

                                  //loves.add(idUser);
                                });
                                CollectionReference userCollect =
                                FirebaseFirestore.instance
                                    .collection('Users');
                                // Get docs from collection reference
                                QuerySnapshot querySnapshotUser =
                                await userCollect
                                    .where("id",
                                    isEqualTo: post.user!.id!)
                                    .get();
                                // Afficher la liste
                                List<UserData> listUsers = querySnapshotUser
                                    .docs
                                    .map((doc) => UserData.fromJson(
                                    doc.data() as Map<String, dynamic>))
                                    .toList();

                                if (post.user!.oneIgnalUserid != null &&
                                    post.user!.oneIgnalUserid!.length > 5) {
                                  await authProvider.sendNotification(
                                      userIds: [post.user!.oneIgnalUserid!],
                                      smallImage:
                                      "${authProvider.loginUserData.imageUrl!}",
                                      send_user_id:
                                      "${authProvider.loginUserData.id!}",
                                      recever_user_id: "${post.user!.id!}",
                                      message:
                                      "📢 @${authProvider.loginUserData.pseudo!} a liké votre look",
                                      type_notif: NotificationType.POST.name,
                                      post_id: "${post!.id!}",
                                      post_type: PostDataType.IMAGE.name,
                                      chat_id: '');

                                  NotificationData notif = NotificationData();
                                  notif.id = firestore
                                      .collection('Notifications')
                                      .doc()
                                      .id;
                                  notif.titre = "Nouveau like 👍🏾";
                                  notif.media_url =
                                      authProvider.loginUserData.imageUrl;
                                  notif.type = NotificationType.POST.name;
                                  notif.description =
                                  "@${authProvider.loginUserData.pseudo!} a liké votre look";
                                  notif.users_id_view = [];
                                  notif.user_id =
                                      authProvider.loginUserData.id;
                                  notif.receiver_id = post.user!.id!;
                                  notif.post_id = post.id!;
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
                                }
                                if (listUsers.isNotEmpty) {
                                  SnackBar snackBar = SnackBar(
                                    content: Text(
                                      '+1 point.  Voir le classement',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: Colors.green),
                                    ),
                                  );
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(snackBar);
                                  listUsers.first!.likes =
                                      listUsers.first!.likes! + 1;
                                  printVm("user trouver");

                                  //userProvider.updateUser(listUsers.first);
                                  postProvider.updatePost(
                                      post, listUsers.first, context);
                                  await authProvider.getAppData();
                                  authProvider.appDefaultData.nbr_likes =
                                      authProvider.appDefaultData.nbr_likes! +
                                          1;
                                  authProvider.updateAppData(
                                      authProvider.appDefaultData);
                                } else {
                                  SnackBar snackBar = SnackBar(
                                    content: Text(
                                      '+1 point.  Voir le classement',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: Colors.green),
                                    ),
                                  );
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(snackBar);
                                  post.user!.likes = post.user!.likes! + 1;
                                  postProvider.updatePost(
                                      post, post.user!, context);
                                  await authProvider.getAppData();
                                  authProvider.appDefaultData.nbr_likes =
                                      authProvider.appDefaultData.nbr_likes! +
                                          1;
                                  authProvider.updateAppData(
                                      authProvider.appDefaultData);
                                }
                              }

                              setState(() {
                                //loves.add(idUser);
                              });
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
                                        isIn(
                                            post.users_like_id!,
                                            authProvider
                                                .loginUserData.id!)
                                            ? MaterialCommunityIcons.thumb_up
                                            : MaterialCommunityIcons
                                            .thumb_up_outline,
                                        size: 20,
                                        color: isIn(
                                            post.users_like_id!,
                                            authProvider
                                                .loginUserData.id!)
                                            ? Colors.blue
                                            : Colors.black,
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.only(
                                            left: 1.0, right: 1),
                                        child: TextCustomerPostDescription(
                                          titre: "${formatAbonnes(like)}",
                                          fontSize: SizeText
                                              .homeProfileDateTextSize,
                                          couleur: ConstColors.textColors,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  /*
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.only(left: 1.0,right: 1),
                                        child: SizedBox(
                                          height: 2,
                                          // width: width*0.75,
                                          child: LinearProgressIndicator(
                                            color: Colors.blue,
                                            value: like/post.user!.abonnes!+1,
                                            semanticsLabel: 'Linear progress indicator',
                                          ),
                                        ),
                                      ),
                                    ),
                                    TextCustomerPostDescription(
                                      titre: "${(like/post.user!.abonnes!+1).toStringAsFixed(2)}%",
                                      fontSize: SizeText.homeProfileDateTextSize,
                                      couleur: ConstColors.textColors,
                                      fontWeight: FontWeight.bold,
                                    ),

                                     */
                                ],
                              ),
                            ),
                          );
                        }),
                        StatefulBuilder(builder:
                            (BuildContext context, StateSetter setState) {
                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        PostComments(post: post),
                                  ));

                              //sheetComments(height*0.7,width,post);
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
                                        padding: const EdgeInsets.only(
                                            left: 1.0, right: 1),
                                        child: TextCustomerPostDescription(
                                          titre: "${formatAbonnes(comments)}",
                                          fontSize: SizeText
                                              .homeProfileDateTextSize,
                                          couleur: ConstColors.textColors,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  /*
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.only(left: 1.0,right: 1),
                                        child: SizedBox(
                                          height: 2,
                                          //width: width*0.75,
                                          child: LinearProgressIndicator(
                                            color: Colors.blueGrey,
                                            value: comments/post.user!.abonnes!+1,
                                            semanticsLabel: 'Linear progress indicator',
                                          ),
                                        ),
                                      ),
                                    ),
                                    TextCustomerPostDescription(
                                      titre: "${(comments/post.user!.abonnes!+1).toStringAsFixed(2)}%",
                                      fontSize: SizeText.homeProfileDateTextSize,
                                      couleur: ConstColors.textColors,
                                      fontWeight: FontWeight.bold,
                                    ),

                                     */
                                ],
                              ),
                            ),
                          );
                        }),
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
          }),
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
            stream: postProvider.getPostsImagesByUser(widget.otherUser.id!),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                printVm("attente");
                return  Skeletonizer(

                  child: Padding(
                    padding: const EdgeInsets.only(top: 5.0,bottom: 5),
                    child: Card(
                      child: ListTile(
                        title: Text('Item number as title'),
                        subtitle: const Text('Subtitle here'),
                        trailing: const Icon(
                          Icons.ac_unit,
                          size: 32,
                        ),
                      ),
                    ),
                  ),
                );
              } else if (snapshot.hasError) {
                printVm("erreur ${snapshot.error}");
                return
                  Skeletonizer(

                    child: Padding(
                      padding: const EdgeInsets.only(top: 5.0,bottom: 5),
                      child: Card(
                        child: ListTile(
                          title: Text('Item number as title'),
                          subtitle: const Text('Subtitle here'),
                          trailing: const Icon(
                            Icons.ac_unit,
                            size: 32,
                          ),
                        ),
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
                        child:           HomePostUsersWidget(
                          post: p,
                          // color: _color,
                          height: height, width: width,
                        ),
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
