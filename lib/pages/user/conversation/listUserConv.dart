import 'package:afrotok/models/chatmodels/message.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/widgets.dart';
import 'package:insta_image_viewer/insta_image_viewer.dart';
import 'package:page_transition/page_transition.dart';
import 'package:provider/provider.dart';
import 'package:searchable_listview/searchable_listview.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../constant/constColors.dart';
import '../../../constant/logo.dart';
import '../../../constant/sizeText.dart';
import '../../../constant/textCustom.dart';
import '../../../models/model_data.dart';
import '../../../providers/authProvider.dart';
import '../../../providers/userProvider.dart';
import '../../auth/authTest/constants.dart';
import '../../chat/myChat.dart';
import '../../component/consoleWidget.dart';
import '../detailsOtherUser.dart';

class ListUserChats extends StatefulWidget {
  const ListUserChats({super.key});

  @override
  State<ListUserChats> createState() => _ListUserChatsState();
}

class _ListUserChatsState extends State<ListUserChats> {
  late UserAuthProvider authProvider =
      Provider.of<UserAuthProvider>(context, listen: false);
  late List<Friends> listfirends = [];

  late UserProvider userProvider =
      Provider.of<UserProvider>(context, listen: false);
  Widget chatWidget(Chat chat) {
    return Container(
      padding: EdgeInsets.only(left: 16, right: 16, top: 10, bottom: 10),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Row(
              children: <Widget>[
                StreamBuilder<UserData>(
                    stream: userProvider.getStreamUser(chat!.chatFriend!.id!),
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        return Stack(
                          children: [
                            CircleAvatar(
                              backgroundImage:
                                  NetworkImage("${snapshot.data!.imageUrl!}"),
                              maxRadius: 25,
                            ),
                            Positioned(
                              bottom: 3,
                              right: 5,
                              child: ClipRRect(
                                borderRadius:
                                    BorderRadius.all(Radius.circular(200)),
                                child: Container(
                                  width: 12,
                                  height: 12,
                                  color: snapshot.data!.state ==
                                          UserState.OFFLINE.name
                                      ? Colors.blueGrey
                                      : Colors.green,
                                ),
                              ),
                            )
                          ],
                        );
                      }
                      return Stack(
                        children: [
                          CircleAvatar(
                            backgroundImage:
                                NetworkImage("${chat!.chatFriend!.imageUrl!}"),
                            maxRadius: 25,
                          ),
                          Positioned(
                            bottom: 3,
                            right: 5,
                            child: ClipRRect(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(200)),
                              child: Container(
                                width: 12,
                                height: 12,
                                color: Colors.blueGrey,
                              ),
                            ),
                          )
                        ],
                      );
                    }),
                SizedBox(
                  width: 16,
                ),
                Expanded(
                  child: Container(
                    color: Colors.transparent,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          "@${chat!.chatFriend!.pseudo!}",
                          style: TextStyle(fontSize: 16),
                        ),
                        SizedBox(
                          height: 6,
                        ),

                        StreamBuilder<Chat>(
                            stream: userProvider.getStreamChat(chat.id!),
                            builder: (context, snapshot) {
                              if (snapshot.hasData) {
                                Chat streamchat=snapshot!.data!;
                              //  printVm("update chat: ${streamchat.toJson()}");

                                if (authProvider.loginUserData.id ==
                                    snapshot!.data!.senderId) {
                                  return snapshot!.data!.receiver_sending==IsSendMessage.SENDING.name
                                      ? TextCustomerUserTitle(
                                    titre: "écrit...",
                                    fontSize: SizeText.homeProfileTextSize,
                                    couleur: Colors.green,
                                    fontWeight: FontWeight.w400,
                                  )
                                      : SizedBox(
                                      width: 200,
                                      height: 22,
                                      child: Text(
                                        '${chat.lastMessage!}',
                                        overflow: TextOverflow.fade,
                                        style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey.shade600,
                                            fontWeight: FontWeight.normal),
                                      ));
                                } else if (authProvider.loginUserData.id ==
                                    snapshot!.data!.receiverId) {
                                  return snapshot!.data!.send_sending==IsSendMessage.SENDING.name
                                      ? TextCustomerUserTitle(
                                    titre: "écrit...",
                                    fontSize: SizeText.homeProfileTextSize,
                                    couleur: Colors.green,
                                    fontWeight: FontWeight.w400,
                                  )
                                      : SizedBox(
                                      width: 200,
                                      height: 22,
                                      child: Text(
                                        '${chat.lastMessage!}',
                                        overflow: TextOverflow.fade,
                                        style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey.shade600,
                                            fontWeight: FontWeight.normal),
                                      ));
                                }else {
                                  return SizedBox(
                                      width: 200,
                                      height: 22,
                                      child: Text(
                                        '${chat.lastMessage!}',
                                        overflow: TextOverflow.fade,
                                        style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey.shade600,
                                            fontWeight: FontWeight.normal),
                                      ));

                                }
                              }else {
                                return SizedBox(
                                    width: 200,
                                    height: 22,
                                    child: Text(
                                      '${chat.lastMessage!}',
                                      overflow: TextOverflow.fade,
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey.shade600,
                                          fontWeight: FontWeight.normal),
                                    ));

                              }
                            }),


                      ],
                    ),
                  ),
                ),
                ClipRRect(
                  borderRadius: BorderRadius.all(Radius.circular(200)),
                  child: Container(
                      color: chat.senderId != authProvider.loginUserData.id!
                          ? chat.your_msg_not_read == 0
                              ? Colors.white
                              : Colors.red
                          : chat.my_msg_not_read == 0
                              ? Colors.white
                              : Colors.red,
                      child: Padding(
                        padding: const EdgeInsets.all(5.0),
                        child: Text(
                          '${chat.senderId != authProvider.loginUserData.id! ? chat.your_msg_not_read == 0 ? '' : chat.your_msg_not_read : chat.my_msg_not_read == 0 ? '' : chat.my_msg_not_read}',
                          style: TextStyle(
                              fontSize: 13,
                              color: Colors.white,
                              fontWeight: FontWeight.w600),
                        ),
                      )),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget chatUserOnLyWidget(Chat chat) {
    return Container(
      padding: EdgeInsets.only(left: 16, right: 16, top: 10, bottom: 10),
      child: StreamBuilder<UserData>(
          stream: userProvider.getStreamUser(chat!.chatFriend!.id!),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return Stack(
                children: [
                  CircleAvatar(
                    backgroundImage:
                        NetworkImage("${snapshot.data!.imageUrl!}"),
                    maxRadius: 27,
                  ),
                  Positioned(
                    bottom: 12,
                    right: 4,
                    child: ClipRRect(
                      borderRadius: BorderRadius.all(Radius.circular(200)),
                      child: Container(
                        width: 12,
                        height: 12,
                        color: snapshot.data!.state == UserState.OFFLINE.name
                            ? Colors.blueGrey
                            : Colors.green,
                      ),
                    ),
                  )
                ],
              );
            }
            return Stack(
              children: [
                CircleAvatar(
                  backgroundImage:
                      NetworkImage("${chat!.chatFriend!.imageUrl!}"),
                  maxRadius: 25,
                ),
                Positioned(
                  bottom: 3,
                  right: 5,
                  child: ClipRRect(
                    borderRadius: BorderRadius.all(Radius.circular(200)),
                    child: Container(
                      width: 12,
                      height: 12,
                      color: Colors.blueGrey,
                    ),
                  ),
                )
              ],
            );
          }),
    );
  }

  Stream<List<Friends>> getFriendsData() async* {
    // Définissez la requête
    var friendsStream = FirebaseFirestore.instance
        .collection('Friends')
        .where(Filter.or(
          Filter('current_user_id', isEqualTo: authProvider.loginUserData.id!),
          Filter('friend_id', isEqualTo: authProvider.loginUserData.id!),
        ))
        .snapshots();

// Obtenez la liste des utilisateurs
    //List<DocumentSnapshot> users = await usersQuery.sget();
    List<Friends> friends = [];

    await for (var friendSnapshot in friendsStream) {
      for (var friendDoc in friendSnapshot.docs) {
        CollectionReference friendCollect =
            await FirebaseFirestore.instance.collection('Users');
        QuerySnapshot querySnapshotUser = await friendCollect
            .where("id",
                isEqualTo: authProvider.loginUserData.id ==
                        friendDoc["current_user_id"]
                    ? friendDoc["friend_id"]
                    : friendDoc["current_user_id"]!)
            .get();
        // Afficher la liste
        List<UserData> userList = querySnapshotUser.docs
            .map((doc) => UserData.fromJson(doc.data() as Map<String, dynamic>))
            .toList();
        //userData=userList.first;

        Friends friend;
        if (userList.first != null) {
          friend = Friends.fromJson(friendDoc.data());
          friend.friend = userList.first;
          if (friend.friend!.state == UserState.ONLINE.name) {
            friends.add(friend);
          }
        }
        listfirends = friends;
        // Map to store unique user names
        Map<String, Friends> uniqueUsers = {};

// Iterate through the user list
        for (Friends user in listfirends) {
          // Check if the name already exists in the map
          if (!uniqueUsers.containsKey(user.friend!.pseudo!)) {
            // Add unique user to the map
            uniqueUsers[user.friend!.pseudo!] = user;
          }
        }

// Access unique users from the map
        List<Friends> uniqueUserList = uniqueUsers.values.toList();

        friends = uniqueUserList;
        userProvider.countFriends = friends.length;
      }

      yield friends;
    }
  }

  void _showUserDetailsModalDialog(UserData user, double w, double h) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          content: DetailsOtherUser(
            user: user,
            w: w,
            h: h,
          ),
        );
      },
    );
  }

  Future<Chat> getChatsData(Friends amigo) async {
    // Définissez la requête
    var friendsStream = FirebaseFirestore.instance
        .collection('Chats')
        .where(Filter.or(
          Filter('docId', isEqualTo: '${amigo.friendId}${amigo.currentUserId}'),
          Filter('docId', isEqualTo: '${amigo.currentUserId}${amigo.friendId}'),
        ))
        .snapshots();

// Obtenez la liste des utilisateurs
    //List<DocumentSnapshot> users = await usersQuery.sget();
    Chat usersChat = Chat();

    if (await friendsStream.isEmpty) {
      printVm("pas de chat ");
      String chatId = FirebaseFirestore.instance.collection('Chats').doc().id;
      Chat chat = Chat(
        docId: '${amigo.friendId}${amigo.currentUserId}',
        id: chatId,
        senderId: authProvider.loginUserData.id == amigo.friendId
            ? '${amigo.friendId}'
            : '${amigo.currentUserId}',
        receiverId: authProvider.loginUserData.id == amigo.friendId
            ? '${amigo.currentUserId}'
            : '${amigo.friendId}',
        lastMessage: 'hi',

        type: ChatType.USER.name,
        createdAt: DateTime.now()
            .millisecondsSinceEpoch, // Get current time in milliseconds
        updatedAt: DateTime.now().millisecondsSinceEpoch,
        // Optional: You can initialize sender and receiver with UserData objects, and messages with a list of Message objects
      );
      await FirebaseFirestore.instance
          .collection('Chats')
          .doc(chatId)
          .set(chat.toJson());
      usersChat = chat;
    } else {
      printVm("le chat existe  ");
      printVm("stream :${friendsStream}");
      usersChat = await friendsStream.first.then((value) async {
        printVm("stream value l :${value.docs.length}");
        if (value.docs.length <= 0) {
          printVm("pas de chat ");
          String chatId =
              FirebaseFirestore.instance.collection('Chats').doc().id;
          Chat chat = Chat(
            docId: '${amigo.friendId}${amigo.currentUserId}',
            id: chatId,
            senderId: authProvider.loginUserData.id == amigo.friendId
                ? '${amigo.friendId}'
                : '${amigo.currentUserId}',
            receiverId: authProvider.loginUserData.id == amigo.friendId
                ? '${amigo.currentUserId}'
                : '${amigo.friendId}',
            lastMessage: 'hi',

            type: ChatType.USER.name,
            createdAt: DateTime.now()
                .millisecondsSinceEpoch, // Get current time in milliseconds
            updatedAt: DateTime.now().millisecondsSinceEpoch,
            // Optional: You can initialize sender and receiver with UserData objects, and messages with a list of Message objects
          );
          await FirebaseFirestore.instance
              .collection('Chats')
              .doc(chatId)
              .set(chat.toJson());
          usersChat = chat;
          return chat;
        } else {
          return Chat.fromJson(value.docs.first.data());
        }
      });
      CollectionReference messageCollect =
          await FirebaseFirestore.instance.collection('Messages');
      QuerySnapshot querySnapshotMessage =
          await messageCollect.where("chat_id", isEqualTo: usersChat.id!).get();
      // Afficher la liste
      List<Message> messageList = querySnapshotMessage.docs
          .map((doc) => Message.fromJson(doc.data() as Map<String, dynamic>))
          .toList();

      if (messageList.isEmpty) {
        usersChat.messages = [];
        userProvider.chat = usersChat;
        printVm("messgae vide ");
      } else {
        printVm("have messages");
        usersChat.messages = messageList;
        userProvider.chat = usersChat;
      }

      /////////////ami//////////
      CollectionReference friendCollect =
          await FirebaseFirestore.instance.collection('Users');
      QuerySnapshot querySnapshotUserSender = await friendCollect
          .where("id",
              isEqualTo: authProvider.loginUserData.id == amigo.friendId
                  ? '${amigo.friendId}'
                  : '${amigo.currentUserId}')
          .get();
      // Afficher la liste
      QuerySnapshot querySnapshotUserReceiver = await friendCollect
          .where("id",
              isEqualTo: authProvider.loginUserData.id == amigo.friendId
                  ? '${amigo.currentUserId}'
                  : '${amigo.friendId}')
          .get();

      List<UserData> receiverUserList = querySnapshotUserReceiver.docs
          .map((doc) => UserData.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
      usersChat.receiver = receiverUserList.first;

      List<UserData> senderUserList = querySnapshotUserSender.docs
          .map((doc) => UserData.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
      usersChat.sender = senderUserList.first;
    }

    return usersChat;
  }

  Widget Monami(Friends amigo) {
    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;
    return Container(
      padding: EdgeInsets.only(left: 16, right: 16, top: 10, bottom: 10),
      child: StreamBuilder<UserData>(
          stream: userProvider.getStreamUser(
              authProvider.loginUserData.id == amigo.currentUserId
                  ? amigo!.friendId!
                  : amigo.currentUserId!),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return Stack(
                children: [
                  GestureDetector(
                    onTap: () {
                      // Navigator.push(context, PageTransition(type: PageTransitionType.fade, child: ChatScreen(currentUserData: authProvider.loginUserData!, secondUser: snapshot.data![index]!.friend!)));
                      getChatsData(amigo!).then(
                        (chat) async {
                          userProvider.chat.messages = chat.messages;

                          Navigator.push(
                              context,
                              PageTransition(
                                  type: PageTransitionType.fade,
                                  child: MyChat(
                                    title: 'mon chat',
                                    chat: chat,
                                  )));
                        },
                      );

                      //  Navigator.pushNamed(context, '/basic_chat');
                    },
                    child: CircleAvatar(
                      backgroundImage:
                          NetworkImage("${amigo!.friend!.imageUrl!}"),
                      maxRadius: 28,
                    ),
                  ),
                  Positioned(
                    bottom: 12,
                    right: 3,
                    child: ClipRRect(
                      borderRadius: BorderRadius.all(Radius.circular(200)),
                      child: Container(
                        width: 12,
                        height: 12,
                        color: amigo.friend!.state == UserState.ONLINE.name
                            ? Colors.green
                            : Colors.blueGrey,
                      ),
                    ),
                  )
                ],
              );
            }
            return Stack(
              children: [
                GestureDetector(
                  onTap: () {
                    // Navigator.push(context, PageTransition(type: PageTransitionType.fade, child: ChatScreen(currentUserData: authProvider.loginUserData!, secondUser: snapshot.data![index]!.friend!)));
                    getChatsData(amigo!).then(
                      (chat) async {
                        userProvider.chat.messages = chat.messages;

                        Navigator.push(
                            context,
                            PageTransition(
                                type: PageTransitionType.fade,
                                child: MyChat(
                                  title: 'mon chat',
                                  chat: chat,
                                )));
                      },
                    );

                    //  Navigator.pushNamed(context, '/basic_chat');
                  },
                  child: CircleAvatar(
                    backgroundImage:
                        NetworkImage("${amigo!.friend!.imageUrl!}"),
                    maxRadius: 28,
                  ),
                ),
                Positioned(
                  bottom: 12,
                  right: 3,
                  child: ClipRRect(
                    borderRadius: BorderRadius.all(Radius.circular(200)),
                    child: Container(
                      width: 12,
                      height: 12,
                      color: Colors.blueGrey,
                    ),
                  ),
                )
              ],
            );
          }),
    );
  }

  late List<Chat> listChatsSearch = [];
  Future<void> searchListDialogue(
      BuildContext context, double h, double w, List<Chat> chats) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Liste de Conversations'),
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
                    child: SearchableList<Chat>(
                      initialList: chats,
                      // builder: (displayedList, itemIndex, chat) =>
                      //     GestureDetector(
                      //         onTap: () async {
                      //           CollectionReference friendCollect =
                      //               await FirebaseFirestore.instance
                      //                   .collection('Messages');
                      //           QuerySnapshot querySnapshotUser =
                      //               await friendCollect
                      //                   .where("chat_id", isEqualTo: chat.docId)
                      //                   .get();
                      //           // Afficher la liste
                      //           List<Message> messages = querySnapshotUser.docs
                      //               .map((doc) => Message.fromJson(
                      //                   doc.data() as Map<String, dynamic>))
                      //               .toList();
                      //           //snapshot.data![index].messages=messages;
                      //           userProvider.chat.messages = messages;
                      //           Navigator.of(context).pop();
                      //           Navigator.push(
                      //               context,
                      //               PageTransition(
                      //                   type: PageTransitionType.fade,
                      //                   child: MyChat(
                      //                     title: 'mon chat',
                      //                     chat: chat,
                      //                   )));
                      //
                      //           //  Navigator.pushNamed(context, '/basic_chat');
                      //         },
                      //         child: chatWidget(chat)),
                      filter: (value) => chats
                          .where(
                            (element) => element.chatFriend!.pseudo!
                                .toLowerCase()
                                .contains(value.toLowerCase()),
                          )
                          .toList(),
                      emptyWidget: Container(
                        child: Text('Conversations'),
                      ),
                      inputDecoration: InputDecoration(
                        labelText: "Amis",
                        fillColor: Colors.white,
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(
                            color: Colors.blue,
                            width: 1.0,
                          ),
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                      ),
                      itemBuilder: (Chat chat) =>
                          GestureDetector(
                              onTap: () async {
                                CollectionReference friendCollect =
                                await FirebaseFirestore.instance
                                    .collection('Messages');
                                QuerySnapshot querySnapshotUser =
                                await friendCollect
                                    .where("chat_id", isEqualTo: chat.docId)
                                    .get();
                                // Afficher la liste
                                List<Message> messages = querySnapshotUser.docs
                                    .map((doc) => Message.fromJson(
                                    doc.data() as Map<String, dynamic>))
                                    .toList();
                                //snapshot.data![index].messages=messages;
                                userProvider.chat.messages = messages;
                                Navigator.of(context).pop();
                                Navigator.push(
                                    context,
                                    PageTransition(
                                        type: PageTransitionType.fade,
                                        child: MyChat(
                                          title: 'mon chat',
                                          chat: chat,
                                        )));

                                //  Navigator.pushNamed(context, '/basic_chat');
                              },
                              child: chatWidget(chat)),
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
              child: Text('Fermer'),
            ),
          ],
        );
      },
    );
  }

  Stream<List<Chat>> getAllChatsData() async* {
    // Définissez la requête
    var chatsStream = FirebaseFirestore.instance
        .collection('Chats')
        .where(Filter.or(
          Filter('receiver_id', isEqualTo: '${authProvider.loginUserData.id}'),
          Filter('sender_id', isEqualTo: '${authProvider.loginUserData.id}'),
        ))
        .where("type", isEqualTo: ChatType.USER.name)
        .orderBy('updated_at', descending: true)
        .snapshots();

// Obtenez la liste des utilisateurs
    //List<DocumentSnapshot> users = await usersQuery.sget();
    Chat usersChat = Chat();
    List<Chat> listChats = [];

    await for (var chatSnapshot in chatsStream) {
      for (var chatDoc in chatSnapshot.docs) {
        CollectionReference friendCollect =
            await FirebaseFirestore.instance.collection('Users');
        QuerySnapshot querySnapshotUser = await friendCollect
            .where("id",
                isEqualTo:
                    authProvider.loginUserData.id == chatDoc["receiver_id"]
                        ? chatDoc["sender_id"]
                        : chatDoc["receiver_id"]!)
            .get();
        // Afficher la liste
        List<UserData> userList = querySnapshotUser.docs
            .map((doc) => UserData.fromJson(doc.data() as Map<String, dynamic>))
            .toList();
        //userData=userList.first;

        if (userList.isNotEmpty) {
          usersChat = Chat.fromJson(chatDoc.data());
          usersChat.chatFriend = userList.first;
          usersChat.receiver = userList.first;

          listChats.add(usersChat);
        }
        listChatsSearch = listChats;
      }
      yield listChats;
      listChats = [];
    }
  }

  @override
  Widget build(BuildContext context) {
    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;
    return Scaffold(
      appBar: AppBar(
        //backgroundColor: Colors.blue,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Logo(),
          )
        ],
        //title: Text(widget.title),
      ),
      body: ListView(
        // crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SafeArea(
            child: Padding(
              padding: EdgeInsets.only(left: 16, right: 16, top: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    "Conversations",
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.pushNamed(context, '/amis');
                    },
                    child: Container(
                      padding:
                          EdgeInsets.only(left: 8, right: 8, top: 2, bottom: 2),
                      height: 30,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        color: ConstColors.buttonsColors,
                      ),
                      child: Row(
                        children: <Widget>[
                          Icon(
                            Icons.add,
                            color: Colors.blue,
                            size: 20,
                          ),
                          SizedBox(
                            width: 2,
                          ),
                          Text(
                            "Amis",
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  )
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(top: 16, left: 16, right: 16),
            child: TextField(
              onTap: () {
                searchListDialogue(
                    context, height * 0.6, width * 0.8, listChatsSearch);
              },
              readOnly: true,
              cursorColor: kPrimaryColor,
              decoration: InputDecoration(
                focusColor: ConstColors.buttonColors,
                focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: kPrimaryColor)),
                hintText: "Recherche...",
                hintStyle: TextStyle(color: Colors.grey.shade600),
                prefixIcon: Icon(
                  Icons.search,
                  color: Colors.grey.shade600,
                  size: 20,
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding: EdgeInsets.all(8),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(color: Colors.grey.shade100)),
              ),
            ),
          ),
          Divider(),
          Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: Text(
              "Enligne",
              style: TextStyle(color: Colors.green),
            ),
          ),
          StreamBuilder<List<Friends>>(
            //initialData: [],
            stream: getFriendsData()!,

            // key: _formKey,

            builder: (context, AsyncSnapshot<List<Friends>> snapshot) {
              if (snapshot.hasData) {
                List<Friends>? friends = snapshot.data;
                if (friends!.isEmpty) {
                  return Container();
                } else {
                  return SizedBox(
                    height: height * 0.1,
                    width: width,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: snapshot.data!.length,

                      shrinkWrap: true,
                      // padding: EdgeInsets.only(top: 16),
                      itemBuilder: (context, index) {
                        return Monami(snapshot.data![index]!);
                      },
                    ),
                  );
                }
              } else if (snapshot.hasError) {
                printVm("${snapshot.error}");
                return Center(
                  child: Column(
                    children: [
                      Image.asset(
                        'assets/images/404.png',
                        height: 200,
                        width: 200,
                      ),
                      Text(
                        "Erreurs lors du chargement",
                        style: TextStyle(color: Colors.red),
                      ),
                      TextButton(
                        child: Text(
                          'Réessayer',
                          style: TextStyle(color: Colors.green),
                        ),
                        onPressed: () {
                          setState(() {});
                          // Réessayez de charger la page.
                        },
                      ),
                    ],
                  ),
                );
              } else {
                // Utiliser les données de snapshot.data

                return Skeletonizer(
                  //enabled: _loading,
                  child: Column(
                    children: [
                      Container(
                        padding: EdgeInsets.only(
                            left: 16, right: 16, top: 10, bottom: 10),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: Row(
                                children: <Widget>[
                                  CircleAvatar(
                                    backgroundImage:
                                        AssetImage("assets/images/404.png"),
                                    maxRadius: 30,
                                  ),
                                  SizedBox(
                                    width: 16,
                                  ),
                                  Expanded(
                                    child: Container(
                                      color: Colors.transparent,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: <Widget>[
                                          Text(
                                            "amigo!.friend!.pseudo!",
                                            style: TextStyle(fontSize: 16),
                                          ),
                                          SizedBox(
                                            height: 6,
                                          ),
                                          Text(
                                            ' abonne(s)',
                                            style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey.shade600,
                                                fontWeight: FontWeight.normal),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    Icons.send_sharp,
                                    color: Colors.green,
                                  )
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.only(
                            left: 16, right: 16, top: 10, bottom: 10),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: Row(
                                children: <Widget>[
                                  CircleAvatar(
                                    backgroundImage:
                                        AssetImage("assets/images/404.png"),
                                    maxRadius: 30,
                                  ),
                                  SizedBox(
                                    width: 16,
                                  ),
                                  Expanded(
                                    child: Container(
                                      color: Colors.transparent,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: <Widget>[
                                          Text(
                                            "amigo!.friend!.pseudo!",
                                            style: TextStyle(fontSize: 16),
                                          ),
                                          SizedBox(
                                            height: 6,
                                          ),
                                          Text(
                                            ' abonne(s)',
                                            style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey.shade600,
                                                fontWeight: FontWeight.normal),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    Icons.send_sharp,
                                    color: Colors.green,
                                  )
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.only(
                            left: 16, right: 16, top: 10, bottom: 10),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: Row(
                                children: <Widget>[
                                  CircleAvatar(
                                    backgroundImage:
                                        AssetImage("assets/images/404.png"),
                                    maxRadius: 30,
                                  ),
                                  SizedBox(
                                    width: 16,
                                  ),
                                  Expanded(
                                    child: Container(
                                      color: Colors.transparent,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: <Widget>[
                                          Text(
                                            "amigo!.friend!.pseudo!",
                                            style: TextStyle(fontSize: 16),
                                          ),
                                          SizedBox(
                                            height: 6,
                                          ),
                                          Text(
                                            ' abonne(s)',
                                            style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey.shade600,
                                                fontWeight: FontWeight.normal),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    Icons.send_sharp,
                                    color: Colors.green,
                                  )
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.only(
                            left: 16, right: 16, top: 10, bottom: 10),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: Row(
                                children: <Widget>[
                                  CircleAvatar(
                                    backgroundImage:
                                        AssetImage("assets/images/404.png"),
                                    maxRadius: 30,
                                  ),
                                  SizedBox(
                                    width: 16,
                                  ),
                                  Expanded(
                                    child: Container(
                                      color: Colors.transparent,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: <Widget>[
                                          Text(
                                            "amigo!.friend!.pseudo!",
                                            style: TextStyle(fontSize: 16),
                                          ),
                                          SizedBox(
                                            height: 6,
                                          ),
                                          Text(
                                            ' abonne(s)',
                                            style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey.shade600,
                                                fontWeight: FontWeight.normal),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    Icons.send_sharp,
                                    color: Colors.green,
                                  )
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.only(
                            left: 16, right: 16, top: 10, bottom: 10),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: Row(
                                children: <Widget>[
                                  CircleAvatar(
                                    backgroundImage:
                                        AssetImage("assets/images/404.png"),
                                    maxRadius: 30,
                                  ),
                                  SizedBox(
                                    width: 16,
                                  ),
                                  Expanded(
                                    child: Container(
                                      color: Colors.transparent,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: <Widget>[
                                          Text(
                                            "amigo!.friend!.pseudo!",
                                            style: TextStyle(fontSize: 16),
                                          ),
                                          SizedBox(
                                            height: 6,
                                          ),
                                          Text(
                                            ' abonne(s)',
                                            style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey.shade600,
                                                fontWeight: FontWeight.normal),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    Icons.send_sharp,
                                    color: Colors.green,
                                  )
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
          Divider(),
          StreamBuilder<List<Chat>>(
            //initialData: [],
            stream: getAllChatsData()!,

            // key: _formKey,

            builder: (context, AsyncSnapshot<List<Chat>> snapshot) {
              if (snapshot.hasData) {
                return ListView.builder(
                  scrollDirection: Axis.vertical,
                  itemCount: snapshot.data!.length,
                  shrinkWrap: true,
                  padding: EdgeInsets.only(top: 16),
                  physics: NeverScrollableScrollPhysics(),
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      onTap: () async {
                        CollectionReference friendCollect =
                            await FirebaseFirestore.instance
                                .collection('Messages');
                        QuerySnapshot querySnapshotUser = await friendCollect
                            .where("chat_id",
                                isEqualTo: snapshot.data![index].docId)
                            .get();
                        // Afficher la liste
                        List<Message> messages = querySnapshotUser.docs
                            .map((doc) => Message.fromJson(
                                doc.data() as Map<String, dynamic>))
                            .toList();
                        //snapshot.data![index].messages=messages;
                        userProvider.chat.messages = messages;
                        Navigator.push(
                            context,
                            PageTransition(
                                type: PageTransitionType.fade,
                                child: MyChat(
                                  title: 'mon chat',
                                  chat: snapshot.data![index],
                                )));

                        //  Navigator.pushNamed(context, '/basic_chat');
                      },
                      child: chatWidget(snapshot.data![index]!),
                    );
                  },
                );
              } else if (snapshot.hasError) {
                printVm("erreur ${snapshot.error}");
                return Center(
                  child: Column(
                    children: [
                      Image.asset(
                        'assets/images/404.png',
                        height: 200,
                        width: 200,
                      ),
                      Text(
                        "Erreurs lors du chargement",
                        style: TextStyle(color: Colors.red),
                      ),
                      TextButton(
                        child: Text(
                          'Réessayer',
                          style: TextStyle(color: Colors.green),
                        ),
                        onPressed: () {
                          setState(() {});
                          // Réessayez de charger la page.
                        },
                      ),
                    ],
                  ),
                );
              } else {
                // Utiliser les données de snapshot.data

                return Skeletonizer(
                  //enabled: _loading,
                  child: Column(
                    children: [
                      Container(
                        padding: EdgeInsets.only(
                            left: 16, right: 16, top: 10, bottom: 10),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: Row(
                                children: <Widget>[
                                  CircleAvatar(
                                    backgroundImage:
                                        AssetImage("assets/images/404.png"),
                                    maxRadius: 25,
                                  ),
                                  SizedBox(
                                    width: 16,
                                  ),
                                  Expanded(
                                    child: Container(
                                      color: Colors.transparent,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: <Widget>[
                                          Text(
                                            "amigo!.friend!.pseudo!",
                                            style: TextStyle(fontSize: 16),
                                          ),
                                          SizedBox(
                                            height: 6,
                                          ),
                                          Text(
                                            ' abonne(s)',
                                            style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey.shade600,
                                                fontWeight: FontWeight.normal),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    Icons.send_sharp,
                                    color: Colors.green,
                                  )
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.only(
                            left: 16, right: 16, top: 10, bottom: 10),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: Row(
                                children: <Widget>[
                                  CircleAvatar(
                                    backgroundImage:
                                        AssetImage("assets/images/404.png"),
                                    maxRadius: 25,
                                  ),
                                  SizedBox(
                                    width: 16,
                                  ),
                                  Expanded(
                                    child: Container(
                                      color: Colors.transparent,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: <Widget>[
                                          Text(
                                            "amigo!.friend!.pseudo!",
                                            style: TextStyle(fontSize: 16),
                                          ),
                                          SizedBox(
                                            height: 6,
                                          ),
                                          Text(
                                            ' abonne(s)',
                                            style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey.shade600,
                                                fontWeight: FontWeight.normal),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    Icons.send_sharp,
                                    color: Colors.green,
                                  )
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.only(
                            left: 16, right: 16, top: 10, bottom: 10),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: Row(
                                children: <Widget>[
                                  CircleAvatar(
                                    backgroundImage:
                                        AssetImage("assets/images/404.png"),
                                    maxRadius: 25,
                                  ),
                                  SizedBox(
                                    width: 16,
                                  ),
                                  Expanded(
                                    child: Container(
                                      color: Colors.transparent,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: <Widget>[
                                          Text(
                                            "amigo!.friend!.pseudo!",
                                            style: TextStyle(fontSize: 16),
                                          ),
                                          SizedBox(
                                            height: 6,
                                          ),
                                          Text(
                                            ' abonne(s)',
                                            style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey.shade600,
                                                fontWeight: FontWeight.normal),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    Icons.send_sharp,
                                    color: Colors.green,
                                  )
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.only(
                            left: 16, right: 16, top: 10, bottom: 10),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: Row(
                                children: <Widget>[
                                  CircleAvatar(
                                    backgroundImage:
                                        AssetImage("assets/images/404.png"),
                                    maxRadius: 25,
                                  ),
                                  SizedBox(
                                    width: 16,
                                  ),
                                  Expanded(
                                    child: Container(
                                      color: Colors.transparent,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: <Widget>[
                                          Text(
                                            "amigo!.friend!.pseudo!",
                                            style: TextStyle(fontSize: 16),
                                          ),
                                          SizedBox(
                                            height: 6,
                                          ),
                                          Text(
                                            ' abonne(s)',
                                            style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey.shade600,
                                                fontWeight: FontWeight.normal),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    Icons.send_sharp,
                                    color: Colors.green,
                                  )
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.only(
                            left: 16, right: 16, top: 10, bottom: 10),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: Row(
                                children: <Widget>[
                                  CircleAvatar(
                                    backgroundImage:
                                        AssetImage("assets/images/404.png"),
                                    maxRadius: 25,
                                  ),
                                  SizedBox(
                                    width: 16,
                                  ),
                                  Expanded(
                                    child: Container(
                                      color: Colors.transparent,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: <Widget>[
                                          Text(
                                            "amigo!.friend!.pseudo!",
                                            style: TextStyle(fontSize: 16),
                                          ),
                                          SizedBox(
                                            height: 6,
                                          ),
                                          Text(
                                            ' abonne(s)',
                                            style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey.shade600,
                                                fontWeight: FontWeight.normal),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    Icons.send_sharp,
                                    color: Colors.green,
                                  )
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
    );
  }
}

class ConversationList extends StatefulWidget {
  String name;
  String messageText;
  String imageUrl;
  String time;
  bool isMessageRead;
  ConversationList(
      {required this.name,
      required this.messageText,
      required this.imageUrl,
      required this.time,
      required this.isMessageRead});
  @override
  _ConversationListState createState() => _ConversationListState();
}

class _ConversationListState extends State<ConversationList> {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(left: 16, right: 16, top: 10, bottom: 10),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Row(
              children: <Widget>[
                CircleAvatar(
                  backgroundImage: NetworkImage(widget.imageUrl),
                  maxRadius: 30,
                ),
                SizedBox(
                  width: 16,
                ),
                Expanded(
                  child: Container(
                    color: Colors.transparent,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          widget.name,
                          style: TextStyle(fontSize: 16),
                        ),
                        SizedBox(
                          height: 6,
                        ),
                        Text(
                          widget.messageText,
                          style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                              fontWeight: widget.isMessageRead
                                  ? FontWeight.bold
                                  : FontWeight.normal),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Text(
            widget.time,
            style: TextStyle(
                fontSize: 12,
                fontWeight:
                    widget.isMessageRead ? FontWeight.bold : FontWeight.normal),
          ),
        ],
      ),
    );
  }
}
