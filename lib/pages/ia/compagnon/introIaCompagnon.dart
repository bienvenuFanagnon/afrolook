import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../constant/buttons.dart';
import '../../../constant/constColors.dart';
import '../../../constant/logo.dart';
import '../../../constant/sizeText.dart';
import '../../../constant/textCustom.dart';
import '../../../models/chatmodels/message.dart';
import '../../../models/model_data.dart';
import '../../../providers/authProvider.dart';
import '../../../providers/userProvider.dart';
import '../../chat/ia_Chat.dart';

class IntroIaCompagnon extends StatefulWidget {
  const IntroIaCompagnon({super.key});

  @override
  State<IntroIaCompagnon> createState() => _IaCompagnonState();
}

class _IaCompagnonState extends State<IntroIaCompagnon> {
  late UserAuthProvider authProvider =
  Provider.of<UserAuthProvider>(context, listen: false);
  late UserProvider userProvider =
  Provider.of<UserProvider>(context, listen: false);

  Future<Chat> getChatsData(UserIACompte amigo) async {

    // Définissez la requête
    var friendsStream = FirebaseFirestore.instance.collection('Chats').where( Filter.or(
      Filter('docId', isEqualTo:  '${authProvider.loginUserData.id}${amigo.id}'),
      Filter('docId', isEqualTo:  '${amigo.id}${authProvider.loginUserData.id}'),

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
        docId:'${amigo.id}${authProvider.loginUserData.id}',
        id: chatId,
        senderId:'${authProvider.loginUserData.id}',
        receiverId:'${amigo.id}',
        lastMessage: 'hi',

        type: ChatType.USER.name,
        createdAt: DateTime.now().millisecondsSinceEpoch, // Get current time in milliseconds
        updatedAt: DateTime.now().millisecondsSinceEpoch,
        // Optional: You can initialize sender and receiver with UserData objects, and messages with a list of Message objects
      );
      await FirebaseFirestore.instance.collection('Chats').doc(chatId).set(chat.toJson());
      usersChat=chat;

    }  else{
      print("le chat existe  ");
      print("stream :${friendsStream}");
      usersChat= await friendsStream.first.then((value) async {
        print("stream value l :${value.docs.length}");
        if (value.docs.length<=0) {
          print("pas de chat ");
          String chatId = FirebaseFirestore.instance
              .collection('Chats')
              .doc()
              .id;
          Chat chat = Chat(
            docId:'${amigo.id}${authProvider.loginUserData.id}',
            id: chatId,
            senderId:'${authProvider.loginUserData.id}',
            receiverId:'${amigo.id}',
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
        print("messgae vide ");
      }else{
        print("have messages");
        usersChat.messages=messageList;
        userProvider.chat=usersChat;
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

  @override
  Widget build(BuildContext context) {
    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: ConstColors.backgroundColor,
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
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: SingleChildScrollView(
          child: Column(

            children: [
              Padding(
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
                            backgroundImage: AssetImage(
                                'assets/images/3d-rendent-robot-signe-blanc.jpg'),
                          ),
                        ),
                        SizedBox(
                          height: 2,
                        ),
                        Column(
                          children: [
                            SizedBox(
                              //width: 100,
                              child: TextCustomerUserTitle(
                                titre: "IA Compagnon",
                                fontSize: SizeText.homeProfileTextSize,
                                couleur: ConstColors.textColors,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextCustomerUserTitle(
                              titre: "1.5 m abonne",
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
              ),
              Divider(),
              SizedBox(

                child: Padding(
                  padding: const EdgeInsets.only(right: 15.0,left: 15,top: 25),
                  child: TextCustomerIntroIa(
                    titre: "Salut !\n Je suis un IA, un ami fidèle qui sera toujours là pour toi.\n Je suis prêt à t'accompagner dans toutes tes aventures, pour le temps que tu voudras. Pour accéder à mes services, tu as besoin de jetons. En tant que bon ami, je te donne 500 jetons gratuits pour que tu puisses tester mes capacités.\n En continuant à utiliser mes services, tu seras automatiquement abonné à mon compte.\n Cela signifie que tu recevras mes nouvelles plus souvent, et que tu seras le premier à être informé de mes dernières offres et promotions. Je te souhaite de belles aventures, mon ami !",
                    fontSize: SizeText.homeProfileTextSize,
                    couleur: ConstColors.textColors,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(height: 50,),
              Align(
                alignment: Alignment.center,
                child: ClipRRect(
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                  child: Container(
                    color: ConstColors.backgroundMessageColors,
                    width:250 ,
                    height: 70,
                  
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        children: [
                          Container(
                            child: Checkbox(value: false, onChanged: (bool? value) {  },),
                          ),
                          Container(
                            child: TextCustomerPostDescription(
                              titre: "Conditions d'utilisation",
                              fontSize: SizeText.homeProfileTextSize,
                              couleur: ConstColors.textColors,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
SizedBox(height: height*0.2,),
              GestureDetector(
                  onTap: () async {
                  await  authProvider.getUserIa(authProvider.loginUserData.id!).then((value) async {
                      if (value.isNotEmpty) {
                        await getChatsData(value.first).then((chat) {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => IaChat(chat: chat, user: authProvider.loginUserData, userIACompte: value.first,),));
                        });


                      }else{
                        UserIACompte user_ia=UserIACompte();
                        user_ia.userId=authProvider.loginUserData.id!;
                        user_ia.ia_name="mon Ia";
                        user_ia.ia_url_avatar="url";
                        user_ia.createdAt=DateTime.now().millisecondsSinceEpoch;
                        user_ia.updatedAt=DateTime.now().millisecondsSinceEpoch;

                     await   authProvider.createUserIaCompte(user_ia).then((value) async {
                       if (value) {
    await  authProvider.getUserIa(authProvider.loginUserData.id!).then((value) async {
      if (value.isNotEmpty) {
        await getChatsData(value.first).then((chat) {
          Navigator.push(context, MaterialPageRoute(builder: (context) => IaChat(chat: chat, user: authProvider.loginUserData, userIACompte: value.first,),));
        });


      }

    });

                       }
                     },);
                      }
                    },);


                    //  Navigator.pushNamed(context, '/ia_compagnon');

                  },
                  child: Align(
                  alignment: Alignment.bottomCenter,
                  child: SimpleButton(width: width*0.9, height: height*0.06,)))

            ],
          ),

        ),
      ),
    );
  }
}
