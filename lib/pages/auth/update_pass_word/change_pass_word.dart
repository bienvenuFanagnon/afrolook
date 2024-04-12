import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/authProvider.dart';


class ChangePasswordPage extends StatefulWidget {
  @override
  _ChangePasswordPageState createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  late UserAuthProvider authProvider =
  Provider.of<UserAuthProvider>(context, listen: false);
  bool onTap=false;


  Future<User?> getUserByUid(String uid) async {
    try {
      User? user = await FirebaseAuth.instance.authStateChanges().firstWhere((User? user) => user != null && user.uid == uid);
      return user;
    } catch (e) {
      print("Erreur lors de la récupération de l'utilisateur: $e");
      return null;
    }
  }

  Future<void> changePassword(String uid, String newPassword) async {
    final FirebaseAuth auth = FirebaseAuth.instance;

    // Récupérer l'utilisateur par son ID
    final User? user = await getUserByUid(uid)!;

    // Créer un AuthCredential pour le nouvel mot de passe
    final AuthCredential credential = EmailAuthProvider.credential(
      email: user!.email!,
      password: newPassword,
    );

    // Mettre à jour le mot de passe de l'utilisateur
    await user.reauthenticateWithCredential(credential);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Changer le mot de passe'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[

              TextFormField(
                controller: _newPasswordController,
                decoration: InputDecoration(labelText: 'Nouveau mot de passe'),
                validator: (value) {
                  if (value!.isEmpty) {
                    return 'Veuillez saisir un nouveau mot de passe.';
                  }
                  if (value.length < 8) {
                    return 'Le mot de passe doit contenir au moins 8 caractères.';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _confirmPasswordController,
                decoration: InputDecoration(labelText: 'Confirmation du mot de passe'),
                validator: (value) {
                  if (value!.isEmpty) {
                    return 'Veuillez confirmer votre nouveau mot de passe.';
                  }
                  if (value != _newPasswordController.text) {
                    return 'Les mots de passe ne correspondent pas.';
                  }
                  return null;
                },
              ),
              SizedBox(height: 50,),
              ElevatedButton(
                child:onTap?Container(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator()): Text('Changer le mot de passe'),
                onPressed:onTap?() {

                }:  () async {
                  if (_formKey.currentState!.validate()) {
                    setState(() {
                      onTap=true;
                    });
                   await changePassword(authProvider.loginUserData.id!, _newPasswordController.text);
                    // Mettre à jour le mot de passe
                    // Afficher un message de succès
                    setState(() {
                      onTap=false;
                    });
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
