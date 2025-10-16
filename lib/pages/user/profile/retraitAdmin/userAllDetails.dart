// pages/admin/user_management_page.dart
import 'package:afrotok/pages/component/showUserDetails.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../models/model_data.dart';
import '../../../../providers/authProvider.dart';
import '../../userTransactionListe.dart';


class UserManagementPage extends StatefulWidget {
  final String userId;

  const UserManagementPage({Key? key, required this.userId}) : super(key: key);

  @override
  _UserManagementPageState createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  UserData? _userData;
  bool _isLoading = true;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final doc = await _firestore.collection('Users').doc(widget.userId).get();
      if (doc.exists) {
        final data = doc.data()!;
        data['id'] = doc.id;
        setState(() {
          _userData = UserData.fromJson(data);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Erreur chargement user: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateUserBalance(double amount, String type, String description, String raison) async {
    if (_userData == null) return;

    setState(() => _isUpdating = true);

    try {
      final newBalance = _userData!.votre_solde_principal! + amount;

      // Mettre à jour le solde de l'utilisateur
      await _firestore.collection('Users').doc(widget.userId).update({
        'votre_solde_principal': newBalance,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      });

      // Enregistrer la transaction
      await _firestore.collection('TransactionSoldes').add({
        'user_id': _userData!.id,
        'montant': amount.abs(),
        'type': type,
        'description': description,
        'raison': raison,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'statut': StatutTransaction.VALIDER.name,
        'processed_by': Provider.of<UserAuthProvider>(context, listen: false).userId,
      });

      // Mettre à jour les données locales
      setState(() {
        _userData!.votre_solde_principal = newBalance;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Opération effectuée avec succès!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isUpdating = false);
    }
  }

  void _showDepotDialog() {
    final montantController = TextEditingController();
    final descriptionController = TextEditingController();
    final raisonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(
          'Dépôt Manuel',
          style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: montantController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Montant (FCFA)',
                  labelStyle: TextStyle(color: Colors.grey[400]),
                  border: OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.green)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.green)),
                ),
                style: TextStyle(color: Colors.white),
              ),
              SizedBox(height: 12),
              TextField(
                controller: raisonController,
                decoration: InputDecoration(
                  labelText: 'Raison du dépôt',
                  labelStyle: TextStyle(color: Colors.grey[400]),
                  border: OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.green)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.green)),
                ),
                style: TextStyle(color: Colors.white),
              ),
              SizedBox(height: 12),
              TextField(
                controller: descriptionController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Description',
                  labelStyle: TextStyle(color: Colors.grey[400]),
                  border: OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.green)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.green)),
                ),
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('ANNULER', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              final montant = double.tryParse(montantController.text);
              if (montant == null || montant <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Montant invalide'), backgroundColor: Colors.red),
                );
                return;
              }
              if (raisonController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Veuillez saisir une raison'), backgroundColor: Colors.red),
                );
                return;
              }

              Navigator.pop(context);
              _updateUserBalance(
                montant,
                TypeTransaction.DEPOTADMIN.name,
                descriptionController.text.isNotEmpty ? descriptionController.text : 'Dépôt administratif',
                raisonController.text,
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: Text('DÉPOSER'),
          ),
        ],
      ),
    );
  }

  void _showRetraitDialog() {
    final montantController = TextEditingController();
    final descriptionController = TextEditingController();
    final raisonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(
          'Retrait Manuel',
          style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Solde actuel: ${_userData?.votre_solde_principal?.toStringAsFixed(2) ?? '0.00'} FCFA',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              TextField(
                controller: montantController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Montant (FCFA)',
                  labelStyle: TextStyle(color: Colors.grey[400]),
                  border: OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.orange)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.orange)),
                ),
                style: TextStyle(color: Colors.white),
              ),
              SizedBox(height: 12),
              TextField(
                controller: raisonController,
                decoration: InputDecoration(
                  labelText: 'Raison du retrait',
                  labelStyle: TextStyle(color: Colors.grey[400]),
                  border: OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.orange)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.orange)),
                ),
                style: TextStyle(color: Colors.white),
              ),
              SizedBox(height: 12),
              TextField(
                controller: descriptionController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Description',
                  labelStyle: TextStyle(color: Colors.grey[400]),
                  border: OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.orange)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.orange)),
                ),
                style: TextStyle(color: Colors.white),
              ),
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange),
                ),
                child: Text(
                  'Note: Le solde peut devenir négatif pour corriger des erreurs.',
                  style: TextStyle(color: Colors.orange, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('ANNULER', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              final montant = double.tryParse(montantController.text);
              if (montant == null || montant <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Montant invalide'), backgroundColor: Colors.red),
                );
                return;
              }
              if (raisonController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Veuillez saisir une raison'), backgroundColor: Colors.red),
                );
                return;
              }

              Navigator.pop(context);
              _updateUserBalance(
                -montant,
                TypeTransaction.RETRAITADMIN.name,
                descriptionController.text.isNotEmpty ? descriptionController.text : 'Retrait administratif',
                raisonController.text,
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: Text('RETIRER'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.yellow[700]),
        ),
      );
    }

    if (_userData == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: Text('Utilisateur non trouvé', style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.black,
          iconTheme: IconThemeData(color: Colors.yellow[700]),
        ),
        body: Center(
          child: Text(
            'Utilisateur non trouvé',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          'Gestion Utilisateur',
          style: TextStyle(color: Colors.yellow[700], fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.black,
        iconTheme: IconThemeData(color: Colors.yellow[700]),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Iconsax.refresh),
            onPressed: _loadUserData,
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // Carte profil utilisateur
            _buildProfileCard(),
            SizedBox(height: 20),

            // Carte solde principal
            _buildBalanceCard(),
            SizedBox(height: 20),

            // Actions admin
            _buildAdminActions(),
            SizedBox(height: 20),

            // Informations détaillées
            _buildUserDetails(),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard() {
    return GestureDetector(
      onTap: () {
        showUserDetailsModalDialog(_userData!, MediaQuery.of(context).size.width, MediaQuery.of(context).size.height, context);
      },
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.purple[800]!, Colors.purple[600]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.purple.withOpacity(0.4),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 40,
              backgroundImage: NetworkImage(_userData!.imageUrl ?? ''),
              backgroundColor: Colors.grey[800],
              child: _userData!.imageUrl == null || _userData!.imageUrl!.isEmpty
                  ? Icon(Icons.person, size: 40, color: Colors.white)
                  : null,
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _userData!.pseudo ?? 'Non renseigné',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    _userData!.email ?? 'Aucun email',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  SizedBox(height: 4),
                  Text(
                    _userData!.numeroDeTelephone ?? 'Aucun numéro',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _userData!.isVerify == true ? Colors.green : Colors.grey,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _userData!.isVerify == true ? 'Vérifié' : 'Non vérifié',
                          style: TextStyle(color: Colors.white, fontSize: 10),
                        ),
                      ),
                      SizedBox(width: 8),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _userData!.isBlocked == true ? Colors.red : Colors.green,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _userData!.isBlocked == true ? 'Bloqué' : 'Actif',
                          style: TextStyle(color: Colors.white, fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceCard() {
    final balance = _userData!.votre_solde_principal ?? 0.0;
    final isNegative = balance < 0;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isNegative ? Colors.red : Colors.green,
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Text(
            'SOLDE PRINCIPAL',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          SizedBox(height: 12),
          Text(
            '${balance.toStringAsFixed(2)} FCFA',
            style: TextStyle(
              color: isNegative ? Colors.red : Colors.yellow[700],
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          if (isNegative)
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.warning, color: Colors.red, size: 16),
                  SizedBox(width: 4),
                  Text(
                    'Solde négatif',
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
  Widget _buildAdminActions() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ACTIONS ADMINISTRATEUR',
            style: TextStyle(
              color: Colors.yellow[700],
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isUpdating ? null : _showDepotDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: Icon(Iconsax.add_circle),
                  label: Text('DÉPÔT MANUEL'),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isUpdating ? null : _showRetraitDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: Icon(Iconsax.minus_cirlce),
                  label: Text('RETRAIT MANUEL'),
                ),
              ),
            ],
          ),
          // AJOUTEZ CE BOUTON ICI - Nouvelle ligne pour le bouton des transactions
          SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () {
              // Navigation vers la page des transactions de l'utilisateur
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => UserTransactionsPage(userId: widget.userId),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[800],
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              minimumSize: Size(double.infinity, 50), // Pleine largeur
            ),
            icon: Icon(Iconsax.receipt),
            label: Text('VOIR LES TRANSACTIONS'),
          ),
          if (_isUpdating) ...[
            SizedBox(height: 16),
            Center(
              child: CircularProgressIndicator(color: Colors.yellow[700]),
            ),
          ],
        ],
      ),
    );
  }
  Widget _buildAdminActions2() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ACTIONS ADMINISTRATEUR',
            style: TextStyle(
              color: Colors.yellow[700],
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isUpdating ? null : _showDepotDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: Icon(Iconsax.add_circle),
                  label: Text('DÉPÔT MANUEL'),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isUpdating ? null : _showRetraitDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: Icon(Iconsax.minus_cirlce),
                  label: Text('RETRAIT MANUEL'),
                ),
              ),
            ],
          ),
          if (_isUpdating) ...[
            SizedBox(height: 16),
            Center(
              child: CircularProgressIndicator(color: Colors.yellow[700]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUserDetails() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'INFORMATIONS DÉTAILLÉES',
            style: TextStyle(
              color: Colors.yellow[700],
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16),
          _buildDetailItem('Nom complet', '${_userData!.nom ?? ''} ${_userData!.prenom ?? ''}'),
          _buildDetailItem('Genre', _userData!.genre ?? 'Non renseigné'),
          _buildDetailItem('Adresse', _userData!.adresse ?? 'Non renseignée'),
          _buildDetailItem('Code parrainage', _userData!.codeParrainage ?? 'Aucun'),
          _buildDetailItem('Rôle', _userData!.role ?? 'Utilisateur'),
          _buildDetailItem('Date création', _formatDate(_userData!.createdAt ?? 0)),
          _buildDetailItem('Dernière activité', _formatDate(_userData!.last_time_active ?? 0)),
          SizedBox(height: 12),
          Divider(color: Colors.grey[700]),
          SizedBox(height: 12),
          Text(
            'STATISTIQUES',
            style: TextStyle(
              color: Colors.green,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Row(
            children: [
              _buildStatItem('Abonnés', _userData!.userAbonnesIds!.length?.toString() ?? '0'),
              _buildStatItem('Publications', _userData!.mesPubs?.toString() ?? '0'),
              _buildStatItem('Likes', _userData!.likes?.toString() ?? '0'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? 'Non renseigné' : value,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Expanded(
      child: Container(
        margin: EdgeInsets.only(right: 8),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                color: Colors.yellow[700],
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(int timestamp) {
    if (timestamp == 0) return 'Non disponible';
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return DateFormat('dd/MM/yyyy à HH:mm').format(date);
  }
}