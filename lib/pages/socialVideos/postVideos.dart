import 'dart:ffi';

import 'package:afrotok/constant/logo.dart';
import 'package:afrotok/pages/socialVideos/videoPlayer.dart';
import 'package:afrotok/providers/postProvider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:chewie/chewie.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:eva_icons_flutter/eva_icons_flutter.dart';
import 'package:flutter_carousel_widget/flutter_carousel_widget.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:ionicons/ionicons.dart';
import 'package:like_button/like_button.dart';
import 'package:marquee/marquee.dart';
import 'package:page_transition/page_transition.dart';
import 'package:provider/provider.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:video_player/video_player.dart';

import '../../constant/constColors.dart';
import '../../constant/custom_theme.dart';
import '../../constant/sizeText.dart';
import '../../constant/textCustom.dart';
import '../../models/chatmodels/message.dart';
import '../../models/model_data.dart';
import '../../providers/afroshop/authAfroshopProvider.dart';
import '../../providers/afroshop/categorie_produits_provider.dart';
import '../../providers/authProvider.dart';
import '../../providers/userProvider.dart';
import '../afroshop/marketPlace/acceuil/produit_details.dart';
import '../chat/entrepriseChat.dart';
import '../postComments.dart';
import 'elements/error_element.dart';
import 'elements/loader.dart';



class PostVideos extends StatefulWidget {

   PostVideos({Key? key}) : super(key: key);

  @override
  _PostVideosState createState() => _PostVideosState();
}

class _PostVideosState extends State<PostVideos> {

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

  Widget ArticleTile(ArticleData article,double w,double h) {
   // print('article ${article.titre}');
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
          title: Text('Menu d\'options'),
          content: SingleChildScrollView(
            child: Column(
              children: <Widget>[
                ListTile(
                  onTap: () async {

                    post.status=PostStatus.SIGNALER.name;
                    await postProvider.updateVuePost(post, context).then((value) {
                      if (value) {
                        SnackBar snackBar = SnackBar(
                          content: Text(
                            'Post signalé !',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.green),
                          ),
                        );
                        ScaffoldMessenger.of(context)
                            .showSnackBar(snackBar);
                      }  else{
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
                      Navigator.pop(context);
                    },);
                    setState(() {
                    });

                  },
                  leading: Icon(Icons.flag,color: Colors.blueGrey,),
                  title: Text('Signaler',),
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
                ListTile(
                  onTap: () async {
                    if (authProvider.loginUserData.role==UserRole.ADM.name) {
                      post.status=PostStatus.NONVALIDE.name;
                      await postProvider.updateVuePost(post, context).then((value) {
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
                        }  else{
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
                      },);
                    }  else
                    if (post.type==PostType.POST.name){
                      if (post.user!.id==authProvider.loginUserData.id) {
                        post.status=PostStatus.SUPPRIMER.name;
                        await postProvider.updateVuePost(post, context).then((value) {
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
                          }  else{
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
                        },);
                      }

                    }



                    setState(() {
                      Navigator.pop(context);

                    });

                  },
                  leading: Icon(Icons.delete,color: Colors.red,),
                  title:authProvider.loginUserData.role==UserRole.ADM.name? Text('Bloquer'):Text('Supprimer'),
                ),
              ],
            ),
          ),
        );
      },
    );
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
      print("pas de chat ");
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
      print("le chat existe  ");
      // print("stream :${friendsStream}");
      usersChat= await friendsStream.first.then((value) async {
        // print("stream value l :${value.docs.length}");
        if (value.docs.length<=0) {
          print("pas de chat ");
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
        print("messages vide ");
      }else{
        print("have messages");
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
  void initState() {
   // feedBloc.getFeeds();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: Colors.black,
        body: Column(
          children: [

            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(top: 2.0,bottom: 0,left: 8),
                child: Row(
                  children: [
                    Icon(Icons.storefront,size: 20,color: Colors.green,),
                    SizedBox(width: 2,),
                    TextCustomerPostDescription(
                      titre:
                      "Afroshop Annonces ",
                      fontSize: 10,
                      couleur: CustomConstants.kPrimaryColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ],
                ),
              ),
            ),


            Padding(
              padding: const EdgeInsets.all(4.0),
              child: FutureBuilder<List<ArticleData>>(
                  future: categorieProduitProvider.getAllArticles(),
                  builder: (BuildContext context, AsyncSnapshot snapshot) {
                    if (snapshot.hasData) {
                      List<ArticleData> articles=snapshot.data;
                      return Column(
                        children: [
                          Container(
                            height: height*0.08,
                            width: width,
                            child: FlutterCarousel.builder(
                              itemCount: articles.length,
                              itemBuilder: (BuildContext context, int index, int pageViewIndex) =>
                                  ArticleTile( articles[index],width,height),
                              options: CarouselOptions(
                                autoPlay: true,
                                //controller: buttonCarouselController,
                                enlargeCenterPage: true,
                                viewportFraction: 0.4,
                                aspectRatio: 2.0,
                                initialPage: 1,
                                reverse: true,
                                autoPlayInterval: const Duration(seconds: 2),
                                autoPlayAnimationDuration: const Duration(milliseconds: 800),
                                autoPlayCurve: Curves.fastOutSlowIn,

                              ),
                            ),
                          ),
                          /*
                          Container(
                            height: height*0.08,
                            width: width,
                            alignment: Alignment.centerLeft,
                            child: ListView.builder(

                              scrollDirection: Axis.horizontal,
                              itemCount: articles.length,
                              itemBuilder:
                                  (BuildContext context, int index) {
                                return ArticleTile( articles[index],width,height);
                              },
                            ),
                          ),

                           */
                        ],
                      );
                    } else if (snapshot.hasError) {
                      return Icon(Icons.error_outline);
                    } else {
                      return CircularProgressIndicator();
                    }
                  }),
            ),

            Expanded(
              child: FutureBuilder<List<Post>>(
                future: postProvider.getPostsVideos(),
                builder: (context, AsyncSnapshot<List<Post>> snapshot) {
                  if (snapshot.hasData) {

                    return _buildFeedWidget(snapshot.data!);
                  } else if (snapshot.hasError) {
                    return buildErrorWidget("Error");
                  } else {
                    return buildLoadingWidget();
                  }
                },
              ),
            ),
          ],
        ));
  }

  Widget _buildFeedWidget(List<Post> datas) {


    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;

    return PageView.builder(
        scrollDirection: Axis.vertical,
        itemCount: datas.length,
        itemBuilder: (context, index) {

          return   Container(
            color: Colors.black,
          //  height: MediaQuery.of(context).size.height,
            child: Stack(
              children: [
                VideoWidget(post: datas[index]!),
                Container(
                  padding: const EdgeInsets.all(10.0),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black,
                        Colors.transparent,
                        Colors.transparent,
                        Colors.black.withOpacity(0.15)
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0, 0, 0.6, 1],
                    ),
                  ),
                ),
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
                                      print('contact tap');
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
                                            Text("Contacter",style: TextStyle(color: Colors.white,fontSize: 12),),
                                          ],
                                        )),
                                  ),

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
                    right: 12.0,
                    bottom: 20.0,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        children: [
                          const SizedBox(
                            height: 20.0,
                          ),
                          LikeButton(

                            onTap: (bool isLiked) async {
                              if (!isIn( datas[index].users_love_id!,authProvider.loginUserData.id!)) {
                                print('tap');
                                setState(()  {
                                  datas[index].loves=datas[index]!.loves!+1;


                                  datas[index]!.users_love_id!.add(authProvider!.loginUserData.id!);

                                  print('update');
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
                          LikeButton(
                            onTap: (bool isLiked) async {
                              if (!isIn( datas[index]!.users_like_id!,authProvider.loginUserData.id!)) {
                                print('tap');
                                setState(()  {
                                  datas[index]!.likes= datas[index]!.likes!+1;

                                  datas[index].users_like_id!.add(authProvider!.loginUserData.id!);

                                  print('update');
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
                                  listUsers.first!.likes=listUsers.first!.likes!+1;
                                  postProvider.updatePost(datas[index], listUsers.first,context);
                                  authProvider.appDefaultData.nbr_likes=authProvider.appDefaultData.nbr_likes!+1;
                                  authProvider.updateAppData(authProvider.appDefaultData);


                                }else{
                                  datas[index].user!.likes=datas[index].user!.likes!+1;
                                  postProvider.updatePost( datas[index],datas[index].user!,context);
                                  authProvider.appDefaultData.nbr_likes=authProvider.appDefaultData.nbr_likes!+1;
                                  authProvider.updateAppData(authProvider.appDefaultData);
                                }
                              }



                              return Future.value(!isLiked);
                            },
                            isLiked: isIn( datas[index]!.users_like_id!,authProvider.loginUserData.id!),
                            size: 35,
                            circleColor:
                            CircleColor(start: Color(0xff00ddff), end: Color(0xff0099cc)),
                            bubblesColor: BubblesColor(
                              dotPrimaryColor: Color(0xff3b9ade),
                              dotSecondaryColor: Color(0xff1176f3),
                            ),
                            countPostion: CountPostion.bottom,
                            likeBuilder: (bool isLiked) {
                              return Icon(
                                AntDesign.like1,
                                color: isLiked ? Colors.blue : Colors.white,
                                size: 35,



                              );
                            },
                            likeCount:  datas[index]!.users_like_id!.length!,
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
  }
}

class VideoWidget extends StatefulWidget {

  final Post post;

  const VideoWidget({Key? key, required this.post}) : super(key: key);

  @override
  _VideoWidgetState createState() => _VideoWidgetState();
}

class _VideoWidgetState extends State<VideoWidget> {
  late VideoPlayerController videoPlayerController;
  late Future<void> _initializeVideoPlayerFuture;
 // late ChewieController _chewieController;

  bool _buttonEnabled = true;

  void _showModalDialog(Post post) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Menu d\'options'),
          content: SingleChildScrollView(
            child: Column(
              children: <Widget>[
                ListTile(
                  onTap: () async {

                    post.status=PostStatus.SIGNALER.name;
                    await postProvider.updateVuePost(post, context).then((value) {
                      if (value) {
                        SnackBar snackBar = SnackBar(
                          content: Text(
                            'Post signalé !',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.green),
                          ),
                        );
                        ScaffoldMessenger.of(context)
                            .showSnackBar(snackBar);
                      }  else{
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
                      Navigator.pop(context);
                    },);
                    setState(() {
                    });

                  },
                  leading: Icon(Icons.flag,color: Colors.blueGrey,),
                  title: Text('Signaler',),
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
                ListTile(
                  onTap: () async {
                    if (authProvider.loginUserData.role==UserRole.ADM.name) {
                      post.status=PostStatus.NONVALIDE.name;
                      await postProvider.updateVuePost(post, context).then((value) {
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
                        }  else{
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
                      },);
                    }  else
                    if (post.type==PostType.POST.name){
                      if (post.user!.id==authProvider.loginUserData.id) {
                        post.status=PostStatus.SUPPRIMER.name;
                        await postProvider.updateVuePost(post, context).then((value) {
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
                          }  else{
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
                        },);
                      }

                    }



                    setState(() {
                      Navigator.pop(context);

                    });

                  },
                  leading: Icon(Icons.delete,color: Colors.red,),
                  title:authProvider.loginUserData.role==UserRole.ADM.name? Text('Bloquer'):Text('Supprimer'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  bool isIn(List<String> users_id, String userIdToCheck) {
    return users_id.any((item) => item == userIdToCheck);
  }
  late UserAuthProvider authProvider =
  Provider.of<UserAuthProvider>(context, listen: false);
  late PostProvider postProvider =
  Provider.of<PostProvider>(context, listen: false);
  late UserProvider userProvider =
  Provider.of<UserProvider>(context, listen: false);
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
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
      print("pas de chat ");
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
      print("le chat existe  ");
      // print("stream :${friendsStream}");
      usersChat= await friendsStream.first.then((value) async {
        // print("stream value l :${value.docs.length}");
        if (value.docs.length<=0) {
          print("pas de chat ");
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
        print("messages vide ");
      }else{
        print("have messages");
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
  void initState() {
    videoPlayerController = VideoPlayerController.contentUri(Uri.parse(widget.post.url_media!));

    _initializeVideoPlayerFuture = videoPlayerController.initialize().then((_) {

    });
    /*
    _chewieController = ChewieController(
      videoPlayerController: videoPlayerController,
      //placeholder: Container(color: Colors.red, child: Text("afrolook")),
      materialProgressColors: ChewieProgressColors(backgroundColor: Colors.green,playedColor: Colors.black,handleColor: Colors.black),
      cupertinoProgressColors: ChewieProgressColors(backgroundColor: Colors.green,playedColor: Colors.black,handleColor: Colors.black),
      //aspectRatio: 16 / 12, // Réglage de l'aspect ratio de la vidéo
      autoPlay: true, // Définir si la vidéo doit démarrer automatiquement
      looping: true, // Définir si la vidéo doit être en mode boucle
      allowFullScreen: true,
     //
      // autoInitialize: true,

      //startAt: Duration(seconds: 1),
      fullScreenByDefault: true,
      errorBuilder: (context, errorMessage) => Container(width: 50,height: 50, child: CircularProgressIndicator(color: Colors.green,)),
    );
    _chewieController.play();

     */
    super.initState();

    videoPlayerController.setLooping(true);
    videoPlayerController.play();
  }

  @override
  void dispose() {

   // _chewieController.dispose();
    super.dispose();
    videoPlayerController.pause();
    videoPlayerController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: _initializeVideoPlayerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return videoPlayerController.value.isInitialized
                ? Listener(

              behavior: HitTestBehavior.opaque,
              onPointerDown: (PointerDownEvent details){
                print('Contact léger détecté 1!');
                bool isReady=true;
                if (widget.post!.type==PostType.PUB.name) {

                  if (_buttonEnabled) {
                    _buttonEnabled = false;

                      if (widget.post!.type==PostType.PUB.name) {
                        if (!isIn(widget.post!.users_vue_id!,authProvider.loginUserData.id!)) {


                        }else{

                          widget.post!.users_vue_id!.add(authProvider!.loginUserData.id!);
                        }

                          widget.post!.vues=widget.post!.vues!+1;



                        // vue=datas[index]!.vues!;


                        postProvider.updateVuePost(widget.post!,context);
                        //loves.add(idUser);



                        // }
                      }
                      _buttonEnabled = true;

                  }  else{
                    print('indispo!');
                  }
                }

              },
                  child: GestureDetector(
                    onTap: () {
                      print('tap tap taptap');
                      if (videoPlayerController.value.isPlaying) {
                        print('pause 1!');
                       // _chewieController.pause();
                        videoPlayerController.pause();

                      } else {

                        //_chewieController.play();
                        videoPlayerController.play();

                        print('play 1!');
                      }
                    },
                    child: SizedBox.expand(
                                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: videoPlayerController.value.size.width,
                      height: videoPlayerController.value.size.height,
                      child: GestureDetector(
                        onTap: () {
                          print('on tap tap');
                        },
                        child:VideoPlayer(
                            key: new PageStorageKey(widget.post.url_media!),
                            videoPlayerController
                        )
                            /*
                        Chewie(
                          key: new PageStorageKey(widget.post.url_media!),
                          controller: _chewieController,

                        ),

                             */
                      ),
                    ),
                                  ),
                                ),
                  ),
                )
                : Container();
          } else {
            return Container();
          }
        },
      );
  }
}
