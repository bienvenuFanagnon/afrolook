import 'package:flutter/material.dart';
import 'package:cinetpay/cinetpay.dart';

class PaiementPage extends StatelessWidget {
  final int montant;
  // final Str montant;
  final Function(bool) onSuccess;

  const PaiementPage({
    Key? key,
    required this.montant,
    required this.onSuccess,
  }) : super(key: key);

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Erreur de paiement"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(title: const Text("Guichet de paiement")),
      body: Center(
        child: CinetPayCheckout(
          title: 'Guichet de paiement Afrolook',
          configData: <String, dynamic>{
            'apikey': '102325650865f879a7b10492.83921456',
            'site_id': '5870078',
            'notify_url': 'https://mondomaine.com/notify/'
          },
          paymentData: <String, dynamic>{
            'transaction_id': '${DateTime.now().millisecondsSinceEpoch}',
            'amount': montant,
            'currency': 'XOF',
            'channels': 'ALL',
            'description': 'Paiement sécurisé'
          },
          waitResponse: (response) {
            if (response['status'] == 'ACCEPTED') {
              onSuccess(true);
              Navigator.pop(context);
            } else {
              _showErrorDialog(context, "Le paiement a échoué.");
            }
          },
          onError: (error) {
            _showErrorDialog(context, error.toString());
          },
        ),
      ),
    );
  }
}
