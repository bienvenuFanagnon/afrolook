import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/authProvider.dart';

class ChangePasswordPage extends StatefulWidget {
  final String phoneNumber;
  const ChangePasswordPage({super.key, required this.phoneNumber});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
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


  Future<User?> getUserByPhone(String email) async {
    print("phone number mail : ${email}");

    try {
      User? user = await FirebaseAuth.instance.authStateChanges().firstWhere((User? user) => user != null && user.email == email);
      print("email: ${user!.email}");
      return user;
    } catch (e) {
      print("Erreur lors de la récupération de l'utilisateur: $e");
      return null;
    }
  }

  void _changePassword(String currentPassword, String newPassword,User user) async {
   // final user = await getUserByUid(user_id)!;
    final cred = EmailAuthProvider.credential(
        email: user!.email!, password: currentPassword);

    await user.reauthenticateWithCredential(cred).then((value) async {
      await  user.updatePassword(newPassword).then((_) {
        //Success, do something
        SnackBar snackBar = SnackBar(
          backgroundColor: Colors.green,
          content: Text('Votre mot de passe a été modifié avec succès. !',style: TextStyle(color: Colors.white),),
        );
      }).catchError((error) {
        SnackBar snackBar = SnackBar(
          backgroundColor: Colors.red,
          content: Text("Une erreur s'est produite ${error}",style: TextStyle(color: Colors.white),),
        );
        ScaffoldMessenger.of(context).showSnackBar(snackBar);
        //Error, show something
      });
    }).catchError((err) {
      SnackBar snackBar = SnackBar(
        backgroundColor: Colors.red,
        content: Text("Une erreur s'est produite ${err}",style: TextStyle(color: Colors.white),),
      );
      ScaffoldMessenger.of(context).showSnackBar(snackBar);

    });}

  Future<void> changePassword(String uid, String newPassword) async {
    try{
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
    }catch(e){
      print("error ${e}");

    }

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
                 await   getUserByPhone("${widget.phoneNumber}@gmail.com").then((user) async {
                      if (user!=null) {
                        await    authProvider.getUserById(user.uid).then((users) {
                          if (users.isNotEmpty) {
                            _changePassword(authProvider.decrypt(users.first.password!), _newPasswordController.text,user);

                          }

                        },);

                      }

                    },);
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
