

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

import '../../../constant/constColors.dart';
import '../../../constant/logo.dart';
import '../../../constant/sizeText.dart';
import '../../../constant/textCustom.dart';
import '../../auth/authTest/constants.dart';

class ChatUsers{
  String name;
  String messageText;
  String imageURL;
  String time;
  ChatUsers({required this.name,required this.messageText,required this.imageURL,required this.time});
}
class EntrepriseListConvWithUser extends StatefulWidget {
  const EntrepriseListConvWithUser({super.key});

  @override
  State<EntrepriseListConvWithUser> createState() => _ListUserChatsState();
}

class _ListUserChatsState extends State<EntrepriseListConvWithUser> {

  List<ChatUsers> chatUsers = [
    ChatUsers(name: "Jane Russel - Produit de beaute", messageText: "Awesome Setup", imageURL: "https://i.pinimg.com/736x/4e/22/dd/4e22dde80c481b344bbe371fe1c2cf81.jpg", time: "Now"),
    ChatUsers(name: "Glady's Murphy - smartphone", messageText: "That's Great", imageURL: "https://image.winudf.com/v2/image1/bmV0LndsbHBwci5ib3lzX3Byb2ZpbGVfcGljdHVyZXNfc2NyZWVuXzBfMTY2NzUzNzYxN18wOTk/screen-0.webp?fakeurl=1&type=.webp", time: "Yesterday"),
    ChatUsers(name: "Jorge Henry - produit de peau", messageText: "Hey where are you?", imageURL: "https://a.storyblok.com/f/191576/1200x800/215e59568f/round_profil_picture_after_.webp", time: "31 Mar"),
    ChatUsers(name: "Philip Fox - Produit de beaute", messageText: "Busy! Call me in 20 mins", imageURL: "https://i.pinimg.com/474x/91/cb/2e/91cb2e86fbbb83592be61606c6438aee.jpg", time: "28 Mar"),
    ChatUsers(name: "Debra Hawkins", messageText: "Thankyou, It's awesome", imageURL: "https://i0.wp.com/eacademy.edu.vn/wp-content/uploads/french/Photo-De-Profil-Instagram/Photo-De-Profil-Instagram-250.jpg", time: "23 Mar"),
    ChatUsers(name: "Jacob Pena", messageText: "will update you in evening", imageURL: "https://i.pinimg.com/474x/91/cb/2e/91cb2e86fbbb83592be61606c6438aee.jpg", time: "17 Mar"),
    ChatUsers(name: "Andrey Jones", messageText: "Can you please share the file?", imageURL: "https://a.storyblok.com/f/191576/1200x800/215e59568f/round_profil_picture_after_.webp", time: "24 Feb"),
    ChatUsers(name: "John Wick", messageText: "How are you?", imageURL: "https://i0.wp.com/eacademy.edu.vn/wp-content/uploads/french/Photo-De-Profil-Instagram/Photo-De-Profil-Instagram-250.jpg", time: "18 Feb"),
  ];
  @override
  Widget build(BuildContext context) {
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
                    Text("Conversations Entreprises",style: TextStyle(fontSize: 20,fontWeight: FontWeight.bold),),
                    Container(
                      padding: EdgeInsets.only(left: 8,right: 8,top: 2,bottom: 2),
                      height: 30,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        color: ConstColors.buttonsColors,
                      ),
                      child: Row(
                        children: <Widget>[
                          Icon(Icons.add,color: Colors.blue,size: 20,),
                          SizedBox(width: 2,),
                          Text("Nouveau",style: TextStyle(fontSize: 14,fontWeight: FontWeight.bold),),
                        ],
                      ),
                    )
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(top: 16,left: 16,right: 16),
              child: TextField(
                cursorColor: kPrimaryColor,
                decoration: InputDecoration(
                  focusColor: ConstColors.buttonColors,
                  focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: kPrimaryColor)),
                  hintText: "Search...",
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
            ListView.builder(
              itemCount: chatUsers.length,
              shrinkWrap: true,
              padding: EdgeInsets.only(top: 16),
              physics: NeverScrollableScrollPhysics(),
              itemBuilder: (context, index){
                return GestureDetector(
                  onTap: () {
                    Navigator.pushNamed(context, '/basic_chat');
                  },
                  child: ConversationList(
                    name: chatUsers[index].name,
                    messageText: chatUsers[index].messageText,
                    imageUrl: chatUsers[index].imageURL,
                    time: chatUsers[index].time,
                    isMessageRead: (index == 0 || index == 3)?true:false,
                  ),
                );
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