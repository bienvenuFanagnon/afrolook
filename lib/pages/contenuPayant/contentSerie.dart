import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/pages/contenuPayant/contentDetails.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../providers/contenuPayantProvider.dart';

class SeriesEpisodesScreen extends StatefulWidget {
  final ContentPaie series;

  const SeriesEpisodesScreen({Key? key, required this.series}) : super(key: key);

  @override
  _SeriesEpisodesScreenState createState() => _SeriesEpisodesScreenState();
}

class _SeriesEpisodesScreenState extends State<SeriesEpisodesScreen> {
  List<Episode> _episodes = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadEpisodes();
  }

  Future<void> _loadEpisodes() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });

      // Récupérer les épisodes depuis Firebase Firestore
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('episodes')
          .where('seriesId', isEqualTo: widget.series.id)
          .orderBy('episodeNumber', descending: false)
          .get();

      List<Episode> loadedEpisodes = [];

      for (var doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        loadedEpisodes.add(Episode.fromJson({
          ...data,
          'id': doc.id,
        }));
      }

      setState(() {
        _episodes = loadedEpisodes;
        _isLoading = false;
      });
    } catch (e) {
      print('Erreur lors du chargement des épisodes: $e');
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Erreur de chargement: ${e.toString()}';
      });
    }
  }

  String _formatDuration(int seconds) {
    final duration = Duration(seconds: seconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}min';
    } else {
      return '${minutes}min';
    }
  }

  Widget _buildEpisodeItem(Episode episode, int index) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Numéro de l'épisode
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.black,
              border: Border.all(color: Colors.green, width: 2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Text(
                '${episode.episodeNumber}',
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          SizedBox(width: 12),
          // Image de l'épisode
          Expanded(
            flex: 2,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                children: [
                  episode.thumbnailUrl != null && episode.thumbnailUrl!.isNotEmpty
                      ? CachedNetworkImage(
                    imageUrl: episode.thumbnailUrl!,
                    width: double.infinity,
                    height: 90,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: Colors.grey[800],
                      height: 90,
                      child: Center(child: CircularProgressIndicator(color: Colors.green)),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[800],
                      height: 90,
                      child: Icon(Icons.error, color: Colors.white),
                    ),
                  )
                      : Container(
                    color: Colors.grey[800],
                    height: 90,
                    child: Icon(Icons.videocam, color: Colors.grey[600], size: 30),
                  ),
                  // Badge de durée
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _formatDuration(episode.duration),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  // Badge pour contenu payant
                  if (!episode.isFree)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.monetization_on, color: Colors.yellow, size: 16),
                      ),
                    ),
                ],
              ),
            ),
          ),
          SizedBox(width: 12),
          // Informations de l'épisode
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  episode.title,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4),
                Text(
                  episode.description,
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    if (!episode.isFree)
                      Text(
                        '${episode.price} F',
                        style: TextStyle(
                          color: Colors.yellow,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      )
                    else
                      Text(
                        'Gratuit',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    SizedBox(width: 16),
                    Row(
                      children: [
                        Icon(Icons.visibility, color: Colors.grey, size: 16),
                        SizedBox(width: 4),
                        Text(
                          '${episode.views}',
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                      ],
                    ),
                    SizedBox(width: 16),
                    Row(
                      children: [
                        Icon(Icons.thumb_up, color: Colors.grey, size: 16),
                        SizedBox(width: 4),
                        Text(
                          '${episode.likes}',
                          style: TextStyle(color: Colors.grey, fontSize: 14),
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

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: Colors.red, size: 64),
          SizedBox(height: 16),
          Text(
            'Erreur de chargement',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          SizedBox(height: 8),
          Text(
            _errorMessage,
            style: TextStyle(color: Colors.grey, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.green,
            ),
            onPressed: _loadEpisodes,
            child: Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.green),
          SizedBox(height: 16),
          Text(
            'Chargement des épisodes...',
            style: TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.playlist_play, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Aucun épisode disponible',
            style: TextStyle(color: Colors.white70, fontSize: 18),
          ),
          SizedBox(height: 8),
          Text(
            'Les épisodes seront bientôt disponibles',
            style: TextStyle(color: Colors.grey, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final contentProvider = Provider.of<ContentProvider>(context, listen: false);
    contentProvider.incrementViews(widget.series.id!);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          widget.series.title,
          style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
        ),
        iconTheme: IconThemeData(color: Colors.green),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.green),
            onPressed: _loadEpisodes,
          ),
          IconButton(
            icon: Icon(Icons.share, color: Colors.green),
            onPressed: () {
              // Action de partage
            },
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingWidget()
          : _hasError
          ? _buildErrorWidget()
          : SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bannière de la série
            Container(
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.grey[900],
              ),
              child: widget.series.thumbnailUrl != null && widget.series.thumbnailUrl!.isNotEmpty
                  ? ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: widget.series.thumbnailUrl!,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: Colors.grey[800],
                    child: Center(child: CircularProgressIndicator(color: Colors.green)),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey[800],
                    child: Icon(Icons.error, color: Colors.white),
                  ),
                ),
              )
                  : Center(
                child: Icon(Icons.videocam, color: Colors.grey[600], size: 50),
              ),
            ),
            SizedBox(height: 16),
            // Titre et description de la série
            Text(
              widget.series.title,
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              widget.series.description,
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 16),
            // Statistiques de la série
            Row(
              children: [
                Row(
                  children: [
                    Icon(Icons.playlist_play, color: Colors.green, size: 20),
                    SizedBox(width: 4),
                    Text(
                      '${_episodes.length} épisode${_episodes.length > 1 ? 's' : ''}',
                      style: TextStyle(color: Colors.green, fontSize: 16),
                    ),
                  ],
                ),
                SizedBox(width: 20),
                Row(
                  children: [
                    Icon(Icons.visibility, color: Colors.grey, size: 20),
                    SizedBox(width: 4),
                    Text(
                      '${widget.series.views} vues',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 24),
            // Liste des épisodes
            Text(
              'Épisodes',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            if (_episodes.isEmpty)
              _buildEmptyWidget()
            else
              Column(
                children: List.generate(_episodes.length, (index) {
                  final episode = _episodes[index];
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ContentDetailScreen(content: widget.series, episode: episode),
                        ),
                      );
                    },
                    child: _buildEpisodeItem(episode, index),
                  );
                }),
              ),
          ],
        ),
      ),
    );
  }
}