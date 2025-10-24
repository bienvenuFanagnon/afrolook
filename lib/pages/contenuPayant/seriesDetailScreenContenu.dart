import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/pages/contenuPayant/contentDetailsEbook.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/contenuPayantProvider.dart';
import 'contentDetails.dart';
import 'contentForm.dart';

class SeriesDetailScreen extends StatefulWidget {
  final ContentPaie series;

  SeriesDetailScreen({required this.series});

  @override
  _SeriesDetailScreenState createState() => _SeriesDetailScreenState();
}

class _SeriesDetailScreenState extends State<SeriesDetailScreen> {
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
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.series.title, style: TextStyle(color: Colors.green)),
        backgroundColor: Colors.black,
        iconTheme: IconThemeData(color: Colors.green),
        actions: [
          IconButton(
            icon: Icon(Icons.add, color: Colors.green),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ContentFormScreen(
                    isEpisode: true,
                    seriesId: widget.series.id,
                  ),
                ),
              ).then((_) => _loadEpisodes());
            },
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Colors.green))
          : SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bannière
            Container(
              height: 200,
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: NetworkImage(widget.series.thumbnailUrl),
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
                padding: EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.series.title,
                        style: TextStyle(color: Colors.green, fontSize: 24, fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Text('${_episodes.length} épisode(s)', style: TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(widget.series.description,
                  style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
            SizedBox(height: 16),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('Épisodes', style: TextStyle(color: Colors.green, fontSize: 20, fontWeight: FontWeight.bold)),
            ),
            SizedBox(height: 8),
            _episodes.isEmpty
                ? Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(Icons.movie_creation, size: 60, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('Aucun épisode pour cette série',
                        style: TextStyle(color: Colors.grey, fontSize: 16)),
                    SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ContentFormScreen(
                              isEpisode: true,
                              seriesId: widget.series.id,
                            ),
                          ),
                        ).then((_) => _loadEpisodes());
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green, foregroundColor: Colors.white),
                      child: Text('Ajouter le premier épisode'),
                    ),
                  ],
                ),
              ),
            )
                : ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: _episodes.length,
              itemBuilder: (context, index) => _buildEpisodeItem(_episodes[index], index + 1),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEpisodeItem(Episode episode, int number) {
    return Card(
      color: Colors.grey[900],
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: Stack(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                image: DecorationImage(
                    image: NetworkImage(episode.thumbnailUrl ?? widget.series.thumbnailUrl),
                    fit: BoxFit.cover),
              ),
            ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(child: Icon(Icons.play_circle_fill, color: Colors.green, size: 32)),
              ),
            ),
          ],
        ),
        title: Text('Épisode $number: ${episode.title}',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4),
            Text(episode.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white70)),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.visibility, size: 12, color: Colors.grey),
                SizedBox(width: 4),
                Text('${episode.views}', style: TextStyle(color: Colors.grey, fontSize: 12)),
                SizedBox(width: 12),
                Icon(Icons.thumb_up, size: 12, color: Colors.grey),
                SizedBox(width: 4),
                Text('${episode.likes}', style: TextStyle(color: Colors.grey, fontSize: 12)),
                SizedBox(width: 12),
                Icon(Icons.access_time, size: 12, color: Colors.grey),
                SizedBox(width: 4),
                Text(_formatDuration(episode.duration), style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
            SizedBox(height: 4),
            !episode.isFree
                ? Text('${episode.price} FCFA', style: TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold))
                : Text('Gratuit', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
          ],
        ),
        trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
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
            pdfUrl: episode.contentType ==ContentType.EBOOK?episode.pdfUrl:null,
            pageCount: episode.contentType ==ContentType.EBOOK?episode.pageCount:0,
            comments: 0,
            duration: episode.duration,
            createdAt: episode.createdAt,
            updatedAt: episode.updatedAt,
          );

          if(episode.contentType ==ContentType.EBOOK){
            Navigator.push(
                context, MaterialPageRoute(builder: (_) => EbookDetailScreen(content: content)));
          }else{
            Navigator.push(
                context, MaterialPageRoute(builder: (_) => ContentDetailScreen(content: content)));
          }


        },
      ),
    );
  }
}
