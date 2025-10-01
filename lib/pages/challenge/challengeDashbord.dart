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

// Couleurs pour le thème
const _afroBlack = Color(0xFF000000);
const _afroGreen = Color(0xFF00BA7C);
const _afroYellow = Color(0xFFFFD400);
const _afroRed = Color(0xFFF91880);
const _afroBlue = Color(0xFF1D9BF0);
const _afroCardBg = Color(0xFF16181C);
const _afroTextPrimary = Color(0xFFFFFFFF);
const _afroTextSecondary = Color(0xFF71767B);

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
    _tabController = TabController(length: 4, vsync: this);
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
      backgroundColor: _afroBlack,
      appBar: AppBar(
        title: Text(
          'Dashboard Challenges',
          style: TextStyle(
            color: _afroTextPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: _afroBlack,
        foregroundColor: _afroTextPrimary,
        elevation: 0,
        actions: [
          if (isAdmin)
            IconButton(
              icon: Icon(Icons.add, color: _afroGreen),
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
          indicatorColor: _afroGreen,
          labelColor: _afroGreen,
          unselectedLabelColor: _afroTextSecondary,
          tabs: [
            Tab(text: 'En Cours'),
            Tab(text: 'À Venir'),
            Tab(text: 'Historique'),
            Tab(text: 'Annulé'),
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
                _buildChallengesGrid('en_cours'),
                _buildChallengesGrid('en_attente'),
                _buildChallengesGrid('termine'),
                _buildChallengesGrid('annule'),
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
        child: Icon(Icons.emoji_events, color: _afroBlack),
        backgroundColor: _afroGreen,
      )
          : null,
    );
  }

  Widget _buildStatsSection() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _afroCardBg,
        border: Border(bottom: BorderSide(color: _afroTextSecondary.withOpacity(0.3))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '📊 Statistiques des Challenges',
            style: TextStyle(
              color: _afroTextPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16),

          // Ligne 1: Challenges
          Row(
            children: [
              _buildStatCard('Total', _totalChallenges.toString(), _afroBlue, Icons.emoji_events),
              SizedBox(width: 8),
              _buildStatCard('En Cours', _challengesEnCours.toString(), _afroGreen, Icons.play_arrow),
              SizedBox(width: 8),
              _buildStatCard('Terminés', _challengesTermines.toString(), _afroYellow, Icons.check_circle),
            ],
          ),
          SizedBox(height: 8),

          // Ligne 2: Participations et Revenus
          Row(
            children: [
              _buildStatCard('Participants', _totalParticipants.toString(), _afroBlue, Icons.people),
              SizedBox(width: 8),
              _buildStatCard('Votes', _totalVotes.toString(), _afroGreen, Icons.how_to_vote),
              SizedBox(width: 8),
              _buildStatCard('Revenus', '${_revenusTotaux.toInt()} FCFA', _afroYellow, Icons.attach_money),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: color),
                SizedBox(width: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 10,
                color: _afroTextSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChallengesGrid(String statut) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('Challenges')
          .where('disponible', isEqualTo: true)
          .where('statut', isEqualTo: statut)
          .orderBy('created_at', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: _afroGreen));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(statut);
        }

        final challenges = snapshot.data!.docs.map((doc) {
          return Challenge.fromJson(doc.data() as Map<String,dynamic>)..id = doc.id;
        }).toList();

        return GridView.builder(
          padding: EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.75,
          ),
          itemCount: challenges.length,
          itemBuilder: (context, index) {
            return _buildChallengeCard(challenges[index]);
          },
        );
      },
    );
  }

  Widget _buildChallengeCard(Challenge challenge) {
    final bool isAdmin = authProvider.loginUserData.role == UserRole.ADM.name;

    return GestureDetector(
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
      child: Container(
        decoration: BoxDecoration(
          color: _afroCardBg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: _getStatusColor(challenge.statut!).withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header avec statut
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _getStatusColor(challenge.statut!).withOpacity(0.1),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _getStatusText(challenge.statut!),
                          style: TextStyle(
                            color: _getStatusColor(challenge.statut!),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Icon(
                        _getStatusIcon(challenge.statut!),
                        color: _getStatusColor(challenge.statut!),
                        size: 16,
                      ),
                    ],
                  ),
                ),

                // Contenu principal
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Titre
                        Text(
                          challenge.titre ?? 'Challenge sans titre',
                          style: TextStyle(
                            color: _afroTextPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 8),

                        // Prix
                        Row(
                          children: [
                            Icon(Icons.attach_money, size: 14, color: _afroYellow),
                            SizedBox(width: 4),
                            Text(
                              '${challenge.prix ?? 0} FCFA',
                              style: TextStyle(
                                color: _afroYellow,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),

                        // Participants et votes
                        Row(
                          children: [
                            Icon(Icons.people, size: 12, color: _afroTextSecondary),
                            SizedBox(width: 4),
                            Text(
                              '${challenge.totalParticipants ?? 0}',
                              style: TextStyle(
                                color: _afroTextSecondary,
                                fontSize: 11,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.how_to_vote, size: 12, color: _afroTextSecondary),
                            SizedBox(width: 4),
                            Text(
                              '${challenge.totalVotes ?? 0}',
                              style: TextStyle(
                                color: _afroTextSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),

                        // Date
                        Text(
                          _getDateInfo(challenge),
                          style: TextStyle(
                            color: _afroTextSecondary,
                            fontSize: 10,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),

                        Spacer(),

                        // Bouton d'action
                        Container(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ChallengeDetailPage(challengeId: challenge.id!),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _afroGreen,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: EdgeInsets.symmetric(vertical: 8),
                              minimumSize: Size(0, 0),
                            ),
                            child: Text(
                              'VOIR CHALLENGE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Badge admin pour suppression
            if (isAdmin)
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: () => _confirmDeleteChallenge(challenge),
                  child: Container(
                    padding: EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _afroRed.withOpacity(0.9),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.delete,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String statut) {
    String message = '';
    IconData icon = Icons.emoji_events;

    switch (statut) {
      case 'en_cours':
        message = 'Aucun challenge en cours';
        icon = Icons.play_arrow;
        break;
      case 'en_attente':
        message = 'Aucun challenge à venir';
        icon = Icons.schedule;
        break;
      case 'termine':
        message = 'Aucun challenge terminé';
        icon = Icons.check_circle;
        break;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: _afroTextSecondary),
          SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              color: _afroTextSecondary,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String statut) {
    switch (statut) {
      case 'en_attente':
        return _afroYellow;
      case 'en_cours':
        return _afroGreen;
      case 'termine':
        return _afroBlue;
      case 'annule':
        return _afroRed;
      default:
        return _afroTextSecondary;
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
        return 'À VENIR';
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

  String _getDateInfo(Challenge challenge) {
    final dateFormat = DateFormat('dd/MM/yy');
    final now = DateTime.now().microsecondsSinceEpoch;

    if (challenge.statut == 'en_attente') {
      final startInscription = challenge.startInscriptionAt ?? 0;
      if (now < startInscription) {
        final startDate = DateTime.fromMicrosecondsSinceEpoch(startInscription);
        return 'Début: ${dateFormat.format(startDate)}';
      } else {
        final endDate = DateTime.fromMicrosecondsSinceEpoch(challenge.endInscriptionAt ?? 0);
        return 'Fin inscriptions: ${dateFormat.format(endDate)}';
      }
    } else if (challenge.statut == 'en_cours') {
      final endDate = DateTime.fromMicrosecondsSinceEpoch(challenge.finishedAt ?? 0);
      return 'Fin: ${dateFormat.format(endDate)}';
    } else if (challenge.statut == 'termine') {
      final endDate = DateTime.fromMicrosecondsSinceEpoch(challenge.finishedAt ?? 0);
      return 'Terminé: ${dateFormat.format(endDate)}';
    }

    return '';
  }

  void _showAdminOptions(Challenge challenge) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _afroCardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _afroTextSecondary.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Options Admin',
                style: TextStyle(
                  color: _afroTextPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                challenge.titre ?? 'Challenge',
                style: TextStyle(
                  color: _afroTextSecondary,
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 20),

              // Actions admin
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildAdminActionButton(
                    'Démarrer',
                    Icons.play_arrow,
                    _afroGreen,
                    challenge.statut == 'en_attente' ? () => _demarrerChallenge(challenge) : null,
                  ),
                  _buildAdminActionButton(
                    'Terminer',
                    Icons.check_circle,
                    _afroBlue,
                    challenge.statut == 'en_cours' ? () => _terminerChallenge(challenge) : null,
                  ),
                  _buildAdminActionButton(
                    'Annuler',
                    Icons.cancel,
                    _afroRed,
                    challenge.statut != 'annule' ? () => _annulerChallenge(challenge) : null,
                  ),
                  _buildAdminActionButton(
                    'Supprimer',
                    Icons.delete,
                    _afroRed,
                        () => _confirmDeleteChallenge(challenge),
                  ),
                  _buildAdminActionButton(
                    'Détails',
                    Icons.visibility,
                    _afroBlue,
                        () => _voirDetails(challenge),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAdminActionButton(String text, IconData icon, Color color, VoidCallback? onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.1),
        foregroundColor: color,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: color.withOpacity(0.3)),
        ),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteChallenge(Challenge challenge) {
    // Navigator.pop(context); // Fermer le bottom sheet si ouvert

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _afroCardBg,
        title: Text(
          'Confirmer la suppression',
          style: TextStyle(color: _afroTextPrimary),
        ),
        content: Text(
          'Êtes-vous sûr de vouloir supprimer ce challenge et tous les posts associés ?\n\nCette action est irréversible !',
          style: TextStyle(color: _afroTextSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'ANNULER',
              style: TextStyle(color: _afroTextSecondary),
            ),
          ),
          TextButton(
            onPressed: () => _confirmDeleteChallengeFinal(challenge),
            child: Text(
              'SUPPRIMER',
              style: TextStyle(color: _afroRed),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteChallengeFinal(Challenge challenge) {
    Navigator.pop(context); // Fermer la première boîte de dialogue

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _afroCardBg,
        title: Text(
          '⚠️ DERNIÈRE CONFIRMATION',
          style: TextStyle(color: _afroRed),
        ),
        content: Text(
          'ATTENTION ! Vous allez supprimer :\n\n'
              '• Le challenge "${challenge.titre}"\n'
              '• Tous les posts de participation\n'
              '• Toutes les données associées\n\n'
              'Cette action ne peut pas être annulée !\n\n'
              'Tapez "SUPPRIMER" pour confirmer :',
          style: TextStyle(color: _afroTextSecondary),
        ),
        contentPadding: EdgeInsets.all(20),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Annuler',
              style: TextStyle(color: _afroTextSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => _deleteChallengeAndPosts(challenge),
            style: ElevatedButton.styleFrom(
              backgroundColor: _afroRed,
              foregroundColor: Colors.white,
            ),
            child: Text('Confirmer la suppression'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteChallengeAndPosts(Challenge challenge) async {
    try {
      Navigator.pop(context); // Fermer la boîte de dialogue

      // Afficher un indicateur de chargement avec progression
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: _afroCardBg,
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: _afroGreen),
                  SizedBox(height: 16),
                  Text(
                    'Suppression en cours...',
                    style: TextStyle(color: _afroTextPrimary),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Cette opération peut prendre quelques secondes',
                    style: TextStyle(
                      color: _afroTextSecondary,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          },
        ),
      );

      // 1. Récupérer tous les posts associés au challenge (posts de participation)
      final postsParticipationSnapshot = await _firestore
          .collection('Posts')
          .where('challenge_id', isEqualTo: challenge.id)
          .get();

      // 2. Récupérer le post du challenge (celui qui contient les détails du challenge)
      Post? postChallenge;
      if (challenge.postChallengeId != null && challenge.postChallengeId!.isNotEmpty) {
        try {
          final postChallengeDoc = await _firestore
              .collection('Posts')
              .doc(challenge.postChallengeId!)
              .get();

          if (postChallengeDoc.exists) {
            postChallenge = Post.fromJson(postChallengeDoc.data()!)..id = postChallengeDoc.id;
          }
        } catch (e) {
          debugPrint('Erreur récupération post challenge: $e');
        }
      }

      // 3. Supprimer tous les posts dans une batch
      final batch = _firestore.batch();

      // Supprimer tous les posts de participation
      for (final postDoc in postsParticipationSnapshot.docs) {
        batch.delete(postDoc.reference);
      }

      // Supprimer le post du challenge s'il existe
      if (postChallenge != null && postChallenge.id != null) {
        batch.delete(_firestore.collection('Posts').doc(postChallenge.id!));
      }

      // 4. Supprimer le challenge
      batch.delete(_firestore.collection('Challenges').doc(challenge.id!));

      // 5. Exécuter la batch
      await batch.commit();

      // 6. Compter le nombre total de posts supprimés
      int totalPostsSupprimes = postsParticipationSnapshot.docs.length;
      if (postChallenge != null) {
        totalPostsSupprimes += 1;
      }

      // 7. Fermer le dialog et montrer le succès
      Navigator.pop(context);
      _showSuccess(
          '✅ Suppression réussie !\n'
              '• Challenge supprimé\n'
              '• ${totalPostsSupprimes} posts supprimés '
              '(${postsParticipationSnapshot.docs.length} participations + '
              '${postChallenge != null ? 1 : 0} post challenge)'
      );

      // 8. Recharger les stats
      await _calculateStats();

    } catch (e) {
      Navigator.pop(context);
      _showError('❌ Erreur lors de la suppression: $e');
    }
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
        backgroundColor: _afroCardBg,
        title: Text('Annuler le challenge', style: TextStyle(color: _afroTextPrimary)),
        content: Text(
          'Êtes-vous sûr de vouloir annuler ce challenge?',
          style: TextStyle(color: _afroTextSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Non', style: TextStyle(color: _afroTextSecondary)),
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
            child: Text('Oui, annuler', style: TextStyle(color: _afroRed)),
          ),
        ],
      ),
    );
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

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: Colors.white)),
        backgroundColor: _afroGreen,
        duration: Duration(seconds: 4),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: Colors.white)),
        backgroundColor: _afroRed,
        duration: Duration(seconds: 4),
      ),
    );
  }
}