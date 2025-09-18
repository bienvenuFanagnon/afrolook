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
    userStream = authProvider.getUserStream();
  }

  void refreshUser() {
    setState(() {
      userStream = authProvider.getUserStream();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0A0A0A),
      appBar: AppBar(
        title: Text('Monétisation',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.black,
        elevation: 0,
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
            return Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00CC66))));
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
                child: Text("Erreur de chargement",
                    style: TextStyle(color: Colors.red)));
          }

          final user = snapshot.data!;
          double soldePrincipal = user.votre_solde_principal ?? 0;

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Carte du solde principal
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Color(0xFF121212),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      )
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "SOLDE PRINCIPAL",
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        "${soldePrincipal.toStringAsFixed(2)} FCFA",
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF00CC66),
                        ),
                      ),
                      SizedBox(height: 16),
                      Divider(color: Colors.grey[800], height: 1),
                      SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Bouton Dépôt
                          Expanded(
                            child: Container(
                              height: 50,
                              margin: EdgeInsets.only(right: 8),
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.push(context,
                                      MaterialPageRoute(builder: (_) => DepositScreen()));
                                },
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.arrow_downward, size: 18, color: Colors.white),
                                    SizedBox(width: 6),
                                    Text("Dépôt", style: TextStyle(fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Color(0xFF00CC66),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                  elevation: 0,
                                ),
                              ),
                            ),
                          ),
                          // Bouton Retrait
                          Expanded(
                            child: Container(
                              height: 50,
                              margin: EdgeInsets.only(left: 8),
                              child: ElevatedButton(
                                onPressed: () {
                                  // Dialogue retrait
                                },
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.arrow_upward, size: 18, color: Colors.white),
                                    SizedBox(width: 6),
                                    Text("Retrait", style: TextStyle(fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Color(0xFFFF3B30),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                  elevation: 0,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24),

                // En-tête historique des transactions
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "HISTORIQUE DES TRANSACTIONS",
                        style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.1
                        ),
                      ),
                      // if (snapshot.hasData)
                      //   Text(
                      //     "Total: ${transactions.length}",
                      //     style: TextStyle(
                      //       color: Colors.grey[500],
                      //       fontSize: 12,
                      //     ),
                      //   ),
                    ],
                  ),
                ),
                SizedBox(height: 16),

                // Liste des transactions
                Expanded(
                  child: StreamBuilder<List<TransactionSolde>>(
                    stream: postProvider.getTransactionsSoldes(user.id!),
                    builder: (context, snapshotTx) {
                      if (snapshotTx.connectionState == ConnectionState.waiting) {
                        return Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00CC66))));
                      }
                      if (snapshotTx.hasError) {
                        return Center(
                            child: Text("Erreur de chargement",
                                style: TextStyle(color: Colors.red)));
                      }

                      final transactions = snapshotTx.data ?? [];
                      if (transactions.isEmpty) {
                        return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.receipt, size: 48, color: Colors.grey[700]),
                                SizedBox(height: 16),
                                Text("Aucune transaction",
                                    style: TextStyle(color: Colors.grey[600])),
                              ],
                            ));
                      }

                      return ListView.builder(
                        physics: BouncingScrollPhysics(),
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
    final isCredit = transaction.type == TypeTransaction.DEPOT.name || transaction.type == TypeTransaction.GAIN.name;
    final isValide = transaction.statut == StatutTransaction.VALIDER.name;

    // Définir les styles selon le type
    IconData icon;
    Color color;
    String prefix;

    switch (transaction.type) {
      case "DEPOT":
        icon = Icons.account_balance_wallet;
        color = const Color(0xFF007AFF);
        prefix = "+ ";
        break;
      case "GAIN":
        icon = Icons.trending_up;
        color = const Color(0xFF00CC66);
        prefix = "+ ";
        break;
      case "DEPENSE":
        icon = Icons.shopping_cart;
        color = const Color(0xFFFF3B30);
        prefix = "- ";
        break;
      default:
        icon = Icons.help_outline;
        color = Colors.grey;
        prefix = "";
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icône
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),

          // Infos principales
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${prefix}${transaction.montant!.toStringAsFixed(2)} FCFA",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  transaction.description ?? '',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Statut + Date
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatDate(DateTime.fromMillisecondsSinceEpoch(transaction.createdAt!)),
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isValide
                      ? const Color(0xFF00CC66).withOpacity(0.15)
                      : const Color(0xFFFF9500).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  transaction.statut!.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isValide ? const Color(0xFF00CC66) : const Color(0xFFFF9500),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
