import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/model_data.dart';  // Pour le formatage de la date

class TransactionWidget extends StatelessWidget {
  final TransactionSolde transaction;

  TransactionWidget({required this.transaction});

  // Fonction pour formater la date
  String formatDate(DateTime date) {
    final DateFormat formatter = DateFormat('dd MMM yyyy, hh:mm a');
    return formatter.format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      elevation: 5.0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            // Colonne de la date formatée
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatDate(DateTime.fromMillisecondsSinceEpoch(transaction.createdAt!)),
                  style: TextStyle(
                    fontSize: 16.0,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8.0),
                Text(
                  transaction.description ?? '',
                  style: TextStyle(
                    fontSize: 14.0,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            Spacer(),
            // Colonne du montant et type (dépôt ou retrait)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  transaction.type!.toUpperCase(),
                  style: TextStyle(
                    fontSize: 16.0,
                    color: transaction.type == TypeTransaction.DEPOT.name ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8.0),
                Text(
                  "${transaction.montant!.toStringAsFixed(2)} FCFA",
                  style: TextStyle(
                    fontSize: 18.0,
                    fontWeight: FontWeight.bold,
                    color: transaction.type == TypeTransaction.DEPOT.name  ? Colors.green : Colors.red,
                  ),
                ),
                SizedBox(height: 8.0),
                Text(
                  transaction.statut!.toUpperCase(),
                  style: TextStyle(
                    fontSize: 14.0,
                    color: transaction.statut == StatutTransaction.VALIDER.name  ? Colors.green : Colors.orange,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
