import 'package:afrotok/providers/authProvider.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'depotPaiment.dart';

class DepositScreen extends StatefulWidget {
  final double? defaultAmount; // Paramètre optionnel

  const DepositScreen({Key? key, this.defaultAmount}) : super(key: key);

  @override
  _DepositScreenState createState() => _DepositScreenState();
}

class _DepositScreenState extends State<DepositScreen> {
  final amountController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _termsAccepted = false;

  @override
  void initState() {
    super.initState();
    // Si un montant par défaut est fourni, l'initialiser dans le contrôleur
    if (widget.defaultAmount != null) {
      amountController.text = widget.defaultAmount!.toStringAsFixed(0);
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: Color(0xFFF9F5EB), // Beige clair pour Afrolook
      appBar: AppBar(
        title: Text(
          'Recharger mon portefeuille Afrolook',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: Color(0xFFD8A868), // Marron doré pour Afrolook
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Card avec informations sur les frais
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Icon(Icons.shopping_bag, color: Color(0xFF5C4A3C), size: 35),
                      SizedBox(height: 16),
                      Text(
                        'Informations importantes',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF5C4A3C), // Marron foncé
                        ),
                      ),
                      SizedBox(height: 15),
                      // _buildInfoRow('• Frais de service:', '5,6% inclus', Color(0xFF5C4A3C)),
                      // SizedBox(height: 8),
                      _buildInfoRow('• Montant minimum:', '200 FCFA', Color(0xFF5C4A3C)),
                      // SizedBox(height: 8),
                      // _buildInfoRow('• Aucun frais supplémentaire:', 'Tout est inclus', Colors.green),
                      SizedBox(height: 8),
                      _buildInfoRow('• Support Afrolook:', 'Contact sous 24h', Color(0xFF5C4A3C)),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 20),

              // Avertissement obligatoire
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Color(0xFFFFEDD5), // Beige orangé clair
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Color(0xFFD8A868)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Color(0xFFD8A868)),
                        SizedBox(width: 8),
                        Text(
                          'Information importante',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF5C4A3C),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                    // Text(
                    //   'Les frais de 5,6% couvrent l\'intégralité des coûts de transaction. Aucun frais supplémentaire ne sera appliqué.',
                    //   style: TextStyle(color: Colors.grey[800]),
                    // ),
                    // SizedBox(height: 10),
                    Text(
                      'En cas de problème, contactez immédiatement le support Afrolook dans les 24h suivant la transaction.',
                      style: TextStyle(color: Colors.grey[800]),
                    ),
                    SizedBox(height: 10),
                    Row(
                      children: [
                        Checkbox(
                          value: _termsAccepted,
                          onChanged: (value) {
                            setState(() {
                              _termsAccepted = value ?? false;
                            });
                          },
                          activeColor: Color(0xFFD8A868),
                        ),
                        Expanded(
                          child: Text(
                            'Je comprends et accepte les conditions de recharge',
                            style: TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),

              // Formulaire de dépôt
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Montant à recharger',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF5C4A3C),
                      ),
                    ),
                    SizedBox(height: 8),
                    TextFormField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: '200 FCFA minimum',
                        suffixText: 'FCFA',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Color(0xFFD8A868)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Color(0xFFD8A868)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Color(0xFF5C4A3C)),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez entrer un montant';
                        }
                        final amount = double.tryParse(value) ?? 0;
                        if (amount < 200) {
                          return 'Le montant minimum est 200 FCFA';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _termsAccepted ? () async {
                        if (_formKey.currentState!.validate()) {
                          Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PaiementPage(
                              // id: postId,
                              montant: double.tryParse(amountController.text) ?? 0.0, // Montant en XOF
                              onSuccess: (success) async {
                                if (success) {
                                  Navigator.pop(context);
                                  Navigator.pop(context);
                                }
                              },
                            ),
                          ),
                        );

                         // await _processPayment();
                        }
                      } : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _termsAccepted ? Color(0xFFD8A868) : Colors.grey,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 3,
                      ),
                      child: Text(
                        'PROCÉDER AU PAIEMENT',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),
              Text(
                'Vous serez redirigé vers la plateforme sécurisée CinetPay pour finaliser votre recharge.',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        SizedBox(width: 5),
        Expanded(child: Text(value, style: TextStyle(color: Colors.grey[800]))),
      ],
    );
  }

  Future<void> _processPayment() async {
    final userTransactionsProvider = Provider.of<UserAuthProvider>(context, listen: false);

    // Afficher le loader
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (_) => Center(
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(Color(0xFFD8A868)),
              ),
              SizedBox(height: 16),
              Text(
                'Connexion sécurisée en cours...',
                style: TextStyle(
                  color: Color(0xFF5C4A3C),
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final amount = double.tryParse(amountController.text) ?? 0;
      final response = await userTransactionsProvider.initiateDeposit(
        amount,
        userTransactionsProvider.loginUserData,
      );

      final String paymentUrl = (response['payment_url'] ?? '') as String;

      // Fermer le loader
      Navigator.of(context).pop();

      if (await canLaunchUrl(Uri.parse(paymentUrl))) {
        await launchUrl(
          Uri.parse(paymentUrl),
          mode: LaunchMode.externalApplication,
        );
      }
    } catch (e) {
      // Fermer le loader en cas d'erreur
      Navigator.of(context).pop();

      // Afficher un snackbar natif
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Échec du traitement: ${e.toString()}'),
          backgroundColor: Colors.red[400],
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

}