

import 'dart:async';
import 'package:afrotok/layout/centered_content.dart';
import 'package:afrotok/layout/responsive_layout.dart';


import 'package:afrotok/services/api.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:page_transition/page_transition.dart';
import 'package:provider/provider.dart';
import 'package:searchable_listview/searchable_listview.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../constant/constColors.dart';
import '../../../models/chatmodels/message.dart';
import '../../../models/model_data.dart';
import '../../../providers/authProvider.dart';
import '../../../providers/userProvider.dart';
import '../../auth/authTest/constants.dart';

import '../../chat/myChat.dart';
import '../../component/consoleWidget.dart';
import '../detailsOtherUser.dart';
import '../../../theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../home/user_presence_widget.dart';


class MesAmis extends StatefulWidget {
  final BuildContext context;
  MesAmis({super.key, required this.context});

  @override
  State<MesAmis> createState() => _MesAmisState();
}

class _MesAmisState extends State<MesAmis> {
  late UserAuthProvider authProvider =
  Provider.of<UserAuthProvider>(widget.context, listen: false);

  late UserProvider userProvider =
  Provider.of<UserProvider>(widget.context, listen: false);
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  String formatNumber(int number) {
    if (number >= 1000) {
      double nombre = number / 1000;
      return nombre.toStringAsFixed(1) + 'k';
    } else {
      return number.toString();
    }
  }

  void _showUserDetailsModalDialog(UserData user,double w,double h) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          content: DetailsOtherUser(user: user, w: w, h: h,),
        );
      },
    );
  }
  Widget Monami(Friends amigo) {
    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);
    final friendId = authProvider.loginUserData.id == amigo.currentUserId ? amigo.friendId! : amigo.currentUserId!;
    return Container(
      padding: EdgeInsets.only(left: 16,right: 16,top: 10,bottom: 10),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Row(
              children: <Widget>[
                GestureDetector(
                  onTap: () {
                    _showUserDetailsModalDialog(amigo.friend!,width,height);
                  },
                  child: Stack(
                    children: [
                      CircleAvatar(
                        backgroundImage: NetworkImage("${amigo.friend!.imageUrl!}"),
                        maxRadius: 30,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: UserPresenceWidget(
                          userId: friendId,
                          size: 14.0,
                          showTextStatus: false,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 16,),
                Expanded(
                  child:  GestureDetector(
                    onTap: () {
                      getChatsData(amigo).then((chat) async {
                        userProvider.chat.messages=chat.messages;
                        Navigator.push(context, PageTransition(type: PageTransitionType.fade, child: MyChat(title: 'mon chat', chat: chat,)));
                      },);
                    },
                    child: Container(
                      color: Colors.transparent,
                      child: Row(
                        spacing: 10,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text("@${amigo.friend!.pseudo!}", style: TextStyle(fontSize: 16,color: colors.textPrimary),),
                              SizedBox(height: 6,),
                              Text('${formatNumber(amigo.friend!.abonnes!)} ${l10n.amiSubscribers}',style: TextStyle(fontSize: 13,color: colors.textSecondary, fontWeight: FontWeight.normal),),
                            ],
                          ),
                          Visibility(
                            visible: amigo.friend!.isVerify!,
                            child: Card(
                              child: Icon(
                                Icons.verified,
                                color: colors.primary,
                                size: 17,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                GestureDetector(
                    onTap: () {
                      getChatsData(amigo).then((chat) async {
                        userProvider.chat.messages=chat.messages;
                        Navigator.push(context, PageTransition(type: PageTransitionType.fade, child: MyChat(title: 'mon chat', chat: chat,)));
                      },);
                    },
                    child: Icon(Icons.message,color: colors.primary,))
              ],
            ),
          ),
        ],
      ),
    );
  }
  late List<Friends> listfirends=[];
  Future<void> searchListDialogue(BuildContext context,double h,double w,List<Friends> firends) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        final colors = AppColors.of(context);
        final l10n = AppLocalizations.of(context);
        return AlertDialog(
          backgroundColor: colors.surface,
          title: Text(l10n.amiListTitle, style: TextStyle(color: colors.textPrimary)),
          content: Container(
            height: h, // Ajustez la hauteur selon vos besoins
            width: w, // Ajustez la largeur selon vos besoins
            child: ListView(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.all(2.0),
                  child: SizedBox(
                    height: h, // Ajustez la hauteur selon vos besoins
                    width: w,
                    child: SearchableList<Friends>(
                      initialList: firends,
                      // builder: (displayedList, itemIndex, friend) => GestureDetector(
                      //     onTap: () {
                      //       // Navigator.push(context, PageTransition(type: PageTransitionType.fade, child: ChatScreen(currentUserData: authProvider.loginUserData!, secondUser: snapshot.data![index]!.friend!)));
                      //       getChatsData(friend).then((chat) {
                      //         userProvider.chat.messages=chat.messages;
                      //         Navigator.pop(context);
                      //
                      //         Navigator.push(context, PageTransition(type: PageTransitionType.fade, child: MyChat(title: 'mon chat', chat: chat,)));
                      //
                      //
                      //
                      //       },);
                      //
                      //
                      //       //  Navigator.pushNamed(context, '/basic_chat');
                      //     },
                      //
                      //     child: Monami(friend)),
                      filter: (value) => firends.where((element) => element.friend!.pseudo!.toLowerCase().contains(value.toLowerCase()),).toList(),
                      emptyWidget:  Container(
                        child: Text(l10n.amiListEmpty, style: TextStyle(color: colors.textSecondary)),
                      ),
                      inputDecoration: InputDecoration(
                        labelText: l10n.amiSearchLabel,
                        labelStyle: TextStyle(color: colors.textSecondary),
                        fillColor: colors.surfaceVariant,
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: colors.primary,
                            width: 1.0,
                          ),
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                      ), itemBuilder: (Friends friend) => GestureDetector(
                        onTap: () {
                          // Navigator.push(context, PageTransition(type: PageTransitionType.fade, child: ChatScreen(currentUserData: authProvider.loginUserData!, secondUser: snapshot.data![index]!.friend!)));
                          getChatsData(friend).then((chat) {
                            userProvider.chat.messages=chat.messages;
                            Navigator.pop(context);

                            Navigator.push(context, PageTransition(type: PageTransitionType.fade, child: MyChat(title: 'mon chat', chat: chat,)));



                          },);


                          //  Navigator.pushNamed(context, '/basic_chat');
                        },

                        child: Monami(friend)),
                    ),
                  ),
                ),
                // Ajoutez d'autres éléments de liste ici
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(l10n.amiClose, style: TextStyle(color: colors.primary)),
            ),
          ],
        );
      },
    );
  }





  bool dejaAmi(List<Friends> invitationList, int userIdToCheck) {
    return invitationList.any((userAbonne) => userAbonne.friendId! == userIdToCheck);
  }

  Stream<List<Friends>> getFriendsData() async* {
    final currentUserId = authProvider.loginUserData.id!;

    // Définissez la requête
    var friendsStream = FirebaseFirestore.instance.collection('Friends').where( Filter.or(
        Filter('current_user_id', isEqualTo:  currentUserId),
        Filter('friend_id', isEqualTo:  currentUserId),

    )).snapshots();

    await for (var friendSnapshot in friendsStream) {
      if (friendSnapshot.docs.isEmpty) {
        listfirends = [];
        userProvider.countFriends = 0;
        yield [];
        continue;
      }

      // Associe chaque ami (Friends doc) à l'id de l'autre utilisateur
      final Map<String, Friends> friendByUserId = {};
      for (var friendDoc in friendSnapshot.docs) {
        final friend = Friends.fromJson(friendDoc.data());
        final otherUserId = currentUserId == friendDoc["current_user_id"]
            ? friendDoc["friend_id"] as String
            : friendDoc["current_user_id"] as String;
        friendByUserId[otherUserId] = friend;
      }

      // Récupération groupée des profils (par lots de 10, en parallèle)
      final ids = friendByUserId.keys.toList();
      final List<Future<QuerySnapshot>> batchFutures = [];
      for (int i = 0; i < ids.length; i += 10) {
        final batch = ids.skip(i).take(10).toList();
        batchFutures.add(
          FirebaseFirestore.instance.collection('Users').where('id', whereIn: batch).get(),
        );
      }
      final batchResults = await Future.wait(batchFutures);

      final List<Friends> friends = [];
      final Set<String> seenPseudos = {};
      for (var snapshot in batchResults) {
        for (var doc in snapshot.docs) {
          final userData = UserData.fromJson(doc.data() as Map<String, dynamic>);
          final friend = friendByUserId[userData.id];
          if (friend != null && !seenPseudos.contains(userData.pseudo)) {
            friend.friend = userData;
            friends.add(friend);
            seenPseudos.add(userData.pseudo!);
          }
        }
      }

      listfirends = friends;
      userProvider.countFriends = friends.length;
      yield friends;
    }
  }


  Future<Chat> getChatsData(Friends amigo) async {

    // Définissez la requête
    var friendsStream = FirebaseFirestore.instance.collection('Chats').where( Filter.or(
      Filter('docId', isEqualTo:  '${amigo.friendId}${amigo.currentUserId}'),
      Filter('docId', isEqualTo:  '${amigo.currentUserId}${amigo.friendId}'),

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
    docId:'${amigo.friendId}${amigo.currentUserId}',
    id: chatId,
    senderId: authProvider.loginUserData.id==amigo.friendId?'${amigo.friendId}':'${amigo.currentUserId}',
    receiverId: authProvider.loginUserData.id==amigo.friendId?'${amigo.currentUserId}':'${amigo.friendId}',
    lastMessage: 'hi',

    type: ChatType.USER.name,
    createdAt: DateTime.now().millisecondsSinceEpoch, // Get current time in milliseconds
    updatedAt: DateTime.now().millisecondsSinceEpoch,
    // Optional: You can initialize sender and receiver with UserData objects, and messages with a list of Message objects
  );
  await FirebaseFirestore.instance.collection('Chats').doc(chatId).set(chat.toJson());
  usersChat=chat;

}  else{
  printVm("le chat existe  ");
  printVm("stream :${friendsStream}");
  usersChat= await friendsStream.first.then((value) async {
    printVm("stream value l :${value.docs.length}");
    if (value.docs.length<=0) {
      printVm("pas de chat ");
      String chatId = FirebaseFirestore.instance
          .collection('Chats')
          .doc()
          .id;
      Chat chat = Chat(
        docId:'${amigo.friendId}${amigo.currentUserId}',
        id: chatId,
        senderId: authProvider.loginUserData.id==amigo.friendId?'${amigo.friendId}':'${amigo.currentUserId}',
        receiverId: authProvider.loginUserData.id==amigo.friendId?'${amigo.currentUserId}':'${amigo.friendId}',
        lastMessage: 'hi',

        type: ChatType.USER.name,
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
    printVm("messgae vide ");
  }else{
    printVm("have messages");
    usersChat.messages=messageList;
    userProvider.chat=usersChat;
  }

  /////////////ami//////////
  CollectionReference friendCollect = await FirebaseFirestore.instance.collection('Users');
  QuerySnapshot querySnapshotUserSender = await friendCollect.where("id",isEqualTo:authProvider.loginUserData.id==amigo.friendId?'${amigo.friendId}':'${amigo.currentUserId}').get();
  // Afficher la liste
  QuerySnapshot querySnapshotUserReceiver= await friendCollect.where("id",isEqualTo:authProvider.loginUserData.id==amigo.friendId?'${amigo.currentUserId}':'${amigo.friendId}').get();


  List<UserData> receiverUserList = querySnapshotUserReceiver.docs.map((doc) =>
      UserData.fromJson(doc.data() as Map<String, dynamic>)).toList();
  usersChat.receiver=receiverUserList.first;

  List<UserData> senderUserList = querySnapshotUserSender.docs.map((doc) =>
      UserData.fromJson(doc.data() as Map<String, dynamic>)).toList();
  usersChat.sender=senderUserList.first;

}

    return usersChat;
  }

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final _myStreamController = StreamController.broadcast();

  Stream get myStream => _myStreamController.stream;

  // Autres méthodes pour ajouter des données au stream, etc.
  void dispose() {
    super.dispose();
    _myStreamController.close();
  }

  @override
  Widget build(BuildContext context) {
    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;
    return Material(
      type: MaterialType.transparency,
      child: CenteredContent(
      maxWidth: AppLayout.isDesktop(context) ? 700 : AppLayout.maxFeedWidth,
      child: SingleChildScrollView(
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.only(top: 16,left: 16,right: 16),
            child: TextField(
              onTap: () {
                searchListDialogue(context,height*0.6,width*0.8,listfirends);
              },
              readOnly: true,


              cursorColor: kPrimaryColor,
              decoration: InputDecoration(
                focusColor: ConstColors.buttonColors,
                focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: kPrimaryColor)),
                hintText: "Recherche...",
                hintStyle: TextStyle(color: Colors.grey.shade600),
                prefixIcon: Icon(Icons.search,color: Colors.grey.shade600, size: 20,),
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding: EdgeInsets.all(8),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(
                        color: Colors.grey.shade100
                    )
                ),
              ),
            ),
          ),
          StreamBuilder<List<Friends>>(
            //initialData: [],
            stream: getFriendsData()!,

            // key: _formKey,

            builder: (context, AsyncSnapshot<List<Friends>> snapshot) {



              if (snapshot.hasData) {
                return
                  ListView.builder(
                    scrollDirection: Axis.vertical,
                    itemCount: snapshot.data!.length,

                    shrinkWrap: true,
                    padding: EdgeInsets.only(top: 16),
                    physics: NeverScrollableScrollPhysics(),
                    itemBuilder: (context, index){
                      return Monami(snapshot.data![index]!

                      );
                    },
                  );
              }
              else if (snapshot.hasError) {
                printVm("${snapshot.error}");
                return    Center(
                  child: Column(
                    children: [
                      Image.asset('assets/images/404.png',height: 200,width: 200,),
                      Text("Erreurs lors du chargement",style: TextStyle(color: Colors.red),),
                      TextButton(
                        child: Text('Réessayer',style: TextStyle(color: Colors.green),),
                        onPressed: () {
                          setState(() {

                          });
                          // Réessayez de charger la page.
                        },
                      ),
                    ],
                  ),
                );
              } else {
                // Utiliser les données de snapshot.data

                return  Skeletonizer(
                  //enabled: _loading,
                  child: Column(
                    children: [
                      Container(
                        padding: EdgeInsets.only(left: 16,right: 16,top: 10,bottom: 10),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: Row(
                                children: <Widget>[
                                  CircleAvatar(
                                    backgroundImage: AssetImage("assets/images/404.png"),
                                    maxRadius: 30,
                                  ),
                                  SizedBox(width: 16,),
                                  Expanded(
                                    child: Container(
                                      color: Colors.transparent,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: <Widget>[
                                          Text("amigo!.friend!.pseudo!", style: TextStyle(fontSize: 16),),
                                          SizedBox(height: 6,),
                                          Text(' abonne(s)',style: TextStyle(fontSize: 13,color: Colors.grey.shade600, fontWeight: FontWeight.normal),),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Icon(Icons.send_sharp,color: Colors.green,)
                                ],
                              ),
                            ),


                          ],
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.only(left: 16,right: 16,top: 10,bottom: 10),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: Row(
                                children: <Widget>[
                                  CircleAvatar(
                                    backgroundImage: AssetImage("assets/images/404.png"),
                                    maxRadius: 30,
                                  ),
                                  SizedBox(width: 16,),
                                  Expanded(
                                    child: Container(
                                      color: Colors.transparent,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: <Widget>[
                                          Text("amigo!.friend!.pseudo!", style: TextStyle(fontSize: 16),),
                                          SizedBox(height: 6,),
                                          Text(' abonne(s)',style: TextStyle(fontSize: 13,color: Colors.grey.shade600, fontWeight: FontWeight.normal),),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Icon(Icons.send_sharp,color: Colors.green,)
                                ],
                              ),
                            ),


                          ],
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.only(left: 16,right: 16,top: 10,bottom: 10),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: Row(
                                children: <Widget>[
                                  CircleAvatar(
                                    backgroundImage: AssetImage("assets/images/404.png"),
                                    maxRadius: 30,
                                  ),
                                  SizedBox(width: 16,),
                                  Expanded(
                                    child: Container(
                                      color: Colors.transparent,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: <Widget>[
                                          Text("amigo!.friend!.pseudo!", style: TextStyle(fontSize: 16),),
                                          SizedBox(height: 6,),
                                          Text(' abonne(s)',style: TextStyle(fontSize: 13,color: Colors.grey.shade600, fontWeight: FontWeight.normal),),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Icon(Icons.send_sharp,color: Colors.green,)
                                ],
                              ),
                            ),


                          ],
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.only(left: 16,right: 16,top: 10,bottom: 10),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: Row(
                                children: <Widget>[
                                  CircleAvatar(
                                    backgroundImage: AssetImage("assets/images/404.png"),
                                    maxRadius: 30,
                                  ),
                                  SizedBox(width: 16,),
                                  Expanded(
                                    child: Container(
                                      color: Colors.transparent,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: <Widget>[
                                          Text("amigo!.friend!.pseudo!", style: TextStyle(fontSize: 16),),
                                          SizedBox(height: 6,),
                                          Text(' abonne(s)',style: TextStyle(fontSize: 13,color: Colors.grey.shade600, fontWeight: FontWeight.normal),),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Icon(Icons.send_sharp,color: Colors.green,)
                                ],
                              ),
                            ),


                          ],
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.only(left: 16,right: 16,top: 10,bottom: 10),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: Row(
                                children: <Widget>[
                                  CircleAvatar(
                                    backgroundImage: AssetImage("assets/images/404.png"),
                                    maxRadius: 30,
                                  ),
                                  SizedBox(width: 16,),
                                  Expanded(
                                    child: Container(
                                      color: Colors.transparent,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: <Widget>[
                                          Text("amigo!.friend!.pseudo!", style: TextStyle(fontSize: 16),),
                                          SizedBox(height: 6,),
                                          Text(' abonne(s)',style: TextStyle(fontSize: 13,color: Colors.grey.shade600, fontWeight: FontWeight.normal),),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Icon(Icons.send_sharp,color: Colors.green,)
                                ],
                              ),
                            ),


                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }
            },
          ),
        ],
      ),
      ),  // CenteredContent
      ),  // Material
    );
  }
}


