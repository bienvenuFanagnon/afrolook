import 'dart:convert';

import 'package:afrotok/models/chatmodels/message.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:afrotok/models/chatmodels/models.dart';
import 'package:afrotok/models/chatmodels/reply_message.dart';
import 'package:afrotok/models/model_data.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as Path;

import 'package:chat_bubbles/chat_bubbles.dart';
import 'package:audioplayers/audioplayers.dart';
import "package:cached_network_image/cached_network_image.dart";
import 'package:flutter_list_view/flutter_list_view.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:io';
import '../../constant/constColors.dart';
import '../../constant/sizeText.dart';
import '../../constant/textCustom.dart';
import '../../providers/authProvider.dart';
import '../../providers/userProvider.dart';
import 'package:image_picker/image_picker.dart';

import '../user/detailsOtherUser.dart';

class MyChat extends StatefulWidget {
  final String title;
  final Chat chat;
  MyChat({Key? key, required this.title, required this.chat}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyChat> with WidgetsBindingObserver,TickerProviderStateMixin{
  late bool replying = false;
  late String replyingTo = '';
  //late List<Widget> actions;
  late TextEditingController _textController = TextEditingController();
  AudioPlayer audioPlayer = new AudioPlayer();
  Duration duration = new Duration();
  Duration position = new Duration();
  bool isPlaying = false;
  bool isLoading = false;
  bool isPause = false;
  bool fileDownloading = false;
  bool sendMessageTap = false;
  double siveBoxLastmessage = 10;
  ScrollController _controller = ScrollController();
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  /// Declare
  FlutterListViewController fluttercontroller = FlutterListViewController();

  File? _image;
  // ignore: unused_field
  PickedFile? _pickedFile;
  final _picker = ImagePicker();

  String? getStringImage(File? file) {
    if (file == null) return null;
    return base64Encode(file.readAsBytesSync());
  }

  Future getImage() async {
    // ignore: deprecated_member_use, no_leading_underscores_for_local_identifiers
    final _pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (_pickedFile != null) {
      setState(() {
        _image = File(_pickedFile.path);
      });
    }
  }

  FocusNode _focusNode = FocusNode();

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

  String formaterDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays < 1) {
      // Si c'est le même jour
      if (difference.inHours < 1) {
        // Si moins d'une heure
        if (difference.inMinutes < 1) {
          return " il y a quelques secondes";
        } else {
          return " il y a ${difference.inMinutes} minutes";
        }
      } else {
        return " il y a ${difference.inHours} heures";
      }
    } else if (difference.inDays < 7) {
      // Si la semaine n'est pas passée
      return " ${difference.inDays} jours plus tôt";
    } else {
      // Si le jour est passé
      return " depuis ${DateFormat('dd MMMM yyyy').format(dateTime)}";
    }
  }

  Stream<List<Message>> getMessageData() async* {
    // Définissez la requête
    var friendsStream = FirebaseFirestore.instance
        .collection('Messages')
        .where('chat_id', isEqualTo: widget.chat.docId!)
        .orderBy('createdAt', descending: false)
        .snapshots();

// Obtenez la liste des utilisateurs
    //List<DocumentSnapshot> users = await usersQuery.sget();
    List<Message> listmessage = [];

    await for (var friendSnapshot in friendsStream) {
      listmessage = friendSnapshot.docs
          .map((doc) => Message.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
      userProvider.chat.messages = listmessage;

      _controller = ScrollController(
          initialScrollOffset: userProvider.chat.messages!.length * 5000);

      yield listmessage;
    }
  }

  @override
  void initState() {
    // TODO: implement initState

    WidgetsBinding.instance.addObserver(this);

    super.initState();
  //  WidgetsBinding.instance.addPostFrameCallback((_) {});

    SystemChannels.lifecycle.setMessageHandler((message) {


      if (message!.contains('resume')) {
        //online
        print('state en ligne chat:  --- ${message}');
 }  else{
        print('state hors chat ligne :  --- ${message}');
        if (widget.chat.senderId == authProvider.loginUserData.id!) {
          //  widget.chat.receiver_sending=false;

          widget.chat.send_sending = IsSendMessage.NOTSENDING.name;

          print('state hors chat ligne update chat sender');

          firestore
              .collection('Chats')
              .doc(widget.chat.id)
              .update(widget.chat!.toJson());
        } else {
          widget.chat.receiver_sending = IsSendMessage.NOTSENDING.name;

          //widget.chat.send_sending=false;
          print('state hors chat ligne update chat receiver');

          firestore
              .collection('Chats')
              .doc(widget.chat.id)
              .update(widget.chat!.toJson());
        }
 }
      return Future.value(message);
    },);


    widget.chat.senderId != authProvider.loginUserData.id!
        ? widget.chat.your_msg_not_read = 0
        : widget.chat.my_msg_not_read = 0;

    firestore
        .collection('Chats')
        .doc(widget.chat.id)
        .update(widget.chat!.toJson());
    _controller = ScrollController(
        initialScrollOffset: userProvider.chat.messages == null
            ? 5000000
            : userProvider.chat.messages!.length + 5000);
  }

  late UserAuthProvider authProvider =
      Provider.of<UserAuthProvider>(context, listen: false);
  late UserProvider userProvider =
      Provider.of<UserProvider>(context, listen: false);
  Widget listBubble() {
    return Column(
      children: <Widget>[
        /*
        BubbleNormalImage(
          id: 'id001',
          image: _image(),
          color: Colors.purpleAccent,
          tail: true,
          delivered: true,
          isSender: true,
        ),

         */
        BubbleNormalAudio(
          color: Color(0xFFE8E8EE),
          duration: duration.inSeconds.toDouble(),
          position: position.inSeconds.toDouble(),
          isPlaying: isPlaying,
          isLoading: isLoading,
          isPause: isPause,
          onSeekChanged: _changeSeek,
          onPlayPauseButtonClick: _playAudio,
          sent: true,
          isSender: true,
        ),
        BubbleSpecialOne(
          text: 'bubble special one with tail',
          isSender: false,
          color: Color(0xFF1B97F3),
          textStyle: TextStyle(
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        DateChip(
          date: new DateTime.now(),
        ),
        BubbleSpecialOne(
          text: 'bubble special one with tail',
          color: Color(0xFFE8E8EE),
          seen: true,
          isSender: true,
        ),
        DateChip(
          date: new DateTime.now(),
        ),
        BubbleSpecialOne(
          text: 'bubble special one with tail',
          isSender: false,
          color: Color(0xFF1B97F3),
          textStyle: TextStyle(
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        DateChip(
          date: new DateTime.now(),
        ),
        BubbleSpecialOne(
          text: 'bubble special one with tail',
          color: Color(0xFFE8E8EE),
          seen: true,
        ),
        DateChip(
          date: new DateTime.now(),
        ),
        BubbleSpecialOne(
          text: 'bubble special one with tail',
          isSender: false,
          color: Color(0xFF1B97F3),
          textStyle: TextStyle(
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        DateChip(
          date: new DateTime.now(),
        ),
        BubbleSpecialOne(
          text: 'bubble special one with tail',
          color: Color(0xFFE8E8EE),
          seen: true,
        ),
        BubbleSpecialOne(
          text: 'bubble special one with tail',
          isSender: false,
          color: Color(0xFF1B97F3),
          textStyle: TextStyle(
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        DateChip(
          date: new DateTime.now(),
        ),
        BubbleSpecialOne(
          text: 'bubble special one with tail',
          color: Color(0xFFE8E8EE),
          seen: true,
        ),
        SizedBox(
          height: 100,
        )
      ],
    );
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

  @override
  void dispose() {
    // TODO: implement dispose
    if (widget.chat.senderId == authProvider.loginUserData.id!) {
      //  widget.chat.receiver_sending=false;

      widget.chat.send_sending = IsSendMessage.NOTSENDING.name;
      print('dispose update chat sender');

      firestore
          .collection('Chats')
          .doc(widget.chat.id)
          .update(widget.chat!.toJson());
    } else {
      widget.chat.receiver_sending = IsSendMessage.NOTSENDING.name;

      //widget.chat.send_sending=false;
      print('dispose update chat reicever');

      firestore
          .collection('Chats')
          .doc(widget.chat.id)
          .update(widget.chat!.toJson());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;
/*
    if (_controller.hasClients) {
      _controller.animateTo(
        _controller.position.maxScrollExtent*15,
        duration: Duration(seconds: 2),
        curve: Curves.fastOutSlowIn,
      );
    }

 */
    final now = new DateTime.now();
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: StreamBuilder<UserData>(
                  stream: userProvider.getStreamUser(widget.chat.receiver!.id!),
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      return GestureDetector(
                        onTap: () {
                          _showUserDetailsModalDialog(
                              snapshot.data!, width, height);
                        },
                        child: Stack(
                          children: [
                            CircleAvatar(
                              backgroundImage:
                                  NetworkImage("${snapshot.data!.imageUrl!}"),
                              //maxRadius: 30,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 2,
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
                            ),
                          ],
                        ),
                      );
                    }
                    return Stack(
                      children: [
                        CircleAvatar(
                          backgroundImage: NetworkImage(
                              "${widget.chat.receiver!.imageUrl!}"),
                          // maxRadius: 30,
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
            ),
            SizedBox(
              height: 2,
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  //width: 100,
                  child: TextCustomerUserTitle(
                    titre: "@${widget.chat.receiver!.pseudo}",
                    fontSize: SizeText.homeProfileTextSize,
                    couleur: ConstColors.textColors,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                StreamBuilder<Chat>(
                    stream: userProvider.getStreamChat(widget.chat.id!),
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        Chat chat=snapshot!.data!;
                       // print("update chat: ${chat.toJson()}");

                        if (authProvider.loginUserData.id ==
                            chat!.senderId) {
                          return chat!.receiver_sending==IsSendMessage.SENDING.name
                              ? TextCustomerUserTitle(
                                  titre: "écrit...",
                                  fontSize: SizeText.homeProfileTextSize,
                                  couleur: Colors.green,
                                  fontWeight: FontWeight.w400,
                                )
                              : TextCustomerUserTitle(
                                  titre:
                                      "${formatNumber(widget.chat.receiver!.abonnes!)} abonné(s)",
                                  fontSize: SizeText.homeProfileTextSize,
                                  couleur: ConstColors.textColors,
                                  fontWeight: FontWeight.w400,
                                );
                        } else  if (authProvider.loginUserData.id ==
                            chat!.receiverId) {
                          return chat!.send_sending==IsSendMessage.SENDING.name
                              ? TextCustomerUserTitle(
                                  titre: "écrit...",
                                  fontSize: SizeText.homeProfileTextSize,
                                  couleur: Colors.green,
                                  fontWeight: FontWeight.w400,
                                )
                              : TextCustomerUserTitle(
                                  titre:
                                      "${formatNumber(widget.chat.receiver!.abonnes!)} abonné(s)",
                                  fontSize: SizeText.homeProfileTextSize,
                                  couleur: ConstColors.textColors,
                                  fontWeight: FontWeight.w400,
                                );
                        }else{
                          return TextCustomerUserTitle(
                            titre:
                            "${formatNumber(widget.chat.receiver!.abonnes!)} abonné(s)",
                            fontSize: SizeText.homeProfileTextSize,
                            couleur: ConstColors.textColors,
                            fontWeight: FontWeight.w400,
                          );

                        }
                      }else{
                        return TextCustomerUserTitle(
                          titre:
                          "${formatNumber(widget.chat.receiver!.abonnes!)} abonné(s)",
                          fontSize: SizeText.homeProfileTextSize,
                          couleur: ConstColors.textColors,
                          fontWeight: FontWeight.w400,
                        );

                      }
                    }),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
              onPressed: () {
                _controller.animateTo(
                  _controller.position.maxScrollExtent * 34,
                  duration: Duration(milliseconds: 800),
                  curve: Curves.fastOutSlowIn,
                );
              },
              icon: Icon(Icons.arrow_downward_rounded, color: Colors.green))
        ],
      ),
      body: Column(
        children: [
          Expanded(
            //flex: 8,

            child: Padding(
              padding: const EdgeInsets.only(bottom: 0.0, top: 0),
              child: StreamBuilder<List<Message>>(
                stream: getMessageData(),
                builder: (context, snapshot) {
                  _controller = ScrollController(
                      initialScrollOffset:
                          userProvider.chat.messages!.length + 5000);
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return ListView.builder(
                        //reverse: true,

                        controller: _controller,
                        scrollDirection: Axis.vertical,
                        itemCount: userProvider.chat.messages!
                            .length, // Nombre d'éléments dans la liste
                        itemBuilder: (context, index) {
                          bool isLastItem =
                              index == userProvider.chat.messages!.length - 1;

                          // Déterminer la hauteur de SizedBox en fonction de la condition
                          double sizedBoxHeight = isLastItem ? 20.0 : 0.0;
                          List<Message> list = userProvider.chat.messages!;
                          return list[index].messageType ==
                                  MessageType.text.name
                              ? Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  crossAxisAlignment: list[index].sendBy ==
                                          authProvider.loginUserData.id!
                                      ? CrossAxisAlignment.end
                                      : CrossAxisAlignment.start,
                                  children: [
                                    BubbleSpecialOne(
                                      text: '${list[index].message}',
                                      isSender: list[index].sendBy ==
                                              authProvider.loginUserData.id!
                                          ? true
                                          : false,
                                      color: list[index].sendBy ==
                                              authProvider.loginUserData.id!
                                          ? ConstColors.meMessageColors
                                          : Color(0xFFE8E8EE),
                                      textStyle: TextStyle(
                                        fontSize: 15,
                                        color: list[index].sendBy ==
                                                authProvider.loginUserData.id!
                                            ? Colors.white
                                            : Colors.black,
                                      ),
                                    ),
                                    Padding(
                                      padding: list[index].sendBy ==
                                              authProvider.loginUserData.id!
                                          ? const EdgeInsets.only(
                                              right: 20.0, bottom: 20)
                                          : const EdgeInsets.only(
                                              left: 20.0, bottom: 20),
                                      child: Column(
                                        children: [
                                          Icon(
                                            MaterialCommunityIcons.check_all,
                                            size: 8,
                                            color: Colors.black,
                                          ),
                                          Text(
                                            "${formaterDateTime(DateTime.fromMillisecondsSinceEpoch(list[index].create_at_time_spam))}",
                                            style: TextStyle(fontSize: 8),
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(
                                      height: isLastItem ? 200 : 0.0,
                                    ),
                                  ],
                                )
                              : list[index].messageType ==
                                      MessageType.image.name
                                  ? BubbleNormalImage(
                                      id: 'id001',
                                      image: _imageUrl(list[index].message),
                                      color: Colors.purpleAccent,
                                      tail: true,
                                      delivered: true,
                                      isSender: list[index].sendBy ==
                                              authProvider.loginUserData.id!
                                          ? true
                                          : false,
                                    )
                                  : list[index].messageType == MessageType.voice
                                      ? BubbleNormalAudio(
                                          color: Color(0xFFE8E8EE),
                                          duration:
                                              duration.inSeconds.toDouble(),
                                          position:
                                              position.inSeconds.toDouble(),
                                          isPlaying: isPlaying,
                                          isLoading: isLoading,
                                          isPause: isPause,
                                          onSeekChanged: _changeSeek,
                                          onPlayPauseButtonClick: _playAudio,
                                          sent: true,
                                          isSender: list[index].sendBy ==
                                                  authProvider.loginUserData.id!
                                              ? true
                                              : false,
                                        )
                                      : BubbleSpecialOne(
                                          text: '${list[index].message}',
                                          isSender: list[index].sendBy ==
                                                  authProvider.loginUserData.id!
                                              ? true
                                              : false,
                                          color: list[index].sendBy ==
                                                  authProvider.loginUserData.id!
                                              ? ConstColors.meMessageColors
                                              : Color(0xFFE8E8EE),
                                          textStyle: TextStyle(
                                            fontSize: 15,
                                            color: list[index].sendBy ==
                                                    authProvider
                                                        .loginUserData.id!
                                                ? Colors.white
                                                : Colors.black,
                                          ),
                                        );
                        });
                  } else if (snapshot.hasError) {
                    return Center(
                        child: Container(
                            width: 50,
                            height: 50,
                            child: CircularProgressIndicator()));
                  } else if (snapshot.hasData) {
                    List<Message> list = snapshot.data!;
                    print("message lenght: ${list.length}");

                    userProvider.chat.messages = list;
                    // Utiliser les données de snapshot.data
                    return ListView.builder(
                        //reverse: true,

                        controller: _controller,
                        scrollDirection: Axis.vertical,
                        itemCount: snapshot
                            .data!.length, // Nombre d'éléments dans la liste
                        itemBuilder: (context, index) {
                          if (authProvider.loginUserData.id !=
                              list[index]!.sendBy) {
                            if (list[index]!.message_state !=
                                MessageState.LU.name) {
                              list[index]!.message_state = MessageState.LU.name;
                              firestore
                                  .collection('Messages')
                                  .doc(list[index].id)
                                  .update(list[index]!.toJson());
                            }
                          }

                          bool isLastItem = index == snapshot.data!.length - 1;

                          // Déterminer la hauteur de SizedBox en fonction de la condition
                          double sizedBoxHeight = isLastItem ? 20.0 : 0.0;
                          //list[index].userAbonnes=[];
                          return list[index].messageType ==
                                  MessageType.text.name
                              ? Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  crossAxisAlignment: list[index].sendBy ==
                                          authProvider.loginUserData.id!
                                      ? CrossAxisAlignment.end
                                      : CrossAxisAlignment.start,
                                  children: [
                                    list[index].replyMessage.message.length > 0
                                        ? BubbleNormal(
                                            text:
                                                'Re: ${list[index].replyMessage.message}',
                                            isSender: list[index].sendBy ==
                                                    authProvider
                                                        .loginUserData.id!
                                                ? true
                                                : false,
                                            color: list[index].sendBy ==
                                                    authProvider
                                                        .loginUserData.id!
                                                ? ConstColors.buttonsColors
                                                : Color(0xfff3fdf8),
                                            textStyle: TextStyle(
                                              fontSize: 10,
                                              color: Colors.blue,
                                            ),
                                          )
                                        : Container(),
                                    Row(
                                      mainAxisAlignment: list[index].sendBy ==
                                              authProvider.loginUserData.id!
                                          ? MainAxisAlignment.end
                                          : MainAxisAlignment.start,
                                      children: [
                                        list[index].sendBy ==
                                                authProvider.loginUserData.id!
                                            ? IconButton(
                                                onPressed: () {
                                                  replying = true;
                                                  replyingTo =
                                                      list[index].message;
                                                  setState(() {});
                                                },
                                                icon: Icon(
                                                  Icons.reply,
                                                  color: Colors.blue,
                                                  size: 15,
                                                ),
                                              )
                                            : Container(),
                                        BubbleSpecialOne(
                                          text: '${list[index].message}',
                                          isSender: list[index].sendBy ==
                                                  authProvider.loginUserData.id!
                                              ? true
                                              : false,
                                          color: list[index].sendBy ==
                                                  authProvider.loginUserData.id!
                                              ? ConstColors.meMessageColors
                                              : Color(0xFFE8E8EE),
                                          textStyle: TextStyle(
                                            fontSize: 15,
                                            color: list[index].sendBy ==
                                                    authProvider
                                                        .loginUserData.id!
                                                ? Colors.white
                                                : Colors.black,
                                          ),
                                        ),
                                        list[index].sendBy !=
                                                authProvider.loginUserData.id!
                                            ? Transform.rotate(
                                                angle: 45 * 3.141592653 / 1,
                                                child: IconButton(
                                                  onPressed: () {
                                                    replying = true;
                                                    replyingTo =
                                                        list[index].message;
                                                    setState(() {});
                                                  },
                                                  icon: Icon(
                                                    Icons.reply,
                                                    color: Colors.blue,
                                                    size: 15,
                                                  ),
                                                ),
                                              )
                                            : Container(),
                                      ],
                                    ),
                                    Padding(
                                      padding: list[index].sendBy ==
                                              authProvider.loginUserData.id!
                                          ? const EdgeInsets.only(
                                              right: 20.0, bottom: 20)
                                          : const EdgeInsets.only(
                                              left: 20.0, bottom: 20),
                                      child: Column(
                                        children: [
                                          Icon(
                                            MaterialCommunityIcons.check_all,
                                            size: 15,
                                            color: list[index]!.message_state ==
                                                    MessageState.LU.name
                                                ? Colors.blue
                                                : Colors.black,
                                          ),
                                          Text(
                                            "${formaterDateTime(DateTime.fromMillisecondsSinceEpoch(list[index].create_at_time_spam))}",
                                            style: TextStyle(fontSize: 8),
                                          ),
                                        ],
                                        crossAxisAlignment: list[index]
                                                    .sendBy ==
                                                authProvider.loginUserData.id!
                                            ? CrossAxisAlignment.end
                                            : CrossAxisAlignment.start,
                                      ),
                                    ),
                                    SizedBox(
                                      height: isLastItem ? 200 : 0.0,
                                    ),
                                  ],
                                )
                              : list[index].messageType ==
                                      MessageType.image.name
                                  ? Column(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      crossAxisAlignment: list[index].sendBy ==
                                              authProvider.loginUserData.id!
                                          ? CrossAxisAlignment.end
                                          : CrossAxisAlignment.start,
                                      children: [
                                        BubbleNormalImage(
                                          id: '${list[index].id!}',
                                          image: _imageUrl(list[index].message),
                                          color: Colors.blue,
                                          tail: true,
                                          /*
                                delivered: true,
                                sent: true,
                                seen:list[index]!.message_state==MessageState.LU.name? true:false,
                               */
                                          isSender: list[index].sendBy ==
                                                  authProvider.loginUserData.id!
                                              ? true
                                              : false,
                                        ),
                                        Padding(
                                          padding: list[index].sendBy ==
                                                  authProvider.loginUserData.id!
                                              ? const EdgeInsets.only(
                                                  right: 20.0, bottom: 20)
                                              : const EdgeInsets.only(
                                                  left: 20.0, bottom: 20),
                                          child: Column(
                                            children: [
                                              Icon(
                                                MaterialCommunityIcons
                                                    .check_all,
                                                size: 15,
                                                color: list[index]!
                                                            .message_state ==
                                                        MessageState.LU.name
                                                    ? Colors.blue
                                                    : Colors.black,
                                              ),
                                              Text(
                                                "${formaterDateTime(DateTime.fromMillisecondsSinceEpoch(list[index].create_at_time_spam))}",
                                                style: TextStyle(fontSize: 8),
                                              ),
                                            ],
                                            crossAxisAlignment:
                                                list[index].sendBy ==
                                                        authProvider
                                                            .loginUserData.id!
                                                    ? CrossAxisAlignment.end
                                                    : CrossAxisAlignment.start,
                                          ),
                                        ),
                                        SizedBox(
                                          height: isLastItem ? 200 : 0.0,
                                        ),
                                      ],
                                    )
                                  : list[index].messageType == MessageType.voice
                                      ? BubbleNormalAudio(
                                          color: Color(0xFFE8E8EE),
                                          duration:
                                              duration.inSeconds.toDouble(),
                                          position:
                                              position.inSeconds.toDouble(),
                                          isPlaying: isPlaying,
                                          isLoading: isLoading,
                                          isPause: isPause,
                                          onSeekChanged: _changeSeek,
                                          onPlayPauseButtonClick: _playAudio,
                                          sent: true,
                                          isSender: list[index].sendBy ==
                                                  authProvider.loginUserData.id!
                                              ? true
                                              : false,
                                        )
                                      : BubbleSpecialOne(
                                          text: '${list[index].message}',
                                          isSender: list[index].sendBy ==
                                                  authProvider.loginUserData.id!
                                              ? true
                                              : false,
                                          color: list[index].sendBy ==
                                                  authProvider.loginUserData.id!
                                              ? ConstColors.meMessageColors
                                              : Color(0xFFE8E8EE),
                                          textStyle: TextStyle(
                                            fontSize: 15,
                                            color: list[index].sendBy ==
                                                    authProvider
                                                        .loginUserData.id!
                                                ? Colors.white
                                                : Colors.black,
                                          ),
                                        );
                        });
                  } else {
                    return Center(
                        child: Container(
                            width: 50,
                            height: 50,
                            child: CircularProgressIndicator()));
                  }
                },
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  replying
                      ? Container(
                          color: const Color(0xffF4F4F5),
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 16,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.reply,
                                color: Colors.blue,
                                size: 24,
                              ),
                              Expanded(
                                child: Container(
                                  child: Text(
                                    'Re : ' + replyingTo,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              InkWell(
                                onTap: () {
                                  //onTapCloseReply
                                  replyingTo = "";
                                  replying = false;
                                  setState(() {});
                                },
                                child: Icon(
                                  Icons.close,
                                  color: Colors.black12,
                                  size: 24,
                                ),
                              ),
                            ],
                          ))
                      : Container(),
                  replying
                      ? Container(
                          height: 1,
                          color: Colors.grey.shade300,
                        )
                      : Container(),
                  Container(
                    color: const Color(0xffF4F4F5),
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 16,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        /*
                        InkWell(
                          child: Icon(
                            Icons.keyboard_voice_outlined,
                            color: Colors.black,
                            size: 24,
                          ),
                          onTap: () {},
                        ),

                         */
                        Padding(
                          padding: EdgeInsets.only(left: 8, right: 8),
                          child: InkWell(
                            child: Icon(
                              Icons.camera_alt,
                              color: Colors.green,
                              size: 24,
                            ),
                            onTap: () {
                              _textController.text = "";
                              getImage();
                            },
                          ),
                        ),
                        _image != null
                            ? Visibility(
                                visible: _image == null ? false : true,
                                child: fileDownloading
                                    ? Container(
                                        height: 70,
                                        width: 70,
                                        child: CircularProgressIndicator())
                                    : Container(
                                        alignment: Alignment.center,
                                        // height: 200,
                                        //width: largeur,
                                        child: Stack(
                                          children: [
                                            Container(
                                              height: 85,
                                              width: 85,
                                              decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.all(
                                                          Radius.circular(200)),
                                                  border: Border.all(
                                                      width: 3,
                                                      color: ConstColors
                                                          .buttonsColors)),
                                              child: ClipRRect(
                                                borderRadius: BorderRadius.all(
                                                    Radius.circular(200)),
                                                child: Container(
                                                  height: 80,
                                                  width: 80,
                                                  child: Padding(
                                                      padding:
                                                          const EdgeInsets.all(
                                                              4.0),
                                                      child: _image == null
                                                          ? CircleAvatar(
                                                              backgroundImage:
                                                                  AssetImage(
                                                                'assets/icon/user-removebg-preview.png',
                                                              ),
                                                            )
                                                          : CircleAvatar(
                                                              foregroundImage:
                                                                  FileImage(
                                                                File(_image!
                                                                    .path),
                                                              ),
                                                              backgroundImage:
                                                                  AssetImage(
                                                                'assets/icon/user-removebg-preview.png',
                                                              ),
                                                            )),
                                                ),
                                              ),
                                            ),
                                            Positioned(
                                              top: 0,
                                              right: -12,
                                              child: Container(
                                                alignment: Alignment.center,
                                                child: Center(
                                                    child: IconButton(
                                                  onPressed: () async {
                                                    // selectedImagePath = await _pickImage();
                                                    setState(() {
                                                      _image = null;
                                                    });
                                                  },
                                                  icon: Icon(
                                                    Icons.delete_forever,
                                                    size: 30,
                                                    color: Colors.red,
                                                  ),
                                                )),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                              )
                            : Expanded(
                                child: Container(
                                  child: TextFormField(
                                    focusNode: _focusNode,
                                    onChanged: (text) async {
                                      Chat streamChat=widget.chat!;
                                      if (text.isNotEmpty) {

                                        if (streamChat.senderId ==
                                            authProvider.loginUserData.id!) {

                                            streamChat.send_sending = IsSendMessage.SENDING.name;
                                            print('textEdit update chat sender');

                                            firestore
                                                .collection('Chats')
                                                .doc(streamChat.id)
                                                .update(streamChat!.toJson());



                                        }
                                        if (streamChat.receiverId ==
                                            authProvider.loginUserData.id!) {



                                            streamChat.receiver_sending = IsSendMessage.SENDING.name;
                                            print('textEdit update chat receiver');

                                            firestore
                                                .collection('Chats')
                                                .doc(streamChat.id)
                                                .update(streamChat!.toJson());

                                        }

                                      }
                                      /*
                                      else {


                                        if (streamChat.senderId ==
                                            authProvider.loginUserData.id!) {



                                            streamChat.send_sending = IsSendMessage.NOTSENDING.name;
                                            print('empty textEdit update chat sender');

                                            firestore
                                                .collection('Chats')
                                                .doc(streamChat.id)
                                                .update(streamChat!.toJson());

                                        }
                                        if (streamChat.receiverId ==
                                            authProvider.loginUserData.id!)  {

                                            streamChat.receiver_sending = IsSendMessage.NOTSENDING.name;
                                            print('empty textEdit update chat receiver');

                                            firestore
                                                .collection('Chats')
                                                .doc(streamChat.id)
                                                .update(streamChat!.toJson());


                                        }

                                      }

                                       */

                                    },
                                    onTap: () async {
                                      _image = null;

                                      _controller.animateTo(
                                        _controller.position.maxScrollExtent *
                                            34,
                                        duration: Duration(milliseconds: 800),
                                        curve: Curves.fastOutSlowIn,
                                      );
                                      print("tap");
                                    },
                                    controller: _textController,
                                    keyboardType: TextInputType.multiline,
                                    textCapitalization:
                                        TextCapitalization.sentences,
                                    minLines: 1,
                                    maxLines: 3,
                                    style: const TextStyle(color: Colors.black),
                                    decoration: InputDecoration(
                                      hintText: "message...",
                                      hintMaxLines: 1,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 8.0, vertical: 10),
                                      hintStyle: const TextStyle(fontSize: 16),
                                      fillColor: Colors.white,
                                      filled: true,
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(30.0),
                                        borderSide: const BorderSide(
                                          color: Colors.white,
                                          width: 0.2,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(30.0),
                                        borderSide: const BorderSide(
                                          color: Colors.black26,
                                          width: 0.2,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                        Padding(
                          padding: const EdgeInsets.only(left: 16),
                          child: InkWell(
                            child: Icon(
                              Icons.send,
                              color: Colors.green,
                              size: 24,
                            ),
                            onTap: sendMessageTap
                                ? () {}
                                : () async {
                                    print("send tap;");
                                    sendMessageTap = true;

                                    if (_image != null) {
                                      try {
                                        setState(() {
                                          fileDownloading = true;
                                        });
                                        Reference storageReference =
                                            FirebaseStorage.instance.ref().child(
                                                'user_profile/${Path.basename(_image!.path)}');
                                        UploadTask uploadTask =
                                            storageReference.putFile(_image!);
                                        await uploadTask.whenComplete(() {
                                          storageReference
                                              .getDownloadURL()
                                              .then((fileURL) async {
                                            print("url photo1");
                                            print(fileURL);

                                            authProvider.registerUser.imageUrl =
                                                fileURL;
                                            final id = userProvider
                                                    .usermessageList.length +
                                                1;
                                            ReplyMessage reply = ReplyMessage(
                                                message: replyingTo,
                                                messageType:
                                                    MessageType.text.name);

                                            Message msg = Message(
                                              id: id.toString(),
                                              createdAt: DateTime.now(),
                                              message: fileURL,
                                              // sendBy: authProvider.loginUserData.id!.toString(),
                                              sendBy:
                                                  '${authProvider.loginUserData.id!}',
                                              replyMessage: reply,
                                              // messageType:messageType==MessageType.text? MessageType.text:message.messageType==MessageType.image?MessageType.image:message.messageType==MessageType.voice?MessageType.voice:MessageType.custom,

                                              messageType:
                                                  MessageType.image.name,
                                              chat_id: widget.chat.docId!,
                                              create_at_time_spam:
                                                  DateTime.now()
                                                      .millisecondsSinceEpoch,
                                              message_state:
                                                  MessageState.NONLU.name,
                                              receiverBy:
                                                  widget.chat!.senderId ==
                                                          authProvider
                                                              .loginUserData.id!
                                                      ? widget.chat!.receiverId!
                                                      : widget.chat!.senderId!,
                                            );
                                            widget.chat.lastMessage = "image";
                                            widget.chat.senderId ==
                                                    authProvider
                                                        .loginUserData.id!
                                                ? widget.chat
                                                    .your_msg_not_read = widget
                                                        .chat
                                                        .your_msg_not_read! +
                                                    1
                                                : widget.chat.my_msg_not_read =
                                                    widget.chat
                                                            .my_msg_not_read! +
                                                        1;
                                            widget.chat.lastMessage = "image";
                                            _textController.text = '';

                                            String msgid = firestore
                                                .collection('Messages')
                                                .doc()
                                                .id;
                                            msg.setStatus =
                                                MessageStatus.undelivered;
                                            msg.id = msgid;
                                            msg.replyMessage = reply;
                                            await firestore
                                                .collection('Messages')
                                                .doc(msgid)
                                                .set(msg.toJson());
                                            widget.chat.updatedAt =
                                                DateTime.now()
                                                    .millisecondsSinceEpoch;
                                            await authProvider
                                                .getUserById(
                                                    widget.chat.receiver!.id!)
                                                .then(
                                              (users) async {
                                                if (users.isNotEmpty) {
                                                  if (users.first!
                                                              .oneIgnalUserid !=
                                                          null &&
                                                      users
                                                              .first!
                                                              .oneIgnalUserid!
                                                              .length >
                                                          5) {
                                                    await authProvider.sendNotification(
                                                        userIds: [
                                                          users.first!
                                                              .oneIgnalUserid!
                                                        ],
                                                        smallImage:
                                                            "${authProvider.loginUserData.imageUrl!}",
                                                        send_user_id:
                                                            "${authProvider.loginUserData.id!}",
                                                        recever_user_id:
                                                            "${widget.chat!.senderId == authProvider.loginUserData.id! ? widget.chat!.receiverId! : widget.chat!.senderId!}",
                                                        message:
                                                            "🗨️ @${authProvider.loginUserData.pseudo!} vous a envoyé un message",
                                                        type_notif:
                                                            NotificationType
                                                                .MESSAGE.name,
                                                        post_id: "",
                                                        post_type: "",
                                                        chat_id:
                                                            '${widget.chat.id!}');
                                                  }
                                                }
                                              },
                                            );

                                            await firestore
                                                .collection('Chats')
                                                .doc(widget.chat.id)
                                                .update(widget.chat!.toJson());
                                            _controller.animateTo(
                                              _controller.position
                                                      .maxScrollExtent *
                                                  500,
                                              duration:
                                                  Duration(milliseconds: 800),
                                              curve: Curves.fastOutSlowIn,
                                            );
                                            // _focusNode.unfocus();

                                            replyingTo = "";
                                            _image = null;

                                            replying = false;

                                            setState(() {
                                              fileDownloading = false;

                                              sendMessageTap = false;
                                            });
                                          });
                                        });
                                      } on FirebaseException catch (error) {
                                        print("error code: ${error.message}");
                                        print(
                                            "error message : ${error.message}");
                                        setState(() {
                                          sendMessageTap = false;
                                        });
                                      }
                                    } else if (_textController.text.length >
                                        0) {
                                      try {
                                        final id = userProvider
                                                .usermessageList.length +
                                            1;
                                        ReplyMessage reply = ReplyMessage(
                                            message: replyingTo,
                                            messageType: MessageType.text.name);

                                        Message msg = Message(
                                          id: id.toString(),
                                          createdAt: DateTime.now(),
                                          message: _textController.text,
                                          // sendBy: authProvider.loginUserData.id!.toString(),
                                          sendBy:
                                              '${authProvider.loginUserData.id!}',
                                          replyMessage: reply,
                                          // messageType:messageType==MessageType.text? MessageType.text:message.messageType==MessageType.image?MessageType.image:message.messageType==MessageType.voice?MessageType.voice:MessageType.custom,

                                          messageType: MessageType.text.name,
                                          chat_id: widget.chat.docId!,
                                          create_at_time_spam: DateTime.now()
                                              .millisecondsSinceEpoch,
                                          message_state:
                                              MessageState.NONLU.name,
                                          receiverBy: widget.chat!.senderId ==
                                                  authProvider.loginUserData.id!
                                              ? widget.chat!.receiverId!
                                              : widget.chat!.senderId!,
                                        );
                                        widget.chat.lastMessage =
                                            _textController.text;
                                        widget.chat.senderId ==
                                                authProvider.loginUserData.id!
                                            ? widget.chat.your_msg_not_read =
                                                widget.chat.your_msg_not_read! +
                                                    1
                                            : widget.chat.my_msg_not_read =
                                                widget.chat.my_msg_not_read! +
                                                    1;
                                        widget.chat.lastMessage =
                                            _textController.text;
                                        _textController.text = '';

                                        String msgid = firestore
                                            .collection('Messages')
                                            .doc()
                                            .id;
                                        msg.setStatus =
                                            MessageStatus.undelivered;
                                        msg.id = msgid;
                                        msg.replyMessage = reply;
                                        await firestore
                                            .collection('Messages')
                                            .doc(msgid)
                                            .set(msg.toJson());
                                        widget.chat.updatedAt = DateTime.now()
                                            .millisecondsSinceEpoch;
                                        await authProvider
                                            .getUserById(
                                                widget.chat.receiver!.id!)
                                            .then(
                                          (users) async {
                                            if (users.isNotEmpty) {
                                              if (users.first!.oneIgnalUserid !=
                                                      null &&
                                                  users.first!.oneIgnalUserid!
                                                          .length >
                                                      5) {
                                                await authProvider.sendNotification(
                                                    userIds: [
                                                      users.first!
                                                          .oneIgnalUserid!
                                                    ],
                                                    smallImage:
                                                        "${authProvider.loginUserData.imageUrl!}",
                                                    send_user_id:
                                                        "${authProvider.loginUserData.id!}",
                                                    recever_user_id:
                                                        "${widget.chat!.senderId == authProvider.loginUserData.id! ? widget.chat!.receiverId! : widget.chat!.senderId!}",
                                                    message:
                                                        "🗨️ @${authProvider.loginUserData.pseudo!} vous a envoyé un message",
                                                    type_notif: NotificationType
                                                        .MESSAGE.name,
                                                    post_id: "",
                                                    post_type: "",
                                                    chat_id:
                                                        '${widget.chat.id!}');
                                              }
                                            }
                                          },
                                        );

                                        if (widget.chat.senderId ==
                                            authProvider.loginUserData.id!) {



                                          widget.chat.send_sending = IsSendMessage.NOTSENDING.name;
                                          print('empty textEdit update chat sender');

                                          firestore
                                              .collection('Chats')
                                              .doc(widget.chat.id)
                                              .update(widget.chat!.toJson());

                                        }
                                        if (widget.chat.receiverId ==
                                            authProvider.loginUserData.id!)  {

                                          widget.chat.receiver_sending = IsSendMessage.NOTSENDING.name;
                                          print('empty textEdit update chat receiver');

                                          firestore
                                              .collection('Chats')
                                              .doc(widget.chat.id)
                                              .update(widget.chat!.toJson());


                                        }

                                        await firestore
                                            .collection('Chats')
                                            .doc(widget.chat.id)
                                            .update(widget.chat!.toJson());
                                        _controller.animateTo(
                                          _controller.position.maxScrollExtent *
                                              500,
                                          duration: Duration(milliseconds: 800),
                                          curve: Curves.fastOutSlowIn,
                                        );
                                        // _focusNode.unfocus();

                                        replyingTo = "";

                                        replying = false;
                                        setState(() {
                                          sendMessageTap = false;
                                        });
                                      } on FirebaseException catch (error) {
                                        print("error code: ${error.message}");
                                        print(
                                            "error message : ${error.message}");
                                        setState(() {
                                          sendMessageTap = false;
                                        });
                                      }
                                    }

                                    sendMessageTap = false;
                                  },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      // This trailing comma makes auto-formatting nicer for build methods.
    );
  }

  Widget _imageUrl(String url) {
    return Container(
      constraints: BoxConstraints(
        minHeight: 20.0,
        minWidth: 20.0,
      ),
      child: CachedNetworkImage(
        imageUrl: '${url}',
        progressIndicatorBuilder: (context, url, downloadProgress) =>
            LinearProgressIndicator(),
        //CircularProgressIndicator(value: downloadProgress.progress),
        errorWidget: (context, url, error) => const Icon(Icons.error),
      ),
    );
  }

  void _changeSeek(double value) {
    setState(() {
      audioPlayer.seek(new Duration(seconds: value.toInt()));
    });
  }

  void _playAudio() async {
    final url =
        'https://firebasestorage.googleapis.com/v0/b/afrolooki.appspot.com/o/Vexento-Spark.mp3?alt=media&token=6723f4b6-6cbd-4e22-8995-8f9dbd06c59f';
    if (isPause) {
      await audioPlayer.resume();
      setState(() {
        isPlaying = true;
        isPause = false;
      });
    } else if (isPlaying) {
      await audioPlayer.pause();
      setState(() {
        isPlaying = false;
        isPause = true;
      });
    } else {
      setState(() {
        isLoading = true;
      });
      await audioPlayer.play(UrlSource(url));
      setState(() {
        isPlaying = true;
      });
    }

    audioPlayer.onDurationChanged.listen((Duration d) {
      setState(() {
        print("duration ${d}");

        duration = d;
        isLoading = false;
      });
    });
    audioPlayer.onPositionChanged.listen((Duration p) {
      setState(() {
        position = p;
      });
    });
    audioPlayer.onPlayerComplete.listen((event) {
      setState(() {
        isPlaying = false;
        duration = new Duration();
        position = new Duration();
      });
    });
  }
}
