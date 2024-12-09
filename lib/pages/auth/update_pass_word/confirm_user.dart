
import 'package:afrotok/pages/auth/update_pass_word/confirm_verification_otp.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:provider/provider.dart';

import '../../../providers/authProvider.dart';
import '../authTest/Screens/Signup/function.dart';
import '../authTest/Screens/Signup/verificationOtps.dart';
import '../authTest/constants.dart';

class ConfirmUser extends StatefulWidget {
  const ConfirmUser({Key? key}) : super(key: key);

  @override
  State<ConfirmUser> createState() => _ConfirmUserState();
}

class _ConfirmUserState extends State<ConfirmUser> {
  bool onTap=false;
  final TextEditingController telephoneController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  late UserAuthProvider authProvider =
  Provider.of<UserAuthProvider>(context, listen: false);
  showErrorDialog(BuildContext context,String text) {
    AwesomeDialog(
      context: context,
      animType: AnimType.leftSlide,
      headerAnimationLoop: true,
      dialogType: DialogType.error,
      showCloseIcon: true,
      title: "Envoi code SMS",
      desc:
      text,
      btnCancelOnPress: () {
        debugPrint('OnClcik');
      },
      btnOkIcon: Icons.error,
      onDismissCallback: (type) {
        debugPrint('Dialog Dissmiss from callback $type');
      },
    ).show();

  }

  void
  sendOtpCode() {
    onTap = true;
    setState(() {});
    final _auth = FirebaseAuth.instance;
    if (telephoneController.text.isNotEmpty) {

      // notData=false;

      authWithPhoneNumber(telephoneController.text!, onCodeSend: (verificationId, v) {
        onTap = false;
        setState(() {});
        Navigator.of(context).push(MaterialPageRoute(
            builder: (c) => ConfirmVerificationOtp(
              verificationId: verificationId,
              phoneNumber: telephoneController.text!,
            )));
      }, onAutoVerify: (v) async {
        await _auth.signInWithCredential(v);

        Navigator.of(context).pop();
      },  onFailed: (e) {
        onTap = false;
        setState(() {});
        var errorMessage = "An error occurred";
        switch (e.code) {
          case 'invalid-phone-number':
            errorMessage = 'Le numéro de téléphone saisi est invalide.';
            break;
          case 'too-many-requests':
            errorMessage = 'Vous avez fait trop de demandes. Veuillez réessayer plus tard.';
            break;
          default:
            errorMessage = 'Une erreur inconnue est survenue. Veuillez réessayer plus tard';
        //errorMessage = e.toString();
        }
        showErrorDialog( context, errorMessage);
        print(" erreur : ${e.toString()}");
      }, autoRetrieval: (v) {});
    }else{
      onTap = false;
      // notData=true;
      setState(() {

      });
    }
  }

  bool isValidEmail(String email) {
    final RegExp emailRegExp = RegExp(
        r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$");
    return emailRegExp.hasMatch(email);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // title: const Text('Confirmation'),
        title: const Text('Changement de mot de passe',style: TextStyle(fontSize: 18),),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(15.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "Un lien pour réinitialiser votre mot de passe vous sera envoyer "
                    "Veuillez vérifier votre boîte de réception (et éventuellement vos spams).",
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: emailController,
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.next,
                cursorColor: kPrimaryColor,
                validator: (value)  {
                  if (value!.isEmpty) {
                    return 'Le champ "Email" est obligatoire.';
                  }
                  if (!isValidEmail(value)) {
                    return 'Email invalide';
                  }
                  return null;
                },
                onSaved: (email) {},
                decoration: const InputDecoration(
                  focusColor: kPrimaryColor,
                  focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: kPrimaryColor)),
                  hintText: "Email",
                  prefixIcon: Padding(
                    padding: EdgeInsets.all(defaultPadding),
                    child: Icon(Icons.email),
                  ),
                ),
              ),
              // IntlPhoneField(
              //   //controller: telephoneController,
              //   // invalidNumberMessage:'numero invalide' ,
              //   onTap: () {
              //
              //   },
              //
              //   cursorColor: kPrimaryColor,
              //   decoration: InputDecoration(
              //     hintText: 'Téléphone',
              //     focusColor: kPrimaryColor,
              //     focusedBorder: UnderlineInputBorder(
              //         borderSide: BorderSide(color: kPrimaryColor)),
              //
              //   ),
              //   initialCountryCode: 'TG',
              //   onChanged: (phone) {
              //     telephoneController.text=phone.completeNumber;
              //     print(phone.completeNumber);
              //   },
              //   onCountryChanged: (country) {
              //     print('Country changed to: ' + country.name);
              //   },
              //   validator: (value) {
              //     if (value!.completeNumber.isEmpty) {
              //       return 'Le champ "Téléphone" est obligatoire.';
              //     }
              //
              //     return null;
              //   },
              //
              // ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed:onTap?() {

                }: () async {
                  setState(() {
                    onTap=true;
                  });
                  if (emailController.text.isNotEmpty) {

    FirebaseAuth.instance.sendPasswordResetEmail(email: emailController.text).then((_) {
      SnackBar snackBar = SnackBar(
        // duration: ,
        content: Text("Un email vous a été envoyé à l'adresse ${emailController.text} avec un lien pour réinitialiser votre mot de passe. "
            "Veuillez vérifier votre boîte de réception (et éventuellement vos spams).",textAlign: TextAlign.center,style: TextStyle(color: Colors.green),),
      );
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
    }).catchError((error) {
      SnackBar snackBar = SnackBar(
        content: Text("Une erreur s'est produite lors de l'envoi de l'email de réinitialisation."
            " Veuillez réessayer ultérieurement ou contacter notre support.",textAlign: TextAlign.center,style: TextStyle(color: Colors.red),),
      );
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
    } );
    setState(() {
      onTap=false;
    });
                  // await  authProvider.getUserByPhone( telephoneController.text).then((value) {
                  //     if (value) {
                  //       sendOtpCode();
                  //     }  else{
                  //       SnackBar snackBar = SnackBar(
                  //         content: Text("Ce compte n'existe pas",textAlign: TextAlign.center,style: TextStyle(color: Colors.red),),
                  //       );
                  //       ScaffoldMessenger.of(context).showSnackBar(snackBar);
                  //       setState(() {
                  //         onTap=false;
                  //       });
                  //     }
                  //
                  //   },);

                  }  else{
                    SnackBar snackBar = SnackBar(
                      content: Text('email est obligatoire',textAlign: TextAlign.center,style: TextStyle(color: Colors.red),),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(snackBar);
                    setState(() {
                      onTap=false;
                    });
                  }

                  // TODO: Implémenter la logique de confirmation
                },
                child: onTap?Container(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator()): Text('Confirmer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
