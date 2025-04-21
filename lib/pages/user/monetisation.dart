import 'package:afrotok/pages/component/consoleWidget.dart';
import 'package:afrotok/pages/paiement/depotPageTranaction.dart';
import 'package:afrotok/pages/paiement/mesTransactions.dart';
import 'package:afrotok/pages/socialVideos/afrovideos/afrovideo.dart';
import 'package:cinetpay/cinetpay.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:phone_form_field/phone_form_field.dart';
import 'package:provider/provider.dart';
import '../../../providers/authProvider.dart';
import '../../../providers/userProvider.dart';
import '../../models/model_data.dart';
import '../paiement/depotPaiment.dart';


class MonetisationPage extends StatefulWidget {
  @override
  _MonetisationPageState createState() => _MonetisationPageState();
}

class _MonetisationPageState extends State<MonetisationPage> {
  late UserAuthProvider authProvider = Provider.of<UserAuthProvider>(context, listen: false);
  late UserProvider userProvider = Provider.of<UserProvider>(context, listen: false);
  DateFormat formatter = DateFormat('dd MMMM yyyy');
  double conversionRate = 25; // 1 Publicash = 650 FCFA




  void _showRetraitPrincipalDialog(BuildContext context) {
    TextEditingController controller = TextEditingController();
    TextEditingController phoneController = TextEditingController();
     String? phone;
         String? prefix;
    final _formKey = GlobalKey<FormState>();
    // double conversionRate = 650; // Taux de conversion de Publicash à FCFA

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(
                "Retrait Publicash",
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                textAlign: TextAlign.center,
              ),
              content: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: controller,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: "Nombre de Publicash",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez entrer un nombre';
                        }
                        double? publicash = double.tryParse(value);
                        if (publicash == null || publicash < 10) {
                          return 'Le nombre de Publicash doit être au moins 10';
                        }
                        if (publicash == null || publicash > (authProvider.loginUserData.votre_solde_principal??0)) {
                          return 'Solde insuffisant';
                        }
                        return null;
                      },
                      onChanged: (value) => setState(() {}),
                    ),
                    SizedBox(height: 10),
                    Text(
                      controller.text.isEmpty
                          ? "Prix en FCFA : 0 FCFA"
                          : "Prix en FCFA : ${(int.tryParse(controller.text) ?? 0) * conversionRate} FCFA",
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                    SizedBox(height: 10),
                    PhoneFormField(

                      decoration: InputDecoration(helperText: 'Numero '),

                      initialValue: PhoneNumber.parse('+228'), // or use the controller
                      validator: PhoneValidator.compose(
                          [PhoneValidator.required(context), PhoneValidator.validMobile(context)]),
                      countrySelectorNavigator: const CountrySelectorNavigator.page(),
                      onChanged: (phoneNumber) {
                        printVm('phoneNumber : ${phoneNumber.toJson()}');

                        // Récupérer le préfixe sans le '+'
                         prefix = phoneNumber.countryCode; // Supprimer le '+' au début du préfixe

                        // Récupérer le numéro sans le préfixe
                         phone = phoneNumber.nsn; // Le numéro sans le préfixe
                        print('Préfixe : $prefix, Numéro : $phone');
                      },
                      onSaved: (newValue) {
                        // printVm('phoneNumber : ${newValue!.toJson()}');
                        //
                        // phone=newValue!.international;

                      },

                      enabled: true,
                      isCountrySelectionEnabled: true,
                      isCountryButtonPersistent: true,
                      countryButtonStyle: const CountryButtonStyle(
                          showDialCode: true,
                          showIsoCode: true,
                          showFlag: true,
                          flagSize: 16
                      ),

                      // + all parameters of TextField
                      // + all parameters of FormField
                      // ...
                    ),

                    // TextFormField(
                    //   controller: phoneController,
                    //   keyboardType: TextInputType.phone,
                    //   decoration: InputDecoration(
                    //     labelText: "Numéro de téléphone (sans préfixe)",
                    //     hintText: "Exemple : 90123456",
                    //     border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    //   ),
                    //   validator: (value) {
                    //     if (value == null || value.isEmpty) {
                    //       return 'Veuillez entrer un numéro de téléphone';
                    //     }
                    //     if (value.length < 8) {
                    //       return 'Le numéro doit comporter au moins 8 chiffres';
                    //     }
                    //     if (!RegExp(r'^[0-9]+$').hasMatch(value)) {
                    //       return 'Veuillez entrer un numéro valide (chiffres uniquement)';
                    //     }
                    //     return null;
                    //   },
                    // ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text("Fermer"),
                ),
                TextButton(
                  onPressed: () async {
                    if (_formKey.currentState?.validate() ?? false) {
                     await authProvider.getUserById(authProvider.loginUserData.id!).then(
                        (value) async {
                          if(value.isNotEmpty){
                            authProvider.loginUserData=value.first;
                            authProvider.loginUserData.votre_solde_principal=authProvider.loginUserData.votre_solde_principal!??0;
                            if(double.parse(controller.text)<= authProvider.loginUserData.votre_solde_principal!){
                              await authProvider.generateToken().then((value) async {
                                await authProvider.ajouterContactCinetPay(authProvider.cinetPayToken!,
                                    "${prefix}",
                                    '${phone}',
                                    '${authProvider.loginUserData.pseudo}',
                                    '${authProvider.loginUserData.pseudo}',
                                    '${authProvider.loginUserData.email}');
                              },);


                            }
                          }
                        },
                      );
                      // Action de confirmation
                      Navigator.pop(context);
                    }
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text("Continuer"),
                ),
              ],
            );
          },
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    //principal
    double principalpubliCash = authProvider.loginUserData.votre_solde_principal ?? 0;
    double principalmontantFcfa = principalpubliCash * 25;
    double principalmontantValable = principalmontantFcfa;
    //parrainage
    double publiCash = authProvider.loginUserData.publi_cash ?? 0;
    double montantFcfa = publiCash * 25;
    double montantValable = montantFcfa * authProvider.loginUserData.popularite!;

    //createur contenu
    double contenuPubliCash = authProvider.loginUserData.votre_solde_contenu ?? 0;
    double contenuMontantFcfa = contenuPubliCash * 25;
    double contenuMontantValable = contenuMontantFcfa * authProvider.loginUserData.popularite!;

    //cadeau
    double cadeauPubliCash = authProvider.loginUserData.votre_solde_cadeau ?? 0;
    double cadeauMontantFcfa = cadeauPubliCash * 25;
    double cadeauMontantValable = cadeauMontantFcfa;

    return Scaffold(
      appBar: AppBar(
        title: Text('Monétisation', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.green,
        centerTitle: true,
      ),
      body: Padding(
        padding: EdgeInsets.all(15.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildSoldeSection('💰 Solde Principal', principalpubliCash, principalmontantFcfa, principalmontantValable, false,Colors.green,"PP"),
              _buildSoldeSection('🎁 Solde Cadeau', cadeauPubliCash, cadeauMontantFcfa, cadeauMontantValable, true,Colors.amber,"CA"),

              _buildSoldeSection('💰 👥 Solde Parrainage', publiCash, montantFcfa, montantValable, true,Colors.blue,"PA"),

              _buildSoldeSection('📝 Solde Créateur de Contenu', contenuPubliCash, contenuMontantFcfa, contenuMontantValable, true,Colors.indigo,"CC"),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSoldeSection(String title, double publiCash,
      double montantFcfa, double montantValable, bool showWithdrawButton,
      Color color,String type) {
    return Column(
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
        ),
        SizedBox(height: 5),
        _buildSoldeCard(publiCash, montantFcfa, montantValable,color),
        SizedBox(height: 10),
        if (showWithdrawButton) _buildRetraitButton(publiCash,type),
    Visibility(
      visible: showWithdrawButton?false:true,
      child: Column(
        children: [

          ElevatedButton(
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => MesTransactions(),));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.lightGreen, // Remplacez par la couleur souhaitée
              padding: EdgeInsets.symmetric(vertical: 12, horizontal: 20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.list, color: Colors.white), // Remplacez par l'icône souhaitée
                SizedBox(width: 8), // Espace entre l'icône et le texte
                Text(
                  'Transactions',
                  style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ElevatedButton(
                onPressed: () {
                  _showRetraitPrincipalDialog(context);              // Action à effectuer lors du clic sur le bouton
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red, // Remplacez par la couleur souhaitée
                  padding: EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.remove_circle_outlined, color: Colors.white), // Remplacez par l'icône souhaitée
                    SizedBox(width: 8), // Espace entre l'icône et le texte
                    Text(
                      'Retrait',
                      style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),

              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DepotPageTransaction(),
                    ),
                  );
                  // _showDepotDialog();              // Action à effectuer lors du clic sur le bouton
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green, // Remplacez par la couleur souhaitée
                  padding: EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_circle_outlined, color: Colors.white), // Remplacez par l'icône souhaitée
                    SizedBox(width: 8), // Espace entre l'icône et le texte
                    Text(
                      'Dépôt',
                      style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              )
            ],
          ),
        ],
      ),
    ),
        SizedBox(height: 20),
      ],
    );
  }

  Widget _buildSoldeCard(double publiCash, double montantFcfa, double montantValable,
      Color color) {
    return Container(
      padding: EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(Icons.money, color: Colors.white, size: 40),
              IconButton(
                icon: Icon(Icons.refresh, color: Colors.white, size: 30),
                onPressed: () async {
                  await authProvider.getLoginUser(authProvider.loginUserData.id!);
                  setState(() {});
                },
              ),
            ],
          ),
          SizedBox(height: 10),
          Text('Votre Solde', style: TextStyle(fontSize: 18, color: Colors.white)),
          SizedBox(height: 5),
          Text('${publiCash.toStringAsFixed(2)} PubliCash (PC)', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.yellow)),
          SizedBox(height: 5),
          Row(
            children: [
              Text('Conversion :   ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              Text('${montantFcfa.toStringAsFixed(2)} FCFA', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            ],
          ),
          SizedBox(height: 5),
          Row(
            children: [
              Text('Solde valable :   ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              Text('${montantValable.toStringAsFixed(2)} FCFA', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            ],
          ),
        ],
      ),
    );
  }
  Widget _buildRetraitButton(double publiCash, String type) {
    bool canWithdraw = publiCash > 5000;

    return ElevatedButton(
      onPressed: () async {
        double montantEncaisser = 0;

        if (type == 'PA'||type == 'CC') {
          _showRetraitDialog(canWithdraw);
        } else {
          _showLoadingDialog(); // Affiche le loader

          await authProvider.getUserById(authProvider.loginUserData.id!).then((value) async {
            if (value.isNotEmpty) {
              UserData userData = value.first;
              userData.votre_solde_principal ??= 0;
              userData.votre_solde ??= 0;
              userData.publi_cash ??= 0;
              userData.votre_solde_contenu ??= 0;
              userData.votre_solde_cadeau ??= 0;

              if (type == 'CA' && userData.votre_solde_cadeau! > 0) {
                montantEncaisser = userData.votre_solde_cadeau!;
                userData.votre_solde_cadeau=0.0;
              }

              // else if (type == 'CC' && userData.votre_solde_contenu! > 0) {
              //   montantEncaisser = userData.votre_solde_contenu!;
              // }

              if (montantEncaisser > 0) {
                userData.votre_solde_principal = userData.votre_solde_principal! + montantEncaisser;

                await authProvider.updateUser(userData).then((value) {
                  Navigator.pop(context); // Ferme le loader
                  if (value) {
                    _showSuccessMessage(); // Afficher message de succès
                  }
                });
                setState(() {

                });
              } else {
                Navigator.pop(context); // Ferme le loader
                _showRetraitAutherSoldeDialog();
                return;
              }
            } else {
              Navigator.pop(context); // Ferme le loader
            }
          });
        }
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green,
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(
        'Encaisser votre solde',
        style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
      ),
    );
  }

  /// Fonction pour afficher le loader
  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Center(
            child: CircularProgressIndicator(),
          ),
        );
      },
    );
  }

  /// Fonction pour afficher un message de succès
  void _showSuccessMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Solde encaissé avec succès !')),
    );
  }

  void _showRetraitDialog(bool canWithdraw) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              canWithdraw
                  ? 'Félicitations ! Vous pouvez maintenant effectuer un retrait.'
                  : 'Vous devez avoir au moins 5000 PC pour effectuer un retrait.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
            ),
            SizedBox(height: 10),
            canWithdraw
                ? Text('Les retraits seront disponibles bientôt. Continuez à parrainer !', textAlign: TextAlign.center)
                : Text('Invitez des amis pour gagner plus de PubliCash !', textAlign: TextAlign.center),
            SizedBox(height: 15),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: Text('OK', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showRetraitAutherSoldeDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Solde insuffisant pour effectuer un lancement.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
            ),
            SizedBox(height: 15),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text('OK', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }


}



