import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../../../constant/constColors.dart';
import '../../../constant/logo.dart';
import '../../../constant/sizeText.dart';
import '../../../constant/textCustom.dart';
import '../../providers/authProvider.dart';
import '../../providers/postProvider.dart';
import '../../providers/userProvider.dart';
import '../auth/authTest/constants.dart';

class ChatUsers {
  String name;
  String messageText;
  String imageURL;
  String time;
  ChatUsers(
      {required this.name,
      required this.messageText,
      required this.imageURL,
      required this.time});
}

class UserClassement extends StatefulWidget {
  const UserClassement({super.key});

  @override
  State<UserClassement> createState() => _UserClassementState();
}

class _UserClassementState extends State<UserClassement> {

  late UserAuthProvider authProvider =
  Provider.of<UserAuthProvider>(context, listen: false);
  late UserProvider userProvider =
  Provider.of<UserProvider>(context, listen: false);
  final List<String> noms = ['Alice', 'Bob', 'Charlie'];
  late PostProvider postProvider =
  Provider.of<PostProvider>(context, listen: false);
  ChatUsers usercurrent = ChatUsers(
      name: "Jane Russel",
      messageText: "10000 abonnés",
      imageURL:
      "https://i.pinimg.com/736x/4e/22/dd/4e22dde80c481b344bbe371fe1c2cf81.jpg",
      time: "Now");
  List<ChatUsers> chatUsers = [
    ChatUsers(
        name: "Jane Russel",
        messageText: "10000 abonnés",
        imageURL:
            "https://i.pinimg.com/736x/4e/22/dd/4e22dde80c481b344bbe371fe1c2cf81.jpg",
        time: "Now"),
    ChatUsers(
        name: "Glady's Murphy",
        messageText: "820 abonnés",
        imageURL:
            "https://image.winudf.com/v2/image1/bmV0LndsbHBwci5ib3lzX3Byb2ZpbGVfcGljdHVyZXNfc2NyZWVuXzBfMTY2NzUzNzYxN18wOTk/screen-0.webp?fakeurl=1&type=.webp",
        time: "Yesterday"),
    ChatUsers(
        name: "Jorge Henry",
        messageText: "512 abonnés",
        imageURL:
            "https://a.storyblok.com/f/191576/1200x800/215e59568f/round_profil_picture_after_.webp",
        time: "31 Mar"),
    ChatUsers(
        name: "Philip Fox",
        messageText: "300 abonnés",
        imageURL:
            "https://i.pinimg.com/474x/91/cb/2e/91cb2e86fbbb83592be61606c6438aee.jpg",
        time: "28 Mar"),
    ChatUsers(
        name: "Debra Hawkins",
        messageText: "920 abonnés",
        imageURL:
            "https://i0.wp.com/eacademy.edu.vn/wp-content/uploads/french/Photo-De-Profil-Instagram/Photo-De-Profil-Instagram-250.jpg",
        time: "23 Mar"),
    ChatUsers(
        name: "Jacob Pena",
        messageText: "100 abonnés",
        imageURL:
            "https://i.pinimg.com/474x/91/cb/2e/91cb2e86fbbb83592be61606c6438aee.jpg",
        time: "17 Mar"),
    ChatUsers(
        name: "Andrey Jones",
        messageText: "10 abonnés",
        imageURL:
            "https://a.storyblok.com/f/191576/1200x800/215e59568f/round_profil_picture_after_.webp",
        time: "24 Feb"),
    ChatUsers(
        name: "John Wick",
        messageText: "20 abonnés",
        imageURL:
            "https://i0.wp.com/eacademy.edu.vn/wp-content/uploads/french/Photo-De-Profil-Instagram/Photo-De-Profil-Instagram-250.jpg",
        time: "18 Feb"),
  ];
  Random random = Random();
  @override
  Widget build(BuildContext context) {
    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;
    return Scaffold(
      appBar: AppBar(
        title: TextCustomerPageTitle(
          titre: "Classement par points",
          fontSize: SizeText.homeProfileTextSize,
          couleur: ConstColors.textColors,
          fontWeight: FontWeight.bold,
        ),

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
            Padding(
              padding: EdgeInsets.only(left: 16, right: 16, top: 10),
              child: Text(
                "Période",
                style:
                TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(left: 16, right: 16, top: 10),
              child: Text(
                "1 janvier 2024 - ...",
                style:
                TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            ListView.builder(
              itemCount: userProvider.listAllUsers.length,
              shrinkWrap: true,
              padding: EdgeInsets.only(top: 16),
              physics: NeverScrollableScrollPhysics(),
              itemBuilder: (context, index) {
                Random random = Random();

                // Générer un nombre aléatoire entre 0 et 10000
                int nombreAleatoire = random.nextInt(10001);

                return GestureDetector(
                  onTap: () {
                  },
                  child: ConversationList(
                    name: "@${userProvider.listAllUsers[index].pseudo}",
                    messageText: "${userProvider.listAllUsers[index].abonnes!} abonnés",
                    imageUrl: "${userProvider.listAllUsers[index].imageUrl}",
                    points: userProvider.listAllUsers[index].pointContribution!,
                    isMessageRead: (index == 0 || index == 3) ? true : false,
                    classe: index + 1,
                    avatarSize: 30,
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

class ConversationList extends StatefulWidget {
  int classe;
  String name;
  String messageText;
  String imageUrl;
  int points;
  double avatarSize;
  bool isMessageRead;
  ConversationList(
      {required this.classe,
      required this.name,
        required this.avatarSize,
      required this.messageText,
      required this.imageUrl,
      required this.points,
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
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    "${widget.classe}",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: widget.classe>10?Colors.red:Colors.green),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: widget.classe ==1?Image.asset(
                    'assets/images/trophee.png',
                    height: 20,
                    width: 20,
                  ):widget.classe ==2?Image.asset(
                    'assets/images/trophee2.png',
                    height: 20,
                    width: 20,
                  ):widget.classe ==3?Image.asset(
                    'assets/images/trophee3.png',
                    height: 20,
                    width: 20,
                  ):Container(
                    height: 20,
                    width: 20,
                  ),
                ),
                CircleAvatar(
                  backgroundImage: NetworkImage(widget.imageUrl),
                  maxRadius: widget.avatarSize,
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
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
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
            '${widget.points} Points',
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
