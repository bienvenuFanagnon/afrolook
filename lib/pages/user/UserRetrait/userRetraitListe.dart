// pages/retrait/user_retrait_list_page.dart
import 'package:afrotok/pages/component/consoleWidget.dart';
import 'package:afrotok/pages/contact.dart';
import 'package:afrotok/pages/user/UserRetrait/userRetraitForm.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../models/model_data.dart';
import '../../../providers/authProvider.dart';
import '../../../services/retraitService.dart';

class UserRetraitListPage extends StatefulWidget {
  @override
  State<UserRetraitListPage> createState() => _UserRetraitListPageState();
}

class _UserRetraitListPageState extends State<UserRetraitListPage> {

  // Méthode pour naviguer vers la page de contact
  void _navigateToContactPage(BuildContext context) {
    // Remplacez par votre navigation vers la page de contact
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ContactPage(), // Votre page de contact
      ),
    );

    // Ou ouvrir un URL/email/téléphone directement
    // _launchContactUrl();
  }

  // Méthode pour lancer les contacts (optionnel)
  void _launchContactUrl() async {
    // Exemple: ouvrir WhatsApp
    // const url = 'https://wa.me/228XXXXXXXXX';
    // if (await canLaunch(url)) {
    //   await launch(url);
    // } else {
    //   ScaffoldMessenger.of(context).showSnackBar(
    //     SnackBar(content: Text('Impossible d\'ouvrir le lien de contact')),
    //   );
    // }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<UserAuthProvider>();
    final userId = authProvider.userId;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          'Mes Demandes de Retrait',
          style: TextStyle(color: Colors.yellow[700]),
        ),
        backgroundColor: Colors.black,
        iconTheme: IconThemeData(color: Colors.yellow[700]),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => UserRetraitPage()),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<TransactionRetrait>>(
        stream: RetraitService.getRetraitsUtilisateur(userId!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: Colors.yellow[700]));
          }

          if (snapshot.hasError) {
            printVm("snapshot.hasError : ${snapshot.error.toString()}");
            return Center(
              child: Text(
                'Erreur de chargement',
                style: TextStyle(color: Colors.red),
              ),
            );
          }

          final retraits = snapshot.data ?? [];

          if (retraits.isEmpty) {
            return _buildEmptyState();
          }

          // Vérifier s'il y a des retraits en attente
          final hasPendingRetraits = retraits.any((retrait) => retrait.isEnAttente);

          return Column(
            children: [
              // Bannière pour les retraits en attente
              if (hasPendingRetraits) _buildPendingRetraitBanner(context),

              // Liste des retraits
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: retraits.length,
                  itemBuilder: (context, index) {
                    return _buildRetraitCard(retraits[index], context);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // Bannière pour les retraits en attente
  Widget _buildPendingRetraitBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange[800]!, Colors.orange[600]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.3),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.white, size: 24),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Action Requise',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Contactez notre service client pour finaliser vos retraits en attente',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => _navigateToContactPage(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.orange[800],
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: Text(
              'Contacter',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.money_off, size: 64, color: Colors.grey[600]),
          SizedBox(height: 16),
          Text(
            'Aucune demande de retrait',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 18,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Faites votre première demande de retrait',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRetraitCard(TransactionRetrait retrait, BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: retrait.statutColor.withOpacity(0.5),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête avec montant et statut
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${retrait.montant!.toStringAsFixed(2)} FCFA',
                style: TextStyle(
                  color: Colors.yellow[700],
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: retrait.statutColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: retrait.statutColor),
                ),
                child: Text(
                  retrait.statutText,
                  style: TextStyle(
                    color: retrait.statutColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),

          // Détails
          _buildDetailRow('Méthode', retrait.methodPaiement ?? 'Non spécifié'),
          _buildDetailRow('Compte', retrait.numeroCompte ?? 'Non spécifié'),
          _buildDetailRow('Date', _formatDate(retrait.createdAt!)),

          // Numéro de transaction
          if (retrait.numeroTransaction != null) ...[
            SizedBox(height: 8),
            GestureDetector(
              onTap: () => _copyTransactionId(retrait.numeroTransaction!, context),
              child: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green),
                ),
                child: Row(
                  children: [
                    Icon(Icons.copy, size: 16, color: Colors.green),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'ID: ${retrait.numeroTransaction!}',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      'Copier',
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Message spécial pour les retraits en attente
          if (retrait.isEnAttente) ...[
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.phone, size: 16, color: Colors.orange),
                      SizedBox(width: 8),
                      Text(
                        'Finalisez votre retrait',
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Contactez notre service client avec votre numéro de transaction pour terminer le processus.',
                    style: TextStyle(
                      color: Colors.orange[200],
                      fontSize: 12,
                    ),
                  ),
                  SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 36,
                    child: ElevatedButton(
                      onPressed: () => _navigateToContactPage(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: EdgeInsets.symmetric(horizontal: 16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.contact_support, size: 16),
                          SizedBox(width: 6),
                          Text(
                            'Contacter le Service',
                            style: TextStyle(
                              fontSize: 12,
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
          ],

          // Motif d'annulation
          if (retrait.isAnnule && retrait.motifAnnulation != null) ...[
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red),
              ),
              child: Text(
                'Motif: ${retrait.motifAnnulation!}',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 12,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${date.day}/${date.month}/${date.year} à ${date.hour}h${date.minute.toString().padLeft(2, '0')}';
  }

  void _copyTransactionId(String transactionId, BuildContext context) {
    Clipboard.setData(ClipboardData(text: transactionId));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Numéro de transaction copié!'),
        backgroundColor: Colors.green,
      ),
    );
  }
}

