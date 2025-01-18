import 'package:afrotok/constant/logo.dart';
import 'package:afrotok/models/model_data.dart';
import 'package:flutter/material.dart';

class LookChallengeDetailsPage extends StatefulWidget {
  final LookChallenge lookChallenge;
  const LookChallengeDetailsPage({super.key, required this.lookChallenge});

  @override
  State<LookChallengeDetailsPage> createState() => _LookChallengeDetailsPageState();
}

class _LookChallengeDetailsPageState extends State<LookChallengeDetailsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Text('Details Look Challenges 🏆🔥🎁',style: TextStyle(color: Colors.white,fontSize: 18),),
        actions: [
        Logo()
        ],
        backgroundColor: Colors.green,
      ),
      body: Container(),

    );
  }
}
