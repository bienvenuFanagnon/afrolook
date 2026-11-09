import 'package:afrotok/services/read_meter.dart';
import 'package:afrotok/widgets/language_selector.dart';
import 'dart:async';

import 'package:afrotok/pages/auth/authTest/Screens/Signup/signup_up_form_step_2.dart';
import 'package:afrotok/widgets/status_dialog.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';
import 'package:provider/provider.dart';

import '../../../../component/consoleWidget.dart';
import 'function.dart';
import '../../../../../theme/app_colors.dart';
import '../../../../../l10n/app_localizations.dart';


class VerificationOtp extends StatefulWidget {

  const VerificationOtp(
      {Key? key, required this.verificationId, required this.phoneNumber})
      : super(key: key);
  final String verificationId;
  final String phoneNumber;



  @override
  State<VerificationOtp> createState() => _VerificationOtpState();
}

class _VerificationOtpState extends State<VerificationOtp> {
  String smsCode = "";
  bool loading = false;
  bool resend = false;
  int count = 20;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();


  final _auth = FirebaseAuth.instance;


// Méthode pour récupérer l'UID de l'utilisateur après vérification SMS et vérifier s'il existe dans Firestore
  Future<void> checkUserAndRedirect(String email) async {

    User? user = _auth.currentUser;

    if (user != null && user.phoneNumber != null) {
      // Récupérer l'UID de l'utilisateur actuel
      String uid = user.uid;

      // La connexion par téléphone est abandonnée : plus de collection de réservation à consulter.
      loading = false;
    } else {
      // L'utilisateur n'est pas connecté ou le numéro de téléphone n'est pas disponible

    }
  }

  showSuccessDialog(BuildContext context) {
    showStatusDialog(context, type: StatusDialogType.success, title: 'Succes', desc: AppLocalizations.of(context).otpVerificationSuccess);

  }
  showErrorDialog(BuildContext context) {
    showStatusDialog(context, type: StatusDialogType.error, title: 'Error', desc: AppLocalizations.of(context).otpVerificationError);

  }
  showWarningDialog(BuildContext context,String msg) {
    showStatusDialog(context, type: StatusDialogType.warning, title: 'Warning', desc: msg);

  }

  @override
  void initState() {
    super.initState();
    decompte();
  }

  late Timer timer;

  void decompte() {
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (count < 1) {
        timer.cancel();
        count = 20;
        resend = true;
        setState(() {});
        return;
      }
      count--;
      setState(() {});
    });
  }

  void onResendSmsCode() {
    resend = false;
    setState(() {});
    authWithPhoneNumber(widget.phoneNumber, onCodeSend: (verificationId, v) {
      loading = false;
      decompte();
      setState(() {});
    }, onAutoVerify: (v) async {
      await _auth.signInWithCredential(v);
      Navigator.of(context).pop();
    }, onFailed: (e) {
      loading = false;
      setState(() {});
      showErrorDialog(_scaffoldKey!.currentContext!);
      printVm("Le code est erroné");
    }, autoRetrieval: (v) {});
  }

  void onVerifySmsCode() async {
    loading = true;
    setState(() {});
    await validateOtp(smsCode, widget.verificationId);
    loading = false;
    setState(() {});
    showSuccessDialog(_scaffoldKey!.currentContext!);
    //checkUserAndRedirect("${widget.phoneNumber!}"+"@gmail.com");
    // Navigator.of(context).pop();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) {
          return SignUpFormEtap3();
        },
      ),
    );

  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
          elevation:0,
          actions: const [Padding(padding: EdgeInsets.only(right: 12), child: Center(child: LanguageSelectorButton()))],
        ),
      backgroundColor: colors.background,
      body: WillPopScope(
        onWillPop: () async {
          return true;
        },
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: Column(
              children: [
                SizedBox(
                    height: MediaQuery.of(context).size.height*0.2,
                    child: Image.asset(
                      "assets/logo/afrolook_logo.png",
                      fit: BoxFit.contain,
                    )
                ),

                Text(
                  l10n.otpVerificationTitle,
                  style: TextStyle(
                    fontSize: 30,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(
                  height: 10,
                ),
                Text(
                  "${l10n.otpVerificationDesc} ${widget.phoneNumber}",
                  style: TextStyle(
                    fontSize: 14,
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(
                  height: 40,
                ),
                Pinput(
                  length: 6,
                  onChanged: (value) {
                    smsCode = value;
                    setState(() {});
                  },
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: !resend ? null : onResendSmsCode,
                    child: Text(!resend
                        ? "00:${count.toString().padLeft(2, "0")}"
                        : l10n.otpResendCode, style: TextStyle(color: colors.primary),),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 15)),
                      onPressed: smsCode.length < 6 || loading
                          ? null
                          : onVerifySmsCode,
                      child: loading
                          ? CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation(colors.onPrimary),
                      )
                          : Text(
                        l10n.otpVerify,
                        style: TextStyle(fontSize: 20, color: colors.primary),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
