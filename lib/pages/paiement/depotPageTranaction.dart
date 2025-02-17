import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import '../../models/model_data.dart';
import '../../providers/authProvider.dart';
import '../../providers/userProvider.dart';
import '../component/consoleWidget.dart';
import '../user/monetisation.dart';
import 'depotPaiment.dart';

class DepotPageTransaction extends StatefulWidget {
  @override
  _DepotPageTransactionState createState() => _DepotPageTransactionState();
}

class _DepotPageTransactionState extends State<DepotPageTransaction> {
  final TextEditingController controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final double conversionRate = 25; // Exemple de taux de conversion
  late UserAuthProvider authProvider = Provider.of<UserAuthProvider>(context, listen: false);
  late UserProvider userProvider = Provider.of<UserProvider>(context, listen: false);
  @override
  Widget build(BuildContext context) {
    double publicash = double.tryParse(controller.text) ?? 0;
    double prixFcfa = publicash * conversionRate;
    double frais = prixFcfa * 0.035;
    double montantTotal = prixFcfa + frais;

    return Scaffold(
      appBar: AppBar(
        iconTheme: IconThemeData(color: Colors.white),
        title: Text("Dépôt Publicash",style: TextStyle(color: Colors.white),),
        backgroundColor: Colors.green,
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Center(
                  child: Text(
                    'Pour les Togolais, Les dépôts avec TMoney - YAS sont plus fiables que Flooz. Il est conseillé de faire le dépôt avec ces moyens. Faute de cela, nous ne pourrons pas récupérer le montant en cas de souci.',
                  ),
                ),
              ),

              SizedBox(height: 15),
              TextFormField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: "Nombre de Publicash",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Ce champ est obligatoire';
                  }
                  final number = double.tryParse(value);
                  if (number == null || number < 10.0) {
                    return 'Valeur supérieure ou égale à 10.0';
                  }
                  return null;
                },
                onChanged: (value) => setState(() {
                   publicash = double.tryParse(controller.text) ?? 0;
                   prixFcfa = publicash * conversionRate;
                   frais = prixFcfa * 0.035;
                   montantTotal = prixFcfa + frais;
                }),
              ),
              SizedBox(height: 10),
              Text(
                "Prix en FCFA : ${prixFcfa.toStringAsFixed(0)} FCFA",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text("Annuler"),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _processDepot(montantTotal,prixFcfa,frais);
                    },
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text("Continuer"),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _processDepot(double montantTotal,prixFcfa,frais) async {
    if (_formKey.currentState?.validate() ?? false) {
      try {
        print("Validation réussie, début du processus de paiement...");

// Si le formulaire est valide, procéder avec l'action
        printVm('paiement');
        TransactionSolde transaction=TransactionSolde();
        String postId = FirebaseFirestore.instance
            .collection('TransactionSoldes')
            .doc()
            .id;
        transaction.id = postId;
        transaction.user_id = authProvider.loginUserData.id;
        transaction.type = TypeTransaction.DEPOT.name;
        transaction.statut = StatutTransaction.VALIDER.name;
        transaction.description = "Dépôt";
        transaction.montant = montantTotal;
        transaction.createdAt = DateTime.now().millisecondsSinceEpoch;
        transaction.updatedAt = DateTime.now().millisecondsSinceEpoch;
        printVm('paiement2222');


        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PaiementPage(
              // id: postId,
              montant: montantTotal.toInt(), // Montant en XOF
              onSuccess: (success) async {
                if (success) {
                  await  authProvider.getUserById(authProvider.loginUserData.id!).then((value) async {
                    if(value.isNotEmpty){
                      authProvider.loginUserData=value.first;
                      await authProvider.getAppData();
                      authProvider.appDefaultData.solde_gain=(authProvider.appDefaultData.solde_gain??0)+ (frais/25);
                      authProvider.appDefaultData.solde_principal=(authProvider.appDefaultData.solde_principal??0)+ (prixFcfa/25);
                      await authProvider.updateAppData(authProvider.appDefaultData);
                      authProvider.loginUserData.votre_solde_principal=(authProvider.loginUserData.votre_solde_principal??0)+(prixFcfa/25);
                      await authProvider.updateUser(authProvider.loginUserData).then(
                            (value) async {


                              await FirebaseFirestore.instance
                                  .collection('TransactionSoldes')
                                  .doc(transaction.id!)
                                  .set(transaction.toJson());



                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Votre paiement a été effectué avec succès. 🎉💰',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.green),
                                  ),
                                ),
                              );
                        },
                      );
                    }
                  },);
                }
              },
            ),
          ),
        );
        printVm('paiement3333');

      } catch (e) {
        print("Erreur lors de la transaction : $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Une erreur est survenue. Veuillez réessayer."),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Veuillez corriger les erreurs du formulaire minimum 10 pc"),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }
}
