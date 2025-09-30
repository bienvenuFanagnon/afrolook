// challenge_dashboard_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/providers/authProvider.dart';
import 'package:afrotok/providers/postProvider.dart';
import 'package:afrotok/providers/userProvider.dart';
import 'challengeDetails.dart';

import 'newChallenge.dart';

class ChallengeDashboardPage extends StatefulWidget {
  const ChallengeDashboardPage({Key? key}) : super(key: key);

  @override
  _ChallengeDashboardPageState createState() => _ChallengeDashboardPageState();
}

class _ChallengeDashboardPageState extends State<ChallengeDashboardPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Variables pour les statistiques
  int _totalChallenges = 0;
  int _challengesEnCours = 0;
  int _challengesTermines = 0;
  int _challengesAnnules = 0;
  int _totalParticipants = 0;
  int _totalVotes = 0;
  double _revenusTotaux = 0;

  late UserAuthProvider authProvider;
  late UserProvider userProvider;
  late PostProvider postProvider;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadStats();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    await _calculateStats();
  }

  Future<void> _calculateStats() async {
    try {
      final challengesSnapshot = await _firestore
          .collection('Challenges')
          .where('disponible', isEqualTo: true)
          .where('isAprouved', isEqualTo: true)
          .get();

      int total = 0;
      int enCours = 0;
      int termines = 0;
      int annules = 0;
      int participants = 0;
      int votes = 0;
      double revenus = 0;

      for (final doc in challengesSnapshot.docs) {
        final challenge = Challenge.fromJson(doc.data());
        total++;

        switch (challenge.statut) {
          case 'en_cours':
            enCours++;
            break;
          case 'termine':
            termines++;
            break;
          case 'annule':
            annules++;
            break;
        }

        participants += challenge.totalParticipants ?? 0;
        votes += challenge.totalVotes ?? 0;

        // Calcul des revenus (participations payantes + votes payants)
        if (!challenge.participationGratuite!) {
          revenus += (challenge.prixParticipation ?? 0) * (challenge.totalParticipants ?? 0);
        }
        if (!challenge.voteGratuit!) {
          revenus += (challenge.prixVote ?? 0) * (challenge.totalVotes ?? 0);
        }
      }

      setState(() {
        _totalChallenges = total;
        _challengesEnCours = enCours;
        _challengesTermines = termines;
        _challengesAnnules = annules;
        _totalParticipants = participants;
        _totalVotes = votes;
        _revenusTotaux = revenus;
      });
    } catch (e) {
      print('Erreur calcul stats: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    authProvider = Provider.of<UserAuthProvider>(context);
    userProvider = Provider.of<UserProvider>(context);
    postProvider = Provider.of<PostProvider>(context);

    final bool isAdmin = authProvider.loginUserData.role == UserRole.ADM.name;

    return Scaffold(
      appBar: AppBar(
        title: Text('Dashboard Challenges'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          if (isAdmin)
            IconButton(
              icon: Icon(Icons.add),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChallengePostPage(isParticipation: false),
                  ),
                );
              },
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'En Cours'),
            Tab(text: 'À Venir'),
            Tab(text: 'Historique'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Section Statistiques
          _buildStatsSection(),

          // Section Liste des Challenges
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildChallengesList('en_cours'),
                _buildChallengesList('en_attente'),
                _buildChallengesList('termine'),
              ],
            ),
          ),
        ],
      ),

      // Bouton flottant pour créer un challenge (admin seulement)
      floatingActionButton: isAdmin
          ? FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChallengePostPage(isParticipation: false),
            ),
          );
        },
        child: Icon(Icons.emoji_events),
        backgroundColor: Colors.blue,
      )
          : null,
    );
  }

  Widget _buildStatsSection() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Statistiques des Challenges',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16),

          // Ligne 1: Challenges
          Row(
            children: [
              _buildStatCard('Total', _totalChallenges.toString(), Colors.blue),
              SizedBox(width: 8),
              _buildStatCard('En Cours', _challengesEnCours.toString(), Colors.green),
              SizedBox(width: 8),
              _buildStatCard('Terminés', _challengesTermines.toString(), Colors.orange),
            ],
          ),
          SizedBox(height: 8),

          // Ligne 2: Participations et Revenus
          Row(
            children: [
              _buildStatCard('Participants', _totalParticipants.toString(), Colors.purple),
              SizedBox(width: 8),
              _buildStatCard('Votes', _totalVotes.toString(), Colors.red),
              SizedBox(width: 8),
              _buildStatCard('Revenus', '${_revenusTotaux.toInt()} FCFA', Colors.green),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChallengesList(String statut) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('Challenges')
          .where('disponible', isEqualTo: true)
          // .where('isAprouved', isEqualTo: true)
          .where('statut', isEqualTo: statut)
          .orderBy('created_at', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.emoji_events, size: 64, color: Colors.grey[400]),
                SizedBox(height: 16),
                Text(
                  statut == 'en_cours'
                      ? 'Aucun challenge en cours'
                      : statut == 'en_attente'
                      ? 'Aucun challenge à venir'
                      : 'Aucun challenge terminé',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        final challenges = snapshot.data!.docs.map((doc) {
          return Challenge.fromJson(doc.data() as Map<String,dynamic>)..id = doc.id;
        }).toList();

        return ListView.builder(
          itemCount: challenges.length,
          itemBuilder: (context, index) {
            return _buildChallengeItem(challenges[index]);
          },
        );
      },
    );
  }

  Widget _buildChallengeItem(Challenge challenge) {
    final now = DateTime.now().microsecondsSinceEpoch;
    final bool isAdmin = authProvider.loginUserData.role == UserRole.ADM.name;

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: _getStatusColor(challenge.statut!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _getStatusIcon(challenge.statut!),
            color: Colors.white,
          ),
        ),
        title: Text(
          challenge.titre ?? 'Sans titre',
          style: TextStyle(fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              challenge.description ?? '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 4),
            _buildChallengeInfo(challenge),
          ],
        ),
        trailing: Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChallengeDetailPage(challengeId: challenge.id!),
            ),
          );
        },
        onLongPress: isAdmin ? () {
          _showAdminOptions(challenge);
        } : null,
      ),
    );
  }

  Widget _buildChallengeInfo(Challenge challenge) {
    final now = DateTime.now().microsecondsSinceEpoch;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Prix et participants
        Row(
          children: [
            Icon(Icons.attach_money, size: 12, color: Colors.green),
            SizedBox(width: 4),
            Text('${challenge.prix ?? 0} FCFA', style: TextStyle(fontSize: 12)),
            SizedBox(width: 16),
            Icon(Icons.people, size: 12, color: Colors.blue),
            SizedBox(width: 4),
            Text('${challenge.totalParticipants ?? 0}', style: TextStyle(fontSize: 12)),
            SizedBox(width: 16),
            Icon(Icons.how_to_vote, size: 12, color: Colors.orange),
            SizedBox(width: 4),
            Text('${challenge.totalVotes ?? 0}', style: TextStyle(fontSize: 12)),
          ],
        ),
        SizedBox(height: 4),

        // Dates et statut
        Text(
          _getDateInfo(challenge, now),
          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
        ),

        // Badge de statut
        Container(
          margin: EdgeInsets.only(top: 4),
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: _getStatusColor(challenge.statut!).withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: _getStatusColor(challenge.statut!)),
          ),
          child: Text(
            _getStatusText(challenge.statut!),
            style: TextStyle(
              fontSize: 10,
              color: _getStatusColor(challenge.statut!),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String statut) {
    switch (statut) {
      case 'en_attente':
        return Colors.orange;
      case 'en_cours':
        return Colors.green;
      case 'termine':
        return Colors.blue;
      case 'annule':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String statut) {
    switch (statut) {
      case 'en_attente':
        return Icons.schedule;
      case 'en_cours':
        return Icons.play_arrow;
      case 'termine':
        return Icons.check_circle;
      case 'annule':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  String _getStatusText(String statut) {
    switch (statut) {
      case 'en_attente':
        return 'EN ATTENTE';
      case 'en_cours':
        return 'EN COURS';
      case 'termine':
        return 'TERMINÉ';
      case 'annule':
        return 'ANNULÉ';
      default:
        return statut.toUpperCase();
    }
  }

  String _getDateInfo(Challenge challenge, int now) {
    final dateFormat = DateFormat('dd/MM/yyyy');

    if (challenge.statut == 'en_attente') {
      final startInscription = challenge.startInscriptionAt ?? 0;
      if (now < startInscription) {
        final startDate = DateTime.fromMicrosecondsSinceEpoch(startInscription);
        return 'Début inscriptions: ${dateFormat.format(startDate)}';
      } else {
        final endDate = DateTime.fromMicrosecondsSinceEpoch(challenge.endInscriptionAt ?? 0);
        return 'Fin inscriptions: ${dateFormat.format(endDate)}';
      }
    } else if (challenge.statut == 'en_cours') {
      final endDate = DateTime.fromMicrosecondsSinceEpoch(challenge.finishedAt ?? 0);
      return 'Fin du challenge: ${dateFormat.format(endDate)}';
    } else if (challenge.statut == 'termine') {
      final endDate = DateTime.fromMicrosecondsSinceEpoch(challenge.finishedAt ?? 0);
      return 'Terminé le: ${dateFormat.format(endDate)}';
    }

    return '';
  }

  void _showAdminOptions(Challenge challenge) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Options Admin - ${challenge.titre}',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),

              // Statistiques détaillées
              _buildAdminStats(challenge),
              SizedBox(height: 16),

              // Actions admin
              Wrap(
                spacing: 8,
                children: [
                  if (challenge.statut == 'en_attente')
                    ElevatedButton(
                      onPressed: () => _demarrerChallenge(challenge),
                      child: Text('Démarrer'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    ),

                  if (challenge.statut == 'en_cours')
                    ElevatedButton(
                      onPressed: () => _terminerChallenge(challenge),
                      child: Text('Terminer'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                    ),

                  if (challenge.statut != 'annule')
                    ElevatedButton(
                      onPressed: () => _annulerChallenge(challenge),
                      child: Text('Annuler'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    ),

                  ElevatedButton(
                    onPressed: () => _voirDetails(challenge),
                    child: Text('Détails'),
                  ),

                  ElevatedButton(
                    onPressed: () => _encaisserRevenus(challenge),
                    child: Text('Encaisser'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAdminStats(Challenge challenge) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Statistiques détaillées:', style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Row(
            children: [
              _buildMiniStat('Participants', '${challenge.totalParticipants ?? 0}'),
              _buildMiniStat('Votes', '${challenge.totalVotes ?? 0}'),
              _buildMiniStat('Posts', '${challenge.postsIds?.length ?? 0}'),
            ],
          ),
          SizedBox(height: 4),
          Text(
            'Revenus estimés: ${_calculerRevenusChallenge(challenge)} FCFA',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: TextStyle(fontWeight: FontWeight.bold)),
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }

  int _calculerRevenusChallenge(Challenge challenge) {
    int revenus = 0;
    if (!challenge.participationGratuite!) {
      revenus += (challenge.prixParticipation ?? 0) * (challenge.totalParticipants ?? 0);
    }
    if (!challenge.voteGratuit!) {
      revenus += (challenge.prixVote ?? 0) * (challenge.totalVotes ?? 0);
    }
    return revenus;
  }

  Future<void> _demarrerChallenge(Challenge challenge) async {
    try {
      await _firestore.collection('Challenges').doc(challenge.id!).update({
        'statut': 'en_cours',
        'updated_at': DateTime.now().microsecondsSinceEpoch,
      });

      Navigator.pop(context);
      _showSuccess('Challenge démarré avec succès!');
    } catch (e) {
      _showError('Erreur: $e');
    }
  }

  Future<void> _terminerChallenge(Challenge challenge) async {
    try {
      await _firestore.collection('Challenges').doc(challenge.id!).update({
        'statut': 'termine',
        'updated_at': DateTime.now().microsecondsSinceEpoch,
      });

      // Déterminer le gagnant
      await _determinerGagnant(challenge.id!);

      Navigator.pop(context);
      _showSuccess('Challenge terminé avec succès!');
    } catch (e) {
      _showError('Erreur: $e');
    }
  }

  Future<void> _annulerChallenge(Challenge challenge) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Annuler le challenge'),
        content: Text('Êtes-vous sûr de vouloir annuler ce challenge? Cette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Non'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await _firestore.collection('Challenges').doc(challenge.id!).update({
                  'statut': 'annule',
                  'updated_at': DateTime.now().microsecondsSinceEpoch,
                });

                Navigator.pop(context); // Fermer dialog
                Navigator.pop(context); // Fermer bottom sheet
                _showSuccess('Challenge annulé avec succès!');
              } catch (e) {
                _showError('Erreur: $e');
              }
            },
            child: Text('Oui, annuler'),
          ),
        ],
      ),
    );
  }

  Future<void> _determinerGagnant(String challengeId) async {
    try {
      // Récupérer le post avec le plus de votes
      final postsSnapshot = await _firestore
          .collection('Posts')
          .where('challenge_id', isEqualTo: challengeId)
          .orderBy('votes_challenge', descending: true)
          .limit(1)
          .get();

      if (postsSnapshot.docs.isNotEmpty) {
        final postGagnant = postsSnapshot.docs.first;
        await _firestore.collection('Challenges').doc(challengeId).update({
          'posts_winner_ids': FieldValue.arrayUnion([postGagnant.id]),
        });
      }
    } catch (e) {
      print('Erreur détermination gagnant: $e');
    }
  }

  void _voirDetails(Challenge challenge) {
    Navigator.pop(context); // Fermer bottom sheet
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChallengeDetailPage(challengeId: challenge.id!),
      ),
    );
  }

  Future<void> _encaisserRevenus(Challenge challenge) async {
    try {
      final revenus = _calculerRevenusChallenge(challenge);

      // Mettre à jour le solde de l'application
      await _firestore.collection('app_default_data').doc('solde').set({
        'solde_gain': FieldValue.increment(revenus)
      }, SetOptions(merge: true));

      // Marquer le challenge comme encaissé
      await _firestore.collection('Challenges').doc(challenge.id!).update({
        'revenus_encaisses': true,
        'updated_at': DateTime.now().microsecondsSinceEpoch,
      });

      Navigator.pop(context);
      _showSuccess('Revenus encaissés: $revenus FCFA');
    } catch (e) {
      _showError('Erreur encaissement: $e');
    }
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}