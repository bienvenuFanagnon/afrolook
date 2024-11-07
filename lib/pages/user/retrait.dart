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
        montant: 1000.0,
        status: "Validé",
        type: "Retrait",
      ),
      Transaction(
        date: DateTime.now().subtract(const Duration(days: 2)),
        montant: 5000.0,
        status: "En attente",
        // type: "Retrait",
        type: "Retrait",
      ),
      Transaction(
        date: DateTime.now().subtract(const Duration(days: 1)),
        montant: 2000.0,
        status: "Annulé",
        type: "Retrait",
      ),
      Transaction(
        date: DateTime.now().subtract(const Duration(days: 2)),
        montant: 4000.0,
        status: "Annulé",
        type: "Retrait",
      ),
      Transaction(
        date: DateTime.now().subtract(const Duration(days: 1)),
        montant: 1000.0,
        status: "Validé",
        type: "Retrait",
      ),
      Transaction(
        date: DateTime.now().subtract(const Duration(days: 2)),
        montant: 25000.0,
        status: "En attente",
        type: "Retrait",
      ),
      Transaction(
        date: DateTime.now().subtract(const Duration(days: 1)),
        montant: 12000.0,
        status: "Annulé",
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
          /*
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              "Cette fonctionnalité n'est pas encore disponible dans cette version bêta de l'application.",
              style: TextStyle(color: Colors.blue),
            ),
          ),

           */
          Form(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: <Widget>[
                  SizedBox(height: 20,),
                  Container(
                    decoration: BoxDecoration(color: Colors.blue,
                    borderRadius: BorderRadius.all(Radius.circular(10))),
                    alignment: Alignment.center,
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: ListTile(

                        leading: Icon(Icons.currency_bitcoin,color: Colors.green, size: 50,),
                      title:  Text(
                        'Votre Solde',
                        style: TextStyle(
                          fontSize: 18.0,
                          color: Colors.white,

                        ),

                      ),
                        subtitle:  Text(
                          '${authProvider.loginUserData.votre_solde} PubliCach',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            fontSize: 18.0,

                          ),
                        ),
                        /*
                        trailing: Text(
                          '37515.00 PubliCach',
                          style: TextStyle(
                            fontSize: 18.0,
                          ),
                        ),

                         */
                      ),
                    ),
                  ),

                  SizedBox(height: 30,),
                  Visibility(
                    visible: !demandeDeDepot,
                    child: ElevatedButton(
                      onPressed: () {
                        if (authProvider.loginUserData.votre_solde! < 1000) {
                          // Envoyer une demande de dépôt
                          print('Demande de dépôt de $montant effectuée');
                          showModalBottomSheet<void>(
                            context: context,
                            builder: (BuildContext context) {
                              return SizedBox(
                                height: height*0.3,
                                child: Padding(
                                  padding: const EdgeInsets.all(20.0),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [

                                      Text('La première étape pour commencer à gagner et retirer vos soldes est d\'avoir minimum 1000 PubliCach.',style: TextStyle(fontSize: 16),),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                          setState(() {
                            //demandeDeDepot = true;
                          });
                        }else {
                          // Envoyer une demande de dépôt
                          print('Demande de dépôt de $montant effectuée');
                          showModalBottomSheet(
                            context: context,
                            builder: (context) => Container(
                              color: Colors.white,
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(20.0),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        "Félicitations ! Vous avez atteint le solde minimum requis.",
                                        style: TextStyle(fontSize: 18,fontWeight: FontWeight.w600),
                                      ),
                                      SizedBox(height: 5,),

                                      Text(
                                        "Les retraits sont désormais disponibles dans la version officielle de notre application. Soyez rassuré, vous pourrez bientôt retirer votre argent de contribution.",
                                        style: TextStyle(fontSize: 16),
                                      ),
                                      SizedBox(height: 5,),


                                      Text(
                                        "En attendant la mise en ligne de la version officielle, continuez à parrainer et à gagner de l'argent. Votre contribution est précieuse pour nous et nous vous remercions de votre confiance.",
                                        style: TextStyle(fontSize: 16),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                          setState(() {
                            //demandeDeDepot = true;
                          });
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
                            "${transaction.montant} PubliCach - ",
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
