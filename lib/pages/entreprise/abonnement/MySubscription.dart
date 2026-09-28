import 'package:afrotok/pages/entreprise/abonnement/Subscription.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/model_data.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../models/model_data.dart';
import '../../../providers/authProvider.dart';
import '../../../l10n/tr.dart';

class CurrentSubscriptionPage extends StatelessWidget {
  final EntrepriseAbonnement abonnement;
  final EntrepriseData entreprise;

  CurrentSubscriptionPage({required this.abonnement, required this.entreprise});

  @override
  Widget build(BuildContext context) {
    final DateFormat dateFormat = DateFormat('dd MMM yyyy');
    final int daysRemaining = abonnement.end != null
        ? DateTime.fromMillisecondsSinceEpoch(abonnement.end!).difference(DateTime.now()).inDays
        : 0;

    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);

    bool isExpired = abonnement.end != null &&
        DateTime.now().millisecondsSinceEpoch > abonnement.end!;
    bool isFree = abonnement.type == TypeAbonement.GRATUIT.name;

    String produitRestant = isFree
        ? "${abonnement.nombre_pub ?? 0} restants"
        : context.tr('Illimité');

    Color getStatusColor() {
      if (isFree) return Colors.grey;
      if (isExpired) return Colors.red;
      return Colors.green;
    }

    String getStatusText() {
      if (isFree) return context.tr('Gratuit');
      if (isExpired) return context.tr('Expiré');
      return context.tr('Actif');
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.tr('Mon Abonnement'),
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.02),
              Color(0xFF2ECC71).withOpacity(0.05),
              Colors.amber.withOpacity(0.02),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Carte de statut
              Card(
                elevation: 5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Colors.black,
                        Color(0xFF2ECC71).withOpacity(0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.tr('Statut'),
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  getStatusText(),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: getStatusColor().withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: getStatusColor()),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isFree ? Icons.free_breakfast :
                                    isExpired ? Icons.error_outline : Icons.check_circle,
                                    color: getStatusColor(),
                                    size: 16,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    abonnement.type ?? context.tr('Inconnu'),
                                    style: TextStyle(
                                      color: getStatusColor(),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 15),
                        if (!isFree && !isExpired)
                          LinearProgressIndicator(
                            value: daysRemaining / 365,
                            backgroundColor: Colors.white.withOpacity(0.3),
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
                          ),
                        if (!isFree && !isExpired)
                          SizedBox(height: 8),
                        if (!isFree && !isExpired)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                context.tr('Jours restants'),
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                '$daysRemaining jours',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              SizedBox(height: 20),

              // Détails de l'abonnement
              Expanded(
                child: ListView(
                  children: [
                    // _buildDetailTile(
                    //   icon: Icons.production_quantity_limits,
                    //   title: 'Produits restants',
                    //   value: produitRestant,
                    //   color: Color(0xFF2ECC71),
                    // ),
                    _buildDetailTile(
                      icon: Icons.image,
                      title: context.tr('Images par produit'),
                      value: '${abonnement.nombre_image_pub ?? 1}',
                      color: Colors.blue,
                    ),
                    if (abonnement.nombre_pub != null && !isFree)
                      _buildDetailTile(
                        icon: Icons.layers,
                        title: context.tr('Total produits autorisés'),
                        value: '${abonnement.nombre_pub}',
                        color: Colors.purple,
                      ),
                    if (abonnement.produistIdBoosted != null && !isFree)
                      _buildDetailTile(
                        icon: Icons.rocket_launch,
                        title: context.tr('Produits boostés'),
                        value: '${abonnement.produistIdBoosted!.length}',
                        color: Colors.orange,
                      ),
                    if (abonnement.createdAt != null && !isFree)
                      _buildDetailTile(
                        icon: Icons.calendar_today,
                        title: context.tr('Date de début'),
                        value: dateFormat.format(DateTime.fromMillisecondsSinceEpoch(abonnement.createdAt!)),
                        color: Colors.green,
                      ),
                    if (abonnement.end != null && !isFree)
                      _buildDetailTile(
                        icon: Icons.event,
                        title: context.tr('Date de fin'),
                        value: dateFormat.format(DateTime.fromMillisecondsSinceEpoch(abonnement.end!)),
                        color: Colors.red,
                      ),
                    if (isFree)
                      _buildInfoCard(),
                  ],
                ),
              ),

              SizedBox(height: 20),

              // Bouton d'action
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PremiumSubscriptionPage(
                          entreprise: entreprise,
                          user: authProvider.loginUserData,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isFree || isExpired ? Color(0xFF2ECC71) : Colors.amber,
                    foregroundColor: isFree || isExpired ? Colors.white : Colors.black,
                    elevation: 4,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isFree || isExpired ? Icons.star : Icons.autorenew,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        isFree ? context.tr('Passer à Premium') :
                        isExpired ? context.tr('Renouveler') : context.tr('Améliorer'),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailTile({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      margin: EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(0.1),
              color.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: ListTile(
          leading: Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          subtitle: Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: Colors.amber[50],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info, color: Colors.amber[700]),
                SizedBox(width: 8),
                Text(
                  tr('Plan Gratuit'),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              tr('Profitez des fonctionnalités de base. Passez à Premium pour débloquer :'),
              style: TextStyle(
                fontSize: 13,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 8),
            _buildFeatureItem(tr('➕ Plus de produits à publier')),
            _buildFeatureItem(tr('🖼️ Plus d\'images par produit')),
            _buildFeatureItem(tr('🚀 Boost de produits gratuit')),
            _buildFeatureItem(tr('📊 Statistiques détaillées')),
            _buildFeatureItem(tr('👀 Visibilité étendue')),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.arrow_forward_ios, size: 12, color: Colors.green),
          SizedBox(width: 4),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
// class CurrentSubscriptionPage extends StatelessWidget {
//   final EntrepriseAbonnement abonnement;
//
//   CurrentSubscriptionPage({required this.abonnement});
//
//   @override
//   Widget build(BuildContext context) {
//     final DateFormat dateFormat = DateFormat('dd MMM yyyy');
//     final int daysRemaining = abonnement.end != null
//         ? DateTime.fromMillisecondsSinceEpoch(abonnement.end!).difference(DateTime.now()).inDays
//         : 0;
//
//     String produitRestant = abonnement.type == TypeAbonement.GRATUIT.name
//         ? "${abonnement.nombre_pub ?? 0} restants"
//         : "Illimité";
//
//     return Scaffold(
//       appBar: AppBar(
//         title: Text(
//           'Mon Abonnement',
//           style: TextStyle(color: Colors.white),
//         ),
//         backgroundColor: Colors.green,
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           children: [
//             SizedBox(height: 10),
//             _buildDetailTile(Icons.star, 'Type d\'abonnement', abonnement.type ?? "Inconnu"),
//             _buildDetailTile(Icons.production_quantity_limits, 'Produits restants', produitRestant),
//             if (abonnement.createdAt != null)
//               _buildDetailTile(Icons.calendar_today, 'Date de début',abonnement.type == TypeAbonement.GRATUIT.name?"***": dateFormat.format(DateTime.fromMillisecondsSinceEpoch(abonnement.createdAt!))),
//             if (abonnement.end != null)
//               _buildDetailTile(Icons.event, 'Date de fin',abonnement.type == TypeAbonement.GRATUIT.name?"***": dateFormat.format(DateTime.fromMillisecondsSinceEpoch(abonnement.end!))),
//             _buildDetailTile(Icons.timer, 'Jours restants',abonnement.type == TypeAbonement.GRATUIT.name?"***": '$daysRemaining jours'),
//             SizedBox(height: 20),
//             Center(
//               child: ElevatedButton(
//                 onPressed: () {
//                   Navigator.push(
//                     context,
//                     MaterialPageRoute(builder: (context) => SubscriptionPage()),
//                   );
//                 },
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: Colors.green,
//                   foregroundColor: Colors.black,
//                   padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
//                   textStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//                 ),
//                 child: Text(
//                   'Renouveler',
//                   style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white),
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildDetailTile(IconData icon, String title, String value) {
//     return Card(
//       elevation: 3,
//       shape: RoundedRectangleBorder(
//         borderRadius: BorderRadius.circular(10),
//       ),
//       child: ListTile(
//         leading: Icon(icon, color: Colors.orange, size: 30),
//         title: Text(
//           title,
//           style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
//         ),
//         subtitle: Text(
//           value,
//           style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green),
//         ),
//       ),
//     );
//   }
// }
