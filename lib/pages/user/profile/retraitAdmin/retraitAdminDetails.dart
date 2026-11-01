// pages/retrait/admin_retrait_detail_page.dart
import 'package:afrotok/pages/user/profile/retraitAdmin/userAllDetails.dart';
import 'package:flutter/material.dart';
import '../../../admin/admin_palette.dart';
import 'package:provider/provider.dart';

import '../../../../l10n/tr.dart';
import '../../../../models/model_data.dart';
import '../../../../providers/authProvider.dart';
import '../../../../services/api/audit_errors.dart';
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
    AdminPalette.of(context);
    final authProvider = context.watch<UserAuthProvider>();
    final adminId = authProvider.userId;

    return Scaffold(
      backgroundColor: AdminPalette.bg,
      appBar: AppBar(
        title: Text(
          'Détail du Retrait admin',
          style: TextStyle(color: AdminPalette.gold),
        ),
        backgroundColor: AdminPalette.bg,
        iconTheme: IconThemeData(color: AdminPalette.gold),
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
        color: AdminPalette.card,
        border: Border.all(color: AdminPalette.green.withOpacity(0.45)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            '${widget.retrait.montant!.toStringAsFixed(2)} FCFA',
            style: TextStyle(
              color: AdminPalette.gold,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: AdminPalette.field,
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
          if (widget.retrait.needsSecondValidation) ...[
            SizedBox(height: 8),
            _buildInfoRow(tr('Validé en premier par'), (widget.retrait.validatedBy ?? '').isEmpty ? tr('personne pour le moment') : widget.retrait.validatedBy!),
          ],
          if (widget.retrait.risk.isNotEmpty) ...[
            SizedBox(height: 12),
            _buildRiskSignals(),
          ],
        ],
      ),
    );
  }

  /// Signaux de risque joints à la demande par l'API (compte récent, gains récents, gros montant).
  Widget _buildRiskSignals() {
    return Container(
      key: const Key('retrait_risk_signals'),
      width: double.infinity,
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.withOpacity(0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 18),
            SizedBox(width: 6),
            Text(tr('Signaux de risque'), style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
          ]),
          SizedBox(height: 6),
          for (final r in widget.retrait.risk)
            Padding(
              padding: EdgeInsets.only(top: 3),
              child: Text('• ${AuditErrors.riskLabel(r)}', style: TextStyle(color: AdminPalette.textP, fontSize: 13)),
            ),
        ],
      ),
    );
  }

  Widget _buildUserInfoCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminPalette.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminPalette.gold),
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
                  color: AdminPalette.gold,
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
    final step = withdrawalStep(
      needsSecondValidation: widget.retrait.needsSecondValidation,
      validatedBy: widget.retrait.validatedBy,
      me: adminId,
    );
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminPalette.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            'Actions Administrateur',
            style: TextStyle(
              color: AdminPalette.gold,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16),

          // Validation à deux dès le seuil fixé par l'API : « Valider » (1re approbation), puis une AUTRE personne paie
          if (step == WithdrawalStep.needsFirstValidation) ...[
            Text(
              tr('Gros montant : une première personne valide, une autre personne de l’équipe paie.'),
              style: TextStyle(color: AdminPalette.textS, fontSize: 13),
            ),
            SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                key: const Key('retrait_btn_valider'),
                onPressed: _isLoading ? null : _premiereValidation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: Icon(Icons.how_to_reg),
                label: Text(tr('VALIDER (1re approbation)')),
              ),
            ),
          ] else if (step == WithdrawalStep.waitingSecondApprover) ...[
            Container(
              key: const Key('retrait_attente_second'),
              width: double.infinity,
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.6)),
              ),
              child: Row(children: [
                Icon(Icons.hourglass_top, color: Colors.blue, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tr('En attente d’un second approbateur : tu as validé ce retrait, une autre personne de l’équipe doit le payer.'),
                    style: TextStyle(color: AdminPalette.textP, fontSize: 13),
                  ),
                ),
              ]),
            ),
          ] else ...[
            // Paiement (fait à la main) : sous le seuil, ou déjà validé par une autre personne
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                key: const Key('retrait_btn_payer'),
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
                label: Text(tr('CONFIRMER LE PAIEMENT')),
              ),
            ),
          ],
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
            Divider(color: AdminPalette.border),
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
              color: AdminPalette.textS,
              fontSize: 14,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: AdminPalette.textP,
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
                color: AdminPalette.textS,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: AdminPalette.textP,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Première approbation d'un gros retrait : rien n'est payé, une autre personne de l'équipe devra payer.
  Future<void> _premiereValidation() async {
    final adminId = context.read<UserAuthProvider>().userId;
    setState(() => _isLoading = true);
    try {
      final ok = await RetraitService.premiereValidation(retraitId: widget.retrait.id!);
      if (!mounted) return;
      if (ok) {
        setState(() => widget.retrait.validatedBy = adminId);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('Retrait validé. Une autre personne de l’équipe doit maintenant le payer.')), backgroundColor: Colors.blue),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(RetraitService.lastError ?? tr('Opération impossible')), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
      } else if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(RetraitService.lastError ?? 'Opération impossible'), backgroundColor: Colors.red),
        );
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
        backgroundColor: AdminPalette.card,
        title: Text(
          'Annuler le retrait',
          style: TextStyle(color: AdminPalette.gold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Veuillez saisir le motif d\'annulation:',
              style: TextStyle(color: AdminPalette.textP),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _motifController,
              maxLines: 3,
              style: TextStyle(color: AdminPalette.textP),
              decoration: InputDecoration(
                hintText: 'Motif d\'annulation...',
                hintStyle: TextStyle(color: AdminPalette.textS),
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
            child: Text('ANNULER', style: TextStyle(color: AdminPalette.textS)),
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
      } else if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(RetraitService.lastError ?? 'Opération impossible'), backgroundColor: Colors.red),
        );
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