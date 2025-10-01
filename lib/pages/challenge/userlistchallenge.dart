import 'dart:typed_data';
import 'package:afrotok/pages/challenge/challengeDetails.dart';
import 'package:afrotok/pages/component/consoleWidget.dart';
import 'package:afrotok/pages/postDetails.dart';
import 'package:afrotok/pages/postDetailsVideoListe.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import '../../models/model_data.dart';
import '../../providers/authProvider.dart';

// Couleurs pour le thème
const _afroBlack = Color(0xFF000000);
const _afroGreen = Color(0xFF00BA7C);
const _afroYellow = Color(0xFFFFD400);
const _afroRed = Color(0xFFF91880);
const _afroBlue = Color(0xFF1D9BF0);
const _afroCardBg = Color(0xFF16181C);
const _afroTextPrimary = Color(0xFFFFFFFF);
const _afroTextSecondary = Color(0xFF71767B);

class UserChallengesPage extends StatefulWidget {
  const UserChallengesPage({Key? key}) : super(key: key);

  @override
  _UserChallengesPageState createState() => _UserChallengesPageState();
}

class _UserChallengesPageState extends State<UserChallengesPage> {
  late UserAuthProvider authProvider;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  String _selectedFilter = 'tous'; // 'tous', 'en_cours', 'termines', 'gagnes'
  List<Map<String, dynamic>> _userChallengeData = []; // [{challenge: Challenge, userPost: Post?}]
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    _loadUserChallenges();
  }

  Future<void> _loadUserChallenges() async {
    try {
      final user = authProvider.loginUserData;
      if (user == null || user.id == null) {
        print("⚠️ Aucun utilisateur connecté.");
        setState(() { _loading = false; });
        return;
      }

      print("👤 Chargement des challenges pour userId = ${user.id}");

      // 1. Récupérer tous les challenges où l'utilisateur est inscrit
      final challengesSnapshot = await firestore
          .collection('Challenges')
          .where('users_inscrits_ids', arrayContains: user.id)
          .get();

      debugPrint("📌 Challenges trouvés: ${challengesSnapshot.docs.length}");

      if (challengesSnapshot.docs.isEmpty) {
        debugPrint("⚠️ Aucun challenge trouvé pour cet utilisateur.");
        setState(() {
          _loading = false;
          _userChallengeData = [];
        });
        return;
      }

      List<Map<String, dynamic>> challengeData = [];

      // 2. Pour chaque challenge, récupérer le post de participation de l'utilisateur
      for (final challengeDoc in challengesSnapshot.docs) {
        final challenge = Challenge.fromJson(challengeDoc.data())..id = challengeDoc.id;
        debugPrint("🏆 Challenge trouvé: ${challenge.titre} (id: ${challenge.id})");

        // Récupérer le post de l'utilisateur pour ce challenge
        final postSnapshot = await firestore
            .collection('Posts')
            .where('user_id', isEqualTo: user.id)
            .where('challenge_id', isEqualTo: challenge.id)
            .limit(1)
            .get();

        debugPrint("📝 Posts trouvés pour ce challenge: ${postSnapshot.docs.length}");

        Post? userPost;
        if (postSnapshot.docs.isNotEmpty) {
          userPost = Post.fromJson(postSnapshot.docs.first.data())..id = postSnapshot.docs.first.id;
          debugPrint("✅ Post de participation trouvé: ${userPost.id}");
        } else {
          debugPrint("⚠️ Aucun post de participation trouvé pour ce challenge.");
        }

        challengeData.add({
          'challenge': challenge,
          'userPost': userPost,
        });
      }

      debugPrint("✅ Données finales: ${challengeData.length} challenges avec posts associés.");

      setState(() {
        _userChallengeData = challengeData;
        _loading = false;
      });

    } catch (e, stack) {
     print('❌ Erreur chargement challenges utilisateur: $e');
      debugPrint('📌 StackTrace: $stack');
      setState(() {
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> _getFilteredChallenges() {
    List<Map<String, dynamic>> filtered = _userChallengeData;

    switch (_selectedFilter) {
      case 'en_cours':
        filtered = filtered.where((data) =>
        (data['challenge'] as Challenge).isEnCours
        ).toList();
        break;
      case 'termines':
        filtered = filtered.where((data) =>
        (data['challenge'] as Challenge).isTermine
        ).toList();
        break;
      case 'gagnes':
        filtered = filtered.where((data) {
          final challenge = data['challenge'] as Challenge;
          return challenge.isTermine &&
              challenge.userGagnantId == authProvider.userData?.id;
        }).toList();
        break;
      case 'tous':
      default:
        break;
    }

    return filtered;
  }

  Widget _buildFilterChips() {
    final filters = [
      {'value': 'tous', 'label': 'Tous mes challenges', 'icon': Icons.all_inclusive},
      {'value': 'en_cours', 'label': 'En cours', 'icon': Icons.play_arrow},
      {'value': 'termines', 'label': 'Terminés', 'icon': Icons.check_circle},
      {'value': 'gagnes', 'label': 'Gagnés', 'icon': Icons.emoji_events},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((filter) {
          final isSelected = _selectedFilter == filter['value'];
          return Container(
            margin: EdgeInsets.only(right: 8),
            child: FilterChip(
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedFilter = filter['value'] as String;
                });
              },
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(filter['icon'] as IconData, size: 16),
                  SizedBox(width: 4),
                  Text(filter['label'] as String),
                ],
              ),
              backgroundColor: _afroCardBg,
              selectedColor: _afroGreen.withOpacity(0.2),
              checkmarkColor: _afroGreen,
              labelStyle: TextStyle(
                color: isSelected ? _afroGreen : _afroTextSecondary,
                fontWeight: FontWeight.w500,
              ),
              side: BorderSide(
                color: isSelected
                    ? _afroGreen
                    : _afroTextSecondary.withOpacity(0.3),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _afroBlack,
      appBar: AppBar(
        backgroundColor: _afroBlack,
        elevation: 0,
        title: Text(
          'Mes Challenges',
          style: TextStyle(
            color: _afroTextPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: _afroTextPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? Center(
        child: CircularProgressIndicator(color: _afroGreen),
      )
          : Column(
        children: [
          // Filtres
          Container(
            padding: EdgeInsets.all(16),
            child: _buildFilterChips(),
          ),

          // Liste des challenges
          Expanded(
            child: _getFilteredChallenges().isEmpty
                ? _buildEmptyState()
                : GridView.builder(
              padding: EdgeInsets.all(16),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.5,
              ),
              itemCount: _getFilteredChallenges().length,
              itemBuilder: (context, index) {
                final data = _getFilteredChallenges()[index];
                final challenge = data['challenge'] as Challenge;
                final userPost = data['userPost'] as Post?;
                return _buildChallengeCard(challenge, userPost);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChallengeCard(Challenge challenge, Post? userPost) {
    final estGagnant = challenge.isTermine &&
        challenge.userGagnantId == authProvider.userData?.id;
    final userPostExists = userPost != null && userPost.id != null;

    return Container(
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
      child: Column(
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
                if (estGagnant)
                  Icon(Icons.emoji_events, size: 16, color: _afroYellow),
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
                  SizedBox(height: 12),

                  // Aperçu du post utilisateur
                  if (userPostExists)
                    Expanded(
                      child: _buildUserPostPreview(userPost!),
                    )
                  else
                    Container(
                      height: 60,
                      decoration: BoxDecoration(
                        color: _afroTextSecondary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _afroTextSecondary.withOpacity(0.3)),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.info_outline, size: 16, color: _afroTextSecondary),
                            SizedBox(height: 4),
                            Text(
                              'Aucun post',
                              style: TextStyle(
                                color: _afroTextSecondary,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Bouton d'action
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(12),
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
    );
  }

  Widget _buildUserPostPreview(Post post) {
    return GestureDetector(
      onTap: () {
        if (post.id != null) {
          if (post.dataType == PostDataType.VIDEO.name) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => VideoTikTokPageDetails(initialPost: post),
              ),
            );
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DetailsPost(post: post),
              ),
            );
          }
        }
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: _afroTextSecondary.withOpacity(0.1),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            children: [
              // Contenu du post
              _buildPostContent(post),

              // Overlay avec informations
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.8),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.how_to_vote, size: 10, color: _afroGreen),
                      SizedBox(width: 2),
                      Text(
                        '${post.votesChallenge ?? 0}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Spacer(),
                      Text(
                        'Cliquer pour voir',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPostContent(Post post) {
    final hasImages = post.images != null && post.images!.isNotEmpty;
    final hasVideo = post.url_media != null && post.url_media!.isNotEmpty;

    if (hasImages) {
      return CachedNetworkImage(
        imageUrl: post.images!.first,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        placeholder: (context, url) => Container(
          color: _afroTextSecondary.withOpacity(0.2),
          child: Center(child: CircularProgressIndicator(color: _afroGreen, strokeWidth: 2)),
        ),
        errorWidget: (context, url, error) => _buildDefaultPostPreview(),
      );
    } else if (hasVideo) {
      return FutureBuilder<Uint8List?>(
        future: _generateThumbnail(post.url_media!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Container(
              color: _afroTextSecondary.withOpacity(0.2),
              child: Center(child: CircularProgressIndicator(color: _afroGreen, strokeWidth: 2)),
            );
          }

          if (snapshot.hasError || snapshot.data == null) {
            return _buildDefaultPostPreview();
          }

          return Image.memory(
            snapshot.data!,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          );
        },
      );
    } else {
      return _buildDefaultPostPreview();
    }
  }

  Widget _buildDefaultPostPreview() {
    return Container(
      color: _afroTextSecondary.withOpacity(0.1),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo_library, color: _afroTextSecondary, size: 20),
            SizedBox(height: 4),
            Text(
              'Mon post',
              style: TextStyle(
                color: _afroTextSecondary,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.emoji_events,
            color: _afroTextSecondary,
            size: 80,
          ),
          SizedBox(height: 16),
          Text(
            'Aucun challenge participé',
            style: TextStyle(
              color: _afroTextPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Participez à des challenges pour les voir apparaître ici',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _afroTextSecondary,
              fontSize: 14,
            ),
          ),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _afroGreen,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text(
              'Découvrir les challenges',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<Uint8List?> _generateThumbnail(String videoUrl) async {
    try {
      final uint8list = await VideoThumbnail.thumbnailData(
        video: videoUrl,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 200,
        quality: 50,
      );
      return uint8list;
    } catch (e) {
      debugPrint("Erreur génération thumbnail: $e");
      return null;
    }
  }
}