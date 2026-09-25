// pages/retrait/user_retrait_list_page.dart
import 'package:afrotok/layout/centered_content.dart';
import 'package:afrotok/pages/component/consoleWidget.dart';
import 'package:afrotok/pages/contact.dart';
import 'package:afrotok/pages/user/UserRetrait/userRetraitForm.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../models/model_data.dart';
import '../../../providers/authProvider.dart';
import '../../../services/retraitService.dart';
import '../../../theme/app_colors.dart';

/// Liste des demandes de retrait de l'utilisateur (thèmes clair et sombre via [AppColors]).
class UserRetraitListPage extends StatefulWidget {
  @override
  State<UserRetraitListPage> createState() => _UserRetraitListPageState();
}

class _UserRetraitListPageState extends State<UserRetraitListPage> {
  static final NumberFormat _moneyFmt = NumberFormat('#,##0.##', 'fr');

  void _openContact() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const ContactPage()));
  }

  void _openNewRequest() {
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => UserDemandeRetraitPage()));
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final userId = context.watch<UserAuthProvider>().userId;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        title: Text('Mes retraits',
            style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 18)),
        backgroundColor: c.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: c.textPrimary),
        actions: [
          IconButton(
            icon: Icon(Icons.add_rounded, color: c.primary),
            tooltip: 'Nouvelle demande',
            onPressed: _openNewRequest,
          ),
        ],
      ),
      body: StreamBuilder<List<TransactionRetrait>>(
        stream: RetraitService.getRetraitsUtilisateur(userId!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: c.primary));
          }
          if (snapshot.hasError) {
            printVm("snapshot.hasError : ${snapshot.error.toString()}");
            return Center(child: Text('Erreur de chargement', style: TextStyle(color: c.danger)));
          }

          final retraits = snapshot.data ?? [];
          if (retraits.isEmpty) return _buildEmptyState(c);

          final hasPending = retraits.any((r) => r.isEnAttente);
          return CenteredContent(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                if (hasPending) ...[
                  _buildPendingBanner(c),
                  const SizedBox(height: 12),
                ],
                for (final r in retraits) _buildRetraitCard(r, c),
              ],
            ),
          );
        },
      ),
    );
  }

  // Bannière : des retraits attendent un contact avec le service client
  Widget _buildPendingBanner(AppColors c) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: c.warning.withOpacity(c.isDark ? 0.16 : 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.warning.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: c.warning, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Action requise',
                    style: TextStyle(color: c.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('Contacte le service client pour finaliser tes retraits en attente.',
                    style: TextStyle(color: c.textSecondary, fontSize: 12, height: 1.3)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: _openContact,
            style: FilledButton.styleFrom(
              backgroundColor: c.warning,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 34),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              shape: const StadiumBorder(),
            ),
            child: const Text('Contacter', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(AppColors c) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.account_balance_rounded, size: 52, color: c.textSecondary),
            const SizedBox(height: 14),
            Text('Aucune demande de retrait',
                style: TextStyle(color: c.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text('Tes demandes apparaîtront ici.',
                style: TextStyle(color: c.textSecondary, fontSize: 13)),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _openNewRequest,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Faire une demande', style: TextStyle(fontWeight: FontWeight.w700)),
              style: FilledButton.styleFrom(
                backgroundColor: c.primary,
                foregroundColor: c.onPrimary,
                shape: const StadiumBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRetraitCard(TransactionRetrait retrait, AppColors c) {
    final statutColor = retrait.statutColor;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Montant + statut
          Row(
            children: [
              Expanded(
                child: Text(
                  '${_moneyFmt.format(retrait.montant ?? 0)} FCFA',
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: statutColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(retrait.statutText,
                    style: TextStyle(color: statutColor, fontSize: 11.5, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _detailRow(c, 'Méthode', retrait.methodPaiement ?? 'Non spécifiée'),
          _detailRow(c, 'Compte', retrait.numeroCompte ?? 'Non spécifié'),
          _detailRow(c, 'Date', _formatDate(retrait.createdAt!)),

          // Numéro de transaction (copiable)
          if (retrait.numeroTransaction != null) ...[
            const SizedBox(height: 8),
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => _copyTransactionId(retrait.numeroTransaction!),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: c.surfaceVariant,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.tag_rounded, size: 15, color: c.textSecondary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(retrait.numeroTransaction!,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: c.textPrimary, fontSize: 12, fontFamily: 'monospace')),
                    ),
                    Icon(Icons.copy_rounded, size: 15, color: c.primary),
                    const SizedBox(width: 4),
                    Text('Copier', style: TextStyle(color: c.primary, fontSize: 12, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          ],

          // Retrait en attente : finaliser avec le service client
          if (retrait.isEnAttente) ...[
            const SizedBox(height: 10),
            Text(
              'Contacte le service client avec ton numéro de transaction pour terminer le retrait.',
              style: TextStyle(color: c.textSecondary, fontSize: 12, height: 1.35),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 36,
              child: OutlinedButton.icon(
                onPressed: _openContact,
                icon: Icon(Icons.support_agent_rounded, size: 17, color: c.warning),
                label: Text('Contacter le service client',
                    style: TextStyle(color: c.warning, fontSize: 12.5, fontWeight: FontWeight.w700)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: c.warning.withOpacity(0.5)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],

          // Motif d'annulation
          if (retrait.isAnnule && retrait.motifAnnulation != null) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: c.danger.withOpacity(c.isDark ? 0.16 : 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('Motif : ${retrait.motifAnnulation!}',
                  style: TextStyle(color: c.danger, fontSize: 12)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _detailRow(AppColors c, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(label, style: TextStyle(color: c.textSecondary, fontSize: 12)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(color: c.textPrimary, fontSize: 12, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  String _formatDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return DateFormat("d MMM yyyy 'à' HH'h'mm", 'fr').format(date);
  }

  void _copyTransactionId(String transactionId) {
    Clipboard.setData(ClipboardData(text: transactionId));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Numéro de transaction copié')),
    );
  }
}
