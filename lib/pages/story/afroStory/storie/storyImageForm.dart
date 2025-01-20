
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:provider/provider.dart';

import '../../../../models/model_data.dart';
import '../../../../providers/authProvider.dart';
import '../../../../providers/postProvider.dart';
import '../../../userPosts/utils/example_helper.dart';

class AddImageStoryPage extends StatefulWidget {
  @override
  _AddImageStoryPageState createState() => _AddImageStoryPageState();
}

class _AddImageStoryPageState extends State<AddImageStoryPage> with ExampleHelperState<AddImageStoryPage> {
  late UserAuthProvider authProvider =
  Provider.of<UserAuthProvider>(context, listen: false);
  late PostProvider postProvider =
  Provider.of<PostProvider>(context, listen: false);
  final TextEditingController _captionController = TextEditingController();
  File? _image;
  double _uploadProgress = 0.0;
  bool _isUploading = false;

  Future<Uint8List> testComporessList(Uint8List list) async {
    var result = await FlutterImageCompress.compressWithList(
      list,
      // minHeight: 1920,
      // minWidth: 1080,
      quality: 50,
      rotate: 0,
    );

    print('Taille originale: ${list.length} bytes');
    print('Taille compressée: ${result!.length} bytes');
    print(list.length);
    print(result.length);
    return result;
  }
  Uint8List? bytes;

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {


      bytes =await testComporessList(
        await File(pickedFile.path).readAsBytes()!,

      );
        setState(() {
      });
    }
  }

  Future<void> _uploadImage() async {
    if (bytes != null) {
      setState(() {
        _isUploading = true;
      });

      final storageRef = FirebaseStorage.instance.ref().child('stories/${DateTime.now().millisecondsSinceEpoch}.jpg');
      final uploadTask = storageRef.putData(bytes!);

      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        setState(() {
          _uploadProgress = snapshot.bytesTransferred / snapshot.totalBytes;
        });
      });

      await uploadTask.whenComplete(() async {
        final imageUrl = await storageRef.getDownloadURL();

        Map<String, dynamic> story = {
          "mediaType": "image",
          "media": imageUrl,
          "duration": "4.0",
          "caption": _captionController.text,
          "when": "2 hours ago",
          "color": "",
          "createdAt": DateTime.now().millisecondsSinceEpoch,
          "updatedAt": DateTime.now().millisecondsSinceEpoch,
          "nbrVues": 0,
          "vues": [],
          "nbrJaimes": 0,
          "jaimes": []
        };

        authProvider.loginUserData.stories!.add(story);
        await authProvider.updateUser(authProvider.loginUserData).then((value) {
          if (value) {
          //    authProvider
          //       .getAllUsersOneSignaUserId()
          //       .then(
          //         (userIds) async {
          //       if (userIds.isNotEmpty) {
          //
          //         await authProvider.sendNotification(
          //             userIds: userIds,
          //             smallImage: "${authProvider.loginUserData.imageUrl!}",
          //             send_user_id: "${authProvider.loginUserData.id!}",
          //             recever_user_id: "",
          //             message: "📢 @${authProvider.loginUserData.pseudo!} vient de partager une chronique 🎥✨ ! Découvrez-la dès maintenant 👀.",
          //             type_notif: NotificationType.CHRONIQUE.name,
          //             post_id: "id",
          //             post_type: PostDataType.TEXT.name, chat_id: ''
          //         );
          //
          //       }
          //     },
          //   );
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

        setState(() {
          _isUploading = false;
          _uploadProgress = 0.0;
          _image = null;
          _captionController.clear();
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Afro Chronique Image', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.green,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              TextField(
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
              ElevatedButton(
                onPressed: _pickImage,
                child: Text('Choisir une Image', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              ),
              SizedBox(height: 20),
              bytes != null ? Image.memory(bytes!) : Container(),
              SizedBox(height: 20),
              _uploadProgress > 0
                  ? LinearProgressIndicator(value: _uploadProgress)
                  : Container(),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isUploading
                    ? null
                    : () async {
                  if (bytes != null && _captionController.text.isNotEmpty) {
                    await _uploadImage();
                  }
                },
                child: Text('Ajouter', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              ),
            ],
          ),
        ),
      ),
    );
  }
}