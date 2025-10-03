// pages/retrait/admin_retrait_detail_page.dart
import 'package:afrotok/pages/user/profile/retraitAdmin/userAllDetails.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../models/model_data.dart';
import '../../../../providers/authProvider.dart';
import '../../../../services/retraitService.dart';

class AdminRetraitDetailPage extends StatefulWidget {
  final TransactionRetrait retrait;

  const AdminRetraitDetailPage({Key? key, required this.retrait}) : super(key: key);

  @override
  _AdminRetraitDetailPageState createState() => _AdminRetraitDetailPageState();
}

class _AdminRetraitDetailPageState extends State<AdminRetraitDetailPage> {
  final TextEditingController _motifController = TextEditingController();
  bool _isLoading = false;

  void _navigateToUserManagement() {
    if (widget.retrait.userId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => UserManagementPage(userId: widget.retrait.userId!),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ID utilisateur non disponible'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<UserAuthProvider>();
    final adminId = authProvider.userId;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          'Détail du Retrait admin',
          style: TextStyle(color: Colors.yellow[700]),
        ),
        backgroundColor: Colors.black,
        iconTheme: IconThemeData(color: Colors.yellow[700]),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // Carte principale
            _buildRetraitCard(),
            SizedBox(height: 20),

            // Informations utilisateur
            _buildUserInfoCard(),
            SizedBox(height: 20),

            // Actions admin
            if (widget.retrait.isEnAttente) _buildAdminActions(adminId!),
          ],
        ),
      ),
    );
  }

  Widget _buildRetraitCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green[800]!, Colors.green[600]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            '${widget.retrait.montant!.toStringAsFixed(2)} FCFA',
            style: TextStyle(
              color: Colors.yellow[700],
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              widget.retrait.statutText,
              style: TextStyle(
                color: widget.retrait.statutColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(height: 16),
          _buildInfoRow('Méthode', widget.retrait.methodPaiement ?? 'Non spécifié'),
          _buildInfoRow('Numéro', widget.retrait.numeroCompte ?? 'Non spécifié'),
          _buildInfoRow('Date', _formatDate(widget.retrait.createdAt!)),
          if (widget.retrait.numeroTransaction != null)
            _buildInfoRow('Transaction', widget.retrait.numeroTransaction!),
        ],
      ),
    );
  }

  Widget _buildUserInfoCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.yellow[700]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Informations Utilisateur',
                style: TextStyle(
                  color: Colors.yellow[700],
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              // NOUVEAU: Bouton pour voir les détails de l'utilisateur
              if (widget.retrait.userId != null)
                ElevatedButton.icon(
                  onPressed: _navigateToUserManagement,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: Icon(Icons.person, size: 16),
                  label: Text(
                    'Voir Profil',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
            ],
          ),
          SizedBox(height: 12),
          _buildUserInfoRow('Pseudo', widget.retrait.userPseudo ?? 'Non renseigné'),
          _buildUserInfoRow('Email', widget.retrait.userEmail ?? 'Non renseigné'),
          _buildUserInfoRow('Téléphone', widget.retrait.userPhone ?? 'Non renseigné'),
          if (widget.retrait.userId != null)
            _buildUserInfoRow('ID Utilisateur', widget.retrait.userId!),
        ],
      ),
    );
  }

  Widget _buildAdminActions(String adminId) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            'Actions Administrateur',
            style: TextStyle(
              color: Colors.yellow[700],
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16),

          // Bouton Valider
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : () => _validerRetrait(adminId),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: Icon(Icons.check_circle),
              label: Text('VALIDER LE RETRAIT'),
            ),
          ),
          SizedBox(height: 12),

          // Bouton Annuler
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _showAnnulationDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: Icon(Icons.cancel),
              label: Text('ANNULER LE RETRAIT'),
            ),
          ),

          // NOUVEAU: Bouton pour gérer l'utilisateur
          if (widget.retrait.userId != null) ...[
            SizedBox(height: 12),
            Divider(color: Colors.grey[700]),
            SizedBox(height: 8),
            Text(
              'Gestion Utilisateur',
              style: TextStyle(
                color: Colors.purple,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _navigateToUserManagement,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: Icon(Icons.manage_accounts),
                label: Text('GÉRER LE COMPTE UTILISATEUR'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _validerRetrait(String adminId) async {
    setState(() => _isLoading = true);

    try {
      final success = await RetraitService.validerRetrait(
        retraitId: widget.retrait.id!,
        adminId: adminId,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Retrait validé avec succès!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showAnnulationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(
          'Annuler le retrait',
          style: TextStyle(color: Colors.yellow[700]),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Veuillez saisir le motif d\'annulation:',
              style: TextStyle(color: Colors.white),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _motifController,
              maxLines: 3,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Motif d\'annulation...',
                hintStyle: TextStyle(color: Colors.grey[600]),
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.red),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.red),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.red),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('ANNULER', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: _motifController.text.isEmpty ? null : () => _annulerRetrait(context),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('CONFIRMER'),
          ),
        ],
      ),
    );
  }

  Future<void> _annulerRetrait(BuildContext dialogContext) async {
    final adminId = context.read<UserAuthProvider>().userId!;

    setState(() => _isLoading = true);
    Navigator.pop(dialogContext);

    try {
      final success = await RetraitService.annulerRetrait(
        retraitId: widget.retrait.id!,
        adminId: adminId,
        motif: _motifController.text,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Retrait annulé et solde remboursé!'),
            backgroundColor: Colors.orange,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${date.day}/${date.month}/${date.year} à ${date.hour}h${date.minute.toString().padLeft(2, '0')}';
  }
}