import 'dart:typed_data';

import 'package:afrotok/pages/challenge/challengeDetails.dart';
import 'package:afrotok/pages/component/consoleWidget.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../../models/model_data.dart';
import '../../providers/authProvider.dart';
import '../pub/native_ad_widget.dart';


// Couleurs pour le thème
const _afroBlack = Color(0xFF000000);
const _afroGreen = Color(0xFF00BA7C);
const _afroYellow = Color(0xFFFFD400);
const _afroRed = Color(0xFFF91880);
const _afroBlue = Color(0xFF1D9BF0);
const _afroCardBg = Color(0xFF16181C);
const _afroTextPrimary = Color(0xFFFFFFFF);
const _afroTextSecondary = Color(0xFF71767B);

class ChallengesListPage extends StatefulWidget {
  const ChallengesListPage({Key? key}) : super(key: key);

  @override
  _ChallengesListPageState createState() => _ChallengesListPageState();
}

class _ChallengesListPageState extends State<ChallengesListPage> {
  late UserAuthProvider authProvider;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  String _selectedFilter = 'tous'; // 'tous', 'en_cours', 'a_venir', 'termines'

  @override
  void initState() {
    super.initState();
    authProvider = Provider.of<UserAuthProvider>(context, listen: false);
  }

  String _getFilteredStatus(String filter) {
    switch (filter) {
      case 'en_cours':
        return 'en_cours';
      case 'a_venir':
        return 'en_attente';
      case 'termines':
        return 'termine';
      default:
        return 'tous';
    }
  }

  Widget _buildFilterChips() {
    final filters = [
      {'value': 'tous', 'label': 'Tous', 'icon': Icons.all_inclusive},
      {'value': 'en_cours', 'label': 'En cours', 'icon': Icons.play_arrow},
      {'value': 'a_venir', 'label': 'À venir', 'icon': Icons.schedule},
      {'value': 'termines', 'label': 'Terminés', 'icon': Icons.check_circle},
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
  Widget _buildAdBanner({required String key}) {
    // return SizedBox.shrink();
    return Container(
      key: ValueKey(key),
      margin: EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: NativeAdWidget(
        templateType: TemplateType.small, // ou TemplateType.small

        onAdLoaded: () {
          print('✅ Native Ad Afrolook chargée: $key');
        },
      ),

      // child: BannerAdWidget(
      //   onAdLoaded: () {
      //     print('✅ Bannière Afrolook chargée: $key');
      //   },
      // ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _afroBlack,
      appBar: AppBar(
        backgroundColor: _afroBlack,
        automaticallyImplyLeading: false,
        elevation: 0,
        title: Text(
          'Challenges',
          style: TextStyle(
            color: _afroTextPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.search, color: _afroTextPrimary),
            onPressed: () {
              // TODO: Implémenter la recherche
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Filtres
          Container(
            padding: EdgeInsets.all(16),
            child: _buildFilterChips(),
          ),
// ✅ AJOUT: Bannière native en première position
          // Liste des challenges
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _selectedFilter == 'tous'
                  ? firestore
                      .collection('Challenges')
                      // .where('isAprouved', isEqualTo: true)
                      .where('disponible', isEqualTo: true)
                      .orderBy('created_at', descending: true)
                      .snapshots()
                  : firestore
                      .collection('Challenges')
                      // .where('isAprouved', isEqualTo: true)
                      .where('disponible', isEqualTo: true)
                      .where('statut',
                          isEqualTo: _getFilteredStatus(_selectedFilter))
                      .orderBy('created_at', descending: true)
                      .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  printVm("Erreur de chargement: ${snapshot.error.toString()}");
                  return Center(
                    child: Text(
                      'Erreur de chargement',
                      style: TextStyle(color: _afroTextSecondary),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(color: _afroGreen),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState();
                }

                final challenges = snapshot.data!.docs;

                // ✅ Construction de la liste avec la pub en PREMIER élément
                return ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: challenges.length + 1, // +1 pour la pub
                  itemBuilder: (context, index) {
                    // Premier élément (index 0) = la pub
                    if (index == 0) {
                      return Column(
                        children: [
                          _buildAdBanner(key: 'challenges_first_ad'),
                          SizedBox(height: 16), // Espacement après la pub
                        ],
                      );
                    }

                    // Ensuite les challenges (décalés d'un index)
                    final challengeIndex = index - 1;
                    final challengeData =
                    challenges[challengeIndex].data() as Map<String, dynamic>;
                    final challenge = Challenge.fromJson(challengeData);

                    return _buildChallengeCard(challenge, context);
                  },
                );              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChallengeCard(Challenge challenge, BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _afroCardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            _navigateToChallengeDetails(challenge, context);
          },
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // En-tête avec statut
                Row(
                  children: [
                    _buildStatusBadge(challenge),
                    Spacer(),
                    _buildParticipantCount(challenge),
                  ],
                ),
                SizedBox(height: 12),

                // Titre et description
                Text(
                  challenge.titre ?? 'Challenge sans titre',
                  style: TextStyle(
                    color: _afroTextPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 8),

                if (challenge.description != null &&
                    challenge.description!.isNotEmpty)
                  Text(
                    challenge.description!,
                    style: TextStyle(
                      color: _afroTextSecondary,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                SizedBox(height: 10),

                // Aperçu du post du challenge
                _buildChallengePreview(challenge),

                SizedBox(height: 10),

                // Informations de prix et dates
                Row(
                  children: [
                    if (challenge.prix != null && challenge.prix! > 0)
                      _buildPrizeInfo(challenge),
                    Spacer(),
                    _buildDateInfo(challenge),
                  ],
                ),

                SizedBox(height: 12),

                // Barre de progression et statistiques
                _buildProgressStats(challenge),

                SizedBox(height: 8),

                // Bouton d'action
                _buildActionButton(challenge),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(Challenge challenge) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (challenge.statut) {
      case 'en_cours':
        statusColor = _afroGreen;
        statusText = 'EN COURS';
        statusIcon = Icons.play_arrow;
        break;
      case 'en_attente':
        statusColor = _afroBlue;
        statusText = 'À VENIR';
        statusIcon = Icons.schedule;
        break;
      case 'termine':
        statusColor = _afroTextSecondary;
        statusText = 'TERMINÉ';
        statusIcon = Icons.check_circle;
        break;
      case 'annule':
        statusColor = _afroRed;
        statusText = 'ANNULÉ';
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = _afroTextSecondary;
        statusText = 'INCONNU';
        statusIcon = Icons.help;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon, color: statusColor, size: 14),
          SizedBox(width: 4),
          Text(
            statusText,
            style: TextStyle(
              color: statusColor,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantCount(Challenge challenge) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.people_outline, color: _afroTextSecondary, size: 16),
        SizedBox(width: 4),
        Text(
          // '${challenge.totalParticipants ?? 0}',
          '${challenge.usersInscritsIds!.length ?? 0}',
          style: TextStyle(
            color: _afroTextPrimary,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          ' participants',
          style: TextStyle(
            color: _afroTextSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildChallengePreview(Challenge challenge) {
    return FutureBuilder<DocumentSnapshot>(
      future: challenge.postChallengeId != null
          ? firestore.collection('Posts').doc(challenge.postChallengeId).get()
          : null,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            height: 120,
            decoration: BoxDecoration(
              color: _afroTextSecondary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: CircularProgressIndicator(color: _afroGreen),
            ),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return _buildDefaultPreview();
        }

        final postData = snapshot.data!.data() as Map<String, dynamic>;
        final post = Post.fromJson(postData);

        return Container(
          height: 120,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: _afroTextSecondary.withOpacity(0.1),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: _buildPostPreviewContent(post),
          ),
        );
      },
    );
  }

  Widget _buildPostPreviewContent(Post post) {

    final hasImages = post.images != null && post.images!.isNotEmpty;
    final hasVideo = post.url_media != null && post.url_media!.isNotEmpty;
    printVm('_buildPostPreviewContent hasVideo : ${hasVideo}');

    if (hasImages) {
      return Stack(
        children: [
          CachedNetworkImage(
            imageUrl: post.images!.first,
            fit: BoxFit.cover,
            width: double.infinity,
            placeholder: (context, url) => Container(
              color: _afroTextSecondary.withOpacity(0.2),
              child: Center(child: CircularProgressIndicator(color: _afroGreen)),
            ),
            errorWidget: (context, url, error) => _buildDefaultPreview(),
          ),
          _buildMediaOverlay('IMAGE'),
        ],
      );
    } else if (hasVideo) {
      return FutureBuilder<Uint8List?>(
        future: _generateThumbnail(post.url_media!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Container(
              color: _afroTextSecondary.withOpacity(0.2),
              child: Center(child: CircularProgressIndicator(color: _afroGreen)),
            );
          }

          if (snapshot.hasError || snapshot.data == null) {

            printVm('_generateThumbnail : ${snapshot.error.toString()}');
            return Stack(
              children: [
                Container(
                  color: _afroTextSecondary.withOpacity(0.2),
                  child: Center(
                    child: Icon(Icons.videocam,
                        color: _afroTextSecondary, size: 40),
                  ),
                ),
                _buildMediaOverlay('VIDÉO'),
              ],
            );
          }

          return Stack(
            children: [
              Image.memory(
                snapshot.data!,
                fit: BoxFit.cover,
                width: double.infinity,
              ),
              _buildMediaOverlay('VIDÉO'),
            ],
          );
        },
      );
    } else {
      return _buildDefaultPreview();
    }
  }

  /// Générer un thumbnail à partir de la vidéo
  Future<Uint8List?> _generateThumbnail(String videoUrl) async {
    printVm('_generateThumbnail ...');

    try {
      final uint8list = await VideoThumbnail.thumbnailData(
        video: videoUrl,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 400, // taille de l'aperçu
        quality: 75,
      );
      return uint8list;
    } catch (e) {
      debugPrint("Erreur génération thumbnail: $e");
      return null;
    }
  }

  Widget _buildMediaOverlay(String type) {
    return Positioned(
      top: 8,
      right: 8,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          type,
          style: TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultPreview() {
    return Container(
      color: _afroTextSecondary.withOpacity(0.1),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.emoji_events, color: _afroTextSecondary, size: 40),
            SizedBox(height: 8),
            Text(
              'Challenge',
              style: TextStyle(
                color: _afroTextSecondary,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrizeInfo(Challenge challenge) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.card_giftcard, color: _afroYellow, size: 16),
        SizedBox(width: 4),
        Text(
          '${challenge.prix} FCFA',
          style: TextStyle(
            color: _afroYellow,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildDateInfo(Challenge challenge) {
    String dateText;
    Color dateColor = _afroTextSecondary;

    if (challenge.isEnCours) {
      dateText = 'Termine ${_formatDate(challenge.finishedAt)}';
      dateColor = _afroGreen;
    } else if (challenge.isEnAttente) {
      dateText = 'Début ${_formatDate(challenge.endInscriptionAt)}';
      dateColor = _afroBlue;
    } else if (challenge.isTermine) {
      dateText = 'Terminé ${_formatDate(challenge.finishedAt)}';
    } else {
      dateText = 'Date inconnue';
    }

    return Text(
      dateText,
      style: TextStyle(
        color: dateColor,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  String _formatDate(int? timestamp) {
    if (timestamp == null) return '--/--/----';

    final date = DateTime.fromMicrosecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final difference = date.difference(now);

    if (difference.inDays == 0) {
      return "aujourd'hui";
    } else if (difference.inDays == 1) {
      return "demain";
    } else if (difference.inDays > 1 && difference.inDays <= 7) {
      return "dans ${difference.inDays} jours";
    } else {
      return DateFormat('dd/MM/yy').format(date);
    }
  }

  Widget _buildProgressStats(Challenge challenge) {
    final totalVotes = challenge.totalVotes ?? 0;
    final totalParticipants =
        challenge.usersInscritsIds!.length ?? 1; // Éviter division par zéro

      // final totalParticipants =
      //   challenge.totalParticipants ?? 1; // Éviter division par zéro

    return Column(
      children: [
        // Barre de progression
        LinearProgressIndicator(
          value: totalParticipants > 0
              ? (totalVotes / (totalParticipants * 10))
              : 0,
          backgroundColor: _afroTextSecondary.withOpacity(0.2),
          valueColor: AlwaysStoppedAnimation<Color>(_afroGreen),
          minHeight: 6,
          borderRadius: BorderRadius.circular(3),
        ),
        SizedBox(height: 8),

        // Statistiques
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildStatItem(
              icon: Icons.how_to_vote,
              value: '${totalVotes}',
              label: 'Votes',
            ),
            _buildStatItem(
              icon: Icons.people,
              value: '${totalParticipants}',
              label: 'Participants',
            ),
            _buildStatItem(
              icon: Icons.trending_up,
              value: '${challenge.prix ?? 0} fcfa',
              label: 'Gains',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatItem(
      {required IconData icon, required String value, required String label}) {
    return Column(
      children: [
        Icon(icon, color: _afroTextSecondary, size: 16),
        SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: _afroTextPrimary,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: _afroTextSecondary,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(Challenge challenge) {
    String buttonText;
    Color buttonColor;
    VoidCallback? onPressed;

    if (challenge.isEnCours) {
      buttonText = 'PARTICIPER';
      buttonColor = _afroGreen;
      onPressed = () => _navigateToChallengeDetails(challenge, context);
    } else if (challenge.isEnAttente) {
      // buttonText = 'VÉRIFIER';
      buttonText = 'S’INSCRIRE';

      buttonColor = _afroBlue;
      onPressed = () => _navigateToChallengeDetails(challenge, context);
    } else if (challenge.isTermine) {
      buttonText = 'VOIR RÉSULTATS';
      buttonColor = _afroTextSecondary;
      onPressed = () => _navigateToChallengeDetails(challenge, context);
    } else {
      buttonText = 'VOIR DÉTAILS';
      buttonColor = _afroTextSecondary;
      onPressed = () => _navigateToChallengeDetails(challenge, context);
    }

    return Container(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: buttonColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: EdgeInsets.symmetric(vertical: 12),
        ),
        child: Text(
          buttonText,
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
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
            'Aucun challenge disponible',
            style: TextStyle(
              color: _afroTextPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Revenez plus tard pour découvrir\nles nouveaux challenges',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _afroTextSecondary,
              fontSize: 14,
            ),
          ),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _selectedFilter = 'tous';
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _afroGreen,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text(
              'Actualiser',
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

  void _navigateToChallengeDetails(Challenge challenge, BuildContext context) {
    // TODO: Implémenter la navigation vers la page de détails du challenge
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChallengeDetailPage(challengeId: challenge.id!),
      ),
    );

    // Pour l'instant, afficher un snackbar
    // ScaffoldMessenger.of(context).showSnackBar(
    //   SnackBar(
    //     backgroundColor: _afroGreen,
    //     content: Text(
    //       'Navigation vers: ${challenge.titre}',
    //       style: TextStyle(color: Colors.white),
    //     ),
    //   ),
    // );
  }
}
