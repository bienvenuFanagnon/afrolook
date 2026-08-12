// pages/admin/user_management_page.dart

import 'package:afrotok/pages/component/consoleWidget.dart';
import 'package:afrotok/pages/component/showUserDetails.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../models/model_data.dart';
import '../../../../providers/authProvider.dart';
import '../../../../widgets/interests_selector_widget.dart';
import '../../mes_gains_post_page.dart';
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
      printVm('Erreur chargement user: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateUserBalance(double amount, String type, String description, String raison, {String balanceField = 'votre_solde_principal'}) async {
    if (_userData == null) return;

    setState(() => _isUpdating = true);

    try {
      final currentBalance = balanceField == 'votre_solde_depot'
          ? (_userData!.votre_solde_depot ?? 0.0)
          : (_userData!.votre_solde_principal ?? 0.0);
      final newBalance = currentBalance + amount;

      await _firestore.collection('Users').doc(widget.userId).update({
        balanceField: newBalance,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      });

      await _firestore.collection('TransactionSoldes').add({
        'user_id': _userData!.id,
        'montant': amount.abs(),
        'type': type,
        'description': description,
        'raison': raison,
        'balance_field': balanceField,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'statut': StatutTransaction.VALIDER.name,
        'processed_by': Provider.of<UserAuthProvider>(context, listen: false).userId,
      });

      setState(() {
        if (balanceField == 'votre_solde_depot') {
          _userData!.votre_solde_depot = newBalance;
        } else {
          _userData!.votre_solde_principal = newBalance;
        }
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
    String selectedField = 'votre_solde_depot';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text(
            'Dépôt Manuel',
            style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Sélecteur de solde cible
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setDialogState(() => selectedField = 'votre_solde_depot'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: selectedField == 'votre_solde_depot' ? const Color(0xFF34C759) : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Solde Dépôt',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: selectedField == 'votre_solde_depot' ? Colors.white : Colors.white54,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setDialogState(() => selectedField = 'votre_solde_principal'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: selectedField == 'votre_solde_principal' ? Colors.amber[700] : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Solde Gains',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: selectedField == 'votre_solde_principal' ? Colors.white : Colors.white54,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  selectedField == 'votre_solde_depot'
                      ? 'Actuel : ${(_userData!.votre_solde_depot ?? 0.0).toStringAsFixed(2)} FCFA'
                      : 'Actuel : ${(_userData!.votre_solde_principal ?? 0.0).toStringAsFixed(2)} FCFA',
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: montantController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Montant (FCFA)',
                    labelStyle: TextStyle(color: Colors.grey[400]),
                    border: const OutlineInputBorder(),
                    enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.green)),
                    focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.green)),
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: raisonController,
                  decoration: InputDecoration(
                    labelText: 'Raison du dépôt',
                    labelStyle: TextStyle(color: Colors.grey[400]),
                    border: const OutlineInputBorder(),
                    enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.green)),
                    focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.green)),
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Description (optionnel)',
                    labelStyle: TextStyle(color: Colors.grey[400]),
                    border: const OutlineInputBorder(),
                    enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.green)),
                    focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.green)),
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('ANNULER', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                final montant = double.tryParse(montantController.text);
                if (montant == null || montant <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Montant invalide'), backgroundColor: Colors.red),
                  );
                  return;
                }
                if (raisonController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Veuillez saisir une raison'), backgroundColor: Colors.red),
                  );
                  return;
                }
                Navigator.pop(ctx);
                _updateUserBalance(
                  montant,
                  TypeTransaction.DEPOTADMIN.name,
                  descriptionController.text.isNotEmpty ? descriptionController.text : 'Dépôt administratif',
                  raisonController.text,
                  balanceField: selectedField,
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('DÉPOSER'),
            ),
          ],
        ),
      ),
    );
  }

  void _showRetraitDialog() {
    final montantController = TextEditingController();
    final descriptionController = TextEditingController();
    final raisonController = TextEditingController();
    String selectedField = 'votre_solde_principal';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text(
            'Retrait Manuel',
            style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Sélecteur de solde source
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setDialogState(() => selectedField = 'votre_solde_depot'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: selectedField == 'votre_solde_depot' ? const Color(0xFF34C759) : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Solde Dépôt',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: selectedField == 'votre_solde_depot' ? Colors.white : Colors.white54,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setDialogState(() => selectedField = 'votre_solde_principal'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: selectedField == 'votre_solde_principal' ? Colors.amber[700] : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Solde Gains',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: selectedField == 'votre_solde_principal' ? Colors.white : Colors.white54,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  selectedField == 'votre_solde_depot'
                      ? 'Actuel : ${(_userData!.votre_solde_depot ?? 0.0).toStringAsFixed(2)} FCFA'
                      : 'Actuel : ${(_userData!.votre_solde_principal ?? 0.0).toStringAsFixed(2)} FCFA',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: montantController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Montant (FCFA)',
                    labelStyle: TextStyle(color: Colors.grey[400]),
                    border: const OutlineInputBorder(),
                    enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.orange)),
                    focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.orange)),
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: raisonController,
                  decoration: InputDecoration(
                    labelText: 'Raison du retrait',
                    labelStyle: TextStyle(color: Colors.grey[400]),
                    border: const OutlineInputBorder(),
                    enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.orange)),
                    focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.orange)),
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Description (optionnel)',
                    labelStyle: TextStyle(color: Colors.grey[400]),
                    border: const OutlineInputBorder(),
                    enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.orange)),
                    focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.orange)),
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange),
                  ),
                  child: const Text(
                    'Note : Le solde peut devenir négatif pour corriger des erreurs.',
                    style: TextStyle(color: Colors.orange, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('ANNULER', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                final montant = double.tryParse(montantController.text);
                if (montant == null || montant <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Montant invalide'), backgroundColor: Colors.red),
                  );
                  return;
                }
                if (raisonController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Veuillez saisir une raison'), backgroundColor: Colors.red),
                  );
                  return;
                }
                Navigator.pop(ctx);
                _updateUserBalance(
                  -montant,
                  TypeTransaction.RETRAITADMIN.name,
                  descriptionController.text.isNotEmpty ? descriptionController.text : 'Retrait administratif',
                  raisonController.text,
                  balanceField: selectedField,
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text('RETIRER'),
            ),
          ],
        ),
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

            // Centres d'intérêt
            if ((_userData!.interests ?? []).isNotEmpty)
              _buildInterestsCard(),
            if ((_userData!.interests ?? []).isNotEmpty)
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

  Widget _buildInterestsCard() {
    final interests = _userData!.interests ?? [];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.favorite_outline, color: Color(0xFF1FAA59), size: 18),
              SizedBox(width: 8),
              Text(
                'Centres d\'intérêt',
                style: TextStyle(
                  color: Color(0xFF1FAA59),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          InterestsDisplayWidget(codes: interests, compact: true),
        ],
      ),
    );
  }

  Widget _buildBalanceCard() {
    final depot = _userData!.votre_solde_depot ?? 0.0;
    final principal = _userData!.votre_solde_principal ?? 0.0;

    return Row(
      children: [
        Expanded(child: _buildSingleBalanceTile('SOLDE DÉPÔT', depot, const Color(0xFF34C759))),
        const SizedBox(width: 12),
        Expanded(child: _buildSingleBalanceTile('SOLDE GAINS', principal, Colors.amber.shade700)),
      ],
    );
  }

  Widget _buildSingleBalanceTile(String label, double balance, Color color) {
    final isNegative = balance < 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isNegative ? Colors.red : color.withOpacity(0.5), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1)),
          const SizedBox(height: 8),
          Text(
            '${balance.toStringAsFixed(2)}',
            style: TextStyle(color: isNegative ? Colors.red : color, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          Text('FCFA', style: TextStyle(color: Colors.grey[600], fontSize: 11)),
          if (isNegative) ...[
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.warning, color: Colors.red, size: 12),
              const SizedBox(width: 4),
              const Text('Négatif', style: TextStyle(color: Colors.red, fontSize: 10)),
            ]),
          ],
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
          SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () {
              // Navigation vers la page des transactions de l'utilisateur
              Navigator.push(context, MaterialPageRoute(builder: (context) => MesGainsPage(userId: widget.userId!, isAdminView: true)));

            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[800],
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              minimumSize: Size(double.infinity, 50), // Pleine largeur
            ),
            icon: Icon(Iconsax.money),
            label: Text('Post Monétisation'),
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
          _buildDetailItem('Rôle', (_userData!.role?.isNotEmpty == true ? _userData!.role! : 'Utilisateur')),
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