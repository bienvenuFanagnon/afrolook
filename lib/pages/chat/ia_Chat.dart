import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:afrotok/models/chatmodels/message.dart';
import 'package:afrotok/pages/contact.dart';
import 'package:flutter_gemini_bot/models/chat_model.dart';
import 'package:flutter_gemini_bot/services/gemini_ai_api.dart';
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
import 'package:url_launcher/url_launcher.dart';

import '../../constant/buttons.dart';
import '../../constant/constColors.dart';
import '../../constant/logo.dart';
import '../../constant/sizeText.dart';
import '../../constant/textCustom.dart';
import '../../providers/authProvider.dart';
import '../../providers/userProvider.dart';
import '../component/consoleWidget.dart';
import '../postDetails.dart';
import '../userPosts/postWidgets/achatTokenPage.dart';
import '../userPosts/postWidgets/postWidgetPage.dart';

class IaChat extends StatefulWidget {

  final Chat chat;
  final UserData user;
  final UserIACompte userIACompte;
  final AppDefaultData appDefaultData;
  final String instruction;

  IaChat({Key? key, required this.chat, required this.user, required this.userIACompte, required this.instruction, required this.appDefaultData}) : super(key: key);

  @override
  _EntrepriseMyChatState createState() => _EntrepriseMyChatState();
}

class _EntrepriseMyChatState extends State<IaChat> {
  late  bool replying=false;
  late String replyingTo='';
  //late List<Widget> actions;
  late TextEditingController _textController = TextEditingController();
  AudioPlayer audioPlayer = new AudioPlayer();
  Duration duration = new Duration();
  Duration position = new Duration();
  bool isPlaying = false;
  bool messageIsLoarding = false;
  bool isLoading = false;
  bool isPause = false;
  bool sendMessageTap = false;
  late List<ChatModel> chatList=[];
  late String errorMessage="";
  List<Map<String, String>> messages = [];

  double siveBoxLastmessage=10;
  ScrollController _controller = ScrollController();
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  /// Declare
  FlutterListViewController fluttercontroller = FlutterListViewController();

  FocusNode _focusNode=FocusNode();
  Future<void> launchWhatsApp(String phone) async {
    //  var whatsappURl_android = "whatsapp://send?phone="+whatsapp+"&text=hello";
    // String url = "https://wa.me/?tel:+228$phone&&text=YourTextHere";
    String url = "whatsapp://send?phone="+phone+"&text=Salut ,\n*je vous contacte Depuis Afrolook*,\n\n  à propos de l'achat du jetons";
    if (!await launchUrl(Uri.parse(url))) {
      final snackBar = SnackBar(duration: Duration(seconds: 2),content: Text("Impossible d\'ouvrir WhatsApp",textAlign: TextAlign.center, style: TextStyle(color: Colors.red),));

      // Afficher le SnackBar en bas de la page
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
      throw Exception('Impossible d\'ouvrir WhatsApp');
    }
  }

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
    // .limit(50)
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
  late bool _isLoading=false;
  void showTokenDialog( UserData userToken,AppDefaultData appdata) {
    showDialog(
      context: context,
      barrierDismissible: false, // Empêche la fermeture
      builder: (BuildContext context) {
        String _selectedGift = '';
        double _selectedPrice = 0.0;

        return StatefulBuilder(
          builder: (context, setState) {
            return Stack(
              children: [
                TokenPurchaseDialog(
                  isLoading: _isLoading,
                  onTokenSelected: (String gift, double price,int token) async {
                    setState(() {
                      _isLoading = true;
                      _selectedPrice=price;
                      _selectedGift=gift;
                    },);

                    try {
                      CollectionReference userCollect = FirebaseFirestore.instance.collection('Users');
                      QuerySnapshot querySnapshotUser = await userCollect.where("id", isEqualTo: userToken.id!).get();

                      List<UserData> listUsers = querySnapshotUser.docs.map(
                            (doc) => UserData.fromJson(doc.data() as Map<String, dynamic>),
                      ).toList();

                      if (listUsers.isNotEmpty) {
                        userToken = listUsers.first;
                        printVm("envoyer cadeau");
                        printVm("userSendCadeau.votre_solde_principal : ${userToken.votre_solde_principal}");
                        printVm("_selectedPrice : ${_selectedPrice}");
                        userToken.votre_solde_principal ??= 0.0;
                        appdata.solde_gain ??= 0.0;

                        if (userToken.votre_solde_principal! >= _selectedPrice) {


// Ajouter le gain au solde cadeau
                          widget.userIACompte.jetons =
                              (widget.userIACompte.jetons ?? 0) + token;
                          await firestore.collection('User_Ia_Compte').doc(widget.userIACompte.id!).update(widget.userIACompte.toJson());

// Ajouter le reste au solde principal
                          userToken.votre_solde_principal =
                              userToken.votre_solde_principal! - _selectedPrice;
                          appdata.solde_gain=appdata.solde_gain!+_selectedPrice;

                          // widget.post.user!.votre_solde_cadeau = (widget.post.user!.votre_solde_cadeau ?? 0.0) + _selectedPrice;
                          // userSendCadeau.votre_solde_principal = userSendCadeau.votre_solde_principal! - (_selectedPrice);
                          String imagetoken="https://e7.pngegg.com/pngimages/464/876/png-clipart-onecoin-security-token-cryptocurrency-%D0%A2%D0%BE%D0%BA%D0%B5%D0%BD-money-others-label-trademark.png";
                          NotificationData notif = NotificationData(
                            id: firestore.collection('Notifications').doc().id,
                            titre: "Achat de token",
                            media_url: imagetoken,
                            type: '',
                            description: "🎉 Félicitations ! 🥳 Vous venez d'acheter des tokens. 💰💎",
                            user_id: authProvider.loginUserData.id!,
                            receiver_id: authProvider.loginUserData.id!,
                            post_id: '',
                            post_data_type: PostDataType.IMAGE.name!,
                            createdAt: DateTime.now().microsecondsSinceEpoch,
                            updatedAt: DateTime.now().microsecondsSinceEpoch,
                            status: PostStatus.VALIDE.name,
                          );

                          await firestore.collection('Notifications').doc(notif.id).set(notif.toJson());
                          await authProvider.sendNotification(
                              userIds: [authProvider.loginUserData.oneIgnalUserid!],
                              smallImage:
                              // "${authProvider.loginUserData.imageUrl!}",
                              "${imagetoken}",
                              send_user_id:
                              "",
                              // "${authProvider.loginUserData.id!}",
                              recever_user_id: "${authProvider.loginUserData.id!}",
                              message:
                              // "📢 @${authProvider.loginUserData
                              //     .pseudo!} a aimé votre look",
                              "Vous venez d'acheter des tokens. 💰💎}",
                              type_notif:
                              NotificationType.POST.name,
                              post_id: "",
                              post_type: PostDataType.IMAGE.name,
                              chat_id: '');


                          await authProvider.updateUser(userToken).then((value) async {
                            await  authProvider.updateUser(userToken);
                            await  authProvider.updateAppData(appdata);

                          },);
                          printVm('update send user');
                          printVm('update send user votre_solde_principal : ${userToken.votre_solde_principal}');
                          setState(() => _isLoading = false);
                          Navigator.of(context).pop();

                          // _sendGift("🎁");
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: Colors.green,
                              content: Text(
                                "🎉 Félicitations ! 🥳 Vous venez d'acheter des tokens. 💰💎",
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          );
                        } else {
                          setState(() => _isLoading = false);
                          showInsufficientBalanceDialog(context);
                        }
                      }
                    } catch (e) {
                      setState(() => _isLoading = false);
                      print("Erreur : $e");
                    }
                  },
                ),
                if (_isLoading)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black54,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
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

    if (_controller.hasClients) {
      _controller.animateTo(
        _controller.position.maxScrollExtent*15,
        duration: Duration(seconds: 2),
        curve: Curves.fastOutSlowIn,
      );
    }


    final now = new DateTime.now();
    return Scaffold(
      appBar: AppBar(

        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Logo(),
          )
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 5.0,left: 10),
                      child: CircleAvatar(
                        radius: 26,
                        backgroundImage: AssetImage(
                            'assets/icon/X.png'),
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
                                titre: "@Xilo",
                                fontSize: SizeText.homeProfileTextSize,
                                couleur: ConstColors.textColors,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextCustomerUserTitle(
                              titre: "Amis imaginaire",
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
                Padding(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: Column(
                    children: [
                      SizedBox(
                        //width: 100,
                        child: TextCustomerUserTitle(
                          titre: "Publicash",
                          fontSize: SizeText.homeProfileTextSize,
                          couleur: ConstColors.textColors,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextCustomerUserTitle(
                        titre: "${widget.userIACompte.jetons}",
                        fontSize: SizeText.homeProfileTextSize,
                        couleur: widget.userIACompte.jetons!<=0? Colors.red:Colors.green,
                        fontWeight: FontWeight.w700,
                      ),
                      SizedBox(height: 2,),
                      GestureDetector(
                          onTap: () {
                            showTokenDialog(authProvider.loginUserData, authProvider.appDefaultData)  ;

                          },
                          child: AchatJetonButton()),

                    ],
                  ),
                ),
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
                                  /*
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

                                   */
                                  BubbleSpecialOne(

                                    text: '${list[index].message}',
                                    isSender:list[index].sendBy==authProvider.loginUserData.id!?true: false,
                                    color:list[index].sendBy==authProvider.loginUserData.id!? ConstColors.meMessageColors:Color(0xFFE8E8EE),
                                    textStyle: TextStyle(
                                      fontSize: 15,
                                      color:list[index].sendBy==authProvider.loginUserData.id!? Colors.white: Colors.black,
                                    ),
                                  ),
                                  /*
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
                               */
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
                  messageIsLoarding
                      ? Visibility(

                        child: Container(

                        child: CircularProgressIndicator(),
                        height: 20,
                          width: 20,
                        ),
                    visible: messageIsLoarding,
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
                        /*
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

                         */
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
                              String message_text="";
                              _focusNode.unfocus();

                              await  authProvider.getUserIa(authProvider.loginUserData.id!).then((ias_data) async {
    if (ias_data.isNotEmpty) {
      if(ias_data.first.jetons!>0){
        if (_textController.text.length>0) {
          try{
            message_text=_textController.text;

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
            setState(() {
              messageIsLoarding = true;
            });



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


            // await authProvider.generateText(ancienMessages: widget.chat!.messages!, message: message_text,regle: widget.instruction!, ia: widget.userIACompte, user: authProvider.loginUserData).then((value) async {
            //
            //
            //
            //   Message msg=Message(
            //     id: id.toString(),
            //     createdAt: DateTime.now(),
            //     message: value==null?"Serait-il possible de reformuler la question d'une manière plus claire ou plus précise, s'il vous plaît ?":value!,
            //     // sendBy: authProvider.loginUserData.id!.toString(),
            //     sendBy:  '${widget.userIACompte.id}',
            //     replyMessage: reply,
            //     // messageType:messageType==MessageType.text? MessageType.text:message.messageType==MessageType.image?MessageType.image:message.messageType==MessageType.voice?MessageType.voice:MessageType.custom,
            //
            //     messageType: MessageType.text.name,
            //     chat_id: widget.chat.docId!,
            //     create_at_time_spam: DateTime.now().millisecondsSinceEpoch,
            //     message_state: MessageState.NONLU.name,
            //     receiverBy: widget.chat!.senderId==authProvider.loginUserData.id!?widget.chat!.receiverId!:widget.chat!.senderId!,
            //
            //   );
            //   widget.chat.lastMessage=message_text;
            //   widget.chat.senderId==authProvider.loginUserData.id!?widget.chat.your_msg_not_read=widget.chat.your_msg_not_read!+1:widget.chat.my_msg_not_read=widget.chat.my_msg_not_read!+1;
            //   message_text = '';
            //
            //
            //
            //   String msgid = firestore
            //       .collection('Messages')
            //       .doc()
            //       .id;
            //   msg.setStatus=
            //       MessageStatus.undelivered;
            //   msg.id=msgid;
            //   msg.replyMessage=reply;
            //   await firestore.collection('Messages').doc(msgid).set(msg.toJson());
            //   widget.chat.updatedAt= DateTime.now().millisecondsSinceEpoch;
            //
            //
            //   await firestore.collection('Chats').doc(widget.chat.id).update( widget.chat!.toJson());
            //   setState(() {
            //     sendMessageTap=false;
            //     messageIsLoarding = false;
            //
            //   });
            //
            //
            //
            // },);



            try {
              var question = message_text;

              // Ajout du message utilisateur et indicateur de chargement
              setState(() {
                chatList
                  ..add(ChatModel(
                      chat: 0,
                      message: message_text,
                      time: "${DateTime.now().hour}:${DateTime.now().second}"))
                  ..add(ChatModel(
                      chatType: ChatTypeIa.loading,
                      chat: 1,
                      message: "",
                      time: ""));
              });

              // Préparation des messages
              messages.add({
                "text": "${widget.instruction}"
                    "pseudo: ${authProvider.loginUserData.pseudo}"
                    "nombre abonnees : ${authProvider.loginUserData.abonnes}"
                    "popularité : ${authProvider.loginUserData.popularite != null ? (authProvider.loginUserData.popularite! * 100).round() : 0}%"
                    "points contribution : ${authProvider.loginUserData.pointContribution}\n"
                    "$question",
              });

              // Appel API
              final (responseString, response) = await GeminiApi.geminiChatApi(
                messages: messages,
                apiKey: widget.appDefaultData.geminiapiKey!,
              ).timeout(const Duration(seconds: 30)); // Timeout ajouté
              printVm("Response API: ${response.statusCode}");
              printVm("Response API: ${response.body}");

              // Gestion de la réponse
              if (response.statusCode == 200) {
                // Traitement réussi
                final body = jsonDecode(response.body);
                final token = body['usageMetadata']['totalTokenCount'] ?? 0;
                    // String token=jsonDecode(response.body)['usageMetadata']['totalTokenCount'].toString();

                    // // Mise à jour des jetons restants pour l'utilisateur IA
                    widget.userIACompte.jetons = widget.userIACompte.jetons! - int.parse(token);
                    await firestore.collection('User_Ia_Compte').doc(widget.userIACompte.id!).update(widget.userIACompte.toJson());
                    chatList.removeLast();
                    chatList.add(ChatModel(
                        chat: 1,
                        message: responseString,
                        time:
                        "${DateTime.now().hour}:${DateTime.now().second}"));

                    Message msg=Message(
                      id: id.toString(),
                      createdAt: DateTime.now(),
                      message: responseString==null?"Serait-il possible de reformuler la question d'une manière plus claire ou plus précise, s'il vous plaît ?":responseString!,
                      // sendBy: authProvider.loginUserData.id!.toString(),
                      sendBy:  '${widget.userIACompte.id}',
                      replyMessage: reply,
                      // messageType:messageType==MessageType.text? MessageType.text:message.messageType==MessageType.image?MessageType.image:message.messageType==MessageType.voice?MessageType.voice:MessageType.custom,

                      messageType: MessageType.text.name,
                      chat_id: widget.chat.docId!,
                      create_at_time_spam: DateTime.now().millisecondsSinceEpoch,
                      message_state: MessageState.NONLU.name,
                      receiverBy: widget.chat!.senderId==authProvider.loginUserData.id!?widget.chat!.receiverId!:widget.chat!.senderId!,

                    );
                    widget.chat.lastMessage=message_text;
                    widget.chat.senderId==authProvider.loginUserData.id!?widget.chat.your_msg_not_read=widget.chat.your_msg_not_read!+1:widget.chat.my_msg_not_read=widget.chat.my_msg_not_read!+1;
                    message_text = '';



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
                    setState(() {
                      sendMessageTap=false;
                      messageIsLoarding = false;

                    });
                // Mise à jour UI
                setState(() {
                  chatList
                    ..removeLast()
                    ..add(ChatModel(
                        chat: 1,
                        message: responseString ?? "Réponse vide de l'API",
                        time: "${DateTime.now().hour}:${DateTime.now().second}"));
                });

                // ... reste du code de traitement ...

              } else {
                // Erreur API (status code != 200)
                final errorBody = jsonDecode(response.body);
                final apiError = errorBody['error']['message'] ?? 'Erreur inconnue';
                printVm("Erreur API: ${apiError}");

                setState(() {
                  chatList
                    ..removeLast()
                    ..add(ChatModel(
                        chatType: ChatTypeIa.error,
                        chat: 1,
                        message: "Erreur API: $apiError (${response.statusCode})",
                        time: "${DateTime.now().hour}:${DateTime.now().second}"));
                });
              }
            } on SocketException catch (e) {
              printVm("Erreur de connexion: ${e}");

              // Erreur réseau
              setState(() {
                chatList
                  ..removeLast()
                  ..add(ChatModel(
                      chatType: ChatTypeIa.error,
                      chat: 1,
                      message: "Erreur de connexion: ${e.message}",
                      time: "${DateTime.now().hour}:${DateTime.now().second}"));
              });
            } on TimeoutException catch (_) {
              // Timeout
              setState(() {
                chatList
                  ..removeLast()
                  ..add(ChatModel(
                      chatType: ChatTypeIa.error,
                      chat: 1,
                      message: "Temps d'attente dépassé",
                      time: "${DateTime.now().hour}:${DateTime.now().second}"));
              });
            } on FormatException catch (e) {
              // Erreur de format JSON
              printVm("Erreur de format des données: ${e.message}");
              setState(() {
                chatList
                  ..removeLast()
                  ..add(ChatModel(
                      chatType: ChatTypeIa.error,
                      chat: 1,
                      message: "Erreur de format des données: ${e.message}",
                      time: "${DateTime.now().hour}:${DateTime.now().second}"));
              });
            } catch (e) {
              printVm("Erreur inattendue: ${e}");

              // Erreur générique
              setState(() {
                chatList
                  ..removeLast()
                  ..add(ChatModel(
                      chatType: ChatTypeIa.error,
                      chat: 1,
                      message: "Erreur inattendue: ${e.toString()}",
                      time: "${DateTime.now().hour}:${DateTime.now().second}"));
              });
            } finally {
              // Nettoyage final
              setState(() {
                sendMessageTap = false;
                messageIsLoarding = false;
              });
              FocusScope.of(context).unfocus();
            }


            // try {
            //   var question = message_text;
            //   setState(() {
            //     chatList.add(ChatModel(
            //         chat: 0,
            //         message: message_text,
            //         time:
            //         "${DateTime.now().hour}:${DateTime.now().second}"));
            //
            //     setState(() {
            //       chatList.add(ChatModel(
            //           chatType: ChatTypeIa.loading,
            //           chat: 1,
            //           message: "",
            //           time: ""));
            //     });
            //
            //     // FocusScope.of(context).unfocus();
            //
            //     messages.add({
            //       "text": widget.instruction+"pseudo: ${authProvider.loginUserData.pseudo} nombre abonnees : ${authProvider.loginUserData.abonnes} popularité en pourcentage à arrondie : ${authProvider.loginUserData.popularite!=null?authProvider.loginUserData.popularite!*100:0} point de contribution à l'amelioration de l application : ${authProvider.loginUserData.pointContribution}" + "\n" + question,
            //     });
            //     message_text = "";
            //   });
            //   var (responseString, response) =
            //   await GeminiApi.geminiChatApi(
            //
            //       messages: messages, apiKey: widget.appDefaultData.geminiapiKey!);
            //
            //   printVm('response api gemini body');
            //   printVm('response api gemini body code: ${response.body}');
            //
            //   if (response.statusCode == 200) {
            //     printVm('response api gemini :');
            //     printVm('response api gemini : ${jsonDecode(response.body)['usageMetadata']}');
            //     // Analyser la réponse pour obtenir les informations sur les tokens
            //     String token=jsonDecode(response.body)['usageMetadata']['totalTokenCount'].toString();
            //
            //     // // Mise à jour des jetons restants pour l'utilisateur IA
            //     widget.userIACompte.jetons = widget.userIACompte.jetons! - int.parse(token);
            //     await firestore.collection('User_Ia_Compte').doc(widget.userIACompte.id!).update(widget.userIACompte.toJson());
            //     chatList.removeLast();
            //     chatList.add(ChatModel(
            //         chat: 1,
            //         message: responseString,
            //         time:
            //         "${DateTime.now().hour}:${DateTime.now().second}"));
            //
            //     Message msg=Message(
            //       id: id.toString(),
            //       createdAt: DateTime.now(),
            //       message: responseString==null?"Serait-il possible de reformuler la question d'une manière plus claire ou plus précise, s'il vous plaît ?":responseString!,
            //       // sendBy: authProvider.loginUserData.id!.toString(),
            //       sendBy:  '${widget.userIACompte.id}',
            //       replyMessage: reply,
            //       // messageType:messageType==MessageType.text? MessageType.text:message.messageType==MessageType.image?MessageType.image:message.messageType==MessageType.voice?MessageType.voice:MessageType.custom,
            //
            //       messageType: MessageType.text.name,
            //       chat_id: widget.chat.docId!,
            //       create_at_time_spam: DateTime.now().millisecondsSinceEpoch,
            //       message_state: MessageState.NONLU.name,
            //       receiverBy: widget.chat!.senderId==authProvider.loginUserData.id!?widget.chat!.receiverId!:widget.chat!.senderId!,
            //
            //     );
            //     widget.chat.lastMessage=message_text;
            //     widget.chat.senderId==authProvider.loginUserData.id!?widget.chat.your_msg_not_read=widget.chat.your_msg_not_read!+1:widget.chat.my_msg_not_read=widget.chat.my_msg_not_read!+1;
            //     message_text = '';
            //
            //
            //
            //     String msgid = firestore
            //         .collection('Messages')
            //         .doc()
            //         .id;
            //     msg.setStatus=
            //         MessageStatus.undelivered;
            //     msg.id=msgid;
            //     msg.replyMessage=reply;
            //     await firestore.collection('Messages').doc(msgid).set(msg.toJson());
            //     widget.chat.updatedAt= DateTime.now().millisecondsSinceEpoch;
            //
            //
            //     await firestore.collection('Chats').doc(widget.chat.id).update( widget.chat!.toJson());
            //     setState(() {
            //       sendMessageTap=false;
            //       messageIsLoarding = false;
            //
            //     });
            //   } else {
            //     chatList.removeLast();
            //     chatList.add(ChatModel(
            //         chat: 0,
            //         chatType: ChatTypeIa.error,
            //         message: errorMessage,
            //         time:
            //         "${DateTime.now().hour}:${DateTime.now().second}"));
            //   }
            //   FocusScope.of(context).unfocus();
            //   setState(() {
            //   });
            // } catch (e) {
            //   setState(() {
            //     sendMessageTap=false;
            //   });
            //   print(
            //       "**************************************************************");
            //   printVm('response api gemini body erreur : ${e}');
            // }

            // FocusScope.of(context).unfocus();
            // _scrollController.animateTo(
            //     _scrollController.position.maxScrollExtent +
            //         MediaQuery.of(context).size.height,
            //     duration: const Duration(milliseconds: 300),
            //     curve: Curves.easeOut);


setState(() {

});


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


      }else{
        showModalBottomSheet(
          context: context,
          builder: (BuildContext context) {
            return Container(
              height: 300,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(Icons.info,color: Colors.red,),
                      Text(
                        'Vos jetons sont épuisés !',
                        style: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 10.0),
                      Text(
                        '🚀 Boostez vos conversations avec Xilo ! 💬 Ne laissez pas le manque de jetons freiner vos échanges. 🎯 Contactez-nous dès maintenant pour recharger votre compte et continuer à discuter sans interruption. 📲',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13.0),
                      ),
                      SizedBox(height: 20.0),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black87,
                        ),
                        onPressed: () {
                          // Navigator.push(context, MaterialPageRoute(builder: (context) => ContactPage(),));
                          // launchWhatsApp("+22896198801");
                          Navigator.pop(context);
                          showTokenDialog(authProvider.loginUserData, authProvider.appDefaultData)  ;
                          },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment
                          .center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Icon(Fontisto.whatsapp,color: Colors.green),
                            SizedBox(width: 5,),
                            Text('Achetez maintenant',
                              style: TextStyle(color: Colors.green,fontWeight: FontWeight.bold),),
                          ],
                        ),

                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      }

    }

                              },);



                              _controller.animateTo(
                                _controller.position.maxScrollExtent*500,
                                duration: Duration(milliseconds: 800),
                                curve: Curves.fastOutSlowIn,
                              );
                              _focusNode.unfocus();

                              sendMessageTap=false;

                              setState(() {
                                sendMessageTap=false;
                              });
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
enum ChatTypeIa {
  message,
  error,
  success,
  warning,
  info,
  loading,
}
