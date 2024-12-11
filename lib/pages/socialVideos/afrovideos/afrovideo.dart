import 'package:afrotok/pages/socialVideos/afrovideos/videoWidget.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:like_button/like_button.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:page_transition/page_transition.dart';
import 'package:provider/provider.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../constant/logo.dart';
import '../../../constant/sizeText.dart';
import '../../../constant/textCustom.dart';
import '../../../models/chatmodels/message.dart';
import '../../../models/model_data.dart';
import '../../../providers/afroshop/authAfroshopProvider.dart';
import '../../../providers/afroshop/categorie_produits_provider.dart';
import '../../../providers/authProvider.dart';
import '../../../providers/postProvider.dart';
import '../../../providers/userProvider.dart';
import '../../afroshop/marketPlace/acceuil/produit_details.dart';
import '../../chat/entrepriseChat.dart';
import '../../component/consoleWidget.dart';
import '../../postComments.dart';

import 'SimpleVideoView.dart';

class AfroVideo extends StatefulWidget {
  const AfroVideo({super.key});

  @override
  State<AfroVideo> createState() => _AfroVideoState();
}

class _AfroVideoState extends State<AfroVideo> {

  bool abonneTap=false;

  String formatAbonnes(int nbAbonnes) {
    if (nbAbonnes >= 1000) {
      double nombre = nbAbonnes / 1000;
      return nombre.toStringAsFixed(1) + 'k';
    } else {
      return nbAbonnes.toString();
    }
  }
  // bool isUserAbonne(List<UserAbonnes> userAbonnesList, String userIdToCheck) {
  //   return userAbonnesList.any((userAbonne) => userAbonne.abonneUserId == userIdToCheck);
  // }

  late UserAuthProvider authProvider =
  Provider.of<UserAuthProvider>(context, listen: false);
  late PostProvider postProvider =
  Provider.of<PostProvider>(context, listen: false);
  late UserProvider userProvider =
  Provider.of<UserProvider>(context, listen: false);

  late UserShopAuthProvider authProviderShop =
  Provider.of<UserShopAuthProvider>(context, listen: false);
  late CategorieProduitProvider categorieProduitProvider =
  Provider.of<CategorieProduitProvider>(context, listen: false);
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  Future<void> launchWhatsApp(String phone) async {
    //  var whatsappURl_android = "whatsapp://send?phone="+whatsapp+"&text=hello";
    // String url = "https://wa.me/?tel:+228$phone&&text=YourTextHere";
    String url = "whatsapp://send?phone="+phone+"";
    if (!await launchUrl(Uri.parse(url))) {
      final snackBar = SnackBar(duration: Duration(seconds: 2),content: Text("Impossible d\'ouvrir WhatsApp",textAlign: TextAlign.center, style: TextStyle(color: Colors.red),));

      // Afficher le SnackBar en bas de la page
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
      throw Exception('Impossible d\'ouvrir WhatsApp');
    }
  }

  Widget ArticleTile(ArticleData article,double w,double h) {
    // printVm('article ${article.titre}');
    return Card(
      child: Container(
        child: Column(

          children: [
            GestureDetector(
              onTap: () async {
                await  authProviderShop.getUserById(article.user_id!).then(
                      (value) async {
                    if (value.isNotEmpty) {
                      article.user=value.first;
                      await    categorieProduitProvider.getArticleById(article.id!).then((value) {
                        if (value.isNotEmpty) {
                          value.first.vues=value.first.vues!+1;
                          article.vues=value.first.vues!+1;
                          categorieProduitProvider.updateArticle(value.first,context).then((value) {
                            if (value) {


                            }
                          },);

                        }
                      },);
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                ProduitDetail(article: article),
                          ));
                    }
                  },
                );

              },
              child: ClipRRect(
                borderRadius: BorderRadius.only(topLeft: Radius.circular(10),topRight: Radius.circular(5)),
                child: Container(
                  width: w*0.3,
                  height: h*0.069,
                  child: CachedNetworkImage(
                    fit: BoxFit.cover,

                    imageUrl: '${article.images!.first}',
                    progressIndicatorBuilder: (context, url, downloadProgress) =>
                    //  LinearProgressIndicator(),

                    Skeletonizer(
                        child: SizedBox(    width: w*0.2,
                            height: h*0.1, child:  ClipRRect(
                                borderRadius: BorderRadius.all(Radius.circular(10)),child: Image.network('${article.images!.first}')))),
                    errorWidget: (context, url, error) =>  Container(    width: w*0.2,
                        height: h*0.1,child: Image.network('${article.images!.first}',fit: BoxFit.cover,)),
                  ),
                ),
              ),
            ),
            //  SizedBox(height: 10,),
            /*

            Padding(
              padding: const EdgeInsets.only(left: 8.0,right: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  Text("${article!.titre}".toUpperCase(),overflow: TextOverflow.ellipsis,style: TextStyle(fontSize: 10,fontWeight: FontWeight.w500),),
                  // Text(article.description),
                  SizedBox(height: 5,),
                  Container(
                      alignment: Alignment.centerLeft,
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.all(Radius.circular(5)),
                          color:  CustomConstants.kPrimaryColor
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text('${article.prix} Fcfa',style: TextStyle(color: Colors.white,fontWeight: FontWeight.w600,fontSize: 10),),
                      )),
                ],
              ),
            ),

             */
            /*
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
                    likeCount:  article.vues,
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
                    likeCount:   article.contact,
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
                      await    categorieProduitProvider.getArticleById(article.id!).then((value) {
                        if (value.isNotEmpty) {
                          value.first.jaime=value.first.jaime!+1;
                          article.jaime=value.first.jaime!+1;
                          categorieProduitProvider.updateArticle(value.first,context).then((value) {
                            if (value) {


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
                    likeCount:   article.jaime,
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
            )

             */


          ],
        ),
      ),
    );
  }
  void _showUserDetailsAnnonceDialog(String url) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          content: ClipRRect(
            borderRadius: BorderRadius.only(topLeft: Radius.circular(10),topRight: Radius.circular(10)),
            child: Container(

              child: CachedNetworkImage(
                fit: BoxFit.cover,

                imageUrl: '${url}',
                progressIndicatorBuilder: (context, url, downloadProgress) =>
                //  LinearProgressIndicator(),

                Skeletonizer(
                    child: SizedBox(width: 120,height: 100, child:  ClipRRect(
                        borderRadius: BorderRadius.all(Radius.circular(10)),child: Image.asset('assets/images/404.png')))),
                errorWidget: (context, url, error) =>  Container(width: 120,height: 100,child: Image.asset("assets/icon/user-removebg-preview.png",fit: BoxFit.cover,)),
              ),
            ),
          ),
        );
      },
    );
  }
  void _showModalDialog(Post post) {
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

  bool isUserAbonne(List<String> userAbonnesList, String userIdToCheck) {
    return userAbonnesList.any((userAbonneId) => userAbonneId == userIdToCheck);
  }

  bool isIn(List<String> users_id, String userIdToCheck) {
    return users_id.any((item) => item == userIdToCheck);
  }

  Future<Chat> getChatsEntrepriseData(UserData amigo,Post post,EntrepriseData entreprise) async {

    // Définissez la requête
    var friendsStream = FirebaseFirestore.instance.collection('Chats').where( Filter.or(
      Filter('docId', isEqualTo:  '${post.id}${authProvider.loginUserData!.id}'),
      Filter('docId', isEqualTo:  '${authProvider.loginUserData!.id}${post.id}'),

    )).snapshots();

// Obtenez la liste des utilisateurs
    //List<DocumentSnapshot> users = await usersQuery.sget();
    Chat usersChat=Chat();

    if (await friendsStream.isEmpty) {
      printVm("pas de chat ");
      String chatId = FirebaseFirestore.instance
          .collection('Chats')
          .doc()
          .id;
      Chat chat = Chat(
        docId:'${post.id}${authProvider.loginUserData!.id}',
        id: chatId,
        senderId: '${authProvider.loginUserData!.id}',
        receiverId: '${amigo.id}',
        lastMessage: 'hi',
        post_id: post.id,
        entreprise_id: post.entreprise_id,
        type: ChatType.ENTREPRISE.name,
        createdAt: DateTime.now().millisecondsSinceEpoch, // Get current time in milliseconds
        updatedAt: DateTime.now().millisecondsSinceEpoch,
        // Optional: You can initialize sender and receiver with UserData objects, and messages with a list of Message objects
      );
      await FirebaseFirestore.instance.collection('Chats').doc(chatId).set(chat.toJson());
      usersChat=chat;

    }  else{
      printVm("le chat existe  ");
      // printVm("stream :${friendsStream}");
      usersChat= await friendsStream.first.then((value) async {
        // printVm("stream value l :${value.docs.length}");
        if (value.docs.length<=0) {
          printVm("pas de chat ");
          String chatId = FirebaseFirestore.instance
              .collection('Chats')
              .doc()
              .id;
          Chat chat = Chat(
            docId:'${post.id}${authProvider.loginUserData!.id}',
            id: chatId,
            senderId: '${authProvider.loginUserData!.id}',
            receiverId: '${amigo.id}',
            lastMessage: 'hi',
            entreprise_id: post.entreprise_id,
            post_id: post.id,
            type: ChatType.ENTREPRISE.name,
            createdAt: DateTime.now().millisecondsSinceEpoch, // Get current time in milliseconds
            updatedAt: DateTime.now().millisecondsSinceEpoch,
            // Optional: You can initialize sender and receiver with UserData objects, and messages with a list of Message objects
          );
          await FirebaseFirestore.instance.collection('Chats').doc(chatId).set(chat.toJson());
          usersChat=chat;
          return chat;
        }  else{
          return  Chat.fromJson(value.docs.first.data());
        }

      });
      CollectionReference messageCollect = await FirebaseFirestore.instance.collection('Messages');
      QuerySnapshot querySnapshotMessage = await messageCollect.where("chat_id",isEqualTo:usersChat.id!).get();
      // Afficher la liste
      List<Message> messageList = querySnapshotMessage.docs.map((doc) =>
          Message.fromJson(doc.data() as Map<String, dynamic>)).toList();


      if (messageList.isEmpty) {
        usersChat.messages=[];
        userProvider.chat=usersChat;
        printVm("messages vide ");
      }else{
        printVm("have messages");
        usersChat.messages=messageList;
        userProvider.chat=usersChat;
      }

      /////////////ami//////////
      CollectionReference friendCollect = await FirebaseFirestore.instance.collection('Users');
      QuerySnapshot querySnapshotUserSender = await friendCollect.where("id",isEqualTo:authProvider.loginUserData.id==amigo.id!?'${amigo.id}':'${authProvider.loginUserData!.id}').get();
      // Afficher la liste
      QuerySnapshot querySnapshotUserReceiver= await friendCollect.where("id",isEqualTo:authProvider.loginUserData.id==amigo.id?'${authProvider.loginUserData!.id}':'${amigo.id}').get();


      List<UserData> receiverUserList = querySnapshotUserReceiver.docs.map((doc) =>
          UserData.fromJson(doc.data() as Map<String, dynamic>)).toList();
      usersChat.receiver=receiverUserList.first;

      List<UserData> senderUserList = querySnapshotUserSender.docs.map((doc) =>
          UserData.fromJson(doc.data() as Map<String, dynamic>)).toList();
      usersChat.sender=senderUserList.first;

      /////////////entreprise//////////
      CollectionReference entrepriseCollect = await FirebaseFirestore.instance.collection('Entreprises');
      QuerySnapshot querySnapshotentreprise = await entrepriseCollect.where("id",isEqualTo:'${post.entreprise_id}').get();
      List<EntrepriseData> entrepriseList = querySnapshotentreprise.docs.map((doc) =>
          EntrepriseData.fromJson(doc.data() as Map<String, dynamic>)).toList();
      usersChat.entreprise=entrepriseList.first;



    }

    return usersChat;
  }

  @override
  Widget build(BuildContext context) {
    double h = MediaQuery.of(context).size.height;
    double w = MediaQuery.of(context).size.width;
    return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          iconTheme: IconThemeData(color: Colors.green),
          backgroundColor: Colors.transparent,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Logo(),
            )
          ],
        ),
        body: Center(
          child: Column(
            children: [


              Expanded(
                child: Consumer<PostProvider>(
              builder: (context, postListProvider, child) {
              var datas= postListProvider.videos;
              return postListProvider.videos.isEmpty
              ? Center(child: SizedBox(
                height: 20,
          width: 20,

          child: CircularProgressIndicator()))
          : PageView.builder(
                          scrollDirection: Axis.vertical,
                          itemCount: datas.length,

                          itemBuilder: (context, index) {
                            // printVm("index : ${index}");
                            // if (datas[index].type==PostType.PUB.name) {
                            //   if (!isIn(datas[index].users_vue_id!,authProvider.loginUserData.id!)) {
                            //
                            //
                            //   }else{
                            //
                            //     datas[index].users_vue_id!.add(authProvider!.loginUserData.id!);
                            //   }
                            //
                            //   datas[index].vues=datas[index].vues!+1;
                            //   // vue=post.vues!;
                            //
                            //
                            //   postProvider.updateVuePost(datas[index],context);
                            //   printVm("update......");
                            //   //loves.add(idUser);
                            //
                            //
                            //
                            //   // }
                            // }

                            //  datas.shuffle();
                            // datas.shuffle();


                            return   Container(
                              color: Colors.black,
                              //  height: MediaQuery.of(context).size.height,
                              child: Stack(
                                children: [
                                  // VideoWidget(post: datas[index]!),
              Container(
              width: w,
              height: h*0.99,
              child: SimpleVideoPlayerWidget(videoUrl: datas[index].url_media!)),
                                  // Container(
                                  //   padding: const EdgeInsets.all(10.0),
                                  //   decoration: BoxDecoration(
                                  //     gradient: LinearGradient(
                                  //       colors: [
                                  //         Colors.black,
                                  //         Colors.transparent,
                                  //         Colors.transparent,
                                  //         Colors.black.withOpacity(0.15)
                                  //       ],
                                  //       begin: Alignment.topCenter,
                                  //       end: Alignment.bottomCenter,
                                  //       stops: const [0, 0, 0.6, 1],
                                  //     ),
                                  //   ),
                                  // ),
                                  Positioned(

                                    left: 12.0,
                                    bottom: 20.0,
                                    child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: SafeArea(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              datas[index].type==PostType.PUB.name?
                                              Column(

                                                children: [
                                                  Padding(
                                                    padding: const EdgeInsets.only(bottom: 4.0),
                                                    child: Row(
                                                      children: [
                                                        Icon(Entypo.network,size: 15,color: Colors.green,),
                                                        SizedBox(width: 10,),
                                                        TextCustomerUserTitle(
                                                          titre: "publicité",
                                                          fontSize: SizeText.homeProfileTextSize,
                                                          couleur: Colors.white,
                                                          fontWeight: FontWeight.w400,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  Row(
                                                    children: [
                                                      Row(
                                                        children: [
                                                          Padding(
                                                            padding: const EdgeInsets.only(right: 8.0),
                                                            child: CircleAvatar(
                                                              radius: 12,
                                                              backgroundImage: NetworkImage(
                                                                  '${ datas[index].entrepriseData!.urlImage!}'),
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
                                                                      titre: "${ datas[index].entrepriseData!.titre!}",
                                                                      fontSize: 10,
                                                                      couleur: Colors.white,
                                                                      fontWeight: FontWeight.bold,

                                                                    ),
                                                                  ),
                                                                  TextCustomerUserTitle(
                                                                    titre: "${datas[index].entrepriseData!.suivi!} suivi(s)",
                                                                    fontSize: 10,
                                                                    couleur: Colors.white,
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

                                                      SizedBox(width: 10,),
                                                      Icon(Entypo.arrow_long_right,color: Colors.green,size: 12,),
                                                      SizedBox(width: 10,),
                                                      Row(
                                                        children: [
                                                          Padding(
                                                            padding: const EdgeInsets.only(right: 8.0),
                                                            child: CircleAvatar(
                                                              radius: 12,
                                                              backgroundImage: NetworkImage(
                                                                  '${ datas[index].user!.imageUrl!}'),
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
                                                                      titre: "@${ datas[index].user!.pseudo!}",
                                                                      fontSize: 10,
                                                                      couleur: Colors.white,
                                                                      fontWeight: FontWeight.bold,
                                                                    ),
                                                                  ),
                                                                  TextCustomerUserTitle(
                                                                    titre: "${ datas[index].user!.abonnes!} abonné(s)",
                                                                    fontSize: 10,
                                                                    couleur: Colors.white,
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
                                                  SizedBox(height: 5,),
                                                  Row(
                                                    children: [
                                                      Container(
                                                        //width: 50,
                                                        height: 30,
                                                        margin: EdgeInsets.zero,
                                                        decoration: BoxDecoration(
                                                            color: Colors.blue,
                                                            borderRadius: BorderRadius.all(Radius.circular(20))),

                                                        child: Padding(
                                                          padding: const EdgeInsets.only(left: 3.0,right: 3),
                                                          child: TextButton(onPressed: () {
                                                            printVm('contact tap');
                                                            getChatsEntrepriseData( datas[index].user!, datas[index], datas[index].entrepriseData!).then((chat) async {
                                                              userProvider.chat.messages=chat.messages;

                                                              //_chewieController.pause();
                                                              // videoPlayerController.pause();


                                                              Navigator.push(context, PageTransition(type: PageTransitionType.fade, child: EntrepriseMyChat(title: 'mon chat', chat: chat, post: datas[index], isEntreprise: false,)));





                                                            },);

                                                          },
                                                              child: Row(
                                                                mainAxisAlignment: MainAxisAlignment.center,
                                                                crossAxisAlignment: CrossAxisAlignment.center,
                                                                children: [
                                                                  Icon(AntDesign.message1,color: Colors.white,size: 12,),
                                                                  SizedBox(width: 5,),
                                                                  Text("Afrolook",style: TextStyle(color: Colors.white,fontSize: 12,fontWeight: FontWeight.w600),),
                                                                ],
                                                              )),
                                                        ),

                                                      ),
                                                      SizedBox(width: 10,),
                                                      Container(
                                                        //width: 50,
                                                        height: 30,
                                                        margin: EdgeInsets.zero,
                                                        decoration: BoxDecoration(
                                                            color: Colors.white,
                                                            borderRadius: BorderRadius.all(Radius.circular(20))),

                                                        child: Padding(
                                                          padding: const EdgeInsets.only(left: 3.0,right: 3),
                                                          child: TextButton(onPressed: () {
                                                            launchWhatsApp("${datas[index].contact_whatsapp}");


                                                          },
                                                              child: Row(
                                                                mainAxisAlignment: MainAxisAlignment.center,
                                                                crossAxisAlignment: CrossAxisAlignment.center,
                                                                children: [
                                                                  Icon(Fontisto.whatsapp,color: Colors.green,size: 12,),
                                                                  SizedBox(width: 5,),
                                                                  Text("WhatsApp",style: TextStyle(color: Colors.green,fontSize: 12,fontWeight: FontWeight.w600),),
                                                                ],
                                                              )),
                                                        ),

                                                      ),

                                                    ],
                                                  )

                                                ],
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                              ): Row(
                                                children: [
                                                  Container(
                                                    height: 30.0,
                                                    width: 30.0,
                                                    decoration: BoxDecoration(
                                                        border:
                                                        Border.all(width: 1.0, color: Colors.white),
                                                        shape: BoxShape.circle,
                                                        image: DecorationImage(
                                                            image: NetworkImage( datas[index].user!.imageUrl!),
                                                            fit: BoxFit.cover)),
                                                  ),
                                                  const SizedBox(
                                                    width: 5.0,
                                                  ),
                                                  Text(
                                                    "@${datas[index].user!.pseudo!}",
                                                    style: const TextStyle(
                                                      fontSize: 12.0, color: Colors.white,),
                                                  ),
                                                  const SizedBox(
                                                    width: 5.0,
                                                  )
                                                ],
                                              ),
                                              const SizedBox(
                                                height: 12.0,
                                              ),
                                              Container(
                                                width: 300,
                                                height: 40,
                                                child: Text(
                                                  datas[index].description!,
                                                  style: const TextStyle(color: Colors.white,fontSize: 10),
                                                ),
                                              )
                                            ],
                                          )),
                                    ),
                                  ),
                                  Positioned(
                                      right: 10.0,
                                      bottom: 50.0,
                                      child: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Column(
                                          children: [
                                            const SizedBox(
                                              height: 20.0,
                                            ),
                                            // StatefulBuilder(
                                            //
                                            //     builder: (BuildContext context, void Function(void Function()) setStateM) {
                                            //       return Container(
                                            //         child:    isUserAbonne(datas[index].user!.userAbonnesIds!,
                                            //             authProvider.loginUserData.id!)?
                                            //         Container(
                                            //
                                            //           child: Icon(Icons.check_circle,color:Colors.green),
                                            //           alignment: Alignment.center,
                                            //
                                            //         ):
                                            //         Container(
                                            //
                                            //           child: TextButton(
                                            //             onPressed:abonneTap?
                                            //                 ()  { }:
                                            //                 ()async{
                                            //                   if (!isUserAbonne(
                                            //                       datas[index].user!
                                            //                           .userAbonnesIds!,
                                            //                       authProvider
                                            //                           .loginUserData
                                            //                           .id!))
                                            //                   {
                                            //                     setStateM(() {
                                            //                       abonneTap = true;
                                            //                     });
                                            //                     UserAbonnes userAbonne =
                                            //                     UserAbonnes();
                                            //                     userAbonne.compteUserId =
                                            //                         authProvider
                                            //                             .loginUserData.id;
                                            //                     userAbonne.abonneUserId =
                                            //                         datas[index].user!.id;
                                            //
                                            //                     userAbonne
                                            //                         .createdAt = DateTime
                                            //                         .now()
                                            //                         .millisecondsSinceEpoch;
                                            //                     userAbonne
                                            //                         .updatedAt = DateTime
                                            //                         .now()
                                            //                         .millisecondsSinceEpoch;
                                            //                     await userProvider
                                            //                         .sendAbonnementRequest(
                                            //                         userAbonne,
                                            //                         datas[index].user!,
                                            //                         context)
                                            //                         .then(
                                            //                           (value) async {
                                            //                         if (value) {
                                            //                           authProvider
                                            //                               .loginUserData
                                            //                               .userAbonnes!
                                            //                               .add(
                                            //                               userAbonne);
                                            //                           datas[index].user!
                                            //                               .userAbonnesIds!.add(userAbonne.id!);
                                            //                           // await userProvider.getUsers(authProvider.loginUserData!.id!);
                                            //                           await authProvider
                                            //                               .getCurrentUser(
                                            //                               authProvider
                                            //                                   .loginUserData!
                                            //                                   .id!);
                                            //                           datas[index].user!
                                            //                               .userAbonnesIds!
                                            //                               .add(authProvider
                                            //                               .loginUserData
                                            //                               .id!);
                                            //                           userProvider
                                            //                               .updateUser(
                                            //                               datas[index].user!);
                                            //                           if (datas[index].user!
                                            //                               .oneIgnalUserid !=
                                            //                               null &&
                                            //                               datas[index]
                                            //                                   .user!
                                            //                                   .oneIgnalUserid!
                                            //                                   .length >
                                            //                                   5) {
                                            //                             await authProvider.sendNotification(
                                            //                                 userIds: [
                                            //                                   datas[index].user!
                                            //                                       .oneIgnalUserid!
                                            //                                 ],
                                            //                                 smallImage:
                                            //                                 "${authProvider.loginUserData.imageUrl!}",
                                            //                                 send_user_id:
                                            //                                 "${authProvider.loginUserData.id!}",
                                            //                                 recever_user_id:
                                            //                                 "${datas[index].user!.id!}",
                                            //                                 message:
                                            //                                 "📢 @${authProvider.loginUserData.pseudo!} s'est abonné(e) à votre compte",
                                            //                                 type_notif:
                                            //                                 NotificationType
                                            //                                     .ABONNER
                                            //                                     .name,
                                            //                                 post_id:
                                            //                                 "${datas[index]!.id!}",
                                            //                                 post_type:
                                            //                                 PostDataType
                                            //                                     .IMAGE
                                            //                                     .name,
                                            //                                 chat_id: '');
                                            //                             NotificationData
                                            //                             notif =
                                            //                             NotificationData();
                                            //                             notif.id = firestore
                                            //                                 .collection(
                                            //                                 'Notifications')
                                            //                                 .doc()
                                            //                                 .id;
                                            //                             notif.titre =
                                            //                             "Nouveau Abonnement ✅";
                                            //                             notif.media_url =
                                            //                                 authProvider
                                            //                                     .loginUserData
                                            //                                     .imageUrl;
                                            //                             notif.type =
                                            //                                 NotificationType
                                            //                                     .ABONNER
                                            //                                     .name;
                                            //                             notif.description =
                                            //                             "@${authProvider.loginUserData.pseudo!} s'est abonné(e) à votre compte";
                                            //                             notif.users_id_view =
                                            //                             [];
                                            //                             notif.user_id =
                                            //                                 authProvider
                                            //                                     .loginUserData
                                            //                                     .id;
                                            //                             notif.receiver_id =
                                            //                             datas[index].user!
                                            //                                 .id!;
                                            //                             notif.post_id =
                                            //                             datas[index].id!;
                                            //                             notif.post_data_type =
                                            //                             PostDataType
                                            //                                 .IMAGE
                                            //                                 .name!;
                                            //                             notif.updatedAt =
                                            //                                 DateTime.now()
                                            //                                     .microsecondsSinceEpoch;
                                            //                             notif.createdAt =
                                            //                                 DateTime.now()
                                            //                                     .microsecondsSinceEpoch;
                                            //                             notif.status =
                                            //                                 PostStatus
                                            //                                     .VALIDE
                                            //                                     .name;
                                            //
                                            //                             // users.add(pseudo.toJson());
                                            //
                                            //                             await firestore
                                            //                                 .collection(
                                            //                                 'Notifications')
                                            //                                 .doc(notif.id)
                                            //                                 .set(notif
                                            //                                 .toJson());
                                            //                           }
                                            //                           SnackBar snackBar =
                                            //                           SnackBar(
                                            //                             content: Text(
                                            //                               'abonné, Bravo ! Vous avez gagné 4 points.',
                                            //                               textAlign:
                                            //                               TextAlign
                                            //                                   .center,
                                            //                               style: TextStyle(
                                            //                                   color: Colors
                                            //                                       .green),
                                            //                             ),
                                            //                           );
                                            //                           ScaffoldMessenger
                                            //                               .of(context)
                                            //                               .showSnackBar(
                                            //                               snackBar);
                                            //                           setStateM(() {
                                            //                             abonneTap = false;
                                            //                           });
                                            //                         } else {
                                            //                           SnackBar snackBar =
                                            //                           SnackBar(
                                            //                             content: Text(
                                            //                               'une erreur',
                                            //                               textAlign:
                                            //                               TextAlign
                                            //                                   .center,
                                            //                               style: TextStyle(
                                            //                                   color: Colors
                                            //                                       .red),
                                            //                             ),
                                            //                           );
                                            //                           ScaffoldMessenger
                                            //                               .of(context)
                                            //                               .showSnackBar(
                                            //                               snackBar);
                                            //                           setStateM(() {
                                            //                             abonneTap = false;
                                            //                           });
                                            //                         }
                                            //                       },
                                            //                     );
                                            //
                                            //                     setStateM(() {
                                            //                       abonneTap = false;
                                            //                     });
                                            //                   }
                                            //                   setState(() {
                                            //
                                            //                   });
                                            //
                                            //               // if (!isUserAbonne(datas[index].user!.userAbonnesIds!,
                                            //               //     authProvider.loginUserData.id!)) {
                                            //               //   setState(() {
                                            //               //     abonneTap=true;
                                            //               //   });
                                            //               //   UserAbonnes userAbonne = UserAbonnes();
                                            //               //   userAbonne.compteUserId=authProvider.loginUserData.id;
                                            //               //   userAbonne.abonneUserId=datas[index].user!.id;
                                            //               //
                                            //               //   userAbonne.createdAt  = DateTime.now().millisecondsSinceEpoch;
                                            //               //   userAbonne.updatedAt  = DateTime.now().millisecondsSinceEpoch;
                                            //               //   await  userProvider.sendAbonnementRequest(userAbonne,datas[index].user!,context).then((value) async {
                                            //               //     if (value) {
                                            //               //
                                            //               //
                                            //               //       // await userProvider.getUsers(authProvider.loginUserData!.id!);
                                            //               //       authProvider.loginUserData.userAbonnes!.add(userAbonne);
                                            //               //       await authProvider.getCurrentUser(authProvider.loginUserData!.id!);
                                            //               //       if (datas[index].user!.oneIgnalUserid!=null&&datas[index].user!.oneIgnalUserid!.length>5) {
                                            //               //         await authProvider.sendNotification(
                                            //               //             userIds: [datas[index].user!.oneIgnalUserid!],
                                            //               //             smallImage: "${authProvider.loginUserData.imageUrl!}",
                                            //               //             send_user_id: "${authProvider.loginUserData.id!}",
                                            //               //             recever_user_id: "${datas[index].user!.id!}",
                                            //               //             message: "📢 @${authProvider.loginUserData.pseudo!} s'est abonné(e) à votre compte",
                                            //               //             type_notif: NotificationType.ABONNER.name,
                                            //               //             post_id: "${datas[index]!.id!}",
                                            //               //             post_type: PostDataType.VIDEO.name, chat_id: ''
                                            //               //         );
                                            //               //         NotificationData notif=NotificationData();
                                            //               //         notif.id=firestore
                                            //               //             .collection('Notifications')
                                            //               //             .doc()
                                            //               //             .id;
                                            //               //         notif.titre="Nouveau Abonnement ✅";
                                            //               //         notif.media_url=authProvider.loginUserData.imageUrl;
                                            //               //         notif.type=NotificationType.ABONNER.name;
                                            //               //         notif.description="@${authProvider.loginUserData.pseudo!} s'est abonné(e) à votre compte";
                                            //               //         notif.users_id_view=[];
                                            //               //         notif.user_id=authProvider.loginUserData.id;
                                            //               //         notif.receiver_id="${datas[index].user!.id!}";
                                            //               //         notif.updatedAt =
                                            //               //             DateTime.now().microsecondsSinceEpoch;
                                            //               //         notif.createdAt =
                                            //               //             DateTime.now().microsecondsSinceEpoch;
                                            //               //         notif.status = PostStatus.VALIDE.name;
                                            //               //
                                            //               //         // users.add(pseudo.toJson());
                                            //               //
                                            //               //         await firestore.collection('Notifications').doc(notif.id).set(notif.toJson());
                                            //               //
                                            //               //
                                            //               //       }
                                            //               //       SnackBar snackBar = SnackBar(
                                            //               //         content: Text('abonné, Bravo ! Vous avez gagné 4 points.',textAlign: TextAlign.center,style: TextStyle(color: Colors.green),),
                                            //               //       );
                                            //               //       ScaffoldMessenger.of(context).showSnackBar(snackBar);
                                            //               //       setState(() {
                                            //               //         abonneTap=false;
                                            //               //
                                            //               //       });
                                            //               //     }  else{
                                            //               //       SnackBar snackBar = SnackBar(
                                            //               //         content: Text('une erreur',textAlign: TextAlign.center,style: TextStyle(color: Colors.red),),
                                            //               //       );
                                            //               //       ScaffoldMessenger.of(context).showSnackBar(snackBar);
                                            //               //       setState(() {
                                            //               //         abonneTap=false;
                                            //               //       });
                                            //               //     }
                                            //               //   },);
                                            //               //
                                            //               //
                                            //               //   setState(() {
                                            //               //     abonneTap=false;
                                            //               //   });
                                            //               // }
                                            //             },
                                            //             child:abonneTap? Center(
                                            //               child: LoadingAnimationWidget.flickr(
                                            //                 size: 20,
                                            //                 leftDotColor: Colors.green,
                                            //                 rightDotColor: Colors.black,
                                            //               ),
                                            //             ):
                                            //             Container(
                                            //
                                            //               child: Icon(Icons.add,color:Colors.white,size: 15,),
                                            //               alignment: Alignment.center,
                                            //               width: 40,
                                            //               height: 20,
                                            //               decoration: BoxDecoration(
                                            //                   color: Colors.red,
                                            //                   borderRadius: BorderRadius.all(Radius.circular(10))
                                            //               ),
                                            //             ),),
                                            //         ),
                                            //       );
                                            //     }
                                            // ),
                                            // const SizedBox(
                                            //   height: 5.0,
                                            // ),

                                            LikeButton(

                                              onTap: (bool isLiked) async {
                                                if (!isIn( datas[index].users_love_id!,authProvider.loginUserData.id!)) {
                                                  printVm('tap');
                                                  setState(()  {
                                                    datas[index].loves=datas[index]!.loves!+1;


                                                    datas[index]!.users_love_id!.add(authProvider!.loginUserData.id!);

                                                    printVm('update');
                                                    //loves.add(idUser);
                                                  });
                                                  CollectionReference userCollect =
                                                  FirebaseFirestore.instance.collection('Users');
                                                  // Get docs from collection reference
                                                  QuerySnapshot querySnapshotUser = await userCollect.where("id",isEqualTo: datas[index].user!.id!).get();
                                                  // Afficher la liste
                                                  List<UserData>  listUsers = querySnapshotUser.docs.map((doc) =>
                                                      UserData.fromJson(doc.data() as Map<String, dynamic>)).toList();
                                                  if (listUsers.isNotEmpty) {
                                                    listUsers.first!.jaimes=listUsers.first!.jaimes!+1;
                                                    postProvider.updatePost(datas[index], listUsers.first!!,context);
                                                    await authProvider.getAppData();
                                                    authProvider.appDefaultData.nbr_loves=authProvider.appDefaultData.nbr_loves!+1;
                                                    authProvider.updateAppData(authProvider.appDefaultData);


                                                  }else{
                                                    datas[index].user!.jaimes=datas[index].user!.jaimes!+1;
                                                    postProvider.updatePost( datas[index],datas[index].user!,context);
                                                    await authProvider.getAppData();
                                                    authProvider.appDefaultData.nbr_loves=authProvider.appDefaultData.nbr_loves!+1;
                                                    authProvider.updateAppData(authProvider.appDefaultData);

                                                  }
                                                  await authProvider.sendNotification(
                                                      userIds: [datas[index].user!.oneIgnalUserid!],
                                                      smallImage: "${authProvider.loginUserData.imageUrl!}",
                                                      send_user_id: "${authProvider.loginUserData.id!}",
                                                      recever_user_id: "${datas[index].user!.id!}",
                                                      message: "📢 @${authProvider.loginUserData.pseudo!} a aimé ❤️ votre look video",
                                                      type_notif: NotificationType.POST.name,
                                                      post_id: "${datas[index]!.id!}",
                                                      post_type: PostDataType.VIDEO.name, chat_id: ''
                                                  );

                                                  NotificationData notif=NotificationData();
                                                  notif.id=firestore
                                                      .collection('Notifications')
                                                      .doc()
                                                      .id;
                                                  notif.titre="Nouveau j'aime ❤️";
                                                  notif.media_url=authProvider.loginUserData.imageUrl;
                                                  notif.type=NotificationType.POST.name;
                                                  notif.description="@${authProvider.loginUserData.pseudo!} a aimé votre look video";
                                                  notif.users_id_view=[];
                                                  notif.user_id=authProvider.loginUserData.id;
                                                  notif.receiver_id="${datas[index].user!.id!}";
                                                  notif.post_id=datas[index].id!;
                                                  notif.post_data_type=PostDataType.VIDEO.name!;
                                                  notif.updatedAt =
                                                      DateTime.now().microsecondsSinceEpoch;
                                                  notif.createdAt =
                                                      DateTime.now().microsecondsSinceEpoch;
                                                  notif.status = PostStatus.VALIDE.name;

                                                  // users.add(pseudo.toJson());

                                                  await firestore.collection('Notifications').doc(notif.id).set(notif.toJson());

                                                }

                                                return Future.value(!isLiked);
                                              },
                                              isLiked: isIn(datas[index]!.users_love_id!,authProvider.loginUserData.id!),

                                              size: 35,
                                              circleColor:
                                              CircleColor(start: Color(0xff00ddff), end: Color(0xff0099cc)),
                                              bubblesColor: BubblesColor(
                                                dotPrimaryColor: Color(0xff3b9ade),
                                                dotSecondaryColor: Color(0xffe33232),
                                              ),
                                              countPostion: CountPostion.bottom,
                                              likeBuilder: (bool isLiked) {
                                                return Icon(
                                                  Entypo.heart,
                                                  color: isLiked ? Colors.red : Colors.white,
                                                  size: 35,
                                                );
                                              },
                                              likeCount:  datas[index]!.users_love_id!.length!,
                                              countBuilder: (int? count, bool isLiked, String text) {
                                                var color = isLiked ? Colors.white : Colors.white;
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
                                            // LikeButton(
                                            //   onTap: (bool isLiked) async {
                                            //     if (!isIn( datas[index]!.users_like_id!,authProvider.loginUserData.id!)) {
                                            //       printVm('tap');
                                            //       setState(()  {
                                            //         datas[index]!.likes= datas[index]!.likes!+1;
                                            //
                                            //         datas[index].users_like_id!.add(authProvider!.loginUserData.id!);
                                            //
                                            //         printVm('update');
                                            //         //loves.add(idUser);
                                            //       });
                                            //       CollectionReference userCollect =
                                            //       FirebaseFirestore.instance.collection('Users');
                                            //       // Get docs from collection reference
                                            //       QuerySnapshot querySnapshotUser = await userCollect.where("id",isEqualTo: datas[index].user!.id!).get();
                                            //       // Afficher la liste
                                            //       List<UserData>  listUsers = querySnapshotUser.docs.map((doc) =>
                                            //           UserData.fromJson(doc.data() as Map<String, dynamic>)).toList();
                                            //
                                            //
                                            //       if (listUsers.isNotEmpty) {
                                            //         listUsers.first!.likes=listUsers.first!.likes!+1;
                                            //         postProvider.updatePost(datas[index], listUsers.first,context);
                                            //         authProvider.appDefaultData.nbr_likes=authProvider.appDefaultData.nbr_likes!+1;
                                            //         authProvider.updateAppData(authProvider.appDefaultData);
                                            //
                                            //
                                            //       }else{
                                            //         datas[index].user!.likes=datas[index].user!.likes!+1;
                                            //         postProvider.updatePost( datas[index],datas[index].user!,context);
                                            //         authProvider.appDefaultData.nbr_likes=authProvider.appDefaultData.nbr_likes!+1;
                                            //         authProvider.updateAppData(authProvider.appDefaultData);
                                            //       }
                                            //
                                            //       await authProvider.sendNotification(
                                            //           userIds: [datas[index].user!.oneIgnalUserid!],
                                            //           smallImage: "${authProvider.loginUserData.imageUrl!}",
                                            //           send_user_id: "${authProvider.loginUserData.id!}",
                                            //           recever_user_id: "${datas[index].user!.id!}",
                                            //           message: "📢 @${authProvider.loginUserData.pseudo!} a liké 👍🏾 votre look video",
                                            //           type_notif: NotificationType.POST.name,
                                            //           post_id: "${datas[index]!.id!}",
                                            //           post_type: PostDataType.VIDEO.name, chat_id: ''
                                            //       );
                                            //
                                            //       NotificationData notif=NotificationData();
                                            //       notif.id=firestore
                                            //           .collection('Notifications')
                                            //           .doc()
                                            //           .id;
                                            //       notif.titre="Nouveau like 👍🏾";
                                            //       notif.media_url=authProvider.loginUserData.imageUrl;
                                            //       notif.type=NotificationType.POST.name;
                                            //       notif.description="@${authProvider.loginUserData.pseudo!} a liké votre look video";
                                            //       notif.users_id_view=[];
                                            //       notif.user_id=authProvider.loginUserData.id;
                                            //       notif.receiver_id=datas[index]!.user!.id!;
                                            //       notif.post_id=datas[index]!.id!;
                                            //       notif.post_data_type=PostDataType.VIDEO.name!;
                                            //
                                            //       notif.updatedAt =
                                            //           DateTime.now().microsecondsSinceEpoch;
                                            //       notif.createdAt =
                                            //           DateTime.now().microsecondsSinceEpoch;
                                            //       notif.status = PostStatus.VALIDE.name;
                                            //
                                            //       // users.add(pseudo.toJson());
                                            //
                                            //       await firestore.collection('Notifications').doc(notif.id).set(notif.toJson());
                                            //
                                            //     }
                                            //
                                            //
                                            //
                                            //     return Future.value(!isLiked);
                                            //   },
                                            //   isLiked: isIn( datas[index]!.users_like_id!,authProvider.loginUserData.id!),
                                            //   size: 35,
                                            //   circleColor:
                                            //   CircleColor(start: Color(0xff00ddff), end: Color(0xff0099cc)),
                                            //   bubblesColor: BubblesColor(
                                            //     dotPrimaryColor: Color(0xff3b9ade),
                                            //     dotSecondaryColor: Color(0xff1176f3),
                                            //   ),
                                            //   countPostion: CountPostion.bottom,
                                            //   likeBuilder: (bool isLiked) {
                                            //     return Icon(
                                            //       AntDesign.like1,
                                            //       color: isLiked ? Colors.blue : Colors.white,
                                            //       size: 35,
                                            //
                                            //
                                            //
                                            //     );
                                            //   },
                                            //   likeCount:  datas[index]!.users_like_id!.length!,
                                            //   countBuilder: (int? count, bool isLiked, String text) {
                                            //     var color = isLiked ? Colors.white : Colors.white;
                                            //     Widget result;
                                            //     if (count == 0) {
                                            //       result = Text(
                                            //         "0",textAlign: TextAlign.center,
                                            //         style: TextStyle(color: color),
                                            //       );
                                            //     } else
                                            //       result = Text(
                                            //         text,
                                            //         style: TextStyle(color: color),
                                            //       );
                                            //     return result;
                                            //   },
                                            //
                                            // ),

                                            LikeButton(
                                              onTap: (bool isLiked) {

                                                //  _chewieController.pause();
                                                //  videoPlayerController.pause();


                                                Navigator.push(context, MaterialPageRoute(builder: (context) => PostComments(post:  datas[index]!),));


                                                return Future.value(!isLiked);
                                              },

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
                                                  FontAwesome.commenting,
                                                  color: isLiked ? Colors.white : Colors.white,
                                                  size: 35,
                                                );
                                              },
                                              likeCount: datas[index]!.comments!,
                                              countBuilder: (int? count, bool isLiked, String text) {
                                                var color = isLiked ? Colors.white : Colors.white;
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
                                                  FontAwesome.eye,
                                                  color: isLiked ? Colors.white : Colors.white,
                                                  size: 35,
                                                );
                                              },
                                              likeCount:  datas[index].vues!,
                                              countBuilder: (int? count, bool isLiked, String text) {
                                                var color = isLiked ? Colors.white : Colors.white;
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

                                            IconButton(
                                                onPressed: () {
                                                  _showModalDialog(datas[index]);
                                                },
                                                icon: Icon(
                                                  Icons.more_horiz,
                                                  size: 35,
                                                  color: Colors.white,
                                                )),

                                          ],
                                        ),
                                      ))
                                ],
                              ),
                            );
                          });

                  },
                ),
              ),
            ],
          ),
        )
    );

  }
}



