import 'package:flutter/material.dart';

/// Page retirée de cette version (plus aucune lecture Firebase). Le fichier pourra être supprimé ou réécrit quand l'API aura la fonction.
class PaymentLogsAdminPage extends StatelessWidget {
  const PaymentLogsAdminPage({super.key, this.preview});
  final Object? preview;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Suivi des paiements')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Cette page n’est pas encore disponible dans la nouvelle version : le serveur n’a pas encore la fonction correspondante (voir lacunes_api_regie_admin.md).', textAlign: TextAlign.center),
        ),
      ),
    );
  }
}
