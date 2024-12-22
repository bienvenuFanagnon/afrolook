

import 'package:chewie/chewie.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../../../models/chatmodels/message.dart';
import '../../../models/model_data.dart';
import '../../../providers/authProvider.dart';
import '../../../providers/postProvider.dart';
import '../../../providers/userProvider.dart';
import '../../component/consoleWidget.dart';

class VideoWidget extends StatefulWidget {

  final Post post;

  const VideoWidget({Key? key, required this.post}) : super(key: key);

  @override
  _VideoWidgetState createState() => _VideoWidgetState();
}

class _VideoWidgetState extends State<VideoWidget> {
  late VideoPlayerController videoPlayerController;
  late Future<void> _initializeVideoPlayerFuture;
  late ChewieController _chewieController;

  bool _buttonEnabled = true;



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

  videoInit() async {
    videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(widget.post.url_media!));


    _initializeVideoPlayerFuture = videoPlayerController.initialize().then((_) {
      // setState(() {
      //
      // });

    });

     _chewieController = ChewieController(
      videoPlayerController: videoPlayerController,
      autoPlay: true,
      looping: true,

    );
    _chewieController.play();

  }
  Future<void> videoInit2() async {
    // Initialisation du contrôleur vidéo
    videoPlayerController = VideoPlayerController.networkUrl(
      Uri.parse(widget.post.url_media!),
    );

    try {
      // Attendez l'initialisation complète du contrôleur vidéo
      // await videoPlayerController.initialize();
      _initializeVideoPlayerFuture =  videoPlayerController.initialize();
      // Configurez le contrôleur Chewie après l'initialisation
      _chewieController = ChewieController(
        videoPlayerController: videoPlayerController,
        autoPlay: true,
        looping: true,
      );

      // Facultatif : démarrez la lecture immédiatement
      _chewieController.play();

      // Appelle `setState` pour refléter les modifications
      setState(() {});
    } catch (e) {
      // Gérer les erreurs d'initialisation
      debugPrint('Erreur lors de l\'initialisation du lecteur vidéo : $e');
    }
  }

  @override
  void initState() {
    // videoPlayerController = VideoPlayerController.contentUri(Uri.parse(widget.post.url_media!));
    //
    // _initializeVideoPlayerFuture = videoPlayerController.initialize().then((_) {
    //
    // });
    //
    // videoPlayerController.setLooping(true);
    // videoPlayerController.play();

    videoInit();

    super.initState();


  }

  @override
  void dispose() {
    // videoPlayerController.pause();
    videoPlayerController.dispose();
    _chewieController.dispose();
    super.dispose();
    // videoPlayerController.pause();
    // videoPlayerController.dispose();
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
              printVm('Contact léger détecté 1!');
              bool isReady=true;
              ////// update view video /////
              // if (widget.post!.type==PostType.PUB.name) {
              //
              //   if (_buttonEnabled) {
              //     _buttonEnabled = false;
              //
              //       if (widget.post!.type==PostType.PUB.name) {
              //         if (!isIn(widget.post!.users_vue_id!,authProvider.loginUserData.id!)) {
              //
              //
              //         }else{
              //
              //           widget.post!.users_vue_id!.add(authProvider!.loginUserData.id!);
              //         }
              //
              //           widget.post!.vues=widget.post!.vues!+1;
              //
              //
              //
              //         // vue=datas[index]!.vues!;
              //
              //
              //         postProvider.updateVuePost(widget.post!,context);
              //         //loves.add(idUser);
              //
              //
              //
              //         // }
              //       }
              //       _buttonEnabled = true;
              //
              //   }  else{
              //     printVm('indispo!');
              //   }
              // }

            },
            child: GestureDetector(
              onTap: () {
                printVm('tap tap taptap');
                if (videoPlayerController.value.isPlaying) {
                  printVm('pause 1!');
                  _chewieController.pause();
                  // videoPlayerController.pause();

                } else {

                  _chewieController.play();
                  // videoPlayerController.play();

                  printVm('play 1!');
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
                          printVm('on tap tap');
                        },
                        // child:VideoPlayer(
                        //     key: new PageStorageKey(widget.post.url_media!),
                        //     videoPlayerController
                        // )

                      child:  Chewie(
                          key: new PageStorageKey(widget.post.url_media!),
                          controller: _chewieController,

                        ),


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