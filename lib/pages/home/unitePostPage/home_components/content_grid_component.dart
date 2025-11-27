import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/pages/contenuPayant/contentDetails.dart';
import 'package:afrotok/pages/contenuPayant/contentSerie.dart';

class ContentGridComponent {
  static Widget build({
    required List<ContentPaie> contents,
    required double width,
    required Function(ContentPaie) onContentTap,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4),
            child: Text(
              "🪙 Zone VIP 🔥",
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          GridView.builder(
            physics: NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.1,
            ),
            itemCount: contents.length,
            itemBuilder: (context, index) {
              final content = contents[index];
              return _buildContentItem(content, width / 2 - 12, onContentTap);
            },
          ),
        ],
      ),
    );
  }

  static Widget _buildContentItem(
      ContentPaie content,
      double itemWidth,
      Function(ContentPaie) onTap,
      ) {
    return GestureDetector(
      onTap: () => onTap(content),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image de preview
            Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
                color: Colors.grey[800],
              ),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                    child: content.thumbnailUrl != null && content.thumbnailUrl!.isNotEmpty
                        ? CachedNetworkImage(
                      imageUrl: content.thumbnailUrl!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      placeholder: (context, url) => Container(
                        color: Colors.grey[800],
                        child: Center(child: CircularProgressIndicator(color: Colors.green)),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[800],
                        child: Icon(Icons.error, color: Colors.white),
                      ),
                    )
                        : Center(child: Icon(Icons.videocam, color: Colors.grey[600], size: 30)),
                  ),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.play_circle_fill, color: Colors.red, size: 40),
                        SizedBox(height: 4),
                        Text(
                          "Voir",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Row(
                      children: [
                        if (!content.isFree)
                          Container(
                            padding: EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${content.price} F',
                              style: TextStyle(
                                color: Colors.yellow,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        SizedBox(width: 4),
                        if (content.isSeries)
                          Container(
                            padding: EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Icon(Icons.playlist_play, color: Colors.blue, size: 12),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Informations
            Padding(
              padding: EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    content.title,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        content.isSeries ? 'Série' : 'Film',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 10,
                        ),
                      ),
                      if (content.views != null && content.views! > 0)
                        Row(
                          children: [
                            Icon(Icons.remove_red_eye, color: Colors.white, size: 10),
                            SizedBox(width: 2),
                            Text(
                              content.views!.toString(),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
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
      ),
    );
  }

  static void navigateToContentDetails(dynamic item, BuildContext context) {
    if (item.isSeries) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => SeriesEpisodesScreen(series: item)),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ContentDetailScreen(content: item)),
      );
    }
  }
}