

import 'package:afrotok/models/chatmodels/message.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
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
import '../../chat/entrepriseChat.dart';
import '../../chat/myChat.dart';


class ListEntrepriseUserChats extends StatefulWidget {
  const ListEntrepriseUserChats({super.key});

  @override
  State<ListEntrepriseUserChats> createState() => _ListEntrepriseUserChatsState();
}

class _ListEntrepriseUserChatsState extends State<ListEntrepriseUserChats> {
  late UserAuthProvider authProvider =
  Provider.of<UserAuthProvider>(context, listen: false);

  late UserProvider userProvider =
  Provider.of<UserProvider>(context, listen: false);
  Widget chatWidget(Chat chat,Post post) {
    return Container(
      padding: EdgeInsets.only(left: 16,right: 16,top: 10,bottom: 10),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Row(
              children: <Widget>[
                Stack(

                  children: [

      post.images==null?Container(
      width: 50,height: 50,
      ):post.images!.isEmpty?Container(
    width: 50,height: 50,
    ):  CircleAvatar(
    backgroundImage: NetworkImage("${post.images!.first}"),
    onBackgroundImageError: (exception, stackTrace) => AssetImage('assets/images/404.png'),
    maxRadius: 30,
    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(

                        decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.all(Radius.circular(200))
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: CircleAvatar(
                            backgroundImage: NetworkImage("${chat.entreprise!.urlImage!}"),
                            maxRadius: 12,
                          ),
                        ),
                      ),
                    ),

                  ],
                ),

                SizedBox(width: 16,),
                Expanded(
                  child: Container(
                    color: Colors.transparent,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text("#${chat.entreprise!.titre!}", style: TextStyle(fontSize: 16),),
                        SizedBox(height: 6,),
                        SizedBox( width:200,height: 22, child: Text('${chat.lastMessage!}',overflow: TextOverflow.fade,style: TextStyle(fontSize: 13,color: Colors.grey.shade600, fontWeight: FontWeight.normal),)),
                      ],
                    ),
                  ),
                ),
                ClipRRect(
                  borderRadius: BorderRadius.all(Radius.circular(200)),
                  child: Container(
                      color:chat.senderId!=authProvider.loginUserData.id!?chat.your_msg_not_read==0?Colors.white: Colors.red :chat.my_msg_not_read==0? Colors.white:Colors.red,
                      child: Padding(
                        padding: const EdgeInsets.all(5.0),


                        child: Text('${chat.senderId!=authProvider.loginUserData.id!?chat.your_msg_not_read==0?'':chat.your_msg_not_read :chat.my_msg_not_read==0?'':chat.my_msg_not_read}',style: TextStyle(fontSize: 13,color: Colors.white, fontWeight: FontWeight.w600),),
                      )),
                ),
              ],
            ),
          ),


        ],
      ),
    );
  }

  late List<Chat> listChatsSearch=[];
  Future<void> searchListDialogue(BuildContext context,double h,double w,List<Chat> chats) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Liste d\'amis'),
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
                      //     onTap: () async {
                      //       CollectionReference friendCollect = await FirebaseFirestore.instance.collection('Messages');
                      //       QuerySnapshot querySnapshotUser = await friendCollect.where("chat_id",isEqualTo:chat.docId).get();
                      //       // Afficher la liste
                      //       List<Message> messages = querySnapshotUser.docs.map((doc) =>
                      //           Message.fromJson(doc.data() as Map<String, dynamic>)).toList();
                      //       //snapshot.data![index].messages=messages;
                      //       userProvider.chat.messages=messages;
                      //       Navigator.of(context).pop();
                      //       Navigator.push(context, PageTransition(type: PageTransitionType.fade, child: MyChat(title: 'mon chat', chat: chat,)));
                      //
                      //
                      //       //  Navigator.pushNamed(context, '/basic_chat');
                      //     },
                      //
                      //     child: chatWidget(chat,chat.post!)),
                      filter: (value) => chats.where((element) => element.chatFriend!.pseudo!.toLowerCase().contains(value.toLowerCase()),).toList(),
                      emptyWidget:  Container(
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
                                CollectionReference friendCollect = await FirebaseFirestore.instance.collection('Messages');
                                QuerySnapshot querySnapshotUser = await friendCollect.where("chat_id",isEqualTo:chat.docId).get();
                                // Afficher la liste
                                List<Message> messages = querySnapshotUser.docs.map((doc) =>
                                    Message.fromJson(doc.data() as Map<String, dynamic>)).toList();
                                //snapshot.data![index].messages=messages;
                                userProvider.chat.messages=messages;
                                Navigator.of(context).pop();
                                Navigator.push(context, PageTransition(type: PageTransitionType.fade, child: MyChat(title: 'mon chat', chat: chat,)));


                                //  Navigator.pushNamed(context, '/basic_chat');
                              },

                              child: chatWidget(chat,chat.post!)),
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
    var chatsStream = FirebaseFirestore.instance.collection('Chats')
        .where( 'sender_id', isEqualTo:  '${authProvider.loginUserData.id}')
        .where("type",isEqualTo:ChatType.ENTREPRISE.name)
        .orderBy('updated_at', descending: true)
        .snapshots();

// Obtenez la liste des utilisateurs
    //List<DocumentSnapshot> users = await usersQuery.sget();
    Chat usersChat=Chat();
    List<Chat> listChats = [];



    await for (var chatSnapshot in chatsStream) {

      for (var chatDoc in chatSnapshot.docs) {
        CollectionReference friendCollect = await FirebaseFirestore.instance.collection('Users');
        QuerySnapshot querySnapshotUser = await friendCollect.where("id",isEqualTo:authProvider.loginUserData.id== chatDoc["receiver_id"]?chatDoc["sender_id"]:chatDoc["receiver_id"]!).get();
        // Afficher la liste
        List<UserData> userList = querySnapshotUser.docs.map((doc) =>
            UserData.fromJson(doc.data() as Map<String, dynamic>)).toList();
        //userData=userList.first;


        if (userList.first != null) {
          usersChat=Chat.fromJson(chatDoc.data());
          /////////////entreprise//////////
          CollectionReference entrepriseCollect = await FirebaseFirestore.instance.collection('Entreprises');
          QuerySnapshot querySnapshotentreprise = await entrepriseCollect.where("id",isEqualTo:'${usersChat.entreprise_id}').get();
          List<EntrepriseData> entrepriseList = querySnapshotentreprise.docs.map((doc) =>
              EntrepriseData.fromJson(doc.data() as Map<String, dynamic>)).toList();
          /////////////post//////////
          CollectionReference postCollect = await FirebaseFirestore.instance.collection('Posts');
          QuerySnapshot querySnapshotpost= await postCollect.where("id",isEqualTo:'${usersChat.post_id}').get();
          List<Post> postList = querySnapshotpost.docs.map((doc) =>
              Post.fromJson(doc.data() as Map<String, dynamic>)).toList();



          usersChat.post=postList.first;
          usersChat.post!.entrepriseData=entrepriseList.first;
          usersChat.entreprise=entrepriseList.first;
          usersChat.chatFriend=userList.first;
          usersChat.sender=userList.first;
          /////////////post user//////////
          CollectionReference friendCollect = await FirebaseFirestore.instance.collection('Users');
          QuerySnapshot querySnapshotUser = await friendCollect.where("id",isEqualTo:'${usersChat.post!.user_id!}').get();

          List<UserData> userPostList = querySnapshotUser.docs.map((doc) =>
              UserData.fromJson(doc.data() as Map<String, dynamic>)).toList();
          usersChat.post!.user=userPostList.first;



          listChats.add(usersChat);
        }
        listChatsSearch=listChats;



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
      body: SingleChildScrollView(
        physics: BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SafeArea(
              child: Padding(
                padding: EdgeInsets.only(left: 16,right: 16,top: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text("Conversations entreprises",style: TextStyle(fontSize: 20,fontWeight: FontWeight.bold),),

                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(top: 16,left: 16,right: 16),
              child: TextField(
                onTap: () {
                  searchListDialogue(context,height*0.6,width*0.8,listChatsSearch);
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
            StreamBuilder<List<Chat>>(
              //initialData: [],
              stream: getAllChatsData()!,

              // key: _formKey,

              builder: (context, AsyncSnapshot<List<Chat>> snapshot) {



                if (snapshot.hasData) {
                  return
                    ListView.builder(
                      scrollDirection: Axis.vertical,
                      itemCount: snapshot.data!.length,

                      shrinkWrap: true,
                      padding: EdgeInsets.only(top: 16),
                      physics: NeverScrollableScrollPhysics(),
                      itemBuilder: (context, index){
                        return GestureDetector(
                          onTap: () async {
                            CollectionReference friendCollect = await FirebaseFirestore.instance.collection('Messages');
                            QuerySnapshot querySnapshotUser = await friendCollect.where("chat_id",isEqualTo:snapshot.data![index].docId).get();
                            // Afficher la liste
                            List<Message> messages = querySnapshotUser.docs.map((doc) =>
                                Message.fromJson(doc.data() as Map<String, dynamic>)).toList();
                            //snapshot.data![index].messages=messages;
                            userProvider.chat.messages=messages;
                           // Navigator.push(context, PageTransition(type: PageTransitionType.fade, child: MyChat(title: 'mon chat', chat: snapshot.data![index],)));

                            Navigator.push(context, PageTransition(type: PageTransitionType.fade, child: EntrepriseMyChat(title: 'mon chat', chat: snapshot.data![index], post: snapshot.data![index]!.post!, isEntreprise: false,)));

                            //  Navigator.pushNamed(context, '/basic_chat');

                          },
                          child:  chatWidget(snapshot.data![index]!,snapshot.data![index].post!

                          ),
                        );
                      },
                    );
                }
                else if (snapshot.hasError) {
                  print("${snapshot.error}");
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
      ),
    );
  }
}

class ConversationList extends StatefulWidget{
  String name;
  String messageText;
  String imageUrl;
  String time;
  bool isMessageRead;
  ConversationList({required this.name,required this.messageText,required this.imageUrl,required this.time,required this.isMessageRead});
  @override
  _ConversationListState createState() => _ConversationListState();
}

class _ConversationListState extends State<ConversationList> {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(left: 16,right: 16,top: 10,bottom: 10),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Row(
              children: <Widget>[
                CircleAvatar(
                  backgroundImage: NetworkImage(widget.imageUrl),
                  maxRadius: 30,
                ),
                SizedBox(width: 16,),
                Expanded(
                  child: Container(
                    color: Colors.transparent,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(widget.name, style: TextStyle(fontSize: 16),),
                        SizedBox(height: 6,),
                        Text(widget.messageText,style: TextStyle(fontSize: 13,color: Colors.grey.shade600, fontWeight: widget.isMessageRead?FontWeight.bold:FontWeight.normal),),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Text(widget.time,style: TextStyle(fontSize: 12,fontWeight: widget.isMessageRead?FontWeight.bold:FontWeight.normal),),
        ],
      ),
    );
  }
}