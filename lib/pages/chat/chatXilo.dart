



import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math';

import '../../models/chatmodels/message.dart';
import '../../models/model_data.dart';
import '../../providers/authProvider.dart';
import '../../providers/userProvider.dart';
import '../component/consoleWidget.dart';
import '../ia/compagnon/introIaCompagnon.dart';
import 'ia_Chat.dart';

class ChatXiloPage extends StatefulWidget {
  final String userName;
  final String userGender;

  ChatXiloPage({required this.userName, required this.userGender});

  @override
  _ChatXiloPageState createState() => _ChatXiloPageState();
}

class _ChatXiloPageState extends State<ChatXiloPage> {
  late String randomMessage;
  late UserAuthProvider authProvider =
  Provider.of<UserAuthProvider>(context, listen: false);
  late UserProvider userProvider =
  Provider.of<UserProvider>(context, listen: false);
  final List<String> maleMessages = [
    "Veux-tu savoir comment draguer une fille en 2025 ?",
    "Tu veux des conseils pour aborder une fille ?",
    "Tu veux discuter de l'actualité ?",
    "Tu veux parler de tes passions ?",
    "Tu veux échanger sur tes centres d'intérêt ?",
    "Tu veux discuter de tes projets ?",
    "Tu veux parler de tes objectifs ?",
    "Tu veux savoir comment séduire une fille ?",
    "Tu veux des astuces pour plaire à une fille ?",
    "Tu veux savoir comment attirer l'attention d'une fille ?",

  ];

  final List<String> femaleMessages = [
    "Veux-tu savoir comment draguer un garçon en 2025 ?",
    "Tu veux des conseils pour aborder un garçon ?",
    "Tu veux savoir comment séduire un garçon ?",
    "Tu veux discuter de l'actualité ?",
    "Tu veux parler de tes passions ?",
    "Tu veux échanger sur tes centres d'intérêt ?",
    "Tu veux des astuces pour plaire à un garçon ?",
    "Tu veux savoir comment attirer l'attention d'un garçon ?",
    "Tu veux discuter de l'actualité ?",
    "Tu veux parler de tes passions ?",
    "Tu veux échanger sur tes centres d'intérêt ?",
    "Tu veux discuter de tes projets ?",
    "Tu veux parler de tes objectifs ?",
  ];

  @override
  void initState() {
    super.initState();
    _generateRandomMessage();
  }

  void _generateRandomMessage() {
    femaleMessages.shuffle();
    maleMessages.shuffle();
    final random = Random();
    setState(() {
      randomMessage = (widget.userGender.toLowerCase() == 'femme'
          ? femaleMessages
          : maleMessages)[random.nextInt(widget.userGender.toLowerCase() == 'femme'
          ? femaleMessages.length
          : maleMessages.length)];
    });
  }
  Future<Chat> getIAChatsData(UserIACompte amigo) async {
    // Définissez la requête
    var friendsStream = FirebaseFirestore.instance
        .collection('Chats')
        .where(Filter.or(
      Filter('docId',
          isEqualTo: '${authProvider.loginUserData.id}${amigo.id}'),
      Filter('docId',
          isEqualTo: '${amigo.id}${authProvider.loginUserData.id}'),
    ))
        .snapshots();

// Obtenez la liste des utilisateurs
    //List<DocumentSnapshot> users = await usersQuery.sget();
    Chat usersChat = Chat();

    if (await friendsStream.isEmpty) {
      printVm("pas de chat ");
      String chatId = FirebaseFirestore.instance.collection('Chats').doc().id;
      Chat chat = Chat(
        docId: '${amigo.id}${authProvider.loginUserData.id}',
        id: chatId,
        senderId: '${authProvider.loginUserData.id}',
        receiverId: '${amigo.id}',
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
            docId: '${amigo.id}${authProvider.loginUserData.id}',
            id: chatId,
            senderId: '${authProvider.loginUserData.id}',
            receiverId: '${amigo.id}',
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
      /*
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

       */
    }

    return usersChat;
  }


  Widget _buildMessageBubble(String text, bool isXilo) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 4),
      alignment: isXilo ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isXilo ? Color(0xFFE3F2FD) : Color(0xFFFFF9C4),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomLeft: isXilo ? Radius.circular(0) : Radius.circular(20),
            bottomRight: isXilo ? Radius.circular(20) : Radius.circular(0),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: Colors.black87,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: 600),
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: 5,
                children: [
                  CircleAvatar(
                    radius: 15, // Taille de l'avatar
                    backgroundImage: AssetImage('assets/icon/X.png'),
                  ),
                  Text(
                  "Chat avec Xilo",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[800],
                  ),
                  textAlign: TextAlign.center,
                            ),
                ],
              ),
            SizedBox(height: 20),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildMessageBubble(
                        "Salut @${widget.userName}! Je suis Xilo, votre ami(e) et confident(e) sur AfroLook, prêt(e) à discuter et vous soutenir.",
                        true
                    ),
                    _buildMessageBubble(randomMessage, true),

                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Image.asset('assets/icon/amixilo2.png'),
                    )
                  ],
                ),
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                await authProvider.getAppData().then(
                      (appdata) async {
                    // Navigator.push(context, MaterialPageRoute(builder: (context) => IntroIaCompagnon(instruction:authProvider.appDefaultData.ia_instruction! ,),));

                    await authProvider
                        .getUserIa(authProvider.loginUserData.id!)
                        .then(
                          (value) async {
                        if (value.isNotEmpty) {
                          await getIAChatsData(value.first).then((chat) {

                            // Navigator.push(context, MaterialPageRoute(builder: (context) => GeminiTextChat(),));
                            // Navigator.push(context, MaterialPageRoute(builder: (context) => DeepSeepChat(instruction: '${authProvider.appDefaultData.ia_instruction!}'),));
                            // Navigator.push(context, MaterialPageRoute(builder: (context) => GeminiChatBot(title: 'BOT XILO', instruction: '${authProvider.appDefaultData.ia_instruction!}', userIACompte: value.first, apiKey:'${authProvider.appDefaultData.geminiapiKey!}' ,),));

                            Navigator.push(context, MaterialPageRoute(builder: (context) => IaChat(
                              chat: chat,
                              user: authProvider.loginUserData,
                              userIACompte: value.first,
                              instruction:
                              '${authProvider.appDefaultData.ia_instruction!}', appDefaultData: authProvider.appDefaultData,
                            ),
                            ));
                          });
                        } else {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => IntroIaCompagnon(
                                  instruction: authProvider
                                      .appDefaultData.ia_instruction!,
                                ),
                              ));
                        }
                      },
                    );
                  },
                );
              },
              child: Text("Discuter maintenant"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[800],
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}