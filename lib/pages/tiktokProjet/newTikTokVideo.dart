import 'package:afrotok/pages/contact.dart';
import 'package:afrotok/pages/user/monetisation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:marquee/marquee.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:tiktok_scraper/tiktok_scraper.dart';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/model_data.dart';
import '../../providers/authProvider.dart';

class UploadVideoPage extends StatefulWidget {
  @override
  _UploadVideoPageState createState() => _UploadVideoPageState();
}

class _UploadVideoPageState extends State<UploadVideoPage> {
  final _formKey = GlobalKey<FormState>();
  late UserAuthProvider authProvider =
  Provider.of<UserAuthProvider>(context, listen: false);
  final _videoUrlController = TextEditingController();
  final _durationController = TextEditingController();
  TiktokVideo? _videoPreview;
  bool _isLoading = false;
  bool _isUploading = false;
  bool valide = false;
  int limite =0;

  initialisation() async {
    final freshUserSnapshot = await FirebaseFirestore.instance
        .collection('Users')
        .doc(authProvider.loginUserData.id)
        .get();

    final freshUserData = UserData.fromJson(
        freshUserSnapshot.data() as Map<String, dynamic>);
    freshUserData.id = freshUserSnapshot.id;

    // Mise à jour du provider avec les nouvelles données
    authProvider.loginUserData = freshUserData;
    print('user data mespub : ${authProvider.loginUserData.mesTiktokPubs}');

    if(authProvider.loginUserData.role==UserRole.ADM.name){
      limite =10000;
    }else{
      limite =5;
    }
    setState(() {

    });
  }

@override
  void initState() {
    // TODO: implement initState


    super.initState();
  }
  @override
  void dispose() {
    _videoUrlController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  Future<void> _loadPreview() async {
    if (_videoUrlController.text.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final video = await TiktokScraper.getVideoInfo(_videoUrlController.text);

        valide = true;

      setState(() => _videoPreview = video);

    } catch (e) {
      setState(() {
        valide = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lien invalide ou vidéo non trouvée')),
      );
    }
    setState(() => _isLoading = false);
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()&&valide) return;
    if (_videoPreview == null) return;
    final freshUserSnapshot = await FirebaseFirestore.instance
        .collection('Users')
        .doc(authProvider.loginUserData.id)
        .get();

    final freshUserData = UserData.fromJson(
        freshUserSnapshot.data() as Map<String, dynamic>);
    freshUserData.id = freshUserSnapshot.id;

    // Mise à jour du provider avec les nouvelles données
    authProvider.loginUserData = freshUserData;

    final currentUser = authProvider.loginUserData;
    final currentMesPubs = currentUser.mesTiktokPubs ?? 0;

    if (currentMesPubs >= limite) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Limite atteinte', style: TextStyle(color: Colors.white)),
          content: Text(
            'Vous avez atteint la limite de 5 vidéos gratuites. Contactez-nous via support@example.com pour plus de quota.',
            style: TextStyle(color: Colors.white70),
          ),
          backgroundColor: Colors.grey[900],
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('OK', style: TextStyle(color: Colors.red)),
            ),
            TextButton(
              onPressed: () {
                // final Uri emailLaunchUri = Uri(
                //   scheme: 'mailto',
                //   path: 'support@example.com',
                //   queryParameters: {'subject': 'Demande de quota supplémentaire'},
                // );
                // launchUrl(emailLaunchUri);
                Navigator.push(context, MaterialPageRoute(builder: (context) => ContactPage(),));
                Navigator.pop(context);
              },
              child: Text('Contactez-nous', style: TextStyle(color: Colors.blue)),
            ),
          ],
        ),
      );
      return;
    }
    setState(() => _isUploading = true);
    try {
      await FirebaseFirestore.instance.collection('videosTiktok').add({
        'videoUrl': _videoUrlController.text,
        'tiktokUsername': _videoPreview!.author.username,
        'userId': FirebaseAuth.instance.currentUser!.uid,
        'timestamp': Timestamp.now(),
        'durationDays': int.tryParse(_durationController.text) ?? 2,
        'clickCount': 0,
        'viewers': [],
      });

      await FirebaseFirestore.instance
          .collection('Users')
          .doc(authProvider.loginUserData.id)
          .update({'mesTiktokPubs': FieldValue.increment(1)});

      // Update local user data
      authProvider.loginUserData.mesTiktokPubs = (authProvider.loginUserData.mesTiktokPubs ?? 0) + 1;
setState(() {

});
      await authProvider
          .getAllUsersOneSignaUserId()
          .then(
            (userIds) async {
          if (userIds.isNotEmpty) {
            await authProvider.sendNotification(
                userIds: userIds,
                smallImage: "${ _videoPreview!.thumbnail}",
                send_user_id: "${authProvider.loginUserData.id!}",
                recever_user_id: "",
                message: "🎥 Nouvelle vidéo TikTok en ligne ! 👀 Regarde-la maintenant et 💸 gagne jusqu' à 25 fcfa 🪙💰🔥",
                type_notif: NotificationType.POST.name,
                post_id: "",
                post_type: PostDataType.IMAGE.name, chat_id: ''
            );

          }
        },
      );
      Navigator.pop(context);
    } finally {
      setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    initialisation();
    return Scaffold(
      appBar: AppBar(
        iconTheme: IconThemeData(color: Colors.red),
        title: Text('Nouvelle video tiktok', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      backgroundColor: Colors.black,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  "Boostez votre compte TikTok ! Partagez vos vidéos ici 🚀",
                  style: TextStyle(color: Colors.white, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  'Vidéos postées: ${authProvider.loginUserData.mesTiktokPubs}/${limite}',
                  style: TextStyle(color: Colors.white54, fontSize: 14),
                ),
              ),
              // Section Prévisualisation
              Container(
                height: 400,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  color: Colors.grey[900],
                ),
                child: _isLoading
                    ? Center(child: CircularProgressIndicator())
                    : _videoPreview == null
                    ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.video_library, size: 50, color: Colors.grey),
                    SizedBox(height: 10),
                    Text('Aperçu de la vidéo',
                        style: TextStyle(color: Colors.grey)),
                  ],
                )
                    : Stack(
                  children: [
                    Image.network(
                      _videoPreview!.thumbnail,
                      fit: BoxFit.cover,
                      height: double.infinity,
                      width: double.infinity,
                    ),
                    Positioned(
                      bottom: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5), // arrière-plan semi-transparent si nécessaire
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.4),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundImage:
                              NetworkImage(_videoPreview!.author.avatar),
                              radius: 15,
                            ),
                            SizedBox(width: 10),
                            Text(
                              '@${_videoPreview!.author.username}',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 20),

              // Champ URL
              TextFormField(
                controller: _videoUrlController,
                style: TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Coller le lien TikTok',
                  labelStyle: TextStyle(color: Colors.grey),
                  enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey)),
                  suffixIcon: IconButton(
                    icon: Icon(Icons.search, color: Colors.pink),
                    onPressed: _loadPreview,
                  ),
                ),
                onChanged: (value) {
                  _loadPreview();
                },
                validator: (value) => value!.isEmpty ? 'Obligatoire' : null,
              ),

              SizedBox(height: 20),

              // Durée
              // TextFormField(
              //   controller: _durationController,
              //   style: TextStyle(color: Colors.white),
              //   keyboardType: TextInputType.number,
              //   decoration: InputDecoration(
              //     labelText: 'Durée d\'affichage (jours)',
              //     labelStyle: TextStyle(color: Colors.grey),
              //     enabledBorder: UnderlineInputBorder(
              //         borderSide: BorderSide(color: Colors.grey)),
              //   ),
              //   validator: (value) => value!.isEmpty ? 'Obligatoire' : null,
              // ),
              //
              // SizedBox(height: 30),

              // Bouton de publication
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.pink,
                  padding: EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                ),
                onPressed: _isUploading ? null : _submitForm,
                child: _isUploading
                    ? SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2),
                )
                    : Text('PUBLIER MAINTENANT',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}