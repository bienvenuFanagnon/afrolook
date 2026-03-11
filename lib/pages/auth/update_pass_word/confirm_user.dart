import 'package:afrotok/pages/auth/update_pass_word/confirm_verification_otp.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  bool _isLoading = false;
  bool _isButtonDisabled = false;
  int _requestCount = 0;
  DateTime? _lastRequestTime;

  final TextEditingController telephoneController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  late UserAuthProvider authProvider;

  // Constantes pour les limites
  static const int MAX_REQUESTS_PER_DAY = 3;
  static const int MIN_INTERVAL_MINUTES = 30;

  // Constantes de couleurs
  static const Color blackColor = Color(0xFF000000);
  static const Color redColor = Color(0xFFD32F2F);
  static const Color yellowColor = Color(0xFFFFC107);
  static const Color lightRedColor = Color(0xFFFFEBEE);
  static const Color lightYellowColor = Color(0xFFFFF8E1);

  @override
  void initState() {
    super.initState();
    authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    _loadRequestData();
  }

  Future<void> _loadRequestData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _requestCount = prefs.getInt('requestCount') ?? 0;
      final lastRequestTimestamp = prefs.getInt('lastRequestTime');
      if (lastRequestTimestamp != null) {
        _lastRequestTime = DateTime.fromMillisecondsSinceEpoch(lastRequestTimestamp);
      }
      _checkIfButtonShouldBeDisabled();
    });
  }

  Future<void> _saveRequestData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('requestCount', _requestCount);
    await prefs.setInt('lastRequestTime', DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> _resetDailyCount() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('requestCount', 0);
    setState(() {
      _requestCount = 0;
    });
  }

  bool _checkIfButtonShouldBeDisabled() {
    if (_lastRequestTime != null) {
      final difference = DateTime.now().difference(_lastRequestTime!);
      if (difference.inMinutes < MIN_INTERVAL_MINUTES) {
        _isButtonDisabled = true;
        return true;
      }
    }

    // Vérifier si c'est un nouveau jour (reset du compteur)
    if (_lastRequestTime != null) {
      final now = DateTime.now();
      if (now.day != _lastRequestTime!.day ||
          now.month != _lastRequestTime!.month ||
          now.year != _lastRequestTime!.year) {
        _resetDailyCount();
      }
    }

    _isButtonDisabled = _requestCount >= MAX_REQUESTS_PER_DAY;
    return _isButtonDisabled;
  }

  void showErrorDialog(BuildContext context, String text) {
    AwesomeDialog(
      context: context,
      animType: AnimType.leftSlide,
      headerAnimationLoop: true,
      dialogType: DialogType.error,
      showCloseIcon: true,
      title: "Envoi code SMS",
      desc: text,
      btnCancelOnPress: () {
        debugPrint('OnClcik');
      },
      btnOkIcon: Icons.error,
      onDismissCallback: (type) {
        debugPrint('Dialog Dissmiss from callback $type');
      },
    ).show();
  }

  void sendOtpCode() {
    setState(() {
      _isLoading = true;
    });

    final _auth = FirebaseAuth.instance;
    if (telephoneController.text.isNotEmpty) {
      authWithPhoneNumber(
        telephoneController.text!,
        onCodeSend: (verificationId, v) {
          setState(() {
            _isLoading = false;
          });
          Navigator.of(context).push(MaterialPageRoute(
            builder: (c) => ConfirmVerificationOtp(
              verificationId: verificationId,
              phoneNumber: telephoneController.text!,
            ),
          ));
        },
        onAutoVerify: (v) async {
          await _auth.signInWithCredential(v);
          Navigator.of(context).pop();
        },
        onFailed: (e) {
          setState(() {
            _isLoading = false;
          });
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
          }
          showErrorDialog(context, errorMessage);
          print(" erreur : ${e.toString()}");
        },
        autoRetrieval: (v) {},
      );
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  bool isValidEmail(String email) {
    final RegExp emailRegExp = RegExp(
        r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$");
    return emailRegExp.hasMatch(email);
  }

  void _showInstructionsModal() {
    showDialog(
      context: context,
      barrierDismissible: false, // L'utilisateur doit fermer manuellement
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Instructions importantes',
            style: TextStyle(
              color: blackColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: const BoxDecoration(
                    color: lightYellowColor,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.mark_email_read,
                    color: redColor,
                    size: 50,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Un email de réinitialisation a été envoyé à votre adresse.',
                  style: TextStyle(fontSize: 16, color: blackColor),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 15),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: lightRedColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: redColor.withOpacity(0.3)),
                  ),
                  child: const Column(
                    children: [
                      Text(
                        'Vérifications importantes :',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: redColor,
                        ),
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.check_circle, color: yellowColor, size: 16),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Consultez votre boîte de réception',
                              style: TextStyle(fontSize: 14, color: blackColor),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Icon(Icons.warning, color: yellowColor, size: 16),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Vérifiez également vos spams / courriers indésirables',
                              style: TextStyle(fontSize: 14, color: blackColor),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            Center(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Fermeture manuelle par l'utilisateur
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: yellowColor,
                  foregroundColor: blackColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                ),
                child: const Text(
                  'J\'ai compris',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _sendResetEmail() async {
    // Validation de l'email
    if (emailController.text.isEmpty) {
      _showSnackBar('L\'email est obligatoire', isError: true);
      return;
    }

    if (!isValidEmail(emailController.text)) {
      _showSnackBar('Format d\'email invalide', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: emailController.text.trim(),
      );

      // Mise à jour des compteurs
      setState(() {
        _requestCount++;
        _lastRequestTime = DateTime.now();
        _checkIfButtonShouldBeDisabled();
      });

      await _saveRequestData();

      // Afficher le modal d'instructions (l'utilisateur doit le fermer)
      _showInstructionsModal();

    } catch (error) {
      _showSnackBar(
        'Erreur lors de l\'envoi. Veuillez réessayer.',
        isError: true,
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: isError ? redColor : blackColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  String _getButtonDisabledReason() {
    if (_requestCount >= MAX_REQUESTS_PER_DAY) {
      return 'Limite journalière atteinte (3/3)';
    }
    if (_lastRequestTime != null) {
      final minutesLeft = MIN_INTERVAL_MINUTES -
          DateTime.now().difference(_lastRequestTime!).inMinutes;
      if (minutesLeft > 0) {
        return 'Réessayez dans $minutesLeft min';
      }
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Réinitialisation du mot de passe',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: blackColor,
        foregroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // En-tête avec illustration
              Container(
                height: 120,
                margin: const EdgeInsets.only(bottom: 30),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: lightRedColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const Icon(
                      Icons.lock_reset,
                      size: 60,
                      color: yellowColor,
                    ),
                  ],
                ),
              ),

              // Texte d'information
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: lightYellowColor,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: yellowColor,
                    width: 1,
                  ),
                ),
                child: const Text(
                  "Un lien de réinitialisation vous sera envoyé par email. "
                      "Vérifiez votre boîte de réception et vos spams.",
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: blackColor,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 30),

              // Champ email
              TextFormField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                cursorColor: redColor,
                decoration: InputDecoration(
                  labelText: "Adresse email",
                  labelStyle: const TextStyle(
                    color: blackColor,
                    fontWeight: FontWeight.w500,
                  ),
                  hintText: "exemple@email.com",
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                  prefixIcon: const Icon(
                    Icons.email_outlined,
                    color: redColor,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide(
                      color: blackColor.withOpacity(0.3),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: const BorderSide(
                      color: redColor,
                      width: 2,
                    ),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: const BorderSide(color: redColor),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),

              const SizedBox(height: 20),

              // Champ téléphone (optionnel - décommenter si nécessaire)
              // IntlPhoneField(
              //   controller: telephoneController,
              //   cursorColor: redColor,
              //   decoration: InputDecoration(
              //     labelText: 'Numéro de téléphone',
              //     labelStyle: const TextStyle(color: blackColor),
              //     hintText: 'Téléphone',
              //     enabledBorder: OutlineInputBorder(
              //       borderRadius: BorderRadius.circular(15),
              //       borderSide: BorderSide(
              //         color: blackColor.withOpacity(0.3),
              //       ),
              //     ),
              //     focusedBorder: OutlineInputBorder(
              //       borderRadius: BorderRadius.circular(15),
              //       borderSide: const BorderSide(color: redColor, width: 2),
              //     ),
              //     prefixIcon: const Icon(Icons.phone, color: redColor),
              //     filled: true,
              //     fillColor: Colors.white,
              //   ),
              //   initialCountryCode: 'TG',
              //   onChanged: (phone) {
              //     telephoneController.text = phone.completeNumber;
              //   },
              // ),

              const SizedBox(height: 20),

              // Indicateur de limite
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: lightYellowColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: yellowColor),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Requêtes aujourd\'hui :',
                      style: TextStyle(
                        color: blackColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _requestCount < MAX_REQUESTS_PER_DAY
                            ? yellowColor
                            : redColor,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Text(
                        '$_requestCount/$MAX_REQUESTS_PER_DAY',
                        style: const TextStyle(
                          color: blackColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (_isButtonDisabled) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: lightRedColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: redColor),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: redColor,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _getButtonDisabledReason(),
                          style: TextStyle(
                            color: redColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 30),

              // Bouton de confirmation (email)
              ElevatedButton(
                onPressed: _isLoading || _isButtonDisabled ? null : _sendResetEmail,
                style: ElevatedButton.styleFrom(
                  backgroundColor: blackColor,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  disabledForegroundColor: Colors.grey.shade600,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  elevation: 3,
                ),
                child: _isLoading
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    color: yellowColor,
                    strokeWidth: 2,
                  ),
                )
                    : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.email, color: yellowColor),
                    const SizedBox(width: 10),
                    Text(
                      _isButtonDisabled ? 'Limite atteinte' : 'Envoyer par email',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 15),

              // Bouton de confirmation (SMS) - optionnel
              // if (telephoneController.text.isNotEmpty)
              //   ElevatedButton(
              //     onPressed: _isLoading || _isButtonDisabled ? null : sendOtpCode,
              //     style: ElevatedButton.styleFrom(
              //       backgroundColor: redColor,
              //       foregroundColor: Colors.white,
              //       disabledBackgroundColor: Colors.grey.shade300,
              //       padding: const EdgeInsets.symmetric(vertical: 16),
              //       shape: RoundedRectangleBorder(
              //         borderRadius: BorderRadius.circular(15),
              //       ),
              //     ),
              //     child: _isLoading
              //         ? const SizedBox(
              //             height: 20,
              //             width: 20,
              //             child: CircularProgressIndicator(
              //               color: yellowColor,
              //               strokeWidth: 2,
              //             ),
              //           )
              //         : Row(
              //             mainAxisAlignment: MainAxisAlignment.center,
              //             children: [
              //               const Icon(Icons.sms, color: yellowColor),
              //               const SizedBox(width: 10),
              //               Text(
              //                 _isButtonDisabled ? 'Limite atteinte' : 'Envoyer par SMS',
              //                 style: const TextStyle(
              //                   fontSize: 16,
              //                   fontWeight: FontWeight.w600,
              //                 ),
              //               ),
              //             ],
              //           ),
              //   ),

              const SizedBox(height: 20),

              // Note de sécurité
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: lightRedColor.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: redColor.withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.security,
                      color: blackColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Limite de sécurité : $MAX_REQUESTS_PER_DAY demandes par jour, '
                            'avec un intervalle de $MIN_INTERVAL_MINUTES minutes entre chaque envoi.',
                        style: const TextStyle(
                          fontSize: 12,
                          color: blackColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


//
// import 'package:afrotok/pages/auth/update_pass_word/confirm_verification_otp.dart';
// import 'package:awesome_dialog/awesome_dialog.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';
// import 'package:intl_phone_field/intl_phone_field.dart';
// import 'package:provider/provider.dart';
//
// import '../../../providers/authProvider.dart';
// import '../authTest/Screens/Signup/function.dart';
// import '../authTest/Screens/Signup/verificationOtps.dart';
// import '../authTest/constants.dart';
//
// class ConfirmUser extends StatefulWidget {
//   const ConfirmUser({Key? key}) : super(key: key);
//
//   @override
//   State<ConfirmUser> createState() => _ConfirmUserState();
// }
//
// class _ConfirmUserState extends State<ConfirmUser> {
//   bool onTap=false;
//   final TextEditingController telephoneController = TextEditingController();
//   final TextEditingController emailController = TextEditingController();
//   late UserAuthProvider authProvider =
//   Provider.of<UserAuthProvider>(context, listen: false);
//   showErrorDialog(BuildContext context,String text) {
//     AwesomeDialog(
//       context: context,
//       animType: AnimType.leftSlide,
//       headerAnimationLoop: true,
//       dialogType: DialogType.error,
//       showCloseIcon: true,
//       title: "Envoi code SMS",
//       desc:
//       text,
//       btnCancelOnPress: () {
//         debugPrint('OnClcik');
//       },
//       btnOkIcon: Icons.error,
//       onDismissCallback: (type) {
//         debugPrint('Dialog Dissmiss from callback $type');
//       },
//     ).show();
//
//   }
//
//   void
//   sendOtpCode() {
//     onTap = true;
//     setState(() {});
//     final _auth = FirebaseAuth.instance;
//     if (telephoneController.text.isNotEmpty) {
//
//       // notData=false;
//
//       authWithPhoneNumber(telephoneController.text!, onCodeSend: (verificationId, v) {
//         onTap = false;
//         setState(() {});
//         Navigator.of(context).push(MaterialPageRoute(
//             builder: (c) => ConfirmVerificationOtp(
//               verificationId: verificationId,
//               phoneNumber: telephoneController.text!,
//             )));
//       }, onAutoVerify: (v) async {
//         await _auth.signInWithCredential(v);
//
//         Navigator.of(context).pop();
//       },  onFailed: (e) {
//         onTap = false;
//         setState(() {});
//         var errorMessage = "An error occurred";
//         switch (e.code) {
//           case 'invalid-phone-number':
//             errorMessage = 'Le numéro de téléphone saisi est invalide.';
//             break;
//           case 'too-many-requests':
//             errorMessage = 'Vous avez fait trop de demandes. Veuillez réessayer plus tard.';
//             break;
//           default:
//             errorMessage = 'Une erreur inconnue est survenue. Veuillez réessayer plus tard';
//         //errorMessage = e.toString();
//         }
//         showErrorDialog( context, errorMessage);
//         print(" erreur : ${e.toString()}");
//       }, autoRetrieval: (v) {});
//     }else{
//       onTap = false;
//       // notData=true;
//       setState(() {
//
//       });
//     }
//   }
//
//   bool isValidEmail(String email) {
//     final RegExp emailRegExp = RegExp(
//         r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$");
//     return emailRegExp.hasMatch(email);
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         // title: const Text('Confirmation'),
//         title: const Text('Changement de mot de passe',style: TextStyle(fontSize: 18),),
//       ),
//       body: Center(
//         child: Padding(
//           padding: const EdgeInsets.all(15.0),
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               const Text(
//                 "Un lien pour réinitialiser votre mot de passe vous sera envoyer "
//                     "Veuillez vérifier votre boîte de réception (et éventuellement vos spams).",
//                 style: TextStyle(fontSize: 18),
//               ),
//               const SizedBox(height: 20),
//               TextFormField(
//                 controller: emailController,
//                 keyboardType: TextInputType.text,
//                 textInputAction: TextInputAction.next,
//                 cursorColor: kPrimaryColor,
//                 validator: (value)  {
//                   if (value!.isEmpty) {
//                     return 'Le champ "Email" est obligatoire.';
//                   }
//                   if (!isValidEmail(value)) {
//                     return 'Email invalide';
//                   }
//                   return null;
//                 },
//                 onSaved: (email) {},
//                 decoration: const InputDecoration(
//                   focusColor: kPrimaryColor,
//                   focusedBorder: UnderlineInputBorder(
//                       borderSide: BorderSide(color: kPrimaryColor)),
//                   hintText: "Email",
//                   prefixIcon: Padding(
//                     padding: EdgeInsets.all(defaultPadding),
//                     child: Icon(Icons.email),
//                   ),
//                 ),
//               ),
//               // IntlPhoneField(
//               //   //controller: telephoneController,
//               //   // invalidNumberMessage:'numero invalide' ,
//               //   onTap: () {
//               //
//               //   },
//               //
//               //   cursorColor: kPrimaryColor,
//               //   decoration: InputDecoration(
//               //     hintText: 'Téléphone',
//               //     focusColor: kPrimaryColor,
//               //     focusedBorder: UnderlineInputBorder(
//               //         borderSide: BorderSide(color: kPrimaryColor)),
//               //
//               //   ),
//               //   initialCountryCode: 'TG',
//               //   onChanged: (phone) {
//               //     telephoneController.text=phone.completeNumber;
//               //     print(phone.completeNumber);
//               //   },
//               //   onCountryChanged: (country) {
//               //     print('Country changed to: ' + country.name);
//               //   },
//               //   validator: (value) {
//               //     if (value!.completeNumber.isEmpty) {
//               //       return 'Le champ "Téléphone" est obligatoire.';
//               //     }
//               //
//               //     return null;
//               //   },
//               //
//               // ),
//               const SizedBox(height: 40),
//               ElevatedButton(
//                 onPressed:onTap?() {
//
//                 }: () async {
//                   setState(() {
//                     onTap=true;
//                   });
//                   if (emailController.text.isNotEmpty) {
//
//     FirebaseAuth.instance.sendPasswordResetEmail(email: emailController.text).then((_) {
//       SnackBar snackBar = SnackBar(
//         // duration: ,
//         content: Text("Un email vous a été envoyé à l'adresse ${emailController.text} avec un lien pour réinitialiser votre mot de passe. "
//             "Veuillez vérifier votre boîte de réception (et éventuellement vos spams).",textAlign: TextAlign.center,style: TextStyle(color: Colors.green),),
//       );
//       ScaffoldMessenger.of(context).showSnackBar(snackBar);
//     }).catchError((error) {
//       SnackBar snackBar = SnackBar(
//         content: Text("Une erreur s'est produite lors de l'envoi de l'email de réinitialisation."
//             " Veuillez réessayer ultérieurement ou contacter notre support.",textAlign: TextAlign.center,style: TextStyle(color: Colors.red),),
//       );
//       ScaffoldMessenger.of(context).showSnackBar(snackBar);
//     } );
//     setState(() {
//       onTap=false;
//     });
//                   // await  authProvider.getUserByPhone( telephoneController.text).then((value) {
//                   //     if (value) {
//                   //       sendOtpCode();
//                   //     }  else{
//                   //       SnackBar snackBar = SnackBar(
//                   //         content: Text("Ce compte n'existe pas",textAlign: TextAlign.center,style: TextStyle(color: Colors.red),),
//                   //       );
//                   //       ScaffoldMessenger.of(context).showSnackBar(snackBar);
//                   //       setState(() {
//                   //         onTap=false;
//                   //       });
//                   //     }
//                   //
//                   //   },);
//
//                   }  else{
//                     SnackBar snackBar = SnackBar(
//                       content: Text('email est obligatoire',textAlign: TextAlign.center,style: TextStyle(color: Colors.red),),
//                     );
//                     ScaffoldMessenger.of(context).showSnackBar(snackBar);
//                     setState(() {
//                       onTap=false;
//                     });
//                   }
//
//                   // TODO: Implémenter la logique de confirmation
//                 },
//                 child: onTap?Container(
//                     width: 20,
//                     height: 20,
//                     child: CircularProgressIndicator()): Text('Confirmer'),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
