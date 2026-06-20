import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/pages/contenuPayant/contentDetails.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../providers/contenuPayantProvider.dart';
import '../../providers/authProvider.dart';
import '../../theme/app_colors.dart';
import 'contentDetailsEbook.dart';

class SeriesEpisodesScreen extends StatefulWidget {
  final ContentPaie series;

  const SeriesEpisodesScreen({Key? key, required this.series}) : super(key: key);

  @override
  _SeriesEpisodesScreenState createState() => _SeriesEpisodesScreenState();
}

class _SeriesEpisodesScreenState extends State<SeriesEpisodesScreen> {
  String _cdnUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    final userProvider = Provider.of<UserAuthProvider>(context, listen: false);
    return userProvider.convertToCdnUrl(url, userProvider.appDefaultData);
  }

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
      setState(() { _isLoading = true; _hasError = false; });
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('episodes')
          .where('seriesId', isEqualTo: widget.series.id)
          .orderBy('episodeNumber', descending: false)
          .get();
      setState(() {
        _episodes = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return Episode.fromJson({...data, 'id': doc.id});
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() { _isLoading = false; _hasError = true; _errorMessage = 'Erreur: ${e.toString()}'; });
    }
  }

  String _formatDuration(int seconds) {
    final d = Duration(seconds: seconds);
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    return h > 0 ? '${h}h ${m}min' : '${m}min';
  }

  String _formatPageCount(int pageCount) => '$pageCount page${pageCount > 1 ? 's' : ''}';

  // VIDEO = info (bleu), EBOOK = warning (orange) — couleurs sémantiques intentionnelles
  Color _typeColor(ContentType t, AppColors colors) =>
      t == ContentType.VIDEO ? colors.info : colors.warning;

  Widget _buildContentTypeBadge(ContentType contentType, AppColors colors) {
    final color = _typeColor(contentType, colors);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color),
      ),
      child: Text(
        contentType == ContentType.VIDEO ? 'VIDÉO' : 'EBOOK',
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildEpisodeItem(Episode episode, int index, AppColors colors) {
    final typeColor = _typeColor(episode.contentType, colors);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Numéro
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: colors.background,
              border: Border.all(color: typeColor, width: 2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Text('${episode.episodeNumber}',
                  style: TextStyle(color: typeColor, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
          const SizedBox(width: 12),
          // Thumbnail
          Expanded(
            flex: 2,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                children: [
                  episode.thumbnailUrl != null && episode.thumbnailUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: _cdnUrl(episode.thumbnailUrl),
                          width: double.infinity, height: 90, fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            color: colors.surfaceVariant, height: 90,
                            child: Center(child: CircularProgressIndicator(color: typeColor)),
                          ),
                          errorWidget: (_, __, ___) => Container(
                            color: colors.surfaceVariant, height: 90,
                            child: Icon(episode.isVideo ? Icons.videocam : Icons.book, color: colors.textSecondary, size: 30),
                          ),
                        )
                      : Container(
                          color: colors.surfaceVariant, height: 90,
                          child: Icon(episode.isVideo ? Icons.videocam : Icons.book, color: colors.textSecondary, size: 30),
                        ),
                  if (!episode.isFree)
                    Positioned(
                      top: 4, right: 4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), shape: BoxShape.circle),
                        child: Icon(Icons.monetization_on, color: colors.accent, size: 16),
                      ),
                    ),
                  Positioned(
                    top: 4, left: 4,
                    child: _buildContentTypeBadge(episode.contentType, colors),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Infos
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(episode.title,
                    style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(episode.description,
                    style: TextStyle(color: colors.textSecondary, fontSize: 14),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (!episode.isFree)
                      Text('${episode.price} F',
                          style: TextStyle(color: colors.accent, fontWeight: FontWeight.bold, fontSize: 14))
                    else
                      Text('Gratuit',
                          style: TextStyle(color: colors.primary, fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(width: 16),
                    Icon(Icons.visibility, color: colors.textSecondary, size: 16),
                    const SizedBox(width: 4),
                    Text('${episode.views}', style: TextStyle(color: colors.textSecondary, fontSize: 14)),
                    const SizedBox(width: 16),
                    Icon(Icons.thumb_up, color: colors.textSecondary, size: 16),
                    const SizedBox(width: 4),
                    Text('${episode.likes}', style: TextStyle(color: colors.textSecondary, fontSize: 14)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToEpisodeDetail(Episode episode) {
    if (episode.isVideo) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => ContentDetailScreen(content: widget.series, episode: episode)));
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (_) => EbookDetailScreen(content: widget.series, episode: episode)));
    }
  }

  Widget _buildSeriesHeader(AppColors colors) {
    final typeColor = _typeColor(widget.series.contentType, colors);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity, height: 200,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: colors.surfaceVariant),
          child: widget.series.thumbnailUrl.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: _cdnUrl(widget.series.thumbnailUrl), fit: BoxFit.cover,
                    placeholder: (_, __) => Container(color: colors.shimmerBase, child: Center(child: CircularProgressIndicator(color: typeColor))),
                    errorWidget: (_, __, ___) => Center(child: Icon(widget.series.isVideo ? Icons.videocam : Icons.book, color: colors.textSecondary, size: 50)),
                  ),
                )
              : Center(child: Icon(widget.series.isVideo ? Icons.videocam : Icons.book, color: colors.textSecondary, size: 50)),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _buildContentTypeBadge(widget.series.contentType, colors),
            const SizedBox(width: 8),
            Text(widget.series.isVideoSeries ? 'Série Vidéo' : 'Série Ebook',
                style: TextStyle(color: colors.textSecondary, fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),
        Text(widget.series.title,
            style: TextStyle(color: colors.textPrimary, fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(widget.series.description, style: TextStyle(color: colors.textSecondary, fontSize: 16)),
        const SizedBox(height: 16),
        Row(
          children: [
            Icon(widget.series.isVideo ? Icons.playlist_play : Icons.library_books, color: typeColor, size: 20),
            const SizedBox(width: 4),
            Text('${_episodes.length} épisode${_episodes.length > 1 ? 's' : ''}',
                style: TextStyle(color: typeColor, fontSize: 16)),
            const SizedBox(width: 20),
            Icon(Icons.visibility, color: colors.textSecondary, size: 20),
            const SizedBox(width: 4),
            Text('${widget.series.views} vues', style: TextStyle(color: colors.textSecondary, fontSize: 16)),
            const SizedBox(width: 20),
            Icon(Icons.thumb_up, color: colors.textSecondary, size: 20),
            const SizedBox(width: 4),
            Text('${widget.series.likes} likes', style: TextStyle(color: colors.textSecondary, fontSize: 16)),
          ],
        ),
      ],
    );
  }

  Widget _buildErrorWidget(AppColors colors) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: colors.danger, size: 64),
          const SizedBox(height: 16),
          Text('Erreur de chargement', style: TextStyle(color: colors.textPrimary, fontSize: 18)),
          const SizedBox(height: 8),
          Text(_errorMessage, style: TextStyle(color: colors.textSecondary, fontSize: 14), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(foregroundColor: colors.onPrimary, backgroundColor: colors.primary),
            onPressed: _loadEpisodes,
            child: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingWidget(AppColors colors) {
    final typeColor = _typeColor(widget.series.contentType, colors);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: typeColor),
          const SizedBox(height: 16),
          Text('Chargement des épisodes...', style: TextStyle(color: colors.textPrimary)),
        ],
      ),
    );
  }

  Widget _buildEmptyWidget(AppColors colors) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(widget.series.isVideo ? Icons.playlist_play : Icons.library_books,
              size: 64, color: colors.textSecondary),
          const SizedBox(height: 16),
          Text('Aucun épisode disponible', style: TextStyle(color: colors.textSecondary, fontSize: 18)),
          const SizedBox(height: 8),
          Text(
            widget.series.isVideo
                ? 'Les épisodes vidéo seront bientôt disponibles'
                : 'Les chapitres ebook seront bientôt disponibles',
            style: TextStyle(color: colors.textSecondary, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final contentProvider = Provider.of<ContentProvider>(context, listen: false);
    contentProvider.incrementViews(widget.series.id!);

    final typeColor = _typeColor(widget.series.contentType, colors);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        title: Text(widget.series.title,
            style: TextStyle(color: typeColor, fontWeight: FontWeight.bold)),
        iconTheme: IconThemeData(color: typeColor),
        actions: [
          IconButton(icon: Icon(Icons.refresh, color: typeColor), onPressed: _loadEpisodes),
          IconButton(icon: Icon(Icons.share, color: typeColor), onPressed: () {}),
        ],
      ),
      body: _isLoading
          ? _buildLoadingWidget(colors)
          : _hasError
              ? _buildErrorWidget(colors)
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSeriesHeader(colors),
                      const SizedBox(height: 24),
                      Text(
                        widget.series.isVideo ? 'Épisodes Vidéo' : 'Chapitres Ebook',
                        style: TextStyle(color: colors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      if (_episodes.isEmpty)
                        _buildEmptyWidget(colors)
                      else
                        Column(
                          children: List.generate(_episodes.length, (index) {
                            final ep = _episodes[index];
                            return GestureDetector(
                              onTap: () => _navigateToEpisodeDetail(ep),
                              child: _buildEpisodeItem(ep, index, colors),
                            );
                          }),
                        ),
                    ],
                  ),
                ),
    );
  }
}
