import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import '../../../../models/model_data.dart';
import '../../../../providers/authProvider.dart';
import '../../../../providers/postProvider.dart';

class AddTextStoryPage extends StatefulWidget {
  @override
  State<AddTextStoryPage> createState() => _AddTextStoryPageState();
}

class _AddTextStoryPageState extends State<AddTextStoryPage> {
  late UserAuthProvider authProvider =
  Provider.of<UserAuthProvider>(context, listen: false);
  late PostProvider postProvider =
  Provider.of<PostProvider>(context, listen: false);
  final TextEditingController _captionController = TextEditingController();
  Color _backgroundColor = Colors.white;

  @override
  Widget build(BuildContext context) {
    double width=MediaQuery.of(context).size.width;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Afro Chronique Text',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.green,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              TextFormField(
                onChanged: (value) {
                  setState(() {

                  });
                },
                controller: _captionController,
                keyboardType: TextInputType.multiline,
                maxLines: null,
                decoration: InputDecoration(
                  hintText: 'Écrivez votre Chronique historique',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                    borderSide: BorderSide(color: Colors.blue, width: 2.0),
                  ),
                ),
              ),
              SizedBox(height: 20),
              Text('Choisissez la couleur du fond :'),
              SizedBox(height: 10),
              SizedBox(
                width: width*0.9,
                height: 70,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    // _colorOption(Colors.white),
                    _colorOption(Colors.yellow),
                    _colorOption(Colors.red),
                    _colorOption(Colors.brown),
                    _colorOption(Colors.green),
                    _colorOption(Colors.blue),
                    _colorOption(Colors.purple),
                    _colorOption(Colors.orange),
                    _colorOption(Colors.pink),
                    _colorOption(Colors.teal),
                    _colorOption(Colors.cyan),
                    _colorOption(Colors.lime),
                    _colorOption(Colors.indigo),
                  ],
                ),
              ),
              SizedBox(height: 20),
              Container(
                width: double.infinity,
                height: 200,
                color: _backgroundColor,
                child: Center(
                  child: Text(
                    _captionController.text,
                    style: TextStyle(fontSize: 24,color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  if (_captionController.text.isNotEmpty) {
                    Map<String, dynamic> story = {
                      "mediaType": "text",
                      "media": "",
                      "duration": "4.0",
                      "caption": _captionController.text,
                      "when": "2 hours ago",
                      "color": "${_backgroundColor.value.toRadixString(16)}",
                      "createdAt": DateTime.now().millisecondsSinceEpoch,
                      "updatedAt": DateTime.now().millisecondsSinceEpoch,
                      "nbrVues": 0,
                      "vues": [],
                      "nbrJaimes": 0,
                      "jaimes": []
                    };
                    authProvider.loginUserData.stories!.add(story);
                    await authProvider.updateUser(authProvider.loginUserData).then((value) async {
                      if (value) {
                        //  authProvider
                        //     .getAllUsersOneSignaUserId()
                        //     .then(
                        //       (userIds) async {
                        //     if (userIds.isNotEmpty) {
                        //
                        //       await authProvider.sendNotification(
                        //           userIds: userIds,
                        //           smallImage: "${authProvider.loginUserData.imageUrl!}",
                        //           send_user_id: "${authProvider.loginUserData.id!}",
                        //           recever_user_id: "",
                        //           message: "📢 @${authProvider.loginUserData.pseudo!} vient de partager une chronique 🎥✨ ! Découvrez-la dès maintenant 👀.",
                        //           type_notif: NotificationType.CHRONIQUE.name,
                        //           post_id: "id",
                        //           post_type: PostDataType.TEXT.name, chat_id: ''
                        //       );
                        //
                        //     }
                        //   },
                        // );
                        SnackBar snackBar = SnackBar(
                          backgroundColor: Colors.green,
                          content: Text(
                            "📜 Félicitations ! Votre Chronique historique a été publiée avec succès 🎉. Partagez votre histoire unique avec le monde 🌍 !",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white),
                          ),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(snackBar);
                        Navigator.pop(context);
                      }
                    });
                  }
                },
                child: Text(
                  'Ajouter',
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _colorOption(Color color) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _backgroundColor = color;
        });
      },
      child: Container(
        width: 40,
        height: 40,
        margin: EdgeInsets.symmetric(horizontal: 5),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: _backgroundColor == color ? Colors.black : Colors.transparent,
            width: 2,
          ),
        ),
      ),
    );
  }
}
