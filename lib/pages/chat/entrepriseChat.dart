import 'package:afrotok/models/chatmodels/message.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:afrotok/models/chatmodels/models.dart';
import 'package:afrotok/models/chatmodels/reply_message.dart';
import 'package:afrotok/models/model_data.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_bubble/chat_bubble.dart';
import 'package:flutter/material.dart';
import 'package:chat_bubbles/chat_bubbles.dart';
import 'package:audioplayers/audioplayers.dart';
import "package:cached_network_image/cached_network_image.dart";
import 'package:flutter_list_view/flutter_list_view.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../constant/constColors.dart';
import '../../constant/sizeText.dart';
import '../../constant/textCustom.dart';
import '../../providers/authProvider.dart';
import '../../providers/userProvider.dart';
import '../component/consoleWidget.dart';
import '../postDetails.dart';

class EntrepriseMyChat extends StatefulWidget {

  final String title;
  final Chat chat;
  final Post post;
  final bool isEntreprise;
  EntrepriseMyChat({Key? key, required this.title, required this.chat, required this.post, required this.isEntreprise}) : super(key: key);

  @override
  _EntrepriseMyChatState createState() => _EntrepriseMyChatState();
}

class _EntrepriseMyChatState extends State<EntrepriseMyChat> {
  late  bool replying=false;
  late String replyingTo='';
  //late List<Widget> actions;
  late TextEditingController _textController = TextEditingController();
  AudioPlayer audioPlayer = new AudioPlayer();
  Duration duration = new Duration();
  Duration position = new Duration();
  bool isPlaying = false;
  bool isLoading = false;
  bool isPause = false;
  bool sendMessageTap = false;
  double siveBoxLastmessage=10;
  ScrollController _controller = ScrollController();
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  /// Declare
  FlutterListViewController fluttercontroller = FlutterListViewController();

  FocusNode _focusNode=FocusNode();

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

  Stream<List<Message>> getMessageData() async* {

    // Définissez la requête
    var friendsStream = FirebaseFirestore.instance.collection('Messages').where('chat_id', isEqualTo: widget.chat.docId!)
        .orderBy('createdAt', descending: false)
        .snapshots();

// Obtenez la liste des utilisateurs
    //List<DocumentSnapshot> users = await usersQuery.sget();
    List<Message> listmessage = [];



    await for (var friendSnapshot in friendsStream) {
      listmessage =  friendSnapshot.docs
          .map((doc) => Message.fromJson(
          doc.data() as Map<String, dynamic>))
          .toList();
      userProvider.chat.messages=listmessage;



      _controller = ScrollController(initialScrollOffset : userProvider.chat.messages!.length*5000);


      yield listmessage;
    }

  }
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_){

    });

    widget.chat.senderId!=authProvider.loginUserData.id!?widget.chat.your_msg_not_read=0:widget.chat.my_msg_not_read=0;

    firestore.collection('Chats').doc( widget.chat.id).update(  widget.chat!.toJson());
    _controller = ScrollController(initialScrollOffset : userProvider.chat.messages==null?5000000:userProvider.chat.messages!.length+5000);



  }
  int imageIndex=0;

  late UserAuthProvider authProvider =
  Provider.of<UserAuthProvider>(context, listen: false);
  late UserProvider userProvider =
  Provider.of<UserProvider>(context, listen: false);
  Widget listBubble(){
    return Column(
      children: <Widget>[
        BubbleNormalImage(
          id: 'id001',
          image: _image(),
          color: Colors.purpleAccent,
          tail: true,
          delivered: true,
          isSender: true,
        ),
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
              child: widget.isEntreprise!=true?   CircleAvatar(
                backgroundImage: NetworkImage("${widget.chat.entreprise!.urlImage!}"),
                //maxRadius: 30,
              ):CircleAvatar(
                backgroundImage: NetworkImage("${widget.chat.sender!.imageUrl!}"),
                //maxRadius: 30,
              ),
            ),
            SizedBox(
              height: 2,
            ),
       widget.isEntreprise==true? Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              //width: 100,
              child: TextCustomerUserTitle(
                titre: "@${widget.chat.sender!.pseudo!}",
                fontSize: SizeText.homeProfileTextSize,
                couleur: ConstColors.textColors,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextCustomerUserTitle(
              titre: "${formatNumber(widget.chat.sender!.abonnes!)} abonné(s)",

              fontSize: SizeText.homeProfileTextSize,
              couleur: ConstColors.textColors,
              fontWeight: FontWeight.w400,
            ),
          ],
        ): Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  //width: 100,
                  child: TextCustomerUserTitle(
                    titre: "#${widget.chat.entreprise!.titre}",
                    fontSize: SizeText.homeProfileTextSize,
                    couleur: ConstColors.textColors,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextCustomerUserTitle(
                  titre: "${formatNumber(widget.chat.entreprise!.suivi!)} suivi(s)",

                  fontSize: SizeText.homeProfileTextSize,
                  couleur: ConstColors.textColors,
                  fontWeight: FontWeight.w400,
                ),
              ],
            ),
          ],
        ),
        actions: [IconButton(onPressed: (){

          _controller.animateTo(
            _controller.position.maxScrollExtent*34,
            duration: Duration(milliseconds: 800),
            curve: Curves.fastOutSlowIn,
          );
        }, icon: Icon(Icons.arrow_downward_rounded,color: Colors.green))],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => DetailsPost(post: widget.post),));
            },
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                //width: width*0.8,
                height: 80,
                child: Padding(
                  padding: const EdgeInsets.all(6.0),
                  child: Container(
                    alignment: Alignment.center,
                    child: TextCustomerPostDescription(
                      titre:
                      "${widget.post.description}",
                      fontSize: SizeText.homeProfileTextSize,
                      couleur: ConstColors.textColors,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ),
          ),
          StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
                return widget.post!.images==null? Container():  Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [

                      for(int i=0;i<widget.post!.images!.length;i++)
                        TextButton(onPressed: ()
                        {
                          setState(() {
                            imageIndex=i;
                          });

                        }, child:
                        Container(
                          width: 100,
                          height: 50,

                          child: ClipRRect(
                            borderRadius: BorderRadius.all(Radius.circular(10)),
                            child: Container(

                              child: CachedNetworkImage(

                                fit: BoxFit.cover,
                                imageUrl: '${widget.post!.images![i]}',
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
                );
              }
          ),

          Divider(),
          Expanded(
            //flex: 8,

            child: Padding(
              padding: const EdgeInsets.only(bottom: 0.0,top: 0),
              child: StreamBuilder<List<Message>>(

                stream: getMessageData(),
                builder: (context, snapshot) {

                  _controller = ScrollController(initialScrollOffset : userProvider.chat.messages!.length+5000);
                  if (snapshot.connectionState == ConnectionState.waiting) {

                    return ListView.builder(
                      //reverse: true,

                        controller: _controller,
                        scrollDirection: Axis.vertical,
                        itemCount: userProvider.chat.messages!.length, // Nombre d'éléments dans la liste
                        itemBuilder: (context, index) {

                          bool isLastItem = index == userProvider.chat.messages!.length - 1;

                          // Déterminer la hauteur de SizedBox en fonction de la condition
                          double sizedBoxHeight = isLastItem ? 20.0 : 0.0;
                          List<Message> list=userProvider.chat.messages!;
                          return list[index].messageType==MessageType.text.name? Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            crossAxisAlignment:list[index].sendBy==authProvider.loginUserData.id!? CrossAxisAlignment.end:CrossAxisAlignment.start,
                            children: [
                              BubbleSpecialOne(

                                text: '${list[index].message}',
                                isSender:list[index].sendBy==authProvider.loginUserData.id!?true: false,
                                color:list[index].sendBy==authProvider.loginUserData.id!? ConstColors.meMessageColors:Color(0xFFE8E8EE),
                                textStyle: TextStyle(
                                  fontSize: 15,
                                  color:list[index].sendBy==authProvider.loginUserData.id!? Colors.white: Colors.black,
                                ),
                              ),
                              Padding(
                                padding: list[index].sendBy==authProvider.loginUserData.id!? const EdgeInsets.only(right: 20.0,bottom: 20):const EdgeInsets.only(left: 20.0,bottom: 20),
                                child: Text("${formaterDateTime(DateTime.fromMillisecondsSinceEpoch(list[index].create_at_time_spam))}",style: TextStyle(fontSize: 8),),
                              ),
                              SizedBox(
                                height: isLastItem ? 200 : 0.0,
                              ),
                            ],
                          ):list[index].messageType==MessageType.image.name? BubbleNormalImage(
                            id: 'id001',
                            image: _image(),
                            color: Colors.purpleAccent,
                            tail: true,
                            delivered: true,
                            isSender:list[index].sendBy==authProvider.loginUserData.id!?true: false,
                          ):list[index].messageType==MessageType.voice? BubbleNormalAudio(
                            color: Color(0xFFE8E8EE),
                            duration: duration.inSeconds.toDouble(),
                            position: position.inSeconds.toDouble(),
                            isPlaying: isPlaying,
                            isLoading: isLoading,
                            isPause: isPause,
                            onSeekChanged: _changeSeek,
                            onPlayPauseButtonClick: _playAudio,
                            sent: true,
                            isSender:list[index].sendBy==authProvider.loginUserData.id!?true: false,
                          ):BubbleSpecialOne(
                            text: '${list[index].message}',
                            isSender:list[index].sendBy==authProvider.loginUserData.id!?true: false,
                            color:list[index].sendBy==authProvider.loginUserData.id!? ConstColors.meMessageColors:Color(0xFFE8E8EE),
                            textStyle: TextStyle(
                              fontSize: 15,
                              color:list[index].sendBy==authProvider.loginUserData.id!? Colors.white: Colors.black,
                            ),
                          );
                        });
                  } else if (snapshot.hasError) {
                    return
                      Center(child: Container(width:50 , height:50,child: CircularProgressIndicator()));
                  } else {
                    // QuerySnapshot data = snapshot.requireData as QuerySnapshot;
                    // Get data from docs and convert map to List




                    List<Message> list = snapshot.data!;
                    printVm("message lenght: ${list.length}");

                    userProvider.chat.messages=list;
                    // Utiliser les données de snapshot.data
                    return  ListView.builder(
                      //reverse: true,

                        controller: _controller,
                        scrollDirection: Axis.vertical,
                        itemCount: snapshot.data!.length, // Nombre d'éléments dans la liste
                        itemBuilder: (context, index) {

                          if (authProvider.loginUserData.id!=list[index]!.sendBy) {
                            if (list[index]!.message_state!=MessageState.LU.name) {
                              list[index]!.message_state=MessageState.LU.name;
                              firestore.collection('Messages').doc(list[index].id).update(list[index]!.toJson());

                            }

                          }

                          bool isLastItem = index == snapshot.data!.length - 1;

                          // Déterminer la hauteur de SizedBox en fonction de la condition
                          double sizedBoxHeight = isLastItem ? 20.0 : 0.0;
                          //list[index].userAbonnes=[];
                          return list[index].messageType==MessageType.text.name?
                          Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            crossAxisAlignment:list[index].sendBy==authProvider.loginUserData.id!? CrossAxisAlignment.end:CrossAxisAlignment.start,
                            children: [
                              list[index].replyMessage.message.length>0? BubbleNormal(

                                text: 'Re: ${ list[index].replyMessage.message}',
                                isSender:list[index].sendBy==authProvider.loginUserData.id!?true: false,
                                color:list[index].sendBy==authProvider.loginUserData.id!? ConstColors.buttonsColors:Color(
                                    0xfff3fdf8),
                                textStyle: TextStyle(
                                  fontSize: 10,
                                  color: Colors.blue,


                                ),
                              ):Container(),
                              Row(
                                mainAxisAlignment:list[index].sendBy==authProvider.loginUserData.id!?  MainAxisAlignment.end:MainAxisAlignment.start,
                                children: [
                                  list[index].sendBy==authProvider.loginUserData.id!?
                                  IconButton(

                                    onPressed: () {
                                      replying=true;
                                      replyingTo=list[index].message;
                                      setState(() {

                                      });
                                    },
                                    icon: Icon(
                                      Icons.reply,
                                      color: Colors.blue,
                                      size: 15,
                                    ),
                                  ):Container(),
                                  BubbleSpecialOne(

                                    text: '${list[index].message}',
                                    isSender:list[index].sendBy==authProvider.loginUserData.id!?true: false,
                                    color:list[index].sendBy==authProvider.loginUserData.id!? ConstColors.meMessageColors:Color(0xFFE8E8EE),
                                    textStyle: TextStyle(
                                      fontSize: 15,
                                      color:list[index].sendBy==authProvider.loginUserData.id!? Colors.white: Colors.black,
                                    ),
                                  ),
                                  list[index].sendBy!=authProvider.loginUserData.id!? Transform.rotate(
                                    angle: 45 * 3.141592653 / 1,
                                    child: IconButton(

                                      onPressed: () {
                                        replying=true;
                                        replyingTo=list[index].message;
                                        setState(() {

                                        });

                                      },
                                      icon: Icon(
                                        Icons.reply,
                                        color: Colors.blue,
                                        size: 15,
                                      ),
                                    ),
                                  ):Container(),
                                ],
                              ),
                              Padding(
                                padding: list[index].sendBy==authProvider.loginUserData.id!? const EdgeInsets.only(right: 20.0,bottom: 20):const EdgeInsets.only(left: 20.0,bottom: 20),
                                child: Text("${formaterDateTime(DateTime.fromMillisecondsSinceEpoch(list[index].create_at_time_spam))}",style: TextStyle(fontSize: 8),),
                              ),
                              SizedBox(
                                height: isLastItem ? 200 : 0.0,
                              ),
                            ],
                          ):list[index].messageType==MessageType.image.name? BubbleNormalImage(
                            id: 'id001',
                            image: _image(),
                            color: Colors.blue,
                            tail: true,
                            delivered: true,
                            isSender:list[index].sendBy==authProvider.loginUserData.id!?true: false,
                          ):list[index].messageType==MessageType.voice? BubbleNormalAudio(
                            color: Color(0xFFE8E8EE),
                            duration: duration.inSeconds.toDouble(),
                            position: position.inSeconds.toDouble(),
                            isPlaying: isPlaying,
                            isLoading: isLoading,
                            isPause: isPause,
                            onSeekChanged: _changeSeek,
                            onPlayPauseButtonClick: _playAudio,
                            sent: true,
                            isSender:list[index].sendBy==authProvider.loginUserData.id!?true: false,
                          ):BubbleSpecialOne(
                            text: '${list[index].message}',
                            isSender:list[index].sendBy==authProvider.loginUserData.id!?true: false,
                            color:list[index].sendBy==authProvider.loginUserData.id!? ConstColors.meMessageColors:Color(0xFFE8E8EE),
                            textStyle: TextStyle(
                              fontSize: 15,
                              color:list[index].sendBy==authProvider.loginUserData.id!? Colors.white: Colors.black,
                            ),
                          );
                        });
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
                              replyingTo="";
                              replying=false;
                              setState(() {

                              });
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
                      children: <Widget>[
                        InkWell(
                          child: Icon(
                            Icons.keyboard_voice_outlined,
                            color: Colors.black,
                            size: 24,
                          ),
                          onTap: () {},
                        ),
                        Padding(
                          padding: EdgeInsets.only(left: 8, right: 8),
                          child: InkWell(
                            child: Icon(
                              Icons.camera_alt,
                              color: Colors.green,
                              size: 24,
                            ),
                            onTap: () {},
                          ),
                        ),
                        Expanded(
                          child: Container(
                            child: TextField(
                              focusNode: _focusNode,
                              onTap: ()async {

                                _controller.animateTo(
                                  _controller.position.maxScrollExtent*34,
                                  duration: Duration(milliseconds: 800),
                                  curve: Curves.fastOutSlowIn,
                                );
                                printVm("tap");
                              },
                              controller: _textController,
                              keyboardType: TextInputType.multiline,
                              textCapitalization: TextCapitalization.sentences,
                              minLines: 1,
                              maxLines: 3,

                              onChanged: (value) {
                                //onTextChanged
                              },
                              style: const TextStyle(color: Colors.black),
                              decoration: InputDecoration(
                                hintText: "message...",
                                hintMaxLines: 1,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8.0, vertical: 10),
                                hintStyle: const TextStyle(fontSize: 16),
                                fillColor: Colors.white,
                                filled: true,
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30.0),
                                  borderSide: const BorderSide(
                                    color: Colors.white,
                                    width: 0.2,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30.0),
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
                            onTap:sendMessageTap?(){}: ()
                            async {
                              printVm("send tap;");
                              sendMessageTap=true;

                              if (_textController.text.length>0) {
                                try{
                                  final id = userProvider.usermessageList.length + 1;
                                  ReplyMessage reply=ReplyMessage(message: replyingTo, messageType: MessageType.text.name);

                                  Message msg=Message(
                                    id: id.toString(),
                                    createdAt: DateTime.now(),
                                    message: _textController.text,
                                    // sendBy: authProvider.loginUserData.id!.toString(),
                                    sendBy:  '${authProvider.loginUserData.id!}',
                                    replyMessage: reply,
                                    // messageType:messageType==MessageType.text? MessageType.text:message.messageType==MessageType.image?MessageType.image:message.messageType==MessageType.voice?MessageType.voice:MessageType.custom,

                                    messageType: MessageType.text.name,
                                    chat_id: widget.chat.docId!,
                                    create_at_time_spam: DateTime.now().millisecondsSinceEpoch,
                                    message_state: MessageState.NONLU.name,
                                    receiverBy: widget.chat!.senderId==authProvider.loginUserData.id!?widget.chat!.receiverId!:widget.chat!.senderId!,

                                  );
                                  widget.chat.lastMessage=_textController.text;
                                  widget.chat.senderId==authProvider.loginUserData.id!?widget.chat.your_msg_not_read=widget.chat.your_msg_not_read!+1:widget.chat.my_msg_not_read=widget.chat.my_msg_not_read!+1;
                                  widget.chat.lastMessage=_textController.text;
                                  _textController.text = '';



                                  String msgid = firestore
                                      .collection('Messages')
                                      .doc()
                                      .id;
                                  msg.setStatus=
                                      MessageStatus.undelivered;
                                  msg.id=msgid;
                                  msg.replyMessage=reply;
                                  await firestore.collection('Messages').doc(msgid).set(msg.toJson());
                                  widget.chat.updatedAt= DateTime.now().millisecondsSinceEpoch;


                                  await firestore.collection('Chats').doc(widget.chat.id).update( widget.chat!.toJson());
                                  _controller.animateTo(
                                    _controller.position.maxScrollExtent*500,
                                    duration: Duration(milliseconds: 800),
                                    curve: Curves.fastOutSlowIn,
                                  );
                                  _focusNode.unfocus();

                                  replyingTo="";

                                  replying=false;
                                  setState(() {
                                    sendMessageTap=false;
                                  });
                                }on FirebaseException catch(error){
                                  printVm("error code: ${error.message}");
                                  printVm("error message : ${error.message}");
                                  setState(() {
                                    sendMessageTap=false;
                                  });
                                }

                              }

                              sendMessageTap=false;


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

  Widget _image() {
    return Container(
      constraints: BoxConstraints(
        minHeight: 20.0,
        minWidth: 20.0,
      ),
      child: CachedNetworkImage(
        imageUrl: 'https://i.ibb.co/JCyT1kT/Asset-1.png',
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
        printVm("duration ${d}");

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
