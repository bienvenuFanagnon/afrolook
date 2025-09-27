



import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';


class ChatXiloPage extends StatefulWidget {
  final String userName;
  final String userGender;

  ChatXiloPage({required this.userName, required this.userGender});

  @override
  _ChatXiloPageState createState() => _ChatXiloPageState();
}

class _ChatXiloPageState extends State<ChatXiloPage> {


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
            child: Container(),
          ),
        ),
      ),
    );
  }
}