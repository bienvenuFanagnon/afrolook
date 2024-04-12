import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../providers/authProvider.dart';
import '../../../providers/userProvider.dart';
import '../../models/model_data.dart';

class RetraitPage extends StatefulWidget {
  @override
  _DepotPageState createState() => _DepotPageState();
}

class _DepotPageState extends State<RetraitPage> {
  late UserAuthProvider authProvider =
  Provider.of<UserAuthProvider>(context, listen: false);

  late UserProvider userProvider =
  Provider.of<UserProvider>(context, listen: false);
  double nombreDeCrypto = 0.0;
  double deviseFcfa = 0.0;
  double montant = 0.0;
  bool demandeDeDepot = false;


  DateFormat formatter = DateFormat('dd MMMM yyyy');
  @override
  Widget build(BuildContext context) {

    final List<Transaction> transactions = [
      Transaction(
        date: DateTime.now().subtract(const Duration(days: 1)),
        montant: 100.0,
        status: "Validé",
        type: "Retrait",
      ),
      Transaction(
        date: DateTime.now().subtract(const Duration(days: 2)),
        montant: 50.0,
        status: "En attente",
        // type: "Retrait",
        type: "Retrait",
      ),
      Transaction(
        date: DateTime.now().subtract(const Duration(days: 1)),
        montant: 100.0,
        status: "Annulé",
        type: "Retrait",
      ),
      Transaction(
        date: DateTime.now().subtract(const Duration(days: 2)),
        montant: 50.0,
        status: "Annulé",
        type: "Retrait",
      ),
      Transaction(
        date: DateTime.now().subtract(const Duration(days: 1)),
        montant: 100.0,
        status: "Validé",
        type: "Retrait",
      ),
      Transaction(
        date: DateTime.now().subtract(const Duration(days: 2)),
        montant: 50.0,
        status: "En attente",
        type: "Retrait",
      ),
      Transaction(
        date: DateTime.now().subtract(const Duration(days: 1)),
        montant: 100.0,
        status: "Annulé",
        type: "Retrait",
      ),
      Transaction(
        date: DateTime.now().subtract(const Duration(days: 2)),
        montant: 50.0,
        status: "En attente",
        type: "Retrait",
      ),
    ];
    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;
    return Scaffold(
      appBar: AppBar(
        title: Text('Monétisation'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              "Cette fonctionnalité n'est pas encore disponible dans cette version bêta de l'application.",
              style: TextStyle(color: Colors.blue),
            ),
          ),
          Form(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: <Widget>[
                  SizedBox(height: 20,),
                  ListTile(

                    leading: Icon(Icons.currency_bitcoin,color: Colors.green, size: 50,),
                  title:  Text(
                    'Publicash',
                    style: TextStyle(
                      fontSize: 18.0,
                    ),

                  ),
                    subtitle:  Text(
                      '150',
                      style: TextStyle(
                        fontSize: 18.0,
                      ),
                    ),
                    trailing: Text(
                      '37515.00 FCFA',
                      style: TextStyle(
                        fontSize: 18.0,
                      ),
                    ),
                  ),

                  SizedBox(height: 30,),
                  Visibility(
                    visible: !demandeDeDepot,
                    child: ElevatedButton(
                      onPressed: () {
                        if (nombreDeCrypto > 0) {
                          // Envoyer une demande de dépôt
                          print('Demande de dépôt de $montant effectuée');
                          setState(() {
                            //demandeDeDepot = true;
                          });
                        } else {
                          // Afficher un message d'erreur
                          print('Le montant du dépôt doit être positif');
                        }
                      },
                      child: Text('Faire une demande de Retrait',style: TextStyle(fontSize: 15),),
                    ),
                  ),
                  Visibility(
                    visible: demandeDeDepot,
                    child: Text('Demande de dépôt en cours...',style: TextStyle(fontSize: 20),),
                  ),

                ],
              ),
            ),
          ),
          SizedBox(height: 30,),
          Text(
            'Exemple Historiques',
            style: TextStyle(
              fontSize: 18.0,
            ),
          ),
          SizedBox(height: 20,),
          Expanded(
            child: ListView.builder(
              itemCount: transactions.length,
              itemBuilder: (context, index) {
                final transaction = transactions[index];
                return Padding(
                  padding: const EdgeInsets.all(2.0),
                  child: Card(
                    child: ListTile(

                      title: Text(transaction.type,style: TextStyle(color: Colors.blue),),
                      subtitle: Row(
                        children: [
                          Text(
                            "${transaction.montant} FCFA - ",
                          ),
                          Text(
                            " ${transaction.status}",
                            style:transaction.status=='Validé'?TextStyle(color: Colors.green,fontSize: 10):transaction.status=='Annulé'?TextStyle(color: Colors.red,fontSize: 10): TextStyle(color: Colors.black38,fontSize: 10),
                          ),
                        ],
                      ),
                      trailing: Container(
                        width: 170,
                        height: height*0.1,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(

                              children: [
                                transaction.status=='En attente'?
                                Container(

                                  child: TextButton(

                                    onPressed: () {

                                    }, child:
                                  Text("Valider la transaction",
                                    style:TextStyle(color: Colors.white,fontSize: 10),
                                  ),

                                  ),
                                  height: 30,
                                  decoration: BoxDecoration(
                                      color: Colors.blue,
                                      borderRadius: BorderRadius.all(Radius.circular(5))),
                                ):Container(),
                                SizedBox(height: 10,),
                                Text("${formatter.format(transaction.date)}",style: TextStyle(fontSize: 10),),
                              ],
                            ),
                            transaction.status=='En attente'? IconButton(onPressed: () {

                            },
                              icon: Icon(Icons.delete_forever),color: Colors.red,):Container()

                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          )
        ],
      ),
    );
  }
}
