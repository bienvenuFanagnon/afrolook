import 'package:flutter/material.dart';
import 'package:flutter_gemini_bot/flutter_gemini_bot.dart';
import 'package:flutter_gemini_bot/models/chat_model.dart';

import '../../../constant/buttons.dart';
import '../../../constant/constColors.dart';
import '../../../constant/logo.dart';
import '../../../constant/sizeText.dart';
import '../../../constant/textCustom.dart';
import '../../../models/model_data.dart';



class GeminiChatBot extends StatefulWidget {
  const GeminiChatBot({super.key, required this.title, required this.instruction, required this.userIACompte, required this.apiKey});
  final String title;
  final String instruction;
  final String apiKey;

  final UserIACompte userIACompte;

  @override
  State<GeminiChatBot> createState() => _GeminiChatBotState();
}

class _GeminiChatBotState extends State<GeminiChatBot> {
  List<ChatModel> chatList = []; // Your list of ChatModel objects

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white12,
      appBar: AppBar(
// title:   Logo(),
title:  Text('@Xilo',style: TextStyle(fontWeight: FontWeight.w900,color: Colors.green),),
        actions: [

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
                // AchatJetonButton(),

              ],
            ),
          ),
          AchatJetonButton(),


        ],
      ),

      body: FlutterGeminiChat(
        hintText: "message",
        chatContext: widget.instruction,
        chatList: chatList,
        apiKey: widget.apiKey,


        botChatBubbleColor: Colors.green,
        botChatBubbleTextColor: Colors.black87,
        userChatBubbleColor: Colors.grey,
        userChatBubbleTextColor: Colors.black87,
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}