import 'package:afrotok/pages/entreprise/abonnement/Subscription.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/model_data.dart';

class CurrentSubscriptionPage extends StatelessWidget {
  final EntrepriseAbonnement abonnement;

  CurrentSubscriptionPage({required this.abonnement});

  @override
  Widget build(BuildContext context) {
    final DateFormat dateFormat = DateFormat('dd MMM yyyy');
    final int daysRemaining = abonnement.end != null
        ? DateTime.fromMillisecondsSinceEpoch(abonnement.end!).difference(DateTime.now()).inDays
        : 0;

    String produitRestant = abonnement.type == TypeAbonement.GRATUIT.name
        ? "${abonnement.nombre_pub ?? 0} restants"
        : "Illimité";

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Mon Abonnement',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.green,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            SizedBox(height: 10),
            _buildDetailTile(Icons.star, 'Type d\'abonnement', abonnement.type ?? "Inconnu"),
            _buildDetailTile(Icons.production_quantity_limits, 'Produits restants', produitRestant),
            if (abonnement.createdAt != null)
              _buildDetailTile(Icons.calendar_today, 'Date de début',abonnement.type == TypeAbonement.GRATUIT.name?"***": dateFormat.format(DateTime.fromMillisecondsSinceEpoch(abonnement.createdAt!))),
            if (abonnement.end != null)
              _buildDetailTile(Icons.event, 'Date de fin',abonnement.type == TypeAbonement.GRATUIT.name?"***": dateFormat.format(DateTime.fromMillisecondsSinceEpoch(abonnement.end!))),
            _buildDetailTile(Icons.timer, 'Jours restants',abonnement.type == TypeAbonement.GRATUIT.name?"***": '$daysRemaining jours'),
            SizedBox(height: 20),
            Center(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => SubscriptionPage()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.black,
                  padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  textStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                child: Text(
                  'Renouveler',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailTile(IconData icon, String title, String value) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.orange, size: 30),
        title: Text(
          title,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
        ),
        subtitle: Text(
          value,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green),
        ),
      ),
    );
  }
}
