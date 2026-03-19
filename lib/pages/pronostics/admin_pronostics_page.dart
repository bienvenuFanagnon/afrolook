// pages/pronostics/admin_pronostics_page.dart

import 'package:afrotok/pages/component/consoleWidget.dart';
import 'package:afrotok/providers/authProvider.dart';
import 'package:afrotok/providers/pronostic_provider.dart';
import 'package:afrotok/services/pronostic_payment_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/model_data.dart';
import 'create_pronostic_page.dart';
import 'pronostic_detail_page.dart';

class AdminPronosticsPage extends StatefulWidget {
  const AdminPronosticsPage({Key? key}) : super(key: key);

  @override
  State<AdminPronosticsPage> createState() => _AdminPronosticsPageState();
}

class _AdminPronosticsPageState extends State<AdminPronosticsPage> {
  late PronosticProvider _pronosticProvider;
  late UserAuthProvider _authProvider;
  late PronosticPaymentService _paymentService;

  // Filtre par statut
  PronosticStatut? _selectedFilter;

  // États pour les dialogs de chargement
  bool _isProcessing = false;

  // Couleurs
  final Color _primaryColor = const Color(0xFFE21221); // Rouge
  final Color _secondaryColor = const Color(0xFFFFD600); // Jaune
  final Color _backgroundColor = const Color(0xFF121212); // Noir
  final Color _cardColor = const Color(0xFF1E1E1E);
  final Color _textColor = Colors.white;
  final Color _hintColor = Colors.grey[400]!;

  @override
  void initState() {
    super.initState();
    _pronosticProvider = Provider.of<PronosticProvider>(context, listen: false);
    _authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    _paymentService = PronosticPaymentService();
  }

  // Couleurs par statut
  Color _getStatutColor(PronosticStatut statut) {
    switch (statut) {
      case PronosticStatut.OUVERT:
        return Colors.green;
      case PronosticStatut.EN_COURS:
        return Colors.orange;
      case PronosticStatut.TERMINE:
        return Colors.blue;
      case PronosticStatut.GAINS_DISTRIBUES:
        return Colors.purple;
    }
  }

  // Icône par statut
  IconData _getStatutIcon(PronosticStatut statut) {
    switch (statut) {
      case PronosticStatut.OUVERT:
        return Iconsax.lock_1;
      case PronosticStatut.EN_COURS:
        return Iconsax.clock;
      case PronosticStatut.TERMINE:
        return Iconsax.tick_circle;
      case PronosticStatut.GAINS_DISTRIBUES:
        return Iconsax.money;
    }
  }

  // Formatage de la date
  String _formatDate(int? timestamp) {
    if (timestamp == null) return 'N/A';
    final date = DateTime.fromMicrosecondsSinceEpoch(timestamp);
    return DateFormat('dd/MM/yy HH:mm').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _cardColor,
        title: Row(
          children: [
            const Text(
              'Gestion des pronostics',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          // Bouton pour créer un nouveau pronostic
          IconButton(
            onPressed: _isProcessing ? null : () => _navigateToCreatePronostic(),
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _secondaryColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: _isProcessing
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.black,
                ),
              )
                  : const Icon(Iconsax.add, color: Colors.black, size: 20),
            ),
          ),
          const SizedBox(width: 8),

          // Filtre par statut
          PopupMenuButton<PronosticStatut?>(
            icon: Icon(Iconsax.filter, color: _secondaryColor),
            color: _cardColor,
            onSelected: (statut) {
              setState(() {
                _selectedFilter = statut;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem<PronosticStatut?>(
                value: null,
                child: Text('Tous', style: TextStyle(color: Colors.white)),
              ),
              ...PronosticStatut.values.map((statut) => PopupMenuItem<PronosticStatut?>(
                value: statut,
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: _getStatutColor(statut),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      statut.name,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              )),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<List<Pronostic>>(
        stream: _pronosticProvider.streamAllPronostics(
          statut: _selectedFilter,
          limit: 50,
        ),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            printVm("Erreur pronostic: ${snapshot.error}");
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Iconsax.warning_2, size: 60, color: _primaryColor),
                  const SizedBox(height: 16),
                  Text(
                    'Erreur: ${snapshot.error}',
                    style: TextStyle(color: _textColor),
                  ),
                ],
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: _primaryColor),
            );
          }

          final pronostics = snapshot.data ?? [];

          if (pronostics.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Iconsax.chart, size: 80, color: _hintColor),
                  const SizedBox(height: 16),
                  Text(
                    'Aucun pronostic trouvé',
                    style: TextStyle(color: _hintColor, fontSize: 16),
                  ),
                  const SizedBox(height: 20),

                  // Bouton pour créer le premier pronostic
                  ElevatedButton.icon(
                    onPressed: _isProcessing ? null : () => _navigateToCreatePronostic(),
                    icon: const Icon(Iconsax.add),
                    label: const Text('CRÉER UN PRONOSTIC'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                  ),

                  if (_selectedFilter != null) ...[
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _selectedFilter = null;
                        });
                      },
                      child: Text(
                        'Voir tous les pronostics',
                        style: TextStyle(color: _secondaryColor),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: pronostics.length,
            itemBuilder: (context, index) {
              final pronostic = pronostics[index];
              return GestureDetector(
                onTap: () => _navigateToDetail(pronostic),
                child: _buildPronosticCard(pronostic),
              );
            },
          );
        },
      ),

      // Bouton flottant pour créer un nouveau pronostic
      floatingActionButton: FloatingActionButton(
        onPressed: _isProcessing ? null : () => _navigateToCreatePronostic(),
        backgroundColor: _primaryColor,
        child: _isProcessing
            ? const CircularProgressIndicator(color: Colors.white)
            : const Icon(Iconsax.add, color: Colors.white),
      ),
    );
  }

  // Navigation vers la page de création
  void _navigateToCreatePronostic() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CreatePronosticPage(),
      ),
    ).then((created) {
      if (created == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Pronostic créé avec succès'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  // Navigation vers la page de détail
  void _navigateToDetail(Pronostic pronostic) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PronosticDetailPage(
          postId: pronostic.postId,
        ),
      ),
    );
  }

  Widget _buildPronosticCard(Pronostic pronostic) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _secondaryColor.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: _secondaryColor.withOpacity(0.1),
            blurRadius: 8,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // En-tête avec équipes
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                // Logo équipe A
                _buildTeamLogo(pronostic.equipeA.urlLogo),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pronostic.equipeA.nom,
                        style: TextStyle(
                          color: _textColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      // Score en direct pour les matchs en cours
                      if (pronostic.statut == PronosticStatut.EN_COURS && pronostic.scoreFinalEquipeA != null)
                        Text(
                          'Score actuel: ${pronostic.scoreFinalEquipeA}',
                          style: TextStyle(
                            color: _secondaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        )
                      else if (pronostic.scoreFinalEquipeA != null)
                        Text(
                          'Score final: ${pronostic.scoreFinalEquipeA}',
                          style: TextStyle(
                            color: _primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                    ],
                  ),
                ),

                // VS avec effet
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_primaryColor, _primaryColor.withOpacity(0.7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: _primaryColor.withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Text(
                    pronostic.statut == PronosticStatut.EN_COURS ? 'LIVE' : 'VS',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),

                // Logo équipe B
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        pronostic.equipeB.nom,
                        style: TextStyle(
                          color: _textColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                      ),
                      const SizedBox(height: 4),
                      if (pronostic.statut == PronosticStatut.EN_COURS && pronostic.scoreFinalEquipeB != null)
                        Text(
                          '${pronostic.scoreFinalEquipeB}',
                          style: TextStyle(
                            color: _secondaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        )
                      else if (pronostic.scoreFinalEquipeB != null)
                        Text(
                          '${pronostic.scoreFinalEquipeB}',
                          style: TextStyle(
                            color: _primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _buildTeamLogo(pronostic.equipeB.urlLogo),
              ],
            ),
          ),

          // Informations
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _backgroundColor,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
              border: Border(
                top: BorderSide(
                  color: _secondaryColor.withOpacity(0.2),
                  width: 1,
                ),
              ),
            ),
            child: Column(
              children: [
                // Stats rapides
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(
                      icon: Iconsax.people,
                      value: '${pronostic.nombreParticipants}',
                      label: 'Participants',
                      color: Colors.blue,
                    ),
                    _buildStatItem(
                      icon: Iconsax.money,
                      value: '${pronostic.cagnotte.toStringAsFixed(0)} F',
                      label: 'Cagnotte',
                      color: _secondaryColor,
                    ),
                    _buildStatItem(
                      icon: Iconsax.chart,
                      value: '${pronostic.nombrePronosticsUniques}',
                      label: 'Scores',
                      color: Colors.green,
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Badge statut et type
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getStatutColor(pronostic.statut).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _getStatutColor(pronostic.statut),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getStatutIcon(pronostic.statut),
                            size: 14,
                            color: _getStatutColor(pronostic.statut),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            pronostic.statut.name,
                            style: TextStyle(
                              color: _getStatutColor(pronostic.statut),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (pronostic.typeAcces == 'PAYANT')
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _secondaryColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _secondaryColor,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Iconsax.money, size: 14, color: _secondaryColor),
                            const SizedBox(width: 4),
                            Text(
                              '${pronostic.prixParticipation.toStringAsFixed(0)} F',
                              style: TextStyle(
                                color: _secondaryColor,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.green,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Iconsax.lock_1, size: 14, color: Colors.green),
                            const SizedBox(width: 4),
                            const Text(
                              'GRATUIT',
                              style: TextStyle(
                                color: Colors.green,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 16),

                // Boutons d'action selon le statut
                if (pronostic.statut == PronosticStatut.OUVERT)
                  _buildActionButton(
                    label: 'DÉMARRER LE MATCH',
                    icon: Iconsax.play,
                    color: Colors.green,
                    onTap: () => _showDemarrerMatchDialog(pronostic),
                  )
                else if (pronostic.statut == PronosticStatut.EN_COURS)
                  Column(
                    children: [
                      // Bouton pour mettre à jour le score en direct
                      _buildActionButton(
                        label: 'METTRE À JOUR LE SCORE',
                        icon: Iconsax.edit,
                        color: Colors.orange,
                        onTap: () => _showUpdateScoreDialog(pronostic),
                      ),
                      const SizedBox(height: 8),
                      // Bouton pour terminer le match
                      _buildActionButton(
                        label: 'TERMINER LE MATCH',
                        icon: Iconsax.tick_circle,
                        color: Colors.red,
                        onTap: () => _showTerminerMatchDialog(pronostic),
                      ),
                    ],
                  )
                else if (pronostic.statut == PronosticStatut.TERMINE)
                    _buildActionButton(
                      label: 'DISTRIBUER LES GAINS',
                      icon: Iconsax.money,
                      color: _secondaryColor,
                      onTap: () => _showDistributionDialog(pronostic),
                    ),

                const SizedBox(height: 12),

                // Indication pour voir les détails
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: _secondaryColor.withOpacity(0.2)),
                      bottom: BorderSide(color: _secondaryColor.withOpacity(0.2)),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Iconsax.arrow_right, color: _secondaryColor, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        'Toucher pour voir les détails',
                        style: TextStyle(
                          color: _secondaryColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // Détails
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Iconsax.calendar, color: _hintColor, size: 10),
                        const SizedBox(width: 4),
                        Text(
                          'Créé: ${_formatDate(pronostic.dateCreation.microsecondsSinceEpoch)}',
                          style: TextStyle(color: _hintColor, fontSize: 10),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Icon(Iconsax.people, color: _hintColor, size: 10),
                        const SizedBox(width: 4),
                        Text(
                          'Quota: ${pronostic.quotaMaxParScore}/score',
                          style: TextStyle(color: _hintColor, fontSize: 10),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamLogo(String url) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _secondaryColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: url.isNotEmpty && url != 'https://via.placeholder.com/150'
          ? ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Icon(MaterialIcons.sports_soccer, color: _hintColor);
          },
        ),
      )
          : Icon(MaterialIcons.sports_soccer, color: _hintColor),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: color.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: _textColor,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: _hintColor, fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withOpacity(0.2),
              color.withOpacity(0.1),
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Dialog pour démarrer le match
  void _showDemarrerMatchDialog(Pronostic pronostic) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: _secondaryColor, width: 2),
        ),
        title: Row(
          children: [
            Icon(Iconsax.play, color: Colors.green),
            const SizedBox(width: 10),
            const Text(
              'Démarrer le match',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${pronostic.equipeA.nom} vs ${pronostic.equipeB.nom}',
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 16),
            const Text(
              'Une fois démarré, plus personne ne pourra participer.\nVoulez-vous continuer ?',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('ANNULER', style: TextStyle(color: _hintColor)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              _showProcessingDialog();

              try {
                await _pronosticProvider.updateStatut(
                  pronosticId: pronostic.id,
                  nouveauStatut: PronosticStatut.EN_COURS,
                );
                // Récupérer les IDs des participants
                List<String> participantsIds = pronostic.toutesParticipations
                    .map((participation) => participation.userId)
                    .where((userId) => userId.isNotEmpty)
                    .toList();

                // Message de notification
                String message = '⚽ Le match ${pronostic.equipeA.nom} vs ${pronostic.equipeB.nom} a commencé ! Les pronostics sont maintenant fermés.';

                // Envoyer la notification à tous les participants
                if (participantsIds.isNotEmpty) {
                  await _authProvider.sendPushToSpecificUsers(
                    userIds: participantsIds,
                    sender: _authProvider.loginUserData,
                    message: message,
                    typeNotif: NotificationType.POST.name,
                    postId: pronostic.postId,
                    postType: 'PRONOSTIC',
                    chatId: '',
                  );
                }

                if (context.mounted) {
                  Navigator.of(context, rootNavigator: true).pop(); // 🔥 ferme le loader

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('✅ Match démarré pour ${pronostic.equipeA.nom} vs ${pronostic.equipeB.nom}'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.of(context, rootNavigator: true).pop(); // 🔥 ferme le loader
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('❌ Erreur: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('DÉMARRER'),
          ),
        ],
      ),
    );
  }

  // Dialog pour mettre à jour le score en direct
  void _showUpdateScoreDialog(Pronostic pronostic) {
    int scoreA = pronostic.scoreFinalEquipeA ?? 0;
    int scoreB = pronostic.scoreFinalEquipeB ?? 0;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: _cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: _secondaryColor, width: 2),
            ),
            title: Row(
              children: [
                Icon(Iconsax.edit, color: Colors.orange),
                const SizedBox(width: 10),
                const Text(
                  'Mettre à jour le score',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Match en cours - Mettez à jour le score en direct',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    // Équipe A
                    Expanded(
                      child: Column(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.grey[900],
                              borderRadius: BorderRadius.circular(25),
                              border: Border.all(color: _primaryColor, width: 2),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(25),
                              child: pronostic.equipeA.urlLogo.isNotEmpty
                                  ? Image.network(
                                pronostic.equipeA.urlLogo,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Icon(MaterialIcons.sports_soccer, color: _hintColor);
                                },
                              )
                                  : Icon(MaterialIcons.sports_soccer, color: _hintColor),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            pronostic.equipeA.nom,
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                onPressed: () {
                                  setState(() {
                                    if (scoreA > 0) scoreA--;
                                  });
                                },
                                icon: Icon(Icons.remove, color: _secondaryColor),
                              ),
                              Container(
                                width: 50,
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: _backgroundColor,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: _secondaryColor),
                                ),
                                child: Text(
                                  '$scoreA',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              IconButton(
                                onPressed: () {
                                  setState(() {
                                    scoreA++;
                                  });
                                },
                                icon: Icon(Icons.add, color: _secondaryColor),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        ':',
                        style: TextStyle(color: Colors.white, fontSize: 24),
                      ),
                    ),

                    // Équipe B
                    Expanded(
                      child: Column(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.grey[900],
                              borderRadius: BorderRadius.circular(25),
                              border: Border.all(color: _primaryColor, width: 2),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(25),
                              child: pronostic.equipeB.urlLogo.isNotEmpty
                                  ? Image.network(
                                pronostic.equipeB.urlLogo,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Icon(MaterialIcons.sports_soccer, color: _hintColor);
                                },
                              )
                                  : Icon(MaterialIcons.sports_soccer, color: _hintColor),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            pronostic.equipeB.nom,
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                onPressed: () {
                                  setState(() {
                                    if (scoreB > 0) scoreB--;
                                  });
                                },
                                icon: Icon(Icons.remove, color: _secondaryColor),
                              ),
                              Container(
                                width: 50,
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: _backgroundColor,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: _secondaryColor),
                                ),
                                child: Text(
                                  '$scoreB',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              IconButton(
                                onPressed: () {
                                  setState(() {
                                    scoreB++;
                                  });
                                },
                                icon: Icon(Icons.add, color: _secondaryColor),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('ANNULER', style: TextStyle(color: _hintColor)),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  _showProcessingDialog();

                  try {
                    await _pronosticProvider.updateScore(
                      pronosticId: pronostic.id,
                      scoreA: scoreA,
                      scoreB: scoreB,
                    );

                    if (context.mounted) {
                      Navigator.of(context, rootNavigator: true).pop(); // 🔥 ferme le loader
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('✅ Score mis à jour: $scoreA - $scoreB'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      Navigator.of(context, rootNavigator: true).pop(); // 🔥 ferme le loader
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('❌ Erreur: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
                child: const Text('METTRE À JOUR'),
              ),
            ],
          );
        },
      ),
    );
  }

  // Dialog pour terminer le match
  void _showTerminerMatchDialog(Pronostic pronostic) {
    int scoreA = pronostic.scoreFinalEquipeA ?? 0;
    int scoreB = pronostic.scoreFinalEquipeB ?? 0;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: _cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: _secondaryColor, width: 2),
            ),
            title: Row(
              children: [
                Icon(Iconsax.tick_circle, color: Colors.red),
                const SizedBox(width: 10),
                const Text(
                  'Terminer le match',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Confirmez le score final pour terminer le match',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            pronostic.equipeA.nom,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: 80,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _backgroundColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _primaryColor),
                            ),
                            child: Text(
                              '$scoreA',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        '-',
                        style: TextStyle(color: Colors.white, fontSize: 24),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            pronostic.equipeB.nom,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: 80,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _backgroundColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _primaryColor),
                            ),
                            child: Text(
                              '$scoreB',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('ANNULER', style: TextStyle(color: _hintColor)),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  _showProcessingDialog();

                  try {
                    await _pronosticProvider.updateStatut(
                      pronosticId: pronostic.id,
                      nouveauStatut: PronosticStatut.TERMINE,
                    );

                    if (context.mounted) {
                      Navigator.of(context, rootNavigator: true).pop(); // 🔥 ferme le loader
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('✅ Match terminé: $scoreA - $scoreB'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      Navigator.of(context, rootNavigator: true).pop(); // 🔥 ferme le loader
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('❌ Erreur: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('TERMINER'),
              ),
            ],
          );
        },
      ),
    );
  }

  // Dialog pour distribuer les gains
  void _showDistributionDialog(Pronostic pronostic) {
    if (pronostic.scoreFinalEquipeA == null || pronostic.scoreFinalEquipeB == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Score final non défini'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    String scoreGagnantKey = '${pronostic.scoreFinalEquipeA}-${pronostic.scoreFinalEquipeB}';
    List<String> gagnantsIds = pronostic.participationsParScore[scoreGagnantKey] ?? [];
    double gainParGagnant = gagnantsIds.isEmpty ? 0 : pronostic.cagnotte / gagnantsIds.length;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: _secondaryColor, width: 2),
        ),
        title: Row(
          children: [
            Icon(Iconsax.money, color: _secondaryColor),
            const SizedBox(width: 10),
            const Text(
              'Distribution des gains',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _backgroundColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _secondaryColor.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  _buildInfoRow('Score gagnant', scoreGagnantKey, Colors.white),
                  const Divider(color: Colors.grey, height: 16),
                  _buildInfoRow('Cagnotte', '${pronostic.cagnotte.toStringAsFixed(0)} FCFA', _secondaryColor),
                  _buildInfoRow('Nombre de gagnants', '${gagnantsIds.length}', Colors.blue),
                  _buildInfoRow('Gain par gagnant', '${gainParGagnant.toStringAsFixed(0)} FCFA', Colors.green),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (gagnantsIds.isEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange, width: 1.5),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Aucun gagnant pour ce score.\nLa cagnotte restera dans l\'application.',
                        style: TextStyle(color: Colors.orange),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('ANNULER', style: TextStyle(color: _hintColor)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              _showProcessingDialog();

              try {
                bool success = await _paymentService.crediterGagnants(
                  pronostic: pronostic,
                  gagnantsIds: gagnantsIds,
                  montantParGagnant: gainParGagnant,
                  authProvider: Provider.of<UserAuthProvider>(context, listen: false),
                );

                if (success) {
                  await _pronosticProvider.distribuerGains(
                    pronosticId: pronostic.id,
                    gagnantsIds: gagnantsIds,
                    gainParGagnant: gainParGagnant,
                  );

                  if (context.mounted) {
                    Navigator.of(context, rootNavigator: true).pop(); // 🔥 ferme le loader
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          gagnantsIds.isEmpty
                              ? '✅ Aucun gagnant, cagnotte conservée'
                              : '✅ Gains distribués: ${gainParGagnant.toStringAsFixed(0)} FCFA à ${gagnantsIds.length} gagnant(s)',
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } else {

                  throw Exception('Échec du paiement');
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.of(context, rootNavigator: true).pop(); // 🔥 ferme le loader
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('❌ Erreur: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _secondaryColor,
              foregroundColor: Colors.black,
            ),
            child: Text(gagnantsIds.isEmpty ? 'CONSERVER' : 'DISTRIBUER'),
          ),
        ],
      ),
    );
  }

  void _showProcessingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    ).then((_) {
      // Optionnel: code à exécuter après la fermeture du dialog
    });

  }
  Widget _buildInfoRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: _hintColor)),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}