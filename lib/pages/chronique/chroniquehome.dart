// pages/chronique/chronique_home_page.dart
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../../providers/chroniqueProvider.dart';
import '../../providers/authProvider.dart';
import 'chroniquedetails.dart';
import 'chroniqueform.dart';
import 'mychroniquepage.dart';

class ChroniqueHomePage extends StatefulWidget {
  @override
  State<ChroniqueHomePage> createState() => _ChroniqueHomePageState();
}

class _ChroniqueHomePageState extends State<ChroniqueHomePage> {
  final ScrollController _scrollController = ScrollController();
  final Map<String, List<Chronique>> _groupedChroniques = {};
  bool _isLoading = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDocument;
  final int _batchSize = 10;
  bool _isFirstLoad = true;
  final Map<String, String> _videoThumbnails = {};

  @override
  void initState() {
    super.initState();
    _loadInitialChroniques();
    _scrollController.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ChroniqueProvider>(context, listen: false)
          .cleanupExpiredChroniques();
    });
  }

  void _loadInitialChroniques() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _groupedChroniques.clear();
      _hasMore = true;
      _lastDocument = null;
    });

    try {
      final provider = Provider.of<ChroniqueProvider>(context, listen: false);
      final result = await provider.getGroupedChroniquesBatch(limit: _batchSize);

      // Charger les thumbnails pour les vidéos
      await _loadVideoThumbnails(result);

      // Mettre à jour le lastDocument pour la pagination
      if (result.isNotEmpty) {
        final allChroniques = result.values.expand((x) => x).toList();
        if (allChroniques.isNotEmpty) {
          final lastChronique = allChroniques.last;
          final lastDoc = await FirebaseFirestore.instance
              .collection('chroniques')
              .doc(lastChronique.id)
              .get();
          _lastDocument = lastDoc;
        }
      }

      setState(() {
        _groupedChroniques.addAll(result);
        _isLoading = false;
        _isFirstLoad = false;
      });
    } catch (e) {
      print('Erreur chargement initial: $e');
      setState(() {
        _isLoading = false;
        _isFirstLoad = false;
      });
    }
  }

  Future<void> _loadVideoThumbnails(Map<String, List<Chronique>> chroniques) async {
    for (var userChroniques in chroniques.values) {
      for (var chronique in userChroniques) {
        if (chronique.type == ChroniqueType.VIDEO && chronique.mediaUrl != null) {
          try {
            final thumbnail = await VideoThumbnail.thumbnailFile(
              video: chronique.mediaUrl!,
              imageFormat: ImageFormat.JPEG,
              maxWidth: 200,
              quality: 50,
              timeMs: 2000, // 2ème frame
            );
            if (thumbnail != null) {
              _videoThumbnails[chronique.id!] = thumbnail;
            }
          } catch (e) {
            print('Erreur génération thumbnail: $e');
          }
        }
      }
    }
  }

  void _loadMoreChroniques() async {
    if (_isLoading || !_hasMore) return;

    setState(() => _isLoading = true);

    try {
      final provider = Provider.of<ChroniqueProvider>(context, listen: false);
      final result = await provider.getGroupedChroniquesBatch(
        limit: _batchSize,
        lastDocument: _lastDocument,
      );

      if (result.isEmpty) {
        setState(() {
          _hasMore = false;
          _isLoading = false;
        });
        return;
      }

      // Charger les thumbnails
      await _loadVideoThumbnails(result);

      // Mettre à jour le lastDocument
      final allChroniques = result.values.expand((x) => x).toList();
      if (allChroniques.isNotEmpty) {
        final lastChronique = allChroniques.last;
        final lastDoc = await FirebaseFirestore.instance
            .collection('chroniques')
            .doc(lastChronique.id)
            .get();
        _lastDocument = lastDoc;
      }

      setState(() {
        _groupedChroniques.addAll(result);
        _isLoading = false;
      });
    } catch (e) {
      print('Erreur chargement supplémentaire: $e');
      setState(() => _isLoading = false);
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 100) {
      _loadMoreChroniques();
    }
  }

  // Trier les chroniques par date (les plus anciennes en premier)
  List<List<Chronique>> _getSortedChroniques() {
    final groupedList = _groupedChroniques.values.toList();

    // Trier chaque groupe par date de création croissante (anciennes d'abord)
    for (var group in groupedList) {
      group.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }

    // Trier les groupes par la date de la chronique la plus ancienne
    groupedList.sort((a, b) {
      final oldestA = a.isNotEmpty ? a.first.createdAt : Timestamp.now();
      final oldestB = b.isNotEmpty ? b.first.createdAt : Timestamp.now();
      return oldestA.compareTo(oldestB);
    });

    return groupedList;
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<UserAuthProvider>(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(authProvider),
            SizedBox(height: 10),
            Expanded(
              child: _buildChroniqueList(),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Widget _buildHeader(UserAuthProvider authProvider) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border(
          bottom: BorderSide(color: Color(0xFFFFD700).withOpacity(0.3), width: 1),
        ),
      ),
      child: Row(
        children: [
          Text(
            'Chroniques Afrolook',
            style: TextStyle(
              color: Color(0xFFFFD700),
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          Spacer(),
          IconButton(
            icon: Icon(Icons.person, color: Color(0xFFFFD700)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MyChroniquesPage(),
                ),
              );
            },
            tooltip: 'Mes chroniques',
          ),
          IconButton(
            icon: Icon(Icons.refresh, color: Color(0xFFFFD700)),
            onPressed: _loadInitialChroniques,
            tooltip: 'Actualiser',
          ),
        ],
      ),
    );
  }

  Widget _buildChroniqueList() {
    if (_isFirstLoad && _isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFFFFD700)),
            SizedBox(height: 16),
            Text(
              'Chargement des chroniques...',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      );
    }

    if (_groupedChroniques.isEmpty && !_isLoading) {
      return _buildEmptyState();
    }

    final sortedChroniques = _getSortedChroniques();

    return NotificationListener<ScrollNotification>(
      onNotification: (scrollNotification) {
        if (scrollNotification is ScrollEndNotification) {
          _onScroll();
        }
        return false;
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: GridView.builder(
          controller: _scrollController,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 0.75,
          ),
          itemCount: sortedChroniques.length + (_hasMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == sortedChroniques.length) {
              return _buildLoadMoreIndicator();
            }
            return _buildUserChroniqueCard(sortedChroniques[index]);
          },
        ),
      ),
    );
  }

  Widget _buildUserChroniqueCard(List<Chronique> userChroniques) {
    if (userChroniques.isEmpty) return SizedBox();

    // Prendre la chronique la plus ancienne pour l'affichage principal
    final oldestChronique = userChroniques.first;
    final chroniqueCount = userChroniques.length;
    final hasMultiple = chroniqueCount > 1;

    // Calculer les stats totales
    int totalViews = 0;
    int totalLikes = 0;
    int totalComments = 0;

    for (var chronique in userChroniques) {
      totalViews += chronique.viewCount;
      totalLikes += chronique.likeCount + chronique.loveCount;
      // Pour les commentaires, vous devrez ajouter cette propriété au modèle Chronique
      totalComments += chronique.commentCount;
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChroniqueDetailPage(
              userChroniques: userChroniques,
            ),
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.all(4),
        child: Stack(
          children: [
            // Carte principale
            _buildChroniquePreview(oldestChronique),

            // Badge nombre de chroniques
            if (hasMultiple)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Color(0xFFFFD700), width: 1.5),
                  ),
                  child: Text(
                    '+${chroniqueCount - 1}',
                    style: TextStyle(
                      color: Color(0xFFFFD700),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

            // Stats en bas
            Positioned(
              bottom: 8,
              left: 8,
              right: 8,
              child: _buildStatsInfo(totalViews, totalLikes, totalComments),
            ),

            // Profil utilisateur avec chrono en haut
            Positioned(
              top: 8,
              left: 8,
              right: 8,
              child: _buildUserInfoWithTimer(oldestChronique),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChroniquePreview(Chronique chronique) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 10,
            offset: Offset(2, 4),
          ),
        ],
        border: Border.all(
          color: Color(0xFFFFD700),
          width: 2,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: _buildChroniqueContent(chronique),
      ),
    );
  }

  Widget _buildChroniqueContent(Chronique chronique) {
    switch (chronique.type) {
      case ChroniqueType.TEXT:
        return Container(
          color: Color(int.parse(chronique.backgroundColor!, radix: 16)),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                chronique.textContent!,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );

      case ChroniqueType.IMAGE:
        return Stack(
          children: [
            CachedNetworkImage(
              imageUrl: chronique.mediaUrl!,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              placeholder: (context, url) => Container(
                color: Colors.grey[800],
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFFFFD700)),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                color: Colors.grey[800],
                child: Icon(Icons.error, color: Color(0xFFFFD700), size: 30),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.6),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ],
        );

      case ChroniqueType.VIDEO:
        return Stack(
          children: [
            // Aperçu de la vidéo (thumbnail)
            if (_videoThumbnails.containsKey(chronique.id!))
              Image.file(
                File(_videoThumbnails[chronique.id!]!),
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              )
            else
              Container(
                color: Colors.grey[900],
                child: Center(
                  child: Icon(
                    Icons.play_circle_filled,
                    color: Color(0xFFFFD700),
                    size: 40,
                  ),
                ),
              ),

            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.6),
                    Colors.transparent,
                  ],
                ),
              ),
            ),

            // Indicateur vidéo
            Positioned(
              bottom: 8,
              right: 8,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Color(0xFFFFD700), width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.play_arrow, color: Colors.white, size: 12),
                    SizedBox(width: 2),
                    Text(
                      '${chronique.duration}s',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
    }
  }

  Widget _buildUserInfoWithTimer(Chronique chronique) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 12,
            backgroundImage: CachedNetworkImageProvider(chronique.userImageUrl),
            backgroundColor: Colors.grey[800],
          ),
          SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  chronique.userPseudo,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 2),
                Text(
                  _getTimeLeft(chronique.expiresAt),
                  style: TextStyle(
                    color: Color(0xFFFFD700),
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsInfo(int totalViews, int totalLikes, int totalComments) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFFFFD700).withOpacity(0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(Icons.remove_red_eye, totalViews),
          _buildStatItem(Icons.thumb_up, totalLikes),
          _buildStatItem(Icons.comment, totalComments),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, int count) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Color(0xFFFFD700), size: 14),
        SizedBox(height: 2),
        Text(
          _formatCount(count),
          style: TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  String _formatCount(int count) {
    if (count < 1000) return count.toString();
    if (count < 1000000) return '${(count / 1000).toStringAsFixed(1)}K';
    return '${(count / 1000000).toStringAsFixed(1)}M';
  }

  String _getTimeLeft(Timestamp expiresAt) {
    final now = DateTime.now();
    final expireTime = expiresAt.toDate();
    final difference = expireTime.difference(now);

    if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'Expiré';
    }
  }

  Widget _buildLoadMoreIndicator() {
    if (!_hasMore) {
      return Container(
        padding: EdgeInsets.all(16),
        child: Center(
          child: Text(
            'Plus de chroniques à charger',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            CircularProgressIndicator(color: Color(0xFFFFD700)),
            SizedBox(height: 8),
            Text(
              'Chargement...',
              style: TextStyle(color: Colors.grey),
            ),
          ],
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
            Icons.history_toggle_off,
            color: Color(0xFFFFD700),
            size: 80,
          ),
          SizedBox(height: 20),
          Text(
            'Aucune chronique active',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Soyez le premier à partager\nvotre histoire !',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AddChroniquePage()),
              );
            },
            child: Text(
              'CRÉER MA PREMIÈRE CHRONIQUE',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFFFFD700),
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return FloatingActionButton(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => AddChroniquePage()),
        );
      },
      backgroundColor: Color(0xFFFFD700),
      foregroundColor: Colors.black,
      elevation: 8,
      child: Icon(Icons.add, size: 28),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}