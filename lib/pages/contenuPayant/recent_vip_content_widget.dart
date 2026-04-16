import 'dart:io';
import 'dart:typed_data';

import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/pages/contenuPayant/contentDetails.dart';
import 'package:afrotok/pages/contenuPayant/contentDetailsEbook.dart';
import 'package:afrotok/pages/contenuPayant/contentSerie.dart';
import 'package:afrotok/providers/contenuPayantProvider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import 'TableauDeBord.dart';

class RecentVIPContentWidget extends StatefulWidget {
  const RecentVIPContentWidget({Key? key}) : super(key: key);

  @override
  State<RecentVIPContentWidget> createState() => _RecentVIPContentWidgetState();
}

class _RecentVIPContentWidgetState extends State<RecentVIPContentWidget> {
  List<ContentPaie> _recentContents = [];
  bool _isLoading = true;
  final Map<String, Uint8List?> _videoThumbnails = {};

  @override
  void initState() {
    super.initState();
    _loadRecentContents();
  }

  Future<void> _loadRecentContents() async {
    final provider = Provider.of<ContentProvider>(context, listen: false);
    final contents = await provider.getRecentContentPaies(limit: 5);
    setState(() {
      _recentContents = contents;
      _isLoading = false;
    });
    // Pré-générer les miniatures pour les vidéos qui n'ont pas de thumbnailUrl
    _preloadThumbnails();
  }

  Future<void> _preloadThumbnails() async {
    for (var content in _recentContents) {
      if (content.isVideo && (content.thumbnailUrl == null || content.thumbnailUrl!.isEmpty)) {
        final thumbnail = await _generateVideoThumbnail(content.videoUrl!);
        if (thumbnail != null) {
          setState(() {
            _videoThumbnails[content.id!] = thumbnail;
          });
        }
      }
    }
  }

  Future<Uint8List?> _generateVideoThumbnail(String videoUrl) async {
    try {
      final path = await VideoThumbnail.thumbnailFile(
        video: videoUrl,
        thumbnailPath: (await getTemporaryDirectory()).path,
        imageFormat: ImageFormat.JPEG,
        maxHeight: 200,
        quality: 75,
      );
      if (path != null) {
        return await File(path).readAsBytes();
      }
    } catch (e) {
      print('Erreur génération miniature : $e');
    }
    return null;
  }

  void _navigateToContent(ContentPaie content) {
    if (content.isSeries) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => SeriesEpisodesScreen(series: content)),
      );
    } else if (content.isEbook) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => EbookDetailScreen(content: content)),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ContentDetailScreen(content: content)),
      );
    }
  }

  Widget _buildContentThumbnail(ContentPaie content) {
    // Si c'est une vidéo et qu'on a une miniature générée localement
    if (content.isVideo && _videoThumbnails[content.id] != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.memory(
          _videoThumbnails[content.id]!,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        ),
      );
    }

    // Sinon utiliser thumbnailUrl ou placeholder
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: content.thumbnailUrl != null && content.thumbnailUrl!.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: content.thumbnailUrl!,
              fit: BoxFit.cover,
              width: double.infinity,
              placeholder: (_, __) => Container(color: Colors.grey[800]),
              errorWidget: (_, __, ___) => _buildPlaceholder(content),
            )
          : _buildPlaceholder(content),
    );
  }

  Widget _buildPlaceholder(ContentPaie content) {
    return Container(
      color: Colors.grey[850],
      child: Center(
        child: Icon(
          content.isEbook ? Icons.book : Icons.videocam,
          color: Colors.grey[600],
          size: 40,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        height: 220,
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: const Center(child: CircularProgressIndicator(color: Colors.red)),
      );
    }

    if (_recentContents.isEmpty) {
      return const SizedBox.shrink(); // Rien si aucun contenu
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête avec titre et bouton voir plus
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text('🔥', style: TextStyle(fontSize: 22)),
                    const SizedBox(width: 6),
                    Text(
                      'Zone VIP',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.red, width: 0.5),
                      ),
                      child: const Text(
                        'Nouveautés',
                        style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) =>  DashboardContentScreen()),
                    );
                  },
                  child: Row(
                    children: [
                      Text(
                        'Voir plus',
                        style: TextStyle(
                          color: Colors.yellow[700],
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_forward_ios, color: Colors.yellow[700], size: 14),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Liste horizontale
          SizedBox(
            height: 210,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _recentContents.length,
              itemBuilder: (context, index) {
                final content = _recentContents[index];
                return GestureDetector(
                  onTap: () => _navigateToContent(content),
                  child: Container(
                    width: 160,
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Image / vignette
                        Expanded(
                          child: Stack(
                            children: [
                              _buildContentThumbnail(content),
                              // Badge prix (si payant)
                              if (!content.isFree)
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.7),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.yellow, width: 0.5),
                                    ),
                                    child: Text(
                                      '${content.price} F',
                                      style: const TextStyle(
                                        color: Colors.yellow,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              // Badge gratuit
                              if (content.isFree)
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.7),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Text(
                                      'Gratuit',
                                      style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                              // Badge type (série, ebook)
                              Positioned(
                                bottom: 6,
                                left: 6,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.7),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        content.isSeries
                                            ? Icons.playlist_play
                                            : (content.isEbook ? Icons.book : Icons.play_circle_outline),
                                        color: content.isSeries
                                            ? Colors.blue
                                            : (content.isEbook ? Colors.purple : Colors.red),
                                        size: 12,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        content.isSeries
                                            ? 'Série'
                                            : (content.isEbook ? 'Ebook' : 'Vidéo'),
                                        style: const TextStyle(color: Colors.white, fontSize: 10),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Titre
                        Text(
                          content.title,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        // Infos supplémentaires
                        Row(
                          children: [
                            if (content.isEbook && content.pageCount > 0)
                              Text(
                                '${content.pageCount} p.',
                                style: const TextStyle(color: Colors.grey, fontSize: 10),
                              ),
                            if (content.isVideo && content.duration > 0)
                              Text(
                                '${(content.duration / 60).floor()} min',
                                style: const TextStyle(color: Colors.grey, fontSize: 10),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}