import 'package:flutter/material.dart';

class SubscriptionPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Choisissez un abonnement'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildSubscriptionTile(
                context,
                icon: Icons.free_breakfast,
                title: 'Gratuit',
                price: '0 FCFA',
                features: [
                  'Nombre de produits à poster 📦 : 10',
                  "Nombre d'images par produit 📸 : 1",
                ],
                isPremium: false,
              ),
              SizedBox(height: 20),
              _buildSubscriptionTile(
                context,
                icon: Icons.star,
                title: 'Premium',
                price: '2000 FCFA / 30 jours',
                features: [
                  "Nombre de produits à poster: Illimité 📦",
                  "Visible dans les autres pages 👀",
                  "Nombre d'images par produit 📸 : 5",
                  "Nombre de produit à Booster 🚀 : 5",
                  "Voir les statistiques 📊",
                  "Notifier vos abonnés pour chaque produit 🔔",
                ],
                isPremium: true,
              ),
              SizedBox(height: 20),
              _buildSubscriptionTile(
                context,
                icon: Icons.ads_click,
                title: 'Afrolook Ads',
                price: 'Contactez-nous',
                features: [
                  "Toutes les fonctionnalités du plan Premium",
                  "Publicité de vos produits sur :",
                  "Facebook Ads",
                  "Instagram Ads",
                  "Google Ads",
                  "TikTok Ads",
                  "LinkedIn Ads",
                  "Twitter Ads",
                  "Snapchat Ads",
                  "YouTube Ads",
                ],
                isPremium: true,
                isContact: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubscriptionTile(BuildContext context, {
    required IconData icon,
    required String title,
    required String price,
    required List<String> features,
    required bool isPremium,
    bool isContact = false,
  }) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      elevation: 5,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: Icon(icon, color: isPremium ? Colors.orange : Colors.blue, size: 30),
              title: Text(
                title,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isPremium ? Colors.orange : Colors.blue,
                ),
              ),
            ),
            SizedBox(height: 10),
            ...features.map((feature) => ListTile(
              leading: Icon(Icons.check_circle, color: Colors.green),
              title: Text(feature, style: TextStyle(fontSize: 16)),
            )),
            SizedBox(height: 15),
            Center(
              child: Text(
                price,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            SizedBox(height: 10),
            if (isPremium)
              Center(
                child: ElevatedButton(
                  onPressed: () {
                    if (isContact) {
                      Navigator.pushNamed(context, '/contact');
                    } else {
                      _showSubscriptionModal(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(isContact ? 'Contactez-nous' : 'Sélectionner'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showSubscriptionModal(BuildContext context) {
    int days = 30;
    double pricePer30Days = 2000;
    double calculatedPrice = pricePer30Days;
    double discountRate = 0.0;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Sélectionnez la durée'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RichText(
                    text: TextSpan(
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black),
                      children: <TextSpan>[
                        TextSpan(text: 'Réduction de '),
                        TextSpan(
                          text: '4%',
                          style: TextStyle(color: Colors.green),
                        ),
                        TextSpan(text: ' pour plus de 30 jours:'),
                        TextSpan(text: '\n'), // Saut de ligne
                        TextSpan(text: 'Réduction de '),
                        TextSpan(
                          text: '10%',
                          style: TextStyle(color: Colors.green),
                        ),
                        TextSpan(text: ' pour plus de 60 jours:'),
                      ],
                    ),
                  ),
                  SizedBox(height: 10),
                  Text('Nombre de jours:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Slider(
                    min: 30,
                    max: 365,
                    divisions: 11,
                    value: days.toDouble(),
                    activeColor: Colors.green,
                    inactiveColor: Colors.grey,
                    label: '$days jours',
                    onChanged: (newValue) {
                      setState(() {
                        days = newValue.toInt();
                        if (days > 60) {
                          discountRate = 0.10;
                        } else if (days > 30) {
                          discountRate = 0.04;
                        } else {
                          discountRate = 0.0;
                        }
                        calculatedPrice = ((days / 30) * pricePer30Days) * (1 - discountRate);
                      });
                    },
                  ),
                  Text('$days jours', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
                  Text('${calculatedPrice.toStringAsFixed(0)} FCFA', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
                  if (discountRate > 0)
                    Text('Réduction de ${(discountRate * 100).toInt()}% appliquée!', style: TextStyle(fontSize: 14, color: Colors.red, fontWeight: FontWeight.bold)),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                  child: Text('Confirmer'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}