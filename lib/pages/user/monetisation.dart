import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../providers/authProvider.dart';
import '../../../providers/postProvider.dart';
import '../../models/model_data.dart';
import '../paiement/depotPageTranaction.dart';
import '../paiement/newDepot.dart';

class MonetisationPage extends StatefulWidget {
  @override
  _MonetisationPageState createState() => _MonetisationPageState();
}

class _MonetisationPageState extends State<MonetisationPage> {
  late UserAuthProvider authProvider;
  late PostProvider postProvider;
  Stream<UserData>? userStream;

  @override
  void initState() {
    super.initState();
    authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    postProvider = Provider.of<PostProvider>(context, listen: false);

    // Initialiser le stream
    userStream = authProvider.getUserStream();
  }

  void refreshUser() {
    // Redémarrer le stream pour rafraîchir les données
    setState(() {
      userStream = authProvider.getUserStream();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Monétisation', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        backgroundColor: Colors.green,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: refreshUser,
            tooltip: "Rafraîchir",
          ),
        ],
      ),
      body: StreamBuilder<UserData>(
        stream: userStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
                child: Text("Erreur de chargement",
                    style: TextStyle(color: Colors.red)));
          }

          final user = snapshot.data!;
          double soldePrincipal = user.votre_solde_principal ?? 0;

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Solde principal
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        "Votre solde principal",
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
                      SizedBox(height: 10),
                      Text(
                        "${soldePrincipal.toStringAsFixed(2)} FCFA",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.yellow,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20),

                // Boutons Dépôt et Retrait
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(context,
                            MaterialPageRoute(builder: (_) => DepositScreen()));
                      },
                      icon: Icon(Icons.add_circle, color: Colors.white),
                      label: Text("Dépôt"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding:
                        EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        // Dialogue retrait
                      },
                      icon: Icon(Icons.remove_circle, color: Colors.white),
                      label: Text("Retrait"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding:
                        EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20),

                // Liste des transactions
                Expanded(
                  child: StreamBuilder<List<TransactionSolde>>(
                    stream: postProvider.getTransactionsSoldes(user.id!),
                    builder: (context, snapshotTx) {
                      if (snapshotTx.connectionState ==
                          ConnectionState.waiting) {
                        return Center(child: CircularProgressIndicator());
                      }
                      if (snapshotTx.hasError) {
                        return Center(
                            child: Text("Erreur de chargement",
                                style: TextStyle(color: Colors.red)));
                      }

                      final transactions = snapshotTx.data ?? [];
                      if (transactions.isEmpty) {
                        return Center(
                            child: Text("Aucune transaction trouvée",
                                style: TextStyle(color: Colors.grey)));
                      }

                      return ListView.builder(
                        itemCount: transactions.length,
                        itemBuilder: (context, index) {
                          final tx = transactions[index];
                          return TransactionWidget(transaction: tx);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// Widget pour afficher chaque transaction
class TransactionWidget extends StatelessWidget {
  final TransactionSolde transaction;
  const TransactionWidget({required this.transaction});

  String formatDate(DateTime date) {
    final formatter = DateFormat('dd MMM yyyy, HH:mm');
    return formatter.format(date);
  }

  @override
  Widget build(BuildContext context) {
    final isDepot = transaction.type == TypeTransaction.DEPOT.name;
    final isValide = transaction.statut == StatutTransaction.VALIDER.name;

    return Card(
      margin: EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: Icon(
          isDepot ? Icons.arrow_downward : Icons.arrow_upward,
          color: isDepot ? Colors.green : Colors.red,
          size: 28,
        ),
        title: Text(
          "${transaction.montant!.toStringAsFixed(2)} FCFA",
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDepot ? Colors.green : Colors.red),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(transaction.description ?? '',
                style: TextStyle(color: Colors.grey[600])),
            SizedBox(height: 4),
            Text(formatDate(
                DateTime.fromMillisecondsSinceEpoch(transaction.createdAt!))),
          ],
        ),
        trailing: Text(
          transaction.statut!.toUpperCase(),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isValide ? Colors.green : Colors.orange,
          ),
        ),
      ),
    );
  }
}

// Dans UserAuthProvider :

