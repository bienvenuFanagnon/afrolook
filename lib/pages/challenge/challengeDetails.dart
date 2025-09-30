// challenge_detail_page.dart (version complète refaite)
import 'package:afrotok/pages/component/consoleWidget.dart';
import 'package:afrotok/pages/postDetails.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/providers/authProvider.dart';
import 'newChallenge.dart';

class ChallengeDetailPage extends StatefulWidget {
  final String challengeId;

  const ChallengeDetailPage({Key? key, required this.challengeId}) : super(key: key);

  @override
  _ChallengeDetailPageState createState() => _ChallengeDetailPageState();
}

class _ChallengeDetailPageState extends State<ChallengeDetailPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late UserAuthProvider authProvider;

  Challenge? _challenge;
  List<Post> _posts = [];
  List<UserData> _participants = [];
  bool _loading = true;
  int _currentTab = 0; // 0: Détails, 1: Participants, 2: Posts
  Timer? _statusTimer;
  StreamSubscription? _challengeSubscription;

  @override
  void initState() {
    super.initState();
    _initializeChallenge();
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _challengeSubscription?.cancel();
    super.dispose();
  }

  void _initializeChallenge() async {
    await _loadChallenge();
    _startStatusMonitoring();
    _listenToChallengeUpdates();
  }

  void _startStatusMonitoring() {
    // Vérifier le statut toutes les 30 secondes
    _statusTimer = Timer.periodic(Duration(seconds: 30), (timer) {
      _checkAndUpdateChallengeStatus();
    });
  }

  void _listenToChallengeUpdates() {
    _challengeSubscription = _firestore
        .collection('Challenges')
        .doc(widget.challengeId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && mounted) {
        setState(() {
          _challenge = Challenge.fromJson(snapshot.data()!)..id = snapshot.id;
        });
        _checkAndUpdateChallengeStatus();
      }
    });
  }

  Future<void> _checkAndUpdateChallengeStatus() async {
    if (_challenge == null) return;

    final now = DateTime.now().microsecondsSinceEpoch;
    String? newStatus;

    debugPrint("=== VÉRIFICATION STATUT ===");
    debugPrint("Statut actuel: ${_challenge!.statut}");
    debugPrint("Now: $now");
    debugPrint("EndInscriptionAt: ${_challenge!.endInscriptionAt}");
    debugPrint("FinishedAt: ${_challenge!.finishedAt}");

    if (_challenge!.statut == 'en_attente') {
      // Si la date de fin d'inscription est passée, passer à 'en_cours'
      if (_challenge!.endInscriptionAt != null && now >= _challenge!.endInscriptionAt!) {
        newStatus = 'en_cours';
        debugPrint("🚀 Passage à EN COURS");
      }
    } else if (_challenge!.statut == 'en_cours') {
      // Si la date de fin du challenge est passée, passer à 'termine'
      if (_challenge!.finishedAt != null && now >= _challenge!.finishedAt!) {
        newStatus = 'termine';
        debugPrint("🏁 Passage à TERMINÉ");
      }
    }

    if (newStatus != null && newStatus != _challenge!.statut) {
      await _updateChallengeStatus(newStatus);
    }
  }

  Future<void> _updateChallengeStatus(String newStatus) async {
    try {
      await _firestore.collection('Challenges').doc(_challenge!.id!).update({
        'statut': newStatus,
        'updated_at': DateTime.now().microsecondsSinceEpoch,
      });

      debugPrint("✅ Statut mis à jour: $newStatus");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Le challenge est maintenant ${_getStatusText(newStatus)}'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Erreur mise à jour statut: $e');
    }
  }

  Future<void> _loadChallenge() async {
    try {
      final challengeDoc = await _firestore.collection('Challenges').doc(widget.challengeId).get();
      if (challengeDoc.exists) {
        setState(() {
          _challenge = Challenge.fromJson(challengeDoc.data()!)..id = challengeDoc.id;
        });

        // Vérifier le statut immédiatement
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _checkAndUpdateChallengeStatus();
        });

        await _loadParticipants();
        await _loadPosts();
      } else {
        throw Exception('Challenge non trouvé');
      }
    } catch (e) {
      debugPrint('❌ Erreur chargement challenge: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du chargement du challenge'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() { _loading = false; });
      }
    }
  }

  Future<void> _loadParticipants() async {
    try {
      if (_challenge?.usersInscritsIds?.isNotEmpty ?? false) {
        final usersSnapshot = await _firestore
            .collection('Users')
            .where(FieldPath.documentId, whereIn: _challenge!.usersInscritsIds!)
            .get();

        setState(() {
          _participants = usersSnapshot.docs
              .map((doc) => UserData.fromJson(doc.data()))
              .toList();
        });
      }
    } catch (e) {
      debugPrint('❌ Erreur chargement participants: $e');
    }
  }

  Future<void> _loadPosts() async {
    try {
      final postsSnapshot = await _firestore
          .collection('Posts')
          .where('challenge_id', isEqualTo: widget.challengeId)
          .orderBy('votes_challenge', descending: true)
          .get();

      List<Post> posts = postsSnapshot.docs.map((doc) {
        final post = Post.fromJson(doc.data())..id = doc.id;
        return post;
      }).toList();

      // Charger les données utilisateur pour chaque post
      for (var post in posts) {
        if (post.user_id != null) {
          final userDoc = await _firestore.collection('Users').doc(post.user_id).get();
          if (userDoc.exists) {
            post.user = UserData.fromJson(userDoc.data()!);
          }
        }
      }

      setState(() {
        _posts = posts;
      });
    } catch (e) {
      debugPrint('❌ Erreur chargement posts: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    authProvider = Provider.of<UserAuthProvider>(context);

    if (_loading) {
      return _buildLoadingScreen();
    }

    if (_challenge == null) {
      return _buildErrorScreen();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          _challenge!.titre ?? 'Détails du Challenge',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadChallenge,
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: Column(
        children: [
          // Section d'action principale
          _buildMainActionSection(),

          // Navigation par onglets
          _buildTabNavigation(),

          // Contenu des onglets
          Expanded(
            child: _buildCurrentTabContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text('Chargement...', style: TextStyle(color: Colors.white)),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.green)),
            SizedBox(height: 20),
            Text('Chargement du challenge...', style: TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text('Erreur', style: TextStyle(color: Colors.white)),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.yellow),
            SizedBox(height: 20),
            Text(
              'Challenge non trouvé',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              'Ce challenge n\'existe pas ou a été supprimé',
              style: TextStyle(color: Colors.grey, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 30),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              ),
              child: Text('RETOUR', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainActionSection() {
    final user = _auth.currentUser;
    final isInscrit = _challenge!.isInscrit(user?.uid);
    final peutParticiper = _challenge!.peutParticiper;
    final aVote = _challenge!.aVote(user?.uid);

    debugPrint("=== ÉTAT UTILISATEUR ===");
    debugPrint("Utilisateur: ${user?.uid}");
    debugPrint("Statut: ${_challenge!.statut}");
    debugPrint("Inscrit: $isInscrit");
    debugPrint("Peut participer: $peutParticiper");
    debugPrint("A voté: $aVote");

    // Gestion selon le statut du challenge
    if (_challenge!.isEnAttente) {
      if (user == null) {
        return _buildNotConnectedMessage();
      } else if (!isInscrit && peutParticiper) {
        return _buildParticipationCallToAction();
      } else if (isInscrit) {
        return _buildAlreadyRegisteredMessage();
      } else if (!peutParticiper) {
        return _buildRegistrationClosedMessage();
      }
    } else if (_challenge!.isEnCours) {
      if (user == null) {
        return _buildNotConnectedMessage();
      } else if (isInscrit) {
        // INSCRIT : Peut publier un post pour participer
        return _buildPostParticipationCallToAction();
      } else {
        // NON-INSCRIT : Ne peut que voter
        if (!aVote) {
          return _buildVoteCallToAction();
        } else {
          return _buildAlreadyVotedMessage();
        }
      }
    } else if (_challenge!.isTermine) {
      return _buildChallengeFinishedMessage();
    } else if (_challenge!.isAnnule) {
      return _buildChallengeCancelledMessage();
    }

    return SizedBox.shrink();
  }
  Widget _buildNotConnectedMessage() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.9),
      ),
      child: Column(
        children: [
          Icon(Icons.person_off, size: 32, color: Colors.white),
          SizedBox(height: 8),
          Text(
            'CONNECTEZ-VOUS',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Connectez-vous pour participer ou voter',
            style: TextStyle(color: Colors.white70, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  Widget _buildPostParticipationCallToAction() {
    final user = _auth.currentUser;
    final aDejaPoste = _posts.any((post) => post.user_id == user?.uid);

    if (aDejaPoste) {
      return _buildAlreadyPostedMessage();
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple.shade800, Colors.purple.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_photo_alternate, size: 32, color: Colors.white),
              SizedBox(width: 10),
              Text(
                'PUBLIEZ VOTRE PARTICIPATION !',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'Vous êtes inscrit. Postez maintenant votre contenu pour concourir !',
            style: TextStyle(color: Colors.white70, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChallengePostPage(
                    challenge: _challenge,
                    isParticipation: true,
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.purple,
              minimumSize: Size(250, 55),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              elevation: 4,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_circle, size: 24),
                SizedBox(width: 10),
                Text(
                  'PUBLIER MAINTENANT',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Le challenge a débuté - Concourez pour gagner !',
            style: TextStyle(color: Colors.yellow, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildAlreadyPostedMessage() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.9),
      ),
      child: Column(
        children: [
          Icon(Icons.check_circle, size: 32, color: Colors.white),
          SizedBox(height: 8),
          Text(
            'PARTICIPATION PUBLIÉE !',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Votre contenu est en compétition. Bonne chance !',
            style: TextStyle(color: Colors.white70, fontSize: 12),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          ElevatedButton(
            onPressed: () {
              setState(() { _currentTab = 2; });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.blue,
            ),
            child: Text('VOIR MA PARTICIPATION'),
          ),
        ],
      ),
    );
  }
  Widget _buildParticipationCallToAction() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.yellow.shade800, Colors.yellow.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.emoji_events, size: 24, color: Colors.black),
              SizedBox(width: 8),
              Text(
                'GAGNEZ ${_challenge!.prix ?? 0} FCFA !',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'Postez votre meilleur contenu et remportez le prix',
            style: TextStyle(color: Colors.black87, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChallengePostPage(
                    challenge: _challenge,
                    isParticipation: true,
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.yellow,
              minimumSize: Size(250, 55),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              elevation: 4,
              shadowColor: Colors.yellow.withOpacity(0.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_circle, size: 24),
                SizedBox(width: 10),
                Text(
                  'PARTICIPER MAINTENANT',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
          ),
          SizedBox(height: 8),
          if (!_challenge!.participationGratuite!)
            Text(
              'Participation: ${_challenge!.prixParticipation} FCFA',
              style: TextStyle(color: Colors.black54, fontSize: 12),
            )
          else
            Text(
              'PARTICIPATION GRATUITE',
              style: TextStyle(color: Colors.green.shade800, fontSize: 12, fontWeight: FontWeight.bold),
            ),
        ],
      ),
    );
  }

  Widget _buildAlreadyRegisteredMessage() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade800, Colors.blue.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle, size: 32, color: Colors.white),
              SizedBox(width: 10),
              Text(
                'VOUS ÊTES INSCRIT !',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'Préparez votre contenu. Le challenge débutera bientôt.',
            style: TextStyle(color: Colors.white70, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: () {
                  setState(() { _currentTab = 2; });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.blue,
                ),
                child: Text('VOIR LES PARTICIPANTS'),
              ),
              SizedBox(width: 10),
              ElevatedButton(
                onPressed: _loadChallenge,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white),
                ),
                child: Text('ACTUALISER'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRegistrationClosedMessage() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.9),
      ),
      child: Column(
        children: [
          Icon(Icons.schedule, size: 32, color: Colors.white),
          SizedBox(height: 8),
          Text(
            'INSCRIPTIONS FERMÉES',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Les inscriptions pour ce challenge sont terminées',
            style: TextStyle(color: Colors.white70, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildVoteCallToAction() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade800, Colors.green.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.how_to_vote, size: 32, color: Colors.white),
              SizedBox(width: 10),
              Text(
                'VOTEZ POUR LES PARTICIPANTS !',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'Vous n\'êtes pas inscrit. Soutenez les participants en votant pour votre favori !',
            style: TextStyle(color: Colors.white70, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              setState(() { _currentTab = 2; });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.green,
              minimumSize: Size(250, 55),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              elevation: 4,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.how_to_vote, size: 24),
                SizedBox(width: 10),
                Text(
                  'VOTER MAINTENANT',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
          ),
          SizedBox(height: 8),
          if (!_challenge!.voteGratuit!)
            Text(
              'Prix par vote: ${_challenge!.prixVote} FCFA',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            )
          else
            Text(
              'VOTE GRATUIT POUR TOUS',
              style: TextStyle(color: Colors.yellow, fontSize: 12, fontWeight: FontWeight.bold),
            ),
        ],
      ),
    );
  }
  Widget _buildAlreadyVotedMessage() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.purple.withOpacity(0.9),
      ),
      child: Column(
        children: [
          Icon(Icons.thumb_up, size: 32, color: Colors.white),
          SizedBox(height: 8),
          Text(
            'VOTE ENREGISTRÉ !',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Merci pour votre participation. Résultats bientôt disponibles.',
            style: TextStyle(color: Colors.white70, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildVoteForOthersMessage() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.teal.withOpacity(0.9),
      ),
      child: Column(
        children: [
          Icon(Icons.people, size: 32, color: Colors.white),
          SizedBox(height: 8),
          Text(
            'SOUTENEZ LES PARTICIPANTS',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'En tant que non-inscrit, votez pour élire le gagnant',
            style: TextStyle(color: Colors.white70, fontSize: 12),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          ElevatedButton(
            onPressed: () {
              setState(() { _currentTab = 2; });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.teal,
            ),
            child: Text('VOTER POUR LES PARTICIPANTS'),
          ),
        ],
      ),
    );
  }
  Widget _buildChallengeFinishedMessage() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.9),
      ),
      child: Column(
        children: [
          Icon(Icons.flag, size: 32, color: Colors.white),
          SizedBox(height: 8),
          Text(
            'CHALLENGE TERMINÉ',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Le challenge est terminé. Merci à tous les participants !',
            style: TextStyle(color: Colors.white70, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildChallengeCancelledMessage() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.9),
      ),
      child: Column(
        children: [
          Icon(Icons.cancel, size: 32, color: Colors.white),
          SizedBox(height: 8),
          Text(
            'CHALLENGE ANNULÉ',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Ce challenge a été annulé',
            style: TextStyle(color: Colors.white70, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTabNavigation() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        border: Border(bottom: BorderSide(color: Colors.grey[800]!)),
      ),
      child: Row(
        children: [
          _buildTabItem(0, Icons.info, 'DÉTAILS'),
          _buildTabItem(1, Icons.people, 'PARTICIPANTS', _participants.length),
          _buildTabItem(2, Icons.photo_library, 'POSTS', _posts.length),
        ],
      ),
    );
  }

  Widget _buildTabItem(int tabIndex, IconData icon, String label, [int? count]) {
    final isSelected = _currentTab == tabIndex;
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() { _currentTab = tabIndex; }),
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isSelected ? Colors.green : Colors.transparent,
                  width: 3,
                ),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(icon,
                        size: 20,
                        color: isSelected ? Colors.green : Colors.grey[400]
                    ),
                    if (count != null && count > 0)
                      Positioned(
                        right: -5,
                        top: -5,
                        child: Container(
                          padding: EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            count > 99 ? '99+' : count.toString(),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: isSelected ? Colors.green : Colors.grey[400],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentTabContent() {
    switch (_currentTab) {
      case 0: return _buildDetailsTab();
      case 1: return _buildParticipantsTab();
      case 2: return _buildPostsTab();
      default: return _buildDetailsTab();
    }
  }

  Widget _buildDetailsTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildChallengeHeader(),
          SizedBox(height: 20),
          _buildPrizeSection(),
          SizedBox(height: 20),
          _buildChallengeStats(),
          SizedBox(height: 20),
          _buildChallengeTimeline(),
          SizedBox(height: 20),
          _buildRulesSection(),
          SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildChallengeHeader() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade800, Colors.black],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getStatusColor().withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _getStatusColor()),
                ),
                child: Text(
                  _getStatusText(_challenge!.statut!),
                  style: TextStyle(
                    color: _getStatusColor(),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              Spacer(),
              if (_challenge!.participationGratuite!)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.yellow.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.yellow),
                  ),
                  child: Text(
                    'GRATUIT',
                    style: TextStyle(color: Colors.yellow, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          SizedBox(height: 16),
          Text(
            _challenge!.titre ?? 'Sans titre',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 12),
          if (_challenge!.description != null)
            Text(
              _challenge!.description!,
              style: TextStyle(
                color: Colors.grey[300],
                fontSize: 16,
                height: 1.4,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPrizeSection() {
    return Card(
      color: Colors.grey[900],
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.card_giftcard, color: Colors.yellow, size: 24),
                SizedBox(width: 12),
                Text(
                  'PRIX À GAGNER',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.yellow.shade800, Colors.yellow.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.yellow.withOpacity(0.3),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    '${_challenge!.prix ?? 0} FCFA',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: 8),
                  if (_challenge!.descriptionCadeaux != null)
                    Text(
                      _challenge!.descriptionCadeaux!,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  if (_challenge!.typeCadeaux != null) ...[
                    SizedBox(height: 8),
                    Text(
                      'Type: ${_challenge!.typeCadeaux!}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChallengeStats() {
    return Card(
      color: Colors.grey[900],
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'STATISTIQUES',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 2.2,
              children: [
                _buildStatCard(Icons.people_alt, 'Participants', '${_challenge!.totalParticipants ?? 0}', Colors.green),
                _buildStatCard(Icons.how_to_vote, 'Votes totaux', '${_challenge!.totalVotes ?? 0}', Colors.blue),
                _buildStatCard(Icons.post_add, 'Publications', '${_posts.length}', Colors.orange),
                _buildStatCard(Icons.visibility, 'Vues', '${_challenge!.vues ?? 0}', Colors.purple),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(IconData icon, String title, String value, Color color) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(value, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
              SizedBox(height: 2),
              Text(title, style: TextStyle(color: Colors.grey[400], fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChallengeTimeline() {
    final dateFormat = DateFormat('dd/MM/yyyy à HH:mm');
    final now = DateTime.now().microsecondsSinceEpoch;

    return Card(
      color: Colors.grey[900],
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'DÉROULEMENT',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            SizedBox(height: 16),
            _buildTimelineItem('Début inscriptions', _challenge!.startInscriptionAt, now),
            _buildTimelineItem('Fin inscriptions', _challenge!.endInscriptionAt, now),
            _buildTimelineItem('Fin du challenge', _challenge!.finishedAt, now),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineItem(String label, int? timestamp, int now) {
    final dateFormat = DateFormat('dd/MM/yyyy à HH:mm');
    final isPassed = timestamp != null && now >= timestamp;
    final isCurrent = timestamp != null &&
        ((label.contains('Fin inscriptions') && _challenge!.isEnAttente) ||
            (label.contains('Fin du challenge') && _challenge!.isEnCours));

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCurrent ? Colors.green.withOpacity(0.1) : Colors.grey[800],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrent ? Colors.green : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: isPassed ? Colors.green : (isCurrent ? Colors.green : Colors.grey),
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: isCurrent ? Colors.green : Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (timestamp != null) ...[
                  SizedBox(height: 4),
                  Text(
                    dateFormat.format(DateTime.fromMicrosecondsSinceEpoch(timestamp)),
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
                  SizedBox(height: 4),
                  Text(
                    isPassed ? 'Terminé' : (isCurrent ? 'En cours' : 'À venir'),
                    style: TextStyle(
                      color: isPassed ? Colors.green : (isCurrent ? Colors.yellow : Colors.grey),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRulesSection() {
    return Card(
      color: Colors.grey[900],
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'INFORMATIONS',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            SizedBox(height: 16),
            if (_challenge!.typeContenu != null)
              _buildInfoItem('Type de contenu', _challenge!.typeContenu!),
            _buildInfoItem(
                'Participation',
                _challenge!.participationGratuite!
                    ? 'GRATUITE'
                    : '${_challenge!.prixParticipation} FCFA'
            ),
            _buildInfoItem(
                'Vote',
                _challenge!.voteGratuit!
                    ? 'GRATUIT'
                    : '${_challenge!.prixVote} FCFA par vote'
            ),
            if (_challenge!.countryData != null)
              _buildInfoItem('Pays', _challenge!.countryData!['name'] ?? ''),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(String title, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: Colors.green),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(color: Colors.grey[300]),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: value.contains('GRATUIT') ? Colors.green : Colors.yellow,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantsTab() {
    return _participants.isEmpty
        ? _buildEmptyState(
        Icons.people_outline,
        'Aucun participant',
        'Soyez le premier à participer à ce challenge !'
    )
        : ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _participants.length,
      itemBuilder: (context, index) {
        final participant = _participants[index];
        return Container(
          margin: EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            leading: CircleAvatar(
              radius: 22,
              backgroundImage: participant.imageUrl != null
                  ? NetworkImage(participant.imageUrl!)
                  : null,
              backgroundColor: Colors.grey[800],
              child: participant.imageUrl == null
                  ? Icon(Icons.person, color: Colors.white, size: 20)
                  : null,
            ),
            title: Text(
              participant.pseudo ?? 'Utilisateur',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
            ),
            subtitle: participant.email != null
                ? Text(
              participant.email!,
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
            )
                : null,
            trailing: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green),
              ),
              child: Text(
                'INSCRIT',
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPostsTab() {
    final user = _auth.currentUser;
    final aVote = _challenge!.aVote(user?.uid);

    if (_posts.isEmpty) {
      return _buildEmptyState(
          _challenge!.isEnCours ? Icons.photo_library : Icons.schedule,
          _challenge!.isEnCours
              ? 'Aucune publication'
              : 'En attente du début du challenge',
          _challenge!.isEnCours
              ? 'Les participants publieront bientôt leurs contenus'
              : 'Revenez quand le challenge aura débuté'
      );
    }

    return Column(
      children: [
        if (_challenge!.isEnCours && !aVote && user != null)
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              border: Border(bottom: BorderSide(color: Colors.green)),
            ),
            child: Row(
              children: [
                Icon(Icons.how_to_vote, color: Colors.green),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Votez pour votre participant préféré !',
                    style: TextStyle(color: Colors.green, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: _posts.length,
            itemBuilder: (context, index) {
              return _buildPostItem(_posts[index], index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPostItem(Post post, int index) {
    final user = _auth.currentUser;
    final aVotePourCePost = post.aVote(user?.uid ?? '');
    final peutVoter = _challenge!.isEnCours &&
        !_challenge!.aVote(user?.uid);
        // &&
        // post.user_id != user?.uid;
    final estGagnant = _challenge!.postsWinnerIds?.contains(post.id) ?? false;

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header du post
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                // Position
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _getRankColor(index),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                // Avatar
                CircleAvatar(
                  radius: 18,
                  backgroundImage: post.user?.imageUrl != null
                      ? NetworkImage(post.user!.imageUrl!)
                      : null,
                  backgroundColor: Colors.grey[700],
                  child: post.user?.imageUrl == null
                      ? Icon(Icons.person, color: Colors.white, size: 16)
                      : null,
                ),
                SizedBox(width: 12),
                // Infos utilisateur
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.user?.pseudo ?? 'Utilisateur',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        '${post.votesChallenge ?? 0} votes',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                // Badges
                if (estGagnant) ...[
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.yellow,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.emoji_events, size: 12, color: Colors.black),
                        SizedBox(width: 4),
                        Text(
                          'GAGNANT',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 8),
                ],
                // Bouton vote
                if (_challenge!.isEnCours && peutVoter)
                  ElevatedButton(
                    onPressed: () => _voterPourPost(post),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: aVotePourCePost ? Colors.green : Colors.blue,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      minimumSize: Size(0, 0),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                            aVotePourCePost ? Icons.check : Icons.how_to_vote,
                            size: 14
                        ),
                        SizedBox(width: 4),
                        Text(
                          aVotePourCePost ? 'VOTÉ' : 'VOTER',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Contenu du post
          InkWell(
            onTap: () {
              if (post.id != null) {

                printVm("Challenge post : ${post.dataType}");
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DetailsPost(post: post),
                  ),
                );
              }
            },
            child: Column(
              children: [
                // Aperçu média
                if (post.dataType == 'VIDEO' && post.url_media != null)
                  _buildVideoPreview(post)
                else if (post.images != null && post.images!.isNotEmpty)
                  _buildImagePreview(post)
                else
                  _buildDefaultPreview(post),

                // Description
                if (post.description != null && post.description!.isNotEmpty)
                  Container(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      post.description!,
                      style: TextStyle(color: Colors.grey[300], fontSize: 14),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                // Actions
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Icon(Icons.how_to_vote, size: 16, color: Colors.blue),
                      SizedBox(width: 6),
                      Text('${post.votesChallenge ?? 0}', style: TextStyle(color: Colors.white)),
                      SizedBox(width: 16),
                      Icon(Icons.comment, size: 16, color: Colors.grey),
                      SizedBox(width: 6),
                      Text('${post.comments ?? 0}', style: TextStyle(color: Colors.white)),
                      Spacer(),
                      Text(
                        'Voir le post →',
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
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPreview(Post post) {
    return Container(
      width: double.infinity,
      height: 200,
      color: Colors.black,
      child: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.play_circle_filled, size: 50, color: Colors.white.withOpacity(0.7)),
                SizedBox(height: 8),
                Text('VIDÉO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                Text('Cliquez pour regarder', style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          Positioned(
            bottom: 10,
            right: 10,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.play_arrow, size: 12, color: Colors.white),
                  SizedBox(width: 4),
                  Text('VIDÉO', style: TextStyle(color: Colors.white, fontSize: 10)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview(Post post) {
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        image: DecorationImage(
          image: NetworkImage(post.images!.first),
          fit: BoxFit.cover,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.3),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.photo, size: 40, color: Colors.white.withOpacity(0.8)),
              SizedBox(height: 8),
              Text(
                'IMAGE',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Cliquez pour voir',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultPreview(Post post) {
    return Container(
      width: double.infinity,
      height: 120,
      color: Colors.grey[800],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo_library, size: 40, color: Colors.grey),
            SizedBox(height: 8),
            Text(
              'PUBLICATION',
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 4),
            Text(
              'Cliquez pour voir les détails',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String title, String subtitle) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 80, color: Colors.grey[600]),
            SizedBox(height: 20),
            Text(
              title,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _voterPourPost(Post post) async {
    final user = _auth.currentUser;
    if (user == null) {
      _showError('CONNECTEZ-VOUS POUR POUVOIR VOTER\nVotre vote compte pour élire le gagnant !');
      return;
    }

    if (_challenge!.aVote(user.uid)) {
      _showError('VOUS AVEZ DÉJÀ VOTÉ DANS CE CHALLENGE\nMerci pour votre participation !');
      return;
    }

    try {
      if (!_challenge!.voteGratuit!) {
        final solde = await _getSoldeUtilisateur(user.uid);
        if (solde < _challenge!.prixVote!) {
          _showSoldeInsuffisant(_challenge!.prixVote! - solde.toInt());
          return;
        }
      }

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.grey[900],
          title: Text('Confirmer votre vote', style: TextStyle(color: Colors.white)),
          content: Text(
            !_challenge!.voteGratuit!
                ? 'Êtes-vous sûr de vouloir voter pour ce participant ?\n\nCe vote vous coûtera ${_challenge!.prixVote} FCFA.'
                : 'Voulez-vous vraiment voter pour ce participant ?\n\nVotre vote est gratuit et ne peut être changé.',
            style: TextStyle(color: Colors.grey[300]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('ANNULER', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await _processVote(post, user.uid);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: Text('CONFIRMER MON VOTE', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    } catch (e) {
      _showError('Erreur lors de la préparation du vote: $e');
    }
  }

  Future<void> _processVote(Post post, String userId) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final challengeRef = _firestore.collection('Challenges').doc(_challenge!.id!);
        final challengeDoc = await transaction.get(challengeRef);

        if (!challengeDoc.exists) throw Exception('Challenge non trouvé');

        final currentChallenge = Challenge.fromJson(challengeDoc.data()!);
        if (!currentChallenge.isEnCours || currentChallenge.aVote(userId)) {
          throw Exception('Vote non autorisé');
        }

        final postRef = _firestore.collection('Posts').doc(post.id!);
        final postDoc = await transaction.get(postRef);

        if (!postDoc.exists) throw Exception('Post non trouvé');

        if (!_challenge!.voteGratuit!) {
          await _debiterUtilisateur(userId, _challenge!.prixVote!, 'Vote pour le challenge ${_challenge!.titre}');
        }

        transaction.update(postRef, {
          'votes_challenge': FieldValue.increment(1),
          'users_votes_ids': FieldValue.arrayUnion([userId])
        });

        transaction.update(challengeRef, {
          'users_votants_ids': FieldValue.arrayUnion([userId]),
          'total_votes': FieldValue.increment(1),
          'updated_at': DateTime.now().microsecondsSinceEpoch
        });
      });

      _showSuccess('VOTE ENREGISTRÉ !\nMerci d\'avoir participé à l\'élection du gagnant.');
      await _loadPosts();
    } catch (e) {
      _showError('ERREUR LORS DU VOTE: $e\nVeuillez réessayer.');
    }
  }

  // Méthodes utilitaires
  Color _getStatusColor() {
    switch (_challenge!.statut) {
      case 'en_attente': return Colors.orange;
      case 'en_cours': return Colors.green;
      case 'termine': return Colors.blue;
      case 'annule': return Colors.red;
      default: return Colors.grey;
    }
  }

  Color _getRankColor(int index) {
    if (index == 0) return Colors.yellow;
    if (index == 1) return Colors.grey[400]!;
    if (index == 2) return Colors.orange.shade300;
    return Colors.grey[700]!;
  }

  String _getStatusText(String statut) {
    switch (statut) {
      case 'en_attente': return 'INSCRIPTIONS OUVERTES';
      case 'en_cours': return 'VOTE EN COURS';
      case 'termine': return 'CHALLENGE TERMINÉ';
      case 'annule': return 'CHALLENGE ANNULÉ';
      default: return statut.toUpperCase();
    }
  }

  Future<double> _getSoldeUtilisateur(String userId) async {
    final doc = await _firestore.collection('Users').doc(userId).get();
    return (doc.data()?['votre_solde_principal'] ?? 0).toDouble();
  }

  Future<void> _debiterUtilisateur(String userId, int montant, String raison) async {
    await _firestore.collection('Users').doc(userId).update({
      'votre_solde_principal': FieldValue.increment(-montant)
    });

    await _firestore.collection('app_default_data').doc('solde').set({
      'solde_gain': FieldValue.increment(montant)
    }, SetOptions(merge: true));

    await _firestore.collection('transactions').add({
      'user_id': userId,
      'type': 'debit',
      'montant': montant,
      'raison': raison,
      'created_at': DateTime.now().microsecondsSinceEpoch
    });
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 4),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 4),
      ),
    );
  }

  void _showSoldeInsuffisant(int montantManquant) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text('SOLDE INSUFFISANT', style: TextStyle(color: Colors.yellow)),
        content: Text(
          'Il vous manque $montantManquant FCFA pour pouvoir voter.\n\n'
              'Rechargez votre compte pour soutenir votre participant préféré !',
          style: TextStyle(color: Colors.grey[300]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('PLUS TARD', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showSuccess('Redirection vers la page de recharge...');
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: Text('RECHARGER MAINTENANT', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}