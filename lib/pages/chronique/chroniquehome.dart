// pages/chronique/chronique_home_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

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

      // Mettre à jour le lastDocument pour la pagination
      if (result.isNotEmpty) {
        final allChroniques = result.values.expand((x) => x).toList();
        if (allChroniques.isNotEmpty) {
          // Récupérer le dernier document pour la pagination
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

  // Trier les chroniques par date (la plus récente en premier)
  List<List<Chronique>> _getSortedChroniques() {
    final groupedList = _groupedChroniques.values.toList();

    // Trier chaque groupe par date de création décroissante
    for (var group in groupedList) {
      group.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    // Trier les groupes par la date de la chronique la plus récente
    groupedList.sort((a, b) {
      final latestA = a.isNotEmpty ? a.first.createdAt : Timestamp.now();
      final latestB = b.isNotEmpty ? b.first.createdAt : Timestamp.now();
      return latestB.compareTo(latestA);
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
          // Bouton pour voir mes chroniques
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

    // Prendre la chronique la plus récente pour l'affichage principal
    final latestChronique = userChroniques.first;
    final chroniqueCount = userChroniques.length;
    final hasMultiple = chroniqueCount > 1;

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
            // Carte principale avec effet décalé
            Positioned(
              top: hasMultiple ? 8 : 0,
              left: hasMultiple ? 8 : 0,
              right: 0,
              bottom: 0,
              child: _buildChroniquePreview(latestChronique, isMain: true),
            ),

            // Deuxième carte décalée (si multiple) - deuxième plus récente
            if (hasMultiple)
              Positioned(
                top: 0,
                left: 0,
                right: 8,
                bottom: 8,
                child: _buildChroniquePreview(
                  userChroniques[1],
                  isMain: false,
                ),
              ),

            // Badge nombre de chroniques
            if (hasMultiple)
              Positioned(
                top: 12,
                right: 12,
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

            // Statistiques en bas
            Positioned(
              bottom: 8,
              left: 8,
              right: 8,
              child: _buildStatsInfo(latestChronique),
            ),

            // Info utilisateur en haut
            Positioned(
              top: 8,
              left: 8,
              right: 8,
              child: _buildUserInfo(latestChronique),
            ),

            // Indicateur "Nouveau" pour les chroniques récentes
            if (_isChroniqueRecent(latestChronique))
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'NOUVEAU',
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
      ),
    );
  }

  bool _isChroniqueRecent(Chronique chronique) {
    final now = DateTime.now();
    final chroniqueTime = chronique.createdAt.toDate();
    final difference = now.difference(chroniqueTime);
    return difference.inHours < 24; // Moins de 24 heures
  }

  Widget _buildChroniquePreview(Chronique chronique, {bool isMain = true}) {
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
          color: isMain ? Color(0xFFFFD700) : Color(0xFF8B0000),
          width: 2.5,
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
            Container(
              color: Colors.grey[900],
              child: Center(
                child: Icon(
                  Icons.play_circle_filled,
                  color: Color(0xFFFFD700),
                  size: 50,
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

  Widget _buildUserInfo(Chronique chronique) {
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
            radius: 10,
            backgroundImage: CachedNetworkImageProvider(chronique.userImageUrl),
            backgroundColor: Colors.grey[800],
          ),
          SizedBox(width: 6),
          Expanded(
            child: Text(
              chronique.userPseudo,
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsInfo(Chronique chronique) {
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
          _buildStatItem(Icons.remove_red_eye, chronique.viewCount),
          _buildStatItem(Icons.thumb_up, chronique.likeCount),
          _buildStatItem(Icons.favorite, chronique.loveCount),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, int count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Color(0xFFFFD700), size: 12),
        SizedBox(width: 2),
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