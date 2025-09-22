

// models/live_models.dart
import 'dart:async';
import 'dart:math';
import 'package:afrotok/pages/component/consoleWidget.dart';
import 'package:afrotok/pages/component/showUserDetails.dart';
import 'package:afrotok/providers/authProvider.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';


import '../../models/model_data.dart';
import '../paiement/newDepot.dart';
import 'create_live_page.dart';
import 'livesAgora.dart';

class CreateLivePage extends StatefulWidget {
  @override
  _CreateLivePageState createState() => _CreateLivePageState();
}

class _CreateLivePageState extends State<CreateLivePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _feeController = TextEditingController(text: '100');
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  List<String> _selectedUsers = [];

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<UserAuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text('Créer un live', style: TextStyle(color: Color(0xFFF9A825))),
        backgroundColor: Colors.black,
      ),
      backgroundColor: Colors.black,
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              SizedBox(height: 20),
              _buildTitleField(),
              // SizedBox(height: 20),
              // _buildFeeField(),
              // SizedBox(height: 20),
              // _buildUserSelection(authProvider),
              SizedBox(height: 30),
              _buildCreateButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTitleField() {

    return TextFormField(
      controller: _titleController,
      style: TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: 'Titre du live',
        labelStyle: TextStyle(color: Color(0xFF2E7D32)),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Color(0xFF2E7D32)),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Color(0xFFF9A825)),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Veuillez entrer un titre';
        }
        return null;
      },
    );
  }

  Widget _buildFeeField() {
    return TextFormField(
      controller: _feeController,
      style: TextStyle(color: Colors.white),
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: 'Frais de participation (FCFA)',
        labelStyle: TextStyle(color: Color(0xFF2E7D32)),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Color(0xFF2E7D32)),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Color(0xFFF9A825)),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Veuillez entrer un montant';
        }
        if (double.tryParse(value) == null) {
          return 'Montant invalide';
        }
        return null;
      },
    );
  }

  Widget _buildUserSelection(UserAuthProvider authProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Inviter des participants',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        SizedBox(height: 8),
        Container(
          height: 200,
          decoration: BoxDecoration(
            border: Border.all(color: Color(0xFF2E7D32)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ListView.builder(
            itemCount: authProvider.availableUsers.length,
            itemBuilder: (context, index) {
              final user = authProvider.availableUsers[index];
              return CheckboxListTile(
                title: Text(user.pseudo ?? user.email ?? '',
                    style: TextStyle(color: Colors.white)),
                value: _selectedUsers.contains(user.id),
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      _selectedUsers.add(user.id!);
                    } else {
                      _selectedUsers.remove(user.id);
                    }
                  });
                },
                activeColor: Color(0xFFF9A825),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCreateButton() {
    return ElevatedButton(
      onPressed: _createLive,
      child: Text('Démarrer le live', style: TextStyle(color: Colors.black)),
      style: ElevatedButton.styleFrom(
        backgroundColor: Color(0xFFF9A825),
        padding: EdgeInsets.symmetric(vertical: 16),
      ),
    );
  }

  Future<void> _createLive() async {
    if (_formKey.currentState!.validate()) {
      User? user = _auth.currentUser;
      late UserAuthProvider authProvider =
      Provider.of<UserAuthProvider>(context, listen: false);
      if (user != null) {
        String liveId = _firestore.collection('lives').doc().id;

        PostLive newLive = PostLive(
          paymentRequired: false,
          liveId: liveId,
          hostId: user.uid,
          hostName: authProvider.loginUserData.pseudo! ?? 'Utilisateur',
          hostImage: authProvider.loginUserData.imageUrl!?? 'https://via.placeholder.com/150',
          title: _titleController.text,
          startTime: DateTime.now(),
          participationFee: double.parse(_feeController.text),
          invitedUsers: _selectedUsers,
        );

        await _firestore.collection('lives').doc(liveId).set(newLive.toMap());
        authProvider
            .getAllUsersOneSignaUserId()
            .then(
              (userIds) async {
            if (userIds.isNotEmpty) {

              await authProvider.sendNotification(
                  userIds: userIds,
                  smallImage: "${authProvider.loginUserData.imageUrl!}",
                  send_user_id: "${authProvider.loginUserData.id!}",
                  recever_user_id: "",
                  message: "🚀 @${authProvider.loginUserData.pseudo!} vient tout juste de lancer un live 🎬✨ ! Rejoignez-le vite pour ne rien manquer 👀🔥",
                  type_notif: NotificationType.CHRONIQUE.name,
                  post_id: "id",
                  post_type: PostDataType.TEXT.name, chat_id: ''
              );

            }
          },
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => LivePage(
              liveId: liveId,
              isHost: true,
              hostName: newLive.hostName!,
              hostImage: newLive.hostImage!,
              isInvited: false, postLive: newLive,
            ),
          ),
        );
      }
    }
  }
}