import 'dart:convert';

import 'package:afrotok/providers/authProvider.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;

import 'package:flutter/foundation.dart' show kIsWeb;

class DepositScreen extends StatefulWidget {
  final double? defaultAmount;

  const DepositScreen({Key? key, this.defaultAmount}) : super(key: key);

  @override
  _DepositScreenState createState() => _DepositScreenState();
}

class _DepositScreenState extends State<DepositScreen> {
  final amountController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _termsAccepted = false;
  String? _selectedPaymentMethod;

  @override
  void initState() {
    super.initState();
    if (widget.defaultAmount != null) {
      amountController.text = widget.defaultAmount!.toStringAsFixed(0);
    }
  }

  void _showPaymentMethodSelection() {
    if (!_formKey.currentState!.validate()) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: BoxDecoration(
          color: Color(0xFFF9F5EB),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(25),
            topRight: Radius.circular(25),
          ),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Color(0xFFD8A868),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(25),
                  topRight: Radius.circular(25),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.payment, color: Colors.white, size: 28),
                  SizedBox(width: 12),
                  Text(
                    'Choisissez votre méthode de paiement',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    // Option CinetPay
                    _PaymentMethodCard(
                      title: 'CinetPay',
                      subtitle: 'Toute l\'Afrique',
                      description: 'Mobile Money • Carte Bancaire • Orange Money',
                      icon: Icons.public,
                      color: Color(0xFF2E7D32),
                      iconColor: Colors.white,
                      onTap: () {
                        Navigator.pop(context);
                        _selectedPaymentMethod = 'cinetpay';
                        _processCinetPayPayment();
                      },
                    ),
                    SizedBox(height: 15),

                    // Option PayGate
                    _PaymentMethodCard(
                      title: 'PayGate',
                      subtitle: 'Togo seulement',
                      description: 'FLOOZ • T-Money • Carte Bancaire',
                      icon: Icons.phone_android,
                      color: Color(0xFF1976D2),
                      iconColor: Colors.white,
                      onTap: () {
                        Navigator.pop(context);
                        _showPayGatePhoneDialog();
                      },
                    ),

                    SizedBox(height: 20),
                    Divider(color: Colors.grey[400]),
                    SizedBox(height: 10),

                    Text(
                      'Sélectionnez la méthode adaptée à votre pays',
                      style: TextStyle(
                        color: Color(0xFF5C4A3C),
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: Color(0xFF5C4A3C),
                  padding: EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                ),
                child: Text('ANNULER', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPayGatePhoneDialog() {
    String selectedNetwork = 'FLOOZ';
    final phoneController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Color(0xFFF9F5EB),
        title: Row(
          children: [
            Icon(Icons.phone_android, color: Color(0xFF1976D2)),
            SizedBox(width: 10),
            Text(
              'Paiement PayGate - Togo',
              style: TextStyle(
                color: Color(0xFF5C4A3C),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Veuillez saisir vos informations de paiement Togo:',
              style: TextStyle(color: Color(0xFF5C4A3C)),
            ),
            SizedBox(height: 20),
            TextFormField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Numéro de téléphone',
                prefixText: '+228 ',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Color(0xFFD8A868)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Color(0xFFD8A868)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Color(0xFF1976D2)),
                ),
                prefixIcon: Icon(Icons.phone, color: Color(0xFF5C4A3C)),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            SizedBox(height: 15),
            DropdownButtonFormField<String>(
              value: selectedNetwork,
              items: [
                DropdownMenuItem(
                  value: 'FLOOZ',
                  child: Text('FLOOZ (Moov)'),
                ),
                DropdownMenuItem(
                  value: 'T-MONEY',
                  child: Text('T-Money (Togocel)'),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  selectedNetwork = value!;
                });
              },
              decoration: InputDecoration(
                labelText: 'Réseau mobile',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Color(0xFFD8A868)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Color(0xFFD8A868)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Color(0xFF1976D2)),
                ),
                prefixIcon: Icon(Icons.network_cell, color: Color(0xFF5C4A3C)),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Annuler',
              style: TextStyle(color: Color(0xFF5C4A3C)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (phoneController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Veuillez saisir votre numéro de téléphone'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              Navigator.pop(context);
              _selectedPaymentMethod = 'paygate';
              _processPayGatePayment(phoneController.text, selectedNetwork);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF1976D2),
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Confirmer',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _processCinetPayPayment() async {
    final userTransactionsProvider = Provider.of<UserAuthProvider>(context, listen: false);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          padding: EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(Color(0xFF2E7D32)),
              ),
              SizedBox(height: 20),
              Text(
                'Connexion à CinetPay...',
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF2E7D32),
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 10),
              Text(
                'Redirection vers la plateforme sécurisée',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
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

      Navigator.of(context).pop(); // Fermer le loader

      if (await canLaunchUrl(Uri.parse(paymentUrl))) {
        await launchUrl(
          Uri.parse(paymentUrl),
          mode: LaunchMode.externalApplication,
        );
        Navigator.pop(context); // Fermer la page de dépôt
      }
    } catch (e) {
      Navigator.of(context).pop(); // Fermer le loader

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Échec du traitement CinetPay: ${e.toString()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }


  Future<void> _processPayGatePayment(String phoneNumber, String network) async {
    final userTransactionsProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final amount = double.tryParse(amountController.text) ?? 0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          padding: EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(Color(0xFF1976D2)),
              ),
              SizedBox(height: 20),
              Text(
                'Connexion à PayGate...',
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF1976D2),
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 10),
              Text(
                'Initialisation du paiement',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final transactionId = 'pg_${DateTime.now().millisecondsSinceEpoch}';

      // ✅ REQUÊTE HTTP DIRECTE VERS L'URL EpargnePlus
      final response = await http.post(
        Uri.parse('https://initiatepaymentfromafrolook-b6fm6gdlrq-uc.a.run.app'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'data': {
            'transactionId': transactionId,
            'amount': amount,
            'userId': userTransactionsProvider.loginUserData.id,
            'type': 'afrolook_deposit',
            'phoneNumber': phoneNumber,
            'network': network,
            'userEmail': userTransactionsProvider.loginUserData.email,
            'userName': userTransactionsProvider.loginUserData.nom,
          }
        }),
      );

      Navigator.of(context).pop(); // Fermer le loader

      if (response.statusCode == 200) {
        final result = json.decode(response.body);

        if (result['result']?['success'] == true) {
          final paymentUrl = result['result']?['payment_url'];

          if (kIsWeb) {
            // Pour le web
            // html.window.open(paymentUrl, '_blank');
          } else {
            // Pour mobile
            if (await canLaunchUrl(Uri.parse(paymentUrl))) {
              await launchUrl(
                Uri.parse(paymentUrl),
                mode: LaunchMode.externalApplication,
              );
            }
          }
          Navigator.pop(context); // Fermer la page de dépôt
        } else {
          throw Exception(result['error']?['message'] ?? 'Erreur inconnue');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }

    } catch (e) {
      Navigator.of(context).pop(); // Fermer le loader

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Échec du traitement PayGate: ${e.toString()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF9F5EB),
      appBar: AppBar(
        title: Text(
          'Recharger mon portefeuille Afrolook',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: Color(0xFFD8A868),
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
                          color: Color(0xFF5C4A3C),
                        ),
                      ),
                      SizedBox(height: 15),
                      _buildInfoRow('• Montant minimum:', '200 FCFA', Color(0xFF5C4A3C)),
                      SizedBox(height: 8),
                      _buildInfoRow('• Frais de service:', '5,6% inclus', Color(0xFF5C4A3C)),
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
                  color: Color(0xFFFFEDD5),
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
                    Text(
                      'Choisissez CinetPay pour toute l\'Afrique ou PayGate spécifiquement pour le Togo.',
                      style: TextStyle(color: Colors.grey[800]),
                    ),
                    SizedBox(height: 10),
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
                      onPressed: _termsAccepted ? _showPaymentMethodSelection : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _termsAccepted ? Color(0xFFD8A868) : Colors.grey,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 3,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.payment, color: Colors.white),
                          SizedBox(width: 10),
                          Text(
                            'CHOISIR LE MODE DE PAIEMENT',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Color(0xFFE8F5E8),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Color(0xFF2E7D32).withOpacity(0.3)),
                ),
                child: Text(
                  'Vous serez redirigé vers une plateforme de paiement sécurisée pour finaliser votre recharge.',
                  style: TextStyle(
                    color: Color(0xFF2E7D32),
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
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
}

class _PaymentMethodCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String description;
  final IconData icon;
  final Color color;
  final Color iconColor;
  final VoidCallback onTap;

  const _PaymentMethodCard({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.color,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: color.withOpacity(0.2), width: 1),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF5C4A3C),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }
}