import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/pages/contenuPayant/contentDetailsEbook.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/contenuPayantProvider.dart';
import '../../providers/authProvider.dart';
import '../../theme/app_colors.dart';
import 'contentDetails.dart';
import 'contentForm.dart';

class SeriesDetailScreen extends StatefulWidget {
  final ContentPaie series;

  const SeriesDetailScreen({super.key, required this.series});

  @override
  _SeriesDetailScreenState createState() => _SeriesDetailScreenState();
}

class _SeriesDetailScreenState extends State<SeriesDetailScreen> {
  String _cdnUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    final userProvider = Provider.of<UserAuthProvider>(context, listen: false);
    return userProvider.convertToCdnUrl(url, userProvider.appDefaultData);
  }

  List<Episode> _episodes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEpisodes();
  }

  Future<void> _loadEpisodes() async {
    setState(() => _isLoading = true);
    final contentProvider = Provider.of<ContentProvider>(context, listen: false);
    _episodes = await contentProvider.getEpisodesForSeries(widget.series.id!);
    setState(() => _isLoading = false);
  }

  String _formatDuration(int seconds) {
    final duration = Duration(seconds: seconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) return '${hours}h ${minutes}min';
    return '${minutes}min';
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(widget.series.title, style: TextStyle(color: colors.primary)),
        backgroundColor: colors.background,
        iconTheme: IconThemeData(color: colors.primary),
        actions: [
          IconButton(
            icon: Icon(Icons.add, color: colors.primary),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ContentFormScreen(isEpisode: true, seriesId: widget.series.id)),
            ).then((_) => _loadEpisodes()),
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: colors.primary))
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Bannière
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: NetworkImage(_cdnUrl(widget.series.thumbnailUrl)),
                        fit: BoxFit.cover,
                      ),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                        ),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.series.title,
                              style: TextStyle(color: colors.primary, fontSize: 24, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text('${_episodes.length} épisode(s)', style: const TextStyle(color: Colors.white70)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(widget.series.description,
                        style: TextStyle(color: colors.textPrimary, fontSize: 16)),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text('Épisodes',
                        style: TextStyle(color: colors.primary, fontSize: 20, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 8),
                  _episodes.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                Icon(Icons.movie_creation, size: 60, color: colors.textSecondary),
                                const SizedBox(height: 16),
                                Text('Aucun épisode pour cette série',
                                    style: TextStyle(color: colors.textSecondary, fontSize: 16)),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => ContentFormScreen(isEpisode: true, seriesId: widget.series.id)),
                                  ).then((_) => _loadEpisodes()),
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: colors.primary, foregroundColor: colors.onPrimary),
                                  child: const Text('Ajouter le premier épisode'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _episodes.length,
                          itemBuilder: (context, index) {
                            final colors = AppColors.of(context);
                            return _buildEpisodeItem(_episodes[index], index + 1, colors);
                          },
                        ),
                ],
              ),
            ),
    );
  }

  Widget _buildEpisodeItem(Episode episode, int number, AppColors colors) {
    return Card(
      color: colors.surface,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: colors.border),
      ),
      child: ListTile(
        leading: Stack(
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                image: DecorationImage(
                    image: NetworkImage(_cdnUrl(episode.thumbnailUrl ?? widget.series.thumbnailUrl)),
                    fit: BoxFit.cover),
              ),
            ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(child: Icon(Icons.play_circle_fill, color: colors.primary, size: 32)),
              ),
            ),
          ],
        ),
        title: Text('Épisode $number: ${episode.title}',
            style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(episode.description,
                maxLines: 2, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: colors.textSecondary)),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.visibility, size: 12, color: colors.textSecondary),
                const SizedBox(width: 4),
                Text('${episode.views}', style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                const SizedBox(width: 12),
                Icon(Icons.thumb_up, size: 12, color: colors.textSecondary),
                const SizedBox(width: 4),
                Text('${episode.likes}', style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                const SizedBox(width: 12),
                Icon(Icons.access_time, size: 12, color: colors.textSecondary),
                const SizedBox(width: 4),
                Text(_formatDuration(episode.duration), style: TextStyle(color: colors.textSecondary, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 4),
            !episode.isFree
                ? Text('${episode.price} FCFA',
                    style: TextStyle(color: colors.accent, fontWeight: FontWeight.bold))
                : Text('Gratuit',
                    style: TextStyle(color: colors.primary, fontWeight: FontWeight.bold)),
          ],
        ),
        trailing: Icon(Icons.arrow_forward_ios, size: 16, color: colors.textSecondary),
        onTap: () {
          final content = ContentPaie(
            id: episode.id,
            ownerId: widget.series.ownerId,
            title: '${widget.series.title} - Épisode ${episode.title}',
            description: episode.description,
            videoUrl: episode.videoUrl,
            thumbnailUrl: episode.thumbnailUrl ?? widget.series.thumbnailUrl,
            categories: widget.series.categories,
            hashtags: widget.series.hashtags,
            isSeries: false,
            seriesId: widget.series.id,
            price: episode.price,
            isFree: episode.isFree,
            views: episode.views,
            likes: episode.likes,
            contentType: episode.contentType,
            pdfUrl: episode.contentType == ContentType.EBOOK ? episode.pdfUrl : null,
            pageCount: episode.contentType == ContentType.EBOOK ? episode.pageCount : 0,
            comments: 0,
            duration: episode.duration,
            createdAt: episode.createdAt,
            updatedAt: episode.updatedAt,
          );
          if (episode.contentType == ContentType.EBOOK) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => EbookDetailScreen(content: content)));
          } else {
            Navigator.push(context, MaterialPageRoute(builder: (_) => ContentDetailScreen(content: content)));
          }
        },
      ),
    );
  }
}
