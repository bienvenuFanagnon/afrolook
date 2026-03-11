import 'package:afrotok/pages/component/consoleWidget.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../../providers/authProvider.dart';
import '../components/already_have_an_account_acheck.dart';
import '../constants.dart';
import 'Login/components/login_screen_top_image.dart';
import 'Signup/components/signup_form.dart';
import 'Signup/signup_screen.dart';

class LoginPages extends StatefulWidget {
  LoginPages({
    Key? key,
  }) : super(key: key);

  @override
  State<LoginPages> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPages> {
  late UserAuthProvider authProvider =
  Provider.of<UserAuthProvider>(context, listen: false);

  late TextEditingController telephoneController = TextEditingController();
  late TextEditingController motDePasseController = TextEditingController();
  late GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late bool onboutonTap = false;
  late bool tap = false;
  late bool inputTap = false;

  final _auth = FirebaseAuth.instance;

  // Variables pour la limitation des envois d'email de vérification
  int _verificationRequestCount = 0;
  DateTime? _lastVerificationRequestTime;
  bool _isVerificationButtonDisabled = false;

  // Constantes pour les limites
  static const int MAX_VERIFICATION_REQUESTS_PER_DAY = 3;
  static const int MIN_VERIFICATION_INTERVAL_MINUTES = 30;

  // Constantes de couleurs
  static const Color blackColor = Color(0xFF000000);
  static const Color redColor = Color(0xFFD32F2F);
  static const Color yellowColor = Color(0xFFFFC107);
  static const Color lightRedColor = Color(0xFFFFEBEE);
  static const Color lightYellowColor = Color(0xFFFFF8E1);

  // string for displaying the error Message
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadVerificationRequestData();
  }

  Future<void> _loadVerificationRequestData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _verificationRequestCount = prefs.getInt('verificationRequestCount') ?? 0;
      final lastRequestTimestamp = prefs.getInt('lastVerificationRequestTime');
      if (lastRequestTimestamp != null) {
        _lastVerificationRequestTime = DateTime.fromMillisecondsSinceEpoch(lastRequestTimestamp);
      }
      _checkIfVerificationButtonShouldBeDisabled();
    });
  }

  Future<void> _saveVerificationRequestData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('verificationRequestCount', _verificationRequestCount);
    await prefs.setInt('lastVerificationRequestTime', DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> _resetDailyVerificationCount() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('verificationRequestCount', 0);
    setState(() {
      _verificationRequestCount = 0;
    });
  }

  bool _checkIfVerificationButtonShouldBeDisabled() {
    if (_lastVerificationRequestTime != null) {
      final difference = DateTime.now().difference(_lastVerificationRequestTime!);
      if (difference.inMinutes < MIN_VERIFICATION_INTERVAL_MINUTES) {
        _isVerificationButtonDisabled = true;
        return true;
      }
    }

    // Vérifier si c'est un nouveau jour (reset du compteur)
    if (_lastVerificationRequestTime != null) {
      final now = DateTime.now();
      if (now.day != _lastVerificationRequestTime!.day ||
          now.month != _lastVerificationRequestTime!.month ||
          now.year != _lastVerificationRequestTime!.year) {
        _resetDailyVerificationCount();
      }
    }

    _isVerificationButtonDisabled = _verificationRequestCount >= MAX_VERIFICATION_REQUESTS_PER_DAY;
    return _isVerificationButtonDisabled;
  }

  String _getVerificationButtonDisabledReason() {
    if (_verificationRequestCount >= MAX_VERIFICATION_REQUESTS_PER_DAY) {
      return 'Limite journalière atteinte (3/3)';
    }
    if (_lastVerificationRequestTime != null) {
      final minutesLeft = MIN_VERIFICATION_INTERVAL_MINUTES -
          DateTime.now().difference(_lastVerificationRequestTime!).inMinutes;
      if (minutesLeft > 0) {
        return 'Réessayez dans $minutesLeft min';
      }
    }
    return '';
  }

  void signIn(String email, String password) async {
    setState(() {
      inputTap = false;
    });

    if (!_formKey.currentState!.validate()) return;

    setState(() {
      tap = true;
    });

    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user == null) throw FirebaseAuthException(code: 'user-null', message: 'Utilisateur introuvable');

      await user.reload(); // Recharge les infos de l'utilisateur
      printVm('data');

      if (!user.emailVerified) {
        setState(() => tap = false);
        // Si email non vérifié, afficher modal
        _showEmailVerificationModal(user);
        return;
      }

      // Si email vérifié, continuer la connexion
      if (await authProvider.getLoginUser(user.uid)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Connexion réussie',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.green),
            ),
          ),
        );
        Navigator.pushNamed(context, '/home');
        Navigator.pushNamed(context, '/chargement');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Erreur de chargement',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red),
            ),
          ),
        );
      }

      setState(() {
        telephoneController.clear();
        motDePasseController.clear();
        tap = false;
      });
    } on FirebaseAuthException catch (error) {
      setState(() => tap = false);

      switch (error.code) {
        case "invalid-email":
          errorMessage = "Votre email semble malformé.";
          break;
        case "wrong-password":
          errorMessage = "Mot de passe incorrect.";
          break;
        case "user-not-found":
          errorMessage = "Utilisateur introuvable.";
          break;
        case "user-disabled":
          errorMessage = "Ce compte a été désactivé.";
          break;
        case "too-many-requests":
          errorMessage = "Trop de tentatives. Réessayez plus tard.";
          break;
        case "operation-not-allowed":
          errorMessage = "Connexion par email et mot de passe non activée.";
          break;
        default:
          errorMessage = "Une erreur inconnue est survenue.";
      }

      _showSnackBar(errorMessage!, isError: true);
      print(error.code);
    }
  }

  void _showEmailVerificationModal(User user) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.email_outlined, color: yellowColor, size: 28),
            SizedBox(width: 10),
            Text(
              "Email non vérifié",
              style: TextStyle(color: blackColor, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: lightYellowColor,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.mark_email_unread, color: redColor, size: 40),
            ),
            SizedBox(height: 15),
            Text(
              "Votre adresse email n'a pas encore été vérifiée.",
              textAlign: TextAlign.center,
              style: TextStyle(color: blackColor, fontSize: 16),
            ),
            SizedBox(height: 10),
            Text(
              "Veuillez cliquer sur le lien de vérification qui vous sera envoyé.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[700], fontSize: 14),
            ),
            SizedBox(height: 15),

            // Indicateur de limite pour la vérification
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: lightYellowColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: yellowColor),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Envois aujourd\'hui :',
                    style: TextStyle(color: blackColor, fontWeight: FontWeight.w500),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _verificationRequestCount < MAX_VERIFICATION_REQUESTS_PER_DAY
                          ? yellowColor
                          : redColor,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Text(
                      '$_verificationRequestCount/$MAX_VERIFICATION_REQUESTS_PER_DAY',
                      style: TextStyle(color: blackColor, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),

            if (_isVerificationButtonDisabled) ...[
              SizedBox(height: 10),
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: lightRedColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: redColor),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: redColor, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _getVerificationButtonDisabledReason(),
                        style: TextStyle(color: redColor, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            SizedBox(height: 20),

            ElevatedButton.icon(
              onPressed: _isVerificationButtonDisabled
                  ? null
                  : () async {
                await _sendEmailVerification(user);
                Navigator.pop(context);
              },
              icon: Icon(Icons.send),
              label: Text("Renvoyer le lien de vérification"),
              style: ElevatedButton.styleFrom(
                backgroundColor: blackColor,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                disabledForegroundColor: Colors.grey.shade600,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),

            SizedBox(height: 10),

            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                foregroundColor: redColor,
              ),
              child: Text("Annuler"),
            )
          ],
        ),
      ),
    );
  }

  Future<void> _sendEmailVerification(User user) async {
    try {
      await user.sendEmailVerification();

      // Mise à jour des compteurs
      setState(() {
        _verificationRequestCount++;
        _lastVerificationRequestTime = DateTime.now();
        _checkIfVerificationButtonShouldBeDisabled();
      });

      await _saveVerificationRequestData();

      _showSnackBar(
        "Lien de vérification envoyé ! Vérifiez votre boîte mail.",
        isError: false,
      );

    } catch (e) {
      _showSnackBar(
        "Erreur lors de l'envoi. Veuillez réessayer.",
        isError: true,
      );
    }
  }

  void signIn2(String email, String password) async {
    setState(() {
      inputTap = false;
    });
    if (_formKey.currentState!.validate()) {
      setState(() {
        tap = true;
      });
      try {
        await _auth
            .signInWithEmailAndPassword(email: email, password: password)
            .then((uid) async => {
          if (await authProvider.getLoginUser(uid.user!.uid!))
            {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Connexion réussie',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.green),
                  ),
                ),
              ),
              Navigator.pushNamed(context, '/home'),
              Navigator.pushNamed(context, '/chargement'),
            }
          else
            {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Erreur de Chargement',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ),
            },
          setState(() {
            telephoneController.clear();
            motDePasseController.clear();
            tap = false;
          }),
        });
      } on FirebaseAuthException catch (error) {
        setState(() {
          tap = false;
        });
        switch (error.code) {
          case "invalid-email":
            errorMessage = "Votre numero semble être malformée.";
            break;
          case "wrong-password":
            errorMessage = "Votre mot de passe est erroné.";
            break;
          case "user-not-found":
            errorMessage = "L'utilisateur avec cet numero n'existe pas.";
            break;
          case "user-disabled":
            errorMessage = "L'utilisateur avec cet numero a été désactivé.";
            break;
          case "too-many-requests":
            errorMessage = "Trop de demandes";
            break;
          case "operation-not-allowed":
            errorMessage = "La connexion avec le numero et un mot de passe n'est pas activée.";
            break;
          default:
            errorMessage = "Une erreur indéfinie s'est produite.";
        }
        _showSnackBar(errorMessage!, isError: true);
        print(error.code);
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: isError ? redColor : blackColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(15.0),
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: SizedBox(
            height: height,
            width: width,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                LoginScreenTopImage(),
                Spacer(),
                Expanded(
                  flex: 8,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 25.0, left: 25, right: 25),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              // Champ téléphone avec style noir/rouge
                              IntlPhoneField(
                                cursorColor: redColor,
                                decoration: InputDecoration(
                                  hintText: 'Téléphone',
                                  hintStyle: TextStyle(color: Colors.grey.shade400),
                                  labelText: 'Numéro de téléphone',
                                  labelStyle: TextStyle(color: blackColor),
                                  focusColor: redColor,
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(15),
                                    borderSide: BorderSide(color: redColor, width: 2),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(15),
                                    borderSide: BorderSide(color: blackColor.withOpacity(0.3)),
                                  ),
                                  errorBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(15),
                                    borderSide: BorderSide(color: redColor),
                                  ),
                                  prefixIcon: Icon(Icons.phone, color: redColor),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                                initialCountryCode: 'TG',
                                onChanged: (phone) {
                                  telephoneController.text = phone.completeNumber;
                                  print(phone.completeNumber);
                                },
                                onCountryChanged: (country) {
                                  print('Country changed to: ' + country.name);
                                },
                                validator: (value) {
                                  if (value!.completeNumber.isEmpty) {
                                    return 'Le champ "Téléphone" est obligatoire.';
                                  }
                                  return null;
                                },
                              ),
                              SizedBox(height: 15),

                              // Champ mot de passe avec style noir/rouge
                              TextFormField(
                                controller: motDePasseController,
                                textInputAction: TextInputAction.done,
                                obscureText: true,
                                cursorColor: redColor,
                                decoration: InputDecoration(
                                  labelText: "Mot de passe",
                                  labelStyle: TextStyle(color: blackColor),
                                  hintText: "Votre mot de passe",
                                  hintStyle: TextStyle(color: Colors.grey.shade400),
                                  focusColor: redColor,
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(15),
                                    borderSide: BorderSide(color: redColor, width: 2),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(15),
                                    borderSide: BorderSide(color: blackColor.withOpacity(0.3)),
                                  ),
                                  errorBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(15),
                                    borderSide: BorderSide(color: redColor),
                                  ),
                                  prefixIcon: Icon(Icons.lock, color: redColor),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                                validator: (value) {
                                  if (value!.isEmpty) {
                                    return 'Le champ "Mot de passe" est obligatoire.';
                                  }
                                  if (value!.length < 6) {
                                    return 'Le mot de passe doit comporter au moins 6 caractères.';
                                  }
                                  return null;
                                },
                              ),

                              SizedBox(height: height * 0.1),

                              // Bouton de connexion
                              Container(
                                width: width * 0.7,
                                child: ElevatedButton(
                                  onPressed: tap
                                      ? () {}
                                      : () {
                                    setState(() {
                                      tap = true;
                                    });
                                    if (_formKey.currentState!.validate()) {
                                      if (telephoneController.text.isNotEmpty) {
                                        signIn(
                                          '${telephoneController.text}@gmail.com',
                                          motDePasseController.text,
                                        );
                                      } else {
                                        _showSnackBar('Numéro de téléphone invalide', isError: true);
                                        setState(() {
                                          tap = false;
                                        });
                                      }
                                    } else {
                                      setState(() {
                                        tap = false;
                                      });
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: blackColor,
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    elevation: 3,
                                  ),
                                  child: tap
                                      ? LoadingAnimationWidget.flickr(
                                    size: 30,
                                    leftDotColor: yellowColor,
                                    rightDotColor: redColor,
                                  )
                                      : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.login, color: yellowColor),
                                      SizedBox(width: 10),
                                      Text(
                                        "Se connecter",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              const SizedBox(height: defaultPadding),

                              AlreadyHaveAnAccountCheck(
                                press: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) {
                                        return SignUpScreen();
                                      },
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
//
//
// import 'package:afrotok/pages/component/consoleWidget.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';
// import 'package:intl_phone_field/intl_phone_field.dart';
// import 'package:loading_animation_widget/loading_animation_widget.dart';
// import 'package:provider/provider.dart';
//
// import '../../../../../providers/authProvider.dart';
//
// import '../components/already_have_an_account_acheck.dart';
// import '../constants.dart';
// import 'Login/components/login_screen_top_image.dart';
// import 'Signup/components/signup_form.dart';
// import 'Signup/signup_screen.dart';
//
//
// class LoginPages extends StatefulWidget {
//
//   LoginPages({
//     Key? key,
//   }) : super(key: key);
//   @override
//   State<LoginPages> createState() => _LoginPageState();
// }
//
// class _LoginPageState extends State<LoginPages> {
//   late UserAuthProvider authProvider =
//   Provider.of<UserAuthProvider>(context, listen: false);
//
//   late TextEditingController telephoneController = TextEditingController();
//
//   late TextEditingController motDePasseController = TextEditingController();
//
//   late GlobalKey<FormState> _formKey = GlobalKey<FormState>();
//
//   late bool onboutonTap=false;
//
//   late bool tap=false;
//   late bool inputTap= false;
//   final _auth = FirebaseAuth.instance;
//
//
//
//   // string for displaying the error Message
//   String? errorMessage;
//   void signIn(String email, String password) async {
//     setState(() {
//       inputTap = false;
//     });
//
//     if (!_formKey.currentState!.validate()) return;
//
//     setState(() {
//       tap = true;
//     });
//
//     try {
//       final userCredential = await _auth.signInWithEmailAndPassword(
//         email: email,
//         password: password,
//       );
//
//       final user = userCredential.user;
//       if (user == null) throw FirebaseAuthException(code: 'user-null', message: 'Utilisateur introuvable');
//
//       await user.reload(); // Recharge les infos de l'utilisateur
//       printVm('data');
//       if (!user.emailVerified) {
//         // Si email non vérifié, afficher modal
//         showDialog(
//           context: context,
//           barrierDismissible: false,
//           builder: (context) => AlertDialog(
//             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//             title: Row(
//               children: [
//                 Icon(Icons.email_outlined, color: Colors.orange, size: 28),
//                 SizedBox(width: 10),
//                 Text("Email non vérifié"),
//               ],
//             ),
//             content: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Text(
//                   "Votre adresse email n'a pas encore été vérifiée. "
//                       "Veuillez cliquer sur le lien que nous allons vous renvoyer.",
//                   textAlign: TextAlign.center,
//                 ),
//                 SizedBox(height: 20),
//                 ElevatedButton.icon(
//                   onPressed: () async {
//                     await user.sendEmailVerification();
//                     Navigator.pop(context);
//                     ScaffoldMessenger.of(context).showSnackBar(
//                       SnackBar(
//                         content: Text(
//                           "Lien de vérification envoyé ! Vérifiez votre boîte mail.",
//                           textAlign: TextAlign.center,
//                         ),
//                         backgroundColor: Colors.green,
//                       ),
//                     );
//                   },
//                   icon: Icon(Icons.send),
//                   label: Text("Renvoyer le lien de vérification"),
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: Colors.orange,
//                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
//                     padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
//                     textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
//                   ),
//                 ),
//                 SizedBox(height: 10),
//                 TextButton(
//                   onPressed: () => Navigator.pop(context),
//                   child: Text("Annuler", style: TextStyle(color: Colors.grey[700])),
//                 )
//               ],
//             ),
//           ),
//         );
//         setState(() => tap = false);
//         return;
//       }
//
//       // Si email vérifié, continuer la connexion
//       if (await authProvider.getLoginUser(user.uid)) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text(
//               'Connexion réussie',
//               textAlign: TextAlign.center,
//               style: TextStyle(color: Colors.green),
//             ),
//           ),
//         );
//         Navigator.pushNamed(context, '/home');
//         Navigator.pushNamed(context, '/chargement');
//       } else {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text(
//               'Erreur de chargement',
//               textAlign: TextAlign.center,
//               style: TextStyle(color: Colors.red),
//             ),
//           ),
//         );
//       }
//
//       setState(() {
//         telephoneController.clear();
//         motDePasseController.clear();
//         tap = false;
//       });
//     } on FirebaseAuthException catch (error) {
//       setState(() => tap = false);
//
//       switch (error.code) {
//         case "invalid-email":
//           errorMessage = "Votre email semble malformé.";
//           break;
//         case "wrong-password":
//           errorMessage = "Mot de passe incorrect.";
//           break;
//         case "user-not-found":
//           errorMessage = "Utilisateur introuvable.";
//           break;
//         case "user-disabled":
//           errorMessage = "Ce compte a été désactivé.";
//           break;
//         case "too-many-requests":
//           errorMessage = "Trop de tentatives. Réessayez plus tard.";
//           break;
//         case "operation-not-allowed":
//           errorMessage = "Connexion par email et mot de passe non activée.";
//           break;
//         default:
//           errorMessage = "Une erreur inconnue est survenue.";
//       }
//
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(errorMessage!, style: TextStyle(color: Colors.red)),
//         ),
//       );
//       print(error.code);
//     }
//   }
//
//   void signIn2(String email, String password) async {
//     setState(() {
//       inputTap=false;
//     });
//     if (_formKey.currentState!.validate()) {
//       setState(() {
//         tap= true;
//       });
//       try {
//         await _auth
//             .signInWithEmailAndPassword(email: email, password: password)
//             .then((uid) async => {
//
//           //serviceProvider.getLoginUser( _auth.currentUser!.uid!,context),
//
//
//
//
//           if (await authProvider.getLoginUser(uid.user!.uid!)) {
//             ScaffoldMessenger.of(context).showSnackBar(SnackBar(
//               content: Text('Connexion réussie',textAlign: TextAlign.center,style: TextStyle(color: Colors.green),),
//             ),),
//             Navigator.pushNamed(
//                 context,
//                 '/home'),
//             Navigator.pushNamed(context, '/chargement'),
//           }else{
//             ScaffoldMessenger.of(context).showSnackBar(SnackBar(
//               content: Text('Erreur de Chargement',textAlign: TextAlign.center,style: TextStyle(color: Colors.red),),
//             ),),
//           },
//
//           setState(() {
//
//             telephoneController.clear();
//             motDePasseController.clear();
//             tap= false;
//
//           }),
//
//         });
//       } on FirebaseAuthException catch (error) {
//         setState(() {
//           tap= false;
//         });
//         switch (error.code) {
//           case "invalid-email":
//             errorMessage = "Votre numero semble être malformée.";
//             break;
//           case "wrong-password":
//             errorMessage = "Votre mot de passe est erroné.";
//             break;
//           case "user-not-found":
//             errorMessage = "L'utilisateur avec cet numero n'existe pas.";
//             break;
//           case "user-disabled":
//             errorMessage = "L'utilisateur avec cet numero a été désactivé.";
//             break;
//           case "too-many-requests":
//             errorMessage = "Trop de demandes";
//             break;
//           case "operation-not-allowed":
//             errorMessage =
//             "La connexion avec le numero et un mot de passe n'est pas activée.";
//             break;
//           default:
//             errorMessage = "Une erreur indéfinie s'est produite.";
//         }
//         SnackBar snackBar = SnackBar(
//           content: Text(errorMessage.toString(),style: TextStyle(color: Colors.red),),
//         );
//         ScaffoldMessenger.of(context).showSnackBar(snackBar);
//         print(error.code);
//       }
//     }
//   }
//   @override
//   Widget build(BuildContext context) {
//     double height = MediaQuery.of(context).size.height;
//     double width = MediaQuery.of(context).size.width;
//     print("loading");
//     return  Scaffold(
//
//       body: Padding(
//         padding: const EdgeInsets.all(15.0),
//         child: SingleChildScrollView(
//           scrollDirection: Axis.vertical,
//           child: SizedBox(
//             height: height,
//             width: width,
//             child: Column(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children:[
//                 LoginScreenTopImage(),
//                 Spacer(),
//                 Expanded(
//                   flex: 8,
//                   child: Column(
//                     children: [
//                       Padding(
//                         padding: const EdgeInsets.only(top: 25.0,left: 25,right: 25),
//                         child: Form(
//                           key: _formKey,
//                           child: Column(
//                             children: [
//                               IntlPhoneField(
//                                 //controller: telephoneController,
//                                 // invalidNumberMessage:'numero invalide' ,
//                                 //onTap: () {},
//
//                                 cursorColor: kPrimaryColor,
//                                 decoration: InputDecoration(
//                                   hintText: 'Téléphone',
//                                   focusColor: kPrimaryColor,
//                                   focusedBorder: UnderlineInputBorder(
//                                       borderSide: BorderSide(color: kPrimaryColor)),
//                                 ),
//                                 initialCountryCode: 'TG',
//                                 onChanged: (phone) {
//                                   telephoneController.text = phone.completeNumber;
//                                   print(phone.completeNumber);
//                                 },
//                                 onCountryChanged: (country) {
//                                   print('Country changed to: ' + country.name);
//                                 },
//                                 validator: (value) {
//                                   if (value!.completeNumber.isEmpty) {
//                                     return 'Le champ "Téléphone" est obligatoire.';
//                                   }
//
//                                   return null;
//                                 },
//                               ),
//                               TextFormField(
//                                 controller: motDePasseController,
//                                 textInputAction: TextInputAction.done,
//                                 obscureText: true,
//                                 cursorColor: kPrimaryColor,
//                                 decoration: const InputDecoration(
//                                   focusColor: kPrimaryColor,
//                                   focusedBorder: UnderlineInputBorder(
//                                       borderSide: BorderSide(color: kPrimaryColor)),
//                                   hintText: "Votre mot de passe",
//                                   prefixIcon: Padding(
//                                     padding: EdgeInsets.all(defaultPadding),
//                                     child: Icon(Icons.lock),
//                                   ),
//                                 ),
//                                 validator: (value) {
//                                   if (value!.isEmpty) {
//                                     return 'Le champ "Mot de passe" est obligatoire.';
//                                   }
//                                   if (value!.length < 6) {
//                                     return 'Le mot de passe doit comporter au moins 6 caractères.';
//                                   }
//                                   return null;
//                                 },
//                               ),
//                               SizedBox(height: height * 0.1),
//                               Container(
//                                 width: width*0.7,
//                                 child: ElevatedButton(
//                                   onPressed: tap?() { }:() {
//                                     setState(() {
//                                       tap=true;
//                                     });
//                                     if (_formKey.currentState!.validate()) {
//                                       // Afficher une SnackBar
//                                       print("phone ${telephoneController.text}");
//
//                                       if (telephoneController.text.isNotEmpty) {
//                                         signIn( '${telephoneController.text}@gmail.com',motDePasseController.text);
//
//                                       } else {
//                                         SnackBar snackBar = SnackBar(
//                                           content: Text(
//                                             'phone number is not valide',
//                                             style: TextStyle(color: Colors.red),
//                                           ),
//                                         );
//                                         ScaffoldMessenger.of(context).showSnackBar(snackBar);
//                                       }
//                                       setState(() {
//                                         tap=false;
//
//
//                                       });
//                                     }else{
//                                       setState(() {
//                                         tap=false;
//
//
//                                       });
//                                     }
//
//                                   },
//                                   child:tap? Center(
//                                     child: LoadingAnimationWidget.flickr(
//                                       size: 30,
//                                       leftDotColor: Colors.green,
//                                       rightDotColor: Colors.black,
//                                     ),
//                                   ): Text(
//                                     "Se connecter",
//                                     style: TextStyle(color: Colors.black),
//                                   ),
//                                 ),
//                               ),
//                               const SizedBox(height: defaultPadding),
//                               AlreadyHaveAnAccountCheck(
//                                 press: () {
//                                   Navigator.push(
//                                     context,
//                                     MaterialPageRoute(
//                                       builder: (context) {
//                                         return  SignUpScreen();
//                                       },
//                                     ),
//                                   );
//                                 },
//                               ),
//                             ],
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//                 Spacer(),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }
